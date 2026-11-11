program test_llm_prompt_stability;
{$mode objfpc}{$H+}
uses
  SysUtils, uAppTypes, uAgentTypes, uAgentTools, uAgentToolBase, uLlmPromptSegments,
  uLlmPromptCacheTypes;

procedure AssertSame(const A, B: string; const AMsg: string);
begin
  if A <> B then
    raise Exception.Create(AMsg + ' (prompt mismatch)');
end;

procedure TestStableSystemPromptHash;
var
  Input: TSystemPromptBuildInput;
  PartsA, PartsB: TStringArray;
  FullA, FullB: string;
  SegA, SegB: TPromptSegmentArray;
  Settings: TPromptCacheSettings;
begin
  Settings := DefaultPromptCacheSettings;
  Input.Mode := wmAsk;
  Input.WorkspaceRoot := '/tmp/project';
  Input.AllowModifyOutsideWorkspace := False;
  Input.ToolsGuidance := 'Available tools (JSON arguments):' + LineEnding +
    '- read_file: Read' + LineEnding;
  Input.RulesText := '';
  Input.WebSearchLine := '';
  FullA := BuildSystemPromptParts(Input, PartsA);
  FullB := BuildSystemPromptParts(Input, PartsB);
  AssertSame(FullA, FullB, 'Identical inputs must produce identical system prompt');
  SegA := BuildSystemPromptSegments(Input, Settings);
  SegB := BuildSystemPromptSegments(Input, Settings);
  if (Length(SegA) <> Length(SegB)) or (SegA[1].ContentHash <> SegB[1].ContentHash) then
    raise Exception.Create('Tool definition segment hash must be stable');
end;

procedure TestToolDefinitionSortOrder;
var
  Ctx: TAgentToolContext;
  Reg: TAgentToolRegistry;
  Defs: TToolDefArray;
  I: Integer;
begin
  Ctx := TAgentToolContext.Create(ExpandFileName('.'));
  Reg := TAgentToolRegistry.Create(Ctx);
  try
    Defs := Reg.GetToolDefinitions(wmAgent);
    for I := Low(Defs) + 1 to High(Defs) do
      if CompareText(Defs[I].Name, Defs[I - 1].Name) < 0 then
        raise Exception.Create('Tool definitions must be sorted by name');
  finally
    Reg.Free;
    Ctx.Free;
  end;
end;

procedure TestSegmentHashChangesWithRules;
var
  Input: TSystemPromptBuildInput;
  SegA, SegB: TPromptSegmentArray;
  Settings: TPromptCacheSettings;
begin
  Settings := DefaultPromptCacheSettings;
  Input.Mode := wmAgent;
  Input.WorkspaceRoot := '/tmp/project';
  Input.AllowModifyOutsideWorkspace := False;
  Input.ToolsGuidance := 'tools';
  Input.WebSearchLine := '';
  Input.RulesText := '';
  SegA := BuildSystemPromptSegments(Input, Settings);
  Input.RulesText := 'rule one';
  SegB := BuildSystemPromptSegments(Input, Settings);
  if (Length(SegA) < 4) or (Length(SegB) < 4) then
    raise Exception.Create('Expected project context segment');
  if SegA[3].ContentHash = SegB[3].ContentHash then
    raise Exception.Create('Rules change must change project context segment hash');
end;

procedure TestEmptyToolsGuidanceOmitsToolList;
var
  Input: TSystemPromptBuildInput;
  Parts: TStringArray;
  Full: string;
  Seg: TPromptSegmentArray;
  Settings: TPromptCacheSettings;
begin
  Settings := DefaultPromptCacheSettings;
  Input.Mode := wmAgent;
  Input.WorkspaceRoot := '/tmp/project';
  Input.AllowModifyOutsideWorkspace := False;
  Input.ToolsGuidance := '';
  Input.RulesText := '';
  Input.WebSearchLine := '';
  Full := BuildSystemPromptParts(Input, Parts);
  if Pos('Available tools (JSON arguments):', Full) > 0 then
    raise Exception.Create('Empty ToolsGuidance must omit tool list header');
  if Pos('Parameters:', Full) > 0 then
    raise Exception.Create('Empty ToolsGuidance must not embed parameter schemas');
  Seg := BuildSystemPromptSegments(Input, Settings);
  if (Length(Seg) < 2) or (Trim(Seg[1].Content) <> '') then
    raise Exception.Create('Tool definition segment should be empty when ToolsGuidance is empty');
end;

begin
  TestStableSystemPromptHash;
  TestToolDefinitionSortOrder;
  TestSegmentHashChangesWithRules;
  TestEmptyToolsGuidanceOmitsToolList;
  WriteLn('LLM prompt stability tests passed.');
end.
