program test_llm_tool_schemas;
{$mode objfpc}{$H+}
uses
  SysUtils, fpjson, jsonparser, uAppTypes, uAgentTypes, uAgentTools, uAgentToolBase,
  uLlmToolCalling;

procedure AssertNoEnumOnParam(const ASchemaJson, AToolName, AParam: string);
var
  Root, Props, ParamObj: TJSONObject;
  Data: TJSONData;
begin
  Data := GetJSON(ASchemaJson);
  try
    Root := TJSONObject(Data);
    Props := Root.Objects['properties'];
    if Props.Find(AParam) = nil then
      raise Exception.CreateFmt('Missing param %s on %s', [AParam, AToolName]);
    ParamObj := TJSONObject(Props.Find(AParam));
    if ParamObj.Find('enum') <> nil then
      raise Exception.CreateFmt('Unexpected enum on %s.%s', [AToolName, AParam]);
  finally
    Data.Free;
  end;
end;

procedure TestBrowserToolsNoSpuriousEnums;
var
  Ctx: TAgentToolContext;
  Reg: TAgentToolRegistry;
  Defs: TToolDefArray;
  I: Integer;
  Schema: string;
begin
  Ctx := TAgentToolContext.Create(ExpandFileName('.'));
  Reg := TAgentToolRegistry.Create(Ctx);
  try
    Defs := Reg.GetToolDefinitions(wmAgent);
    for I := Low(Defs) to High(Defs) do begin
      Schema := ToolDefToParametersJson(Defs[I]);
      if SameText(Defs[I].Name, 'browser_click') then begin
        AssertNoEnumOnParam(Schema, 'browser_click', 'timeout_ms');
        AssertNoEnumOnParam(Schema, 'browser_click', 'selector');
      end;
      if SameText(Defs[I].Name, 'browser_fill') then
        AssertNoEnumOnParam(Schema, 'browser_fill', 'value');
    end;
  finally
    Reg.Free;
    Ctx.Free;
  end;
end;

procedure TestWebSearchRecencyEnumIsolated;
var
  Ctx: TAgentToolContext;
  Reg: TAgentToolRegistry;
  Defs: TToolDefArray;
  I, J: Integer;
  SchemaA, SchemaB: string;
  Root, Props: TJSONObject;
  Data: TJSONData;
  RecencyEnum: TJSONArray;
begin
  Ctx := TAgentToolContext.Create(ExpandFileName('.'));
  Reg := TAgentToolRegistry.Create(Ctx);
  try
    Defs := Reg.GetToolDefinitions(wmAgent);
    SchemaA := '';
    for I := Low(Defs) to High(Defs) do
      if SameText(Defs[I].Name, 'write_file') then
        SchemaA := ToolDefToParametersJson(Defs[I]);
    if SchemaA = '' then
      raise Exception.Create('write_file missing');
    AssertNoEnumOnParam(SchemaA, 'write_file', 'path');
    for I := Low(Defs) to High(Defs) do begin
      if not SameText(Defs[I].Name, 'web_search') then Continue;
      SchemaB := ToolDefToParametersJson(Defs[I]);
      Data := GetJSON(SchemaB);
      try
        Root := TJSONObject(Data);
        Props := Root.Objects['properties'];
        if Props.Find('recency') = nil then Continue;
        RecencyEnum := TJSONArray(TJSONObject(Props.Find('recency')).Find('enum'));
        if RecencyEnum.Count <> 5 then
          raise Exception.Create('web_search recency enum size');
        for J := Low(Defs) to High(Defs) do begin
          if SameText(Defs[J].Name, 'web_search') then Continue;
          SchemaA := ToolDefToParametersJson(Defs[J]);
          Data := GetJSON(SchemaA);
          try
            Props := TJSONObject(Data).Objects['properties'];
            if Props.Find('recency') <> nil then
              if TJSONObject(Props.Find('recency')).Find('enum') <> nil then
                raise Exception.CreateFmt('recency enum leaked to %s', [Defs[J].Name]);
          finally
            Data.Free;
          end;
        end;
      finally
        Data.Free;
      end;
    end;
  finally
    Reg.Free;
    Ctx.Free;
  end;
end;

procedure TestDistinctSchemaJsonPerTool;
var
  Ctx: TAgentToolContext;
  Reg: TAgentToolRegistry;
  Defs: TToolDefArray;
  I, J: Integer;
  SA, SB: string;
begin
  Ctx := TAgentToolContext.Create(ExpandFileName('.'));
  Reg := TAgentToolRegistry.Create(Ctx);
  try
    Defs := Reg.GetToolDefinitions(wmAgent);
    for I := Low(Defs) to High(Defs) do
      for J := I + 1 to High(Defs) do begin
        SA := ToolDefToParametersJson(Defs[I]);
        SB := ToolDefToParametersJson(Defs[J]);
        if SA = SB then
          raise Exception.CreateFmt('Schemas must differ: %s vs %s', [Defs[I].Name, Defs[J].Name]);
      end;
  finally
    Reg.Free;
    Ctx.Free;
  end;
end;

procedure TestCloneToolParametersIndependent;
var
  Def: TToolDef;
  A, B: TJSONObject;
begin
  Def.Name := 'web_search';
  SetLength(Def.Params, 1);
  Def.Params[0].Name := 'recency';
  Def.Params[0].EnumValues := ['any', 'day'];
  Def.Params[0].Required := False;
  A := CloneToolParametersJson(ToolDefToParametersJson(Def));
  B := CloneToolParametersJson(ToolDefToParametersJson(Def));
  try
    TJSONArray(TJSONObject(A.Find('properties')).Objects['recency']).Add('week');
    if TJSONArray(TJSONObject(B.Find('properties')).Objects['recency']).Count <> 2 then
      raise Exception.Create('clone must not share enum array');
  finally
    A.Free;
    B.Free;
  end;
end;

begin
  TestBrowserToolsNoSpuriousEnums;
  TestWebSearchRecencyEnumIsolated;
  TestDistinctSchemaJsonPerTool;
  TestCloneToolParametersIndependent;
  WriteLn('LLM tool schema tests passed.');
end.
