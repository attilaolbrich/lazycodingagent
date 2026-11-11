unit uToolProcessCore;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAgentToolBase;

function RunToolProcess(const Executable: string; Args: TStrings; const Cwd: string;
  TimeoutMS: Integer = 120000; TrackChanges: Boolean = False;
  StripGitEnv: Boolean = False): TJSONObject;

implementation

uses
  Math, Process, Pipes, uAgentToolPaths,
  {$IFDEF UNIX}BaseUnix, Unix, ctypes{$ELSE}Windows{$ENDIF};

const
  OutputLimit = 1024 * 1024;

type
  {$IFDEF WINDOWS}
  TWindowsJobObject = class
  private
    FHandle: THandle;
  public
    constructor Create;
    function AssignProcess(AProcessHandle: THandle): Boolean;
    destructor Destroy; override;
  end;
  {$ENDIF}
  TProcessGroup = class
    procedure AfterFork(Sender: TObject);
  end;

{$IFDEF WINDOWS}
const
  JobObjectExtendedLimitInformation = 9;
  JobObjectLimitKillOnJobClose = $00002000;

type
  TJobObjectBasicLimitInformation = record
    PerProcessUserTimeLimit: Int64;
    PerJobUserTimeLimit: Int64;
    LimitFlags: DWORD;
    MinimumWorkingSetSize: NativeUInt;
    MaximumWorkingSetSize: NativeUInt;
    ActiveProcessLimit: DWORD;
    Affinity: NativeUInt;
    PriorityClass: DWORD;
    SchedulingClass: DWORD;
  end;
  TIoCounters = record
    ReadOperationCount: Int64;
    WriteOperationCount: Int64;
    OtherOperationCount: Int64;
    ReadTransferCount: Int64;
    WriteTransferCount: Int64;
    OtherTransferCount: Int64;
  end;
  TJobObjectExtendedLimitInformation = record
    BasicLimitInformation: TJobObjectBasicLimitInformation;
    IoInfo: TIoCounters;
    ProcessMemoryLimit: NativeUInt;
    JobMemoryLimit: NativeUInt;
    PeakProcessMemoryUsed: NativeUInt;
    PeakJobMemoryUsed: NativeUInt;
  end;

function WinCreateJobObject(lpJobAttributes: Pointer; lpName: PWideChar): THandle; stdcall;
  external 'kernel32.dll' name 'CreateJobObjectW';
function WinSetInformationJobObject(hJob: THandle; JobObjectInfoClass: Integer;
  lpJobObjectInformation: Pointer; cbJobObjectInformationLength: DWORD): LongBool; stdcall;
  external 'kernel32.dll' name 'SetInformationJobObject';
function WinAssignProcessToJobObject(hJob, hProcess: THandle): LongBool; stdcall;
  external 'kernel32.dll' name 'AssignProcessToJobObject';
function WinCloseHandle(hObject: THandle): LongBool; stdcall;
  external 'kernel32.dll' name 'CloseHandle';

constructor TWindowsJobObject.Create;
var
  Info: TJobObjectExtendedLimitInformation;
begin
  inherited Create;
  FHandle := WinCreateJobObject(nil, nil);
  if FHandle = 0 then Exit;
  FillChar(Info, SizeOf(Info), 0);
  Info.BasicLimitInformation.LimitFlags := JobObjectLimitKillOnJobClose;
  if not WinSetInformationJobObject(FHandle, JobObjectExtendedLimitInformation,
    @Info, SizeOf(Info)) then
  begin
    WinCloseHandle(FHandle);
    FHandle := 0;
  end;
end;

function TWindowsJobObject.AssignProcess(AProcessHandle: THandle): Boolean;
begin
  Result := (FHandle <> 0) and WinAssignProcessToJobObject(FHandle, AProcessHandle);
end;

destructor TWindowsJobObject.Destroy;
begin
  if FHandle <> 0 then WinCloseHandle(FHandle);
  inherited Destroy;
end;
{$ENDIF}

procedure TProcessGroup.AfterFork(Sender: TObject);
begin
  {$IFDEF UNIX}fpSetSid;{$ENDIF}
