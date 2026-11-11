unit uAgentEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, uAppTypes, uAgentTypes, uLlmClient, uAgentTools, uAgentRules,
  uAgentExecutionLog, uAgentToolErrorLog, uChatContextManager, uLlmPromptCacheTypes,
  uLlmPromptSegments, uLlmToolCalling, uLlmCacheCapabilities;

type
  { Event types for UI notification }
  TAgentStateChangeEvent = procedure(Sender: TObject; AOldState, ANewState: TAgentState;
    AStep, AMaxSteps: Integer) of object;
  TAgentMessageEvent = procedure(Sender: TObject; const AMessage: TChatMessage) of object;
  TAgentToolCallEvent = procedure(Sender: TObject; const AToolName, AArgs: string) of object;
  TAgentToolResultEvent = procedure(Sender: TObject; const AToolName, AArgsJson: string;
    const AResult: TToolExecutionResult) of object;
  TAgentExecutionLogEvent = procedure(Sender: TObject; AEntryIndex: Integer) of object;
  TAgentToolErrorLogEvent = procedure(Sender: TObject; AEntryIndex: Integer) of object;

  { TAgentEngine - Coordinates conversation, autonomous ReAct loops, and tool execution }
  TAgentEngine = class
  private
    FState: TAgentState;
    FClient: TLlmClient;
    FTools: TAgentToolRegistry;
    FContext: TAgentToolContext;
    FMessages: array of TChatMessage;
    FMaxSteps: Integer;
    FCancelRequested: Boolean;
    FRunActive: Boolean;
    FInWorkerRun: Boolean;
    FDestroying: Boolean;
    FRunThread: TThread;
    FRunLock: TCriticalSection;
    FDataLock: TCriticalSection;

    FOnStateChange: TAgentStateChangeEvent;
    FOnMessageAdded: TAgentMessageEvent;
    FOnToolCall: TAgentToolCallEvent;
    FOnToolResult: TAgentToolResultEvent;
    FOnExecutionLogAdded: TAgentExecutionLogEvent;
    FOnToolErrorAdded: TAgentToolErrorLogEvent;
    FExecutionLog: TAgentExecutionLog;
    FToolErrorLog: TAgentToolErrorLog;

    FSyncOldState: TAgentState;
    FSyncNewState: TAgentState;
    FSyncRunStep: Integer;
    FSyncRunMaxSteps: Integer;
    FSyncMessage: TChatMessage;
    FSyncToolName: string;
    FSyncToolArgs: string;
    FSyncToolResult: TToolExecutionResult;
    FSyncLogEntryIndex: Integer;
    FSyncToolErrorIndex: Integer;
    FSyncRunFailureMessage: string;

    FRunSnapProvider: TLlmProvider;
    FRunSnapApiKey: string;
    FRunSnapBaseUrl: string;
    FRunSnapModel: string;
    FRunSnapTemperature: Double;
    FRunSnapMaxTokens: Integer;
    FRunSnapConnectTimeoutMs: Integer;
    FRunSnapReadTimeoutMs: Integer;
    FRunSnapHttpRetryCount: Integer;
    FRunSnapPromptCacheSettings: TPromptCacheSettings;
    FRunSnapToolCallingCaps: TLlmToolCallingCapabilities;
    FRunSnapLearnWireLogging: Boolean;

    FToolCallingCapabilities: TLlmToolCallingCapabilities;
    FLearnWireLogging: Boolean;
    FAutoSummarizeContext: Boolean;
    FPromptCacheSettings: TPromptCacheSettings;
    FContextWindowTokens: Integer;
    FSummarizeThreshold: Double;
    FLastPromptTokens: Integer;
    FSummarizeAttemptsThisRun: Integer;
    FLastPromptSegments: TPromptSegmentArray;
    FCachedRulesFingerprint: string;
    FCachedRulesText: string;

    function TryCompactConversationHistory(out ANote: string): Boolean;
    function SendCompletionWithTruncationRetry(const AMessages: array of TChatMessage;
      const AToolDefs: array of TToolDef; AStep: Integer; out AResp: TLlmResponse): Boolean;
    function ToolDefinitionsSentInApiPayload: Boolean;
    procedure ApplyTextToolCompatIfNeeded(var AResp: TLlmResponse;
      const AToolDefs: array of TToolDef; AStep: Integer);
    procedure AppendTruncationNoticeIfNeeded(var AContent: string;
      const AFinishReason: string; ATruncationRetriesExhausted: Boolean);

    procedure SetRunProgress(AStep: Integer);
    procedure SetState(ANewState: TAgentState);
    procedure AppendMessage(const AMsg: TChatMessage);
    procedure ApplySystemPrompt(AMode: TWorkspaceMode);
    function BuildSystemPrompt(AMode: TWorkspaceMode): string;
    function GetCancelRequested: Boolean;
    procedure CaptureClientSnapshot;
    procedure ApplyClientSnapshot;
    procedure SyncStateChange;
    procedure SyncMessageAdded;
    procedure SyncToolCall;
    procedure SyncToolResult;
    procedure SyncExecutionLogAdded;
    procedure SyncToolErrorAdded;
    procedure SyncRunFailure;
    procedure NotifyExecutionLogAdded(AEntryIndex: Integer);
    procedure NotifyToolErrorAdded(AEntryIndex: Integer);
    procedure NotifyRunFailure(const AMessage: string);
    procedure WaitForRunComplete;
  public
    constructor Create(const AWorkspaceRoot: string);
    destructor Destroy; override;

    procedure ClearConversation;
    procedure LoadConversation(const AMessages: TChatMessageArray);
    procedure ExportMessages(out AMessages: TChatMessageArray);
    function StartRunAsync(const AUserPrompt: string;
      const AAttachments: array of TChatAttachment; AMode: TWorkspaceMode;
      const AModel: string): Boolean;
    procedure RequestCancel;
    function IsRunActive: Boolean;
    procedure ExecuteRun(const AUserPrompt: string;
      const AAttachments: array of TChatAttachment; AMode: TWorkspaceMode;
      const AModel: string);
    procedure RunThreadFinished;

    function ExecuteToolDirect(const AName, AArgumentsJson: string;
      AMode: TWorkspaceMode): TToolExecutionResult;

    function GetMessageCount: Integer;
    function GetMessage(AIndex: Integer): TChatMessage;

    property State: TAgentState read FState;
    property Client: TLlmClient read FClient;
    property Context: TAgentToolContext read FContext;
    property MaxSteps: Integer read FMaxSteps write FMaxSteps;
    property AutoSummarizeContext: Boolean read FAutoSummarizeContext write FAutoSummarizeContext;
    property ContextWindowTokens: Integer read FContextWindowTokens write FContextWindowTokens;
    property SummarizeThreshold: Double read FSummarizeThreshold write FSummarizeThreshold;
    property PromptCacheSettings: TPromptCacheSettings read FPromptCacheSettings
      write FPromptCacheSettings;
    property ToolCallingCapabilities: TLlmToolCallingCapabilities read FToolCallingCapabilities
      write FToolCallingCapabilities;
    property LearnWireLogging: Boolean read FLearnWireLogging write FLearnWireLogging;

    property OnStateChange: TAgentStateChangeEvent read FOnStateChange write FOnStateChange;
    property OnMessageAdded: TAgentMessageEvent read FOnMessageAdded write FOnMessageAdded;
    property OnToolCall: TAgentToolCallEvent read FOnToolCall write FOnToolCall;
    property OnToolResult: TAgentToolResultEvent read FOnToolResult write FOnToolResult;
    property OnExecutionLogAdded: TAgentExecutionLogEvent read FOnExecutionLogAdded
      write FOnExecutionLogAdded;
    property OnToolErrorAdded: TAgentToolErrorLogEvent read FOnToolErrorAdded
      write FOnToolErrorAdded;
    property ExecutionLog: TAgentExecutionLog read FExecutionLog write FExecutionLog;
    property ToolErrorLog: TAgentToolErrorLog read FToolErrorLog write FToolErrorLog;
    procedure ReportRunException(const E: Exception);
  end;

