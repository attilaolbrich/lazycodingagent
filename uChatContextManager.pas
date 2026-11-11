unit uChatContextManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, uAgentTypes, uLlmClient, uAgentToolBase;

function FinishReasonIndicatesTruncation(const AReason: string): Boolean;

function IsContextLengthError(const AMessage: string): Boolean;

function EstimatePromptTokens(const AMessages: TChatMessageArray;
  const ATools: TToolDefArray; ALastReportedPromptTokens: Integer): Integer;

function ComputePromptTokenBudget(AContextWindowTokens, AMaxOutputTokens: Integer;
  ASummarizeThreshold: Double): Integer;

function ShouldProactivelySummarize(AEstimatedPromptTokens, AContextWindowTokens,
  AMaxOutputTokens: Integer; ASummarizeThreshold: Double;
  ALastReportedPromptTokens: Integer): Boolean;

function FindSafeKeepFromIndex(const AMessages: TChatMessageArray;
  AKeepRecentMessages: Integer): Integer;

function SerializeMessagesForSummary(const AMessages: TChatMessageArray;
  AFromIndex, AToIndex: Integer): string;

procedure BuildSummarizationMessages(const AHistoryText: string;
  out AMessages: TChatMessageArray);

procedure ApplySummaryToHistory(var AMessages: TChatMessageArray;
  const ASummary: string; AMiddleFromIndex, AMiddleToIndex: Integer);

function AnyToolCallArgsInvalid(const AToolCalls: TToolCallArray): Boolean;

function ResponseNeedsTruncationRetry(const AResp: TLlmResponse): Boolean;

function RetryMaxTokensAfterTruncation(AUserMax, AAttempt: Integer): Integer;

function ClampMaxOutputTokens(AValue: Integer): Integer;

function RunConversationSummary(AClient: TLlmClient;
  const AMessages: TChatMessageArray; AFromIndex, AToIndex: Integer;
  out ASummary: string; out AError: string): Boolean;

implementation

uses
  uAgentExecutionLog, uChatImageStore;

const
  ATTACHMENT_TOKEN_FLOOR = 800;

function FinishReasonIndicatesTruncation(const AReason: string): Boolean;
var
  R: string;
begin
  R := LowerCase(Trim(AReason));
  Result := (R = 'length') or (R = 'max_tokens');
end;

function IsContextLengthError(const AMessage: string): Boolean;
var
  L: string;
begin
  L := LowerCase(AMessage);
  Result := (Pos('context_length_exceeded', L) > 0) or
    (Pos('maximum context length', L) > 0) or
    (Pos('context length exceeded', L) > 0) or
    (Pos('prompt is too long', L) > 0) or
    (Pos('too many tokens', L) > 0) and (Pos('maximum', L) > 0) or
    (Pos('reduce the length', L) > 0) and (Pos('messages', L) > 0);
end;

function EstimateTextTokens(const S: string): Integer;
begin
  Result := (Length(S) + 3) div 4;
end;

function EstimatePromptTokens(const AMessages: TChatMessageArray;
  const ATools: TToolDefArray; ALastReportedPromptTokens: Integer): Integer;
var
  I, J, K: Integer;
  M: TChatMessage;
  ImgTok: Integer;
  FileSize: Int64;
begin
  if ALastReportedPromptTokens > 0 then
    Exit(ALastReportedPromptTokens);

  Result := 0;
  for I := Low(AMessages) to High(AMessages) do begin
    M := AMessages[I];
    Inc(Result, 4 + EstimateTextTokens(M.Content));
    for K := Low(M.Attachments) to High(M.Attachments) do begin
      FileSize := AttachmentFileSize(M.Attachments[K].RelativePath);
      ImgTok := EstimateTextTokens(IntToStr(FileSize)) + ATTACHMENT_TOKEN_FLOOR;
      if ImgTok < ATTACHMENT_TOKEN_FLOOR then
        ImgTok := ATTACHMENT_TOKEN_FLOOR;
      Inc(Result, ImgTok);
    end;
    for J := Low(M.ToolCalls) to High(M.ToolCalls) do
      Inc(Result, 8 + EstimateTextTokens(M.ToolCalls[J].Name) +
        EstimateTextTokens(M.ToolCalls[J].ArgumentsJson));
    if M.ToolCallId <> '' then
      Inc(Result, 4 + EstimateTextTokens(M.ToolCallId));
  end;

  for I := Low(ATools) to High(ATools) do begin
    Inc(Result, 12 + EstimateTextTokens(ATools[I].Name) +
      EstimateTextTokens(ATools[I].Description));
    for J := Low(ATools[I].Params) to High(ATools[I].Params) do
      Inc(Result, EstimateTextTokens(ATools[I].Params[J].Name));
  end;
