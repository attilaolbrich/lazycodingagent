unit uLlmCacheUsage;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, SyncObjs, uLlmPromptCacheTypes;

type
  TPromptCacheStatsSnapshot = record
    TotalInputTokens: Int64;
    TotalCachedReadTokens: Int64;
    TotalCacheWriteTokens: Int64;
    TotalOutputTokens: Int64;
    RequestCount: Integer;
    MetricsKnownRequestCount: Integer;
  end;

  TPromptCacheStats = class
  private
    FLock: TCriticalSection;
    FCumulative: TPromptCacheStatsSnapshot;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RecordUsage(const AUsage: TPromptCacheUsage);
    procedure Reset;
    function Snapshot: TPromptCacheStatsSnapshot;
    function CacheHitRatio(const ASnap: TPromptCacheStatsSnapshot): Double;
  end;

function NormalizeOpenAiCacheUsage(APromptTokens, ACompletionTokens, ATotalTokens: Integer;
  ACachedTokens: Integer; AHasCachedField: Boolean): TPromptCacheUsage;
function NormalizeAnthropicCacheUsage(APromptTokens, ACompletionTokens: Integer;
  ACacheCreate, ACacheRead: Integer; AHasCacheFields: Boolean): TPromptCacheUsage;
function NormalizeGeminiCacheUsage(APromptTokens, ACompletionTokens: Integer;
  ACachedContentTokens: Integer; AHasCachedField: Boolean): TPromptCacheUsage;
function CacheHitRatioFromUsage(const AUsage: TPromptCacheUsage): Double;

var
  GlobalPromptCacheStats: TPromptCacheStats;

implementation

constructor TPromptCacheStats.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  Reset;
end;

destructor TPromptCacheStats.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

procedure TPromptCacheStats.Reset;
begin
  FLock.Enter;
  try
    FillChar(FCumulative, SizeOf(FCumulative), 0);
  finally
    FLock.Leave;
  end;
end;

procedure TPromptCacheStats.RecordUsage(const AUsage: TPromptCacheUsage);
begin
  FLock.Enter;
  try
    Inc(FCumulative.RequestCount);
    if AUsage.CacheMetricsAvailable then begin
      Inc(FCumulative.MetricsKnownRequestCount);
      if AUsage.InputTokens >= 0 then
        FCumulative.TotalInputTokens := FCumulative.TotalInputTokens + AUsage.InputTokens;
      if AUsage.CachedReadTokens >= 0 then
        FCumulative.TotalCachedReadTokens := FCumulative.TotalCachedReadTokens + AUsage.CachedReadTokens;
      if AUsage.CacheWriteTokens >= 0 then
        FCumulative.TotalCacheWriteTokens := FCumulative.TotalCacheWriteTokens + AUsage.CacheWriteTokens;
      if AUsage.OutputTokens >= 0 then
        FCumulative.TotalOutputTokens := FCumulative.TotalOutputTokens + AUsage.OutputTokens;
    end;
  finally
    FLock.Leave;
  end;
end;

function TPromptCacheStats.Snapshot: TPromptCacheStatsSnapshot;
begin
  FLock.Enter;
  try
    Result := FCumulative;
  finally
    FLock.Leave;
  end;
end;

function TPromptCacheStats.CacheHitRatio(const ASnap: TPromptCacheStatsSnapshot): Double;
var
  Denom: Int64;
begin
  Denom := ASnap.TotalInputTokens;
  if Denom <= 0 then
    Exit(-1);
  if ASnap.MetricsKnownRequestCount = 0 then
    Exit(-1);
  Result := (ASnap.TotalCachedReadTokens * 100.0) / Denom;
end;

function NormalizeOpenAiCacheUsage(APromptTokens, ACompletionTokens, ATotalTokens: Integer;
  ACachedTokens: Integer; AHasCachedField: Boolean): TPromptCacheUsage;
begin
  ClearPromptCacheUsage(Result);
  Result.OutputTokens := ACompletionTokens;
  Result.InputTokens := APromptTokens;
  if AHasCachedField and (ACachedTokens >= 0) then begin
    Result.CacheMetricsAvailable := True;
    Result.CachedReadTokens := ACachedTokens;
    Result.UncachedInputTokens := APromptTokens - ACachedTokens;
    if Result.UncachedInputTokens < 0 then
      Result.UncachedInputTokens := 0;
  end;
  if ATotalTokens > 0 then
    Result.InputTokens := APromptTokens;
end;

function NormalizeAnthropicCacheUsage(APromptTokens, ACompletionTokens: Integer;
  ACacheCreate, ACacheRead: Integer; AHasCacheFields: Boolean): TPromptCacheUsage;
begin
  ClearPromptCacheUsage(Result);
  Result.OutputTokens := ACompletionTokens;
  Result.InputTokens := APromptTokens;
  if AHasCacheFields then begin
    Result.CacheMetricsAvailable := True;
    Result.CacheWriteTokens := ACacheCreate;
    Result.CachedReadTokens := ACacheRead;
    Result.UncachedInputTokens := APromptTokens - ACacheRead - ACacheCreate;
    if Result.UncachedInputTokens < 0 then
      Result.UncachedInputTokens := 0;
  end;
end;

function NormalizeGeminiCacheUsage(APromptTokens, ACompletionTokens: Integer;
  ACachedContentTokens: Integer; AHasCachedField: Boolean): TPromptCacheUsage;
begin
  ClearPromptCacheUsage(Result);
  Result.OutputTokens := ACompletionTokens;
  Result.InputTokens := APromptTokens;
  if AHasCachedField then begin
    Result.CacheMetricsAvailable := True;
    Result.CachedReadTokens := ACachedContentTokens;
    Result.UncachedInputTokens := APromptTokens - ACachedContentTokens;
    if Result.UncachedInputTokens < 0 then
      Result.UncachedInputTokens := 0;
  end;
end;

function CacheHitRatioFromUsage(const AUsage: TPromptCacheUsage): Double;
var
  Denom: Int64;
begin
  if not AUsage.CacheMetricsAvailable then
    Exit(-1);
  Denom := AUsage.InputTokens;
  if Denom <= 0 then
    Exit(-1);
  Result := (AUsage.CachedReadTokens * 100.0) / Denom;
end;

initialization
  GlobalPromptCacheStats := TPromptCacheStats.Create;

finalization
  GlobalPromptCacheStats.Free;

end.