implementation

uses
  Forms, uAgentRunThread, uAgentToolBase, uChatImageStore;

function TruncationHintForFinishReason(const AReason: string): string;
begin
  if FinishReasonIndicatesTruncation(AReason) then
    Result := 'Response was truncated (finish_reason=' + Trim(AReason) + '). '
  else
    Result := '';
end;

constructor TAgentEngine.Create(const AWorkspaceRoot: string);
begin
  inherited Create;
  FState := asIdle;
  FMaxSteps := DEFAULT_MAX_AGENT_STEPS;
  FAutoSummarizeContext := True;
  FContextWindowTokens := DEFAULT_CONTEXT_WINDOW_TOKENS;
  FSummarizeThreshold := DEFAULT_SUMMARIZE_THRESHOLD;
  FLastPromptTokens := 0;
  FSummarizeAttemptsThisRun := 0;
  FCancelRequested := False;
  FRunActive := False;
  FInWorkerRun := False;
  FDestroying := False;
  FRunThread := nil;
  FRunLock := TCriticalSection.Create;
  FDataLock := TCriticalSection.Create;

  FClient := TLlmClient.Create;
  FPromptCacheSettings := DefaultPromptCacheSettings;
  FClient.PromptCacheSettings := FPromptCacheSettings;
  FToolCallingCapabilities := DefaultLlmToolCallingCapabilities;
  FLearnWireLogging := False;
  FContext := TAgentToolContext.Create(AWorkspaceRoot);
  FContext.SetCancelFlag(@FCancelRequested);
  FContext.SetCancelDeadline(0);
  FTools := TAgentToolRegistry.Create(FContext);
  SetLength(FMessages, 0);
