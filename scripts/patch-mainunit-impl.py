#!/usr/bin/env python3
"""Replace key implementation blocks in mainunit.pas."""
from pathlib import Path
import re

path = Path(__file__).resolve().parents[1] / "mainunit.pas"
t = path.read_text()

# BindSessionToUI utility clear
t = t.replace(
    "  if Assigned(FUtilityExecDetail) then\n    FUtilityExecDetail.ClearDetail;",
    "  memUtilityExecDetail.Clear;",
)

# SelectSession
t = t.replace(
    "  BindSessionToUI(ASessionId);\n  SyncChatSessionTabs;\nend;",
    "  BindSessionToUI(ASessionId);\n  UpdateSessionCaption;\nend;",
)

# Remove old session tab procedures (whole blocks)
for proc in [
    "SyncChatSessionTabs",
    "RefreshChatSessionRunningBadges",
    "ChatSessionTabChange",
    "ChatSessionCloseQuery",
    "ChatSessionsPlusClick",
    "DeferredTabArchiveClose",
]:
    pat = re.compile(
        rf"procedure TLazyCodingAgentForm\.{proc}\b.*?^end;\n",
        re.MULTILINE | re.DOTALL,
    )
    t, c = pat.subn("", t)
    print(f"removed {proc}: {c}")

# Add UpdateSessionCaption before AgentStateIsRunning if missing
if "procedure TLazyCodingAgentForm.UpdateSessionCaption" not in t:
    insert = """
procedure TLazyCodingAgentForm.UpdateSessionCaption;
var
  S: TChatSessionInfo;
  Cap: string;
begin
  if not Assigned(FChatPanel) then Exit;
  Cap := '(no session)';
  if Assigned(ActiveStore) and ActiveStore.FindSessionInfo(FCurrentSessionId, S) then begin
    Cap := S.Title;
    if Assigned(FActiveHub) and FActiveHub.IsSessionRunning(FCurrentSessionId) then
      Cap := Cap + ' ●';
  end;
  FChatPanel.SetSessionCaption('Session: ' + Cap);
end;

"""
    t = t.replace(
        "function TLazyCodingAgentForm.AgentStateIsRunning",
        insert + "function TLazyCodingAgentForm.AgentStateIsRunning",
    )

# FormCreate - remove chat tab ids
t = t.replace("  FChatTabSessionIds := TStringList.Create;\n", "")
t = t.replace("  FSyncingChatTabs := False;\n", "")

# FormShow - remove RaiseDetachedFloatingForms
t = t.replace("    RaiseDetachedFloatingForms;\n", "")

# PostShowStartup - remove EnsureLayout
t = t.replace(
    "  if Assigned(FChatPanel) then\n    FChatPanel.EnsureLayout;\n",
    "",
)

# FormCloseQuery detach
for p in ["Navigation", "Chat", "Reserved", "Utility", "Terminal"]:
    t = t.replace(f"  FinalizeDetachSlotForClose(pi{p});\n", "")

# FormDestroy
t = re.sub(
    r"  for P := Low\(TPanelId\) to High\(TPanelId\) do\n    FreeAndNil\(FDetachSlots\[P\]\);\n",
    "",
    t,
)
t = t.replace("  FreeAndNil(FChatTabSessionIds);\n\n", "")

# Remove detach-related procedures
for proc in [
    "FinalizeDetachSlotForClose",
    "DetachSlot",
    "FloatingFormRequestAttach",
    "InitDetachSlots",
    "PanelDetachClick",
    "RaiseDetachedFloatingForms",
    "ApplyPanelDetachLayout",
    "ApplyDetachSlotThemes",
    "DockPanelAction",
    "MenuDetachPanel",
    "MenuAttachPanel",
    "CenterTabsPlusClick",
    "CenterTabsChange",
    "CenterEditorCloseAllowForIndex",
    "CenterTabCloseQuery",
    "CenterEditorTabCloseAllow",
    "InitThemedTabHosts",
    "FindEditorTabByPath",
    "FindMarkdownTabByPath",
    "ActiveFileEditorTab",
    "ApplyCenterEditorThemes",
    "ApplyUtilityPlanTabThemes",
    "PromptAllDirtyEditors",
]:
    pat = re.compile(
        rf"(?:function|procedure) TLazyCodingAgentForm\.{proc}\b.*?^end;\n",
        re.MULTILINE | re.DOTALL,
    )
    t, c = pat.subn("", t)
    print(f"removed {proc}: {c}")

# StateChanged
t = t.replace("    SyncChatSessionTabs;\n", "    UpdateSessionCaption;\n")
t = t.replace("      RefreshUtilityPlanTabModels(Models);\n", "      RefreshPlanViewModels(Models);\n")

# HubStateChange badges
t = t.replace("    RefreshChatSessionRunningBadges;\n", "    UpdateSessionCaption;\n")

path.write_text(t)
print("patch-mainunit-impl done")
