unit uToolCreatePlanFile;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAppTypes, uAgentTypes, uAgentToolBase;

type
  TToolCreatePlanFile = class(TAgentTool)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

implementation

uses
  uAgentToolPaths, DateUtils;

constructor TToolCreatePlanFile.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  AllowedModes := [wmPlan, wmAgent];
  MutatesFiles := True;
end;

function TToolCreatePlanFile.GetDefinition: TToolDef;
begin
  Result.Name := 'create_plan_file';
  Result.Description := 'Save a completed implementation plan as a timestamped Markdown file under the project .plan directory.';
  SetLength(Result.Params, 1);
  Result.Params[0].Name := 'content';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Complete implementation plan in Markdown.';
  Result.Params[0].Required := True;
end;

function TToolCreatePlanFile.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Content, PlanDir, PlanPath, BaseName, Json: string;
  Suffix: Integer;
  Stream: TFileStream;
  OutJSON: TJSONObject;
begin
  Content := Args.Get('content', '');
  if Trim(Content) = '' then
  begin
    Result := ToolResultFromJson(ToolError('Plan content is required'));
    Exit;
  end;
  if Length(Content) > 1024 * 1024 then
  begin
    Result := ToolResultFromJson(ToolError('Plan content exceeds 1 MiB limit'));
    Exit;
  end;

  try
    PlanDir := IncludeTrailingPathDelimiter(ResolveProjectPathInWorkspace('')) + '.plan';
    if IsPathLink(PlanDir) then
      raise Exception.Create('Project .plan directory must not be a symbolic link or reparse point');
    PlanDir := ResolveProjectPathInWorkspace(PlanDir);
    if not ForceDirectories(PlanDir) then
      raise Exception.Create('Could not create project .plan directory');

    BaseName := 'plan-' + FormatDateTime('yyyymmdd-hhnnss', Now);
    PlanPath := IncludeTrailingPathDelimiter(PlanDir) + BaseName + '.md';
    Suffix := 1;
    while FileExists(PlanPath) do
    begin
      PlanPath := IncludeTrailingPathDelimiter(PlanDir) + BaseName + '-' + IntToStr(Suffix) + '.md';
      Inc(Suffix);
    end;
    ResolveProjectPathInWorkspace(PlanPath);
    Stream := TFileStream.Create(PlanPath, fmCreate);
    try
      if Length(Content) > 0 then
        Stream.WriteBuffer(Content[1], Length(Content));
    finally
      Stream.Free;
    end;
    OutJSON := TJSONObject.Create;
    try
      OutJSON.Add('status', 'success');
      OutJSON.Add('path', PlanPath);
      OutJSON.Add('content', Content);
      Json := OutJSON.AsJSON;
    finally
      OutJSON.Free;
    end;
  except
    on E: Exception do
      Json := ToolError('Could not save plan: ' + E.Message);
  end;
  Result := ToolResultFromJson(Json);
end;

end.
