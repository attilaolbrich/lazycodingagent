unit uLlmRequestAnthropic;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson, uAgentTypes, uAgentToolBase, uLlmPromptCacheTypes,
  uLlmCacheBreakpoints;

function AnthropicMessagesUrl(const ABaseUrl: string): string;
function BuildAnthropicMessagesPayload(
  const AModel: string;
  ATemperature: Double;
  AMaxTokens: Integer;
  const AMessages: array of TChatMessage;
  const ATools: array of TToolDef;
  const ASegments: TPromptSegmentArray;
  const ASettings: TPromptCacheSettings;
  const ACapabilities: TPromptCacheCapabilities
): string;

implementation

function AnthropicMessagesUrl(const ABaseUrl: string): string;
var
  Url: string;
begin
  Url := Trim(ABaseUrl);
  if Url = '' then
    Url := 'https://api.anthropic.com/v1';
  if Url[Length(Url)] = '/' then
    Url := Copy(Url, 1, Length(Url) - 1);
  if SameText(Copy(Url, Length(Url) - 8, 9), '/messages') then
    Result := Url
  else if SameText(Copy(Url, Length(Url) - 2, 3), '/v1') then
    Result := Url + '/messages'
  else
    Result := Url + '/messages';
end;

function ShouldCacheBlock(AKind: TPromptSegmentKind;
  const ABreakpoints: TPromptSegmentKindArray): Boolean;
var
  I: Integer;
begin
  for I := Low(ABreakpoints) to High(ABreakpoints) do
    if ABreakpoints[I] = AKind then
      Exit(True);
  Result := False;
end;

procedure AddCacheControlIfNeeded(AObj: TJSONObject; AUseCache: Boolean;
  ARetention: TPromptCacheRetention);
var
  Cc: TJSONObject;
begin
  if not AUseCache then Exit;
  Cc := TJSONObject.Create;
  Cc.Add('type', 'ephemeral');
  if ARetention = pcrExtended then
    Cc.Add('ttl', '1h');
  AObj.Add('cache_control', Cc);
end;

procedure AddSystemBlocks(ARoot: TJSONObject; const ASystemText: string;
  const ASegments: TPromptSegmentArray; const ASettings: TPromptCacheSettings;
  const ACapabilities: TPromptCacheCapabilities);
var
  SysArr: TJSONArray;
  Block: TJSONObject;
  Bps: TPromptSegmentKindArray;
  I: Integer;
  UseExplicit: Boolean;
begin
  if Trim(ASystemText) = '' then Exit;
  SysArr := TJSONArray.Create;
  UseExplicit := (ASettings.Mode = pcmExplicit) and ACapabilities.SupportsExplicitCaching;
  Bps := SelectCacheBreakpointKinds(ASegments, ASettings, ACapabilities);
  if UseExplicit and (Length(ASegments) > 0) then begin
    for I := Low(ASegments) to High(ASegments) do begin
      if Trim(ASegments[I].Content) = '' then Continue;
      if not ShouldCacheBlock(ASegments[I].Kind, Bps) then Continue;
      Block := TJSONObject.Create;
      Block.Add('type', 'text');
      Block.Add('text', ASegments[I].Content);
      AddCacheControlIfNeeded(Block, True, ASettings.Retention);
      SysArr.Add(Block);
    end;
  end;
  if SysArr.Count = 0 then begin
    Block := TJSONObject.Create;
    Block.Add('type', 'text');
    Block.Add('text', ASystemText);
    if (ASettings.Mode = pcmAutomatic) and ACapabilities.SupportsAutomaticCaching then
      AddCacheControlIfNeeded(Block, ASettings.CacheSystemInstructions, ASettings.Retention);
    SysArr.Add(Block);
  end;
  ARoot.Add('system', SysArr);
end;

function ToolInputSchemaJson(const ADef: TToolDef): TJSONObject;
var
  ParamData: TJSONData;
  ParamObj: TJSONObject;
begin
  ParamData := GetJSON(ToolDefToParametersJson(ADef));
  if ParamData is TJSONObject then
    Result := TJSONObject(ParamData)
  else begin
    if ParamData <> nil then
      ParamData.Free;
    ParamObj := TJSONObject.Create;
    ParamObj.Add('type', 'object');
    ParamObj.Add('properties', TJSONObject.Create);
    Result := ParamObj;
  end;
end;

procedure AddToolsArray(ARoot: TJSONObject; const ATools: array of TToolDef;
  const ASettings: TPromptCacheSettings; const ACapabilities: TPromptCacheCapabilities);
