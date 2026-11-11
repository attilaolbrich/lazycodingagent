unit uAgentExecutionLog;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, uAppTypes, uAgentTypes;

type
  TExecutionLogKind = (elUserPrompt, elToolExecution, elAssistantResponse, elLlmWire);

  TExecutionLogEntry = class
  public
    Kind: TExecutionLogKind;
    Timestamp: TDateTime;
    Caption: string;
    UserOrResponseText: string;
    ContextText: string;
    ToolName: string;
    ToolArgsJson: string;
    ToolOutputJson: string;
    ToolSuccess: Boolean;
    AssistantToolCalls: TToolCallArray;
    RawRequestJson: string;
    RawResponseJson: string;
    ParsedToolCallsJson: string;
    ParseFailuresText: string;
    function BuildInspectorMarkdown: string;
    destructor Destroy; override;
  end;

  TAgentExecutionLog = class
  private
    FEntries: TObjectList;
    function NewEntry: TExecutionLogEntry;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Count: Integer;
    function Entry(AIndex: Integer): TExecutionLogEntry;
    function AddUserPrompt(const AUserText, AFullContext: string): Integer;
    function AddTool(const AName, AArgsJson, AOutputJson, ASummary: string;
      ASuccess: Boolean; AStep, AMaxSteps: Integer): Integer;
    function AddAssistant(const AContent, ALlmContext: string;
      const AToolCalls: TToolCallArray; AStep, AMaxSteps: Integer): Integer;
    function AddLlmWire(const ARawRequest, ARawResponse: string;
      const AToolCalls: TToolCallArray; const AParseFailures: array of string;
      AStep, AMaxSteps: Integer): Integer;
  end;

function PrettyJsonString(const S: string): string;
function TruncateLogCaption(const S: string; AMaxLen: Integer = 72): string;
function FormatToolCallActivityDetail(const AToolName, AArgsJson: string): string;
function FormatToolCallActivityLine(const AToolName, AArgsJson: string): string;
function FormatMessagesForDisplay(const AMessages: array of TChatMessage;
  const ATools: array of TToolDef; AToolSchemasInApiPayload: Boolean = False): string;
function FormatMessageBodyForLog(const AMsg: TChatMessage): string;

implementation

uses
  fpjson, jsonparser, uAgentToolBase, uExecutionDetailText, uChatImageStore;

function PrettyJsonString(const S: string): string;
var
  Data: TJSONObject;
  T: string;
begin
  T := Trim(S);
  if T = '' then Exit('');
  if not JsonToolArgumentsWellFormed(T) then
  begin
    Result := string(SafeToolText(T, 200));
    if Length(T) > Length(Result) then
      Result := Result + '...';
    Exit;
  end;
  if TryGetJSONObject(T, Data) then
  begin
    try
      Result := Data.FormatJSON;
    finally
      Data.Free;
    end;
  end
  else
    Result := T;
end;

function TruncateLogCaption(const S: string; AMaxLen: Integer): string;
var
  T: string;
begin
  T := Trim(StringReplace(S, LineEnding, ' ', [rfReplaceAll]));
  if Length(T) <= AMaxLen then
    Result := T
  else
    Result := Copy(T, 1, AMaxLen - 3) + '...';
end;

function ShortDisplayPath(const APath: string): string;
var
  T: string;
begin
  T := Trim(APath);
  if T = '' then Exit('');
  if Length(T) > 56 then
    Result := ExtractFileName(T)
  else
    Result := T;
end;

function FirstLineOf(const S: string): string;
var
  P: Integer;
begin
  P := Pos(LineEnding, S);
  if P > 0 then
    Result := Trim(Copy(S, 1, P - 1))
  else
    Result := Trim(S);
end;

function JsonObjField(const Obj: TJSONObject; const ANames: array of string): string;
var
  I: Integer;
  D: TJSONData;
begin
  Result := '';
  if Obj = nil then Exit;
  for I := Low(ANames) to High(ANames) do begin
    D := Obj.Find(ANames[I]);
    if D = nil then Continue;
    if D is TJSONString then
      Exit(TJSONString(D).AsString)
    else
      Exit(D.AsJSON);
  end;
end;

function FirstPatchPathFromPatch(const APatch: string): string;
var
  Lines, I: Integer;
  Line: string;
