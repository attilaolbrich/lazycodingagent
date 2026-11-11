unit uBuildTargetResolver;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBuildInvocation = record
    Executable: string;
    Args: TStringList;
    RunnerLabel: string;
    ResolvedTarget: string;
    UseShell: Boolean;
    ShellCommand: string;
    WorkingDirectory: string;
  end;

function ResolveBuildInvocation(const WorkspaceRoot, TargetPath: string;
  out Inv: TBuildInvocation): Boolean;
function ResolveBuildInvocationFromCommand(const Command: string;
  out Inv: TBuildInvocation): Boolean;
procedure FreeBuildInvocation(var Inv: TBuildInvocation);

implementation

uses
  fpjson, jsonparser;

function ReadFileText(const Path: string): string;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.LoadFromFile(Path);
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

function JsonObjectHasScript(const PackageJsonPath, ScriptName: string): Boolean;
var
  Root: TJSONData;
  Scripts: TJSONData;
begin
  Result := False;
  if not FileExists(PackageJsonPath) then Exit;
  try
    Root := GetJSON(ReadFileText(PackageJsonPath));
    try
      if not (Root is TJSONObject) then Exit;
      Scripts := TJSONObject(Root).Find('scripts');
      if not (Scripts is TJSONObject) then Exit;
      Result := TJSONObject(Scripts).Find(ScriptName) <> nil;
    finally
      Root.Free;
    end;
  except
    Result := False;
  end;
end;

function DirForTarget(const TargetPath: string): string;
begin
  if DirectoryExists(TargetPath) then
    Result := IncludeTrailingPathDelimiter(TargetPath)
  else
    Result := IncludeTrailingPathDelimiter(ExtractFileDir(TargetPath));
end;

function MarkerDir(const WorkspaceRoot, TargetPath: string): string;
begin
  if TargetPath <> '' then
    Result := DirForTarget(TargetPath)
  else
    Result := IncludeTrailingPathDelimiter(WorkspaceRoot);
end;

procedure SetDirect(var Inv: TBuildInvocation; const Exe, Runner, Target: string;
  const ExtraArgs: array of string);
var
  I: Integer;
begin
  Inv.UseShell := False;
  Inv.ShellCommand := '';
  Inv.Executable := Exe;
  Inv.RunnerLabel := Runner;
  Inv.ResolvedTarget := Target;
  Inv.Args.Clear;
  for I := Low(ExtraArgs) to High(ExtraArgs) do
    Inv.Args.Add(ExtraArgs[I]);
end;

function TryMarkerBuild(const SearchDir, TargetPath: string;
  var Inv: TBuildInvocation): Boolean;
var
  RelTarget: string;
begin
  Result := False;
  if FileExists(SearchDir + 'Cargo.toml') then
  begin
    SetDirect(Inv, 'cargo', 'cargo', TargetPath, ['build']);
    Exit(True);
  end;
  if FileExists(SearchDir + 'go.mod') then
  begin
    SetDirect(Inv, 'go', 'go', TargetPath, ['build', './...']);
    Exit(True);
  end;
  if FileExists(SearchDir + 'package.json') then
  begin
    if JsonObjectHasScript(SearchDir + 'package.json', 'build') then
    begin
      if FileExists(SearchDir + 'pnpm-lock.yaml') then
        SetDirect(Inv, 'pnpm', 'pnpm', TargetPath, ['run', 'build'])
      else if FileExists(SearchDir + 'yarn.lock') then
        SetDirect(Inv, 'yarn', 'yarn', TargetPath, ['run', 'build'])
      else
        SetDirect(Inv, 'npm', 'npm', TargetPath, ['run', 'build']);
      Exit(True);
    end;
    if JsonObjectHasScript(SearchDir + 'package.json', 'test') then
    begin
      SetDirect(Inv, 'npm', 'npm', TargetPath, ['test']);
      Exit(True);
    end;
    raise Exception.Create('package.json found but no build or test script; pass command explicitly');
  end;
  if FileExists(SearchDir + 'pyproject.toml') or FileExists(SearchDir + 'setup.py') then
  begin
    RelTarget := '.';
    if TargetPath <> '' then
      RelTarget := TargetPath;
    {$IFDEF UNIX}
    SetDirect(Inv, 'python3', 'python3', TargetPath, ['-m', 'compileall', '-q', RelTarget]);
    {$ELSE}
    SetDirect(Inv, 'python', 'python', TargetPath, ['-m', 'compileall', '-q', RelTarget]);
    {$ENDIF}
    Exit(True);
  end;
  if FileExists(SearchDir + 'CMakeLists.txt') then
  begin
    if DirectoryExists(SearchDir + 'build') then
      SetDirect(Inv, 'cmake', 'cmake', TargetPath, ['--build', 'build'])
    else
      raise Exception.Create('CMake project requires a build/ directory; configure with cmake or pass command explicitly');
    Exit(True);
  end;
  if FileExists(SearchDir + 'Makefile') then
  begin
    SetDirect(Inv, 'make', 'make', TargetPath, []);
    Exit(True);
  end;
  if FileExists(SearchDir + 'build.gradle') or FileExists(SearchDir + 'build.gradle.kts') then
  begin
    SetDirect(Inv, 'gradle', 'gradle', TargetPath, ['build']);
    Exit(True);
  end;
  if FileExists(SearchDir + 'pom.xml') then
  begin
    SetDirect(Inv, 'mvn', 'mvn', TargetPath, ['-q', 'test']);
    Exit(True);
  end;
