unit uBrowserReadUrl;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uWebFetchTypes, uWebFetchUrl, uBrowserReadTypes;

function ValidateBrowserReadUrl(const Url: string; AllowLocalhost: Boolean;
  const WorkspaceRoot: string; out ErrKind: TBrowserReadErrorKind;
  out ErrMsg: string): Boolean;

function ValidateBrowserReadRequestUrl(const Url: string; AllowLocalhost: Boolean;
  const WorkspaceRoot: string; out ErrKind: TBrowserReadErrorKind;
  out ErrMsg: string): Boolean;

implementation

function PathJailPrefixMatches(const Root, Prefix, Candidate: string): Boolean;
begin
  {$IFDEF WINDOWS}
  if SameText(Candidate, Root) then Exit(True);
  Result := SameText(Copy(Candidate, 1, Length(Prefix)), Prefix);
  {$ELSE}
  {$IFDEF DARWIN}
  if SameText(Candidate, Root) then Exit(True);
  Result := SameText(Copy(Candidate, 1, Length(Prefix)), Prefix);
  {$ELSE}
  if Candidate = Root then Exit(True);
  Result := Copy(Candidate, 1, Length(Prefix)) = Prefix;
  {$ENDIF}
  {$ENDIF}
end;

function BrowserFilePathIsInsideWorkspace(const WorkspaceFolder, Candidate: string): Boolean;
var
  Root, Can, Prefix: string;
begin
  Result := False;
  Root := Trim(WorkspaceFolder);
  if Root = '' then Exit;
  if Trim(Candidate) = '' then Exit;
  Root := ExcludeTrailingPathDelimiter(ExpandFileName(Root));
  Can := ExcludeTrailingPathDelimiter(ExpandFileName(Candidate));
  Prefix := IncludeTrailingPathDelimiter(Root);
  Result := PathJailPrefixMatches(Root, Prefix, Can);
end;

function MapWebFetchError(AKind: TWebFetchErrorKind): TBrowserReadErrorKind;
begin
  case AKind of
    wfekInvalidUrl: Result := brekInvalidUrl;
    wfekBlockedDestination: Result := brekAccessDenied;
  else
    Result := brekAccessDenied;
  end;
end;

function StripUrlFragment(const S: string): string;
var
  P: SizeInt;
begin
  P := Pos('#', S);
  if P > 0 then
    Result := Copy(S, 1, P - 1)
  else
    Result := S;
end;

function UrlDecodePathSegment(const S: string): string;
var
  I, N: Integer;
  C: Char;
  B: Byte;
  Code: Integer;
  V: LongInt;
begin
  SetLength(Result, 0);
  I := 1;
  N := Length(S);
  while I <= N do
  begin
    C := S[I];
    if (C = '%') and (I + 2 <= N) then
    begin
      Val('$' + Copy(S, I + 1, 2), V, Code);
      if (Code = 0) and (V >= 0) and (V <= 255) then
      begin
        B := Byte(V);
        Result := Result + Chr(B);
        Inc(I, 3);
        Continue;
      end;
    end;
    Result := Result + C;
    Inc(I);
  end;
end;

function FileUrlToLocalPath(const AUrl: string; out LocalPath: string;
  out ErrMsg: string): Boolean;
var
  S, PathPart: string;
begin
  Result := False;
  LocalPath := '';
  ErrMsg := 'Invalid file URL';
  S := Trim(StripUrlFragment(AUrl));
  if not SameText(Copy(S, 1, 7), 'file://') then Exit;
  Delete(S, 1, 7);
  if SameText(Copy(S, 1, 9), 'localhost') then
  begin
    if Length(S) = 9 then
      PathPart := '/'
    else if (Length(S) > 9) and (S[10] = '/') then
      PathPart := Copy(S, 10, MaxInt)
    else
      Exit;
  end
  else
    PathPart := S;
  PathPart := UrlDecodePathSegment(PathPart);
  if PathPart = '' then
  begin
    ErrMsg := 'file URL has no path';
    Exit;
  end;
  while (Length(PathPart) > 1) and (PathPart[1] = '/') and (PathPart[2] = '/') do
    Delete(PathPart, 1, 1);
  {$IFDEF WINDOWS}
  if (Length(PathPart) >= 3) and (PathPart[1] = '/') and (PathPart[3] = ':') then
    Delete(PathPart, 1, 1);
  {$ENDIF}
  LocalPath := ExpandFileName(PathPart);
  Result := True;
  ErrMsg := '';