end;

destructor TAgentEngine.Destroy;
begin
  RequestCancel;
  WaitForRunComplete;
  FDestroying := True;
  FOnStateChange := nil;
  FOnMessageAdded := nil;
  FOnToolCall := nil;
  FOnToolResult := nil;
  FOnExecutionLogAdded := nil;
  FOnToolErrorAdded := nil;
  if Assigned(Application) then
    Application.ProcessMessages;
  FTools.Free;
  FContext.Free;
  FClient.Free;
  FDataLock.Free;
  FRunLock.Free;
  inherited Destroy;
end;

function TAgentEngine.GetCancelRequested: Boolean;
begin
  FRunLock.Enter;
  try
    Result := FCancelRequested;
  finally
    FRunLock.Leave;
  end;
end;

procedure TAgentEngine.CaptureClientSnapshot;
begin
  FRunSnapProvider := FClient.Provider;
  FRunSnapApiKey := FClient.ApiKey;
  FRunSnapBaseUrl := FClient.BaseUrl;
  FRunSnapModel := FClient.Model;
  FRunSnapTemperature := FClient.Temperature;
  FRunSnapMaxTokens := FClient.MaxTokens;
  FRunSnapConnectTimeoutMs := FClient.ConnectTimeoutMs;
  FRunSnapReadTimeoutMs := FClient.ReadTimeoutMs;
  FRunSnapHttpRetryCount := FClient.HttpRetryCount;
  FRunSnapPromptCacheSettings := FPromptCacheSettings;
  FRunSnapToolCallingCaps := FToolCallingCapabilities;
  FRunSnapLearnWireLogging := FLearnWireLogging;
end;

procedure TAgentEngine.ApplyClientSnapshot;
begin
  FClient.Provider := FRunSnapProvider;
  FClient.ApiKey := FRunSnapApiKey;
  FClient.BaseUrl := FRunSnapBaseUrl;
  FClient.Model := FRunSnapModel;
  FClient.Temperature := FRunSnapTemperature;
  FClient.MaxTokens := FRunSnapMaxTokens;
  FClient.ConnectTimeoutMs := FRunSnapConnectTimeoutMs;
  FClient.ReadTimeoutMs := FRunSnapReadTimeoutMs;
  FClient.HttpRetryCount := FRunSnapHttpRetryCount;
  FClient.PromptCacheSettings := FRunSnapPromptCacheSettings;
  FClient.ToolCallingCapabilities := FRunSnapToolCallingCaps;
  FClient.LearnWireLogging := FRunSnapLearnWireLogging;
  FToolCallingCapabilities := FRunSnapToolCallingCaps;
  FLearnWireLogging := FRunSnapLearnWireLogging;
end;

procedure TAgentEngine.SyncStateChange;
begin
  if FDestroying then Exit;
  if Assigned(FOnStateChange) then
    FOnStateChange(Self, FSyncOldState, FSyncNewState, FSyncRunStep, FSyncRunMaxSteps);
end;

procedure TAgentEngine.SyncMessageAdded;
begin
  if FDestroying then Exit;
  if Assigned(FOnMessageAdded) then
    FOnMessageAdded(Self, FSyncMessage);
end;

procedure TAgentEngine.SyncToolCall;
begin
  if FDestroying then Exit;
  if Assigned(FOnToolCall) then
    FOnToolCall(Self, FSyncToolName, FSyncToolArgs);
end;

procedure TAgentEngine.SyncToolResult;
begin
  if FDestroying then Exit;
  if Assigned(FOnToolResult) then
    FOnToolResult(Self, FSyncToolName, FSyncToolArgs, FSyncToolResult);
end;

procedure TAgentEngine.SyncExecutionLogAdded;
begin
  if FDestroying then Exit;
  if Assigned(FOnExecutionLogAdded) then
    FOnExecutionLogAdded(Self, FSyncLogEntryIndex);
