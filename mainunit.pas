unit mainunit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, Buttons,
  ComCtrls, Menus, FileUtil, SynEdit, SynGutterBase,
  uAppTypes, uAgentTypes, uAgentTools, LcaTheme, LcaThemedPageTabBar, LcaPaintButton,
  LcaPaintComboBox, LcaPaintNavRailButton, LcaTerminalPanel, LcaThemedMainMenu, LcaThemedTitleBar, LcaFormChrome,
  uWorkspaceState, uWorkspaceRegistry, uChatSessionStore, uChatSessionHub, uNavigationPanel,
  uChatPanel, uMainFileEditor, uPlanView,
  uAgentEngine,
  uAgentExecutionLog, uAgentToolErrorLog,
  uSyntaxSchemeRegistry,
  LcaMarkdownView, LcaPaintNavList, uPanelDetach, uThemeHooks,
  LcaThemedMessageBox,
  fpjson, jsonparser;

type
  TExecDetailSource = (edsNone, edsExecLog, edsToolError);

  { TLazyCodingAgentForm }
  TLazyCodingAgentForm = class(TForm)
  published
    lcaTitleBar: TLcaThemedTitleBar;
    Panel1: TPanel;
    pnlMainContainer: TPanel;
    pnlNavRailHost: TPanel;
    sbtnNavToolErrors: TLcaPaintNavRailButton;
    sbtnNavTasks: TLcaPaintNavRailButton;
    sbtnNavTools: TLcaPaintNavRailButton;
    sbtnNavBots: TLcaPaintNavRailButton;
    sbtnNavSessions: TLcaPaintNavRailButton;
    sbtnNavProjects: TLcaPaintNavRailButton;
    sbtnNavHome: TLcaPaintNavRailButton;
    pnlNavHost: TPanel;
    pnlNavChrome: TPanel;
    pnlNavChromeTitleHost: TPanel;
    lblNavTitle: TLabel;
    pnlNavChromeActions: TPanel;
    btnNavDetach: TLcaPaintButton;
    btnNavHide: TLcaPaintButton;
    pnlNavContent: TPanel;
    lblNavViewTitle: TLabel;
    lblNavViewSub: TLabel;
    lblNavComingSoon: TLabel;
    btnNavPrimary: TLcaPaintButton;
    btnNavSecondary: TLcaPaintButton;
    lstNavFile: TLcaPaintNavList;
    tvNavProjects: TTreeView;
    lstNavLog: TLcaPaintNavList;
    lstNavErrors: TLcaPaintNavList;
    splNav: TSplitter;
    pnlUtilityHost: TPanel;
    pnlUtilityChrome: TPanel;
    pnlUtilityTabStripHost: TPanel;
    lcaUtilityTabBar: TLcaThemedPageTabBar;
    pnlUtilityChromeActions: TPanel;
    btnUtilityDetach: TLcaPaintButton;
    btnUtilityHide: TLcaPaintButton;
    pnlUtilityContent: TPanel;
    pgcUtility: TPageControl;
    tsUtilityExecDetail: TTabSheet;
    pnlUtilityExecDetailHost: TPanel;
    tsUtilityPlan: TTabSheet;
    pnlPlanDocTabStripHost: TPanel;
    lcaPlanDocTabBar: TLcaThemedPageTabBar;
    pnlPlanHeader: TPanel;
    lblPlanPath: TLabel;
    btnPlanBuild: TLcaPaintButton;
    cboPlanModel: TLcaPaintComboBox;
    lcaPlanBody: TLcaMarkdownView;
    splUtility: TSplitter;
    pnlReservedHost: TPanel;
    pnlReservedChrome: TPanel;
    pnlReservedChromeTitleHost: TPanel;
    lblReservedTitle: TLabel;
    pnlReservedChromeActions: TPanel;
    btnReservedDetach: TLcaPaintButton;
    btnReservedHide: TLcaPaintButton;
    pnlReservedContent: TPanel;
    memReserved: TMemo;
    splReserved: TSplitter;
    pnlChatHost: TPanel;
    pnlChatChrome: TPanel;
    pnlCenterTabStripHost: TPanel;
    lcaCenterTabBar: TLcaThemedPageTabBar;
    pnlCenterChromeActions: TPanel;
    btnChatDetach: TLcaPaintButton;
    pnlCenterContent: TPanel;
    pgcCenter: TPageControl;
    tsChat: TTabSheet;
    pnlChatSessionTabStripHost: TPanel;
    lcaChatSessionTabBar: TLcaThemedPageTabBar;
    pnlChatHeader: TPanel;
    lblChatHeading: TLabel;
    lblChatSession: TLabel;
    lblChatSub: TLabel;
    pnlChatComposer: TPanel;
    lblChatWorkspaceTag: TLabel;
    memChatPrompt: TMemo;
    pnlChatFooter: TPanel;
    pnlChatFooterRowActions: TPanel;
    pnlWrapChatAttach: TPanel;
    btnChatAttachImage: TLcaPaintButton;
    pnlWrapChatMode: TPanel;
    cboChatMode: TLcaPaintComboBox;
    pnlWrapChatModel: TPanel;
    cboChatModel: TLcaPaintComboBox;
    pnlWrapChatStop: TPanel;
    btnChatStop: TLcaPaintButton;
    pnlWrapChatSend: TPanel;
    btnChatSend: TLcaPaintButton;
    pnlChatFooterRowCheck: TPanel;
    chkChatAllowModifyOutside: TCheckBox;
    lblChatAllowModifyOutside: TLabel;
    pnlChatHistoryHost: TPanel;
    lcaChatHistory: TLcaMarkdownView;
    tsEditor: TTabSheet;
    synEditor: TSynEdit;
    tsMarkdown: TTabSheet;
    pnlMarkdownPreviewHost: TPanel;
    splTerminal: TSplitter;
    pnlTerminalHost: TPanel;
    pnlTerminalChrome: TPanel;
    pnlTerminalChromeTitleHost: TPanel;
    lblTerminalTitle: TLabel;
    pnlTerminalChromeActions: TPanel;
    btnTerminalDetach: TLcaPaintButton;
    btnTerminalHide: TLcaPaintButton;
    pnlTerminalContent: TPanel;
    lblTerminalStatus: TLabel;
    lcaTerminalPanel: TLcaTerminalPanel;
    pnlChatAttachmentStrip: TPanel;
    StatusBar1: TStatusBar;
    lcaMainMenu: TLcaThemedMainMenu;
    mnuFile: TMenuItem;
    mnuFileNew: TMenuItem;
    mnuFileOpen: TMenuItem;
    mnuFileRemoveWorkspace: TMenuItem;
    mnuFileSave: TMenuItem;
    mnuFileSaveFile: TMenuItem;
    mnuFileSep1: TMenuItem;
    mnuFileExit: TMenuItem;
    mnuView: TMenuItem;
    mnuViewToggleTheme: TMenuItem;
    mnuViewResetLayout: TMenuItem;
    mnuViewTerminal: TMenuItem;
    mnuViewSyntaxSep: TMenuItem;
    mnuViewSyntaxSchemes: TMenuItem;
    mnuViewActiveSchemes: TMenuItem;
    mnuWorkspace: TMenuItem;
    mnuWorkspaceMultiAgent: TMenuItem;
    mnuWorkspaceExecutionPlans: TMenuItem;
    mnuWorkspaceKnowledgeBase: TMenuItem;
    mnuWorkspaceTheBrain: TMenuItem;
    mnuWorkspaceSepRules: TMenuItem;
    mnuWorkspaceProjectRules: TMenuItem;
    mnuAgent: TMenuItem;
    mnuAgentClearHistory: TMenuItem;
    mnuAgentStop: TMenuItem;
    mnuSettings: TMenuItem;
    mnuSettingsOptions: TMenuItem;
    mnuWindow: TMenuItem;
    mnuPanelsVisibility: TMenuItem;
    mnuHelp: TMenuItem;
    mnuHelpUserGuide: TMenuItem;
    mnuHelpAbout: TMenuItem;
    popNavProjects: TPopupMenu;
    mnuTreeOpenInApp: TMenuItem;
    mnuTreeOpenInFileManager: TMenuItem;
    mnuTreeOpenDefault: TMenuItem;
    popNavSessions: TPopupMenu;
    mnuSessionArchive: TMenuItem;
    mnuSessionRestore: TMenuItem;
    mnuSessionDeleteSep: TMenuItem;
    mnuSessionDeletePermanent: TMenuItem;

    procedure PanelHideClick(Sender: TObject);
    procedure PanelDetachClick(Sender: TObject);

    // Published Event Handlers (Form Designer connected)
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
    procedure MnuViewToggleThemeClick(Sender: TObject);
    procedure MnuViewResetLayoutClick(Sender: TObject);
    procedure MnuViewTerminalClick(Sender: TObject);
    procedure SplTerminalMoved(Sender: TObject);
    procedure MnuFileNewClick(Sender: TObject);
    procedure MnuFileOpenClick(Sender: TObject);
    procedure MnuFileRemoveWorkspaceClick(Sender: TObject);
    procedure MnuFileSaveClick(Sender: TObject);
    procedure MnuFileSaveFileClick(Sender: TObject);
    procedure MnuFileExitClick(Sender: TObject);
    procedure MnuViewSyntaxSchemesClick(Sender: TObject);
    procedure MnuAgentClearHistoryClick(Sender: TObject);
    procedure MnuAgentStopClick(Sender: TObject);
    procedure MnuSettingsOptionsClick(Sender: TObject);
    procedure MnuWorkspaceProjectRulesClick(Sender: TObject);
    procedure MnuWorkspaceMultiAgentClick(Sender: TObject);
    procedure MnuWorkspaceExecutionPlansClick(Sender: TObject);
    procedure MnuWorkspaceKnowledgeBaseClick(Sender: TObject);
    procedure MnuWorkspaceTheBrainClick(Sender: TObject);
    procedure MnuHelpUserGuideClick(Sender: TObject);
    procedure MnuHelpAboutClick(Sender: TObject);
    procedure NavRailBtnClick(Sender: TObject);
    procedure ChkChatAllowModifyOutsideClick(Sender: TObject);
    procedure LblChatAllowModifyOutsideClick(Sender: TObject);
  private
    FChatSessionTabIds: TStringList;
    FPlanDocPaths: TStringList;
    FPlanDocContents: TStringList;
    FActivePlanDocIndex: Integer;
    FState: TWorkspaceState;
    FSessionHubs: TChatSessionHubManager;
    FActiveHub: TChatSessionHub;
    FUpdatingState: Boolean;
    FPendingInitialDockLayout: Boolean;
    FPendingInitialWorkspaceUI: Boolean;
    FDeferThemesUntilShown: Boolean;
    FPostShowStartupScheduled: Boolean;
    FPostShowStartupTimer: TTimer;
    FTerminalStartQueued: Boolean;
    FTerminalRetryTimer: TTimer;
    FTerminalRetryCount: Integer;
    FFormChrome: TLcaFormChrome;

    FNavRailBtns: array[TNavigationItem] of TLcaPaintNavRailButton;
    FNavContent: TNavContentControl;
    FChatPanel: TChatPanel;
    FSyntaxSchemes: TSyntaxSchemeRegistry;

    FFileEditor: TMainFileEditor;
    FPlanView: TPlanView;
    FMarkdownPreview: TLcaMarkdownView;
    FExecDetailView: TLcaMarkdownView;
    FExecDetailSource: TExecDetailSource;
    FExecDetailIndex: Integer;
    FPanelDetach: TPanelDetachManager;
    FMarkdownPath: string;
    FCurrentRunMode: TWorkspaceMode;
    FPlanSavedThisRun: Boolean;
    FExecutionLogFollowLive: Boolean;
    FStatusRunStep: Integer;
    FStatusRunMaxSteps: Integer;
    FExecDetailRefreshQueued: Boolean;
    FExecDetailPendingIndex: Integer;
    FExecDetailPendingSource: TExecDetailSource;

    FRegistry: TWorkspaceRegistry;
    FCurrentSessionId: string;
    FNavWorkCaptions: TStringList;
    FNavWorkIds: TStringList;
    FNavSessionCaptions: TStringList;
    FNavSessionIds: TStringList;
    FNavSessionArchived: TStringList;

    function ActiveAgent: TAgentEngine;
    function ActiveStore: TChatSessionStore;
    procedure EnsureActiveHub;
    procedure SaveCurrentSession;
    procedure BindSessionToUI(const ASessionId: string);
    procedure SelectSession(const ASessionId: string);
    procedure UpdateSessionCaption;
    function AgentStateIsRunning(AState: TAgentState): Boolean;
    procedure ApplySessionComposerState;
    procedure ApplyAllowModifyOutsideToSession(const ASessionId: string; AValue: Boolean);
    procedure LoadAllowModifyOutsideForSession(const ASessionId: string);
    procedure HandleBrowserSensitiveConfirm(const AMessage: string; var AApproved,
      AAllowForSession: Boolean);
    procedure ActivateWorkspace(const AWorkspaceId: string);
    procedure DeactivateWorkspace;
    procedure RemoveWorkspaceFromList(const AWorkspaceId: string);
    function ResolveWorkspaceIdForRemoval: string;
    function AddOrActivateFolder(const ADisplayName, AFolderPath: string): Boolean;
    procedure RefreshWorkspaceNav;
    procedure RefreshSessionNav;
    procedure RefreshChatSessionTabs;
    procedure NavWorkspaceSelect(Sender: TObject; const AWorkspaceId: string);
    procedure NavWorkspaceNew(Sender: TObject);
    procedure NavWorkspaceDelete(Sender: TObject; const AWorkspaceId: string);
    procedure NavSessionSelect(Sender: TObject; const ASessionId: string);
    procedure CreateAndSelectNewSession;
    procedure NavSessionNew(Sender: TObject);
    procedure DoArchiveSession(const ASessionId: string);
    procedure EnsureActiveNonArchivedSession;
    procedure NavSessionArchive(Sender: TObject; const ASessionId: string);
    procedure NavSessionRestore(Sender: TObject; const ASessionId: string);
    procedure NavSessionDelete(Sender: TObject; const ASessionId: string);
    procedure ApplyWorkspaceChatVisibility;

    function ParsePlanToolSuccess(const AResult: TToolExecutionResult;
      out APath, AContent: string): Boolean;
    procedure OpenPlanInUtilityTab(const APath, AContent: string);
    procedure TrySaveProposedPlanFromChat;
    procedure PlanBuildRequested(Sender: TObject; const APlanPath, APlanContent,
      AModelId: string);
    procedure RefreshPlanViewModels(const AModels: array of TSavedModel);
    function PlanDocCaption(const APath: string): string;
    function FindPlanDocIndex(const APath: string): Integer;
    function EnsurePlanDocOpen(const APath, AContent: string): Integer;
    procedure ApplyPlanViewModelsAndTheme;
    procedure ClearActivePlanDocument;
    procedure SelectPlanDocIndex(AIndex: Integer);
    procedure RefreshPlanDocTabs;
    procedure TabBarPlanDocSelect(Sender: TObject; ATabIndex: Integer);
    procedure TabBarPlanDocClose(Sender: TObject; ATabIndex: Integer; var AllowClose: Boolean);

    function IsMarkdownFile(const APath: string): Boolean;
    procedure OpenFileInCenterTab(const APath: string);
    procedure OpenMarkdownInCenterTab(const APath: string);
    procedure ShowChatCenterTab;
    procedure ApplyEditorTheme;
    procedure RefreshEditorScheme;
    function SaveActiveEditorFile: Boolean;
    function PromptDirtyEditor: Boolean;
    procedure RebuildActiveSchemeMenu;
    procedure MenuSelectSyntaxScheme(Sender: TObject);
    procedure NavFileOpen(Sender: TObject; const AFilePath: string);

    procedure InitWorkspaceSubControls;
    procedure InitNavRailButtons;
    procedure UpdateNavRailSelection;
    procedure PopulateMenusAndCombos;
    procedure StateChanged(Sender: TObject);
    procedure ApplyDockPanelsLayout;
    procedure PanelDetachFloatChanged(Sender: TObject; AId: TPanelId; AFloating: Boolean);
    procedure SyncCenterAddTabNav;
    procedure WireThemedTabBars;
    procedure InitCenterTabStrip;
    procedure TabBarCenterAddTab(Sender: TObject);
    procedure TabBarCenterTabClose(Sender: TObject; TabSheet: TTabSheet; var AllowClose: Boolean);
    procedure TabBarChatSessionSelect(Sender: TObject; ATabIndex: Integer);
    procedure TabBarChatSessionClose(Sender: TObject; ATabIndex: Integer; var AllowClose: Boolean);
    procedure SyncTerminalWorkingDirectory;
    procedure ScheduleDeferredTerminalStart;
    procedure DeferredEnsureTerminal(Data: PtrInt);
    procedure DeferredEnforceHiddenPageTabs(Data: PtrInt);
    procedure DeferredRefreshThemedChromeButtons(Data: PtrInt);
    procedure RefreshThemedButtonsRecursive(ARoot: TWinControl);
    procedure ScheduleTerminalStartRetry;
    procedure TerminalRetryTimer(Sender: TObject);
    procedure TerminalStatus(Sender: TObject; const AMessage: string);
    function IsTerminalSurfaceVisible: Boolean;
    function EffectiveTerminalDockHeight: Integer;
    procedure ApplyAllThemes;
    procedure ApplyPlatformChromeThemes;
    procedure SchedulePostShowStartup;
    procedure PostShowStartup(Sender: TObject);
    procedure ApplyInitialStartupThemes;
    procedure RebuildWindowMenu;

    procedure PanelHideClickAction(AId: TPanelId);
    procedure ChatPrompt(Sender: TObject; const APrompt: string;
      const AAttachments: array of TChatAttachment; AMode: TWorkspaceMode;
      const AModel: string);
    procedure ChatModeChange(Sender: TObject; AMode: TWorkspaceMode);
    procedure ChatModelChange(Sender: TObject; const AModel: string);
    procedure ChatCancel(Sender: TObject);

    procedure HubStateChange(Sender: TObject; const ASessionId: string;
      AOldState, ANewState: TAgentState; AStep, AMaxSteps: Integer);
    procedure HubMessageAdded(Sender: TObject; const ASessionId: string; const AMsg: TChatMessage);
    procedure HubToolCall(Sender: TObject; const ASessionId: string; const AToolName, AArgs: string);
    procedure HubToolResult(Sender: TObject; const ASessionId: string; const AToolName,
      AArgsJson: string; const AResult: TToolExecutionResult);
    procedure HubExecutionLogAdded(Sender: TObject; const ASessionId: string; AEntryIndex: Integer);
    procedure HubToolErrorAdded(Sender: TObject; const ASessionId: string; AEntryIndex: Integer);
    procedure NavLogEntrySelected(Sender: TObject; AIndex: Integer);
    procedure NavToolErrorEntrySelected(Sender: TObject; AIndex: Integer);
    procedure NavClearExecutionLog(Sender: TObject);
    procedure NavClearToolErrorLog(Sender: TObject);
    procedure BindExecutionLogToNav(const ASessionId: string);
    procedure BindToolErrorLogToNav(const ASessionId: string);
    procedure DetachNavSessionLogs;
    procedure ShowExecutionLogDetail(AIndex: Integer);
    procedure ShowToolErrorDetail(AIndex: Integer);
    procedure ScheduleExecDetailLiveRefresh(AIndex: Integer; ASource: TExecDetailSource);
    procedure DeferredExecDetailRefresh(Data: PtrInt);
    procedure ApplyExecDetailAtIndex(AIndex: Integer; ASource: TExecDetailSource;
      AOpenTabIfNeeded: Boolean);
    procedure ClearExecDetailView;
    procedure RefreshExecDetailView;
    procedure OpenUtilityExecutionDetailTab;
    function FormatSessionStatusLabel(AState: TAgentState): string;
    procedure RefreshNavTaskList;
    procedure NavTasksRefresh(Sender: TObject);
    procedure SyncHubClientSettings(AHub: TChatSessionHub);

    procedure MenuSelectNav(Sender: TObject);
    procedure MenuSelectMode(Sender: TObject);
    procedure MenuTogglePanel(Sender: TObject);
    procedure ApplyInitialWindowSize;
    procedure EnsureFormOnScreen;
  public
    procedure PrepareVisibleStartup;
    procedure FinishThemingBehindSplash;
    procedure RevealAfterSplash;
    property State: TWorkspaceState read FState;
    property Agent: TAgentEngine read ActiveAgent;
  end;

