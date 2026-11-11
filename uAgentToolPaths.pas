unit uAgentToolPaths;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson;

type
  TPathAccess = (paRead, paWrite);

function ResolveProjectPath(const Path: string; AAccess: TPathAccess = paWrite): string;
function ResolveProjectPathInWorkspace(const Path: string): string;
function CanonicalFilePath(const Path: string): string;
function PathIsInsideWorkspace(const WorkspaceFolder, Candidate: string): Boolean;
function CanonicalWorkspaceRoot: string;
function ReadTextBytes(const Path: string): RawByteString;
procedure WriteBytes(const Path: string; const Content: RawByteString);
function IsPathLink(const Path: string): Boolean;
function SkipGenerated(const Name: string): Boolean;
function GlobMatches(const Pattern, Path: string): Boolean;
procedure CollectFiles(const Root, Sub: string; Hidden: Boolean; Files: TStrings; Depth: Integer = 0);
function SuccessFile(const Path: string; Bytes: Int64): string;

implementation

uses
  {$IFDEF UNIX}BaseUnix{$ELSE}Windows{$ENDIF}, uAgentToolBase;

const
  TextFileMaxBytes = 16 * 1024 * 1024;

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

function GlobCharEqual(A, B: Char): Boolean;
begin
  if A = B then Exit(True);
  if B = '/' then Exit(False);
  {$IFDEF WINDOWS}
  if SameText(A, B) then Exit(True);
  if (A = '\') and (B = '/') then Exit(True);
  if (A = '/') and (B = '\') then Exit(True);
  {$ELSE}
  {$IFDEF DARWIN}
  if SameText(A, B) then Exit(True);
  {$ENDIF}
  {$ENDIF}
  Result := False;
end;

{$IFDEF WINDOWS}
const
  FILE_NAME_NORMALIZED = 0;

function WinGetFinalPathNameByHandle(hFile: THandle; lpszFilePath: PWideChar;
  cchFilePath: DWORD; dwFlags: DWORD): DWORD; stdcall;
  external 'kernel32.dll' name 'GetFinalPathNameByHandleW';

function WinGetFinalPath(const Path: string): string;
var
  H: THandle;
  Buf: array[0..32767] of WideChar;
  N: DWORD;
  S: string;
begin
  Result := '';
  H := CreateFile(PChar(Path), 0, FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
    nil, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, 0);
  if H = INVALID_HANDLE_VALUE then Exit;
  try
    N := WinGetFinalPathNameByHandle(H, Buf, Length(Buf), FILE_NAME_NORMALIZED);
    if N = 0 then Exit;
    SetString(S, Buf, N);
    if Copy(S, 1, 4) = '\\?\' then
      Result := Copy(S, 5, MaxInt)
    else
      Result := S;
  finally
    CloseHandle(H);
  end;
end;

function WinPathIsDirectory(const Path: string): Boolean;
var
  Attr: DWORD;
begin
  Attr := GetFileAttributes(PChar(Path));
  Result := (Attr <> INVALID_FILE_ATTRIBUTES) and ((Attr and FILE_ATTRIBUTE_DIRECTORY) <> 0);
end;

procedure AssertRegularFileTarget(const Path: string; ForWrite: Boolean);
var
  Attr: DWORD;
begin
  Attr := GetFileAttributes(PChar(Path));
  if Attr = INVALID_FILE_ATTRIBUTES then Exit;
  if (Attr and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
    raise Exception.Create('Not a regular file: ' + Path);
  if ForWrite and ((Attr and FILE_ATTRIBUTE_DEVICE) <> 0) then
    raise Exception.Create('Not a regular file: ' + Path);
end;
{$ENDIF}

function JoinPathSegments(const Prefix, Suffix: string): string;
begin
  if Suffix = '' then Exit(Prefix);
  if Suffix[1] = '/' then Exit(Suffix);
  Result := IncludeTrailingPathDelimiter(Prefix) + Suffix;
end;

function RemainingPathParts(Parts: TStringList; StartIndex: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := StartIndex to Parts.Count - 1 do
  begin
    if Parts[I] = '' then Continue;
    if Result = '' then Result := Parts[I]
    else Result := Result + DirectorySeparator + Parts[I];
  end;
end;

function CanonicalPath(const Path: string; Depth: Integer): string;
var
  Parts: TStringList;
  I: Integer;
  Cur, Link, Tail, Drive, Remainder, FinalPath: string;
  {$IFDEF WINDOWS}Attr: DWORD;{$ENDIF}
begin
  if Depth > 32 then raise Exception.Create('Too many symbolic links');
  Result := ExpandFileName(Path);
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := DirectorySeparator;
    {$IFDEF UNIX}
    Cur := '/';
    Remainder := Copy(Result, 2, MaxInt);
    {$ELSE}
    Drive := ExtractFileDrive(Result);
    if Drive = '' then raise Exception.Create('Cannot resolve absolute path: ' + Path);
    Cur := IncludeTrailingPathDelimiter(Drive);
    Remainder := Copy(Result, Length(Drive) + 1, MaxInt);
    {$ENDIF}
    Parts.DelimitedText := Remainder;
    for I := 0 to Parts.Count - 1 do
    begin
      if Parts[I] = '' then Continue;
      Cur := IncludeTrailingPathDelimiter(Cur) + Parts[I];
      {$IFDEF UNIX}
      Link := fpReadLink(Cur);
      if Link <> '' then
      begin
        if Link[1] <> '/' then Link := IncludeTrailingPathDelimiter(ExtractFileDir(Cur)) + Link;
        Tail := RemainingPathParts(Parts, I + 1);
        Exit(CanonicalPath(JoinPathSegments(Link, Tail), Depth + 1));
      end;
      {$ELSE}
      Attr := GetFileAttributes(PChar(Cur));
      if (Attr <> INVALID_FILE_ATTRIBUTES) and ((Attr and FILE_ATTRIBUTE_REPARSE_POINT) <> 0) then
      begin
        FinalPath := WinGetFinalPath(Cur);
        if FinalPath = '' then raise Exception.Create('Cannot resolve reparse point: ' + Cur);
        Tail := RemainingPathParts(Parts, I + 1);
        Exit(CanonicalPath(JoinPathSegments(FinalPath, Tail), Depth + 1));
      end;
      {$ENDIF}
    end;
    Result := Cur;
  finally
    Parts.Free;
  end;
end;

function CanonicalFilePath(const Path: string): string;
begin
  Result := CanonicalPath(Path, 0);
end;

function PathIsInsideWorkspace(const WorkspaceFolder, Candidate: string): Boolean;
var
  Root, Can, Prefix: string;
begin
  Result := False;
  Root := Trim(WorkspaceFolder);
  if Root = '' then Exit;
  if Trim(Candidate) = '' then Exit;
  Root := ExcludeTrailingPathDelimiter(CanonicalFilePath(ExpandFileName(Root)));
  Can := ExcludeTrailingPathDelimiter(CanonicalFilePath(Candidate));
  Prefix := IncludeTrailingPathDelimiter(Root);
  Result := PathJailPrefixMatches(Root, Prefix, Can);
end;

function CanonicalWorkspaceRoot: string;
var
  C: TAgentToolContext;
begin
  C := CurrentToolContext;
  if not Assigned(C) then raise Exception.Create('Tool context is not active');
  Result := ExcludeTrailingPathDelimiter(CanonicalPath(C.WorkspaceRoot, 0));
end;

function ResolveProjectPathCore(const Path: string; AEnforceWorkspaceJail: Boolean): string;
var
  Root, Candidate, Prefix: string;
  C: TAgentToolContext;
begin
  if Pos(#0, Path) > 0 then raise Exception.Create('Invalid path');
  C := CurrentToolContext;
  if not Assigned(C) then raise Exception.Create('Tool context is not active');
  Root := CanonicalWorkspaceRoot;
  if Path = '' then Candidate := Root
  {$IFDEF UNIX}
  else if Path[1] = '/' then Candidate := Path
  {$ELSE}
  else if ((Length(Path) > 1) and (Path[2] = ':')) or (Copy(Path, 1, 2) = '\\') then Candidate := Path
  {$ENDIF}
  else Candidate := IncludeTrailingPathDelimiter(Root) + Path;
  Result := CanonicalPath(Candidate, 0);
  if SafeToolText(Result) <> Result then raise Exception.Create('Unsupported path encoding');
  if AEnforceWorkspaceJail then
  begin
    Prefix := IncludeTrailingPathDelimiter(Root);
    if not PathJailPrefixMatches(Root, Prefix, Result) then
      raise Exception.Create('Path escapes the active project: ' + Path);
  end;
end;

function ResolveProjectPath(const Path: string; AAccess: TPathAccess): string;
var
  C: TAgentToolContext;
  EnforceJail: Boolean;
begin
  C := CurrentToolContext;
  if not Assigned(C) then raise Exception.Create('Tool context is not active');
  EnforceJail := (AAccess = paWrite) and not C.AllowModifyOutsideWorkspace;
  Result := ResolveProjectPathCore(Path, EnforceJail);
end;

function ResolveProjectPathInWorkspace(const Path: string): string;
begin
  Result := ResolveProjectPathCore(Path, True);
end;

function ReadTextBytes(const Path: string): RawByteString;
var
  S: TFileStream;
  I: Integer;
  {$IFDEF UNIX}Info: Stat;{$ENDIF}
begin
  Result := '';
  {$IFDEF UNIX}
  if (fpStat(Path, Info) <> 0) or not FPS_ISREG(Info.st_mode) then
    raise Exception.Create('Not a regular text file: ' + Path);
  {$ELSE}
  if WinPathIsDirectory(Path) then
    raise Exception.Create('Not a regular text file: ' + Path);
  {$ENDIF}
  S := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
  try
    if S.Size > TextFileMaxBytes then raise Exception.Create('Text file exceeds 16 MiB limit');
    SetLength(Result, S.Size);
    if Length(Result) > 0 then S.ReadBuffer(Result[1], Length(Result));
  finally
    S.Free;
  end;
  if SafeToolText(Result) <> Result then raise Exception.Create('Unsupported text encoding; use UTF-8: ' + Path);
  for I := 1 to Length(Result) do
    if (Result[I] = #0) or ((Ord(Result[I]) < 9) or (Ord(Result[I]) in [14..31])) then
      raise Exception.Create('Unsupported binary or text encoding: ' + Path);
end;

procedure WriteBytes(const Path: string; const Content: RawByteString);
var
  S: TFileStream;
  Resolved, TempPath: string;
  {$IFDEF UNIX}Info: Stat;{$ENDIF}
begin
  Resolved := ResolveProjectPath(Path, paWrite);
  {$IFDEF UNIX}
  if (fpStat(Resolved, Info) = 0) and not FPS_ISREG(Info.st_mode) then
    raise Exception.Create('Not a regular file: ' + Path);
  {$ELSE}
  AssertRegularFileTarget(Resolved, True);
  {$ENDIF}
  if not ForceDirectories(ExtractFileDir(Resolved)) then raise Exception.Create('Cannot create parent directories');
  TempPath := SysUtils.GetTempFileName(ExtractFileDir(Resolved), '.agent-write-');
  try
    S := TFileStream.Create(TempPath, fmCreate);
    try
      if Length(Content) > 0 then S.WriteBuffer(Content[1], Length(Content));
    finally
      S.Free;
    end;
    {$IFDEF UNIX}
    if fpStat(Resolved, Info) = 0 then
      if fpChmod(TempPath, Info.st_mode and &777) <> 0 then
        raise Exception.Create('Cannot preserve file permissions');
    {$ENDIF}
    {$IFDEF WINDOWS}
    if not MoveFileEx(PChar(TempPath), PChar(Resolved), MOVEFILE_REPLACE_EXISTING) then
      raise Exception.Create('Cannot replace ' + Path);
    {$ELSE}
    if not RenameFile(TempPath, Resolved) then
      raise Exception.Create('Cannot replace ' + Path);
    {$ENDIF}
    TempPath := '';
  finally
    if TempPath <> '' then SysUtils.DeleteFile(TempPath);
  end;
end;

function IsPathLink(const Path: string): Boolean;
{$IFDEF UNIX}var Info: Stat;{$ELSE}var Attr: DWORD;{$ENDIF}
begin
  {$IFDEF UNIX}
  Result := (fpLStat(Path, Info) = 0) and FPS_ISLNK(Info.st_mode);
  {$ELSE}
  Attr := GetFileAttributes(PChar(Path));
  Result := (Attr <> INVALID_FILE_ATTRIBUTES) and ((Attr and FILE_ATTRIBUTE_REPARSE_POINT) <> 0);
  {$ENDIF}
end;

function SkipGenerated(const Name: string): Boolean;
begin
  Result := Pos(';' + LowerCase(Name) + ';',
    ';node_modules;backup;lib;units;bin;obj;target;dist;__pycache__;venv;.git;') > 0;
end;

function GlobMatches(const Pattern, Path: string): Boolean;
var
  NormPattern: string;

  function Match(P, S: Integer): Boolean;
  var
    K: Integer;
    Recursive: Boolean;
  begin
    if P > Length(NormPattern) then Exit(S > Length(Path));
    if NormPattern[P] = '*' then
    begin
      Recursive := (P < Length(NormPattern)) and (NormPattern[P + 1] = '*');
      if Recursive then
      begin
        Inc(P);
        if (P < Length(NormPattern)) and (NormPattern[P + 1] = '/') and Match(P + 2, S) then Exit(True);
      end;
      K := S;
      repeat
        if Match(P + 1, K) then Exit(True);
        if K > Length(Path) then Break;
        if not Recursive and (Path[K] = '/') then Break;
        Inc(K);
      until False;
      Exit(False);
    end;
    if S > Length(Path) then Exit(False);
    Result := (GlobCharEqual(NormPattern[P], Path[S]) or
      ((NormPattern[P] = '?') and (Path[S] <> '/'))) and Match(P + 1, S + 1);
  end;

begin
  NormPattern := Pattern;
  {$IFDEF WINDOWS}
  NormPattern := StringReplace(NormPattern, '\', '/', [rfReplaceAll]);
  {$ENDIF}
  Result := Match(1, 1);
end;

procedure CollectFiles(const Root, Sub: string; Hidden: Boolean; Files: TStrings; Depth: Integer);
var
  R: TSearchRec;
  Dir, Rel, Full: string;
begin
  if ToolCancelled then raise Exception.Create('Tool cancelled');
  if Depth > 64 then raise Exception.Create('Directory nesting exceeds 64 levels');
  Dir := IncludeTrailingPathDelimiter(Root) + Sub;
  if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, R) <> 0 then Exit;
  try
    repeat
      if ToolCancelled then raise Exception.Create('Tool cancelled');
      if (R.Name = '.') or (R.Name = '..') then Continue;
      if not Hidden and (R.Name[1] = '.') then Continue;
      Rel := Sub + R.Name;
      Full := IncludeTrailingPathDelimiter(Root) + Rel;
      if IsPathLink(Full) then Continue;
      ResolveProjectPath(Full, paRead);
      if (R.Attr and faDirectory) <> 0 then
      begin
        if not SkipGenerated(R.Name) then
          CollectFiles(Root, Rel + DirectorySeparator, Hidden, Files, Depth + 1);
      end
      else
        Files.Add(StringReplace(Rel, DirectorySeparator, '/', [rfReplaceAll]));
    until FindNext(R) <> 0;
  finally
    SysUtils.FindClose(R);
  end;
end;

function SuccessFile(const Path: string; Bytes: Int64): string;
var
  O: TJSONObject;
  A: TJSONArray;
begin
  O := TJSONObject.Create(['status', 'success', 'path', Path, 'bytes_written', Bytes]);
  A := TJSONArray.Create;
  A.Add(Path);
  O.Add('changed_paths', A);
  try
    Result := O.AsJSON;
  finally
    O.Free;
  end;
end;

end.
