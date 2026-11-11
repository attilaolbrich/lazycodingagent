unit uToolDiagnostics;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAppTypes, uAgentTypes, uAgentToolBase;

type
  TToolDiagnostics = class(TAgentTool)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

implementation

uses
  uAgentToolPaths, uToolProcessCore, uBuildTargetResolver, uDiagnosticParse, DateUtils;

constructor TToolDiagnostics.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  AllowedModes := [wmAsk, wmPlan, wmAgent];
  MutatesFiles := False;
end;

function TToolDiagnostics.GetDefinition: TToolDef;
begin
  Result.Name := 'diagnostics';
  Result.Description := 'Read cached compiler/linter diagnostics for the workspace; in Agent mode, run a build or check for an explicit target file or project manifest and refresh the cache.';
  SetLength(Result.Params, 4);
  Result.Params[0].Name := 'action';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'read or build.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'target';
  Result.Params[1].ParamType := 'string';
  Result.Params[1].Description := 'Project file, manifest directory, or source file to build (optional when command is set).';
  Result.Params[1].Required := False;
  Result.Params[2].Name := 'timeout_ms';
  Result.Params[2].ParamType := 'integer';
  Result.Params[2].Description := 'Build timeout.';
  Result.Params[2].Required := False;
  Result.Params[3].Name := 'command';
  Result.Params[3].ParamType := 'string';
  Result.Params[3].Description := 'Optional shell command to run in the project root instead of auto-detected build.';
  Result.Params[3].Required := False;
end;

function RunBuildInvocation(const Inv: TBuildInvocation; const Cwd: string; TimeoutMS: Integer): TJSONObject;
var
  ProcArgs: TStringList;
begin
  if Inv.UseShell then
  begin
    ProcArgs := TStringList.Create;
    try
      {$IFDEF UNIX}
      ProcArgs.Add('-c');
      ProcArgs.Add(Inv.ShellCommand);
      Result := RunToolProcess('/bin/sh', ProcArgs, Cwd, TimeoutMS, True);
      {$ELSE}
      ProcArgs.Add('/S');
      ProcArgs.Add('/C');
      ProcArgs.Add(Inv.ShellCommand);
      Result := RunToolProcess('cmd.exe', ProcArgs, Cwd, TimeoutMS, True);
      {$ENDIF}
    finally
      ProcArgs.Free;
    end;
  end
  else
    Result := RunToolProcess(Inv.Executable, Inv.Args, Cwd, TimeoutMS, True);
end;

function TToolDiagnostics.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Action, Target, Command, Text, Json, RunnerLabel, BuildCwd: string;
  O, D: TJSONObject;
  Messages: TJSONArray;
  Session: TAgentToolSession;
  Inv: TBuildInvocation;
  Resolved: Boolean;
begin
  Session := FContext.Session;
  Action := Args.Get('action', 'read');

  if Action = 'read' then
  begin
    if (Session.Diagnostics.Count = 0) or
       (Session.Diagnostics.Get('project_root', '') <> FContext.WorkspaceRoot) then
      Json := '{"status":"unavailable","message":"No compiler diagnostics for the active project yet."}'
    else
      Json := Session.Diagnostics.AsJSON;
    Result := ToolResultFromJson(Json);
    Exit;
  end;

  if Action <> 'build' then
  begin
    Result := ToolResultFromJson(ToolError('action must be read or build'));
    Exit;
  end;
  if FContext.Mode <> wmAgent then
  begin
    Result := ToolResultFromJson(ToolError('Diagnostic builds require Agent mode'));
    Exit;
  end;

  Target := Args.Get('target', '');
  Command := Args.Get('command', '');
  if (Trim(Target) = '') and (Trim(Command) = '') then
  begin
    Result := ToolResultFromJson(ToolError('Build requires target and/or command'));
    Exit;
  end;

  FillChar(Inv, SizeOf(Inv), 0);
  try
    try
    if Trim(Command) <> '' then
    begin
      if not ResolveBuildInvocationFromCommand(Command, Inv) then
        raise Exception.Create('command must not be empty');
      RunnerLabel := Inv.RunnerLabel;
    end
    else
    begin
      if Target <> '' then
        Target := ResolveProjectPath(Target, paRead);
      if (Target <> '') and not (FileExists(Target) or DirectoryExists(Target)) then
        raise Exception.Create('Build target does not exist');
      Resolved := ResolveBuildInvocation(FContext.WorkspaceRoot, Target, Inv);
      if not Resolved then
        raise Exception.Create('Could not resolve build for target');
      RunnerLabel := Inv.RunnerLabel;
    end;

    BuildCwd := FContext.WorkspaceRoot;
    if Inv.WorkingDirectory <> '' then
      BuildCwd := Inv.WorkingDirectory;
    try
      O := RunBuildInvocation(Inv, BuildCwd, Args.Get('timeout_ms', 120000));
    except
      on E: Exception do
        raise Exception.Create('Cannot start build tool "' + RunnerLabel +
          '"; ensure it is installed and available on PATH. Process error: ' + E.Message);
    end;
    try
      O.Add('project_root', FContext.WorkspaceRoot);
      if Inv.ResolvedTarget <> '' then
        O.Add('target', Inv.ResolvedTarget)
      else if Target <> '' then
        O.Add('target', Target)
      else if Inv.ShellCommand <> '' then
        O.Add('target', Inv.ShellCommand);
      O.Add('runner', RunnerLabel);
      O.Add('compiler', RunnerLabel);
      O.Add('timestamp', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', LocalTimeToUniversal(Now)));
      O.Add('refresh_project', True);
      Messages := TJSONArray.Create;
      O.Add('messages', Messages);
      Text := O.Get('stdout', '') + LineEnding + O.Get('stderr', '');
      ParseCompilerOutput(Text, Messages);
      if O.Get('timed_out', False) or O.Get('cancelled', False) then
        O.Add('status', 'incomplete')
      else if O.Get('exit_code', 0) = 0 then
        O.Add('status', 'success')
      else
        O.Add('status', 'failed');
      D := O.Clone as TJSONObject;
      Session.Diagnostics.Free;
      Session.Diagnostics := D;
      Json := O.AsJSON;
    finally
      O.Free;
    end;
    except
      on E: Exception do
        Json := ToolError(E.Message);
    end;
  finally
    FreeBuildInvocation(Inv);
  end;
  Result := ToolResultFromJson(Json);
end;

end.