var
  LazyCodingAgentForm: TLazyCodingAgentForm;

implementation

uses
  frmSplash, uAppIcon, LCLIntf,
  frmSettings, frmNewWorkspace, frmWorkspaceRules, frmSyntaxSchemes, uBrowserManager,
  frmMultiAgentWorkspace, frmExecutionPlansConfig, frmKnowledgeBaseConfig, frmTheBrainConfig,
  uBrowserPermissions, frmBrowserConfirm,
  frmOpenMarkdown, frmHelp, frmPlanBuildConfirm, uGlobalConfigBootstrap, uAppDatabase,
  uLlmToolCalling
  {$IFDEF WINDOWS}, Windows{$ENDIF};

function ToolCallingCapsFromState(const AState: TWorkspaceState): TLlmToolCallingCapabilities;
begin
  Result.NativeToolCalling := AState.LlmNativeToolCalling;
  Result.TextToolCompat := AState.LlmTextToolCompat;
  Result.StreamingEnabled := AState.LlmStreamingEnabled;
end;

{$R *.lfm}

{ TLazyCodingAgentForm }

function TLazyCodingAgentForm.ActiveAgent: TAgentEngine;
begin
  if not Assigned(FActiveHub) or (FCurrentSessionId = '') then
    Exit(nil);
  Result := FActiveHub.EngineFor(FCurrentSessionId);
  if Result = nil then
    Result := FActiveHub.GetOrCreateEngine(FCurrentSessionId);
end;

function TLazyCodingAgentForm.ActiveStore: TChatSessionStore;
begin
  if Assigned(FActiveHub) then
    Result := FActiveHub.Store
  else
    Result := nil;
end;

procedure TLazyCodingAgentForm.EnsureActiveHub;
var
  Hub: TChatSessionHub;
begin
  if not FState.HasActiveWorkspace then begin
    FActiveHub := nil;
    Exit;
  end;
  Hub := FSessionHubs.GetOrCreate(FState.ActiveWorkspaceId, FState.WorkspaceRoot);
  Hub.OnStateChange := @HubStateChange;
  Hub.OnMessageAdded := @HubMessageAdded;
  Hub.OnToolCall := @HubToolCall;
  Hub.OnToolResult := @HubToolResult;
  Hub.OnExecutionLogAdded := @HubExecutionLogAdded;
  Hub.OnToolErrorAdded := @HubToolErrorAdded;
  SyncHubClientSettings(Hub);
  FActiveHub := Hub;
end;

procedure TLazyCodingAgentForm.SyncHubClientSettings(AHub: TChatSessionHub);
begin
  if not Assigned(AHub) then Exit;
  AHub.ApplyClientSettings(FState.Provider, FState.ApiKey, FState.BaseUrl, FState.Model,
    FState.Temperature, FState.MaxTokens, FState.MaxSteps, FState.AutoSummarizeContext,
    FState.ContextWindowTokens, FState.SummarizeThreshold,
    FState.LlmConnectTimeoutMs, FState.LlmReadTimeoutMs, FState.LlmHttpRetryCount,
    FState.PromptCacheSettings, ToolCallingCapsFromState(FState), FState.LearnMode);
end;

procedure TLazyCodingAgentForm.ApplyAllowModifyOutsideToSession(const ASessionId: string;
  AValue: Boolean);
var
  Eng: TAgentEngine;
begin
  if (ASessionId = '') or not Assigned(ActiveStore) then Exit;
  ActiveStore.SetAllowModifyOutside(ASessionId, AValue);
  if Assigned(FActiveHub) then begin
    Eng := FActiveHub.EngineFor(ASessionId);
    if Assigned(Eng) then
      Eng.Context.AllowModifyOutsideWorkspace := AValue;
  end;
end;

procedure TLazyCodingAgentForm.HandleBrowserSensitiveConfirm(const AMessage: string;
  var AApproved, AAllowForSession: Boolean);
begin
  AApproved := ConfirmSensitiveBrowserAction(AMessage, FState.Theme, AAllowForSession);
  if AApproved and AAllowForSession and (FCurrentSessionId <> '') and Assigned(ActiveStore) then
  begin
    ActiveStore.SetAllowBrowserSensitive(FCurrentSessionId, True);
    if Assigned(FActiveHub) then
      FActiveHub.GetOrCreateEngine(FCurrentSessionId).Context.AllowBrowserSensitive := True;
  end;
end;

procedure TLazyCodingAgentForm.LoadAllowModifyOutsideForSession(const ASessionId: string);
var
  Info: TChatSessionInfo;
  Value: Boolean;
  Eng: TAgentEngine;
  HasInfo: Boolean;
begin
  Value := False;
  HasInfo := Assigned(ActiveStore) and ActiveStore.FindSessionInfo(ASessionId, Info);
  if HasInfo then
    Value := Info.AllowModifyOutside;
  if Assigned(FChatPanel) then
    FChatPanel.SetAllowModifyOutsideChecked(Value);
  if Assigned(FActiveHub) then begin
    Eng := FActiveHub.GetOrCreateEngine(ASessionId);
    Eng.Context.AllowModifyOutsideWorkspace := Value;
    Eng.Context.ChatSessionId := ASessionId;
    if HasInfo then begin
      Eng.Context.AllowBrowserLocalhost := Info.AllowBrowserLocalhost;
      Eng.Context.AllowBrowserInteractive := Info.AllowBrowserInteractive;
      Eng.Context.AllowBrowserSensitive := Info.AllowBrowserSensitive;
    end
    else begin
      Eng.Context.AllowBrowserLocalhost := False;
      Eng.Context.AllowBrowserInteractive := False;
      Eng.Context.AllowBrowserSensitive := False;
    end;
  end;
end;

procedure TLazyCodingAgentForm.ChkChatAllowModifyOutsideClick(Sender: TObject);
begin
  if not Assigned(FChatPanel) then Exit;
  if FCurrentSessionId = '' then Exit;
  if Assigned(FActiveHub) and FActiveHub.IsSessionRunning(FCurrentSessionId) then Exit;
  ApplyAllowModifyOutsideToSession(FCurrentSessionId, FChatPanel.GetAllowModifyOutsideChecked);
end;

procedure TLazyCodingAgentForm.LblChatAllowModifyOutsideClick(Sender: TObject);
begin
  if not Assigned(chkChatAllowModifyOutside) or not chkChatAllowModifyOutside.Enabled then Exit;
  chkChatAllowModifyOutside.Checked := not chkChatAllowModifyOutside.Checked;
end;

procedure TLazyCodingAgentForm.ApplySessionComposerState;
var
  Info: TChatSessionInfo;
  Archived: Boolean;
  Running: Boolean;
begin
  if not Assigned(FChatPanel) then Exit;
  Archived := False;
  Running := Assigned(FActiveHub) and (FCurrentSessionId <> '') and
    FActiveHub.IsSessionRunning(FCurrentSessionId);
  if Assigned(ActiveStore) and ActiveStore.FindSessionInfo(FCurrentSessionId, Info) then
    Archived := Info.Archived;
  if Archived or Running then
    FChatPanel.SetComposerEnabled(False)
  else
    FChatPanel.SetComposerEnabled(True);
end;

procedure TLazyCodingAgentForm.BindSessionToUI(const ASessionId: string);
var
  E: TAgentEngine;
  I: Integer;
  Msgs: TChatMessageArray;
begin
  if ASessionId = '' then Exit;
  EnsureActiveHub;
  if not Assigned(FActiveHub) then Exit;

  E := FActiveHub.GetOrCreateEngine(ASessionId);
  Msgs := nil;
  SetLength(Msgs, E.GetMessageCount);
  for I := 0 to E.GetMessageCount - 1 do
    Msgs[I] := E.GetMessage(I);

  if Assigned(FChatPanel) then begin
    FChatPanel.ReloadFromMessages(Msgs, FState.DebuggingMode);
    FChatPanel.SetRunning(E.IsRunActive);
  end;
  LoadAllowModifyOutsideForSession(ASessionId);
  ApplySessionComposerState;
  BindExecutionLogToNav(ASessionId);
  BindToolErrorLogToNav(ASessionId);
  RefreshNavTaskList;
  ClearExecDetailView;
end;

procedure TLazyCodingAgentForm.BindExecutionLogToNav(const ASessionId: string);
var
  Log: TAgentExecutionLog;
begin
  if not Assigned(FNavContent) then Exit;
  Log := nil;
  if (ASessionId <> '') and FState.HasActiveWorkspace then begin
    EnsureActiveHub;
    if Assigned(FActiveHub) then begin
      FActiveHub.GetOrCreateEngine(ASessionId);
      Log := FActiveHub.ExecutionLogFor(ASessionId);
    end;
  end;
  FNavContent.BindExecutionLog(Log);
end;

procedure TLazyCodingAgentForm.BindToolErrorLogToNav(const ASessionId: string);
var
  Log: TAgentToolErrorLog;
begin
  if not Assigned(FNavContent) then Exit;
  Log := nil;
  if (ASessionId <> '') and FState.HasActiveWorkspace then begin
    EnsureActiveHub;
    if Assigned(FActiveHub) then begin
      FActiveHub.GetOrCreateEngine(ASessionId);
      Log := FActiveHub.ToolErrorLogFor(ASessionId);
    end;
  end;
  FNavContent.BindToolErrorLog(Log);
end;

procedure TLazyCodingAgentForm.SelectSession(const ASessionId: string);
begin
  if ASessionId = '' then Exit;
  if SameText(ASessionId, FCurrentSessionId) then Exit;
  SaveCurrentSession;
  FCurrentSessionId := ASessionId;
  if Assigned(ActiveStore) then
    ActiveStore.SetLastSessionId(ASessionId);
  if FState.HasActiveWorkspace then
    FRegistry.SetLastSessionId(FState.ActiveWorkspaceId, ASessionId);
  BindSessionToUI(ASessionId);
  UpdateSessionCaption;
