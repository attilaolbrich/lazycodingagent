unit uMcpJson;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uAgentTypes, uMcpTypes;

type
  TToolParamDefArray = array of TToolParamDef;

function ParseMcpToolsListResponse(const AJson: string; out ATools: TMcpToolInfoArray;
  out ErrMsg: string): Boolean;
function McpToolInfoToToolDef(const AInfo: TMcpToolInfo): TToolDef;
function McpToolsToBoundTools(const AAlias, AConnId: string; const ATools: TMcpToolInfoArray;
  out ABound: TMcpBoundToolArray): Integer;
function BuildMcpToolsGuidance(const ABound: TMcpBoundToolArray; AIncludeSchemas: Boolean): string;
function ExtractMcpCallResultText(const AJson: string): string;
function ExtractJsonRpcFromHttpBody(const ABody: string): string;
function JsonRpcErrorMessage(const AJson: string): string;
function JsonRpcValidateResponse(const AJson: string; out ErrMsg: string): Boolean;

implementation

uses
  Classes, fpjson, jsonparser, uAgentToolBase;

function JsonSchemaTypeToParamType(const ATypeName: string): string;
begin
  if SameText(ATypeName, 'integer') then
    Result := 'integer'
  else if SameText(ATypeName, 'number') then
    Result := 'number'
  else if SameText(ATypeName, 'boolean') then
    Result := 'boolean'
  else
    Result := 'string';
end;

