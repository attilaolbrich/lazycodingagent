program test_llm_message_repair;
{$mode objfpc}{$H+}
uses
  SysUtils, uAgentTypes, uLlmMessageRepair;

procedure AssertTrue(ACond: Boolean; const AMsg: string);
begin
  if not ACond then
    raise Exception.Create(AMsg);
end;

procedure AddToolCall(var AMsg: TChatMessage; const AId, AName: string);
var
  N: Integer;
begin
  N := Length(AMsg.ToolCalls);
  SetLength(AMsg.ToolCalls, N + 1);
  AMsg.ToolCalls[N].Id := AId;
  AMsg.ToolCalls[N].Name := AName;
  AMsg.ToolCalls[N].ArgumentsJson := '{}';
end;

function ToolMsg(const AId, AContent: string): TChatMessage;
begin
  Result := StringToChatRole('tool');
  Result.ToolCallId := AId;
  Result.Content := AContent;
end;

procedure TestMissingToolBeforeUser;
var
  InMsgs, OutMsgs: TChatMessageArray;
  Asst, UserMsg: TChatMessage;
  Changed: Boolean;
begin
  Asst := StringToChatRole('assistant');
  Asst.Content := '';
  AddToolCall(Asst, 'call_a', 'read_file');
  AddToolCall(Asst, 'call_b', 'write_file');
  UserMsg := StringToChatRole('user');
  UserMsg.Content := 'try again';
  InMsgs := [Asst, UserMsg];
  Changed := NormalizeAssistantToolBlocks(InMsgs, OutMsgs);
  AssertTrue(Changed, 'should repair');
  AssertTrue(Length(OutMsgs) = 4, 'assistant + 2 tools + user');
  AssertTrue(OutMsgs[1].Role = crTool, 'tool1');
  AssertTrue(SameText(OutMsgs[1].ToolCallId, 'call_a'), 'call_a first');
  AssertTrue(SameText(OutMsgs[2].ToolCallId, 'call_b'), 'call_b second');
end;

procedure TestWrongToolOrder;
var
  InMsgs, OutMsgs: TChatMessageArray;
  Asst, UserMsg: TChatMessage;
begin
  Asst := StringToChatRole('assistant');
  AddToolCall(Asst, 'call_first', 'a');
  AddToolCall(Asst, 'call_second', 'b');
  InMsgs := [Asst, ToolMsg('call_second', '{}'), ToolMsg('call_first', '{}')];
  NormalizeAssistantToolBlocks(InMsgs, OutMsgs);
  AssertTrue(SameText(OutMsgs[1].ToolCallId, 'call_first'), 'reorder first');
  AssertTrue(SameText(OutMsgs[2].ToolCallId, 'call_second'), 'reorder second');
end;

procedure TestMisplacedToolAfterUser;
var
  InMsgs, OutMsgs: TChatMessageArray;
  Asst, UserMsg: TChatMessage;
begin
  Asst := StringToChatRole('assistant');
  AddToolCall(Asst, 'call_orphan', 'browser_close');
  UserMsg := StringToChatRole('user');
  UserMsg.Content := 'retry';
  InMsgs := [Asst, UserMsg, ToolMsg('call_orphan', '{"success":true}')];
  NormalizeAssistantToolBlocks(InMsgs, OutMsgs);
  AssertTrue(SameText(OutMsgs[1].ToolCallId, 'call_orphan'), 'orphan moved before user');
  AssertTrue(OutMsgs[2].Role = crUser, 'user after tools');
  AssertTrue(Length(OutMsgs) = 3, 'no duplicate orphan');
end;

procedure TestIsMissingToolOutputError;
begin
  AssertTrue(IsMissingToolOutputError(
    'No tool output found for function call call_341fff.'), 'detect phrase');
  AssertTrue(not IsMissingToolOutputError('rate limited'), 'other errors');
end;

procedure TestCollapseInterruptedTurn;
var
  InMsgs, OutMsgs: TChatMessageArray;
  Asst, UserMsg, T1, T2: TChatMessage;
  Changed: Boolean;
begin
  Asst := StringToChatRole('assistant');
  AddToolCall(Asst, 'call_a', 'browser_navigate');
  AddToolCall(Asst, 'call_b', 'browser_click');
  T1 := MakeInterruptedToolMessage('call_a');
  T2 := MakeInterruptedToolMessage('call_b');
  UserMsg := StringToChatRole('user');
  UserMsg.Content := 'try again';
  InMsgs := [Asst, T1, T2, UserMsg];
  Changed := CollapseFullyInterruptedTurns(InMsgs, OutMsgs);
  AssertTrue(Changed, 'collapsed');
  AssertTrue(Length(OutMsgs) = 2, 'assistant note + user');
  AssertTrue(Length(OutMsgs[0].ToolCalls) = 0, 'no tool_calls');
  AssertTrue(Pos('ended before tools finished', OutMsgs[0].Content) > 0, 'note');
end;

procedure TestMixedTurnNotCollapsed;
var
  InMsgs, OutMsgs: TChatMessageArray;
  Asst: TChatMessage;
  Changed: Boolean;
begin
  Asst := StringToChatRole('assistant');
  AddToolCall(Asst, 'call_a', 'read_file');
  InMsgs := [Asst, ToolMsg('call_a', '{"success":true}')];
  Changed := CollapseFullyInterruptedTurns(InMsgs, OutMsgs);
  AssertTrue(not Changed, 'real result kept');
  AssertTrue(Length(OutMsgs[0].ToolCalls) = 1, 'still has calls');
end;

procedure TestPrepareMessagesStripsErrorAssistant;
var
  InMsgs, OutMsgs: TChatMessageArray;
  ErrAsst, UserMsg: TChatMessage;
begin
  UserMsg := StringToChatRole('user');
  UserMsg.Content := 'hi';
  ErrAsst := StringToChatRole('assistant');
  ErrAsst.Content := '❌ LLM Request Error: bad';
  InMsgs := [UserMsg, ErrAsst, UserMsg];
  OutMsgs := PrepareMessagesForLlmApi(InMsgs);
  AssertTrue(Length(OutMsgs) = 2, 'dropped error assistant');
end;

begin
  TestMissingToolBeforeUser;
  TestWrongToolOrder;
  TestMisplacedToolAfterUser;
  TestIsMissingToolOutputError;
  TestCollapseInterruptedTurn;
  TestMixedTurnNotCollapsed;
  TestPrepareMessagesStripsErrorAssistant;
  WriteLn('test_llm_message_repair: OK');
end.