var
  Sorted: array of TToolDef;
  I, J: Integer;
  Tmp: TToolDef;
  ToolObj, Schema: TJSONObject;
  Arr: TJSONArray;
begin
  if Length(ATools) = 0 then Exit;
  SetLength(Sorted, Length(ATools));
  for I := Low(ATools) to High(ATools) do
    Sorted[I] := ATools[I];
  for I := Low(Sorted) to High(Sorted) - 1 do
    for J := I + 1 to High(Sorted) do
      if CompareText(Sorted[J].Name, Sorted[I].Name) < 0 then begin
        Tmp := Sorted[I];
        Sorted[I] := Sorted[J];
        Sorted[J] := Tmp;
      end;
  Arr := TJSONArray.Create;
  for I := Low(Sorted) to High(Sorted) do begin
    ToolObj := TJSONObject.Create;
    ToolObj.Add('name', Sorted[I].Name);
    ToolObj.Add('description', Sorted[I].Description);
    Schema := ToolInputSchemaJson(Sorted[I]);
    ToolObj.Add('input_schema', Schema);
    if (ASettings.Mode = pcmAutomatic) and ASettings.CacheToolDefinitions and
       ACapabilities.SupportsAutomaticCaching then
      AddCacheControlIfNeeded(ToolObj, True, ASettings.Retention);
    Arr.Add(ToolObj);
  end;
  ARoot.Add('tools', Arr);
end;

function BuildAnthropicMessagesPayload(
  const AModel: string;
  ATemperature: Double;
  AMaxTokens: Integer;
  const AMessages: array of TChatMessage;
  const ATools: array of TToolDef;
  const ASegments: TPromptSegmentArray;
  const ASettings: TPromptCacheSettings;
  const ACapabilities: TPromptCacheCapabilities
): string;
var
  Root, MsgObj, Block: TJSONObject;
  MsgArr: TJSONArray;
  I, J: Integer;
  Msg: TChatMessage;
  SystemText: string;
  ContentArr: TJSONArray;
  ToolUse, ToolRes: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('model', AModel);
    Root.Add('temperature', ATemperature);
    if AMaxTokens > 0 then
      Root.Add('max_tokens', AMaxTokens);

    SystemText := '';
    MsgArr := TJSONArray.Create;
    for I := Low(AMessages) to High(AMessages) do begin
      Msg := AMessages[I];
      if Msg.Role = crSystem then begin
        if SystemText <> '' then
          SystemText := SystemText + LineEnding;
        SystemText := SystemText + Msg.Content;
        Continue;
      end;
      MsgObj := TJSONObject.Create;
      case Msg.Role of
        crUser:
        begin
          MsgObj.Add('role', 'user');
          MsgObj.Add('content', Msg.Content);
        end;
        crAssistant:
        begin
          MsgObj.Add('role', 'assistant');
          if Length(Msg.ToolCalls) > 0 then begin
            ContentArr := TJSONArray.Create;
            if Trim(Msg.Content) <> '' then begin
              Block := TJSONObject.Create;
              Block.Add('type', 'text');
              Block.Add('text', Msg.Content);
              ContentArr.Add(Block);
            end;
            for J := Low(Msg.ToolCalls) to High(Msg.ToolCalls) do begin
              ToolUse := TJSONObject.Create;
              ToolUse.Add('type', 'tool_use');
              ToolUse.Add('id', Msg.ToolCalls[J].Id);
              ToolUse.Add('name', Msg.ToolCalls[J].Name);
              ToolUse.Add('input', GetJSON(Msg.ToolCalls[J].ArgumentsJson));
              ContentArr.Add(ToolUse);
            end;
            MsgObj.Add('content', ContentArr);
          end else
            MsgObj.Add('content', Msg.Content);
        end;
        crTool:
        begin
          MsgObj.Add('role', 'user');
          ContentArr := TJSONArray.Create;
          ToolRes := TJSONObject.Create;
          ToolRes.Add('type', 'tool_result');
          ToolRes.Add('tool_use_id', Msg.ToolCallId);
          ToolRes.Add('content', Msg.Content);
          ContentArr.Add(ToolRes);
          MsgObj.Add('content', ContentArr);
        end;
      else
        MsgObj.Free;
        Continue;
      end;
      MsgArr.Add(MsgObj);
    end;
    AddSystemBlocks(Root, SystemText, ASegments, ASettings, ACapabilities);
    AddToolsArray(Root, ATools, ASettings, ACapabilities);
    Root.Add('messages', MsgArr);
    Result := Root.AsJSON;
  finally
    Root.Free;
  end;
end;

end.