function ParamRequiredInSchema(const AReq: TJSONArray; const AKey: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if AReq = nil then Exit;
  for I := 0 to AReq.Count - 1 do
    if SameText(AReq.Strings[I], AKey) then
      Exit(True);
end;

procedure AppendSchemaProperty(const AKey: string; APropObj: TJSONObject; AReq: TJSONArray;
  var AParams: TToolParamDefArray);
var
  Param: TToolParamDef;
  EnumArr: TJSONArray;
  E: Integer;
begin
  Param.Name := AKey;
  Param.ParamType := JsonSchemaTypeToParamType(APropObj.Get('type', 'string'));
  Param.Description := APropObj.Get('description', '');
  Param.Required := ParamRequiredInSchema(AReq, AKey);
  SetLength(Param.EnumValues, 0);
  EnumArr := APropObj.Find('enum') as TJSONArray;
  if EnumArr <> nil then
    for E := 0 to EnumArr.Count - 1 do
    begin
      SetLength(Param.EnumValues, Length(Param.EnumValues) + 1);
      Param.EnumValues[High(Param.EnumValues)] := EnumArr.Strings[E];
    end;
  SetLength(AParams, Length(AParams) + 1);
  AParams[High(AParams)] := Param;
end;

function ParseInputSchemaParams(const ASchema: TJSONObject): TToolParamDefArray;
var
  Props: TJSONObject;
  Req: TJSONArray;
  I: Integer;
  Prop: TJSONData;
  PropObj: TJSONObject;
begin
  SetLength(Result, 0);
  if ASchema = nil then Exit;
  Props := ASchema.Find('properties') as TJSONObject;
  Req := ASchema.Find('required') as TJSONArray;
  if Props = nil then Exit;
  for I := 0 to Props.Count - 1 do
  begin
    if Props.Names[I] = '' then Continue;
    Prop := Props.Items[I];
    if not (Prop is TJSONObject) then Continue;
    PropObj := TJSONObject(Prop);
    AppendSchemaProperty(Props.Names[I], PropObj, Req, Result);
  end;
end;

function ParseMcpToolsListResponse(const AJson: string; out ATools: TMcpToolInfoArray;
  out ErrMsg: string): Boolean;
var
  Data: TJSONData;
  Root, ResultObj, ToolObj: TJSONObject;
  ToolsArr: TJSONArray;
  I, N: Integer;
  Item: TJSONData;
  Info: TMcpToolInfo;
  SchemaObj: TJSONObject;
begin
  Result := False;
  SetLength(ATools, 0);
  ErrMsg := '';
  try
    Data := GetJSON(AJson);
  except
    on E: Exception do
    begin
      ErrMsg := E.Message;
      Exit;
    end;
  end;
  try
    if not (Data is TJSONObject) then
    begin
      ErrMsg := 'Expected JSON object';
      Exit;
    end;
    Root := TJSONObject(Data);
    if Root.Find('error') <> nil then
    begin
      ErrMsg := Root.Find('error').AsJSON;
      Exit;
    end;
    if Root.Find('result') is TJSONArray then
    begin
      ErrMsg := 'Unexpected array result';
      Exit;
    end;
    ResultObj := Root.Find('result') as TJSONObject;
    if ResultObj = nil then
    begin
      ErrMsg := 'Missing result in MCP response';
      Exit;
    end;
    ToolsArr := ResultObj.Find('tools') as TJSONArray;
    if ToolsArr = nil then
    begin
      ErrMsg := 'Missing tools array';
      Exit;
    end;
  SetLength(ATools, ToolsArr.Count);
  N := 0;
    for I := 0 to ToolsArr.Count - 1 do
    begin
      Item := ToolsArr.Items[I];
      if not (Item is TJSONObject) then Continue;
      ToolObj := TJSONObject(Item);
      Info.Name := ToolObj.Get('name', '');
      if Info.Name = '' then Continue;
      Info.Description := ToolObj.Get('description', '');
      SchemaObj := ToolObj.Find('inputSchema') as TJSONObject;
      if SchemaObj <> nil then
        Info.InputSchemaJson := SchemaObj.AsJSON
      else
        Info.InputSchemaJson := '{"type":"object","properties":{}}';
      ATools[N] := Info;
      Inc(N);
    end;
    SetLength(ATools, N);
    Result := True;
  finally
    Data.Free;
  end;
end;

function McpToolInfoToToolDef(const AInfo: TMcpToolInfo): TToolDef;
var
  SchemaData: TJSONData;
  SchemaObj: TJSONObject;
begin
  Result.Name := AInfo.Name;
  Result.Description := AInfo.Description;
  SetLength(Result.Params, 0);
  if Trim(AInfo.InputSchemaJson) = '' then Exit;
  try
    SchemaData := GetJSON(AInfo.InputSchemaJson);
    try
      if SchemaData is TJSONObject then
      begin
        SchemaObj := TJSONObject(SchemaData);
        Result.Params := ParseInputSchemaParams(SchemaObj);
      end;
    finally
      SchemaData.Free;
    end;
  except
  end;
end;

function McpToolsToBoundTools(const AAlias, AConnId: string; const ATools: TMcpToolInfoArray;
  out ABound: TMcpBoundToolArray): Integer;
var
  I: Integer;
begin
  SetLength(ABound, Length(ATools));
  for I := 0 to High(ATools) do
  begin
    ABound[I].Alias := AAlias;
    ABound[I].ConnectionId := AConnId;
    ABound[I].ServerName := ATools[I].Name;
    ABound[I].PrefixedName := McpPrefixedToolName(AAlias, ATools[I].Name);
    ABound[I].Def := McpToolInfoToToolDef(ATools[I]);
    ABound[I].Def.Name := ABound[I].PrefixedName;
    if ABound[I].Def.Description = '' then
      ABound[I].Def.Description := 'MCP tool ' + ATools[I].Name + ' from plugin ' + AAlias;
  end;
  Result := Length(ABound);
end;

function BuildMcpToolsGuidance(const ABound: TMcpBoundToolArray; AIncludeSchemas: Boolean): string;
var
  I: Integer;
  Def: TToolDef;
  Schema: string;
begin
  if Length(ABound) = 0 then
    Exit('');
  Result := 'MCP plugin tools (JSON arguments; call by prefixed name):' + LineEnding;
  for I := 0 to High(ABound) do
  begin
    Def := ABound[I].Def;
    if AIncludeSchemas then
    begin
      Schema := ToolDefToParametersJson(Def);
      Result := Result + '- ' + Def.Name + ': ' + Def.Description +
        ' Parameters: ' + Schema + LineEnding;
    end     else
      Result := Result + '- ' + Def.Name + ': ' + Def.Description + LineEnding;
  end;
end;

function ExtractJsonRpcFromHttpBody(const ABody: string): string;
var
  S, Line, Payload: string;
  Lines: TStringList;
  I: Integer;
begin
  S := Trim(ABody);
  if S = '' then
    Exit('');
  if S[1] = '{' then
    Exit(S);
  Result := '';
  Lines := TStringList.Create;
  try
    Lines.Text := ABody;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if (Length(Line) >= 5) and SameText(Copy(Line, 1, 5), 'data:') then
      begin
        Payload := Trim(Copy(Line, 6, MaxInt));
        if Payload <> '' then
          Result := Payload;
      end;
    end;
    if Result = '' then
      Result := S;
  finally
    Lines.Free;
  end;
end;

function JsonRpcErrorMessage(const AJson: string): string;
var
  Data: TJSONData;
  Root, ErrObj: TJSONObject;
  Msg: string;
begin
  Result := '';
  if Trim(AJson) = '' then Exit;
  try
    Data := GetJSON(AJson);
  except
    Exit;
  end;
  try
    if not (Data is TJSONObject) then Exit;
    Root := TJSONObject(Data);
    ErrObj := Root.Find('error') as TJSONObject;
    if ErrObj = nil then Exit;
    Msg := ErrObj.Get('message', '');
    if Msg <> '' then
      Result := Msg
    else
      Result := ErrObj.AsJSON;
  finally
    Data.Free;
  end;
end;

function JsonRpcValidateResponse(const AJson: string; out ErrMsg: string): Boolean;
var
  Data: TJSONData;
  Root: TJSONObject;
  RpcErr: string;
begin
  Result := False;
  ErrMsg := '';
  if Trim(AJson) = '' then
  begin
    ErrMsg := 'Empty JSON-RPC response';
    Exit;
  end;
  RpcErr := JsonRpcErrorMessage(AJson);
  if RpcErr <> '' then
  begin
    ErrMsg := RpcErr;
    Exit;
  end;
  try
    Data := GetJSON(AJson);
  except
    on E: Exception do
    begin
      ErrMsg := 'Invalid JSON: ' + E.Message;
      Exit;
    end;
  end;
  try
    if not (Data is TJSONObject) then
    begin
      ErrMsg := 'Expected JSON object';
      Exit;
    end;
    Root := TJSONObject(Data);
    if Root.Find('error') <> nil then
    begin
      ErrMsg := JsonRpcErrorMessage(AJson);
      Exit;
    end;
    if Root.Find('result') = nil then
    begin
      ErrMsg := 'Missing result in JSON-RPC response';
      Exit;
    end;
    Result := True;
  finally
    Data.Free;
  end;
end;

function ExtractMcpCallResultText(const AJson: string): string;
var
  Data: TJSONData;
  Root, ResultObj: TJSONObject;
  I: Integer;
  Item: TJSONData;
  TextVal: string;
begin
  Result := AJson;
  try
    Data := GetJSON(AJson);
  except
    Exit;
  end;
  try
    if not (Data is TJSONObject) then Exit;
    Root := TJSONObject(Data);
    if Root.Find('error') <> nil then
    begin
      Result := Root.Find('error').AsJSON;
      Exit;
    end;
    ResultObj := Root.Find('result') as TJSONObject;
    if ResultObj = nil then Exit;
    if ResultObj.Find('content') is TJSONArray then
    begin
      TextVal := '';
      for I := 0 to TJSONArray(ResultObj.Find('content')).Count - 1 do
      begin
        Item := TJSONArray(ResultObj.Find('content')).Items[I];
        if (Item is TJSONObject) and SameText(TJSONObject(Item).Get('type', ''), 'text') then
          TextVal := TextVal + TJSONObject(Item).Get('text', '');
      end;
      if TextVal <> '' then
        Result := TextVal
      else
        Result := ResultObj.AsJSON;
    end
    else if ResultObj.Find('structuredContent') <> nil then
      Result := ResultObj.Find('structuredContent').AsJSON
    else
      Result := ResultObj.AsJSON;
  finally
    Data.Free;
  end;
end;

end.
