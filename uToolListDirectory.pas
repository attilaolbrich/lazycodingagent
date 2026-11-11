unit uToolListDirectory;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAppTypes, uAgentTypes, uAgentToolBase;

type
  TToolListDirectory = class(TAgentTool)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

implementation

uses
  uToolDirListing;

constructor TToolListDirectory.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  AllowedModes := [wmAsk, wmPlan, wmAgent];
  MutatesFiles := False;
end;

function TToolListDirectory.GetDefinition: TToolDef;
begin
  Result.Name := 'list_directory';
  Result.Description := 'List immediate file and directory entries, sorted and capped at 500.';
  SetLength(Result.Params, 2);
  Result.Params[0].Name := 'path';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Directory path (default: project root).';
  Result.Params[0].Required := False;
  Result.Params[1].Name := 'include_hidden';
  Result.Params[1].ParamType := 'boolean';
  Result.Params[1].Description := 'Whether to include hidden files.';
  Result.Params[1].Required := False;
end;

function TToolListDirectory.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Json: string;
begin
  try
    Json := DirectoryListingJson(Args, False);
  except
    on E: Exception do
      Json := ToolError(E.Message);
  end;
  Result := ToolResultFromJson(Json);
end;

end.
