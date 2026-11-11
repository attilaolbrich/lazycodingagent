unit uBrowserProcess;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, uBrowserReadTypes;

type
  TBrowserProcess = class
  private
    FProcess: TProcess;
    FUserDataDir: string;
    FExecutable: string;
    FOwnedPid: Integer;
    {$IFDEF MSWINDOWS}
    FJob: TObject;
    {$ENDIF}
    function ReadDevToolsPort(TimeoutMs: Integer): Word;
    function FetchWebSocketUrl(Port: Word; TimeoutMs: Integer): string;
  public
    destructor Destroy; override;
    function Start(const Executable: string; TimeoutMs: Integer;
      AHeadless: Boolean; CancelCheck: TBrowserReadCancelCheck;
      out WebSocketUrl: string; out ErrKind: TBrowserReadErrorKind;
      out ErrMsg: string): Boolean;
    procedure Stop;
    function IsRunning: Boolean;
    property OwnedPid: Integer read FOwnedPid;
  end;

implementation

uses
  DateUtils, Math, fphttpclient, fpjson, jsonparser, FileUtil
  {$IFDEF UNIX}, BaseUnix, Unix{$ENDIF}
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

{$IFDEF MSWINDOWS}
type
  TWindowsJobObject = class
  private
    FHandle: THandle;
  public
    constructor Create;
    function AssignProcess(AProcessHandle: THandle): Boolean;
    destructor Destroy; override;
  end;

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

destructor TBrowserProcess.Destroy;
begin
  Stop;
  inherited Destroy;
end;

function TBrowserProcess.IsRunning: Boolean;
begin
  Result := Assigned(FProcess) and FProcess.Running;
end;

procedure TBrowserProcess.Stop;
begin
  if Assigned(FProcess) then
  begin
    if FProcess.Running then
    begin
      try
        FProcess.Terminate(0);
        FProcess.WaitOnExit;
      except
      end;
    end;
    FProcess.Free;
    FProcess := nil;
  end;
  {$IFDEF MSWINDOWS}
  if Assigned(FJob) then
  begin
    FJob.Free;
    FJob := nil;
  end;
  {$ENDIF}
  FOwnedPid := 0;
  if (FUserDataDir <> '') and DirectoryExists(FUserDataDir) then
  begin
    try
      DeleteDirectory(FUserDataDir, True);
    except
    end;
    FUserDataDir := '';
  end;
end;

function TryReadDevToolsPortFile(const PortFile: string; out APort: Word): Boolean;
var
  FS: TFileStream;
  Buf: RawByteString;
  Lines: TStringList;
  I, N: Integer;
begin
  Result := False;
  APort := 0;
  if not FileExists(PortFile) then Exit;
  Lines := TStringList.Create;
  try
    try
      FS := TFileStream.Create(PortFile, fmOpenRead or fmShareDenyNone);
      try
        SetLength(Buf, FS.Size);
        if FS.Size > 0 then
          FS.ReadBuffer(Buf[1], FS.Size);
        Lines.Text := string(Buf);
      finally
        FS.Free;
      end;
    except
      Exit;
    end;
    for I := 0 to Lines.Count - 1 do
    begin
      N := StrToIntDef(Trim(Lines[I]), 0);
      if (N > 0) and (N <= 65535) then
      begin
        APort := Word(N);
        Exit(True);
      end;
    end;
  finally
    Lines.Free;
  end;
end;

function TBrowserProcess.ReadDevToolsPort(TimeoutMs: Integer): Word;
var
  PortFile: string;
  T0: QWord;
  P: Word;
begin
  Result := 0;
  PortFile := IncludeTrailingPathDelimiter(FUserDataDir) + 'DevToolsActivePort';
  T0 := GetTickCount64;
  while GetTickCount64 - T0 < QWord(TimeoutMs) do
  begin
    if TryReadDevToolsPortFile(PortFile, P) then
      Exit(P);
    Sleep(50);
  end;
end;

function TBrowserProcess.FetchWebSocketUrl(Port: Word; TimeoutMs: Integer): string;
var
  Client: TFPHTTPClient;
  Body: string;
  O: TJSONObject;
begin
  Result := '';
  Client := TFPHTTPClient.Create(nil);
  try
    Client.ConnectTimeout := TimeoutMs;
    Client.IOTimeout := TimeoutMs;
    Body := Client.Get('http://127.0.0.1:' + IntToStr(Port) + '/json/version');
    O := TJSONObject(GetJSON(Body));
    try
      Result := O.Get('webSocketDebuggerUrl', '');
    finally
      O.Free;
    end;
  finally
    Client.Free;
  end;