end;



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
  FChatPanel.SetSessionId(FCurrentSessionId);
end;

function TLazyCodingAgentForm.AgentStateIsRunning(AState: TAgentState): Boolean;
begin
  Result := not (AState in [asIdle, asFinished, asError]);
end;


procedure TLazyCodingAgentForm.FormCreate(Sender: TObject);
begin
  if csDesigning in ComponentState then Exit;
  ReportSplashLoadProgress(5);
  ApplyOwlApplicationIcon;
  Caption := 'LazyCodingAgent — AI Workspace';
  FUpdatingState := False;
  FTerminalStartQueued := False;
  FPendingInitialDockLayout := True;
  FPendingInitialWorkspaceUI := True;
  FDeferThemesUntilShown := True;
  FPostShowStartupScheduled := False;

  FPostShowStartupTimer := TTimer.Create(Self);
  FPostShowStartupTimer.Enabled := False;
  FPostShowStartupTimer.Interval := 1;
  FPostShowStartupTimer.OnTimer := @PostShowStartup;

  EnsureGlobalConfigReady;
  FState := TWorkspaceState.Create;
  FState.Load;
  FState.OnChange := @StateChanged;
  ReportSplashLoadProgress(20);

  FRegistry := TWorkspaceRegistry.Create;
  FRegistry.Load;
  ReportSplashLoadProgress(35);

  FSessionHubs := TChatSessionHubManager.Create;
  FActiveHub := nil;
  SetBrowserSensitiveConfirmHandler(@HandleBrowserSensitiveConfirm);
  FNavWorkCaptions := TStringList.Create;
  FNavWorkIds := TStringList.Create;
  FNavSessionCaptions := TStringList.Create;
  FChatSessionTabIds := TStringList.Create;
  FPlanDocPaths := TStringList.Create;
  FPlanDocContents := TStringList.Create;
  FActivePlanDocIndex := -1;
  FNavSessionIds := TStringList.Create;
  FNavSessionArchived := TStringList.Create;
  FCurrentSessionId := '';
  FExecutionLogFollowLive := False;
  FStatusRunStep := 0;
  FStatusRunMaxSteps := 0;
  FExecDetailView := nil;
  FExecDetailSource := edsNone;
  FExecDetailIndex := -1;
  FExecDetailRefreshQueued := False;
  FExecDetailPendingIndex := -1;
  FExecDetailPendingSource := edsNone;

  FSyntaxSchemes := TSyntaxSchemeRegistry.Create;
  FSyntaxSchemes.Load;
  ReportSplashLoadProgress(55);

  mnuWorkspaceSepRules.Tag := -1;
  mnuWorkspaceProjectRules.Tag := -1;

  RegisterThemeCustomHooks;
  WireThemedTabBars;
  InitWorkspaceSubControls;
  ReportSplashLoadProgress(75);
  FPanelDetach := TPanelDetachManager.Create(Self, Self, FState);
  FPanelDetach.OnPanelFloat := @PanelDetachFloatChanged;
  FPanelDetach.Bind(piNavigation, pnlNavHost, pnlNavContent);
  FPanelDetach.Bind(piChat, pnlChatHost, pnlCenterContent);
  FPanelDetach.Bind(piReserved, pnlReservedHost, pnlReservedContent);
  FPanelDetach.Bind(piUtility, pnlUtilityHost, pnlUtilityContent);
  FPanelDetach.Bind(piTerminal, pnlTerminalHost, pnlTerminalContent);
  PopulateMenusAndCombos;
  FFormChrome := AttachLcaFormChrome(Self);
  if Assigned(Application) and Assigned(Application.Icon) then
    Icon := Application.Icon;
  ReportSplashLoadProgress(90);
end;

procedure TLazyCodingAgentForm.ApplyInitialWindowSize;
var
  R: TRect;
  W, H: Integer;
const
  TARGET_PCT = 67;
begin
  if csDesigning in ComponentState then Exit;
  R := Screen.PrimaryMonitor.WorkareaRect;
  W := (R.Width * TARGET_PCT) div 100;
  H := (R.Height * TARGET_PCT) div 100;
  if Constraints.MinWidth > R.Width then
    Constraints.MinWidth := R.Width;
  if Constraints.MinHeight > R.Height then
    Constraints.MinHeight := R.Height;
  if W < Constraints.MinWidth then
    W := Constraints.MinWidth;
  if H < Constraints.MinHeight then
    H := Constraints.MinHeight;
  if W > R.Width then
    W := R.Width;
  if H > R.Height then
    H := R.Height;
  Width := W;
  Height := H;
  Position := poScreenCenter;
  Left := R.Left + (R.Width - W) div 2;
  Top := R.Top + (R.Height - H) div 2;
end;

procedure TLazyCodingAgentForm.EnsureFormOnScreen;
var
  R: TRect;
begin
  if csDesigning in ComponentState then Exit;
  R := Screen.PrimaryMonitor.WorkareaRect;
  if (Left + Width < R.Left + 48) or (Left > R.Right - 48) or
     (Top + Height < R.Top + 48) or (Top > R.Bottom - 48) then
    ApplyInitialWindowSize
  else begin
    if Width > R.Width then
      Width := R.Width;
    if Height > R.Height then
      Height := R.Height;
  end;
end;

procedure TLazyCodingAgentForm.RevealAfterSplash;
begin
  if csDesigning in ComponentState then Exit;
  ApplyInitialWindowSize;
  EnsureFormOnScreen;
  WindowState := wsNormal;
  Visible := True;
  Show;
  BringToFront;
  {$IFDEF WINDOWS}
  if HandleAllocated then begin
    ShowWindow(Handle, SW_SHOW);
    SetForegroundWindow(Handle);
  end;
  {$ENDIF}
  if Assigned(Application) then
    Application.BringToFront;
end;

procedure TLazyCodingAgentForm.PrepareVisibleStartup;
begin
  if FPendingInitialDockLayout then begin
    FPendingInitialDockLayout := False;
    ApplyDockPanelsLayout;
  end;
  ReportSplashLoadProgress(88);
end;

procedure TLazyCodingAgentForm.ApplyInitialStartupThemes;
begin
  FDeferThemesUntilShown := False;
  ApplyAllThemes;
  EnforcePageControlHiddenTabs(pgcCenter);
  EnforcePageControlHiddenTabs(pgcUtility);
  if Assigned(lcaCenterTabBar) then
    lcaCenterTabBar.RefreshFromPageControl;
  if Assigned(lcaUtilityTabBar) then
    lcaUtilityTabBar.RefreshFromPageControl;
  DeferredEnforceHiddenPageTabs(0);
  DeferredRefreshThemedChromeButtons(0);
  if Assigned(Application) then
    Application.ProcessMessages;
end;

procedure TLazyCodingAgentForm.FinishThemingBehindSplash;
begin
  if csDesigning in ComponentState then Exit;
  if not FDeferThemesUntilShown then Exit;
  ReportSplashLoadProgress(92);
  if not HandleAllocated then
    HandleNeeded;
  if Assigned(FFormChrome) then
    FFormChrome.EnsurePlatformChrome;
  ApplyInitialStartupThemes;
  ReportSplashLoadProgress(100);
end;

procedure TLazyCodingAgentForm.FormShow(Sender: TObject);
begin
  if csDesigning in ComponentState then Exit;
  if Assigned(FFormChrome) then
    FFormChrome.EnsurePlatformChrome;
  if FPendingInitialDockLayout then begin
    FPendingInitialDockLayout := False;
    ApplyDockPanelsLayout;
  end;
  if Assigned(FPanelDetach) then
    FPanelDetach.RaiseFloatingForms;
  SchedulePostShowStartup;
end;

procedure TLazyCodingAgentForm.SchedulePostShowStartup;
begin
  if FPostShowStartupScheduled then Exit;
  FPostShowStartupScheduled := True;
  FPostShowStartupTimer.Enabled := True;
end;

procedure TLazyCodingAgentForm.PostShowStartup(Sender: TObject);
var
  Entry: TWorkspaceEntry;
begin
  FPostShowStartupTimer.Enabled := False;
  if csDesigning in ComponentState then Exit;
  if csDestroying in ComponentState then Exit;
  if not HandleAllocated then Exit;

  if FDeferThemesUntilShown then
    ApplyInitialStartupThemes;
  if FPendingInitialWorkspaceUI then begin
    FPendingInitialWorkspaceUI := False;
    if FRegistry.Count = 0 then
      DeactivateWorkspace
    else if FRegistry.FindById(FRegistry.ActiveWorkspaceId, Entry) then
      ActivateWorkspace(FRegistry.ActiveWorkspaceId)
    else
      DeactivateWorkspace;
  end;
  if FState.IsPanelVisible(piTerminal) then
    ScheduleDeferredTerminalStart;
end;


procedure TLazyCodingAgentForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  I: Integer;
begin
  if csDesigning in ComponentState then Exit;
  CanClose := True;
  if not PromptDirtyEditor then begin
    CanClose := False;
    Exit;
  end;
  if Assigned(FSessionHubs) and FSessionHubs.AnyRunActive then begin
    if LcaMessageDlg('LazyCodingAgent',
      'One or more agent runs are still in progress. Stop all runs and exit?',
      mtConfirmation, [mbYes, mbNo], FState.Theme) <> mrYes then begin
      CanClose := False;
      Exit;
    end;
    FSessionHubs.ShutdownAll(True);
    FActiveHub := nil;
    DetachNavSessionLogs;
  end;
  BrowserManagerShutdownAll;
  if not Assigned(FState) then Exit;
  if Assigned(FSessionHubs) then
    for I := 0 to FSessionHubs.Count - 1 do
      FSessionHubs.HubAt(I).SaveAll;
  SaveCurrentSession;
  if Assigned(FRegistry) then
    FRegistry.Save;
  if Assigned(lcaTerminalPanel) then
    lcaTerminalPanel.Stop;
  if Assigned(FPanelDetach) then
    FPanelDetach.FinalizeOnClose;
end;

procedure TLazyCodingAgentForm.FormDestroy(Sender: TObject);
var
  I: Integer;
begin
  if csDesigning in ComponentState then Exit;
  FreeAndNil(FPanelDetach);
  FreeAndNil(FExecDetailView);
  FreeAndNil(FMarkdownPreview);
  FreeAndNil(FFileEditor);
  if Assigned(FSessionHubs) then begin
    for I := 0 to FSessionHubs.Count - 1 do
      FSessionHubs.HubAt(I).SaveAll;
  end;
  SaveCurrentSession;
  if Assigned(FRegistry) then begin
    FRegistry.Save;
    FreeAndNil(FRegistry);
  end;
  DetachNavSessionLogs;
  FActiveHub := nil;
  FreeAndNil(FSessionHubs);
  FreeAndNil(FNavWorkCaptions);
  FreeAndNil(FNavWorkIds);
  FreeAndNil(FNavSessionCaptions);
  FreeAndNil(FNavSessionIds);
  FreeAndNil(FNavSessionArchived);
  FreeAndNil(FChatSessionTabIds);
  FreeAndNil(FPlanDocPaths);
  FreeAndNil(FPlanDocContents);
  FreeAndNil(FSyntaxSchemes);

  if Assigned(FState) then begin
    FState.Save;
    FreeAndNil(FState);
  end;
end;




procedure TLazyCodingAgentForm.InitNavRailButtons;
var
  Nav: TNavigationItem;
  Btn: TLcaPaintNavRailButton;
begin
  FNavRailBtns[niHome] := sbtnNavHome;
  FNavRailBtns[niProjects] := sbtnNavProjects;
  FNavRailBtns[niSessions] := sbtnNavSessions;
  FNavRailBtns[niBots] := sbtnNavBots;
  FNavRailBtns[niTools] := sbtnNavTools;
  FNavRailBtns[niTasks] := sbtnNavTasks;
  FNavRailBtns[niToolErrors] := sbtnNavToolErrors;
  for Nav := Low(TNavigationItem) to High(TNavigationItem) do begin
    Btn := FNavRailBtns[Nav];
    if not Assigned(Btn) then Continue;
    Btn.Hint := NavigationHint(Nav);
    Btn.ShowHint := True;
  end;
end;

procedure TLazyCodingAgentForm.NavRailBtnClick(Sender: TObject);
begin
  if Sender is TLcaPaintNavRailButton then
    FState.SetNavigation(TNavigationItem(TLcaPaintNavRailButton(Sender).Tag));
end;

procedure TLazyCodingAgentForm.UpdateNavRailSelection;
var
  Nav: TNavigationItem;
  Btn: TLcaPaintNavRailButton;
begin
  for Nav := Low(TNavigationItem) to High(TNavigationItem) do begin
    Btn := FNavRailBtns[Nav];
    if not Assigned(Btn) then Continue;
    Btn.Active := Nav = FState.Navigation;
  end;
end;

procedure TLazyCodingAgentForm.PanelHideClickAction(AId: TPanelId);
begin
  if Assigned(FPanelDetach) and FState.IsPanelFloating(AId) then
    FPanelDetach.AttachPanel(AId);
  FState.SetPanelVisible(AId, False);
  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.PanelHideClick(Sender: TObject);
begin
  if Sender is TControl then
    PanelHideClickAction(TPanelId(TControl(Sender).Tag));
end;

procedure TLazyCodingAgentForm.PanelDetachFloatChanged(Sender: TObject; AId: TPanelId;
  AFloating: Boolean);
begin
  if (AId <> piChat) or not Assigned(lcaCenterTabBar) then Exit;
  if AFloating then
    lcaCenterTabBar.PageControl := nil
  else
    lcaCenterTabBar.PageControl := pgcCenter;
end;

procedure TLazyCodingAgentForm.PanelDetachClick(Sender: TObject);
var
  Id: TPanelId;
  WasFloating: Boolean;
begin
  if not Assigned(FPanelDetach) then Exit;
  if not (Sender is TControl) then Exit;
  Id := TPanelId(TControl(Sender).Tag);
  WasFloating := FState.IsPanelFloating(Id);
  FUpdatingState := True;
  try
    FPanelDetach.ToggleDetach(Id);
    ApplyDockPanelsLayout;
  finally
    FUpdatingState := False;
  end;
  if (Id = piTerminal) and not WasFloating and FState.IsPanelFloating(piTerminal) and
     Assigned(lcaTerminalPanel) then
    lcaTerminalPanel.FocusTerminal;
end;





procedure TLazyCodingAgentForm.ShowChatCenterTab;
begin
  if Assigned(pgcCenter) then
    pgcCenter.ActivePage := tsChat;
end;

