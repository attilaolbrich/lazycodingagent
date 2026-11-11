unit uToolReadFile;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAppTypes, uAgentTypes, uAgentToolBase;

type
  TToolReadFile = class(TAgentTool)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

implementation

uses
  uAgentToolPaths;

constructor TToolReadFile.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  AllowedModes := [wmAsk, wmPlan, wmAgent];
  MutatesFiles := False;
end;

function TToolReadFile.GetDefinition: TToolDef;
begin
  Result.Name := 'read_file';
  Result.Description := 'Read the text contents of a file with optional line offset and limit (max 2000 lines, 16 MiB file cap).';
  SetLength(Result.Params, 3);
  Result.Params[0].Name := 'path';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Relative or absolute file path to read.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'offset';
  Result.Params[1].ParamType := 'integer';
  Result.Params[1].Description := 'Line number to start reading from (1-indexed).';
  Result.Params[1].Required := False;
  Result.Params[2].Name := 'limit';
  Result.Params[2].ParamType := 'integer';
  Result.Params[2].Description := 'Maximum number of lines to read (default: 2000).';
  Result.Params[2].Required := False;
end;

function TToolReadFile.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  FilePath, ResolvedPath, FormattedText: string;
  Offset, Limit, StartIdx, EndIdx, I: Integer;
  Lines, FormattedLines: TStringList;
  OutJSON: TJSONObject;
  Json: string;
begin
  FilePath := Args.Get('path', '');
  Offset := Args.Get('offset', 1);
  Limit := Args.Get('limit', 2000);

  if FilePath = '' then
  begin
    Result := ToolResultFromJson(ToolError('Missing required parameter: path'));
    Exit;
  end;

  if (Offset < 1) or (Limit < 1) or (Limit > 2000) then
  begin
    Result := ToolResultFromJson(ToolError('offset must be positive and limit must be 1..2000'));
    Exit;
  end;

  try
    ResolvedPath := ResolveProjectPath(FilePath, paRead);
    if not FileExists(ResolvedPath) then
    begin
      Result := ToolResultFromJson(ToolError('File not found: ' + ResolvedPath));
      Exit;
    end;

    Lines := TStringList.Create;
    try
      Lines.Text := ReadTextBytes(ResolvedPath);
      StartIdx := Offset - 1;
      if (StartIdx >= Lines.Count) and ((Lines.Count > 0) or (Offset <> 1)) then
      begin
        Result := ToolResultFromJson(ToolError(Format(
          'Offset line out of range; total_lines: %d', [Lines.Count])));
        Exit;
      end;
      EndIdx := StartIdx + Limit;
      if EndIdx > Lines.Count then EndIdx := Lines.Count;

      FormattedLines := TStringList.Create;
      try
        for I := StartIdx to EndIdx - 1 do
          FormattedLines.Add(IntToStr(I + 1) + '|' + Lines[I]);
        FormattedText := FormattedLines.Text;
      finally
        FormattedLines.Free;
      end;

      OutJSON := TJSONObject.Create;
      try
        OutJSON.Add('path', ResolvedPath);
        OutJSON.Add('offset', Offset);
        OutJSON.Add('lines_returned', EndIdx - StartIdx);
        OutJSON.Add('total_lines', Lines.Count);
        OutJSON.Add('content', FormattedText);
        Json := OutJSON.AsJSON;
      finally
        OutJSON.Free;
      end;
    finally
      Lines.Free;
    end;
  except
    on E: Exception do
      Json := ToolError('Failed to read file: ' + E.Message);
  end;
  Result := ToolResultFromJson(Json);
end;

end.
