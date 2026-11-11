unit uLlmPromptCacheTypes;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uAgentTypes;

type
  TPromptCacheMode = (
    pcmDisabled,
    pcmAutomatic,
    pcmExplicit
  );

  TPromptCacheRetention = (
    pcrProviderDefault,
    pcrShort,
    pcrExtended
  );

  TPromptCacheSettings = record
    Mode: TPromptCacheMode;
    Retention: TPromptCacheRetention;
    CacheSystemInstructions: Boolean;
    CacheToolDefinitions: Boolean;
    CacheProjectContext: Boolean;
    CacheConversationHistory: Boolean;
  end;

  TPromptCacheCapabilities = record
    SupportsAutomaticCaching: Boolean;
    SupportsExplicitCaching: Boolean;
    SupportsRetentionControl: Boolean;
    ReportsCachedTokens: Boolean;
    ReportsCacheWriteTokens: Boolean;
    MaxExplicitBreakpoints: Integer;
    MinCacheableTokensHint: Integer;
  end;

  TPromptSegmentKind = (
    pskSystemInstructions,
    pskAgentInstructions,
    pskToolDefinitions,
    pskProjectInstructions,
    pskProjectContext,
    pskConversationHistory,
    pskCurrentTurn
  );

  TPromptSegment = record
    Kind: TPromptSegmentKind;
    Content: string;
    ContentHash: string;
    Revision: Integer;
    EstimatedTokens: Integer;
    CacheEligible: Boolean;
    BreakpointEligible: Boolean;
  end;

  TPromptSegmentArray = array of TPromptSegment;

  TPromptCacheUsage = record
    InputTokens: Int64;
    CachedReadTokens: Int64;
    CacheWriteTokens: Int64;
    OutputTokens: Int64;
    UncachedInputTokens: Int64;
    CacheMetricsAvailable: Boolean;
  end;

  TLlmWireFormat = (
    lwfOpenAiChat,
    lwfAnthropicMessages,
    lwfGemini
  );

function DefaultPromptCacheSettings: TPromptCacheSettings;
function DefaultPromptCacheCapabilities: TPromptCacheCapabilities;
procedure ClearPromptCacheUsage(out AUsage: TPromptCacheUsage);

implementation

function DefaultPromptCacheSettings: TPromptCacheSettings;
begin
  Result.Mode := pcmAutomatic;
  Result.Retention := pcrProviderDefault;
  Result.CacheSystemInstructions := True;
  Result.CacheToolDefinitions := True;
  Result.CacheProjectContext := True;
  Result.CacheConversationHistory := True;
end;

function DefaultPromptCacheCapabilities: TPromptCacheCapabilities;
begin
  Result.SupportsAutomaticCaching := False;
  Result.SupportsExplicitCaching := False;
  Result.SupportsRetentionControl := False;
  Result.ReportsCachedTokens := False;
  Result.ReportsCacheWriteTokens := False;
  Result.MaxExplicitBreakpoints := 0;
  Result.MinCacheableTokensHint := 1024;
end;

procedure ClearPromptCacheUsage(out AUsage: TPromptCacheUsage);
begin
  AUsage.InputTokens := -1;
  AUsage.CachedReadTokens := -1;
  AUsage.CacheWriteTokens := -1;
  AUsage.OutputTokens := -1;
  AUsage.UncachedInputTokens := -1;
  AUsage.CacheMetricsAvailable := False;
end;

end.
