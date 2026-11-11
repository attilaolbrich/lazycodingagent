unit uLlmCacheBreakpoints;

{$mode objfpc}{$H+}

interface

uses
  uLlmPromptCacheTypes;

type
  TPromptSegmentKindArray = array of TPromptSegmentKind;

function SelectCacheBreakpointKinds(
  const ASegments: TPromptSegmentArray;
  const ASettings: TPromptCacheSettings;
  const ACapabilities: TPromptCacheCapabilities
): TPromptSegmentKindArray;

implementation

function KindAllowed(AKind: TPromptSegmentKind; const ASettings: TPromptCacheSettings): Boolean;
begin
  case AKind of
    pskSystemInstructions, pskAgentInstructions, pskProjectInstructions:
      Result := ASettings.CacheSystemInstructions;
    pskToolDefinitions:
      Result := ASettings.CacheToolDefinitions;
    pskProjectContext:
      Result := ASettings.CacheProjectContext;
    pskConversationHistory:
      Result := ASettings.CacheConversationHistory;
    pskCurrentTurn:
      Result := False;
  else
    Result := False;
  end;
end;

function SelectCacheBreakpointKinds(
  const ASegments: TPromptSegmentArray;
  const ASettings: TPromptCacheSettings;
  const ACapabilities: TPromptCacheCapabilities
): TPromptSegmentKindArray;
var
  I, N, MaxBp: Integer;
  Priorities: array[0..5] of TPromptSegmentKind;
  K: TPromptSegmentKind;
  J: Integer;
  Found: Boolean;
begin
  SetLength(Result, 0);
  if (ASettings.Mode <> pcmExplicit) or (not ACapabilities.SupportsExplicitCaching) then
    Exit;
  MaxBp := ACapabilities.MaxExplicitBreakpoints;
  if MaxBp <= 0 then
    MaxBp := 4;
  Priorities[0] := pskAgentInstructions;
  Priorities[1] := pskToolDefinitions;
  Priorities[2] := pskProjectContext;
  Priorities[3] := pskProjectInstructions;
  Priorities[4] := pskConversationHistory;
  Priorities[5] := pskSystemInstructions;
  for I := Low(Priorities) to High(Priorities) do begin
    K := Priorities[I];
    if not KindAllowed(K, ASettings) then
      Continue;
    Found := False;
    for J := Low(ASegments) to High(ASegments) do
      if (ASegments[J].Kind = K) and ASegments[J].BreakpointEligible and
         (ASegments[J].EstimatedTokens >= ACapabilities.MinCacheableTokensHint) then
      begin
        Found := True;
        Break;
      end;
    if not Found then
      Continue;
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N] := K;
    if Length(Result) >= MaxBp then
      Break;
  end;
end;

end.