end;

function IsGitOverrideEnv(const Line: string): Boolean;
var
  Key: string;
  P: Integer;
begin
  P := Pos('=', Line);
  if P <= 1 then Exit(False);
  Key := UpperCase(Copy(Line, 1, P - 1));
  Result := (Key = 'GIT_DIR') or (Key = 'GIT_WORK_TREE') or (Key = 'GIT_INDEX_FILE') or
    (Key = 'GIT_OBJECT_DIRECTORY') or (Key = 'GIT_ALTERNATE_OBJECT_DIRECTORIES');
end;

function LoadInheritedEnvironment: TStringList;
var
  {$IFDEF UNIX}
  I: Integer;
  {$ELSE}
  Block, Cur: PWideChar;
  Entry: string;
  {$ENDIF}
begin
  Result := TStringList.Create;
  {$IFDEF UNIX}
  for I := 0 to GetEnvironmentVariableCount - 1 do
    Result.Add(GetEnvironmentString(I));
  {$ELSE}
  Block := GetEnvironmentStringsW;
  if Block <> nil then
  begin
    Cur := Block;
    while Cur^ <> #0 do
    begin
      Entry := Cur;
      Result.Add(Entry);
      Cur := Cur + Length(Entry) + 1;
    end;
    FreeEnvironmentStringsW(Block);
  end;
  {$ENDIF}
end;

procedure StopTree(P: TProcess);
{$IFDEF WINDOWS}var Killer: TProcess;{$ENDIF}
begin
  {$IFDEF UNIX}
  fpKill(-P.ProcessID, SIGKILL);
  if P.Running then fpKill(P.ProcessID, SIGKILL);
  {$ELSE}
  Killer := TProcess.Create(nil);
  try
    Killer.Executable := 'taskkill.exe';
    Killer.Parameters.Add('/PID');
    Killer.Parameters.Add(IntToStr(P.ProcessID));
    Killer.Parameters.Add('/T');
    Killer.Parameters.Add('/F');
    Killer.Options := [poNoConsole];
    Killer.Execute;
    Killer.WaitOnExit;
  finally
    Killer.Free;
  end;
  if P.Running then P.Terminate(1);
  {$ENDIF}
end;

function RunToolProcess(const Executable: string; Args: TStrings; const Cwd: string;
  TimeoutMS: Integer; TrackChanges: Boolean; StripGitEnv: Boolean): TJSONObject;