end;

procedure TAgentEngine.NotifyExecutionLogAdded(AEntryIndex: Integer);
begin
  if FInWorkerRun then begin
    FSyncLogEntryIndex := AEntryIndex;
    TThread.Queue(nil, @SyncExecutionLogAdded);
  end else if Assigned(FOnExecutionLogAdded) then
    FOnExecutionLogAdded(Self, AEntryIndex);
end;

procedure TAgentEngine.SyncToolErrorAdded;
begin
  if FDestroying then Exit;
  if Assigned(FOnToolErrorAdded) then
    FOnToolErrorAdded(Self, FSyncToolErrorIndex);
end;

procedure TAgentEngine.NotifyToolErrorAdded(AEntryIndex: Integer);
begin
  if FInWorkerRun then begin
    FSyncToolErrorIndex := AEntryIndex;
    TThread.Queue(nil, @SyncToolErrorAdded);
  end else if Assigned(FOnToolErrorAdded) then
    FOnToolErrorAdded(Self, AEntryIndex);
end;

procedure TAgentEngine.SyncRunFailure;
var
  Msg: TChatMessage;
begin
  if FDestroying then Exit;
  Msg := StringToChatRole('assistant');
  Msg.Content := FSyncRunFailureMessage;
  AppendMessage(Msg);
  SetState(asError);
end;

procedure TAgentEngine.NotifyRunFailure(const AMessage: string);
begin
  FSyncRunFailureMessage := AMessage;
  if FInWorkerRun then
    TThread.Queue(nil, @SyncRunFailure)
  else
    SyncRunFailure;
end;

procedure TAgentEngine.ReportRunException(const E: Exception);
var
  Msg, Sid: string;
begin
  Msg := 'Agent run failed: ' + E.Message;
  if Assigned(FToolErrorLog) then
    NotifyToolErrorAdded(FToolErrorLog.Add('_agent_run', '', '', Msg, E.ClassName, True))
  else
    AppendToolErrorLogFile('', FContext.WorkspaceRoot, '', '_agent_run', '', '',
      Msg, E.ClassName, True, Now);
  NotifyRunFailure('❌ ' + Msg);
end;

procedure TAgentEngine.SetRunProgress(AStep: Integer);
begin
  FSyncRunStep := AStep;
  FSyncRunMaxSteps := FMaxSteps;
end;

procedure TAgentEngine.SetState(ANewState: TAgentState);
var
  Old: TAgentState;
begin
  FDataLock.Enter;
  try
    if FState = ANewState then Exit;
    Old := FState;
    FState := ANewState;
  finally
    FDataLock.Leave;
  end;

  if FInWorkerRun then begin
    FSyncOldState := Old;
    FSyncNewState := ANewState;
    TThread.Queue(nil, @SyncStateChange);
  end else if Assigned(FOnStateChange) then
    FOnStateChange(Self, Old, ANewState, FSyncRunStep, FSyncRunMaxSteps);
end;

procedure TAgentEngine.AppendMessage(const AMsg: TChatMessage);
var
  Idx: Integer;
begin
  FDataLock.Enter;
  try
    Idx := Length(FMessages);
    SetLength(FMessages, Idx + 1);
    FMessages[Idx] := AMsg;
  finally
    FDataLock.Leave;
  end;

  if FInWorkerRun then begin
    FSyncMessage := AMsg;
    TThread.Queue(nil, @SyncMessageAdded);
  end else if Assigned(FOnMessageAdded) then
    FOnMessageAdded(Self, AMsg);
end;

function TAgentEngine.BuildSystemPrompt(AMode: TWorkspaceMode): string;
var
  Input: TSystemPromptBuildInput;
  Parts: array of string;
  Fp: string;
begin
  Fp := TAgentRules.RulesContentFingerprint(FContext.WorkspaceRoot);
  if Fp = FCachedRulesFingerprint then
    Input.RulesText := FCachedRulesText
  else begin
    FCachedRulesFingerprint := Fp;
    FCachedRulesText := TAgentRules.ReadAll(FContext.WorkspaceRoot);
    Input.RulesText := FCachedRulesText;
  end;
  Input.Mode := AMode;
  Input.WorkspaceRoot := FContext.WorkspaceRoot;
  Input.AllowModifyOutsideWorkspace := FContext.AllowModifyOutsideWorkspace;
  if ToolDefinitionsSentInApiPayload then
    Input.ToolsGuidance := ''
  else
    Input.ToolsGuidance := FTools.ToolGuidance(AMode, True);
  Input.WebSearchLine := WebSearchInstructionLineForPrompt;
  Result := BuildSystemPromptParts(Input, Parts);
  FLastPromptSegments := BuildSystemPromptSegments(Input, FPromptCacheSettings);
