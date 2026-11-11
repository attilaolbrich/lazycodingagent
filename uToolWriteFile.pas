unit uToolWriteFile;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAppTypes, uAgentTypes, uAgentToolBase;

type
  TToolWriteFile = class(TAgentTool)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

implementation

uses
  uAgentToolPaths;

constructor TToolWriteFile.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  AllowedModes := [wmAgent];
  MutatesFiles := True;
end;

function TToolWriteFile.GetDefinition: TToolDef;
begin
  Result.Name := 'write_file';
  Result.Description := 'Write or overwrite complete content to a file. Automatically creates directories.';
  SetLength(Result.Params, 2);
  Result.Params[0].Name := 'path';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Relative or absolute file path to write.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'content';
  Result.Params[1].ParamType := 'string';
  Result.Params[1].Description := 'Complete text content to write to the file.';
  Result.Params[1].Required := True;
end;

function TToolWriteFile.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  FilePath, ResolvedPath, Content, Json: string;
  OutJSON: TJSONObject;
  Changed: TJSONArray;
begin
  FilePath := Args.Get('path', '');
  if Args.Find('content') = nil then
  begin
    Result := ToolResultFromJson(ToolError('Missing required parameter: content'));
    Exit;
  end;
  Content := Args.Get('content', '');

  if FilePath = '' then
  begin
    Result := ToolResultFromJson(ToolError('Missing required parameter: path'));
    Exit;
  end;

  try
    ResolvedPath := ResolveProjectPath(FilePath, paWrite);
    WriteBytes(ResolvedPath, UTF8Encode(Content));
    OutJSON := TJSONObject.Create;
    try
      OutJSON.Add('status', 'success');
      OutJSON.Add('path', ResolvedPath);
      OutJSON.Add('bytes_written', Length(Content));
      Changed := TJSONArray.Create;
      Changed.Add(ResolvedPath);
      OutJSON.Add('changed_paths', Changed);
      OutJSON.Add('tracking_warning', NotifyToolFileChanged(ResolvedPath));
      Json := OutJSON.AsJSON;
    finally
      OutJSON.Free;
    end;
  except
    on E: Exception do
      Json := ToolError('Failed to write file: ' + E.Message);
  end;
  Result := ToolResultFromJson(Json);
end;

end.