end;

function TryExtensionBuild(const TargetPath: string; var Inv: TBuildInvocation): Boolean;
var
  Ext: string;
begin
  Result := False;
  if (TargetPath = '') or DirectoryExists(TargetPath) then Exit;
  Ext := LowerCase(ExtractFileExt(TargetPath));
  if (Ext = '.lpi') or (Ext = '.lpk') then
  begin
    SetDirect(Inv, 'lazbuild', 'lazbuild', TargetPath, [TargetPath]);
    Exit(True);
  end;
  if (Ext = '.pas') or (Ext = '.lpr') then
  begin
    SetDirect(Inv, 'fpc', 'fpc', TargetPath, [TargetPath]);
    Exit(True);
  end;
  if (Ext = '.sln') or (Ext = '.csproj') then
  begin
    SetDirect(Inv, 'dotnet', 'dotnet', TargetPath, ['build', TargetPath]);
    Exit(True);
  end;
end;

function TryGlobProjectFile(const SearchDir, Pattern, Exe, Runner: string;
  var Inv: TBuildInvocation): Boolean;
var
  SR: TSearchRec;
  Found: string;
begin
  Result := False;
  if FindFirst(SearchDir + Pattern, faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Attr and faDirectory) = 0 then
        begin
          Found := SearchDir + SR.Name;
          SetDirect(Inv, Exe, Runner, Found, [Found]);
          Exit(True);
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

function ResolveBuildInvocation(const WorkspaceRoot, TargetPath: string;
  out Inv: TBuildInvocation): Boolean;
var
  SearchDir: string;
begin
  Inv.Executable := '';
  Inv.RunnerLabel := '';
  Inv.ResolvedTarget := TargetPath;
  Inv.UseShell := False;
  Inv.ShellCommand := '';
  Inv.WorkingDirectory := '';
  Inv.Args := TStringList.Create;

  SearchDir := MarkerDir(WorkspaceRoot, TargetPath);

  if TryExtensionBuild(TargetPath, Inv) then
    Exit(True);

  if TryMarkerBuild(SearchDir, TargetPath, Inv) then
  begin
    Inv.WorkingDirectory := ExcludeTrailingPathDelimiter(SearchDir);
    Exit(True);
  end;

  if TargetPath = '' then
  begin
    if TryGlobProjectFile(SearchDir, '*.sln', 'dotnet', 'dotnet', Inv) then
    begin
      Inv.WorkingDirectory := ExcludeTrailingPathDelimiter(SearchDir);
      Exit(True);
    end;
    if TryGlobProjectFile(SearchDir, '*.csproj', 'dotnet', 'dotnet', Inv) then
    begin
      Inv.WorkingDirectory := ExcludeTrailingPathDelimiter(SearchDir);
      Exit(True);
    end;
    if TryGlobProjectFile(SearchDir, '*.lpi', 'lazbuild', 'lazbuild', Inv) then
    begin
      Inv.WorkingDirectory := ExcludeTrailingPathDelimiter(SearchDir);
      Exit(True);
    end;
  end;

  if (TargetPath <> '') and FileExists(TargetPath) then
    raise Exception.Create('Unsupported build target "' + ExtractFileName(TargetPath) +
      '"; use a known project manifest, supported source extension, or pass command explicitly');

  raise Exception.Create('Could not detect a build for this workspace; pass target and/or command explicitly. ' +
    'Supported markers include Cargo.toml, go.mod, package.json, pyproject.toml, CMakeLists.txt, Makefile, and common project files.');
end;

function ResolveBuildInvocationFromCommand(const Command: string;
  out Inv: TBuildInvocation): Boolean;
begin
  Inv.Executable := '';
  Inv.RunnerLabel := 'shell';
  Inv.ResolvedTarget := '';
  Inv.UseShell := True;
  Inv.ShellCommand := Command;
  Inv.WorkingDirectory := '';
  Inv.Args := nil;
  Result := Trim(Command) <> '';
end;

procedure FreeBuildInvocation(var Inv: TBuildInvocation);
begin
  if Assigned(Inv.Args) then
  begin
    Inv.Args.Free;
    Inv.Args := nil;
  end;
end;

end.
