unit uLlmMessageRepair;

{$mode objfpc}{$H+}

interface

uses
  uAgentTypes;

function RepairIncompleteToolTurns(const AIn: TChatMessageArray;
  out AOut: TChatMessageArray): Boolean;

function NormalizeAssistantToolBlocks(const AIn: TChatMessageArray;
  out AOut: TChatMessageArray): Boolean;

function MakeInterruptedToolMessage(const AToolCallId: string): TChatMessage;

function IsMissingToolOutputError(const AMessage: string): Boolean;

function IsInterruptedToolMessage(const AMsg: TChatMessage): Boolean;

function CollapseFullyInterruptedTurns(const AIn: TChatMessageArray;
  out AOut: TChatMessageArray): Boolean;

function RepairToolHistory(const AIn: TChatMessageArray; out AOut: TChatMessageArray;
  AAggressive: Boolean): Boolean;

function PrepareMessagesForLlmApi(const AIn: TChatMessageArray): TChatMessageArray;

function IsLikelyProviderOutage(const AMessage: string): Boolean;

const
  COLLAPSED_TURN_NOTE = '*Prior agent step ended before tools finished; continuing from here.*';

implementation

uses
  SysUtils;

type
  TIndexList = array of Integer;

function SameToolId(const A, B: string): Boolean;
begin
  Result := SameText(Trim(A), Trim(B));
end;

function SyntheticInterruptedToolResult(const AToolCallId: string): string;
begin
  Result := '{"success":false,"error":"Tool did not finish (run interrupted, timed out, or app blocked).","error_code":"TOOL_INTERRUPTED","tool_call_id":"' +
    AToolCallId + '"}';
end;

function MakeInterruptedToolMessage(const AToolCallId: string): TChatMessage;
begin
  Result := StringToChatRole('tool');
  Result.ToolCallId := AToolCallId;
  Result.Content := SyntheticInterruptedToolResult(AToolCallId);
  Result.VisualSummary := 'TOOL_INTERRUPTED';
end;

function IsMissingToolOutputError(const AMessage: string): Boolean;
var
  L: string;
begin
  L := LowerCase(Trim(AMessage));
  Result := (Pos('no tool output found for function call', L) > 0) or
    (Pos('no tool output found', L) > 0);
end;

function FindTurnEndIndex(const AMsgs: TChatMessageArray; AAsstIdx: Integer): Integer;
begin
  Result := AAsstIdx + 1;
  while (Result < Length(AMsgs)) and
    (AMsgs[Result].Role <> crUser) and (AMsgs[Result].Role <> crAssistant) do
    Inc(Result);
end;

procedure AppendIndex(var AList: TIndexList; var ACount: Integer; AIdx: Integer);
begin
  if AIdx < 0 then Exit;
  SetLength(AList, ACount + 1);
  AList[ACount] := AIdx;
  Inc(ACount);
end;

function IndexMarked(const AList: TIndexList; ACount, AIdx: Integer): Boolean;
var
  I: Integer;
begin
  for I := 0 to ACount - 1 do
    if AList[I] = AIdx then
      Exit(True);
  Result := False;
end;

procedure SortIndicesDesc(var AList: TIndexList; ACount: Integer);
var
  I, J, T: Integer;
begin
  for I := 0 to ACount - 2 do
    for J := I + 1 to ACount - 1 do
      if AList[J] > AList[I] then begin
        T := AList[I];
        AList[I] := AList[J];
        AList[J] := T;
      end;
end;

function BlockAlreadyMatches(const AMsgs: TChatMessageArray; AAsstIdx, AEndIdx: Integer;
  const ABlock: TChatMessageArray): Boolean;
var
  K, P: Integer;
begin
  Result := (AEndIdx - AAsstIdx - 1) = Length(ABlock);
  if not Result then Exit;
  for K := 0 to High(ABlock) do begin
    P := AAsstIdx + 1 + K;
    if (AMsgs[P].Role <> crTool) or
       (not SameToolId(AMsgs[P].ToolCallId, ABlock[K].ToolCallId)) then
      Exit(False);
  end;
  Result := True;
end;

function TryBuildToolBlock(const AMsgs: TChatMessageArray; AAsstIdx, AEndIdx: Integer;
  out ABlock: TChatMessageArray; out AOrphanRemoves: TIndexList; out AOrphanCount: Integer): Boolean;
var
  ToolCount, J, K: Integer;
  FoundOk: array of Boolean;
  FoundMsg: array of TChatMessage;
  Id: string;