end;

function ComputePromptTokenBudget(AContextWindowTokens, AMaxOutputTokens: Integer;
  ASummarizeThreshold: Double): Integer;
var
  Reserve, Budget: Integer;
  T: Double;
begin
  if AContextWindowTokens <= 0 then
    AContextWindowTokens := DEFAULT_CONTEXT_WINDOW_TOKENS;
  T := ASummarizeThreshold;
  if T <= 0 then T := DEFAULT_SUMMARIZE_THRESHOLD;
  if T > 0.98 then T := 0.98;
  Reserve := AMaxOutputTokens + CONTEXT_RESERVE_OVERHEAD;
  Budget := AContextWindowTokens - Reserve;
  if Budget < 1024 then Budget := 1024;
  Result := Trunc(Budget * T);
end;

function ShouldProactivelySummarize(AEstimatedPromptTokens, AContextWindowTokens,
  AMaxOutputTokens: Integer; ASummarizeThreshold: Double;
  ALastReportedPromptTokens: Integer): Boolean;
var
  Est: Integer;
begin
  Est := AEstimatedPromptTokens;
  if Est <= 0 then
    Est := EstimatePromptTokens([], [], ALastReportedPromptTokens);
  Result := Est >= ComputePromptTokenBudget(AContextWindowTokens, AMaxOutputTokens,
    ASummarizeThreshold);
end;

function AssistantToolBlockLength(const AMessages: TChatMessageArray; AStart: Integer): Integer;
var
  N, I: Integer;
begin
  Result := 1;
  if (AStart < 0) or (AStart > High(AMessages)) then Exit(0);
  if AMessages[AStart].Role <> crAssistant then Exit(1);
  if Length(AMessages[AStart].ToolCalls) = 0 then Exit(1);
  N := Length(AMessages[AStart].ToolCalls);
  I := AStart + 1;
  while (I <= High(AMessages)) and (AMessages[I].Role = crTool) and (Result <= N + 5) do begin
    Inc(Result);
    Inc(I);
  end;
end;

function FindSafeKeepFromIndex(const AMessages: TChatMessageArray;
  AKeepRecentMessages: Integer): Integer;
var
  I, Count, BlockLen: Integer;
begin
  Result := Length(AMessages);
  if Length(AMessages) <= 1 then Exit(Result);

  Count := 0;
  I := High(AMessages);
  while I >= 0 do begin
    if AMessages[I].Role = crSystem then begin
      Dec(I);
      Continue;
    end;
    if (AMessages[I].Role = crAssistant) and (Length(AMessages[I].ToolCalls) > 0) then begin
      BlockLen := AssistantToolBlockLength(AMessages, I);
      if Count + BlockLen > AKeepRecentMessages then
        Break;
      Inc(Count, BlockLen);
      I := I - BlockLen;
      Continue;
    end;
    Inc(Count);
    if Count >= AKeepRecentMessages then begin
      Result := I;
      Break;
    end;
    Dec(I);
  end;

  if Result < 1 then Result := 1;
  while (Result > 1) and (AMessages[Result].Role = crTool) do
    Dec(Result);
  if (Result > 0) and (AMessages[Result].Role = crAssistant) and
     (Length(AMessages[Result].ToolCalls) > 0) then begin
    BlockLen := AssistantToolBlockLength(AMessages, Result);
    if Result + BlockLen - 1 <= High(AMessages) then ;
  end;
end;

function SerializeMessagesForSummary(const AMessages: TChatMessageArray;
  AFromIndex, AToIndex: Integer): string;
var
  I: Integer;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    if AFromIndex < 0 then AFromIndex := 0;
    if AToIndex > High(AMessages) then AToIndex := High(AMessages);
    for I := AFromIndex to AToIndex do begin
      if AMessages[I].Role = crSystem then Continue;
      SB.AppendLine('[' + ChatRoleToString(AMessages[I].Role) + ']');
      SB.AppendLine(FormatMessageBodyForLog(AMessages[I]));
      SB.AppendLine;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

procedure BuildSummarizationMessages(const AHistoryText: string;
  out AMessages: TChatMessageArray);
var
  SysMsg, UserMsg: TChatMessage;