end;

function ParseWsUrl(const Url: string; out Host: string; out Port: Word;
  out Path: string): Boolean;
var
  S, Rest: string;
  P: SizeInt;
begin
  Host := '';
  Port := 0;
  Path := '/';
  S := Url;
  if not SameText(Copy(S, 1, 5), 'ws://') then Exit(False);
  Delete(S, 1, 5);
  P := Pos('/', S);
  if P > 0 then
  begin
    Rest := Copy(S, P, MaxInt);
    S := Copy(S, 1, P - 1);
    Path := Rest;
  end;
  P := Pos(':', S);
  if P > 0 then
  begin
    Host := Copy(S, 1, P - 1);
    Port := StrToIntDef(Copy(S, P + 1, MaxInt), 0);
  end
  else
  begin
    Host := S;
    Port := 80;
  end;
  Result := (Host <> '') and (Port > 0);
end;

function TBrowserProcess.Start(const Executable: string; TimeoutMs: Integer;
  AHeadless: Boolean; CancelCheck: TBrowserReadCancelCheck;
  out WebSocketUrl: string; out ErrKind: TBrowserReadErrorKind;
  out ErrMsg: string): Boolean;
var
  Args: TStringList;
  Port: Word;
  LaunchTimeout: Integer;
  StartTick: QWord;
begin
  Port := 0;
  WebSocketUrl := '';
  ErrKind := brekNone;
  ErrMsg := '';
  Stop;

  FExecutable := Executable;
  FUserDataDir := IncludeTrailingPathDelimiter(GetTempDir) +
    'lca-browser-' + IntToStr(GetProcessID) + '-' + IntToStr(Random(999999));
  ForceDirectories(FUserDataDir);

  FProcess := TProcess.Create(nil);
  Args := TStringList.Create;
  try
    FProcess.Executable := Executable;
    if AHeadless then
    begin
      Args.Add('--headless=new');
      Args.Add('--disable-gpu');
    end;
    Args.Add('--no-first-run');
    Args.Add('--no-default-browser-check');
    Args.Add('--disable-extensions');
    Args.Add('--disable-sync');
    Args.Add('--disable-background-networking');
    Args.Add('--disable-default-apps');
    Args.Add('--disable-translate');
    if AHeadless then
      Args.Add('--mute-audio');
    Args.Add('--user-data-dir=' + FUserDataDir);
    Args.Add('--remote-debugging-port=0');
    Args.Add('--remote-allow-origins=*');
    FProcess.Parameters := Args;
    FProcess.Options := [poUsePipes, poNoConsole];
    if AHeadless then
      FProcess.ShowWindow := swoHide
    else
      FProcess.ShowWindow := swoShowNormal;
    FProcess.Execute;
    FOwnedPid := FProcess.ProcessID;
    {$IFDEF MSWINDOWS}
    FJob := TWindowsJobObject.Create;
    if (FJob <> nil) and (TWindowsJobObject(FJob).AssignProcess(FProcess.Handle)) then ;
    {$ENDIF}
  finally
    Args.Free;
  end;

  LaunchTimeout := Min(TimeoutMs, 30000);
  StartTick := GetTickCount64;
  while (GetTickCount64 - StartTick < QWord(LaunchTimeout)) and
    (not Assigned(CancelCheck) or not CancelCheck()) do
  begin
    Port := ReadDevToolsPort(LaunchTimeout);
    if Port > 0 then Break;
    if not FProcess.Running then
    begin
      ErrKind := brekBrowserStartFailed;
      ErrMsg := 'Browser process exited before the debugger port was ready';
      Stop;
      Exit(False);
    end;
    Sleep(50);
  end;
  if Port = 0 then
  begin
    ErrKind := brekBrowserStartFailed;
    ErrMsg := 'Timed out waiting for DevToolsActivePort';
    Stop;
    Exit(False);
  end;
  if Assigned(CancelCheck) and CancelCheck() then
  begin
    ErrKind := brekCancelled;
    ErrMsg := 'Cancelled';
    Stop;
    Exit(False);
  end;

  WebSocketUrl := FetchWebSocketUrl(Port, LaunchTimeout);
  if WebSocketUrl = '' then
  begin
    ErrKind := brekCdpConnectionFailed;
    ErrMsg := 'Could not read WebSocket debugger URL';
    Stop;
    Exit(False);
  end;
  Result := True;
end;

end.