end;

procedure TAgentEngine.ApplySystemPrompt(AMode: TWorkspaceMode);
var
  SysMsg: TChatMessage;
  I: Integer;
begin
  SysMsg := StringToChatRole('system');
  SysMsg.Content := BuildSystemPrompt(AMode);
  FDataLock.Enter;
  try
    if (Length(FMessages) > 0) and (FMessages[0].Role = crSystem) then
      FMessages[0] := SysMsg
    else if Length(FMessages) = 0 then
      FMessages := [SysMsg]
    else begin
      SetLength(FMessages, Length(FMessages) + 1);
      for I := High(FMessages) downto 1 do
        FMessages[I] := FMessages[I - 1];
      FMessages[0] := SysMsg;
    end;
  finally
    FDataLock.Leave;
  end;
end;

function TAgentEngine.ExecuteToolDirect(const AName, AArgumentsJson: string;
  AMode: TWorkspaceMode): TToolExecutionResult;
begin
  if IsRunActive then begin
    Result.Success := False;
    Result.Output := '{"error":"Agent run in progress"}';
    Result.Summary := 'busy';
    Exit;
  end;
  Result := FTools.ExecuteTool(AName, AArgumentsJson, AMode);
end;

procedure TAgentEngine.ClearConversation;
begin
  RequestCancel;
  WaitForRunComplete;
  FDataLock.Enter;
  try
    SetLength(FMessages, 0);
  finally
    FDataLock.Leave;
  end;
  FContext.ClearSession;
  if Assigned(FExecutionLog) then
    FExecutionLog.Clear;
  SetState(asIdle);
end;

procedure TAgentEngine.LoadConversation(const AMessages: TChatMessageArray);
var
  I: Integer;
begin
  RequestCancel;
  WaitForRunComplete;
  FDataLock.Enter;
  try
    SetLength(FMessages, Length(AMessages));
    for I := 0 to High(AMessages) do
      FMessages[I] := AMessages[I];
  finally
    FDataLock.Leave;
  end;
  FContext.ClearSession;
  SetState(asIdle);
end;

procedure TAgentEngine.ExportMessages(out AMessages: TChatMessageArray);
var
  I: Integer;
begin
  FDataLock.Enter;
  try
    SetLength(AMessages, Length(FMessages));
    for I := 0 to High(FMessages) do
      AMessages[I] := FMessages[I];
  finally
    FDataLock.Leave;
  end;
end;

procedure TAgentEngine.RequestCancel;
begin
  FRunLock.Enter;
  try
    FCancelRequested := True;
  finally
    FRunLock.Leave;
  end;
end;

function TAgentEngine.IsRunActive: Boolean;
begin
  FRunLock.Enter;
  try
    Result := FRunActive;
  finally
    FRunLock.Leave;
  end;
end;

procedure TAgentEngine.WaitForRunComplete;
var
  T: TThread;
begin
  T := FRunThread;
  if T = nil then Exit;
  if T = TThread.CurrentThread then Exit;
  T.WaitFor;
  FreeAndNil(FRunThread);
end;

procedure TAgentEngine.RunThreadFinished;
begin
  FRunLock.Enter;
  try
    FRunActive := False;
  finally
    FRunLock.Leave;
  end;
end;

function TAgentEngine.GetMessageCount: Integer;
begin
  FDataLock.Enter;
  try
    Result := Length(FMessages);
  finally
    FDataLock.Leave;
  end;
end;

function TAgentEngine.GetMessage(AIndex: Integer): TChatMessage;
begin
  FDataLock.Enter;
  try
    Result := FMessages[AIndex];
  finally
    FDataLock.Leave;
  end;
end;

procedure TAgentEngine.AppendTruncationNoticeIfNeeded(var AContent: string;
  const AFinishReason: string; ATruncationRetriesExhausted: Boolean);
var
  Note: string;
begin
  if not FinishReasonIndicatesTruncation(AFinishReason) then Exit;
  Note := LineEnding + LineEnding +
    '*(Response may be incomplete: output hit Max Output Tokens';
  if ATruncationRetriesExhausted then
    Note := Note + ' even after automatic retry; raise the limit in Settings.)*'
  else
    Note := Note + '.)*';
  if Pos('*(Response may be incomplete', AContent) = 0 then
    AContent := AContent + Note;
end;