procedure TLazyCodingAgentForm.WireThemedTabBars;
begin
  if Assigned(lcaCenterTabBar) then
    lcaCenterTabBar.OnTabClose := @TabBarCenterTabClose;
  if Assigned(lcaChatSessionTabBar) then begin
    lcaChatSessionTabBar.ShowAddTab := True;
    lcaChatSessionTabBar.OnAddTab := @TabBarCenterAddTab;
    lcaChatSessionTabBar.OnManualTabSelect := @TabBarChatSessionSelect;
    lcaChatSessionTabBar.OnManualTabClose := @TabBarChatSessionClose;
  end;
  if Assigned(lcaPlanDocTabBar) then begin
    lcaPlanDocTabBar.ShowAddTab := False;
    lcaPlanDocTabBar.OnManualTabSelect := @TabBarPlanDocSelect;
    lcaPlanDocTabBar.OnManualTabClose := @TabBarPlanDocClose;
  end;
end;

procedure TLazyCodingAgentForm.InitCenterTabStrip;
begin
  TLcaThemedPageTabBar.SetTabAllowsClose(tsEditor, True);
  TLcaThemedPageTabBar.SetTabAllowsClose(tsMarkdown, True);
  TLcaThemedPageTabBar.SetTabHidden(tsEditor, True);
  TLcaThemedPageTabBar.SetTabHidden(tsMarkdown, True);
  if Assigned(lcaCenterTabBar) then
    lcaCenterTabBar.RefreshFromPageControl;
end;

procedure TLazyCodingAgentForm.SyncCenterAddTabNav;
begin
  if Assigned(FNavContent) then
    FNavContent.SetCenterAddTabAvailable(FState.IsPanelVisible(piChat));
end;

procedure TLazyCodingAgentForm.TabBarCenterAddTab(Sender: TObject);
begin
  CreateAndSelectNewSession;
end;

procedure TLazyCodingAgentForm.TabBarChatSessionSelect(Sender: TObject; ATabIndex: Integer);
begin
  if (ATabIndex < 0) or (ATabIndex >= FChatSessionTabIds.Count) then Exit;
  SelectSession(FChatSessionTabIds[ATabIndex]);
  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.TabBarChatSessionClose(Sender: TObject; ATabIndex: Integer;
  var AllowClose: Boolean);
begin
  AllowClose := False;
  if (ATabIndex < 0) or (ATabIndex >= FChatSessionTabIds.Count) then Exit;
  AllowClose := True;
  DoArchiveSession(FChatSessionTabIds[ATabIndex]);
end;

procedure TLazyCodingAgentForm.TabBarCenterTabClose(Sender: TObject; TabSheet: TTabSheet;
  var AllowClose: Boolean);
begin
  AllowClose := False;
  if TabSheet = tsEditor then begin
    if not PromptDirtyEditor then Exit;
    if Assigned(FFileEditor) then
      FFileEditor.Clear;
    TLcaThemedPageTabBar.SetTabHidden(tsEditor, True);
    AllowClose := True;
    ShowChatCenterTab;
  end else if TabSheet = tsMarkdown then begin
    FMarkdownPath := '';
    if Assigned(FMarkdownPreview) then
      FMarkdownPreview.SetMarkdown('');
    TLcaThemedPageTabBar.SetTabHidden(tsMarkdown, True);
    AllowClose := True;
    ShowChatCenterTab;
  end;
  if Assigned(lcaCenterTabBar) then
    lcaCenterTabBar.RefreshFromPageControl;
end;

procedure TLazyCodingAgentForm.InitWorkspaceSubControls;
begin
  lblNavTitle.Caption := PanelCaption(piNavigation);
  lblReservedTitle.Caption := PanelCaption(piReserved);
  lblTerminalTitle.Caption := PanelCaption(piTerminal);
  InitCenterTabStrip;

  if memReserved.Lines.Count = 0 then begin
    memReserved.Lines.Add('=== Workspace Context & Guidelines ===');
    memReserved.Lines.Add('');
    memReserved.Lines.Add('• Follow single responsibility principles.');
    memReserved.Lines.Add('• Visual Form Designer first with modern styling.');
    memReserved.Lines.Add('• Dark-first modern design across all platforms.');
    memReserved.Lines.Add('• Cross-platform Free Pascal / LCL target.');
    memReserved.Lines.Add('• Autonomous tool execution with live logging.');
  end;

  InitNavRailButtons;

  FNavContent := TNavContentControl.Create(Self);
  FNavContent.Bind(lblNavViewTitle, lblNavViewSub, lblNavComingSoon, lstNavFile, tvNavProjects,
    lstNavLog, lstNavErrors, btnNavPrimary, btnNavSecondary);
  FNavContent.OnWorkspaceSelect := @NavWorkspaceSelect;
  FNavContent.OnWorkspaceNew := @NavWorkspaceNew;
  FNavContent.OnWorkspaceDelete := @NavWorkspaceDelete;
  FNavContent.OnSessionSelect := @NavSessionSelect;
  FNavContent.OnSessionNew := @NavSessionNew;
  FNavContent.OnSessionArchive := @NavSessionArchive;
  FNavContent.OnSessionRestore := @NavSessionRestore;
  FNavContent.OnSessionDelete := @NavSessionDelete;
  FNavContent.OnFileOpen := @NavFileOpen;
  FNavContent.OnLogEntrySelected := @NavLogEntrySelected;
  FNavContent.OnClearExecutionLog := @NavClearExecutionLog;
  FNavContent.OnToolErrorEntrySelected := @NavToolErrorEntrySelected;
  FNavContent.OnClearToolErrorLog := @NavClearToolErrorLog;
  FNavContent.OnTasksRefresh := @NavTasksRefresh;
  FNavContent.BindProjectsTreeContextMenu(popNavProjects, mnuTreeOpenInApp,
    mnuTreeOpenInFileManager, mnuTreeOpenDefault);
  FNavContent.BindSessionsListContextMenu(popNavSessions, mnuSessionArchive, mnuSessionRestore,
    mnuSessionDeletePermanent);

  if not Assigned(lcaChatHistory) then begin
    lcaChatHistory := TLcaMarkdownView.Create(Self);
    lcaChatHistory.Name := 'lcaChatHistory';
    lcaChatHistory.Parent := pnlChatHistoryHost;
    lcaChatHistory.Align := alClient;
  end else if lcaChatHistory.Parent <> pnlChatHistoryHost then begin
    lcaChatHistory.Parent := pnlChatHistoryHost;
    lcaChatHistory.Align := alClient;
  end;
  lcaChatHistory.ApplyTheme(FState.Theme);

  FChatPanel := TChatPanel.Create(Self);
  FChatPanel.Bind(lblChatHeading, lblChatSub, lblChatSession, pnlChatHistoryHost, memChatPrompt,
    lblChatWorkspaceTag, cboChatMode, cboChatModel, btnChatSend, btnChatStop,
    btnChatAttachImage, pnlChatAttachmentStrip, chkChatAllowModifyOutside, lblChatAllowModifyOutside);
  FChatPanel.OnPrompt := @ChatPrompt;
  FChatPanel.OnModeChange := @ChatModeChange;
  FChatPanel.OnModelChange := @ChatModelChange;
  FChatPanel.OnCancel := @ChatCancel;

  FFileEditor := TMainFileEditor.Create(synEditor, Self);
  FPlanView := TPlanView.Create(Self);
  FPlanView.Bind(lblPlanPath, cboPlanModel, btnPlanBuild, lcaPlanBody);
  FPlanView.OnBuild := @PlanBuildRequested;

  if not Assigned(lcaTerminalPanel) then begin
    lcaTerminalPanel := TLcaTerminalPanel.Create(Self);
    lcaTerminalPanel.Parent := pnlTerminalContent;
    lcaTerminalPanel.Align := alClient;
    lcaTerminalPanel.StatusLabel := lblTerminalStatus;
  end;
  lcaTerminalPanel.OnTerminalStatus := @TerminalStatus;
  lcaTerminalPanel.ApplyTheme(FState.Theme);

  if not Assigned(FExecDetailView) then begin
    FExecDetailView := TLcaMarkdownView.Create(Self);
    FExecDetailView.Parent := pnlUtilityExecDetailHost;
    FExecDetailView.Align := alClient;
  end;
  FExecDetailView.ApplyTheme(FState.Theme);
  if not Assigned(FMarkdownPreview) then begin
    FMarkdownPreview := TLcaMarkdownView.Create(Self);
    FMarkdownPreview.Parent := pnlMarkdownPreviewHost;
    FMarkdownPreview.Align := alClient;
  end;
  FMarkdownPreview.ApplyTheme(FState.Theme);

  FTerminalRetryTimer := TTimer.Create(Self);
  FTerminalRetryTimer.Enabled := False;
  FTerminalRetryTimer.Interval := 150;
  FTerminalRetryTimer.OnTimer := @TerminalRetryTimer;

  FCurrentRunMode := wmAgent;
  FPlanSavedThisRun := False;
  FMarkdownPath := '';
end;

procedure TLazyCodingAgentForm.PopulateMenusAndCombos;
var
  Nav: TNavigationItem;
  SubItem: TMenuItem;
  I: Integer;
begin
  // Remove dynamic navigation entries; keep designer-defined items (separator, rules).
  I := 0;
  while I < mnuWorkspace.Count do begin
    if ((mnuWorkspace.Items[I].Tag >= Ord(Low(TNavigationItem))) and
        (mnuWorkspace.Items[I].Tag <= Ord(High(TNavigationItem)))) or
       (mnuWorkspace.Items[I].Tag = -2) or (mnuWorkspace.Items[I].Tag = -3) then
      mnuWorkspace.Delete(I)
    else
      Inc(I);
  end;

  for Nav := High(TNavigationItem) downto Low(TNavigationItem) do begin
    if NavigationIsFutureFeature(Nav) then
      Continue;
    SubItem := TMenuItem.Create(mnuWorkspace);
    SubItem.Caption := NavigationCaption(Nav);
    SubItem.Hint := NavigationHint(Nav);
    SubItem.Tag := Ord(Nav);
    SubItem.OnClick := @MenuSelectNav;
    mnuWorkspace.Insert(0, SubItem);
  end;

  RebuildWindowMenu;
  RebuildActiveSchemeMenu;
  if Assigned(lcaTitleBar) then
    lcaTitleBar.RefreshFromMainMenu;
end;


procedure TLazyCodingAgentForm.ApplyDockPanelsLayout;
begin
  pnlNavHost.Visible := FState.IsPanelVisible(piNavigation) and
    not FState.IsPanelFloating(piNavigation);
  splNav.Visible := pnlNavHost.Visible;
  pnlChatHost.Visible := FState.IsPanelVisible(piChat) and
    not FState.IsPanelFloating(piChat);
  pnlReservedHost.Visible := FState.IsPanelVisible(piReserved) and
    not FState.IsPanelFloating(piReserved);
  splReserved.Visible := pnlReservedHost.Visible;
  pnlUtilityHost.Visible := FState.IsPanelVisible(piUtility) and
    not FState.IsPanelFloating(piUtility);
  splUtility.Visible := pnlUtilityHost.Visible;

  pnlTerminalHost.Visible := FState.IsPanelVisible(piTerminal) and
    not FState.IsPanelFloating(piTerminal);
  splTerminal.Visible := pnlTerminalHost.Visible;
  if Assigned(FPanelDetach) then
    FPanelDetach.ApplyLayout;
  if pnlTerminalHost.Visible then
    pnlTerminalHost.Height := EffectiveTerminalDockHeight;

  if FState.IsPanelVisible(piTerminal) and not FDeferThemesUntilShown
     and not FPendingInitialWorkspaceUI then
    ScheduleDeferredTerminalStart;
  SyncCenterAddTabNav;
end;

function TLazyCodingAgentForm.EffectiveTerminalDockHeight: Integer;
var
  Available, DefaultH, MaxDock, Saved: Integer;
begin
  Available := ClientHeight - StatusBar1.Height;
  if Available < splTerminal.MinSize + 80 then
    Available := splTerminal.MinSize + 80;
  DefaultH := Available div 4;
  if DefaultH < splTerminal.MinSize then
    DefaultH := splTerminal.MinSize;
  MaxDock := Available div 2;
  if MaxDock < DefaultH then
    MaxDock := DefaultH;
  Saved := FState.GetPanelDockedHeight(piTerminal);
  if (Saved >= splTerminal.MinSize) and (Saved <= MaxDock) then
    Result := Saved
  else
    Result := DefaultH;
end;

procedure TLazyCodingAgentForm.ScheduleDeferredTerminalStart;
begin
  if csDesigning in ComponentState then Exit;
  if FTerminalStartQueued then Exit;
  if not FState.IsPanelVisible(piTerminal) then Exit;
  FTerminalStartQueued := True;
  Application.QueueAsyncCall(@DeferredEnsureTerminal, 0);
end;

procedure TLazyCodingAgentForm.DeferredEnforceHiddenPageTabs({%H-}Data: PtrInt);
begin
  EnforcePageControlHiddenTabs(pgcCenter);
  EnforcePageControlHiddenTabs(pgcUtility);
  if Assigned(lcaCenterTabBar) then
    lcaCenterTabBar.RefreshFromPageControl;
  if Assigned(lcaUtilityTabBar) then
    lcaUtilityTabBar.RefreshFromPageControl;
end;

procedure TLazyCodingAgentForm.RefreshThemedButtonsRecursive(ARoot: TWinControl);
var
  I: Integer;
  C: TControl;
begin
  if not Assigned(ARoot) then Exit;
  for I := 0 to ARoot.ControlCount - 1 do begin
    C := ARoot.Controls[I];
    if C is TLcaPaintButton then
      TLcaPaintButton(C).ApplyTheme(FState.Theme);
    if C is TWinControl then
      RefreshThemedButtonsRecursive(TWinControl(C));
  end;
end;

procedure TLazyCodingAgentForm.DeferredRefreshThemedChromeButtons({%H-}Data: PtrInt);
begin
  if csDesigning in ComponentState then Exit;
  if csDestroying in ComponentState then Exit;
  if not HandleAllocated then Exit;
  if not Assigned(pnlMainContainer) then Exit;
  RefreshThemedButtonsRecursive(pnlMainContainer);
end;

procedure TLazyCodingAgentForm.DeferredEnsureTerminal({%H-}Data: PtrInt);
begin
  FTerminalStartQueued := False;
  if csDesigning in ComponentState then Exit;
  if not Assigned(lcaTerminalPanel) then Exit;
  if not IsTerminalSurfaceVisible then Exit;
  SyncTerminalWorkingDirectory;
  if not lcaTerminalPanel.EnsureRunning then
    ScheduleTerminalStartRetry
  else
    FTerminalRetryTimer.Enabled := False;
end;

function TLazyCodingAgentForm.IsTerminalSurfaceVisible: Boolean;
begin
  if not FState.IsPanelVisible(piTerminal) then
    Exit(False);
  if not Assigned(lcaTerminalPanel) then
    Exit(False);
  if FState.IsPanelFloating(piTerminal) then
    Result := lcaTerminalPanel.Visible
  else
    Result := pnlTerminalHost.Visible;
end;

procedure TLazyCodingAgentForm.ScheduleTerminalStartRetry;
begin
  if not Assigned(FTerminalRetryTimer) then Exit;
  FTerminalRetryCount := 0;
  FTerminalRetryTimer.Enabled := True;
end;

