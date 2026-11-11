unit uToolEditFile;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAppTypes, uAgentTypes, uAgentToolBase, uToolApplyPatch;

type
  TToolEditFile = class(TAgentTool)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

implementation

constructor TToolEditFile.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  AllowedModes := [wmAgent];
  MutatesFiles := True;
  Advertised := True;
end;

function TToolEditFile.GetDefinition: TToolDef;
begin
  Result.Name := 'edit_file';
  Result.Description := 'Replace exactly one occurrence of old_text in a text file.';
  SetLength(Result.Params, 3);
  Result.Params[0].Name := 'path';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'File path.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'old_text';
  Result.Params[1].ParamType := 'string';
  Result.Params[1].Description := 'Exact text to replace once.';
  Result.Params[1].Required := True;
  Result.Params[2].Name := 'new_text';
  Result.Params[2].ParamType := 'string';
  Result.Params[2].Description := 'Replacement text.';
  Result.Params[2].Required := True;
end;

function TToolEditFile.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Json: string;
begin
  try
    Json := ExecuteEditFileJson(Args);
  except
    on E: Exception do
      Json := ToolError(E.Message);
  end;
  Result := ToolResultFromJson(Json);
end;

end.
