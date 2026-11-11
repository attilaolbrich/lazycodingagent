#!/usr/bin/env python3
"""Patch mainunit.pas for static designer layout."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / "mainunit.pas"
text = path.read_text()

uses_old = """uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, Buttons,
  ComCtrls, Menus, FileUtil, uAppTypes, uAgentTypes, uAgentTools, uTheme, fraThemedButton, fraThemedTabs, uWorkspaceState,
  uWorkspaceRegistry, uChatSessionStore, uChatSessionHub, uPanelDetach, uNavigationPanel, uChatPanel,
  uTerminalPanel,
  uAgentEngine, frmSettings, frmNewWorkspace, frmWorkspaceRules,
  uUtilityPlanTab, uUtilityExecutionDetailTab, uAgentExecutionLog, uAgentToolErrorLog,
  uFileEditorTab,
  uFileMarkdownTab, uSyntaxSchemeRegistry, frmSyntaxSchemes,
  frmOpenMarkdown, frmHelp, fpjson, jsonparser;"""

uses_new = """uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, Buttons,
  ComCtrls, Menus, FileUtil, SynEdit, SynEditTypes,
  Terminal.View.LCL,
  uAppTypes, uAgentTypes, uAgentTools, uTheme, uWorkspaceState,
  uWorkspaceRegistry, uChatSessionStore, uChatSessionHub, uNavigationPanel, uChatPanel,
  uTerminalPanel, uMainFileEditor, uPlanView,
  uAgentEngine, frmSettings, frmNewWorkspace, frmWorkspaceRules,
  uAgentExecutionLog, uAgentToolErrorLog,
  uSyntaxSchemeRegistry, frmSyntaxSchemes,
  frmOpenMarkdown, frmHelp, fpjson, jsonparser;"""

text = text.replace(uses_old, uses_new)

# Replace published fields block (from StatusBar1 through pnlTerminalContent)
pub_pat = re.compile(
    r"    StatusBar1: TStatusBar;.*?    pnlTerminalContent: TPanel;\s*\n",
    re.DOTALL,
)
pub_new = """    StatusBar1: TStatusBar;

    pnlMainContainer: TPanel;
    pnlNavRailHost: TPanel;
    sbtnNavHome: TSpeedButton;
    sbtnNavProjects: TSpeedButton;
    sbtnNavSessions: TSpeedButton;
    sbtnNavBots: TSpeedButton;
    sbtnNavTools: TSpeedButton;
    sbtnNavTasks: TSpeedButton;
    sbtnNavToolErrors: TSpeedButton;
    sbtnNavMultiAgent: TSpeedButton;
    sbtnNavExecPlans: TSpeedButton;
    sbtnNavKnowledge: TSpeedButton;
    sbtnNavBrain: TSpeedButton;
    pnlNavHost: TPanel;
    pnlNavChrome: TPanel;
    lblNavTitle: TLabel;
    btnNavHide: TButton;
    pnlNavContent: TPanel;
    lblNavViewTitle: TLabel;
    lblNavViewSub: TLabel;
    btnNavPrimary: TButton;
    btnNavSecondary: TButton;
    lstNavFile: TListBox;
    tvNavProjects: TTreeView;
    lstNavLog: TListBox;
    lstNavErrors: TListBox;
    splNav: TSplitter;
    pnlUtilityHost: TPanel;
    pnlUtilityChrome: TPanel;
    lblUtilityTitle: TLabel;
    btnUtilityHide: TButton;
    pnlUtilityContent: TPanel;
    pgcUtility: TPageControl;
    tsUtilityExecDetail: TTabSheet;
    memUtilityExecDetail: TMemo;
    tsUtilityPlan: TTabSheet;
    pnlPlanHeader: TPanel;
    lblPlanPath: TLabel;
    pnlPlanToolbar: TPanel;
    cboPlanModel: TLcaThemedComboBox;
    btnPlanBuild: TLcaThemedButton;
    lcaPlanBody: TLcaMarkdownView;
    splUtility: TSplitter;
    pnlReservedHost: TPanel;
    pnlReservedChrome: TPanel;
    lblReservedTitle: TLabel;
    btnReservedHide: TButton;
    pnlReservedContent: TPanel;
    memReserved: TMemo;
    splReserved: TSplitter;
    pnlChatHost: TPanel;
    pnlChatChrome: TPanel;
    lblChatTitle: TLabel;
    btnChatHide: TButton;
    pgcCenter: TPageControl;
    tsChat: TTabSheet;
    lblChatHeading: TLabel;
    lblChatSession: TLabel;
    lblChatSub: TLabel;
    pnlChatComposer: TPanel;
    lblChatWorkspaceTag: TLabel;
    memChatPrompt: TMemo;
    pnlChatFooter: TPanel;
    cboChatMode: TComboBox;
    cboChatModel: TComboBox;
    btnChatStop: TButton;
    btnChatSend: TButton;
    memChatHistory: TMemo;
    tsEditor: TTabSheet;
    synEditor: TSynEdit;
    tsMarkdown: TTabSheet;
    memMarkdownPreview: TMemo;
    splTerminal: TSplitter;
    pnlTerminalHost: TPanel;
    pnlTerminalChrome: TPanel;
    lblTerminalTitle: TLabel;
    btnTerminalHide: TButton;
    pnlTerminalContent: TPanel;
    lblTerminalStatus: TLabel;

"""
text, n = pub_pat.subn(pub_new, text, count=1)
if n != 1:
    raise SystemExit(f"published block replace failed: {n}")

# Remove obsolete published handlers
for rem in [
    "    procedure PanelDetachClick(Sender: TObject);\n",
    "    procedure CenterTabsChange(Sender: TObject);\n",
    "    procedure ChatSessionTabChange(Sender: TObject);\n",
    "    procedure FloatingFormRequestAttach(Sender: TObject; AId: TPanelId);\n",
]:
    text = text.replace(rem, "")

path.write_text(text)
print("patch-mainunit phase 1 ok")