procedure TLazyCodingAgentForm.TerminalRetryTimer(Sender: TObject);
begin
  if not Assigned(lcaTerminalPanel) then begin
    FTerminalRetryTimer.Enabled := False;
    Exit;
  end;
  Inc(FTerminalRetryCount);
  if FTerminalRetryCount > 3 then begin
    FTerminalRetryTimer.Enabled := False;
    Exit;
  end;
  if not IsTerminalSurfaceVisible then
    Exit;
  SyncTerminalWorkingDirectory;
  if lcaTerminalPanel.EnsureRunning then
    FTerminalRetryTimer.Enabled := False;
end;

procedure TLazyCodingAgentForm.TerminalStatus(Sender: TObject; const AMessage: string);
begin
  if Trim(AMessage) <> '' then
    StatusBar1.SimpleText := AMessage;
end;

procedure TLazyCodingAgentForm.SyncTerminalWorkingDirectory;
begin
  if not Assigned(lcaTerminalPanel) then Exit;
  if FState.HasActiveWorkspace then
    lcaTerminalPanel.SetWorkingDirectory(FState.WorkspaceRoot)
  else
    lcaTerminalPanel.SetWorkingDirectory('');
end;


procedure TLazyCodingAgentForm.StateChanged(Sender: TObject);
var
  I, N: Integer;
  Models: array of TSavedModel;
  WsLabel: string;
begin
  if FUpdatingState then Exit;
  if FPendingInitialWorkspaceUI then Exit;
  FUpdatingState := True;
  try
    if FState.HasActiveWorkspace then
      EnsureActiveHub;
    if Assigned(FActiveHub) then
      SyncHubClientSettings(FActiveHub);
    for I := 0 to FSessionHubs.Count - 1 do begin
      if Assigned(FSessionHubs.HubAt(I)) then
        SyncHubClientSettings(FSessionHubs.HubAt(I));
    end;

    UpdateNavRailSelection;
    if Assigned(FNavContent) then begin
      RefreshWorkspaceNav;
      RefreshSessionNav;
      FNavContent.SetSelected(FState.Navigation, FState.WorkspaceName, FState.WorkspaceRoot);
      FNavContent.SetWorkspaceList(FNavWorkCaptions, FNavWorkIds, FState.ActiveWorkspaceId);
      FNavContent.SetSessionList(FNavSessionCaptions, FNavSessionIds, FNavSessionArchived,
        FCurrentSessionId);
    end;

    UpdateSessionCaption;
    RefreshChatSessionTabs;
    ApplyWorkspaceChatVisibility;

    if Assigned(FChatPanel) then begin
      N := FState.SavedModelCount(FState.Provider);
      Models := nil;
      SetLength(Models, N);
      for I := 0 to N - 1 do
        Models[I] := FState.GetSavedModel(FState.Provider, I);
      FChatPanel.SetAvailableModels(Models);
      FChatPanel.SetWorkspace(FState.WorkspaceName);
      FChatPanel.SetMode(FState.Mode);
      FChatPanel.SetModel(FState.Model);
      ApplySessionComposerState;
      RefreshPlanViewModels(Models);
    end;

    if not FPendingInitialDockLayout then
      ApplyDockPanelsLayout;

    RebuildWindowMenu;
    if Assigned(mnuViewTerminal) then
      mnuViewTerminal.Checked := FState.IsPanelVisible(piTerminal);
    if Assigned(mnuFileRemoveWorkspace) then
      mnuFileRemoveWorkspace.Enabled := FRegistry.Count > 0;

    if FState.HasActiveWorkspace then
      WsLabel := FState.WorkspaceName
    else
      WsLabel := '(none)';
    if Assigned(ActiveAgent) then
      StatusBar1.SimpleText := Format('⚡ Workspace: %s  |  🎯 Mode: %s  |  🤖 Model: %s  |  Status: %s',
        [WsLabel, WorkspaceModeCaption(FState.Mode), FState.Model,
          FormatSessionStatusLabel(ActiveAgent.State)])
    else
      StatusBar1.SimpleText := Format('⚡ Workspace: %s  |  🎯 Mode: %s  |  🤖 Model: %s',
        [WsLabel, WorkspaceModeCaption(FState.Mode), FState.Model]);
  finally
    FUpdatingState := False;
  end;
end;

procedure TLazyCodingAgentForm.ApplyAllThemes;
var
  P: TThemePalette;
  Theme: TThemeKind;
begin
  if not HandleAllocated then Exit;
  Theme := FState.Theme;
  P := ThemePalette(Theme);

  Color := P.Background;
  Font.Color := P.Text;

  ApplyThemedControlTree(pnlMainContainer, FState.Theme);

  ApplyThemedPanelColors(pnlMainContainer, P.Background, Theme);
  ApplyThemedPanelColors(pnlNavRailHost, P.RailBg, Theme);
  ApplyThemedPanelColors(pnlNavHost, P.Surface, Theme);
  ApplyThemedPanelColors(pnlNavChrome, P.HeaderBg, Theme);
  if Assigned(pnlNavContent) then
    ApplyThemedPanelColors(pnlNavContent, P.Surface, Theme);
  ApplyThemedPanelColors(pnlChatHost, P.Background, Theme);
  ApplyThemedPanelColors(pnlChatChrome, P.HeaderBg, Theme);
  if Assigned(pnlCenterContent) then
    ApplyThemedPanelColors(pnlCenterContent, P.Surface, Theme);
  ApplyThemedPanelColors(pnlReservedHost, P.Surface, Theme);
  ApplyThemedPanelColors(pnlReservedChrome, P.HeaderBg, Theme);
  if Assigned(pnlReservedContent) then
    ApplyThemedPanelColors(pnlReservedContent, P.Surface, Theme);
  ApplyThemedPanelColors(pnlUtilityHost, P.Surface, Theme);
  ApplyThemedPanelColors(pnlUtilityChrome, P.HeaderBg, Theme);
  if Assigned(pnlUtilityContent) then
    ApplyThemedPanelColors(pnlUtilityContent, P.Surface, Theme);
  ApplyThemedPanelColors(pnlTerminalHost, P.Surface, Theme);
  ApplyThemedPanelColors(pnlTerminalChrome, P.HeaderBg, Theme);
  if Assigned(pnlTerminalContent) then
    ApplyThemedPanelColors(pnlTerminalContent, P.Surface, Theme);
  ApplyThemedControlTree(pnlTerminalHost, FState.Theme);

  splNav.Color := P.Border;
  splReserved.Color := P.Border;
  splUtility.Color := P.Border;
  splTerminal.Color := P.Border;

  StatusBar1.Color := P.Surface;
  StatusBar1.Font.Color := P.TextMuted;
  if Assigned(FPanelDetach) then
    FPanelDetach.ApplyThemes(FState.Theme);

  if Assigned(FNavContent) then FNavContent.ApplyTheme(FState.Theme);
  if Assigned(FChatPanel) then FChatPanel.ApplyTheme(FState.Theme);
  if Assigned(lcaTerminalPanel) then lcaTerminalPanel.ApplyTheme(FState.Theme);
  if Assigned(FPlanView) then FPlanView.ApplyTheme(FState.Theme);
  if Assigned(lcaCenterTabBar) then lcaCenterTabBar.ApplyTheme(FState.Theme);
  if Assigned(lcaChatSessionTabBar) then lcaChatSessionTabBar.ApplyTheme(FState.Theme);
  if Assigned(lcaPlanDocTabBar) then lcaPlanDocTabBar.ApplyTheme(FState.Theme);
  if Assigned(lcaUtilityTabBar) then lcaUtilityTabBar.ApplyTheme(FState.Theme);
  if Assigned(lcaTitleBar) then lcaTitleBar.ApplyTheme(FState.Theme);
  if not Assigned(FMarkdownPreview) then begin
    FMarkdownPreview := TLcaMarkdownView.Create(Self);
    FMarkdownPreview.Parent := pnlMarkdownPreviewHost;
    FMarkdownPreview.Align := alClient;
  end;
  FMarkdownPreview.ApplyTheme(FState.Theme);
  ApplyEditorTheme;

  if Assigned(FExecDetailView) then begin
    RefreshExecDetailView;
    FExecDetailView.ApplyTheme(FState.Theme);
  end;

  UpdateNavRailSelection;
  ApplyPlatformChromeThemes;
  Invalidate;
end;

procedure TLazyCodingAgentForm.ApplyPlatformChromeThemes;
begin
  if not HandleAllocated then Exit;
  ApplyPlatformChrome(Self, FState.Theme);
  ApplyPlatformScrollableThemeRecursive(Self, FState.Theme);
  if Assigned(FNavContent) then
    FNavContent.ApplyPlatformChrome(FState.Theme);
  if Assigned(FChatPanel) then
    FChatPanel.ApplyPlatformChrome(FState.Theme);
end;

procedure TLazyCodingAgentForm.RebuildWindowMenu;
var
  P: TPanelId;
  Item: TMenuItem;
begin
  mnuPanelsVisibility.Clear;
  for P := Low(TPanelId) to High(TPanelId) do begin
    Item := TMenuItem.Create(mnuPanelsVisibility);
    Item.Caption := PanelCaption(P);
    Item.Checked := FState.IsPanelVisible(P);
    Item.Tag := Ord(P);
    Item.OnClick := @MenuTogglePanel;
    mnuPanelsVisibility.Add(Item);
  end;

  ApplyPlatformChrome(Self, FState.Theme);
  if Assigned(lcaTitleBar) then
    lcaTitleBar.RefreshFromMainMenu;
end;


procedure TLazyCodingAgentForm.ChatPrompt(Sender: TObject; const APrompt: string;
  const AAttachments: array of TChatAttachment; AMode: TWorkspaceMode;
  const AModel: string);
var
  Info: TChatSessionInfo;
  Eng: TAgentEngine;
begin
  if not FState.HasActiveWorkspace then Exit;
  if Assigned(ActiveStore) and ActiveStore.FindSessionInfo(FCurrentSessionId, Info) and Info.Archived then
    Exit;
  FCurrentRunMode := AMode;
  FPlanSavedThisRun := False;
  Eng := ActiveAgent;
  if not Assigned(Eng) then Exit;
  if FState.LearnMode then begin
    FState.SetNavigation(niTools);
    FExecutionLogFollowLive := True;
    OpenUtilityExecutionDetailTab;
  end else
    FExecutionLogFollowLive := False;
  Eng.Context.AllowModifyOutsideWorkspace := FChatPanel.GetAllowModifyOutsideChecked;
  FChatPanel.SetRunning(True);
  if not Eng.StartRunAsync(APrompt, AAttachments, AMode, AModel) then
    FChatPanel.SetRunning(False);
end;

procedure TLazyCodingAgentForm.ChatModeChange(Sender: TObject; AMode: TWorkspaceMode);
begin
  FState.SetMode(AMode);
end;

procedure TLazyCodingAgentForm.ChatModelChange(Sender: TObject; const AModel: string);
begin
  FState.SetModel(AModel);
end;

procedure TLazyCodingAgentForm.ChatCancel(Sender: TObject);
var
  Eng: TAgentEngine;
begin
  Eng := ActiveAgent;
  if Assigned(Eng) then begin
    Eng.RequestCancel;
    StatusBar1.SimpleText := StatusBar1.SimpleText + '  |  Stopping after current step…';
  end;
end;

procedure TLazyCodingAgentForm.HubStateChange(Sender: TObject; const ASessionId: string;
  AOldState, ANewState: TAgentState; AStep, AMaxSteps: Integer);
begin
  if SameText(ASessionId, FCurrentSessionId) then begin
    FStatusRunStep := AStep;
    FStatusRunMaxSteps := AMaxSteps;
    StatusBar1.SimpleText := Format('⚡ Workspace: %s  |  🎯 Mode: %s  |  🤖 Model: %s  |  Status: %s',
      [FState.WorkspaceName, WorkspaceModeCaption(FState.Mode), FState.Model,
        FormatAgentStateLabel(ANewState, AStep, AMaxSteps)]);
    if (ANewState = asFinished) and (FCurrentRunMode = wmPlan) and not FPlanSavedThisRun then
      TrySaveProposedPlanFromChat;
    if Assigned(FChatPanel) then begin
      if ANewState = asThinking then
        FChatPanel.SetAgentThinkingInChat(True)
      else if AOldState = asThinking then
        FChatPanel.SetAgentThinkingInChat(False);
    end;
    if (ANewState in [asIdle, asFinished, asError]) and Assigned(FChatPanel) then
      FChatPanel.SetRunning(False);
  end;
  if AgentStateIsRunning(AOldState) <> AgentStateIsRunning(ANewState) then
    UpdateSessionCaption;
end;

procedure TLazyCodingAgentForm.HubMessageAdded(Sender: TObject; const ASessionId: string;
  const AMsg: TChatMessage);
begin
  if SameText(ASessionId, FCurrentSessionId) and Assigned(FChatPanel) then begin
    if AMsg.Role = crTool then
      FChatPanel.AppendToolMessage(AMsg, FState.DebuggingMode)
    else
      FChatPanel.AppendMessage(AMsg);
  end;
end;

procedure TLazyCodingAgentForm.HubToolCall(Sender: TObject; const ASessionId: string;
  const AToolName, AArgs: string);
begin
  if not SameText(ASessionId, FCurrentSessionId) then Exit;
  if Assigned(FChatPanel) and (Trim(AToolName) <> '') then
    FChatPanel.AppendToolActivityLine(AToolName, AArgs);
end;

procedure TLazyCodingAgentForm.HubToolResult(Sender: TObject; const ASessionId: string;
  const AToolName, {%H-}AArgsJson: string; const AResult: TToolExecutionResult);
var
  PlanPath, PlanContent: string;
begin
  if not SameText(ASessionId, FCurrentSessionId) then Exit;
  if SameText(AToolName, 'create_plan_file') then begin
    if ParsePlanToolSuccess(AResult, PlanPath, PlanContent) and (FCurrentRunMode = wmPlan) then begin
      FPlanSavedThisRun := True;
      OpenPlanInUtilityTab(PlanPath, PlanContent);
    end;
  end;
  if SameText(AToolName, 'todo') or SameText(AToolName, 'plan') then
    RefreshNavTaskList;
end;

procedure TLazyCodingAgentForm.NavTasksRefresh(Sender: TObject);
begin
  RefreshNavTaskList;
end;

procedure TLazyCodingAgentForm.RefreshNavTaskList;
var
  Caps: TStringList;
  Tasks: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  ID, TaskText, Status, Line: string;
  Eng: TAgentEngine;
begin
  if not Assigned(FNavContent) then Exit;
  Caps := TStringList.Create;
  try
    Eng := ActiveAgent;
    if Assigned(Eng) then begin
      Tasks := Eng.Context.Session.Tasks;
      for I := 0 to Tasks.Count - 1 do begin
        if not (Tasks[I] is TJSONObject) then Continue;
        Item := TJSONObject(Tasks[I]);
        ID := Item.Get('id', '');
        TaskText := Item.Get('text', '');
        Status := Item.Get('status', '');
        if Status = 'completed' then
          Line := '✔ '
        else if Status = 'in_progress' then
          Line := '⏳ '
        else
          Line := '○ ';
        Line := Line + ID + '. ' + TaskText;
        if Status <> '' then
          Line := Line + ' [' + Status + ']';
        Caps.Add(Line);
      end;
    end;
    FNavContent.UpdateSessionTasks(Caps);
  finally
    Caps.Free;
  end;