begin
  Result := '';
  I := 1;
  while I <= Length(APatch) do begin
    Lines := I;
    while (I <= Length(APatch)) and (APatch[I] <> #10) and (APatch[I] <> #13) do
      Inc(I);
    Line := Trim(Copy(APatch, Lines, I - Lines));
    if (I <= Length(APatch)) and (APatch[I] = #13) then Inc(I);
    if (I <= Length(APatch)) and (APatch[I] = #10) then Inc(I);
    if (Length(Line) > 4) and ((Copy(Line, 1, 4) = '+++ ') or (Copy(Line, 1, 4) = '--- ')) then begin
      Line := Trim(Copy(Line, 5, MaxInt));
      if (Length(Line) > 2) and ((Line[1] = 'b') or (Line[1] = 'a')) and (Line[2] = '/') then
        Line := Copy(Line, 3, MaxInt);
      if Line <> '' then
        Exit(ShortDisplayPath(Line));
    end;
  end;
end;

function TodoActivityDetail(Obj: TJSONObject): string;
var
  Act, ItemText: string;
  Items: TJSONArray;
  First: TJSONObject;
begin
  Act := Obj.Get('action', '');
  Result := Act;
  if not SameText(Act, 'replace') then Exit;
  Items := Obj.Find('items') as TJSONArray;
  if (Items = nil) or (Items.Count = 0) then Exit;
  if Items.Items[0] is TJSONObject then begin
    First := TJSONObject(Items.Items[0]);
    ItemText := JsonObjField(First, ['text', 'id']);
    if ItemText <> '' then begin
      if Result <> '' then
        Result := Result + ' - ' + TruncateLogCaption(ItemText, 48)
      else
        Result := TruncateLogCaption(ItemText, 48);
    end;
  end;
end;

function ToolNameMatches(const AToolName, ACanonical: string): Boolean;
begin
  Result := SameText(AToolName, ACanonical);
end;

function FormatToolCallActivityDetail(const AToolName, AArgsJson: string): string;
var
  Obj: TJSONObject;
  Name, Detail, Cmd, Op, Rev: string;
begin
  Result := '';
  if not JsonToolArgumentsWellFormed(AArgsJson) then begin
    Result := TruncateLogCaption(string(SafeToolText(AArgsJson, 120)), 48);
    Exit;
  end;
  if not TryGetJSONObject(AArgsJson, Obj) then begin
    Result := TruncateLogCaption(AArgsJson, 48);
    Exit;
  end;
  try
    Name := LowerCase(Trim(AToolName));
    if ToolNameMatches(Name, 'shell') or ToolNameMatches(Name, 'run_process') or
       ToolNameMatches(Name, 'terminal') then begin
      Cmd := Obj.Get('command', '');
      Result := TruncateLogCaption(FirstLineOf(Cmd), 72);
      Exit;
    end;
    if ToolNameMatches(Name, 'git') then begin
      Op := Obj.Get('operation', '');
      Rev := Obj.Get('revision', '');
      Detail := Op;
      if Rev <> '' then
        Detail := Detail + ' ' + Rev;
      if Obj.Get('staged', False) then
        Detail := Detail + ' staged';
      Result := Trim(Detail);
      Exit;
    end;
    if ToolNameMatches(Name, 'read_file') or ToolNameMatches(Name, 'write_file') or
       ToolNameMatches(Name, 'edit_file') or ToolNameMatches(Name, 'list_directory') then begin
      Result := ShortDisplayPath(Obj.Get('path', ''));
      Exit;
    end;
    if ToolNameMatches(Name, 'glob') then begin
      Result := TruncateLogCaption(Obj.Get('pattern', ''), 72);
      Exit;
    end;
    if ToolNameMatches(Name, 'search_code') then begin
      Detail := Obj.Get('query', '');
      if Detail = '' then
        Detail := Obj.Get('pattern', '');
      Result := TruncateLogCaption(Detail, 72);
      Exit;
    end;
    if ToolNameMatches(Name, 'todo') or ToolNameMatches(Name, 'plan') then begin
      Result := TodoActivityDetail(Obj);
      Exit;
    end;
    if ToolNameMatches(Name, 'apply_patch') then begin
      Result := FirstPatchPathFromPatch(Obj.Get('patch', ''));
      if Result = '' then
        Result := 'patch';
      Exit;
    end;
    if ToolNameMatches(Name, 'create_plan_file') then begin
      Detail := FirstLineOf(Obj.Get('content', ''));
      if Detail = '' then
        Result := 'plan'
      else
        Result := TruncateLogCaption(Detail, 72);
      Exit;
    end;
    if ToolNameMatches(Name, 'diagnostics') then begin
      Result := Obj.Get('action', '');
      Exit;
    end;
    Result := TruncateLogCaption(AArgsJson, 48);
  finally
    Obj.Free;
  end;
end;

function FormatToolCallActivityLine(const AToolName, AArgsJson: string): string;
var
  Detail: string;
begin
  Detail := FormatToolCallActivityDetail(AToolName, AArgsJson);
  if Detail <> '' then
    Result := AToolName + ' - ' + Detail
  else
    Result := AToolName;
end;

procedure CopyToolCalls(const ASrc: TToolCallArray; var ADst: TToolCallArray);
var
  I: Integer;
begin
  SetLength(ADst, Length(ASrc));
  for I := Low(ASrc) to High(ASrc) do begin
    ADst[I].Id := ASrc[I].Id;
    ADst[I].Name := ASrc[I].Name;
    ADst[I].ArgumentsJson := ASrc[I].ArgumentsJson;
  end;
end;

function ToolCallNamesCaption(const AToolCalls: TToolCallArray): string;
var
  I: Integer;
  Names: TStringList;
begin
  Names := TStringList.Create;
  try
    Names.Duplicates := dupIgnore;
    for I := Low(AToolCalls) to High(AToolCalls) do
      if AToolCalls[I].Name <> '' then
        Names.Add(AToolCalls[I].Name);
    Result := Names.CommaText;
    Result := StringReplace(Result, '"', '', [rfReplaceAll]);
  finally
    Names.Free;
  end;
end;

function FormatMessageBodyForLog(const AMsg: TChatMessage): string;
var
  I: Integer;
  Parts: TStringList;
  AttSummary: string;
begin
  Parts := TStringList.Create;
  try
    if AMsg.Role = crTool then begin
      if AMsg.ToolCallId <> '' then
        Parts.Add('tool_call_id: ' + AMsg.ToolCallId);
      Parts.Add(PrettyJsonString(AMsg.Content));
    end else if (AMsg.Role = crAssistant) and (Length(AMsg.ToolCalls) > 0) then begin
      if Trim(AMsg.Content) <> '' then
        Parts.Add(AMsg.Content);
      for I := Low(AMsg.ToolCalls) to High(AMsg.ToolCalls) do
        Parts.Add(Format('tool_call: %s(%s)', [
          AMsg.ToolCalls[I].Name, PrettyJsonString(AMsg.ToolCalls[I].ArgumentsJson)]));
    end else begin
      if Trim(AMsg.Content) <> '' then
        Parts.Add(AMsg.Content);
      if Length(AMsg.Attachments) > 0 then begin
        AttSummary := FormatAttachmentsSummary(AMsg.Attachments);
        if AttSummary <> '' then
          Parts.Add(AttSummary);
      end;
    end;
    Result := Parts.Text;
  finally
    Parts.Free;
  end;
end;

function FormatMessagesForDisplay(const AMessages: array of TChatMessage;
  const ATools: array of TToolDef; AToolSchemasInApiPayload: Boolean): string;
var
  I, J: Integer;
  SB: TStringBuilder;
  SysText, NamesLine: string;
begin
  SB := TStringBuilder.Create;
  try
    SysText := '';
    for I := Low(AMessages) to High(AMessages) do begin
      if AMessages[I].Role = crSystem then begin
        SysText := AMessages[I].Content;
        Break;
      end;
    end;

    SB.AppendLine('--- System ---');
    if SysText <> '' then
      SB.AppendLine(SysText)
    else
      SB.AppendLine('(none)');

    SB.AppendLine;
    SB.AppendLine('--- Conversation ---');
    for I := Low(AMessages) to High(AMessages) do begin
      if AMessages[I].Role = crSystem then Continue;
      SB.AppendLine('[' + ChatRoleToString(AMessages[I].Role) + ']');
      SB.AppendLine(FormatMessageBodyForLog(AMessages[I]));
      SB.AppendLine;
    end;

    SB.AppendLine('--- Tools available (this step) ---');
    if Length(ATools) = 0 then
      SB.AppendLine('(none)')
    else if AToolSchemasInApiPayload then begin
      NamesLine := '';
      for J := Low(ATools) to High(ATools) do begin
        if NamesLine <> '' then
          NamesLine := NamesLine + ', ';
        NamesLine := NamesLine + ATools[J].Name;
      end;
      SB.AppendLine('(schemas in API tools[]; names: ' + NamesLine + ')');
    end else
      for J := Low(ATools) to High(ATools) do
        SB.AppendLine(Format('- %s: %s', [ATools[J].Name, ATools[J].Description]));

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

destructor TExecutionLogEntry.Destroy;
begin
  SetLength(AssistantToolCalls, 0);
  inherited Destroy;
end;

function TExecutionLogEntry.BuildInspectorMarkdown: string;
var
  SB: TStringBuilder;
  I: Integer;
begin
  SB := TStringBuilder.Create;
  try
    case Kind of
      elUserPrompt:
        begin
          AppendDetailSectionHeader(SB, 'User input');
          AppendDetailProseBlock(SB, UserOrResponseText);
          AppendDetailSectionHeader(SB, 'Full prompt sent to model');
          AppendDetailProseBlock(SB, ContextText);
        end;
      elToolExecution:
        begin
          AppendDetailSectionHeader(SB, 'Tool');
          AppendDetailToolLine(SB, ToolName, not ToolSuccess);
          AppendDetailSectionHeader(SB, 'Input (arguments)');
          AppendDetailJsonBlock(SB, ToolArgsJson);
          AppendDetailSectionHeader(SB, 'Output');
          AppendDetailJsonBlock(SB, ToolOutputJson);
        end;
      elAssistantResponse:
        begin
          if Length(AssistantToolCalls) > 0 then begin
            AppendDetailSectionHeader(SB, 'Tool calls');
            for I := Low(AssistantToolCalls) to High(AssistantToolCalls) do begin
              AppendDetailToolLine(SB, AssistantToolCalls[I].Name, False);
              if AssistantToolCalls[I].Id <> '' then
                SB.AppendLine('_id: ' + AssistantToolCalls[I].Id + '_');
              AppendDetailJsonBlock(SB, AssistantToolCalls[I].ArgumentsJson);
            end;
          end;
          AppendDetailSectionHeader(SB, 'Model response');
          if Trim(UserOrResponseText) <> '' then
            AppendDetailProseBlock(SB, UserOrResponseText)
          else if Length(AssistantToolCalls) = 0 then
            SB.AppendLine('*(empty)*')
          else
            SB.AppendLine('*(empty content; tool calls only)*');
          SB.AppendLine;
          AppendDetailSectionHeader(SB, 'Request context');
          AppendDetailProseBlock(SB, ContextText);
        end;
      elLlmWire:
        begin
          AppendDetailSectionHeader(SB, 'Outgoing API request (redacted)');
          AppendDetailJsonBlock(SB, RawRequestJson);
          AppendDetailSectionHeader(SB, 'Incoming API response (redacted)');
          AppendDetailJsonBlock(SB, RawResponseJson);
          if Trim(ParsedToolCallsJson) <> '' then begin
            AppendDetailSectionHeader(SB, 'Parsed native tool calls');
            AppendDetailJsonBlock(SB, ParsedToolCallsJson);
          end;
          if Trim(ParseFailuresText) <> '' then begin
            AppendDetailSectionHeader(SB, 'Parse / validation notes');
            AppendDetailProseBlock(SB, ParseFailuresText);
          end;
        end;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

{ TAgentExecutionLog }

constructor TAgentExecutionLog.Create;
begin
  inherited Create;
  FEntries := TObjectList.Create(True);
end;

destructor TAgentExecutionLog.Destroy;
begin
  FEntries.Free;
  inherited Destroy;
end;

procedure TAgentExecutionLog.Clear;
begin
  FEntries.Clear;
end;

function TAgentExecutionLog.Count: Integer;
begin
  Result := FEntries.Count;
end;

function TAgentExecutionLog.Entry(AIndex: Integer): TExecutionLogEntry;
begin
  Result := TExecutionLogEntry(FEntries[AIndex]);
end;

function TAgentExecutionLog.NewEntry: TExecutionLogEntry;
begin
  Result := TExecutionLogEntry.Create;
  Result.Timestamp := Now;
  SetLength(Result.AssistantToolCalls, 0);
  FEntries.Add(Result);
end;

function TAgentExecutionLog.AddUserPrompt(const AUserText, AFullContext: string): Integer;
var
  E: TExecutionLogEntry;
begin
  E := NewEntry;
  E.Kind := elUserPrompt;
  E.UserOrResponseText := AUserText;
  E.ContextText := AFullContext;
  E.Caption := 'User: ' + TruncateLogCaption(AUserText);
  Result := FEntries.Count - 1;
end;

function StepCaptionPrefix(AStep, AMaxSteps: Integer): string;
begin
  if (AMaxSteps > 0) and (AStep > 0) then
    Result := Format('Step %d/%d · ', [AStep, AMaxSteps])
  else
    Result := '';
end;

function TAgentExecutionLog.AddTool(const AName, AArgsJson, AOutputJson, ASummary: string;
  ASuccess: Boolean; AStep, AMaxSteps: Integer): Integer;
var
  E: TExecutionLogEntry;
  Cap: string;
begin
  E := NewEntry;
  E.Kind := elToolExecution;
  E.ToolName := AName;
  E.ToolArgsJson := AArgsJson;
  E.ToolOutputJson := AOutputJson;
  E.ToolSuccess := ASuccess;
  if ASummary <> '' then
    Cap := ASummary
  else
    Cap := TruncateLogCaption(AArgsJson, 48);
  E.Caption := StepCaptionPrefix(AStep, AMaxSteps) + AName + '(' + Cap + ')';
  Result := FEntries.Count - 1;
end;

function TAgentExecutionLog.AddAssistant(const AContent, ALlmContext: string;
  const AToolCalls: TToolCallArray; AStep, AMaxSteps: Integer): Integer;
var
  E: TExecutionLogEntry;
  Cap: string;
  ToolCount: Integer;
begin
  E := NewEntry;
  E.Kind := elAssistantResponse;
  E.UserOrResponseText := AContent;
  E.ContextText := ALlmContext;
  CopyToolCalls(AToolCalls, E.AssistantToolCalls);
  ToolCount := Length(AToolCalls);
  if ToolCount > 0 then begin
    Cap := TruncateLogCaption(AContent);
    if Cap = '' then
      Cap := TruncateLogCaption(ToolCallNamesCaption(AToolCalls), 48);
    E.Caption := StepCaptionPrefix(AStep, AMaxSteps) + 'Model: ' + Cap +
      Format(' [%d tools]', [ToolCount]);
  end else begin
    Cap := TruncateLogCaption(AContent);
    E.Caption := StepCaptionPrefix(AStep, AMaxSteps) + 'Model: ' + Cap;
  end;
  Result := FEntries.Count - 1;
end;

function ToolCallsToJsonArray(const AToolCalls: TToolCallArray): string;
var
  Arr: TJSONArray;
  I: Integer;
  Item, Fn: TJSONObject;
begin
  Arr := TJSONArray.Create;
  try
    for I := Low(AToolCalls) to High(AToolCalls) do begin
      Item := TJSONObject.Create;
      Item.Add('id', AToolCalls[I].Id);
      Fn := TJSONObject.Create;
      Fn.Add('name', AToolCalls[I].Name);
      Fn.Add('arguments', AToolCalls[I].ArgumentsJson);
      Item.Add('function', Fn);
      Arr.Add(Item);
    end;
    Result := Arr.AsJSON;
  finally
    Arr.Free;
  end;
end;

function ParseFailuresToText(const AFailures: array of string): string;
var
  I: Integer;
  SB: TStringBuilder;
begin
  if Length(AFailures) = 0 then Exit('');
  SB := TStringBuilder.Create;
  try
    for I := Low(AFailures) to High(AFailures) do begin
      if I > 0 then SB.AppendLine;
      SB.Append(AFailures[I]);
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TAgentExecutionLog.AddLlmWire(const ARawRequest, ARawResponse: string;
  const AToolCalls: TToolCallArray; const AParseFailures: array of string;
  AStep, AMaxSteps: Integer): Integer;
var
  E: TExecutionLogEntry;
begin
  E := NewEntry;
  E.Kind := elLlmWire;
  E.RawRequestJson := ARawRequest;
  E.RawResponseJson := ARawResponse;
  E.ParsedToolCallsJson := ToolCallsToJsonArray(AToolCalls);
  E.ParseFailuresText := ParseFailuresToText(AParseFailures);
  E.Caption := StepCaptionPrefix(AStep, AMaxSteps) + 'LLM wire';
  Result := FEntries.Count - 1;
end;

end.
