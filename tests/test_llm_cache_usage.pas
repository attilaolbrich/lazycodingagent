program test_llm_cache_usage;
{$mode objfpc}{$H+}
uses
  SysUtils, uLlmPromptCacheTypes, uLlmCacheUsage;

procedure TestOpenAiNormalization;
var
  U: TPromptCacheUsage;
begin
  U := NormalizeOpenAiCacheUsage(1000, 200, 1200, 800, True);
  if not U.CacheMetricsAvailable then
    raise Exception.Create('Expected cache metrics');
  if U.CachedReadTokens <> 800 then
    raise Exception.Create('Cached read mismatch');
  if U.UncachedInputTokens <> 200 then
    raise Exception.Create('Uncached input mismatch');
  if CacheHitRatioFromUsage(U) < 79.9 then
    raise Exception.Create('Hit ratio calculation failed');
end;

procedure TestMissingMetrics;
var
  U: TPromptCacheUsage;
begin
  U := NormalizeOpenAiCacheUsage(500, 100, 600, -1, False);
  if U.CacheMetricsAvailable then
    raise Exception.Create('Missing metrics must not be marked available');
  if CacheHitRatioFromUsage(U) >= 0 then
    raise Exception.Create('Hit ratio must be unknown when metrics missing');
end;

begin
  TestOpenAiNormalization;
  TestMissingMetrics;
  WriteLn('LLM cache usage tests passed.');
end.