end;

procedure TLazyCodingAgentForm.DetachNavSessionLogs;
begin
  if Assigned(FNavContent) then begin
    FNavContent.BindExecutionLog(nil);
    FNavContent.BindToolErrorLog(nil);
  end;
end;

procedure TLazyCodingAgentForm.HubExecutionLogAdded(Sender: TObject; const ASessionId: string;
  AEntryIndex: Integer);
begin
  if csDestroying in ComponentState then Exit;
  if not SameText(ASessionId, FCurrentSessionId) then Exit;
  if Assigned(FNavContent) then
    FNavContent.AppendExecutionLogEntry(AEntryIndex, FExecutionLogFollowLive);
  if FExecutionLogFollowLive then
    ScheduleExecDetailLiveRefresh(AEntryIndex, edsExecLog);
end;

procedure TLazyCodingAgentForm.ScheduleExecDetailLiveRefresh(AIndex: Integer;
  ASource: TExecDetailSource);
begin
  if csDestroying in ComponentState then Exit;
  FExecDetailPendingIndex := AIndex;
  FExecDetailPendingSource := ASource;
  if FExecDetailRefreshQueued then Exit;
  FExecDetailRefreshQueued := True;
  Application.QueueAsyncCall(@DeferredExecDetailRefresh, PtrInt(Self));
end;

procedure TLazyCodingAgentForm.DeferredExecDetailRefresh(Data: PtrInt);
begin
  FExecDetailRefreshQueued := False;
  if PtrInt(Self) <> Data then Exit;
  if csDestroying in ComponentState then Exit;
  if FExecDetailPendingIndex < 0 then Exit;
  ApplyExecDetailAtIndex(FExecDetailPendingIndex, FExecDetailPendingSource, True);
end;

procedure TLazyCodingAgentForm.ApplyExecDetailAtIndex(AIndex: Integer; ASource: TExecDetailSource;
  AOpenTabIfNeeded: Boolean);
var
  Log: TAgentExecutionLog;
  ErrLog: TAgentToolErrorLog;
  Entry: TExecutionLogEntry;
  ErrEntry: TToolErrorLogEntry;
begin
  if ASource = edsExecLog then begin
    Log := nil;
    if Assigned(FActiveHub) and (FCurrentSessionId <> '') then
      Log := FActiveHub.ExecutionLogFor(FCurrentSessionId);
    if (Log = nil) or (AIndex < 0) or (AIndex >= Log.Count) then Exit;
    Entry := Log.Entry(AIndex);
    FExecDetailSource := edsExecLog;
    FExecDetailIndex := AIndex;
    if Assigned(FExecDetailView) then
      FExecDetailView.SetMarkdown(Entry.BuildInspectorMarkdown);
  end else if ASource = edsToolError then begin
    ErrLog := nil;
    if Assigned(FActiveHub) and (FCurrentSessionId <> '') then
      ErrLog := FActiveHub.ToolErrorLogFor(FCurrentSessionId);
    if (ErrLog = nil) or (AIndex < 0) or (AIndex >= ErrLog.Count) then Exit;
    ErrEntry := ErrLog.Entry(AIndex);
    FExecDetailSource := edsToolError;
    FExecDetailIndex := AIndex;
    if Assigned(FExecDetailView) then
      FExecDetailView.SetMarkdown(ErrEntry.BuildInspectorMarkdown);
  end else
    Exit;
  if AOpenTabIfNeeded then
    OpenUtilityExecutionDetailTab;
end;

procedure TLazyCodingAgentForm.OpenUtilityExecutionDetailTab;
var
  NeedDockLayout: Boolean;
begin
  NeedDockLayout := not FState.IsPanelVisible(piUtility);
  FState.SetPanelVisible(piUtility, True);
  if Assigned(pgcUtility) and (pgcUtility.ActivePage <> tsUtilityExecDetail) then begin
    pgcUtility.ActivePage := tsUtilityExecDetail;
    NeedDockLayout := True;
  end;
  if NeedDockLayout then
    ApplyDockPanelsLayout;
end;

function TLazyCodingAgentForm.FormatSessionStatusLabel(AState: TAgentState): string;
begin
  Result := FormatAgentStateLabel(AState, FStatusRunStep, FStatusRunMaxSteps);
end;

procedure TLazyCodingAgentForm.ClearExecDetailView;
begin
  FExecDetailSource := edsNone;
  FExecDetailIndex := -1;
  if Assigned(FExecDetailView) then
    FExecDetailView.Clear;
end;

procedure TLazyCodingAgentForm.RefreshExecDetailView;
begin
  if not Assigned(FExecDetailView) then Exit;
  case FExecDetailSource of
    edsExecLog:
      if FExecDetailIndex >= 0 then
        ShowExecutionLogDetail(FExecDetailIndex)
      else
        ClearExecDetailView;
    edsToolError:
      if FExecDetailIndex >= 0 then
        ShowToolErrorDetail(FExecDetailIndex)
      else
        ClearExecDetailView;
  else
    ClearExecDetailView;
  end;
end;

procedure TLazyCodingAgentForm.ShowExecutionLogDetail(AIndex: Integer);
begin
  ApplyExecDetailAtIndex(AIndex, edsExecLog, True);
end;

procedure TLazyCodingAgentForm.ShowToolErrorDetail(AIndex: Integer);
begin
  ApplyExecDetailAtIndex(AIndex, edsToolError, True);
end;

procedure TLazyCodingAgentForm.NavLogEntrySelected(Sender: TObject; AIndex: Integer);
var
  Log: TAgentExecutionLog;
begin
  Log := nil;
  if Assigned(FActiveHub) and (FCurrentSessionId <> '') then
    Log := FActiveHub.ExecutionLogFor(FCurrentSessionId);
  if Log <> nil then begin
    if AIndex = Log.Count - 1 then
      FExecutionLogFollowLive := True
    else
      FExecutionLogFollowLive := False;
  end;
  ShowExecutionLogDetail(AIndex);
end;

procedure TLazyCodingAgentForm.NavClearExecutionLog(Sender: TObject);
var
  Log: TAgentExecutionLog;
begin
  if not Assigned(FActiveHub) or (FCurrentSessionId = '') then Exit;
  Log := FActiveHub.ExecutionLogFor(FCurrentSessionId);
  if Assigned(Log) then
    Log.Clear;
  if Assigned(FNavContent) then
    FNavContent.RefreshExecutionLogList;
  ClearExecDetailView;
end;

procedure TLazyCodingAgentForm.HubToolErrorAdded(Sender: TObject; const ASessionId: string;
  AEntryIndex: Integer);
begin
  if csDestroying in ComponentState then Exit;
  if not SameText(ASessionId, FCurrentSessionId) then Exit;
  if Assigned(FNavContent) then
    FNavContent.AppendToolErrorLogEntry(AEntryIndex);
end;

procedure TLazyCodingAgentForm.NavToolErrorEntrySelected(Sender: TObject; AIndex: Integer);
begin
  ShowToolErrorDetail(AIndex);
end;

procedure TLazyCodingAgentForm.NavClearToolErrorLog(Sender: TObject);
var
  Log: TAgentToolErrorLog;
begin
  if not Assigned(FActiveHub) or (FCurrentSessionId = '') then Exit;
  Log := FActiveHub.ToolErrorLogFor(FCurrentSessionId);
  if Assigned(Log) then
    Log.Clear;
  if Assigned(FNavContent) then
    FNavContent.RefreshToolErrorLogList;
  if FExecDetailSource = edsToolError then
    ClearExecDetailView;
end;

function TLazyCodingAgentForm.ParsePlanToolSuccess(const AResult: TToolExecutionResult;
  out APath, AContent: string): Boolean;
var
  Data: TJSONData;
  Obj: TJSONObject;
begin
  Result := False;
  APath := '';
  AContent := '';
  if not AResult.Success then Exit;
  try
    Data := GetJSON(AResult.Output);
    try
      if Data is TJSONObject then begin
        Obj := TJSONObject(Data);
        if SameText(Obj.Get('status', ''), 'success') then begin
          APath := Obj.Get('path', '');
          AContent := Obj.Get('content', '');
          Result := (APath <> '') and (AContent <> '');
        end;
      end;
    finally
      Data.Free;
    end;
  except
    Result := False;
  end;
end;

function TLazyCodingAgentForm.PlanDocCaption(const APath: string): string;
begin
  Result := ExtractFileName(APath);
  if Result = '' then
    Result := 'Plan';
end;

function TLazyCodingAgentForm.FindPlanDocIndex(const APath: string): Integer;
var
  I: Integer;
  Norm: string;
begin
  Norm := ExpandFileName(Trim(APath));
  if Norm = '' then Exit(-1);
  for I := 0 to FPlanDocPaths.Count - 1 do
    if SameText(ExpandFileName(FPlanDocPaths[I]), Norm) then
      Exit(I);
  Result := -1;
end;

function TLazyCodingAgentForm.EnsurePlanDocOpen(const APath, AContent: string): Integer;
var
  Path: string;
  Idx: Integer;
begin
  Path := ExpandFileName(Trim(APath));
  if Path = '' then Exit(-1);
  Idx := FindPlanDocIndex(Path);
  if Idx >= 0 then
    FPlanDocContents[Idx] := AContent
  else begin
    FPlanDocPaths.Add(Path);
    FPlanDocContents.Add(AContent);
    Idx := FPlanDocPaths.Count - 1;
  end;
  Result := Idx;
end;

procedure TLazyCodingAgentForm.ApplyPlanViewModelsAndTheme;
var
  I: Integer;
  Models: array of TSavedModel;
begin
  if not Assigned(FPlanView) then Exit;
  SetLength(Models, FState.SavedModelCount(FState.Provider));
  for I := 0 to High(Models) do
    Models[I] := FState.GetSavedModel(FState.Provider, I);
  FPlanView.SetAvailableModels(Models);
  if Assigned(FChatPanel) and (FChatPanel.Model <> '') then
    FPlanView.SetModel(FChatPanel.Model)
  else
    FPlanView.SetModel(FState.Model);
  FPlanView.ApplyTheme(FState.Theme);
end;

procedure TLazyCodingAgentForm.ClearActivePlanDocument;
begin
  FActivePlanDocIndex := -1;
  if Assigned(FPlanView) then
    FPlanView.ClearPlan;
end;

procedure TLazyCodingAgentForm.SelectPlanDocIndex(AIndex: Integer);
begin
  if not Assigned(FPlanView) then Exit;
  if (AIndex < 0) or (AIndex >= FPlanDocPaths.Count) then begin
    ClearActivePlanDocument;
    Exit;
  end;
  FActivePlanDocIndex := AIndex;
  FPlanView.LoadPlan(FPlanDocPaths[AIndex], FPlanDocContents[AIndex]);
  ApplyPlanViewModelsAndTheme;
end;

procedure TLazyCodingAgentForm.RefreshPlanDocTabs;
var
  I, SelIdx: Integer;
  Cap: string;
  Caps: array of string;
  Closable: array of Boolean;
begin
  if not Assigned(lcaPlanDocTabBar) then Exit;
  Caps := nil;
  Closable := nil;
  SetLength(Caps, 0);
  SetLength(Closable, 0);
  SelIdx := -1;
  for I := 0 to FPlanDocPaths.Count - 1 do begin
    Cap := PlanDocCaption(FPlanDocPaths[I]);
    SetLength(Caps, Length(Caps) + 1);
    SetLength(Closable, Length(Closable) + 1);
    Caps[High(Caps)] := Cap;
    Closable[High(Closable)] := True;
    if I = FActivePlanDocIndex then
      SelIdx := I;
  end;
  lcaPlanDocTabBar.SetManualTabs(Caps, Closable, SelIdx);
end;

procedure TLazyCodingAgentForm.TabBarPlanDocSelect(Sender: TObject; ATabIndex: Integer);
begin
  if (ATabIndex < 0) or (ATabIndex >= FPlanDocPaths.Count) then Exit;
  if ATabIndex = FActivePlanDocIndex then Exit;
  SelectPlanDocIndex(ATabIndex);
  RefreshPlanDocTabs;
end;

procedure TLazyCodingAgentForm.TabBarPlanDocClose(Sender: TObject; ATabIndex: Integer;
  var AllowClose: Boolean);
begin
  AllowClose := False;
  if (ATabIndex < 0) or (ATabIndex >= FPlanDocPaths.Count) then Exit;
  AllowClose := True;
  FPlanDocPaths.Delete(ATabIndex);
  FPlanDocContents.Delete(ATabIndex);
  if FPlanDocPaths.Count = 0 then
    ClearActivePlanDocument
  else if ATabIndex = FActivePlanDocIndex then begin
    if FActivePlanDocIndex >= FPlanDocPaths.Count then
      FActivePlanDocIndex := FPlanDocPaths.Count - 1;
    SelectPlanDocIndex(FActivePlanDocIndex);
  end else if ATabIndex < FActivePlanDocIndex then
    Dec(FActivePlanDocIndex);
  RefreshPlanDocTabs;
end;

procedure TLazyCodingAgentForm.OpenPlanInUtilityTab(const APath, AContent: string);
var
  Idx: Integer;
begin
  if not Assigned(FPlanView) then Exit;
  Idx := EnsurePlanDocOpen(APath, AContent);
  if Idx < 0 then Exit;
  FState.SetPanelVisible(piUtility, True);
  ApplyDockPanelsLayout;
  if Assigned(pgcUtility) then
    pgcUtility.ActivePage := tsUtilityPlan;
  SelectPlanDocIndex(Idx);
  RefreshPlanDocTabs;
end;

procedure TLazyCodingAgentForm.TrySaveProposedPlanFromChat;
var
  I, PlanStart, PlanEnd: Integer;
  Msg: TChatMessage;
  PlanContent, PlanPath: string;
  Args: TJSONObject;
  Res: TToolExecutionResult;
begin
  if FPlanSavedThisRun then Exit;
  if not Assigned(ActiveAgent) then Exit;
  for I := ActiveAgent.GetMessageCount - 1 downto 0 do begin
    Msg := ActiveAgent.GetMessage(I);
    if Msg.Role <> crAssistant then Continue;
    PlanStart := Pos('<proposed_plan>', Msg.Content);
    PlanEnd := Pos('</proposed_plan>', Msg.Content);
    if (PlanStart <= 0) or (PlanEnd <= PlanStart) then Exit;
    PlanContent := Trim(Copy(Msg.Content, PlanStart + Length('<proposed_plan>'),
      PlanEnd - PlanStart - Length('<proposed_plan>')));
    if PlanContent = '' then Exit;
    Args := TJSONObject.Create;
    try
      Args.Add('content', PlanContent);
      Res := ActiveAgent.ExecuteToolDirect('create_plan_file', Args.AsJSON, wmPlan);
    finally
      Args.Free;
    end;
    if ParsePlanToolSuccess(Res, PlanPath, PlanContent) then begin
      FPlanSavedThisRun := True;
      OpenPlanInUtilityTab(PlanPath, PlanContent);
    end;
    Exit;
  end;
