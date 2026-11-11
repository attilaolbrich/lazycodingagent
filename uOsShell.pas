unit uOsShell;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function OpenPathWithDefaultApplication(const APath: string): Boolean;
function RevealPathInFileManager(const APath: string): Boolean;

implementation

uses
  Classes, LCLIntf, Process, FileUtil;

function NormalizeExistingPath(const APath: string): string;
begin
  Result := ExpandFileName(Trim(APath));
  if Result = '' then Exit;
  if not (FileExists(Result) or DirectoryExists(Result)) then
    Result := '';
end;

function PathToFileUri(const APath: string): string;
var
  S: string;
begin
  S := ExpandFileName(APath);
  S := StringReplace(S, '\', '/', [rfReplaceAll]);
  Result := 'file://' + S;
  if (Length(Result) > 7) and (Result[8] <> '/') then
    Result := 'file:///' + S;
end;

function RunProcess(const AExecutable: string; const AParams: TStringList;
  AWaitOnExit: Boolean): Boolean;
var
  P: TProcess;
begin
  Result := False;
  if AExecutable = '' then Exit;
  P := TProcess.Create(nil);
  try
    P.Executable := AExecutable;
    P.Parameters.Assign(AParams);
    if AWaitOnExit then
      P.Options := [poNoConsole, poWaitOnExit]
    else
      P.Options := [poNoConsole];
    P.ShowWindow := swoHide;
    P.Execute;
    if AWaitOnExit then
      Result := P.ExitStatus = 0
    else
      Result := True;
  finally
    P.Free;
  end;
end;

function RevealPathLinuxFileManager(const APath: string): Boolean;
var
  Params: TStringList;
  Uri: string;
  DbusSend: string;
begin
  Result := False;
  Uri := PathToFileUri(APath);
  DbusSend := FindDefaultExecutablePath('dbus-send');
  if DbusSend = '' then
    DbusSend := '/usr/bin/dbus-send';
  if not FileExists(DbusSend) then
    Exit(False);
  Params := TStringList.Create;
  try
    Params.Add('--session');
    Params.Add('--print-reply');
    Params.Add('--dest=org.freedesktop.FileManager1');
    Params.Add('/org/freedesktop/FileManager1');
    Params.Add('org.freedesktop.FileManager1.ShowItems');
    Params.Add('array:string:' + Uri);
    Params.Add('string:');
    Result := RunProcess(DbusSend, Params, True);
  finally
    Params.Free;
  end;
end;

function RevealPathInFileManager(const APath: string): Boolean;
var
  Norm: string;
  Params: TStringList;
  Explorer: string;
  OpenCmd: string;
  SelectArg: string;
begin
  Norm := NormalizeExistingPath(APath);
  if Norm = '' then
    Exit(False);

  {$IFDEF MSWINDOWS}
  Explorer := IncludeTrailingPathDelimiter(GetEnvironmentVariable('WINDIR')) + 'explorer.exe';
  if not FileExists(Explorer) then
    Explorer := 'explorer.exe';
  Params := TStringList.Create;
  try
    if DirectoryExists(Norm) then
      Params.Add(Norm)
    else begin
      SelectArg := '/select,' + Norm;
      if Pos(' ', Norm) > 0 then
        SelectArg := '/select,' + '"' + Norm + '"';
      Params.Add(SelectArg);
    end;
    Result := RunProcess(Explorer, Params, False);
  finally
    Params.Free;
  end;
  Exit;
  {$ENDIF}

  {$IFDEF DARWIN}
  OpenCmd := '/usr/bin/open';
  if not FileExists(OpenCmd) then
    OpenCmd := 'open';
  Params := TStringList.Create;
  try
    Params.Add('-R');
    Params.Add(Norm);
    Result := RunProcess(OpenCmd, Params, False);
  finally
    Params.Free;
  end;
  Exit;
  {$ENDIF}

  {$IFDEF UNIX}
  if RevealPathLinuxFileManager(Norm) then
    Exit(True);
  if DirectoryExists(Norm) then
    Result := OpenDocument(Norm)
  else
    Result := OpenDocument(ExtractFileDir(Norm));
  {$ENDIF}
end;

function OpenPathWithDefaultApplication(const APath: string): Boolean;
var
  Norm: string;
begin
  Norm := NormalizeExistingPath(APath);
  if Norm = '' then
    Exit(False);
  Result := OpenDocument(Norm);
end;

end.
