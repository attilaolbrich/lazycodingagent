unit uLlmRequestGemini;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson, uAgentTypes, uAgentToolBase, uLlmPromptCacheTypes;

function GeminiGenerateUrl(const ABaseUrl, AModel: string): string;
function BuildGeminiGeneratePayload(
  const AModel: string;
  ATemperature: Double;
  AMaxTokens: Integer;
  const AMessages: array of TChatMessage;
  const ATools: array of TToolDef
): string;

implementation

function GeminiGenerateUrl(const ABaseUrl, AModel: string): string;
var
  Url, Model: string;
begin
  Url := Trim(ABaseUrl);
  if Url = '' then
    Url := 'https://generativelanguage.googleapis.com/v1beta';
  if Url[Length(Url)] = '/' then
    Url := Copy(Url, 1, Length(Url) - 1);
  Model := Trim(AModel);
  if Pos('models/', Model) = 1 then
    Model := Copy(Model, 8, MaxInt);
  Result := Url + '/models/' + Model + ':generateContent';
end;

function BuildGeminiGeneratePayload(
  const AModel: string;
  ATemperature: Double;
  AMaxTokens: Integer;
  const AMessages: array of TChatMessage;
  const ATools: array of TToolDef
): string;
var
  Root, GenCfg, ContentObj, PartObj, ToolsCfg, Decl, Schema: TJSONObject;
  Contents, Parts, ToolsArr, FuncDecls: TJSONArray;
  I: Integer;
  Msg: TChatMessage;
  Role: string;
  SystemText: string;
begin
  Root := TJSONObject.Create;
  try
    Contents := TJSONArray.Create;
    SystemText := '';
    for I := Low(AMessages) to High(AMessages) do begin
      Msg := AMessages[I];
      if Msg.Role = crSystem then begin
        if SystemText <> '' then SystemText := SystemText + LineEnding;
        SystemText := SystemText + Msg.Content;
        Continue;
      end;
      ContentObj := TJSONObject.Create;
      case Msg.Role of
        crUser: Role := 'user';
        crAssistant: Role := 'model';
        crTool: Role := 'user';
      else
        Role := 'user';
      end;
      ContentObj.Add('role', Role);
      Parts := TJSONArray.Create;
      PartObj := TJSONObject.Create;
      if Msg.Role = crTool then
        PartObj.Add('text', '[tool_result:' + Msg.ToolCallId + '] ' + Msg.Content)
      else
        PartObj.Add('text', Msg.Content);
      Parts.Add(PartObj);
      ContentObj.Add('parts', Parts);
      Contents.Add(ContentObj);
    end;
    if SystemText <> '' then begin
      ContentObj := TJSONObject.Create;
      ContentObj.Add('role', 'user');
      Parts := TJSONArray.Create;
      PartObj := TJSONObject.Create;
      PartObj.Add('text', SystemText);
      Parts.Add(PartObj);
      ContentObj.Add('parts', Parts);
      Contents.Add(ContentObj);
    end;
    Root.Add('contents', Contents);
    GenCfg := TJSONObject.Create;
    GenCfg.Add('temperature', ATemperature);
    if AMaxTokens > 0 then
      GenCfg.Add('maxOutputTokens', AMaxTokens);
    Root.Add('generationConfig', GenCfg);
    if Length(ATools) > 0 then begin
      ToolsCfg := TJSONObject.Create;
      Decl := TJSONObject.Create;
      Decl.Add('name', ATools[0].Name);
      Schema := GetJSON(ToolDefToParametersJson(ATools[0])) as TJSONObject;
      if Schema = nil then
        Schema := TJSONObject.Create;
      Decl.Add('parameters', Schema);
      FuncDecls := TJSONArray.Create;
      FuncDecls.Add(Decl);
      ToolsCfg.Add('functionDeclarations', FuncDecls);
      ToolsArr := TJSONArray.Create;
      ToolsArr.Add(ToolsCfg);
      Root.Add('tools', ToolsArr);
    end;
    Result := Root.AsJSON;
  finally
    Root.Free;
  end;
end;

end.
