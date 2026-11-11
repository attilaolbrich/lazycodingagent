unit uAgentTypes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser;

const
  DEFAULT_MAX_OUTPUT_TOKENS = 8192;
  DEFAULT_MAX_AGENT_STEPS = 200;
  MIN_MAX_OUTPUT_TOKENS = 256;
  MAX_MAX_OUTPUT_TOKENS = 200000;
  RECOMMENDED_MIN_OUTPUT_TOKENS = 2048;
  DEFAULT_CONTEXT_WINDOW_TOKENS = 128000;
  DEFAULT_SUMMARIZE_THRESHOLD = 0.85;
  CONTEXT_RESERVE_OVERHEAD = 4096;
  SUMMARIZE_MAX_OUTPUT_TOKENS = 2048;
  MAX_TRUNCATION_RETRIES = 2;
  MAX_SUMMARIZE_ATTEMPTS_PER_RUN = 2;
  CONTEXT_KEEP_RECENT_MESSAGES = 6;
  TRUNCATION_RETRY_CAP_TOKENS = 16384;

  DEFAULT_LLM_CONNECT_TIMEOUT_MS = 60000;
  DEFAULT_LLM_READ_TIMEOUT_MS = 600000;
  MIN_LLM_CONNECT_TIMEOUT_MS = 60000;
  MIN_LLM_READ_TIMEOUT_MS = 60000;

  DEFAULT_LLM_HTTP_RETRY_COUNT = 3;
  MAX_LLM_HTTP_RETRY_COUNT = 10;
  DEFAULT_LLM_HTTP_RETRY_BASE_MS = 1000;

function ClampLlmConnectTimeoutMs(AMs: Integer): Integer;
function ClampLlmReadTimeoutMs(AMs: Integer): Integer;
function ClampLlmHttpRetryCount(AValue: Integer): Integer;
function LlmHttpRetryDelayMs(ARetryAttempt: Integer): Integer;
function LlmHttpStatusRetriable(AStatusCode: Integer): Boolean;

type
  { Role in a conversation }
  TChatRole = (crSystem, crUser, crAssistant, crTool);

  { Agent Loop Execution Status }
  TAgentState = (
    asIdle,
    asThinking,
    asExecutingTool,
    asAwaitingConfirmation,
    asFinished,
    asError
  );

  { LLM Provider Target (order matches uLlmProviderCatalog combo) }
  TLlmProvider = (
    lpOpenAI,
    lpNousResearch,
    lpOpenRouter,
    lpGroq,
    lpTogetherAI,
    lpFireworksAI,
    lpDeepSeek,
    lpGoogleGemini,
    lpXAI,
    lpMistralAI,
    lpCerebras,
    lpNebiusAI,
    lpNovitaAI,
    lpHyperbolic,
    lpDeepInfra,
    lpSambaNova,
    lpMoonshotAI,
    lpHuggingFace,
    lpVeniceAI,
    lpLeptonAI,
    lpPerplexity,
    lpAnyscale,
    lpCustom
  );

  { Single Tool Parameter Definition }
  TToolParamDef = record
    Name: string;
    ParamType: string; // 'string', 'integer', 'boolean', 'array', 'object'
    Description: string;
    Required: Boolean;
    EnumValues: array of string;
  end;

  { Tool Schema Definition }
  TToolDef = record
    Name: string;
    Description: string;
    Params: array of TToolParamDef;
  end;
  TToolDefArray = array of TToolDef;

  { Invocable Tool Call received from LLM }
  TToolCall = record
    Id: string;
    Name: string;
    ArgumentsJson: string;
  end;
  TToolCallArray = array of TToolCall;

  TChatAttachmentKind = (cakImage);

  TChatAttachment = record
    Kind: TChatAttachmentKind;
    RelativePath: string;
    MimeType: string;
    OriginalName: string;
    Width: Integer;
    Height: Integer;
  end;
  TChatAttachmentArray = array of TChatAttachment;

  { Chat Message data struct }
  TChatMessage = record
    Role: TChatRole;
    Content: string;
    ToolCallId: string; // for tool response messages
    ToolCalls: TToolCallArray;
    Attachments: TChatAttachmentArray;
    Timestamp: TDateTime;
    TokensUsed: Integer;
    VisualSummary: string; // Summary banner for tool outputs in UI
  end;
  TChatMessageArray = array of TChatMessage;

  { Task / Checklist Item }
  TTaskItem = record
    Id: string;
    Text: string;
    Status: string; // 'pending', 'in_progress', 'completed'
  end;

  { Helper Conversion Functions }
  function ChatRoleToString(ARole: TChatRole): string;
  function StringToChatRole(const ARole: string): TChatMessage;
  function LlmProviderToString(AProv: TLlmProvider): string;
  function StringToLlmProvider(const S: string): TLlmProvider;
  function AgentStateToString(AState: TAgentState): string;
  function FormatAgentStateLabel(AState: TAgentState; AStep, AMaxSteps: Integer): string;
  function ChatAttachmentKindToString(AKind: TChatAttachmentKind): string;
  function StringToChatAttachmentKind(const S: string): TChatAttachmentKind;