end;

procedure TLazyCodingAgentForm.PlanBuildRequested(Sender: TObject; const APlanPath,
  APlanContent, AModelId: string);
var
  Prompt, Sid, Title: string;
  AllowOutside: Boolean;
begin
  if not FState.HasActiveWorkspace then Exit;
  if not Assigned(FChatPanel) then Exit;
  if Trim(APlanPath) = '' then Exit;
  if Trim(AModelId) = '' then Exit;
  if not TPlanBuildConfirmForm.Execute(Self, FState.Theme, AllowOutside) then
    Exit;

  FState.SetModel(AModelId);
  FState.SetMode(wmAgent);

  SaveCurrentSession;
  EnsureActiveHub;
  Title := 'Build ' + ExtractFileName(APlanPath);
  if SameText(Trim(Title), 'Build') then
    Title := 'Build plan';
  Sid := ActiveStore.CreateSession(Title);
  FRegistry.SetLastSessionId(FState.ActiveWorkspaceId, Sid);
  FRegistry.Save;
  FCurrentSessionId := Sid;
  ActiveStore.SetLastSessionId(Sid);
  FActiveHub.GetOrCreateEngine(Sid);
  ApplyAllowModifyOutsideToSession(Sid, AllowOutside);
  BindSessionToUI(Sid);
  UpdateSessionCaption;

  ShowChatCenterTab;
  FState.SetPanelVisible(piChat, True);
  ApplyDockPanelsLayout;

  FChatPanel.SetMode(wmAgent);
  FChatPanel.SetModel(AModelId);

  Prompt := 'Implement the plan saved at ' + APlanPath +
    '. First inspect the project files, then carry out the plan completely.' +
    LineEnding + LineEnding + APlanContent;
  FChatPanel.SubmitPrompt(Prompt);
  StateChanged(Self);
end;


procedure TLazyCodingAgentForm.RefreshPlanViewModels(const AModels: array of TSavedModel);
begin
  if Assigned(FPlanView) then
    FPlanView.SetAvailableModels(AModels);
end;

procedure TLazyCodingAgentForm.MenuSelectNav(Sender: TObject);
begin
  if Sender is TMenuItem then
    FState.SetNavigation(TNavigationItem(TMenuItem(Sender).Tag));
end;

procedure TLazyCodingAgentForm.MenuSelectMode(Sender: TObject);
begin
  if Sender is TMenuItem then
    FState.SetMode(TWorkspaceMode(TMenuItem(Sender).Tag));
end;

procedure TLazyCodingAgentForm.MenuTogglePanel(Sender: TObject);
var
  P: TPanelId;
begin
  if Sender is TMenuItem then begin
    P := TPanelId(TMenuItem(Sender).Tag);
    FState.SetPanelVisible(P, not FState.IsPanelVisible(P));
  end;
end;



procedure TLazyCodingAgentForm.MnuViewToggleThemeClick(Sender: TObject);
begin
  if FState.Theme = tkDark then
    FState.SetTheme(tkLight)
  else
    FState.SetTheme(tkDark);
  if not FDeferThemesUntilShown then
    ApplyAllThemes;
end;

procedure TLazyCodingAgentForm.MnuViewResetLayoutClick(Sender: TObject);
begin
  FState.ResetLayout;
end;

procedure TLazyCodingAgentForm.MnuViewTerminalClick(Sender: TObject);
begin
  FState.SetPanelVisible(piTerminal, not FState.IsPanelVisible(piTerminal));
end;

procedure TLazyCodingAgentForm.SplTerminalMoved(Sender: TObject);
begin
  if FState.IsPanelVisible(piTerminal) then
    FState.SetPanelDockedHeight(piTerminal, pnlTerminalHost.Height);
end;

procedure TLazyCodingAgentForm.MnuFileNewClick(Sender: TObject);
var
  WsName, Path: string;
  Entry: TWorkspaceEntry;
begin
  if not TNewWorkspaceForm.Execute(Self, FState.Theme, FRegistry, WsName, Path) then Exit;
  if FRegistry.FindByPath(Path, Entry) then
    ActivateWorkspace(Entry.Id)
  else
    AddOrActivateFolder(WsName, Path);
end;

procedure TLazyCodingAgentForm.MnuFileOpenClick(Sender: TObject);
var
  Dir: string;
begin
  Dir := FState.WorkspaceRoot;
  if Dir = '' then
    Dir := GetUserDir;
  if SelectDirectory('Open project folder', '', Dir) then
    AddOrActivateFolder(ExtractFileName(Dir), Dir);
end;

procedure TLazyCodingAgentForm.MnuFileRemoveWorkspaceClick(Sender: TObject);
var
  WsId: string;
begin
  if FRegistry.Count = 0 then begin
    LcaShowMessage('There are no workspaces in the list.', FState.Theme);
    Exit;
  end;
  WsId := ResolveWorkspaceIdForRemoval;
  if WsId = '' then begin
    LcaShowMessage('Select a workspace on the Home panel, or activate one, then try again.',
      FState.Theme);
    Exit;
  end;
  NavWorkspaceDelete(Self, WsId);
end;

procedure TLazyCodingAgentForm.MnuFileSaveClick(Sender: TObject);
begin
  SaveCurrentSession;
  FRegistry.Save;
  FState.Save;
  LcaShowMessage('Workspace configuration saved.', FState.Theme);
end;

procedure TLazyCodingAgentForm.MnuFileExitClick(Sender: TObject);
begin
  Close;
end;

procedure TLazyCodingAgentForm.MnuAgentClearHistoryClick(Sender: TObject);
var
  Eng: TAgentEngine;
begin
  Eng := ActiveAgent;
  if Assigned(Eng) then
    Eng.ClearConversation;
  if Assigned(FChatPanel) then
    FChatPanel.ClearHistory;
  SaveCurrentSession;
end;

procedure TLazyCodingAgentForm.MnuAgentStopClick(Sender: TObject);
var
  Eng: TAgentEngine;
begin
  Eng := ActiveAgent;
  if Assigned(Eng) then
    Eng.RequestCancel;
end;

procedure TLazyCodingAgentForm.MnuSettingsOptionsClick(Sender: TObject);
begin
  if TSettingsForm.Execute(FState, FRegistry) then begin
    FRegistry.Save;
    StateChanged(Self);
  end;
end;

procedure TLazyCodingAgentForm.MnuWorkspaceProjectRulesClick(Sender: TObject);
begin
  if Trim(FState.WorkspaceRoot) = '' then begin
    LcaShowMessage('Set a workspace project folder first (Settings or File → Open Project Folder).',
      FState.Theme);
    Exit;
  end;
  TWorkspaceRulesForm.Execute(Self, FState.Theme, FState.WorkspaceRoot);
end;

procedure TLazyCodingAgentForm.MnuWorkspaceMultiAgentClick(Sender: TObject);
begin
  TMultiAgentWorkspaceForm.Execute(Self, FState.Theme, FState.WorkspaceName);
end;

procedure TLazyCodingAgentForm.MnuWorkspaceExecutionPlansClick(Sender: TObject);
begin
  TExecutionPlansConfigForm.Execute(Self, FState.Theme, FState.WorkspaceName);
end;

procedure TLazyCodingAgentForm.MnuWorkspaceKnowledgeBaseClick(Sender: TObject);
begin
  TKnowledgeBaseConfigForm.Execute(Self, FState.Theme, FState.WorkspaceName);
end;

procedure TLazyCodingAgentForm.MnuWorkspaceTheBrainClick(Sender: TObject);
begin
  TTheBrainConfigForm.Execute(Self, FState.Theme, FState.WorkspaceName);
end;

procedure TLazyCodingAgentForm.MnuHelpUserGuideClick(Sender: TObject);
begin
  THelpForm.ShowGuide(Self, FState.Theme);
end;

procedure TLazyCodingAgentForm.MnuHelpAboutClick(Sender: TObject);
begin
  LcaShowMessage('LazyCodingAgent v1.0'#13#10 +
              'Standalone Desktop AI Coding Assistant'#13#10 +
              'Built with Free Pascal & Lazarus LCL', FState.Theme);
end;

procedure TLazyCodingAgentForm.ApplyWorkspaceChatVisibility;
begin
  if FState.HasActiveWorkspace then
    FState.SetPanelVisible(piChat, True)
  else if not FState.IsPanelFloating(piChat) then
    FState.SetPanelVisible(piChat, False);
end;

procedure TLazyCodingAgentForm.RefreshWorkspaceNav;
var
  I: Integer;
  E: TWorkspaceEntry;
  Cap: string;
begin
  FNavWorkCaptions.Clear;
  FNavWorkIds.Clear;
  for I := 0 to FRegistry.Count - 1 do begin
    E := FRegistry.GetEntry(I);
    if SameText(E.Id, FState.ActiveWorkspaceId) then
      Cap := '● ' + E.DisplayName
    else
      Cap := '  ' + E.DisplayName;
    FNavWorkCaptions.Add(Cap);
    FNavWorkIds.Add(E.Id);
  end;
end;

procedure TLazyCodingAgentForm.RefreshChatSessionTabs;
var
  I, SelIdx: Integer;
  S: TChatSessionInfo;
  Cap: string;
  Store: TChatSessionStore;
  Caps: array of string;
  Closable: array of Boolean;
begin
  if not Assigned(lcaChatSessionTabBar) then Exit;
  Caps := nil;
  Closable := nil;
  FChatSessionTabIds.Clear;
  SelIdx := -1;
  SetLength(Caps, 0);
  SetLength(Closable, 0);
  if not FState.HasActiveWorkspace or not Assigned(ActiveStore) then begin
    lcaChatSessionTabBar.SetManualTabs(Caps, Closable, -1);
    Exit;
  end;
  Store := ActiveStore;
  for I := 0 to Store.SessionCount - 1 do begin
    S := Store.GetSessionInfo(I);
    if S.Archived then Continue;
    Cap := S.Title;
    if Assigned(FActiveHub) and FActiveHub.IsSessionRunning(S.Id) then
      Cap := Cap + ' ●';
    SetLength(Caps, Length(Caps) + 1);
    SetLength(Closable, Length(Closable) + 1);
    Caps[High(Caps)] := Cap;
    Closable[High(Closable)] := True;
    FChatSessionTabIds.Add(S.Id);
    if SameText(S.Id, FCurrentSessionId) then
      SelIdx := FChatSessionTabIds.Count - 1;
  end;
  lcaChatSessionTabBar.SetManualTabs(Caps, Closable, SelIdx);
end;

procedure TLazyCodingAgentForm.RefreshSessionNav;
var
  I: Integer;
  S: TChatSessionInfo;
  Cap: string;
  Store: TChatSessionStore;
  HasArchived: Boolean;
begin
  FNavSessionCaptions.Clear;
  FNavSessionIds.Clear;
  FNavSessionArchived.Clear;
  if not FState.HasActiveWorkspace or not Assigned(ActiveStore) then Exit;
  Store := ActiveStore;
  HasArchived := False;
  for I := 0 to Store.SessionCount - 1 do begin
    S := Store.GetSessionInfo(I);
    if S.Archived then begin
      HasArchived := True;
      Continue;
    end;
    Cap := S.Title;
    if Assigned(FActiveHub) and FActiveHub.IsSessionRunning(S.Id) then
      Cap := '⏳ ' + Cap;
    if SameText(S.Id, FCurrentSessionId) then
      Cap := '● ' + Cap
    else
      Cap := '  ' + Cap;
    FNavSessionCaptions.Add(Cap);
    FNavSessionIds.Add(S.Id);
    FNavSessionArchived.Add('0');
  end;
  if HasArchived then begin
    FNavSessionCaptions.Add('── Archived ──');
    FNavSessionIds.Add('');
    FNavSessionArchived.Add('0');
    for I := 0 to Store.SessionCount - 1 do begin
      S := Store.GetSessionInfo(I);
      if not S.Archived then Continue;
      Cap := '📦 ' + S.Title;
      if SameText(S.Id, FCurrentSessionId) then
        Cap := '● ' + Cap;
      FNavSessionCaptions.Add(Cap);
      FNavSessionIds.Add(S.Id);
      FNavSessionArchived.Add('1');
    end;
  end;
end;

procedure TLazyCodingAgentForm.SaveCurrentSession;
begin
  if not FState.HasActiveWorkspace then Exit;
  if FCurrentSessionId = '' then Exit;
  if Assigned(FActiveHub) then
    FActiveHub.SaveSessionToStore(FCurrentSessionId);
  FRegistry.SetLastSessionId(FState.ActiveWorkspaceId, FCurrentSessionId);
end;

function TLazyCodingAgentForm.AddOrActivateFolder(const ADisplayName, AFolderPath: string): Boolean;
var
  Id: string;
  Entry: TWorkspaceEntry;
  Norm: string;
begin
  Norm := NormalizeWorkspaceFolderPath(AFolderPath);
  if (Norm = '') or not DirectoryExists(Norm) then
    Exit(False);
  if FRegistry.FindByPath(Norm, Entry) then
    Id := Entry.Id
  else
    Id := FRegistry.AddWorkspace(ADisplayName, Norm);
  FRegistry.Save;
  ActivateWorkspace(Id);
  Result := True;
end;

procedure TLazyCodingAgentForm.ActivateWorkspace(const AWorkspaceId: string);
var
  Entry: TWorkspaceEntry;
  Sid: string;
begin
  if not FRegistry.FindById(AWorkspaceId, Entry) then begin
    DeactivateWorkspace;
    Exit;
  end;
  if not DirectoryExists(Entry.FolderPath) then begin
    if LcaMessageDlg('LazyCodingAgent',
      'The workspace folder no longer exists:'#13#10 + Entry.FolderPath + #13#10#13#10 +
      'Remove "' + Entry.DisplayName + '" from the workspace list?',
      mtConfirmation, [mbYes, mbNo], FState.Theme) = mrYes then
      RemoveWorkspaceFromList(AWorkspaceId)
    else if SameText(FState.ActiveWorkspaceId, AWorkspaceId) or not FState.HasActiveWorkspace then
      DeactivateWorkspace;
    Exit;
  end;

  if FState.HasActiveWorkspace and not SameText(FState.ActiveWorkspaceId, AWorkspaceId) then begin
    if Assigned(FActiveHub) then
      FActiveHub.SaveAll;
    FActiveHub := nil;
  end;

  FState.ActiveWorkspaceId := Entry.Id;
  FState.WorkspaceName := Entry.DisplayName;
  FState.WorkspaceRoot := Entry.FolderPath;
  FRegistry.ActiveWorkspaceId := Entry.Id;
  FRegistry.Save;

  EnsureActiveHub;
  FCurrentSessionId := Entry.LastSessionId;
  if FCurrentSessionId = '' then
    FCurrentSessionId := ActiveStore.GetLastSessionId;

  if ActiveStore.SessionCount = 0 then begin
    Sid := ActiveStore.CreateSession('Chat 1');
    FCurrentSessionId := Sid;
  end else if FCurrentSessionId = '' then
    FCurrentSessionId := ActiveStore.GetSessionInfo(0).Id;

  FRegistry.SetLastSessionId(Entry.Id, FCurrentSessionId);
  BindSessionToUI(FCurrentSessionId);

  if Assigned(lcaTerminalPanel) then begin
    lcaTerminalPanel.SetWorkingDirectory(FState.WorkspaceRoot);
    if FState.IsPanelVisible(piTerminal) then
      lcaTerminalPanel.RestartForWorkspace;
  end;

  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.DeactivateWorkspace;