begin
  Result := False;
  AOrphanCount := 0;
  ToolCount := Length(AMsgs[AAsstIdx].ToolCalls);
  if ToolCount = 0 then Exit;

  SetLength(FoundOk, ToolCount);
  SetLength(FoundMsg, ToolCount);
  for K := 0 to ToolCount - 1 do
    FoundOk[K] := False;

  for J := AAsstIdx + 1 to AEndIdx - 1 do
    if AMsgs[J].Role = crTool then begin
      Id := Trim(AMsgs[J].ToolCallId);
      for K := 0 to ToolCount - 1 do
        if (not FoundOk[K]) and (Id <> '') and SameToolId(Id, AMsgs[AAsstIdx].ToolCalls[K].Id) then begin
          FoundOk[K] := True;
          FoundMsg[K] := AMsgs[J];
        end;
    end;

  J := AEndIdx;
  while J < Length(AMsgs) do begin
    if (AMsgs[J].Role = crAssistant) and (Length(AMsgs[J].ToolCalls) > 0) then Break;
    if AMsgs[J].Role = crTool then begin
      Id := Trim(AMsgs[J].ToolCallId);
      for K := 0 to ToolCount - 1 do
        if (not FoundOk[K]) and (Id <> '') and SameToolId(Id, AMsgs[AAsstIdx].ToolCalls[K].Id) then begin
          FoundOk[K] := True;
          FoundMsg[K] := AMsgs[J];
          AppendIndex(AOrphanRemoves, AOrphanCount, J);
        end;
    end;
    Inc(J);
  end;

  SetLength(ABlock, ToolCount);
  for K := 0 to ToolCount - 1 do
    if FoundOk[K] then
      ABlock[K] := FoundMsg[K]
    else
      ABlock[K] := MakeInterruptedToolMessage(AMsgs[AAsstIdx].ToolCalls[K].Id);

  if BlockAlreadyMatches(AMsgs, AAsstIdx, AEndIdx, ABlock) and (AOrphanCount = 0) then
    Exit;

  Result := True;
end;

procedure ReplaceSegmentInsertBlock(var AMsgs: TChatMessageArray; AAsstIdx, AEndIdx: Integer;
  const ABlock: TChatMessageArray; const AOrphanRemoves: TIndexList; AOrphanCount: Integer);
var
  Remove: TIndexList;
  RemCount, J, K, P, Q, NewLen, InsLen, NonToolLen: Integer;
  NonTools: TChatMessageArray;
  Segment: TChatMessageArray;
  R: TChatMessageArray;
begin
  RemCount := 0;
  for J := AAsstIdx + 1 to AEndIdx - 1 do
    if AMsgs[J].Role = crTool then
      AppendIndex(Remove, RemCount, J);
  for J := 0 to AOrphanCount - 1 do
    if not IndexMarked(Remove, RemCount, AOrphanRemoves[J]) then
      AppendIndex(Remove, RemCount, AOrphanRemoves[J]);
  SortIndicesDesc(Remove, RemCount);
  for J := 0 to RemCount - 1 do begin
    P := Remove[J];
    for K := P to High(AMsgs) - 1 do
      AMsgs[K] := AMsgs[K + 1];
    SetLength(AMsgs, Length(AMsgs) - 1);
    if AEndIdx > P then
      Dec(AEndIdx);
  end;

  NonToolLen := 0;
  SetLength(NonTools, 0);
  for J := AAsstIdx + 1 to AEndIdx - 1 do
    if AMsgs[J].Role <> crTool then begin
      SetLength(NonTools, NonToolLen + 1);
      NonTools[NonToolLen] := AMsgs[J];
      Inc(NonToolLen);
    end;

  InsLen := Length(ABlock) + NonToolLen;
  SetLength(Segment, InsLen);
  for K := 0 to High(ABlock) do
    Segment[K] := ABlock[K];
  for K := 0 to NonToolLen - 1 do
    Segment[Length(ABlock) + K] := NonTools[K];

  NewLen := Length(AMsgs) - (AEndIdx - AAsstIdx - 1) + InsLen;
  SetLength(R, NewLen);
  for P := 0 to AAsstIdx do
    R[P] := AMsgs[P];
  for Q := 0 to InsLen - 1 do
    R[AAsstIdx + 1 + Q] := Segment[Q];
  P := AAsstIdx + 1 + InsLen;
  for Q := AEndIdx to High(AMsgs) do begin
    R[P] := AMsgs[Q];
    Inc(P);
  end;
  AMsgs := R;
end;

function NormalizeAssistantToolBlocks(const AIn: TChatMessageArray;
  out AOut: TChatMessageArray): Boolean;
