unit uToolRunProcess;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAppTypes, uAgentTypes, uAgentToolBase;

type
  TToolRunProcess = class(TAgentTool)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function MatchesName(const AName: string): Boolean; override;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

implementation

uses
  uAgentToolPaths, uToolProcessCore;

constructor TToolRunProcess.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  FAliases := 'terminal;run_process';
  AllowedModes := [wmAgent];
  MutatesFiles := True;
end;

function TToolRunProcess.MatchesName(const AName: string): Boolean;
begin
  Result := inherited MatchesName(AName);
end;

function TToolRunProcess.GetDefinition: TToolDef;
begin
  Result.Name := 'shell';
  {$IFDEF UNIX}
  Result.Description := 'Run a command via /bin/sh -c in the project. Default timeout 120000ms, maximum 600000ms.';
  {$ELSE}
  Result.Description := 'Run a command via cmd.exe /C in the project. Default timeout 120000ms, maximum 600000ms.';
  {$ENDIF}
  SetLength(Result.Params, 3);
  Result.Params[0].Name := 'command';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Shell command to run.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'cwd';
  Result.Params[1].ParamType := 'string';
  Result.Params[1].Description := 'Working directory (default: project root).';
  Result.Params[1].Required := False;
  Result.Params[2].Name := 'timeout_ms';
  Result.Params[2].ParamType := 'integer';
  Result.Params[2].Description := 'Timeout in milliseconds (1..600000).';
  Result.Params[2].Required := False;
end;

function TToolRunProcess.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Command, Cwd, Json: string;
  ProcArgs: TStringList;
  O: TJSONObject;
begin
  Command := Args.Get('command', '');
  if Trim(Command) = '' then
  begin
    Result := ToolResultFromJson(ToolError('command must not be empty'));
    Exit;
  end;

  try
    Cwd := ResolveProjectPath(Args.Get('cwd', '.'), paWrite);
    ProcArgs := TStringList.Create;
    try
      {$IFDEF UNIX}
      ProcArgs.Add('-c');
      {$ELSE}
      ProcArgs.Add('/S');
      ProcArgs.Add('/C');
      {$ENDIF}
      ProcArgs.Add(Command);
      {$IFDEF UNIX}
      O := RunToolProcess('/bin/sh', ProcArgs, Cwd, Args.Get('timeout_ms', 120000), True);
      {$ELSE}
      O := RunToolProcess('cmd.exe', ProcArgs, Cwd, Args.Get('timeout_ms', 120000), True);
      {$ENDIF}
      try
        O.Add('refresh_project', True);
        Json := O.AsJSON;
      finally
        O.Free;
      end;
    finally
      ProcArgs.Free;
    end;
  except
    on E: Exception do
      Json := ToolError(E.Message);
  end;
  Result := ToolResultFromJson(Json);
end;

end.
