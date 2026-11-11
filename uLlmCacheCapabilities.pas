unit uLlmCacheCapabilities;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uAgentTypes, uLlmPromptCacheTypes;

function ResolveLlmWireFormat(AProvider: TLlmProvider; const ABaseUrl, AModel: string): TLlmWireFormat;
function ResolveCacheCapabilities(AProvider: TLlmProvider; const ABaseUrl, AModel: string;
  AWire: TLlmWireFormat): TPromptCacheCapabilities;
function BaseUrlHost(const AUrl: string): string;

implementation

function Lower(const S: string): string;
begin
  Result := LowerCase(S);
end;

function BaseUrlHost(const AUrl: string): string;
var
  U, Rest: string;
  P: Integer;
begin
  U := Trim(AUrl);
  if U = '' then Exit('');
  if Pos('://', U) > 0 then
    U := Copy(U, Pos('://', U) + 3, MaxInt);
  P := Pos('/', U);
  if P > 0 then
    Rest := Copy(U, 1, P - 1)
  else
    Rest := U;
  P := Pos(':', Rest);
  if P > 0 then
    Result := Copy(Rest, 1, P - 1)
  else
    Result := Rest;
end;

function ModelLooksLikeGemini(const AModel: string): Boolean;
begin
  Result := (Pos('gemini', Lower(AModel)) > 0);
end;

function ModelLooksLikeClaude(const AModel: string): Boolean;
var
  M: string;
begin
  M := Lower(AModel);
  Result := (Pos('claude', M) > 0) or (Pos('anthropic/', M) = 1);
end;

function ResolveLlmWireFormat(AProvider: TLlmProvider; const ABaseUrl, AModel: string): TLlmWireFormat;
var
  Host, Url: string;
begin
  Url := Lower(Trim(ABaseUrl));
  Host := Lower(BaseUrlHost(ABaseUrl));
  if (Host = 'api.anthropic.com') or
     ((Url <> '') and (Pos('anthropic', Host) > 0) and (Pos('chat/completions', Url) = 0)) then
    Exit(lwfAnthropicMessages);
  if (Pos('generativelanguage.googleapis.com', Url) > 0) or
     ((AProvider in [lpCustom, lpOpenAI, lpGoogleGemini]) and ModelLooksLikeGemini(AModel) and
      (Pos('google', Url) > 0)) then
    Exit(lwfGemini);
  Result := lwfOpenAiChat;
end;

function ResolveCacheCapabilities(AProvider: TLlmProvider; const ABaseUrl, AModel: string;
  AWire: TLlmWireFormat): TPromptCacheCapabilities;
var
  Host: string;
begin
  Host := Lower(BaseUrlHost(ABaseUrl));
  Result := DefaultPromptCacheCapabilities;
  case AWire of
    lwfAnthropicMessages:
    begin
      Result.SupportsAutomaticCaching := True;
      Result.SupportsExplicitCaching := True;
      Result.SupportsRetentionControl := ModelLooksLikeClaude(AModel);
      Result.ReportsCachedTokens := True;
      Result.ReportsCacheWriteTokens := True;
      Result.MaxExplicitBreakpoints := 4;
      Result.MinCacheableTokensHint := 1024;
    end;
    lwfGemini:
    begin
      Result.SupportsAutomaticCaching := True;
      Result.ReportsCachedTokens := True;
      Result.MinCacheableTokensHint := 32768;
    end;
    lwfOpenAiChat:
    begin
      if (AProvider = lpOpenAI) or ModelLooksLikeClaude(AModel) or
         (Pos('gpt-', Lower(AModel)) > 0) or (AProvider = lpOpenRouter) then
      begin
        Result.SupportsAutomaticCaching := True;
        Result.ReportsCachedTokens := True;
      end;
      if (Host = 'localhost') or (Host = '127.0.0.1') or (Pos('ollama', Host) > 0) then
        Result.SupportsAutomaticCaching := True;
    end;
  end;
end;

end.
