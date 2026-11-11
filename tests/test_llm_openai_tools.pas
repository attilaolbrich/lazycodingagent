program test_llm_openai_tools;
{$mode objfpc}{$H+}
uses
  SysUtils, fpjson, uAgentTypes, uAgentToolBase, uLlmClient, uLlmToolCalling;

procedure AssertTrue(ACond: Boolean; const AMsg: string);
begin
  if not ACond then
    raise Exception.Create(AMsg);
end;

procedure TestParseNativeToolCalls;
var
  Client: TLlmClient;
  Resp: TLlmResponse;
  Json: string;
begin
  Client := TLlmClient.Create;
  try
    Json := '{"choices":[{"message":{"role":"assistant","content":"","tool_calls":[' +
      '{"id":"call_1","type":"function","function":{"name":"write_file","arguments":"{\"path\":\"a.go\"}"}}' +
      ']},"finish_reason":"tool_calls"}]}';
    Resp := Client.ParseOpenAiResponsePublic(Json);
    AssertTrue(Resp.Success, 'parse success');
    AssertTrue(Length(Resp.ToolCalls) = 1, 'one tool call');
    AssertTrue(SameText(Resp.ToolCalls[0].Name, 'write_file'), 'tool name');
    AssertTrue(Pos('a.go', Resp.ToolCalls[0].ArgumentsJson) > 0, 'args');
  finally
    Client.Free;
  end;
end;

procedure TestParseMultipleToolCalls;
var
  Client: TLlmClient;
  Resp: TLlmResponse;
begin
  Client := TLlmClient.Create;
  try
    Resp := Client.ParseOpenAiResponsePublic(
      '{"choices":[{"message":{"content":"","tool_calls":[' +
      '{"id":"a","function":{"name":"read_file","arguments":"{}"}},' +
      '{"id":"b","function":{"name":"write_file","arguments":"{}"}}' +
      ']}}]}');
    AssertTrue(Length(Resp.ToolCalls) = 2, 'two calls');
  finally
    Client.Free;
  end;
end;

procedure TestStrictTextToolCall;
var
  Defs: array of TToolDef;
  Calls: TToolCallArray;
  Err: string;
  Def: TToolDef;
begin
  SetLength(Defs, 1);
  Def.Name := 'write_file';
  Def.Description := 'write';
  SetLength(Def.Params, 0);
  Defs[0] := Def;
  AssertTrue(TryParseStrictTextToolCalls(
    '{"name":"write_file","arguments":{"path":"main.go","content":"hi"}}',
    Defs, 'text_call_1_', Calls, Err), Err);
  AssertTrue(Length(Calls) = 1, 'parsed one');
  if TryParseStrictTextToolCalls(
    'Here is an example: {"name":"write_file","arguments":{}}',
    Defs, 'x_', Calls, Err) then
    raise Exception.Create('prose must not parse');
  SetLength(Calls, 0);
end;

procedure TestStreamingAccumulator;
var
  Sse: string;
  Resp: TLlmResponse;
  Failures: array of string;
begin
  Sse := 'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_x","function":{"name":"write_file","arguments":"{\"path\":"}}]}}]}' + LineEnding +
    'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\"x\"}"}}]}}]}' + LineEnding +
    'data: [DONE]' + LineEnding;
  Resp := ParseOpenAiSseBody(Sse, Failures);
  AssertTrue(Length(Resp.ToolCalls) >= 1, 'stream tool');
  AssertTrue(SameText(Resp.ToolCalls[0].Name, 'write_file'), 'stream name');
  AssertTrue(JsonToolArgumentsWellFormed(Resp.ToolCalls[0].ArgumentsJson), 'stream args well formed');
end;

begin
  TestParseNativeToolCalls;
  TestParseMultipleToolCalls;
  TestStrictTextToolCall;
  TestStreamingAccumulator;
  WriteLn('LLM OpenAI tool tests passed.');
end.