var
  P: TProcess;
  Group: TProcessGroup;
  {$IFDEF WINDOWS}Job: TWindowsJobObject;{$ENDIF}
  OutText, ErrText: RawByteString;
  CleanOut, CleanErr: string;
  OutTruncated, ErrTruncated, TimedOut, Cancelled, Stopped: Boolean;
  Started, StopAt: QWord;
  BeforeFiles, AfterFiles, SanitizedEnv: TStringList;
  TrackingWarning, Root: string;
  Changed: TJSONArray;
  EnvI: Integer;

  function FileFingerprint(const Path: string): string;
  var
    {$IFDEF UNIX}Info: Stat;{$ENDIF}
    R: TSearchRec;
  begin
    {$IFDEF UNIX}
    if (fpLStat(Path, Info) <> 0) or not FPS_ISREG(Info.st_mode) then
      raise Exception.Create('Cannot track nonregular file: ' + Path);
    Result := IntToStr(Info.st_size) + ':' + IntToStr(Info.st_mtime);
    {$IFDEF LINUX}
    Result := Result + ':' + IntToStr(Info.st_mtime_nsec);
    {$ENDIF}
    Result := Result + ':' + IntToStr(Info.st_ctime) + ':' + IntToStr(Info.st_ino);
    {$ELSE}
    if FindFirst(Path, faAnyFile, R) <> 0 then
      raise Exception.Create('Cannot track file: ' + Path);
    try
      if (R.Attr and faDirectory) <> 0 then
        raise Exception.Create('Cannot track nonregular file: ' + Path);
      Result := IntToStr(R.Size) + ':' + IntToStr(R.Time);
    finally
      SysUtils.FindClose(R);
    end;
    {$ENDIF}
  end;

  procedure Snapshot(Files: TStringList);

    procedure Walk(const Dir: string; Depth: Integer);
    var
      R: TSearchRec;
      Path, FP: string;
      Code: Integer;
    begin
      if Depth > 64 then raise Exception.Create('Directory nesting exceeds 64 levels');
      Code := FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, R);
      if Code <> 0 then
      begin
        if not DirectoryExists(Dir) then raise Exception.Create('Cannot scan ' + Dir);
        {$IFDEF UNIX}
        if fpAccess(Dir, R_OK or X_OK) <> 0 then raise Exception.Create('Cannot scan ' + Dir);
        {$ENDIF}
        Exit;
      end;
      try
        repeat
          if (R.Name = '.') or (R.Name = '..') then Continue;
          Path := IncludeTrailingPathDelimiter(Dir) + R.Name;
          if IsPathLink(Path) then Continue;
          if (R.Attr and faDirectory) <> 0 then
          begin
            if not SkipGenerated(R.Name) and (R.Name <> '.plan') then Walk(Path, Depth + 1);
          end
          else
          begin
            try
              FP := FileFingerprint(Path);
              Files.Add(Path + #0 + FP);
            except
              on E: Exception do
                TrackingWarning := 'Changed-file list may be incomplete: ' + E.Message;
            end;
          end;
        until FindNext(R) <> 0;
      finally
        SysUtils.FindClose(R);
      end;
    end;

  begin
    try
      Walk(Root, 0);
    except
      on E: Exception do
        TrackingWarning := 'Changed-file list may be incomplete: ' + E.Message;
    end;
    Files.Sort;
  end;

  procedure AddChanges;
  var
    BI, AI: Integer;
    BeforeName, AfterName: string;
  begin
    Snapshot(AfterFiles);
    Changed := TJSONArray.Create;
    BI := 0;
    AI := 0;
    while (BI < BeforeFiles.Count) or (AI < AfterFiles.Count) do
    begin
      if BI >= BeforeFiles.Count then
      begin
        Changed.Add(AfterFiles.Names[AI]);
        Inc(AI);
        Continue;
      end;
      if AI >= AfterFiles.Count then
      begin
        Changed.Add(BeforeFiles.Names[BI]);
        Inc(BI);
        Continue;
      end;
      BeforeName := BeforeFiles.Names[BI];
      AfterName := AfterFiles.Names[AI];
      if BeforeName = AfterName then
      begin
        if BeforeFiles.ValueFromIndex[BI] <> AfterFiles.ValueFromIndex[AI] then
          Changed.Add(BeforeName);
        Inc(BI);
        Inc(AI);
      end
      else if BeforeName < AfterName then
      begin
        Changed.Add(BeforeName);
        Inc(BI);
      end
      else
      begin
        Changed.Add(AfterName);
        Inc(AI);
      end;
    end;
    Result.Add('changed_paths', Changed);
    if TrackingWarning <> '' then Result.Add('tracking_warning', TrackingWarning);
  end;

  procedure Drain(Stream: TInputPipeStream; var Text: RawByteString; var Truncated: Boolean);
  var
    Buffer: array[0..8191] of Byte;
    N, Keep: Integer;
    Chunk: RawByteString;
  begin
    if Stream.NumBytesAvailable = 0 then Exit;
    N := Stream.Read(Buffer, Min(Stream.NumBytesAvailable, SizeOf(Buffer)));
    if N <= 0 then Exit;
    Keep := N;
    if Length(Text) + Keep > OutputLimit then Keep := OutputLimit - Length(Text);
    if Keep < N then Truncated := True;
    SetLength(Chunk, Keep);
    if Keep > 0 then Move(Buffer[0], Chunk[1], Keep);
    Text := Text + Chunk;
  end;

begin
  if (TimeoutMS < 1) or (TimeoutMS > 600000) then raise Exception.Create('timeout_ms must be 1..600000');
  if not DirectoryExists(Cwd) then raise Exception.Create('Working directory does not exist');
  BeforeFiles := TStringList.Create;
  AfterFiles := TStringList.Create;
  BeforeFiles.CaseSensitive := {$IFDEF WINDOWS}False{$ELSE}True{$ENDIF};
  AfterFiles.CaseSensitive := BeforeFiles.CaseSensitive;
  BeforeFiles.NameValueSeparator := #0;
  AfterFiles.NameValueSeparator := #0;
  Root := CurrentToolContext.WorkspaceRoot;
  TrackingWarning := '';
  P := TProcess.Create(nil);
  Group := TProcessGroup.Create;
  {$IFDEF WINDOWS}Job := nil;{$ENDIF}
  OutText := '';
  ErrText := '';
  OutTruncated := False;
  ErrTruncated := False;
  TimedOut := False;
  Cancelled := False;
  Stopped := False;
  StopAt := 0;
  try
    if TrackChanges then Snapshot(BeforeFiles);
    P.Executable := Executable;
    P.Parameters.Assign(Args);
    P.CurrentDirectory := Cwd;
    if StripGitEnv then
    begin
      SanitizedEnv := LoadInheritedEnvironment;
      try
        for EnvI := SanitizedEnv.Count - 1 downto 0 do
          if IsGitOverrideEnv(SanitizedEnv[EnvI]) then
            SanitizedEnv.Delete(EnvI);
        P.Environment.Assign(SanitizedEnv);
      finally
        SanitizedEnv.Free;
      end;
    end;
    P.Options := [poUsePipes, poNoConsole, poNewProcessGroup];
    {$IFDEF WINDOWS}
    P.Options := P.Options + [poRunSuspended];
    Job := TWindowsJobObject.Create;
    {$ENDIF}
    {$IFDEF UNIX}P.OnForkEvent := @Group.AfterFork;{$ENDIF}
    P.Execute;
    {$IFDEF WINDOWS}
    if Assigned(Job) and not Job.AssignProcess(P.ProcessHandle) then
      TrackingWarning := Trim(TrackingWarning + ' Process job assignment failed.');
    P.Resume;
    {$ENDIF}
    P.CloseInput;
    Started := GetTickCount64;
    repeat
      Drain(P.Output, OutText, OutTruncated);
      Drain(P.Stderr, ErrText, ErrTruncated);
      Cancelled := Cancelled or ToolCancelled;
      TimedOut := TimedOut or ((GetTickCount64 - Started) >= QWord(TimeoutMS));
      if (Cancelled or TimedOut) and not Stopped then
      begin
        StopTree(P);
        Stopped := True;
        StopAt := GetTickCount64;
      end;
      if not P.Running and (P.Output.NumBytesAvailable = 0) and (P.Stderr.NumBytesAvailable = 0) then Break;
      if Stopped and (GetTickCount64 - StopAt > 2000) then Break;
      Sleep(5);
    until False;
    if Stopped and P.Running then
      StopTree(P);
    P.WaitOnExit;
    CleanOut := SafeToolText(OutText);
    CleanErr := SafeToolText(ErrText);
    if Length(CleanOut) > OutputLimit then
    begin
      OutTruncated := True;
      CleanOut := SafeToolText(CleanOut, OutputLimit);
    end;
    if Length(CleanErr) > OutputLimit then
    begin
      ErrTruncated := True;
      CleanErr := SafeToolText(CleanErr, OutputLimit);
    end;
    Result := TJSONObject.Create(['exit_code', P.ExitCode, 'stdout', CleanOut,
      'stderr', CleanErr, 'timed_out', TimedOut, 'cancelled', Cancelled,
      'stdout_truncated', OutTruncated, 'stderr_truncated', ErrTruncated]);
    if TrackChanges then AddChanges;
  finally
    if P.Running then StopTree(P);
    {$IFDEF WINDOWS}Job.Free;{$ENDIF}
    P.Free;
    Group.Free;
    BeforeFiles.Free;
    AfterFiles.Free;
  end;
end;

end.