function TAgentEngine.TryCompactConversationHistory(out ANote: string): Boolean;
var
  Msgs: TChatMessageArray;
  KeepFrom, MiddleFrom, MiddleTo: Integer;
  Summary, Err: string;
  NoteMsg: TChatMessage;
begin
  Result := False;
  ANote := '';
  if not FAutoSummarizeContext then Exit;
  if FSummarizeAttemptsThisRun >= MAX_SUMMARIZE_ATTEMPTS_PER_RUN then Exit;

  ExportMessages(Msgs);

  if Length(Msgs) < 4 then Exit;

  KeepFrom := FindSafeKeepFromIndex(Msgs, CONTEXT_KEEP_RECENT_MESSAGES);
  MiddleFrom := 1;
  if (Msgs[0].Role = crSystem) then
    MiddleFrom := 1
  else
    MiddleFrom := 0;
  MiddleTo := KeepFrom - 1;
  if MiddleTo < MiddleFrom then Exit;

  if not RunConversationSummary(FClient, Msgs, MiddleFrom, MiddleTo, Summary, Err) then begin
    ANote := Err;
    Exit;
  end;

  ApplySummaryToHistory(Msgs, Summary, MiddleFrom, MiddleTo);

  FDataLock.Enter;
  try
    FMessages := Msgs;
  finally
    FDataLock.Leave;
  end;

  Inc(FSummarizeAttemptsThisRun);
  FLastPromptTokens := 0;
  NoteMsg := StringToChatRole('assistant');
  NoteMsg.Content := 'Context summarized to continue the conversation.';
  AppendMessage(NoteMsg);
  ANote := NoteMsg.Content;
  Result := True;
end;

function TAgentEngine.ToolDefinitionsSentInApiPayload: Boolean;
var
  Wire: TLlmWireFormat;
begin
  if not FToolCallingCapabilities.NativeToolCalling then
    Exit(False);
  Wire := ResolveLlmWireFormat(FClient.Provider, FClient.BaseUrl, FClient.Model);
  Result := Wire in [lwfOpenAiChat, lwfAnthropicMessages];
end;

procedure TAgentEngine.ApplyTextToolCompatIfNeeded(var AResp: TLlmResponse;
  const AToolDefs: array of TToolDef; AStep: Integer);
var
  Parsed: TToolCallArray;
  Err: string;
  IdPrefix: string;
begin
  if (Length(AResp.ToolCalls) > 0) or (not FToolCallingCapabilities.TextToolCompat) then
    Exit;
  IdPrefix := Format('text_call_%d_', [AStep]);
  if not TryParseStrictTextToolCalls(AResp.Content, AToolDefs, IdPrefix, Parsed, Err) then
  begin
    if Err <> '' then
    begin
      SetLength(AResp.ParseFailures, Length(AResp.ParseFailures) + 1);
      AResp.ParseFailures[High(AResp.ParseFailures)] := 'Text tool compat: ' + Err;
    end;
    Exit;
  end;
  AResp.ToolCalls := Parsed;
  AResp.Content := AssistantDisplayContent(AResp.Content, AResp.ToolCalls);
end;

function TAgentEngine.SendCompletionWithTruncationRetry(const AMessages: array of TChatMessage;
  const AToolDefs: array of TToolDef; AStep: Integer; out AResp: TLlmResponse): Boolean;
var
  SavedMax, Attempt, UserMax: Integer;
  LogIdx: Integer;
begin
  Result := False;
  UserMax := FClient.MaxTokens;
  SavedMax := UserMax;
  Attempt := 0;
  repeat
    FClient.PromptSegments := BuildPromptSegmentsFromSystemAndHistory(
      FLastPromptSegments, AMessages, FClient.PromptCacheSettings);
    AResp := FClient.SendChatCompletion(AMessages, AToolDefs);
    ApplyTextToolCompatIfNeeded(AResp, AToolDefs, AStep);
    if FLearnWireLogging and Assigned(FExecutionLog) then begin
      LogIdx := FExecutionLog.AddLlmWire(FClient.LastWireRequestRedacted,
        FClient.LastWireResponseRedacted, AResp.ToolCalls, AResp.ParseFailures, AStep, FMaxSteps);
      NotifyExecutionLogAdded(LogIdx);
    end;
    if not AResp.Success then begin
      FClient.MaxTokens := SavedMax;
      Exit;
    end;
    if AResp.PromptTokens > 0 then
      FLastPromptTokens := AResp.PromptTokens;
    if ResponseNeedsTruncationRetry(AResp) and (Attempt < MAX_TRUNCATION_RETRIES) then begin
      FClient.MaxTokens := RetryMaxTokensAfterTruncation(UserMax, Attempt);
      Inc(Attempt);
      Continue;
    end;
    Break;
  until False;
  FClient.MaxTokens := SavedMax;
  Result := AResp.Success;
