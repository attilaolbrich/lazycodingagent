unit uToolGlob;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAppTypes, uAgentTypes, uAgentToolBase;

type
  TToolGlob = class(TAgentTool)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

implementation

uses
  uToolDirListing;

constructor TToolGlob.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  AllowedModes := [wmAsk, wmPlan, wmAgent];
  MutatesFiles := False;
end;

function TToolGlob.GetDefinition: TToolDef;
begin
  Result.Name := 'glob';
  Result.Description := 'Find files by project-relative wildcard pattern (*, ?, **), sorted and capped at 500.';
  SetLength(Result.Params, 3);
  Result.Params[0].Name := 'pattern';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Glob pattern such as src/**/*';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'path';
  Result.Params[1].ParamType := 'string';
  Result.Params[1].Description := 'Search root directory.';
  Result.Params[1].Required := False;
  Result.Params[2].Name := 'include_hidden';
  Result.Params[2].ParamType := 'boolean';
  Result.Params[2].Description := 'Include hidden files.';
  Result.Params[2].Required := False;
end;

function TToolGlob.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Json: string;
begin
  try
    Json := DirectoryListingJson(Args, True);
  except
    on E: Exception do
      Json := ToolError(E.Message);
  end;
  Result := ToolResultFromJson(Json);
end;

end.
