unit uToolGit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAppTypes, uAgentTypes, uAgentToolBase;

type
  TToolGit = class(TAgentTool)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

implementation

uses
  uAgentToolPaths, uToolProcessCore;

constructor TToolGit.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  AllowedModes := [wmAsk, wmPlan, wmAgent];
  MutatesFiles := False;
end;

function TToolGit.GetDefinition: TToolDef;
begin
  Result.Name := 'git';
  Result.Description := 'Inspect Git status, diff, log or show. No mutating operations. limit is 1..100.';
  SetLength(Result.Params, 5);
  Result.Params[0].Name := 'operation';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'One of: status, diff, log, show.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'revision';
  Result.Params[1].ParamType := 'string';
  Result.Params[1].Description := 'Optional revision.';
  Result.Params[1].Required := False;
  Result.Params[2].Name := 'paths';
  Result.Params[2].ParamType := 'array';
  Result.Params[2].Description := 'Optional path filter.';
  Result.Params[2].Required := False;
  Result.Params[3].Name := 'limit';
  Result.Params[3].ParamType := 'integer';
  Result.Params[3].Description := 'Log limit 1..100.';
  Result.Params[3].Required := False;
  Result.Params[4].Name := 'staged';
  Result.Params[4].ParamType := 'boolean';
  Result.Params[4].Description := 'Staged diff for diff operation.';
  Result.Params[4].Required := False;
end;

function TToolGit.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Op, Rev, Json: string;
  Limit: Integer;
  ProcArgs: TStringList;
  Paths: TJSONArray;
  I: Integer;
  O: TJSONObject;
begin
  Op := Args.Get('operation', '');
  Rev := Args.Get('revision', '');
  if not ((Op = 'status') or (Op = 'diff') or (Op = 'log') or (Op = 'show')) then
  begin
    Result := ToolResultFromJson(ToolError('Unsupported Git operation'));
    Exit;
  end;
  if (Rev <> '') and ((Rev[1] = '-') or (Pos(#0, Rev) > 0)) then
  begin
    Result := ToolResultFromJson(ToolError('Invalid Git revision'));
    Exit;
  end;
  Limit := Args.Get('limit', 20);
  if (Limit < 1) or (Limit > 100) then
  begin
    Result := ToolResultFromJson(ToolError('limit must be 1..100'));
    Exit;
  end;

  ProcArgs := TStringList.Create;
  try
    try
      ProcArgs.Add('--no-pager');
      ProcArgs.Add('--no-optional-locks');
      ProcArgs.Add('-c');
      ProcArgs.Add('core.fsmonitor=false');
      ProcArgs.Add(Op);
      if Op = 'status' then ProcArgs.Add('--porcelain=v1');
      if (Op = 'diff') or (Op = 'show') then
      begin
        ProcArgs.Add('--no-ext-diff');
        ProcArgs.Add('--no-textconv');
      end;
      if (Op = 'diff') and Args.Get('staged', False) then ProcArgs.Add('--cached');
      if Op = 'log' then
      begin
        ProcArgs.Add('-n');
        ProcArgs.Add(IntToStr(Limit));
      end;
      if (Op = 'status') and (Rev <> '') then
        raise Exception.Create('status does not accept a revision');
      if Rev <> '' then ProcArgs.Add(Rev);
      ProcArgs.Add('--');
      Paths := Args.Find('paths') as TJSONArray;
      if Assigned(Paths) then
        for I := 0 to Paths.Count - 1 do
        begin
          if Paths[I].JSONType <> jtString then
            raise Exception.Create('paths must contain strings');
          ProcArgs.Add(ResolveProjectPath(Paths.Strings[I], paRead));
        end;
      O := RunToolProcess('git', ProcArgs, CurrentToolContext.WorkspaceRoot, 120000, False, True);
      try
        if O.Get('exit_code', 0) <> 0 then
          O.Add('error', 'Git inspection failed: ' + O.Get('stderr', ''));
        Json := O.AsJSON;
      finally
        O.Free;
      end;
    except
      on E: Exception do
        Json := ToolError('Cannot run Git; ensure git is installed. ' + E.Message);
    end;
  finally
    ProcArgs.Free;
  end;
  Result := ToolResultFromJson(Json);
end;

end.
