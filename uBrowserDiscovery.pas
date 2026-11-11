unit uBrowserDiscovery;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uBrowserReadTypes;

function DiscoverChromiumExecutable(const Config: TBrowserReadConfig;
  out Executable: string; out ErrMsg: string): Boolean;

implementation

uses
  {$IFDEF UNIX}BaseUnix,{$ENDIF}
  {$IFDEF MSWINDOWS}Windows,{$ENDIF}
  Process;

function PathIsRunnable(const Path: string): Boolean;
begin
  Result := (Path <> '') and FileExists(Path);
  {$IFDEF UNIX}
  if Result then
    Result := fpAccess(Path, X_OK) = 0;
  {$ENDIF}
end;

function CanonicalExecutablePath(const Path: string): string;
var
  LinkTarget: string;
begin
  Result := ExpandFileName(Path);
  {$IFDEF UNIX}
  repeat
    LinkTarget := fpReadLink(Result);
    if LinkTarget = '' then
      Break;
    if LinkTarget[1] <> '/' then
      LinkTarget := ExpandFileName(
        IncludeTrailingPathDelimiter(ExtractFilePath(Result)) + LinkTarget);
    Result := LinkTarget;
  until False;
  {$ENDIF}
end;

function ResolveToRunnableBinary(const Path: string): string;
const
  OPT_GOOGLE_CHROME = '/opt/google/chrome/google-chrome';
var
  Canonical: string;
  F: TFileStream;
  B: array[0..1] of Byte;
begin
  Canonical := CanonicalExecutablePath(Path);
  if not PathIsRunnable(Canonical) then
    Exit('');
  Result := Canonical;
  if not FileExists(Canonical) then
    Exit;
  F := TFileStream.Create(Canonical, fmOpenRead or fmShareDenyWrite);
  try
    if F.Read(B, 2) = 2 then
      if (B[0] = Ord('#')) and (B[1] = Ord('!')) then
        if PathIsRunnable(OPT_GOOGLE_CHROME) then
          Result := OPT_GOOGLE_CHROME;
  finally
    F.Free;
  end;
end;

function TryCandidate(const Path: string; out Executable: string): Boolean;
var
  Resolved: string;
begin
  Resolved := ResolveToRunnableBinary(Path);
  if Resolved <> '' then
  begin
    Executable := Resolved;
    Exit(True);
  end;
  Result := False;
end;

function WhichOnPath(const Name: string): string;
var
  Args: TStringList;
  P: TProcess;
  OutS: TStringList;
  Line: string;
begin
  Result := '';
  Args := TStringList.Create;
  OutS := TStringList.Create;
  P := TProcess.Create(nil);
  try
    {$IFDEF MSWINDOWS}
    P.Executable := 'where';
    Args.Add(Name);
    {$ELSE}
    P.Executable := '/usr/bin/which';
    if not FileExists(P.Executable) then
      P.Executable := 'which';
    Args.Add(Name);
    {$ENDIF}
    P.Parameters := Args;
    P.Options := [poUsePipes, poWaitOnExit, poNoConsole];
    P.ShowWindow := swoHide;
    P.Execute;
    OutS.LoadFromStream(P.Output);
    if OutS.Count > 0 then
    begin
      Line := Trim(OutS[0]);
      if PathIsRunnable(Line) then
        Result := Line;
    end;
  finally
    P.Free;
    Args.Free;
    OutS.Free;
  end;
end;

function DiscoverWindows(out Executable: string): Boolean;
const
  Candidates: array[0..5] of string = (
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files\Chromium\Application\chrome.exe',
    'C:\Program Files (x86)\Chromium\Application\chrome.exe'
  );
var
  I: Integer;
begin
  for I := Low(Candidates) to High(Candidates) do
    if TryCandidate(Candidates[I], Executable) then
      Exit(True);
  if TryCandidate(WhichOnPath('chrome'), Executable) then Exit(True);
  if TryCandidate(WhichOnPath('msedge'), Executable) then Exit(True);
  if TryCandidate(WhichOnPath('chromium'), Executable) then Exit(True);
  Result := False;
end;

function DiscoverMacOS(out Executable: string): Boolean;
const
  Candidates: array[0..3] of string = (
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
    '/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary'
  );
var
  I: Integer;
begin
  for I := Low(Candidates) to High(Candidates) do
    if TryCandidate(Candidates[I], Executable) then
      Exit(True);
  Result := False;
end;

function DiscoverUnix(out Executable: string): Boolean;
const
  Candidates: array[0..9] of string = (
    '/opt/google/chrome/google-chrome',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/snap/bin/chromium',
    '/usr/lib/chromium/chromium',
    '/usr/lib/chromium-browser/chromium-browser',
    '/usr/bin/microsoft-edge',
    '/usr/bin/microsoft-edge-stable'
  );
var
  I: Integer;
  Names: array[0..3] of string;
  N: Integer;
begin
  for I := Low(Candidates) to High(Candidates) do
    if TryCandidate(Candidates[I], Executable) then
      Exit(True);
  Names[0] := 'chromium';
  Names[1] := 'chromium-browser';
  Names[2] := 'google-chrome';
  Names[3] := 'google-chrome-stable';
  for N := Low(Names) to High(Names) do
    if TryCandidate(WhichOnPath(Names[N]), Executable) then
      Exit(True);
  Result := False;
end;

function DiscoverChromiumExecutable(const Config: TBrowserReadConfig;
  out Executable: string; out ErrMsg: string): Boolean;
begin
  Executable := '';
  ErrMsg := '';
  if Trim(Config.ExecutablePath) <> '' then
  begin
    if TryCandidate(Config.ExecutablePath, Executable) then
      Exit(True);
    ErrMsg := 'Configured browser executable was not found: ' + Config.ExecutablePath;
    Exit(False);
  end;

  {$IFDEF MSWINDOWS}
  if DiscoverWindows(Executable) then Exit(True);
  {$ELSE}
  {$IFDEF DARWIN}
  if DiscoverMacOS(Executable) then Exit(True);
  {$ELSE}
  if DiscoverUnix(Executable) then Exit(True);
  {$ENDIF}
  {$ENDIF}

  ErrMsg :=
    'No Chromium-compatible browser found. Install Google Chrome, Chromium, or Microsoft Edge, ' +
    'or set the browser executable path in Settings (Agent tab) or BrowserRead/ExecutablePath in the app config file.';
  Result := False;
end;

end.