begin
  SetLength(AMessages, 2);
  SysMsg := StringToChatRole('system');
  SysMsg.Content :=
    'You compress chat history for a coding agent. Produce a concise factual summary ' +
    'that preserves: user goals, decisions, file paths touched, errors, and unfinished work. ' +
    'Use bullet points. Do not invent facts.';
  UserMsg := StringToChatRole('user');
  UserMsg.Content := 'Summarize this conversation segment for continuation:' + LineEnding +
    LineEnding + AHistoryText;
  AMessages[0] := SysMsg;
  AMessages[1] := UserMsg;
end;

procedure ApplySummaryToHistory(var AMessages: TChatMessageArray;
  const ASummary: string; AMiddleFromIndex, AMiddleToIndex: Integer);
var
  NewMsgs: TChatMessageArray;
  I, Cnt, KeepFrom: Integer;
  SumMsg: TChatMessage;
begin
  if Length(AMessages) = 0 then Exit;
  KeepFrom := AMiddleToIndex + 1;
  if KeepFrom > High(AMessages) then Exit;
  if AMiddleFromIndex > AMiddleToIndex then Exit;

  SumMsg := StringToChatRole('user');
  SumMsg.Content := '[Conversation summary — earlier turns compressed]' + LineEnding +
    LineEnding + Trim(ASummary);

  Cnt := 2 + (High(AMessages) - KeepFrom + 1);
  SetLength(NewMsgs, Cnt);
  NewMsgs[0] := AMessages[0];
  NewMsgs[1] := SumMsg;
  I := 2;
  for Cnt := KeepFrom to High(AMessages) do begin
    NewMsgs[I] := AMessages[Cnt];
    Inc(I);
  end;
  AMessages := NewMsgs;
end;

function AnyToolCallArgsInvalid(const AToolCalls: TToolCallArray): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := Low(AToolCalls) to High(AToolCalls) do
    if not JsonToolArgumentsWellFormed(AToolCalls[I].ArgumentsJson) then
      Exit(True);
end;

function ResponseNeedsTruncationRetry(const AResp: TLlmResponse): Boolean;
begin
  if not AResp.Success then Exit(False);
  if not FinishReasonIndicatesTruncation(AResp.FinishReason) then Exit(False);
  if Length(AResp.ToolCalls) = 0 then Exit(True);
  Result := AnyToolCallArgsInvalid(AResp.ToolCalls);
end;

function RetryMaxTokensAfterTruncation(AUserMax, AAttempt: Integer): Integer;
var
  Bumped: Integer;
begin
  Bumped := AUserMax * (2 shl AAttempt);
  if AUserMax < RECOMMENDED_MIN_OUTPUT_TOKENS then
    Bumped := Max(Bumped, 4096);
  Result := Min(Bumped, TRUNCATION_RETRY_CAP_TOKENS);
  if Result <= AUserMax then
    Result := Min(AUserMax + 4096, TRUNCATION_RETRY_CAP_TOKENS);
end;

function ClampMaxOutputTokens(AValue: Integer): Integer;
begin
  Result := AValue;
  if Result < MIN_MAX_OUTPUT_TOKENS then Result := MIN_MAX_OUTPUT_TOKENS;
  if Result > MAX_MAX_OUTPUT_TOKENS then Result := MAX_MAX_OUTPUT_TOKENS;
end;

function RunConversationSummary(AClient: TLlmClient;
  const AMessages: TChatMessageArray; AFromIndex, AToIndex: Integer;
  out ASummary: string; out AError: string): Boolean;
var
  Req: TChatMessageArray;
  EmptyTools: array of TToolDef;
  Resp: TLlmResponse;
  SavedMax: Integer;
begin
  Result := False;
  ASummary := '';
  AError := '';
  SetLength(EmptyTools, 0);
  BuildSummarizationMessages(SerializeMessagesForSummary(AMessages, AFromIndex, AToIndex), Req);
  SavedMax := AClient.MaxTokens;
  try
    AClient.MaxTokens := SUMMARIZE_MAX_OUTPUT_TOKENS;
    Resp := AClient.SendChatCompletion(Req, EmptyTools);
  finally
    AClient.MaxTokens := SavedMax;
  end;
  if not Resp.Success then begin
    AError := Resp.ErrorMessage;
    Exit;
  end;
  ASummary := Trim(Resp.Content);
  Result := ASummary <> '';
  if not Result then
    AError := 'Summarization returned empty content.';
end;

end.