end;

function TAgentEngine.StartRunAsync(const AUserPrompt: string;
  const AAttachments: array of TChatAttachment; AMode: TWorkspaceMode;
  const AModel: string): Boolean;
begin
  Result := False;
  if IsRunActive then Exit;

  WaitForRunComplete;

  FRunLock.Enter;
  try
    FCancelRequested := False;
    FRunActive := True;
  finally
    FRunLock.Leave;
  end;

  CaptureClientSnapshot;

  FRunThread := TAgentRunThread.Create(Self, AUserPrompt, AAttachments, AMode, AModel);
  TAgentRunThread(FRunThread).Start;
  Result := True;
end;

procedure TAgentEngine.ExecuteRun(
  const AUserPrompt: string;
  const AAttachments: array of TChatAttachment;
  AMode: TWorkspaceMode;
  const AModel: string
);
var
  UserMsg, AssistantMsg, ToolMsg: TChatMessage;
  ToolDefs: array of TToolDef;
  Resp: TLlmResponse;
  StepCount, I: Integer;
  ToolResult: TToolExecutionResult;
  HadToolCalls: Boolean;
  LastResponseHadTools: Boolean;
  MessagesCopy: array of TChatMessage;
  RequestContext: string;
  CompactNote: string;
  ContextRetry: Boolean;
  TruncationExhausted: Boolean;
  UserLogText: string;
  AttIdx: Integer;