begin
  if Assigned(FActiveHub) then
    FActiveHub.SaveAll;
  FActiveHub := nil;
  FState.ActiveWorkspaceId := '';
  FState.WorkspaceName := '';
  FState.WorkspaceRoot := '';
  FCurrentSessionId := '';
  FRegistry.ActiveWorkspaceId := '';
  FRegistry.Save;
  FState.Save;
  if Assigned(FChatPanel) then
    FChatPanel.ClearHistory;
  FState.SetPanelVisible(piChat, False);
  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.NavWorkspaceSelect(Sender: TObject; const AWorkspaceId: string);
begin
  if SameText(AWorkspaceId, FState.ActiveWorkspaceId) then Exit;
  ActivateWorkspace(AWorkspaceId);
end;

procedure TLazyCodingAgentForm.NavWorkspaceNew(Sender: TObject);
begin
  MnuFileNewClick(Self);
end;

procedure TLazyCodingAgentForm.RemoveWorkspaceFromList(const AWorkspaceId: string);
var
  Entry: TWorkspaceEntry;
  WasActive: Boolean;
  Hub: TChatSessionHub;
  NextId: string;
begin
  if not FRegistry.FindById(AWorkspaceId, Entry) then Exit;
  WasActive := SameText(FState.ActiveWorkspaceId, AWorkspaceId);
  if WasActive then begin
    if Assigned(FActiveHub) then
      FActiveHub.SaveAll;
    FActiveHub := nil;
  end else begin
    Hub := FSessionHubs.FindHub(AWorkspaceId);
    if Assigned(Hub) then
      Hub.SaveAll;
  end;
  FSessionHubs.RemoveHub(AWorkspaceId, True, False);
  TAppDatabase.CloseWorkspace(AWorkspaceId);
  FRegistry.RemoveWorkspace(AWorkspaceId);
  FRegistry.Save;
  if FRegistry.Count = 0 then
    DeactivateWorkspace
  else if WasActive then begin
    NextId := FRegistry.GetEntry(0).Id;
    ActivateWorkspace(NextId);
  end else
    StateChanged(Self);
end;

function TLazyCodingAgentForm.ResolveWorkspaceIdForRemoval: string;
var
  Entry: TWorkspaceEntry;
  Idx: Integer;
begin
  Result := '';
  if FRegistry.Count = 0 then Exit;
  if FRegistry.FindById(FState.ActiveWorkspaceId, Entry) then begin
    Result := Entry.Id;
    Exit;
  end;
  if FRegistry.Count = 1 then begin
    Result := FRegistry.GetEntry(0).Id;
    Exit;
  end;
  if (FState.Navigation = niHome) and Assigned(lstNavFile) then begin
    Idx := lstNavFile.ItemIndex;
    if (Idx >= 0) and (Idx < FNavWorkIds.Count) then
      Result := FNavWorkIds[Idx];
  end;
end;

procedure TLazyCodingAgentForm.NavWorkspaceDelete(Sender: TObject; const AWorkspaceId: string);
var
  Entry: TWorkspaceEntry;
begin
  if not FRegistry.FindById(AWorkspaceId, Entry) then Exit;
  if LcaMessageDlg('LazyCodingAgent',
    'Remove workspace "' + Entry.DisplayName + '" from the list?'#13#10#13#10 +
    'Your project folder will not be changed or deleted.'#13#10 +
    'Chat history stays in LazyCodingAgent settings and returns if you open the same folder again.',
    mtConfirmation, [mbYes, mbNo], FState.Theme) <> mrYes then
    Exit;
  RemoveWorkspaceFromList(AWorkspaceId);
end;

procedure TLazyCodingAgentForm.NavSessionSelect(Sender: TObject; const ASessionId: string);
begin
  SelectSession(ASessionId);
  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.CreateAndSelectNewSession;
begin
  ShowChatCenterTab;
  NavSessionNew(Self);
end;

procedure TLazyCodingAgentForm.NavSessionNew(Sender: TObject);
var
  Sid: string;
begin
  if not FState.HasActiveWorkspace then begin
    LcaShowMessage('Select a workspace first.', FState.Theme);
    Exit;
  end;
  EnsureActiveHub;
  SaveCurrentSession;
  Sid := ActiveStore.CreateSession('');
  FRegistry.SetLastSessionId(FState.ActiveWorkspaceId, Sid);
  FRegistry.Save;
  FCurrentSessionId := Sid;
  ActiveStore.SetLastSessionId(Sid);
  FActiveHub.GetOrCreateEngine(Sid);
  BindSessionToUI(Sid);
  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.EnsureActiveNonArchivedSession;
var
  I: Integer;
  Store: TChatSessionStore;
  Info: TChatSessionInfo;
  NewId: string;
begin
  if not FState.HasActiveWorkspace or not Assigned(ActiveStore) then Exit;
  Store := ActiveStore;
  if (FCurrentSessionId <> '') and Store.FindSessionInfo(FCurrentSessionId, Info) and not Info.Archived then
    Exit;

  NewId := '';
  for I := 0 to Store.SessionCount - 1 do
    if not Store.GetSessionInfo(I).Archived then begin
      NewId := Store.GetSessionInfo(I).Id;
      Break;
    end;
  if NewId = '' then
    NewId := Store.CreateSession('');
  FCurrentSessionId := NewId;
  ActiveStore.SetLastSessionId(NewId);
  FRegistry.SetLastSessionId(FState.ActiveWorkspaceId, NewId);
  FRegistry.Save;
  if Assigned(FActiveHub) then
    FActiveHub.GetOrCreateEngine(NewId);
  BindSessionToUI(NewId);
end;

procedure TLazyCodingAgentForm.DoArchiveSession(const ASessionId: string);
var
  E: TAgentEngine;
begin
  if not FState.HasActiveWorkspace or not Assigned(FActiveHub) or not Assigned(ActiveStore) then Exit;
  if ASessionId = '' then Exit;
  E := FActiveHub.EngineFor(ASessionId);
  if Assigned(E) then
    E.RequestCancel;
  ActiveStore.SetSessionArchived(ASessionId, True);
  FActiveHub.SaveSessionToStore(ASessionId);
  EnsureActiveNonArchivedSession;
  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.NavSessionArchive(Sender: TObject; const ASessionId: string);
begin
  DoArchiveSession(ASessionId);
end;

procedure TLazyCodingAgentForm.NavSessionRestore(Sender: TObject; const ASessionId: string);
begin
  if not FState.HasActiveWorkspace or not Assigned(ActiveStore) then Exit;
  ActiveStore.SetSessionArchived(ASessionId, False);
  if SameText(ASessionId, FCurrentSessionId) then
    ApplySessionComposerState;
  StateChanged(Self);
end;

procedure TLazyCodingAgentForm.NavSessionDelete(Sender: TObject; const ASessionId: string);
var
  I: Integer;
  Store: TChatSessionStore;
  NewId: string;
begin
  if not FState.HasActiveWorkspace or not Assigned(ActiveStore) then Exit;
  if LcaMessageDlg('LazyCodingAgent', 'Permanently delete this chat session?',
    mtConfirmation, [mbYes, mbNo], FState.Theme) <> mrYes then
    Exit;
  Store := ActiveStore;
  if Assigned(FActiveHub) then
    FActiveHub.RemoveSession(ASessionId);
  Store.DeleteSession(ASessionId);
  if SameText(ASessionId, FCurrentSessionId) then begin
    NewId := '';
    for I := 0 to Store.SessionCount - 1 do
      if not Store.GetSessionInfo(I).Archived then begin
        NewId := Store.GetSessionInfo(I).Id;
        Break;
      end;
    if NewId = '' then
      NewId := Store.CreateSession('');
    FCurrentSessionId := NewId;
    BindSessionToUI(NewId);
  end;
  StateChanged(Self);
end;



procedure TLazyCodingAgentForm.OpenMarkdownInCenterTab(const APath: string);
var
  Path: string;
  Lines: TStringList;
begin
  Path := ExpandFileName(Trim(APath));
  if (Path = '') or not FileExists(Path) then begin
    LcaShowMessage('File not found.', FState.Theme);
    Exit;
  end;
  FMarkdownPath := Path;
  tsMarkdown.Caption := ExtractFileName(Path) + ' [Preview]';
  TLcaThemedPageTabBar.SetTabHidden(tsMarkdown, False);
  FState.SetPanelVisible(piChat, True);
  ApplyDockPanelsLayout;
  if Assigned(pgcCenter) then
    pgcCenter.ActivePage := tsMarkdown;
  if Assigned(lcaCenterTabBar) then
    lcaCenterTabBar.RefreshFromPageControl;
  if not Assigned(FMarkdownPreview) then begin
    FMarkdownPreview := TLcaMarkdownView.Create(Self);
    FMarkdownPreview.Parent := pnlMarkdownPreviewHost;
    FMarkdownPreview.Align := alClient;
  end;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Path);
    FMarkdownPreview.SetMarkdown(Lines.Text);
  finally
    Lines.Free;
  end;
end;


procedure TLazyCodingAgentForm.NavFileOpen(Sender: TObject; const AFilePath: string);
var
  Choice: TMarkdownOpenChoice;
begin
  if IsMarkdownFile(AFilePath) then begin
    Choice := TOpenMarkdownForm.Execute(Self, FState.Theme, AFilePath);
    case Choice of
      mocPreview: OpenMarkdownInCenterTab(AFilePath);
      mocSource: OpenFileInCenterTab(AFilePath);
    end;
  end else
    OpenFileInCenterTab(AFilePath);
end;

function TLazyCodingAgentForm.IsMarkdownFile(const APath: string): Boolean;
begin
  Result := SameText(ExtractFileExt(APath), '.md');
end;

procedure TLazyCodingAgentForm.OpenFileInCenterTab(const APath: string);
var
  Path: string;
begin
  Path := ExpandFileName(Trim(APath));
  if (Path = '') or not FileExists(Path) then begin
    LcaShowMessage('File not found.', FState.Theme);
    Exit;
  end;
  if Assigned(FFileEditor) and FFileEditor.Modified and
     (FFileEditor.FilePath <> '') and not SameText(FFileEditor.FilePath, Path) then
    if not FFileEditor.PromptSaveIfModified then
      Exit;
  if not Assigned(FFileEditor) then Exit;
  if not FFileEditor.LoadFile(Path) then begin
    LcaShowMessage('Could not open file.', FState.Theme);
    Exit;
  end;
  tsEditor.Caption := ExtractFileName(Path);
  TLcaThemedPageTabBar.SetTabHidden(tsEditor, False);
  FState.SetPanelVisible(piChat, True);
  ApplyDockPanelsLayout;
  ApplyEditorTheme;
  RefreshEditorScheme;
  if Assigned(pgcCenter) then
    pgcCenter.ActivePage := tsEditor;
  if Assigned(lcaCenterTabBar) then
    lcaCenterTabBar.RefreshFromPageControl;
end;

procedure TLazyCodingAgentForm.ApplyEditorTheme;
begin
  if Assigned(FFileEditor) then
    FFileEditor.ApplyTheme(FState.Theme);
end;

procedure TLazyCodingAgentForm.RefreshEditorScheme;
begin
  if Assigned(FFileEditor) and Assigned(FSyntaxSchemes) then
    FFileEditor.ApplySyntaxScheme(FSyntaxSchemes.ActiveScheme);
end;

function TLazyCodingAgentForm.PromptDirtyEditor: Boolean;
begin
  if not Assigned(FFileEditor) then
    Exit(True);
  if (pgcCenter = nil) or (pgcCenter.ActivePage <> tsEditor) then
    Exit(True);
  Result := FFileEditor.PromptSaveIfModified;
end;

function TLazyCodingAgentForm.SaveActiveEditorFile: Boolean;
begin
  if not Assigned(FFileEditor) or (FFileEditor.FilePath = '') then
    Exit(False);
  if (pgcCenter = nil) or (pgcCenter.ActivePage <> tsEditor) then
    Exit(False);
  Result := FFileEditor.SaveFile;
  if Result then begin
    tsEditor.Caption := ExtractFileName(FFileEditor.FilePath);
    if Assigned(lcaCenterTabBar) then
      lcaCenterTabBar.RefreshFromPageControl;
  end;
end;


procedure TLazyCodingAgentForm.RebuildActiveSchemeMenu;
var
  I: Integer;
  Item: TMenuItem;
  E: TSyntaxSchemeEntry;
begin
  while mnuViewActiveSchemes.Count > 0 do
    mnuViewActiveSchemes.Delete(0);
  if not Assigned(FSyntaxSchemes) then Exit;
  for I := 0 to FSyntaxSchemes.Count - 1 do begin
    E := FSyntaxSchemes.GetEntry(I);
    Item := TMenuItem.Create(mnuViewActiveSchemes);
    Item.Caption := E.Name;
    Item.Tag := I;
    Item.RadioItem := True;
    Item.Checked := SameText(E.Id, FSyntaxSchemes.ActiveId);
    Item.OnClick := @MenuSelectSyntaxScheme;
    mnuViewActiveSchemes.Add(Item);
  end;
  if Assigned(lcaTitleBar) then
    lcaTitleBar.RefreshFromMainMenu;
end;

procedure TLazyCodingAgentForm.MenuSelectSyntaxScheme(Sender: TObject);
var
  Idx: Integer;
  E: TSyntaxSchemeEntry;
begin
  if not (Sender is TMenuItem) or not Assigned(FSyntaxSchemes) then Exit;
  Idx := TMenuItem(Sender).Tag;
  if (Idx < 0) or (Idx >= FSyntaxSchemes.Count) then Exit;
  E := FSyntaxSchemes.GetEntry(Idx);
  FSyntaxSchemes.SetActive(E.Id);
  RefreshEditorScheme;
  RebuildActiveSchemeMenu;
end;

procedure TLazyCodingAgentForm.MnuViewSyntaxSchemesClick(Sender: TObject);
var
  SchemesChanged: Boolean;
begin
  if not Assigned(FSyntaxSchemes) then Exit;
  TSyntaxSchemesForm.Execute(Self, FState.Theme, FSyntaxSchemes, SchemesChanged);
  if SchemesChanged then begin
    RefreshEditorScheme;
    RebuildActiveSchemeMenu;
  end;
end;

procedure TLazyCodingAgentForm.MnuFileSaveFileClick(Sender: TObject);
begin
  if not SaveActiveEditorFile then
    LcaShowMessage('No file editor tab is active.', FState.Theme);
end;

end.
