unit uLlmClient;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, uAgentTypes, uLlmPromptCacheTypes, uLlmToolCalling;

type
  { Completion Response struct }
  TLlmResponse = record
    Success: Boolean;
    ErrorMessage: string;
    Content: string;
    ToolCalls: TToolCallArray;
    FinishReason: string;
    PromptTokens: Integer;
    CompletionTokens: Integer;
    TotalTokens: Integer;
    CacheUsage: TPromptCacheUsage;
    ParseFailures: array of string;
  end;

  { Callback types for async LLM interactions }
  TLlmChunkCallback = procedure(Sender: TObject; const AChunk: string) of object;

  TLlmModelInfo = record
    Id: string;
    DisplayName: string;
  end;

  TLlmModelListResult = record
    Success: Boolean;
    ErrorMessage: string;
    Models: array of TLlmModelInfo;
  end;

  { TLlmClient - Handles REST API communication with OpenAI, OpenRouter, Anthropic, Ollama }
  TLlmClient = class
  private
    FProvider: TLlmProvider;
    FApiKey: string;
    FBaseUrl: string;
    FModel: string;
    FTemperature: Double;
    FMaxTokens: Integer;
    FConnectTimeoutMs: Integer;
    FReadTimeoutMs: Integer;
    FHttpRetryCount: Integer;
    FPromptCacheSettings: TPromptCacheSettings;
    FPromptSegments: TPromptSegmentArray;
    FToolCallingCaps: TLlmToolCallingCapabilities;
    FLearnWireLogging: Boolean;
    FLastWireRequestRedacted: string;
    FLastWireResponseRedacted: string;
    function BuildOpenAiPayload(const AMessages: array of TChatMessage;
      const ATools: array of TToolDef; AStream: Boolean): string;
    function ChatCompletionsUrl: string;
    function ParseOpenAiResponse(const AJsonStr: string): TLlmResponse;
    function ParseModelsResponse(const AJsonStr: string): TLlmModelListResult;
    function BuildRequestHeaders(AIncludeJsonContentType, AStreamSse: Boolean): TStringList;
    function ModelsListUrl: string;
    function SendHttpPost(const AUrl, APayload: string; out AResponse: string;
      AStreamResponse: Boolean): Boolean;
    function SendHttpGet(const AUrl: string; out AResponse: string): Boolean;
    function SendHttpGetOnce(const AUrl: string; out AResponse: string; out AStatusCode: Integer): Boolean;
    function SendHttpPostOnce(const AUrl, APayload: string; out AResponse: string;
      out AStatusCode: Integer; AStreamResponse: Boolean): Boolean;
    function ShouldRetryLlmHttp(AAttempt, AMaxAttempts: Integer; ASuccess: Boolean;
      AStatusCode: Integer; const AResponse: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    function SendChatCompletion(
      const AMessages: array of TChatMessage;
      const ATools: array of TToolDef
    ): TLlmResponse;

    function ListModels: TLlmModelListResult;

    function ParseOpenAiResponsePublic(const AJsonStr: string): TLlmResponse;

    property Provider: TLlmProvider read FProvider write FProvider;
    property ApiKey: string read FApiKey write FApiKey;
    property BaseUrl: string read FBaseUrl write FBaseUrl;
    property Model: string read FModel write FModel;
    property Temperature: Double read FTemperature write FTemperature;
    property MaxTokens: Integer read FMaxTokens write FMaxTokens;
    property ConnectTimeoutMs: Integer read FConnectTimeoutMs write FConnectTimeoutMs;
    property ReadTimeoutMs: Integer read FReadTimeoutMs write FReadTimeoutMs;
    property HttpRetryCount: Integer read FHttpRetryCount write FHttpRetryCount;
    property PromptCacheSettings: TPromptCacheSettings read FPromptCacheSettings
      write FPromptCacheSettings;
    property PromptSegments: TPromptSegmentArray read FPromptSegments write FPromptSegments;
    property ToolCallingCapabilities: TLlmToolCallingCapabilities read FToolCallingCaps
      write FToolCallingCaps;
    property LearnWireLogging: Boolean read FLearnWireLogging write FLearnWireLogging;
    property LastWireRequestRedacted: string read FLastWireRequestRedacted;
    property LastWireResponseRedacted: string read FLastWireResponseRedacted;
  end;

implementation

uses
  uAgentToolBase, uChatImageStore, uSslRuntime, uLlmCacheCapabilities, uLlmCacheUsage,
  uLlmRequestAnthropic, uLlmRequestGemini
  {$IFNDEF MSWINDOWS}
  , fphttpclient, opensslsockets
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  , uWindowsHTTP
  {$ENDIF}
  ;

procedure CopyOpenAiParseToResponse(const AParsed: TOpenAiParseResult;
  const ARootJson: string; var AResult: TLlmResponse);
var
  Data: TJSONData;
  RootObj, UsageObj: TJSONObject;
begin
  AResult.Success := AParsed.Success;
  AResult.ErrorMessage := AParsed.ErrorMessage;
  AResult.Content := AParsed.Content;
  AResult.ToolCalls := AParsed.ToolCalls;
  AResult.FinishReason := AParsed.FinishReason;
  AResult.PromptTokens := AParsed.PromptTokens;
  AResult.CompletionTokens := AParsed.CompletionTokens;
  AResult.TotalTokens := AParsed.TotalTokens;
  AResult.ParseFailures := AParsed.ParseFailures;
  ClearPromptCacheUsage(AResult.CacheUsage);
  if Trim(ARootJson) = '' then Exit;
  try
    Data := GetJSON(ARootJson);
    try
      if not (Data is TJSONObject) then Exit;
      RootObj := TJSONObject(Data);
      if RootObj.IndexOfName('usage') < 0 then Exit;
      UsageObj := RootObj.Objects['usage'];
      if UsageObj.IndexOfName('prompt_tokens_details') >= 0 then begin
        if UsageObj.Objects['prompt_tokens_details'].IndexOfName('cached_tokens') >= 0 then
          AResult.CacheUsage := NormalizeOpenAiCacheUsage(AResult.PromptTokens,
            AResult.CompletionTokens, AResult.TotalTokens,
            UsageObj.Objects['prompt_tokens_details'].Get('cached_tokens', 0), True);
      end else if UsageObj.IndexOfName('cache_read_input_tokens') >= 0 then begin
        AResult.CacheUsage := NormalizeAnthropicCacheUsage(AResult.PromptTokens,
          AResult.CompletionTokens, UsageObj.Get('cache_creation_input_tokens', 0),
          UsageObj.Get('cache_read_input_tokens', 0), True);
      end;
    finally
      Data.Free;
    end;
  except
  end;
end;

procedure AddUserContentToMessageObject(AMsgObj: TJSONObject; const AMsg: TChatMessage);
var
  Parts: TJSONArray;
  TextPart, ImgPart, ImgUrlObj: TJSONObject;
  K: Integer;
  DataUrl, Err: string;
begin
  if (AMsg.Role <> crUser) or (Length(AMsg.Attachments) = 0) then begin
    AMsgObj.Add('content', AMsg.Content);
    Exit;
  end;

  Parts := TJSONArray.Create;
  TextPart := TJSONObject.Create;
  TextPart.Add('type', 'text');
  TextPart.Add('text', UserMessageTextForPayload(AMsg.Content, True));
  Parts.Add(TextPart);
  for K := Low(AMsg.Attachments) to High(AMsg.Attachments) do begin
    Err := LoadAttachmentAsDataUrl(AMsg.Attachments[K].RelativePath, DataUrl);
    if Err <> '' then
      raise Exception.Create(Err);
    ImgPart := TJSONObject.Create;
    ImgPart.Add('type', 'image_url');
    ImgUrlObj := TJSONObject.Create;
    ImgUrlObj.Add('url', DataUrl);
    ImgUrlObj.Add('detail', 'auto');
    ImgPart.Add('image_url', ImgUrlObj);
    Parts.Add(ImgPart);
  end;
  AMsgObj.Add('content', Parts);
end;

function SanitizeToolArgumentsForPayload(const AArgumentsJson: string): string;
begin
  if ToolArgumentsJsonIsValid(AArgumentsJson) then
    Result := AArgumentsJson
  else
    Result := '{"_parse_error":"invalid stored tool arguments"}';
end;

function HttpFailureMessage(AStatusCode: Integer; const AStatusText: string): string;
begin
  if AStatusCode = 0 then
    Result := 'No HTTP response (timed out or connection closed before headers).'
  else if Trim(AStatusText) = '' then
    Result := Format('HTTP Error %d', [AStatusCode])
  else
    Result := Format('HTTP Error %d: %s', [AStatusCode, AStatusText]);
end;

function HttpConnectionErrorMessage(const E: Exception): string;
begin
  if E is EInOutError then begin
    Result := 'HTTPS requires OpenSSL. ' + E.Message;
    if (Pos('OpenSSL', E.Message) > 0) or (Pos('initialize', LowerCase(E.Message)) > 0) then
      Result := Result + ' ' + OpenSslUnavailableUserMessage;
    Exit;
  end;
  {$IFNDEF MSWINDOWS}
  if E is EHTTPClient then begin
    Result := 'HTTP Error: ' + E.Message;
    Exit;
  end;
  {$ENDIF}
  Result := 'Connection Exception: ' + E.Message;
end;

{$IFNDEF MSWINDOWS}
procedure ConfigureHttpClientTimeouts(AClient: TFPHTTPClient; AConnectTimeoutMs,
  AReadTimeoutMs: Integer);
begin
  AClient.ConnectTimeout := ClampLlmConnectTimeoutMs(AConnectTimeoutMs);
  AClient.IOTimeout := ClampLlmReadTimeoutMs(AReadTimeoutMs);
end;

procedure ApplyHeadersToHttpClient(AClient: TFPHTTPClient; AHeaders: TStrings);
var
  I, P: Integer;
  Line, N, V: string;
begin
  for I := 0 to AHeaders.Count - 1 do begin
    Line := AHeaders[I];
    P := Pos(':', Line);
    if P > 0 then begin
      N := Trim(Copy(Line, 1, P - 1));
      V := Trim(Copy(Line, P + 1, MaxInt));
      AClient.AddHeader(N, V);
    end;
  end;
end;
{$ENDIF}

constructor TLlmClient.Create;
begin
  inherited Create;
  FProvider := lpOpenRouter;
  FApiKey := '';
  FBaseUrl := '';
  FModel := 'anthropic/claude-3.7-sonnet';
  FTemperature := 0.2;
  FMaxTokens := DEFAULT_MAX_OUTPUT_TOKENS;
  FConnectTimeoutMs := DEFAULT_LLM_CONNECT_TIMEOUT_MS;
  FReadTimeoutMs := DEFAULT_LLM_READ_TIMEOUT_MS;
  FHttpRetryCount := DEFAULT_LLM_HTTP_RETRY_COUNT;
  FPromptCacheSettings := DefaultPromptCacheSettings;
  FToolCallingCaps := DefaultLlmToolCallingCapabilities;
  FLearnWireLogging := False;
  FLastWireRequestRedacted := '';
  FLastWireResponseRedacted := '';
  SetLength(FPromptSegments, 0);
end;

procedure SortToolDefsForPayload(var ATools: array of TToolDef);
var
  I, J: Integer;
  Tmp: TToolDef;
begin
  for I := Low(ATools) to High(ATools) - 1 do
    for J := I + 1 to High(ATools) do
      if CompareText(ATools[J].Name, ATools[I].Name) < 0 then begin
        Tmp := ATools[I];
        ATools[I] := ATools[J];
        ATools[J] := Tmp;
      end;
end;

destructor TLlmClient.Destroy;
begin
  inherited Destroy;
end;

function TLlmClient.BuildOpenAiPayload(
  const AMessages: array of TChatMessage;
  const ATools: array of TToolDef;
  AStream: Boolean
): string;
var
  RootObj, MsgObj, ToolCallObj, FuncObj, ToolObj, ParamObj: TJSONObject;
  MsgArray, ToolCallsArray, ToolsArray: TJSONArray;
  I, J: Integer;
  Msg: TChatMessage;
  SortedTools: array of TToolDef;
begin
  SetLength(SortedTools, Length(ATools));
  for I := Low(ATools) to High(ATools) do
    SortedTools[I] := ATools[I];
  SortToolDefsForPayload(SortedTools);
  RootObj := TJSONObject.Create;
  try
    RootObj.Add('model', FModel);
    RootObj.Add('temperature', FTemperature);
    if FMaxTokens > 0 then
      RootObj.Add('max_tokens', FMaxTokens);

    // Messages
    MsgArray := TJSONArray.Create;
    for I := Low(AMessages) to High(AMessages) do begin
      Msg := AMessages[I];
      MsgObj := TJSONObject.Create;
      MsgObj.Add('role', ChatRoleToString(Msg.Role));

      if Msg.Role = crTool then begin
        MsgObj.Add('tool_call_id', Msg.ToolCallId);
        MsgObj.Add('content', Msg.Content);
      end else if Msg.Role = crUser then
        AddUserContentToMessageObject(MsgObj, Msg)
      else
        MsgObj.Add('content', Msg.Content);

      // If assistant produced tool calls previously
      if (Msg.Role = crAssistant) and (Length(Msg.ToolCalls) > 0) then begin
        ToolCallsArray := TJSONArray.Create;
        for J := Low(Msg.ToolCalls) to High(Msg.ToolCalls) do begin
          ToolCallObj := TJSONObject.Create;
          ToolCallObj.Add('id', Msg.ToolCalls[J].Id);
          ToolCallObj.Add('type', 'function');
          FuncObj := TJSONObject.Create;
          FuncObj.Add('name', Msg.ToolCalls[J].Name);
          FuncObj.Add('arguments', SanitizeToolArgumentsForPayload(Msg.ToolCalls[J].ArgumentsJson));
          ToolCallObj.Add('function', FuncObj);
          ToolCallsArray.Add(ToolCallObj);
        end;
        MsgObj.Add('tool_calls', ToolCallsArray);
      end;

      MsgArray.Add(MsgObj);
    end;
    RootObj.Add('messages', MsgArray);

    // Tools definition
    if FToolCallingCaps.NativeToolCalling and (Length(SortedTools) > 0) then begin
      ToolsArray := TJSONArray.Create;
      for I := Low(SortedTools) to High(SortedTools) do begin
        ToolObj := TJSONObject.Create;
        ToolObj.Add('type', 'function');

        FuncObj := TJSONObject.Create;
        FuncObj.Add('name', SortedTools[I].Name);
        FuncObj.Add('description', SortedTools[I].Description);

        ParamObj := CloneToolParametersJson(ToolDefToParametersJson(SortedTools[I]));
        if Assigned(ParamObj) then
          FuncObj.Add('parameters', ParamObj)
        else begin
          ParamObj := TJSONObject.Create;
          ParamObj.Add('type', 'object');
          ParamObj.Add('properties', TJSONObject.Create);
          ParamObj.Add('required', TJSONArray.Create);
          FuncObj.Add('parameters', ParamObj);
        end;
        ToolObj.Add('function', FuncObj);

        ToolsArray.Add(ToolObj);
      end;
      RootObj.Add('tools', ToolsArray);
      RootObj.Add('tool_choice', 'auto');
    end;

    if AStream then
      RootObj.Add('stream', True);

    Result := RootObj.AsJSON;
  finally
    RootObj.Free;
  end;
end;

function TLlmClient.ParseOpenAiResponse(const AJsonStr: string): TLlmResponse;
var
  Data: TJSONData;
  RootObj: TJSONObject;
  Failures: array of string;
  Parsed: TOpenAiParseResult;
begin
  FillChar(Result, SizeOf(Result), 0);
  SetLength(Result.ParseFailures, 0);
  ClearPromptCacheUsage(Result.CacheUsage);

  try
    Data := GetJSON(AJsonStr);
    try
      if not (Data is TJSONObject) then begin
        Result.ErrorMessage := 'Invalid JSON response from LLM endpoint.';
        Exit;
      end;
      RootObj := TJSONObject(Data);
      if not ApplyOpenAiCompletionJson(Parsed, RootObj, Failures) then begin
        Result.ErrorMessage := Parsed.ErrorMessage;
        Exit;
      end;
      CopyOpenAiParseToResponse(Parsed, AJsonStr, Result);
    finally
      Data.Free;
    end;
  except
    on E: Exception do begin
      Result.ErrorMessage := 'JSON Parse Error: ' + E.Message;
      Result.Success := False;
    end;
  end;
end;

function TLlmClient.ParseOpenAiResponsePublic(const AJsonStr: string): TLlmResponse;
begin
  Result := ParseOpenAiResponse(AJsonStr);
end;

function TLlmClient.BuildRequestHeaders(AIncludeJsonContentType, AStreamSse: Boolean): TStringList;
begin
  Result := TStringList.Create;
  if AIncludeJsonContentType then
    Result.Add('Content-Type: application/json');
  if AStreamSse then
    Result.Add('Accept: text/event-stream')
  else
    Result.Add('Accept: application/json');
  Result.Add('User-Agent: LazyCodingAgent/1.0');
  if Trim(FApiKey) <> '' then begin
    if ResolveLlmWireFormat(FProvider, FBaseUrl, FModel) = lwfAnthropicMessages then begin
      Result.Add('x-api-key: ' + Trim(FApiKey));
      Result.Add('anthropic-version: 2023-06-01');
    end else
      Result.Add('Authorization: Bearer ' + Trim(FApiKey));
  end;
  if (FProvider = lpOpenRouter) or (Pos('openrouter.ai', LowerCase(BaseUrlHost(FBaseUrl))) > 0) then begin
    Result.Add('HTTP-Referer: https://github.com/lazycodingagent');
    Result.Add('X-Title: LazyCodingAgent');
  end;
end;

function TLlmClient.ModelsListUrl: string;
var
  Url: string;
begin
  Url := Trim(FBaseUrl);
  if (Length(Url) >= 7) and SameText(Copy(Url, Length(Url) - 6, 7), '/models') then
    Result := Url
  else if Url[Length(Url)] = '/' then
    Result := Url + 'models'
  else
    Result := Url + '/models';
end;

function TLlmClient.ParseModelsResponse(const AJsonStr: string): TLlmModelListResult;
var
  Data: TJSONData;
  RootObj, ItemObj: TJSONObject;
  DataArray: TJSONArray;
  I, N: Integer;
  Id, Name: string;
begin
  Result.Success := False;
  Result.ErrorMessage := '';
  SetLength(Result.Models, 0);

  try
    Data := GetJSON(AJsonStr);
    try
      if not (Data is TJSONObject) then begin
        Result.ErrorMessage := 'Invalid JSON response from models endpoint.';
        Exit;
      end;

      RootObj := TJSONObject(Data);

      if RootObj.IndexOfName('error') >= 0 then begin
        if RootObj.Types['error'] = jtObject then
          Result.ErrorMessage := RootObj.Objects['error'].Get('message', 'Unknown API Error')
        else
          Result.ErrorMessage := RootObj.Get('error', 'Unknown API Error');
        Exit;
      end;

      if RootObj.IndexOfName('data') >= 0 then
        DataArray := RootObj.Arrays['data']
      else if RootObj.IndexOfName('models') >= 0 then
        DataArray := RootObj.Arrays['models']
      else begin
        Result.ErrorMessage := 'Models list not found in response.';
        Exit;
      end;

      N := DataArray.Count;
      SetLength(Result.Models, N);
      for I := 0 to N - 1 do begin
        if not (DataArray.Items[I] is TJSONObject) then Continue;
        ItemObj := TJSONObject(DataArray.Items[I]);
        Id := ItemObj.Get('id', '');
        if Id = '' then
          Id := ItemObj.Get('name', '');
        Name := ItemObj.Get('display_name', '');
        if Name = '' then
          Name := ItemObj.Get('name', '');
        if (Name = '') or SameText(Name, Id) then
          Name := Id;
        Result.Models[I].Id := Id;
        Result.Models[I].DisplayName := Name;
      end;

      Result.Success := True;
    finally
      Data.Free;
    end;
  except
    on E: Exception do begin
      Result.ErrorMessage := 'JSON Parse Error: ' + E.Message;
      Result.Success := False;
    end;
  end;
end;

function TLlmClient.ShouldRetryLlmHttp(AAttempt, AMaxAttempts: Integer; ASuccess: Boolean;
  AStatusCode: Integer; const AResponse: string): Boolean;
begin
  if ASuccess then
    Exit(False);
  if AAttempt >= AMaxAttempts then
    Exit(False);
  if AResponse = OpenSslUnavailableUserMessage then
    Exit(False);
  Result := LlmHttpStatusRetriable(AStatusCode);
end;

function TLlmClient.SendHttpGetOnce(const AUrl: string; out AResponse: string;
  out AStatusCode: Integer): Boolean;
var
  {$IFNDEF MSWINDOWS}
  Client: TFPHTTPClient;
  {$ENDIF}
  Headers: TStringList;
  RespStream: TStringStream;
begin
  Result := False;
  AResponse := '';
  AStatusCode := 0;
  Headers := BuildRequestHeaders(False, False);
  RespStream := TStringStream.Create('', TEncoding.UTF8);
  try
    try
      {$IFDEF MSWINDOWS}
      WindowsHTTPRequest('GET', AUrl, Headers, '', RespStream, AStatusCode,
        FConnectTimeoutMs, FReadTimeoutMs);
      AResponse := RespStream.DataString;
      Result := (AStatusCode >= 200) and (AStatusCode < 300);
      if not Result then begin
        if Trim(AResponse) = '' then
          AResponse := HttpFailureMessage(AStatusCode, '');
      end;
      {$ELSE}
      if not EnsureOpenSslAvailable then begin
        AResponse := OpenSslUnavailableUserMessage;
        Exit;
      end;
      Client := TFPHTTPClient.Create(nil);
      try
        ApplyHeadersToHttpClient(Client, Headers);
        ConfigureHttpClientTimeouts(Client, FConnectTimeoutMs, FReadTimeoutMs);
        Client.AllowRedirect := True;
        Client.MaxRedirects := 5;
        Client.Get(AUrl, RespStream);
        AStatusCode := Client.ResponseStatusCode;
        AResponse := RespStream.DataString;
        Result := (AStatusCode >= 200) and (AStatusCode < 300);
        if not Result then begin
          if Trim(AResponse) = '' then
            AResponse := HttpFailureMessage(AStatusCode, Client.ResponseStatusText);
        end;
      finally
        Client.Free;
      end;
      {$ENDIF}
    except
      on E: Exception do begin
        AStatusCode := 0;
        AResponse := HttpConnectionErrorMessage(E);
        Result := False;
      end;
    end;
  finally
    RespStream.Free;
    Headers.Free;
  end;
end;

function TLlmClient.SendHttpGet(const AUrl: string; out AResponse: string): Boolean;
var
  Attempt, MaxAttempts, StatusCode: Integer;
begin
  MaxAttempts := 1 + ClampLlmHttpRetryCount(FHttpRetryCount);
  for Attempt := 1 to MaxAttempts do begin
    Result := SendHttpGetOnce(AUrl, AResponse, StatusCode);
    if not ShouldRetryLlmHttp(Attempt, MaxAttempts, Result, StatusCode, AResponse) then
      Exit;
    Sleep(LlmHttpRetryDelayMs(Attempt));
  end;
end;

function TLlmClient.SendHttpPostOnce(const AUrl, APayload: string; out AResponse: string;
  out AStatusCode: Integer; AStreamResponse: Boolean): Boolean;
var
  {$IFNDEF MSWINDOWS}
  Client: TFPHTTPClient;
  ReqStream: TStringStream;
  {$ENDIF}
  Headers: TStringList;
  RespStream: TStringStream;
  Body: RawByteString;
begin
  Result := False;
  AResponse := '';
  AStatusCode := 0;
  Headers := BuildRequestHeaders(True, AStreamResponse);
  RespStream := TStringStream.Create('', TEncoding.UTF8);
  Body := RawByteString(APayload);
  try
    try
      {$IFDEF MSWINDOWS}
      WindowsHTTPRequest('POST', AUrl, Headers, Body, RespStream, AStatusCode,
        FConnectTimeoutMs, FReadTimeoutMs);
      AResponse := RespStream.DataString;
      Result := (AStatusCode >= 200) and (AStatusCode < 300);
      if not Result then begin
        if Trim(AResponse) = '' then
          AResponse := HttpFailureMessage(AStatusCode, '');
      end;
      {$ELSE}
      if not EnsureOpenSslAvailable then begin
        AResponse := OpenSslUnavailableUserMessage;
        Exit;
      end;
      Client := TFPHTTPClient.Create(nil);
      ReqStream := TStringStream.Create(APayload, TEncoding.UTF8);
      try
        ApplyHeadersToHttpClient(Client, Headers);
        ConfigureHttpClientTimeouts(Client, FConnectTimeoutMs, FReadTimeoutMs);
        Client.AllowRedirect := True;
        Client.MaxRedirects := 5;
        Client.RequestBody := ReqStream;
        Client.Post(AUrl, RespStream);
        AStatusCode := Client.ResponseStatusCode;
        AResponse := RespStream.DataString;
        Result := (AStatusCode >= 200) and (AStatusCode < 300);
        if not Result then begin
          if Trim(AResponse) = '' then
            AResponse := HttpFailureMessage(AStatusCode, Client.ResponseStatusText);
        end;
      finally
        ReqStream.Free;
        Client.Free;
      end;
      {$ENDIF}
    except
      on E: Exception do begin
        AStatusCode := 0;
        AResponse := HttpConnectionErrorMessage(E);
        Result := False;
      end;
    end;
  finally
    RespStream.Free;
    Headers.Free;
  end;
end;

function TLlmClient.SendHttpPost(const AUrl, APayload: string; out AResponse: string;
  AStreamResponse: Boolean): Boolean;
var
  Attempt, MaxAttempts, StatusCode: Integer;
begin
  MaxAttempts := 1 + ClampLlmHttpRetryCount(FHttpRetryCount);
  for Attempt := 1 to MaxAttempts do begin
    Result := SendHttpPostOnce(AUrl, APayload, AResponse, StatusCode, AStreamResponse);
    if not ShouldRetryLlmHttp(Attempt, MaxAttempts, Result, StatusCode, AResponse) then
      Exit;
    Sleep(LlmHttpRetryDelayMs(Attempt));
  end;
end;

function TLlmClient.ChatCompletionsUrl: string;
var
  Url: string;
begin
  Url := Trim(FBaseUrl);
  if not (Copy(Url, Length(Url) - 15, 16) = '/chat/completions') then begin
    if Url[Length(Url)] = '/' then
      Url := Url + 'chat/completions'
    else
      Url := Url + '/chat/completions';
  end;
  Result := Url;
end;

function ParseGeminiGenerateResponse(const AJsonStr: string): TLlmResponse;
var
  Data: TJSONData;
  Root, Cand, Content, Part, Usage: TJSONObject;
  Parts: TJSONArray;
  Cached: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Success := False;
  ClearPromptCacheUsage(Result.CacheUsage);
  try
    Data := GetJSON(AJsonStr);
    try
      if not (Data is TJSONObject) then begin
        Result.ErrorMessage := 'Invalid JSON response from Gemini.';
        Exit;
      end;
      Root := TJSONObject(Data);
      if Root.IndexOfName('error') >= 0 then begin
        Result.ErrorMessage := Root.Objects['error'].Get('message', 'Unknown API Error');
        Exit;
      end;
      if Root.IndexOfName('candidates') >= 0 then begin
        Cand := Root.Arrays['candidates'].Objects[0];
        if Cand.IndexOfName('content') >= 0 then begin
          Content := Cand.Objects['content'];
          if Content.IndexOfName('parts') >= 0 then begin
            Parts := Content.Arrays['parts'];
            if Parts.Count > 0 then
              Result.Content := Parts.Objects[0].Get('text', '');
          end;
        end;
        Result.FinishReason := Cand.Get('finishReason', '');
      end;
      if Root.IndexOfName('usageMetadata') >= 0 then begin
        Usage := Root.Objects['usageMetadata'];
        Result.PromptTokens := Usage.Get('promptTokenCount', 0);
        Result.CompletionTokens := Usage.Get('candidatesTokenCount', 0);
        Result.TotalTokens := Usage.Get('totalTokenCount', 0);
        Cached := Usage.Get('cachedContentTokenCount', -1);
        Result.CacheUsage := NormalizeGeminiCacheUsage(Result.PromptTokens,
          Result.CompletionTokens, Cached, Cached >= 0);
      end;
      Result.Success := True;
    finally
      Data.Free;
    end;
  except
    on E: Exception do
      Result.ErrorMessage := 'JSON Parse Error: ' + E.Message;
  end;
end;

function ParseAnthropicMessagesResponse(const AJsonStr: string): TLlmResponse;
var
  Data: TJSONData;
  Root, Usage: TJSONObject;
  ContentArr: TJSONArray;
  I: Integer;
  CacheCreate, CacheRead: Integer;
  HasCache: Boolean;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Success := False;
  ClearPromptCacheUsage(Result.CacheUsage);
  try
    Data := GetJSON(AJsonStr);
    try
      if not (Data is TJSONObject) then begin
        Result.ErrorMessage := 'Invalid JSON response from Anthropic.';
        Exit;
      end;
      Root := TJSONObject(Data);
      if Root.IndexOfName('error') >= 0 then begin
        if Root.Types['error'] = jtObject then
          Result.ErrorMessage := Root.Objects['error'].Get('message', 'Unknown API Error')
        else
          Result.ErrorMessage := Root.Get('error', 'Unknown API Error');
        Exit;
      end;
      if Root.IndexOfName('content') >= 0 then begin
        ContentArr := Root.Arrays['content'];
        for I := 0 to ContentArr.Count - 1 do
          if ContentArr.Objects[I].Get('type', '') = 'text' then
            Result.Content := Result.Content + ContentArr.Objects[I].Get('text', '');
      end;
      Result.FinishReason := Root.Get('stop_reason', '');
      if Root.IndexOfName('usage') >= 0 then begin
        Usage := Root.Objects['usage'];
        Result.PromptTokens := Usage.Get('input_tokens', 0);
        Result.CompletionTokens := Usage.Get('output_tokens', 0);
        Result.TotalTokens := Result.PromptTokens + Result.CompletionTokens;
        CacheCreate := Usage.Get('cache_creation_input_tokens', -1);
        CacheRead := Usage.Get('cache_read_input_tokens', -1);
        HasCache := (CacheCreate >= 0) or (CacheRead >= 0);
        Result.CacheUsage := NormalizeAnthropicCacheUsage(Result.PromptTokens,
          Result.CompletionTokens, CacheCreate, CacheRead, HasCache);
      end;
      Result.Success := True;
    finally
      Data.Free;
    end;
  except
    on E: Exception do
      Result.ErrorMessage := 'JSON Parse Error: ' + E.Message;
  end;
end;

function TLlmClient.ListModels: TLlmModelListResult;
var
  Url, RespStr: string;
begin
  if Trim(FBaseUrl) = '' then begin
    Result.Success := False;
    Result.ErrorMessage := 'Set Base API Endpoint in Settings.';
    SetLength(Result.Models, 0);
    Exit;
  end;
  Url := ModelsListUrl;
  if SendHttpGet(Url, RespStr) then
    Result := ParseModelsResponse(RespStr)
  else begin
    RespStr := Trim(RespStr);
    if (RespStr <> '') and ((RespStr[1] = '{') or (RespStr[1] = '[')) then begin
      Result := ParseModelsResponse(RespStr);
      if (not Result.Success) and (Result.ErrorMessage = '') then
        Result.ErrorMessage := RespStr;
    end else begin
      Result.Success := False;
      SetLength(Result.Models, 0);
      Result.ErrorMessage := RespStr;
    end;
    Result.Success := False;
  end;
end;

function TLlmClient.SendChatCompletion(
  const AMessages: array of TChatMessage;
  const ATools: array of TToolDef
): TLlmResponse;
var
  Url, Payload, RespStr: string;
  Wire: TLlmWireFormat;
  CacheSettings: TPromptCacheSettings;
  CacheCapabilities: TPromptCacheCapabilities;
  StreamOpenAi: Boolean;
  SseFailures: array of string;
  Parsed: TOpenAiParseResult;
begin
  FLastWireRequestRedacted := '';
  FLastWireResponseRedacted := '';
  SetLength(Result.ParseFailures, 0);
  if Trim(FBaseUrl) = '' then begin
    Result.Success := False;
    Result.ErrorMessage := 'Set Base API Endpoint in Settings.';
    Exit;
  end;
  Wire := ResolveLlmWireFormat(FProvider, FBaseUrl, FModel);
  CacheCapabilities := ResolveCacheCapabilities(FProvider, FBaseUrl, FModel, Wire);
  CacheSettings := FPromptCacheSettings;
  if CacheSettings.Mode = pcmDisabled then
    CacheCapabilities.SupportsExplicitCaching := False;

  StreamOpenAi := (Wire = lwfOpenAiChat) and FToolCallingCaps.StreamingEnabled;

  if Wire = lwfAnthropicMessages then begin
    Url := AnthropicMessagesUrl(FBaseUrl);
    Payload := BuildAnthropicMessagesPayload(FModel, FTemperature, FMaxTokens,
      AMessages, ATools, FPromptSegments, CacheSettings, CacheCapabilities);
  end else if Wire = lwfGemini then begin
    Url := GeminiGenerateUrl(FBaseUrl, FModel);
    Payload := BuildGeminiGeneratePayload(FModel, FTemperature, FMaxTokens, AMessages, ATools);
  end else begin
    Url := ChatCompletionsUrl;
    Payload := BuildOpenAiPayload(AMessages, ATools, StreamOpenAi);
  end;

  if FLearnWireLogging then
    FLastWireRequestRedacted := RedactLlmPayloadForLog(Payload);

  if SendHttpPost(Url, Payload, RespStr, StreamOpenAi) then begin
    if FLearnWireLogging then
      FLastWireResponseRedacted := RedactLlmPayloadForLog(RespStr);
    if Wire = lwfAnthropicMessages then
      Result := ParseAnthropicMessagesResponse(RespStr)
    else if Wire = lwfGemini then
      Result := ParseGeminiGenerateResponse(RespStr)
    else if StreamOpenAi then begin
      Parsed := ParseOpenAiSseBody(RespStr, SseFailures);
      CopyOpenAiParseToResponse(Parsed, '', Result);
      Result.ParseFailures := SseFailures;
    end else
      Result := ParseOpenAiResponse(RespStr);
    if Result.Success and Result.CacheUsage.CacheMetricsAvailable then
      GlobalPromptCacheStats.RecordUsage(Result.CacheUsage);
  end else begin
    if FLearnWireLogging then
      FLastWireResponseRedacted := RedactLlmPayloadForLog(RespStr);
    // Try to parse error JSON if available
    RespStr := Trim(RespStr);
    if (RespStr <> '') and ((RespStr[1] = '{') or (RespStr[1] = '[')) then begin
      if Wire = lwfAnthropicMessages then
        Result := ParseAnthropicMessagesResponse(RespStr)
      else if Wire = lwfGemini then
        Result := ParseGeminiGenerateResponse(RespStr)
      else if StreamOpenAi then begin
        Parsed := ParseOpenAiSseBody(RespStr, SseFailures);
        CopyOpenAiParseToResponse(Parsed, '', Result);
      end else
        Result := ParseOpenAiResponse(RespStr);
      if Result.ErrorMessage = '' then
        Result.ErrorMessage := RespStr;
    end else begin
      FillChar(Result, SizeOf(Result), 0);
      Result.ErrorMessage := RespStr;
    end;
    Result.Success := False;
  end;
end;

end.
