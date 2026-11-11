unit uLlmToolCalling;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, uAgentTypes, uAgentToolBase;

type
  TLlmToolCallingCapabilities = record
    NativeToolCalling: Boolean;
    TextToolCompat: Boolean;
    StreamingEnabled: Boolean;
  end;

  TOpenAiParseResult = record
    Success: Boolean;
    ErrorMessage: string;
    Content: string;
    ToolCalls: TToolCallArray;
    FinishReason: string;
    PromptTokens: Integer;
    CompletionTokens: Integer;
    TotalTokens: Integer;
    ParseFailures: array of string;
  end;

  TOpenAiStreamAccumulator = class
  private
    FContent: string;
    FToolIds: array of string;
    FToolNames: array of string;
    FToolArgFragments: array of string;
    FFinishReason: string;
    procedure EnsureToolSlot(AIndex: Integer);
  public
    procedure Reset;
    procedure ApplyDelta(const ADeltaObj: TJSONObject);
    procedure NoteFinishReason(const AReason: string);
    function BuildResponse: TOpenAiParseResult;
    property Content: string read FContent;
    property FinishReason: string read FFinishReason;
  end;

function DefaultLlmToolCallingCapabilities: TLlmToolCallingCapabilities;

function CloneToolParametersJson(const AParametersJson: string): TJSONObject;

function RedactLlmPayloadForLog(const AJson: string): string;

function ExtractStrictTextToolJson(const AContent: string): string;

function TryParseStrictTextToolCalls(const AContent: string;
  const AAllowedTools: array of TToolDef; const AIdPrefix: string;
  out AToolCalls: TToolCallArray; out AError: string): Boolean;

function ToolNameAllowedInDefs(const AName: string;
  const ADefs: array of TToolDef): Boolean;

function AssistantDisplayContent(const AContent: string;
  const AToolCalls: TToolCallArray): string;

function ParseOpenAiSseBody(const ASseBody: string; out AParseFailures: TStringArray): TOpenAiParseResult;

function ApplyOpenAiCompletionJson(var AResult: TOpenAiParseResult;
  const ARootObj: TJSONObject; out AParseFailures: TStringArray): Boolean;

function ExtractFunctionArgumentsJson(AFuncObj: TJSONObject): string;

implementation

uses
  StrUtils;

function DefaultLlmToolCallingCapabilities: TLlmToolCallingCapabilities;
begin
  Result.NativeToolCalling := True;
  Result.TextToolCompat := False;
  Result.StreamingEnabled := False;
end;

function CloneToolParametersJson(const AParametersJson: string): TJSONObject;
var
  Data: TJSONData;
begin
  Result := nil;
  if Trim(AParametersJson) = '' then Exit;
  Data := GetJSON(AParametersJson);
  try
    if Data is TJSONObject then
      Result := TJSONObject(GetJSON(Data.AsJSON))
    else
      Data.Free;
  except
    if Assigned(Data) then
      Data.Free;
  end;
end;

function RedactLlmPayloadForLog(const AJson: string): string;
var
  Data: TJSONData;
  Root: TJSONObject;
  I: Integer;
begin
  Result := AJson;
  if Trim(AJson) = '' then Exit;
  try
    Data := GetJSON(AJson);
    try
      if not (Data is TJSONObject) then Exit;
      Root := TJSONObject(Data);
      for I := Pred(Root.Count) downto 0 do begin
        if SameText(Root.Names[I], 'api_key') or SameText(Root.Names[I], 'authorization') then
          Root.Delete(I);
      end;
      Result := Root.AsJSON;
    finally
      Data.Free;
    end;
  except
    Result := AJson;
  end;
end;

function TrimContent(const S: string): string;
begin
  Result := Trim(S);
end;

function ExtractJsonFenceStrict(const Text: string; out AInner: string): Boolean;
var
  Marker: string;
  StartI, EndI, TailStart: Integer;
  Before, After: string;