var
  I, EndIdx: Integer;
  Block: TChatMessageArray;
  Orphans: TIndexList;
  OrphanCount: Integer;
begin
  Result := False;
  AOut := AIn;
  I := 0;
  while I < Length(AOut) do begin
    if (AOut[I].Role <> crAssistant) or (Length(AOut[I].ToolCalls) = 0) then begin
      Inc(I);
      Continue;
    end;
    EndIdx := FindTurnEndIndex(AOut, I);
    if TryBuildToolBlock(AOut, I, EndIdx, Block, Orphans, OrphanCount) then begin
      ReplaceSegmentInsertBlock(AOut, I, EndIdx, Block, Orphans, OrphanCount);
      Result := True;
      Inc(I);
      while (I < Length(AOut)) and (AOut[I].Role = crTool) do
        Inc(I);
      Continue;
    end;
    Inc(I);
    while (I < Length(AOut)) and (AOut[I].Role = crTool) do
      Inc(I);
  end;
end;

function RepairIncompleteToolTurns(const AIn: TChatMessageArray;
  out AOut: TChatMessageArray): Boolean;
begin
  Result := NormalizeAssistantToolBlocks(AIn, AOut);
end;

function IsInterruptedToolMessage(const AMsg: TChatMessage): Boolean;
begin
  if AMsg.Role <> crTool then
    Exit(False);
  if SameText(Trim(AMsg.VisualSummary), 'TOOL_INTERRUPTED') then
    Exit(True);
  Result := Pos('"error_code":"TOOL_INTERRUPTED"', AMsg.Content) > 0;
end;

function ShouldCollapseTurn(const AMsgs: TChatMessageArray; AAsstIdx, AEndIdx: Integer): Boolean;
var
  J: Integer;
begin
  if Length(AMsgs[AAsstIdx].ToolCalls) = 0 then
    Exit(False);
  for J := AAsstIdx + 1 to AEndIdx - 1 do
    if (AMsgs[J].Role = crTool) and (not IsInterruptedToolMessage(AMsgs[J])) then
      Exit(False);
  Result := True;
end;

function CollapseFullyInterruptedTurns(const AIn: TChatMessageArray;
  out AOut: TChatMessageArray): Boolean;
var
  I, EndIdx, J, K: Integer;
  Note: TChatMessage;
begin
  Result := False;
  AOut := AIn;
  I := 0;
  while I < Length(AOut) do begin
    if (AOut[I].Role <> crAssistant) or (Length(AOut[I].ToolCalls) = 0) then begin
      Inc(I);
      Continue;
    end;
    EndIdx := FindTurnEndIndex(AOut, I);
    if not ShouldCollapseTurn(AOut, I, EndIdx) then begin
      Inc(I);
      while (I < Length(AOut)) and (AOut[I].Role = crTool) do
        Inc(I);
      Continue;
    end;
    Note := AOut[I];
    SetLength(Note.ToolCalls, 0);
    if Trim(Note.Content) = '' then
      Note.Content := COLLAPSED_TURN_NOTE
    else
      Note.Content := Note.Content + LineEnding + LineEnding +
        '*(Prior tool calls in this step did not finish.)*';
    for J := EndIdx - 1 downto I + 1 do
      if AOut[J].Role = crTool then begin
        for K := J to High(AOut) - 1 do
          AOut[K] := AOut[K + 1];
        SetLength(AOut, Length(AOut) - 1);
        Dec(EndIdx);
      end;
    AOut[I] := Note;
    Result := True;
    Inc(I);
  end;
end;

function RepairToolHistory(const AIn: TChatMessageArray; out AOut: TChatMessageArray;
  AAggressive: Boolean): Boolean;
begin
  Result := NormalizeAssistantToolBlocks(AIn, AOut);
  if AAggressive and CollapseFullyInterruptedTurns(AOut, AOut) then
    Result := True;
end;

function PrepareMessagesForLlmApi(const AIn: TChatMessageArray): TChatMessageArray;
var
  I, O: Integer;
begin
  SetLength(Result, 0);
  for I := 0 to High(AIn) do begin
    if (AIn[I].Role = crAssistant) and (Pos('❌ LLM Request Error:', AIn[I].Content) = 1) then
      Continue;
    O := Length(Result);
    SetLength(Result, O + 1);
    Result[O] := AIn[I];
  end;
end;

function IsLikelyProviderOutage(const AMessage: string): Boolean;
var
  L: string;
begin
  L := LowerCase(Trim(AMessage));
  Result := (Pos('something unexpected happened', L) > 0) or
    (Pos('try again in a moment', L) > 0) or
    (Pos('contact us if the issue persists', L) > 0);
end;

end.