implementation

uses
  uLlmProviderCatalog;

function ChatRoleToString(ARole: TChatRole): string;
begin
  case ARole of
    crSystem: Result := 'system';
    crUser: Result := 'user';
    crAssistant: Result := 'assistant';
    crTool: Result := 'tool';
  end;
end;

function StringToChatRole(const ARole: string): TChatMessage;
begin
  Result.Content := '';
  Result.ToolCallId := '';
  SetLength(Result.ToolCalls, 0);
  SetLength(Result.Attachments, 0);
  Result.Timestamp := Now;
  Result.TokensUsed := 0;
  Result.VisualSummary := '';

  if SameText(ARole, 'system') then
    Result.Role := crSystem
  else if SameText(ARole, 'assistant') then
    Result.Role := crAssistant
  else if SameText(ARole, 'tool') then
    Result.Role := crTool
  else
    Result.Role := crUser;
end;

function LlmProviderToString(AProv: TLlmProvider): string;
begin
  Result := LlmProviderCatalogName(AProv);
end;

function StringToLlmProvider(const S: string): TLlmProvider;
var
  P: TLlmProvider;
  T: string;
begin
  T := Trim(S);
  if T = '' then
    Exit(lpCustom);
  for P := Low(TLlmProvider) to High(TLlmProvider) do
    if SameText(T, LlmProviderCatalogName(P)) then
      Exit(P);
  if SameText(T, 'Nous') then
    Exit(lpNousResearch);
  if SameText(T, 'Anthropic') or SameText(T, 'Ollama') or
     SameText(T, 'Custom / OpenAI Compatible') then
    Exit(lpCustom);
  Result := lpCustom;
end;

function AgentStateToString(AState: TAgentState): string;
begin
  case AState of
    asIdle: Result := 'Idle';
    asThinking: Result := 'Thinking...';
    asExecutingTool: Result := 'Executing Tool...';
    asAwaitingConfirmation: Result := 'Awaiting Permission';
    asFinished: Result := 'Completed';
    asError: Result := 'Error';
  end;
end;

function FormatAgentStateLabel(AState: TAgentState; AStep, AMaxSteps: Integer): string;
begin
  Result := AgentStateToString(AState);
  if (AMaxSteps > 0) and (AStep > 0) and (AState in [asThinking, asExecutingTool]) then
    Result := Result + Format(' (step %d/%d)', [AStep, AMaxSteps]);
end;

function ChatAttachmentKindToString(AKind: TChatAttachmentKind): string;
begin
  case AKind of
    cakImage: Result := 'image';
  end;
end;

function StringToChatAttachmentKind(const S: string): TChatAttachmentKind;
begin
  if SameText(S, 'image') then
    Result := cakImage
  else
    Result := cakImage;
end;

function ClampLlmConnectTimeoutMs(AMs: Integer): Integer;
begin
  Result := AMs;
  if Result < MIN_LLM_CONNECT_TIMEOUT_MS then
    Result := MIN_LLM_CONNECT_TIMEOUT_MS;
end;

function ClampLlmReadTimeoutMs(AMs: Integer): Integer;
begin
  Result := AMs;
  if Result < MIN_LLM_READ_TIMEOUT_MS then
    Result := MIN_LLM_READ_TIMEOUT_MS;
end;

function ClampLlmHttpRetryCount(AValue: Integer): Integer;
begin
  Result := AValue;
  if Result < 0 then
    Result := 0;
  if Result > MAX_LLM_HTTP_RETRY_COUNT then
    Result := MAX_LLM_HTTP_RETRY_COUNT;
end;

function LlmHttpRetryDelayMs(ARetryAttempt: Integer): Integer;
var
  Shift: Integer;
begin
  if ARetryAttempt < 1 then
    Exit(DEFAULT_LLM_HTTP_RETRY_BASE_MS);
  Shift := ARetryAttempt - 1;
  if Shift > 16 then
    Shift := 16;
  Result := DEFAULT_LLM_HTTP_RETRY_BASE_MS * (1 shl Shift);
end;

function LlmHttpStatusRetriable(AStatusCode: Integer): Boolean;
begin
  case AStatusCode of
    0, 429, 502, 503, 504:
      Result := True;
  else
    Result := False;
  end;
end;

end.