end;

function ValidateBrowserReadFileUrl(const Url, WorkspaceRoot: string;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  LocalPath, WsFolder: string;
begin
  ErrKind := brekAccessDenied;
  ErrMsg := '';
  WsFolder := Trim(WorkspaceRoot);
  if WsFolder = '' then
  begin
    ErrMsg := 'file URLs require an active workspace';
    Exit(False);
  end;
  WsFolder := ExpandFileName(WsFolder);
  if not FileUrlToLocalPath(Url, LocalPath, ErrMsg) then
  begin
    if ErrMsg = '' then
      ErrMsg := 'Invalid file URL';
    ErrKind := brekInvalidUrl;
    Exit(False);
  end;
  try
    LocalPath := ExcludeTrailingPathDelimiter(ExpandFileName(LocalPath));
  except
    on E: Exception do
    begin
      ErrKind := brekInvalidUrl;
      ErrMsg := E.Message;
      Exit(False);
    end;
  end;
  if not BrowserFilePathIsInsideWorkspace(WsFolder, LocalPath) then
  begin
    ErrMsg := 'file URL is outside the active workspace';
    Exit(False);
  end;
  if not (FileExists(LocalPath) or DirectoryExists(LocalPath)) then
  begin
    ErrKind := brekInvalidUrl;
    ErrMsg := 'Path does not exist';
    Exit(False);
  end;
  ErrKind := brekNone;
  Result := True;
end;

function ValidateBrowserReadRequestUrl(const Url: string; AllowLocalhost: Boolean;
  const WorkspaceRoot: string; out ErrKind: TBrowserReadErrorKind;
  out ErrMsg: string): Boolean;
var
  Parsed: TWebFetchUrl;
  WfKind: TWebFetchErrorKind;
  ConnectIP: string;
  LHost: string;
  TrimUrl: string;
begin
  ErrKind := brekNone;
  ErrMsg := '';
  TrimUrl := Trim(Url);
  if SameText(Copy(TrimUrl, 1, 7), 'file://') then
    Exit(ValidateBrowserReadFileUrl(TrimUrl, WorkspaceRoot, ErrKind, ErrMsg));
  if not ParseWebFetchUrl(Url, Parsed, WfKind, ErrMsg) then
  begin
    ErrKind := MapWebFetchError(WfKind);
    if ErrKind = brekNone then
      ErrKind := brekInvalidUrl;
    Exit(False);
  end;
  if (Parsed.Scheme <> 'http') and (Parsed.Scheme <> 'https') then
  begin
    ErrKind := brekAccessDenied;
    ErrMsg := 'Only http and https URLs are allowed';
    Exit(False);
  end;
  LHost := LowerCase(Parsed.Host);
  if AllowLocalhost and ((LHost = 'localhost') or (LHost = '127.0.0.1') or
     (LHost = '::1') or (LHost = '[::1]')) then
    Exit(True);
  if not ValidateWebFetchTarget(Parsed, WfKind, ErrMsg) then
  begin
    ErrKind := MapWebFetchError(WfKind);
    Exit(False);
  end;
  if not SelectConnectAddress(Parsed, ConnectIP, WfKind, ErrMsg) then
  begin
    ErrKind := MapWebFetchError(WfKind);
    Exit(False);
  end;
  Result := True;
end;

function ValidateBrowserReadUrl(const Url: string; AllowLocalhost: Boolean;
  const WorkspaceRoot: string; out ErrKind: TBrowserReadErrorKind;
  out ErrMsg: string): Boolean;
begin
  Result := ValidateBrowserReadRequestUrl(Url, AllowLocalhost, WorkspaceRoot,
    ErrKind, ErrMsg);
end;

end.