begin
  Result := False;
  AInner := '';
  Marker := '```json';
  StartI := Pos(Marker, Text);
  if StartI = 0 then Exit;
  Before := Trim(Copy(Text, 1, StartI - 1));
  if Before <> '' then Exit;
  StartI := StartI + Length(Marker);
  if (StartI <= Length(Text)) and (Text[StartI] in [#10, #13, #32, #9]) then begin
    while (StartI <= Length(Text)) and (Text[StartI] in [#10, #13, #32, #9]) do
      Inc(StartI);
  end;
  EndI := Pos('```', Copy(Text, StartI, MaxInt));
  if EndI = 0 then Exit;
  AInner := Trim(Copy(Text, StartI, EndI - 1));
  TailStart := StartI + EndI - 1 + 3;
  After := Trim(Copy(Text, TailStart, MaxInt));
  Result := After = '';
end;

function ExtractStrictTextToolJson(const AContent: string): string;
var
  T, Inner: string;
begin
  Result := '';
  T := TrimContent(AContent);
  if T = '' then Exit;
  if ExtractJsonFenceStrict(T, Inner) then begin
    Result := Inner;
    Exit;
  end;
  if (Length(T) >= 2) and (T[1] = '{') and (T[Length(T)] = '}') then
    Result := T;
end;

function ToolNameAllowedInDefs(const AName: string;
  const ADefs: array of TToolDef): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := Low(ADefs) to High(ADefs) do
    if SameText(ADefs[I].Name, AName) then
      Exit(True);
end;

function TryParseStrictTextToolCalls(const AContent: string;
  const AAllowedTools: array of TToolDef; const AIdPrefix: string;
  out AToolCalls: TToolCallArray; out AError: string): Boolean;
var
  JsonText: string;
  Data: TJSONData;
  Root: TJSONObject;
  Name, ArgsJson: string;
  ArgsNode: TJSONData;
  ParseErr: string;
  ArgsObj: TJSONObject;
  Dummy: TToolCall;
  I: Integer;
begin
  Result := False;
  AError := '';
  SetLength(AToolCalls, 0);
  JsonText := ExtractStrictTextToolJson(AContent);
  if JsonText = '' then
    Exit;
  try
    Data := GetJSON(JsonText);
    try
      if not (Data is TJSONObject) then begin
        AError := 'Text tool call must be a single JSON object.';
        Exit;
      end;
      Root := TJSONObject(Data);
      if (Root.Find('name') = nil) or (Root.Find('arguments') = nil) then begin
        AError := 'Text tool call must include name and arguments.';
        Exit;
      end;
      for I := 0 to Pred(Root.Count) do begin
        if not SameText(Root.Names[I], 'name') and not SameText(Root.Names[I], 'arguments') then begin
          AError := 'Text tool call object must contain only name and arguments.';
          Exit;
        end;
      end;
      if not (Root.Find('name') is TJSONString) then begin
        AError := 'Tool name must be a string.';
        Exit;
      end;
      Name := TJSONString(Root.Find('name')).AsString;
      if Trim(Name) = '' then begin
        AError := 'Tool name is empty.';
        Exit;
      end;
      if not ToolNameAllowedInDefs(Name, AAllowedTools) then begin
        AError := 'Tool not available: ' + Name;
        Exit;
      end;
      ArgsNode := Root.Find('arguments');
      if ArgsNode is TJSONString then
        ArgsJson := TJSONString(ArgsNode).AsString
      else if (ArgsNode is TJSONObject) or (ArgsNode is TJSONArray) then
        ArgsJson := ArgsNode.AsJSON
      else begin
        AError := 'arguments must be an object or JSON string.';
        Exit;
      end;
      if not JsonToolArgumentsWellFormed(ArgsJson) then begin
        AError := 'arguments JSON is invalid.';
        Exit;
      end;
      if not TryParseToolArguments(Name, ArgsJson, ArgsObj, ParseErr) then begin
        AError := ParseErr;
        Exit;
      end;
      ArgsObj.Free;
      SetLength(AToolCalls, 1);
      Dummy.Id := AIdPrefix + '0';
      Dummy.Name := Name;
      Dummy.ArgumentsJson := ArgsJson;
      AToolCalls[0] := Dummy;
      Result := True;
    finally
      Data.Free;
    end;
  except
    on E: Exception do
      AError := E.Message;
  end;
end;

function AssistantDisplayContent(const AContent: string;
  const AToolCalls: TToolCallArray): string;
var
  T: string;
begin
  if Length(AToolCalls) = 0 then
    Exit(AContent);
  T := Trim(AContent);
  if T = '' then
    Exit('');
  if ExtractStrictTextToolJson(T) <> '' then
    Exit('');
  Result := AContent;
end;

function ExtractFunctionArgumentsJson(AFuncObj: TJSONObject): string;
var
  Node: TJSONData;
begin
  Result := '{}';
  if not Assigned(AFuncObj) then Exit;
  Node := AFuncObj.Find('arguments');
  if Node = nil then Exit;
  case Node.JSONType of
    jtString: Result := Node.AsString;
    jtObject, jtArray: Result := Node.AsJSON;
  else
    Result := '{}';
  end;
end;

procedure AppendParseFailure(var AFailures: TStringArray; const AMsg: string);
var
  N: Integer;
begin
  N := Length(AFailures);
  SetLength(AFailures, N + 1);
  AFailures[N] := AMsg;
end;

function ApplyOpenAiCompletionJson(var AResult: TOpenAiParseResult;
  const ARootObj: TJSONObject; out AParseFailures: TStringArray): Boolean;
var
  ChoicesArray, ToolCallsArray: TJSONArray;
  ChoiceObj, MsgObj, ToolCallObj, FuncObj, UsageObj: TJSONObject;
  I, ValidCount: Integer;
  Call: TToolCall;
  Temp: array of TToolCall;
begin
  SetLength(AParseFailures, 0);
  Result := False;
  AResult.Content := '';
  SetLength(AResult.ToolCalls, 0);
  AResult.FinishReason := '';
  AResult.PromptTokens := 0;
  AResult.CompletionTokens := 0;
  AResult.TotalTokens := 0;
  SetLength(AResult.ParseFailures, 0);

  if ARootObj.IndexOfName('error') >= 0 then begin
    if ARootObj.Types['error'] = jtObject then
      AResult.ErrorMessage := ARootObj.Objects['error'].Get('message', 'Unknown API Error')
    else
      AResult.ErrorMessage := ARootObj.Get('error', 'Unknown API Error');
    Exit;
  end;

  if ARootObj.IndexOfName('choices') < 0 then begin
    AResult.ErrorMessage := 'Missing choices in completion response.';
    Exit;
  end;

  ChoicesArray := ARootObj.Arrays['choices'];
  if ChoicesArray.Count = 0 then begin
    AResult.ErrorMessage := 'Empty choices array.';
    Exit;
  end;

  ChoiceObj := ChoicesArray.Objects[0];
  AResult.FinishReason := ChoiceObj.Get('finish_reason', '');
  if ChoiceObj.IndexOfName('message') < 0 then begin
    AResult.ErrorMessage := 'Missing message in choice.';
    Exit;
  end;

  MsgObj := ChoiceObj.Objects['message'];
  AResult.Content := MsgObj.Get('content', '');

  ValidCount := 0;
  SetLength(Temp, 0);
  if MsgObj.IndexOfName('tool_calls') >= 0 then begin
    ToolCallsArray := MsgObj.Arrays['tool_calls'];
    for I := 0 to ToolCallsArray.Count - 1 do begin
      if not (ToolCallsArray.Items[I] is TJSONObject) then begin
        AppendParseFailure(AParseFailures, Format('tool_calls[%d] is not an object', [I]));
        Continue;
      end;
      ToolCallObj := TJSONObject(ToolCallsArray.Items[I]);
      Call.Id := ToolCallObj.Get('id', Format('call_%d', [I]));
      Call.Name := '';
      Call.ArgumentsJson := '{}';
      if ToolCallObj.IndexOfName('function') >= 0 then begin
        FuncObj := ToolCallObj.Objects['function'];
        Call.Name := FuncObj.Get('name', '');
        Call.ArgumentsJson := ExtractFunctionArgumentsJson(FuncObj);
      end;
      if Trim(Call.Name) = '' then begin
        AppendParseFailure(AParseFailures, Format('tool_calls[%d] missing function name', [I]));
        Continue;
      end;
      SetLength(Temp, ValidCount + 1);
      Temp[ValidCount] := Call;
      Inc(ValidCount);
    end;
    SetLength(AResult.ToolCalls, ValidCount);
    for I := 0 to ValidCount - 1 do
      AResult.ToolCalls[I] := Temp[I];
  end;

  if ARootObj.IndexOfName('usage') >= 0 then begin
    UsageObj := ARootObj.Objects['usage'];
    AResult.PromptTokens := UsageObj.Get('prompt_tokens', 0);
    AResult.CompletionTokens := UsageObj.Get('completion_tokens', 0);
    AResult.TotalTokens := UsageObj.Get('total_tokens', 0);
  end;

  AResult.Success := True;
  AResult.ErrorMessage := '';
  Result := True;
end;

{ TOpenAiStreamAccumulator }

procedure TOpenAiStreamAccumulator.Reset;
begin
  FContent := '';
  SetLength(FToolIds, 0);
  SetLength(FToolNames, 0);
  SetLength(FToolArgFragments, 0);
  FFinishReason := '';
end;

procedure TOpenAiStreamAccumulator.EnsureToolSlot(AIndex: Integer);
var
  I, N: Integer;
begin
  N := Length(FToolIds);
  if AIndex < N then Exit;
  SetLength(FToolIds, AIndex + 1);
  SetLength(FToolNames, AIndex + 1);
  SetLength(FToolArgFragments, AIndex + 1);
  for I := N to AIndex do begin
    FToolIds[I] := '';
    FToolNames[I] := '';
    FToolArgFragments[I] := '';
  end;
end;

procedure TOpenAiStreamAccumulator.NoteFinishReason(const AReason: string);
begin
  if Trim(AReason) <> '' then
    FFinishReason := AReason;
end;

procedure TOpenAiStreamAccumulator.ApplyDelta(const ADeltaObj: TJSONObject);
var
  ToolArr: TJSONArray;
  I, Idx: Integer;
  Item, FuncObj: TJSONObject;
  Frag: string;
begin
  if ADeltaObj.Find('content') <> nil then
    FContent := FContent + ADeltaObj.Get('content', '');
  if ADeltaObj.Find('tool_calls') = nil then Exit;
  ToolArr := ADeltaObj.Arrays['tool_calls'];
  for I := 0 to ToolArr.Count - 1 do begin
    if not (ToolArr.Items[I] is TJSONObject) then Continue;
    Item := TJSONObject(ToolArr.Items[I]);
    Idx := Item.Get('index', I);
    EnsureToolSlot(Idx);
    if Item.Find('id') <> nil then
      FToolIds[Idx] := FToolIds[Idx] + Item.Get('id', '');
    if Item.IndexOfName('function') >= 0 then begin
      FuncObj := Item.Objects['function'];
      if FuncObj.Find('name') <> nil then
        FToolNames[Idx] := FToolNames[Idx] + FuncObj.Get('name', '');
      if FuncObj.Find('arguments') <> nil then begin
        Frag := FuncObj.Get('arguments', '');
        FToolArgFragments[Idx] := FToolArgFragments[Idx] + Frag;
      end;
    end;
  end;
end;

function TOpenAiStreamAccumulator.BuildResponse: TOpenAiParseResult;
var
  I, N: Integer;
begin
  Result.Success := True;
  Result.ErrorMessage := '';
  Result.Content := FContent;
  Result.FinishReason := FFinishReason;
  Result.PromptTokens := 0;
  Result.CompletionTokens := 0;
  Result.TotalTokens := 0;
  SetLength(Result.ParseFailures, 0);
  N := Length(FToolIds);
  SetLength(Result.ToolCalls, 0);
  for I := 0 to N - 1 do begin
    if (Trim(FToolNames[I]) = '') and (Trim(FToolArgFragments[I]) = '') then
      Continue;
    SetLength(Result.ToolCalls, Length(Result.ToolCalls) + 1);
    with Result.ToolCalls[High(Result.ToolCalls)] do begin
      if Trim(FToolIds[I]) <> '' then
        Id := FToolIds[I]
      else
        Id := Format('stream_call_%d', [I]);
      Name := FToolNames[I];
      ArgumentsJson := FToolArgFragments[I];
      if not JsonToolArgumentsWellFormed(ArgumentsJson) then
        ArgumentsJson := '{}';
    end;
  end;
end;

function ParseOpenAiSseBody(const ASseBody: string; out AParseFailures: TStringArray): TOpenAiParseResult;
var
  Acc: TOpenAiStreamAccumulator;
  Lines: TStringList;
  I: Integer;
  Line, Payload: string;
  Data: TJSONData;
  Root, ChoiceObj, DeltaObj: TJSONObject;
  Choices: TJSONArray;
  Parsed: TOpenAiParseResult;
  Fail: array of string;
begin
  SetLength(AParseFailures, 0);
  Acc := TOpenAiStreamAccumulator.Create;
  Lines := TStringList.Create;
  try
    Acc.Reset;
    Lines.Text := ASseBody;
    for I := 0 to Lines.Count - 1 do begin
      Line := Trim(Lines[I]);
      if not StartsStr('data:', Line) then Continue;
      Payload := Trim(Copy(Line, 6, MaxInt));
      if Payload = '' then Continue;
      if Payload = '[DONE]' then Break;
      try
        Data := GetJSON(Payload);
        try
          if not (Data is TJSONObject) then Continue;
          Root := TJSONObject(Data);
          if Root.IndexOfName('choices') < 0 then Continue;
          Choices := Root.Arrays['choices'];
          if Choices.Count = 0 then Continue;
          ChoiceObj := Choices.Objects[0];
          if ChoiceObj.Find('finish_reason') <> nil then
            Acc.NoteFinishReason(ChoiceObj.Get('finish_reason', ''));
          if ChoiceObj.IndexOfName('delta') >= 0 then begin
            DeltaObj := ChoiceObj.Objects['delta'];
            Acc.ApplyDelta(DeltaObj);
          end else if ChoiceObj.IndexOfName('message') >= 0 then begin
            Parsed.Success := False;
            if ApplyOpenAiCompletionJson(Parsed, Root, Fail) then
              AParseFailures := Fail;
          end;
        finally
          Data.Free;
        end;
      except
        on E: Exception do
          AppendParseFailure(AParseFailures, 'SSE chunk: ' + E.Message);
      end;
    end;
    Result := Acc.BuildResponse;
    if Acc.FinishReason <> '' then
      Result.FinishReason := Acc.FinishReason;
  finally
    Lines.Free;
    Acc.Free;
  end;
end;

end.
