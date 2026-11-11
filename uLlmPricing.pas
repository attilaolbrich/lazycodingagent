unit uLlmPricing;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uLlmPromptCacheTypes;

type
  TModelPriceRates = record
    InputPerMillion: Double;
    CachedInputPerMillion: Double;
    CacheWritePerMillion: Double;
    OutputPerMillion: Double;
    Available: Boolean;
  end;

function EstimateCostUsd(const AUsage: TPromptCacheUsage; const ARates: TModelPriceRates;
  out ACostUsd: Double): Boolean;

implementation

function EstimateCostUsd(const AUsage: TPromptCacheUsage; const ARates: TModelPriceRates;
  out ACostUsd: Double): Boolean;
var
  Uncached, Cached, Write, OutTok: Double;
begin
  ACostUsd := 0;
  if not ARates.Available then
    Exit(False);
  if not AUsage.CacheMetricsAvailable then begin
    Uncached := AUsage.InputTokens;
    if Uncached < 0 then
      Exit(False);
    ACostUsd := (Uncached * ARates.InputPerMillion / 1000000.0) +
      (AUsage.OutputTokens * ARates.OutputPerMillion / 1000000.0);
    Exit(AUsage.InputTokens >= 0);
  end;
  Uncached := AUsage.UncachedInputTokens;
  Cached := AUsage.CachedReadTokens;
  Write := AUsage.CacheWriteTokens;
  OutTok := AUsage.OutputTokens;
  if (Uncached < 0) or (OutTok < 0) then
    Exit(False);
  if Cached < 0 then Cached := 0;
  if Write < 0 then Write := 0;
  ACostUsd :=
    (Uncached * ARates.InputPerMillion / 1000000.0) +
    (Cached * ARates.CachedInputPerMillion / 1000000.0) +
    (Write * ARates.CacheWritePerMillion / 1000000.0) +
    (OutTok * ARates.OutputPerMillion / 1000000.0);
  Result := True;
end;

end.