begin
  FInWorkerRun := True;
  FSyncRunStep := 0;
  FSyncRunMaxSteps := FMaxSteps;
  LastResponseHadTools := False;
  FSummarizeAttemptsThisRun := 0;
  FLastPromptTokens := 0;
  try
    ApplyClientSnapshot;
    if Trim(AModel) <> '' then
      FClient.Model := AModel;

    ApplySystemPrompt(AMode);

    UserMsg := StringToChatRole('user');
    UserMsg.Content := AUserPrompt;
    SetLength(UserMsg.Attachments, Length(AAttachments));
    for AttIdx := 0 to High(AAttachments) do
      UserMsg.Attachments[AttIdx] := AAttachments[AttIdx];
    AppendMessage(UserMsg);

    StepCount := 0;
    FContext.Mode := AMode;
    ToolDefs := FTools.GetToolDefinitions(AMode);

    if Assigned(FExecutionLog) then begin
      FDataLock.Enter;
      try
        MessagesCopy := FMessages;
      finally
        FDataLock.Leave;
      end;
      UserLogText := AUserPrompt;
      if Length(AAttachments) > 0 then begin
        if UserLogText <> '' then
          UserLogText := UserLogText + LineEnding;
        UserLogText := UserLogText + FormatAttachmentsSummary(AAttachments);
      end;
      NotifyExecutionLogAdded(FExecutionLog.AddUserPrompt(UserLogText,
        FormatMessagesForDisplay(MessagesCopy, ToolDefs, ToolDefinitionsSentInApiPayload)));
    end;

    while (StepCount < FMaxSteps) and not GetCancelRequested do begin
      Inc(StepCount);
      SetRunProgress(StepCount);
      SetState(asThinking);

      FDataLock.Enter;
      try
        MessagesCopy := FMessages;
      finally
        FDataLock.Leave;
      end;

      ContextRetry := True;
      while ContextRetry do begin
        ContextRetry := False;

        FDataLock.Enter;
        try
          MessagesCopy := FMessages;
        finally
          FDataLock.Leave;
        end;

        if FAutoSummarizeContext and (FSummarizeAttemptsThisRun < MAX_SUMMARIZE_ATTEMPTS_PER_RUN) and
           ShouldProactivelySummarize(
             EstimatePromptTokens(MessagesCopy, ToolDefs, FLastPromptTokens),
             FContextWindowTokens, FClient.MaxTokens, FSummarizeThreshold, FLastPromptTokens) then begin
          TryCompactConversationHistory(CompactNote);
          FDataLock.Enter;
          try
            MessagesCopy := FMessages;
          finally
            FDataLock.Leave;
          end;
        end;

        RequestContext := FormatMessagesForDisplay(MessagesCopy, ToolDefs,
          ToolDefinitionsSentInApiPayload);

        if not SendCompletionWithTruncationRetry(MessagesCopy, ToolDefs, StepCount, Resp) then begin
          if GetCancelRequested then begin
            SetState(asIdle);
            Exit;
          end;
          if FAutoSummarizeContext and IsContextLengthError(Resp.ErrorMessage) and
             TryCompactConversationHistory(CompactNote) then begin
            ContextRetry := True;
            Continue;
          end;
          AssistantMsg := StringToChatRole('assistant');
          AssistantMsg.Content := '❌ LLM Request Error: ' + Resp.ErrorMessage;
          AppendMessage(AssistantMsg);
          SetState(asError);
          Exit;
        end;
        Break;
      end;

      if GetCancelRequested then begin
        SetState(asIdle);
        Exit;
      end;

      TruncationExhausted := FinishReasonIndicatesTruncation(Resp.FinishReason);

      AssistantMsg := StringToChatRole('assistant');
      AssistantMsg.Content := AssistantDisplayContent(Resp.Content, Resp.ToolCalls);
      AppendTruncationNoticeIfNeeded(AssistantMsg.Content, Resp.FinishReason,
        TruncationExhausted);
      AssistantMsg.ToolCalls := Resp.ToolCalls;
      AssistantMsg.TokensUsed := Resp.TotalTokens;
      AppendMessage(AssistantMsg);

      if Assigned(FExecutionLog) then
        NotifyExecutionLogAdded(FExecutionLog.AddAssistant(Resp.Content, RequestContext,
          Resp.ToolCalls, StepCount, FMaxSteps));

      if Length(Resp.ToolCalls) = 0 then begin
        SetState(asFinished);
        Exit;
      end;

      LastResponseHadTools := True;
      HadToolCalls := False;
      SetState(asExecutingTool);
      for I := Low(Resp.ToolCalls) to High(Resp.ToolCalls) do begin
        if GetCancelRequested then Break;

        HadToolCalls := True;
        FSyncToolName := Resp.ToolCalls[I].Name;
        FSyncToolArgs := Resp.ToolCalls[I].ArgumentsJson;
        TThread.Queue(nil, @SyncToolCall);

        if not JsonToolArgumentsWellFormed(Resp.ToolCalls[I].ArgumentsJson) then
          ToolResult := ToolResultFromJson(ToolError(
            'Tool call "' + Resp.ToolCalls[I].Name +
            '" has invalid or truncated JSON arguments (' +
            IntToStr(Length(Resp.ToolCalls[I].ArgumentsJson)) + ' bytes). ' +
            TruncationHintForFinishReason(Resp.FinishReason) +
            'Retry with smaller writes or increase max tokens in Settings.'))
        else
          ToolResult := FTools.ExecuteTool(Resp.ToolCalls[I].Name,
            Resp.ToolCalls[I].ArgumentsJson, AMode);

        FSyncToolName := Resp.ToolCalls[I].Name;
        FSyncToolResult := ToolResult;
        TThread.Queue(nil, @SyncToolResult);

        if Assigned(FExecutionLog) then
          NotifyExecutionLogAdded(FExecutionLog.AddTool(Resp.ToolCalls[I].Name,
            Resp.ToolCalls[I].ArgumentsJson, ToolResult.Output, ToolResult.Summary,
            ToolResult.Success, StepCount, FMaxSteps));

        if (not ToolResult.Success) and Assigned(FToolErrorLog) then
          NotifyToolErrorAdded(FToolErrorLog.Add(Resp.ToolCalls[I].Name,
            Resp.ToolCalls[I].ArgumentsJson, ToolResult.Output, ToolResult.Summary,
            ToolResult.ExceptionClass, ToolResult.WasException));

        ToolMsg := StringToChatRole('tool');
        ToolMsg.ToolCallId := Resp.ToolCalls[I].Id;
        ToolMsg.Content := ToolResult.Output;
        ToolMsg.VisualSummary := ToolResult.Summary;
        if Length(ToolResult.Attachments) > 0 then
          ToolMsg.Attachments := ToolResult.Attachments;
        AppendMessage(ToolMsg);
      end;

      if not HadToolCalls or GetCancelRequested then Break;
    end;

    if GetCancelRequested then
      SetState(asIdle)
    else begin
      if LastResponseHadTools and (StepCount >= FMaxSteps) then begin
        AssistantMsg := StringToChatRole('assistant');
        AssistantMsg.Content := Format(
          'Stopped: reached the step limit (%d) before the model finished without tool calls.',
          [FMaxSteps]);
        AppendMessage(AssistantMsg);
      end;
      SetState(asFinished);
    end;
  finally
    FInWorkerRun := False;
    FSyncRunStep := 0;
    FSyncRunMaxSteps := FMaxSteps;
  end;
end;

end.
