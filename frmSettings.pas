unit frmSettings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, ComCtrls, LCLType,
  LcaPaintButton, LcaPaintComboBox, LcaThemedPageTabBar, LcaThemedGroupBox,
  uAppTypes, uAgentTypes, LcaTheme, LcaThemedMessageBox, uWorkspaceState, uWorkspaceRegistry,
  LCLIntf,
  uWebSearchTypes, uLlmPromptCacheTypes;

type
  { TSettingsForm }
  TSettingsForm = class(TForm)
  published
    Panel2: TPanel;
    pcChkEnabled: TCheckBox;
    pcLblEnabled: TLabel;
    pcLblRbAutomatic1: TLabel;
    pnlSettingsTabsHost: TPanel;
    pnlSettingsTabStripHost: TPanel;
    lcaSettingsTabBar: TLcaThemedPageTabBar;
    pgcSettings: TPageControl;
    tsProvider: TTabSheet;
    pnlTabProvider: TPanel;
    lblProvider: TLabel;
    cboProvider: TLcaPaintComboBox;
    lblCustomName: TLabel;
    edtCustomName: TEdit;
    lblApiKey: TLabel;
    edtApiKey: TEdit;
    lblBaseUrl: TLabel;
    edtBaseUrl: TEdit;
    btnOpenProviderPortal: TLcaPaintButton;
    lblModels: TLabel;
    lstModels: TListBox;
    btnFetchModels: TLcaPaintButton;
    btnEditModel: TLcaPaintButton;
    btnDeleteModel: TLcaPaintButton;
    lblNotice: TLabel;
    tsAgent: TTabSheet;
    scrAgentTab: TScrollBox;
    pnlTabAgent: TPanel;
    pnlAgentCoreEdits: TPanel;
    pnlAgentLlmNetwork: TPanel;
    pnlAgentToolCalling: TPanel;
    pnlAgentNativeBlock: TPanel;
    pnlAgentNativeRow: TPanel;
    pnlAgentTextToolBlock: TPanel;
    pnlAgentTextToolRow: TPanel;
    pnlAgentStreamingBlock: TPanel;
    pnlAgentStreamingRow: TPanel;
    pnlAgentRunBehavior: TPanel;
    pnlAgentDebuggingBlock: TPanel;
    pnlAgentDebuggingRow: TPanel;
    pnlAgentLearnBlock: TPanel;
    pnlAgentLearnRow: TPanel;
    pnlAgentAutoSumBlock: TPanel;
    pnlAgentAutoSumRow: TPanel;
    pnlAgentContext: TPanel;
    pnlAgentBrowser: TPanel;
    lblTemp: TLabel;
    edtTemp: TEdit;
    lblMaxTokens: TLabel;
    edtMaxTokens: TEdit;
    lblMaxSteps: TLabel;
    edtMaxSteps: TEdit;
    lblLlmConnectTimeout: TLabel;
    edtLlmConnectTimeoutSec: TEdit;
    lblLlmReadTimeout: TLabel;
    edtLlmReadTimeoutSec: TEdit;
    lblLlmHttpRetries: TLabel;
    edtLlmHttpRetries: TEdit;
    chkLlmNativeToolCalling: TCheckBox;
    lblLlmNativeToolCalling: TLabel;
    lblLlmNativeToolHint: TLabel;
    chkLlmTextToolCompat: TCheckBox;
    lblLlmTextToolCompat: TLabel;
    lblLlmTextToolHint: TLabel;
    chkLlmStreamingEnabled: TCheckBox;
    lblLlmStreamingEnabled: TLabel;
    lblLlmStreamingHint: TLabel;
    chkDebuggingMode: TCheckBox;
    lblDebuggingMode: TLabel;
    lblDebuggingHint: TLabel;
    chkLearnMode: TCheckBox;
    lblLearnMode: TLabel;
    lblLearnModeHint: TLabel;
    chkAutoSummarizeContext: TCheckBox;
    lblAutoSummarizeContext: TLabel;
    lblAutoSummarizeHint: TLabel;
    lblContextWindow: TLabel;
    edtContextWindow: TEdit;
    lblSummarizeThreshold: TLabel;
    edtSummarizeThreshold: TEdit;
    lblMaxTokensHint: TLabel;
    lblBrowserExecutable: TLabel;
    edtBrowserExecutable: TEdit;
    tsTools: TTabSheet;
    scrToolsTab: TScrollBox;
    pnlToolsContent: TPanel;
    pnlToolsHeader: TPanel;
    wsLblWebSearchTitle: TLabel;
    wsChkWebSearchEnabled: TCheckBox;
    wsLblWebSearchEnabled: TLabel;
    wsLblMaxResults: TLabel;
    wsEdtMaxResults: TEdit;
    wsLblTotalTimeout: TLabel;
    wsEdtTotalTimeoutSec: TEdit;
    wsChkAutoFallback: TCheckBox;
    wsLblAutoFallback: TLabel;
    wsChkFallbackEmpty: TCheckBox;
    wsLblFallbackEmpty: TLabel;
    wsChkAllowPrivateInstances: TCheckBox;
    wsLblAllowPrivateInstances: TLabel;
    pnlToolsConnections: TPanel;
    wsLblConnections: TLabel;
    wsLvConnections: TListView;
    pnlToolsFooter: TPanel;
    pnlToolsConnButtons: TPanel;
    wsBtnAddConn: TLcaPaintButton;
    wsBtnEditConn: TLcaPaintButton;
    wsBtnRemoveConn: TLcaPaintButton;
    wsBtnTestConn: TLcaPaintButton;
    wsBtnMoveUp: TLcaPaintButton;
    wsBtnMoveDown: TLcaPaintButton;
    wsLblTestNote: TLabel;
    wsMemoConnStatus: TMemo;
    tsPerformance: TTabSheet;
    scrPerformanceTab: TScrollBox;
    pnlPerformanceContent: TPanel;
    pcLblHint: TLabel;
    pcGrpMode: TLcaThemedGroupBox;
    pcRbAutomatic: TRadioButton;
    pcLblRbAutomatic: TLabel;
    pcRbExplicit: TRadioButton;
    pcLblRbExplicit: TLabel;
    pcRbDisabled: TRadioButton;
    pcLblRbDisabled: TLabel;
    pcLblRetention: TLabel;
    pcCboRetention: TComboBox;
    pcGrpContent: TLcaThemedGroupBox;
    pcChkSystem: TCheckBox;
    pcLblChkSystem: TLabel;
    pcChkTools: TCheckBox;
    pcLblChkTools: TLabel;
    pcChkProject: TCheckBox;
    pcLblChkProject: TLabel;
    pcChkHistory: TCheckBox;
    pcLblChkHistory: TLabel;
    pcGrpStats: TLcaThemedGroupBox;
    pcLblInputTokens: TLabel;
    pcLblCachedTokens: TLabel;
    pcLblHitRatio: TLabel;
    pcLblSavings: TLabel;
    pcBtnResetStats: TLcaPaintButton;
    tsWorkspace: TTabSheet;
    pnlTabWorkspace: TPanel;
    lblWorkspaceRoot: TLabel;
    edtWorkspaceRoot: TEdit;
    btnBrowseWorkspace: TLcaPaintButton;
    lblWorkspaceName: TLabel;
    edtWorkspaceName: TEdit;
    pnlBottom: TPanel;
    btnOK: TLcaPaintButton;
    btnCancel: TLcaPaintButton;


    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure cboProviderChange(Sender: TObject);
    procedure btnOpenProviderPortalClick(Sender: TObject);
    procedure lstModelsClick(Sender: TObject);
    procedure lstModelsDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure btnFetchModelsClick(Sender: TObject);
    procedure btnEditModelClick(Sender: TObject);
    procedure btnDeleteModelClick(Sender: TObject);
    procedure btnBrowseWorkspaceClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure lblAgentToggleCheckClick(Sender: TObject);
    procedure pnlSettingsTabsHostClick(Sender: TObject);
    procedure wsLblToggleCheckClick(Sender: TObject);
    procedure wsLvConnectionsResize(Sender: TObject);
    procedure wsBtnAddConnClick(Sender: TObject);
    procedure wsBtnEditConnClick(Sender: TObject);
    procedure wsBtnRemoveConnClick(Sender: TObject);
    procedure wsBtnTestConnClick(Sender: TObject);
    procedure wsBtnMoveUpClick(Sender: TObject);
    procedure wsBtnMoveDownClick(Sender: TObject);
    procedure pcLblToggleCheckClick(Sender: TObject);
    procedure pcLblSelectRadioClick(Sender: TObject);
    procedure pcBtnResetStatsClick(Sender: TObject);
  private
    FState: TWorkspaceState;
    FRegistry: TWorkspaceRegistry;
    FCurrentTheme: TThemeKind;
    FDialogProvider: TLlmProvider;
    FDefaultModelId: string;
    FSwitchingProvider: Boolean;
    FWebSearchConfig: TWebSearchGlobalConfig;
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    function CurrentDialogProvider: TLlmProvider;
    function SavedModelLine(const M: TSavedModel): string;
    procedure LoadFromState;
    procedure SaveToState;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure UpdateMaxTokensHint;
    procedure ReadLlmTimeoutFieldsFromForm(out AConnectMs, AReadMs: Integer);
    procedure WriteLlmTimeoutFieldsToForm(AConnectMs, AReadMs: Integer);
    function ReadLlmHttpRetryField: Integer;
    procedure WriteLlmHttpRetryField(AValue: Integer);
    procedure FlushCredentialsToState(AProv: TLlmProvider);
    procedure LoadProviderTab(AProv: TLlmProvider);
    procedure RefreshProviderComboItem;
    procedure UpdateProviderAuxiliaryFields(AProv: TLlmProvider);
    procedure RefreshModelList;
    procedure ModelSearchAdd(Sender: TObject; const AModelId, ADisplayName: string);
    procedure LoadWebSearchTab;
    procedure SaveWebSearchTab;
    procedure RefreshWebSearchConnectionList;
    procedure AdjustWebSearchListColumns;
    function WebSearchSelectedConnectionIndex: Integer;
    procedure RenumberWebSearchPriorities;
    procedure ApplyWebSearchUiToConfig;
    procedure LoadPromptCacheTab(const ASettings: TPromptCacheSettings);
    function SavePromptCacheTab: TPromptCacheSettings;
    procedure UpdatePromptCacheCapabilityUi;
    procedure RefreshPromptCacheStats;
  public
    class function Execute(AState: TWorkspaceState; ARegistry: TWorkspaceRegistry = nil): Boolean;
  end;

implementation

{$R *.lfm}

uses
  StrUtils, frmWebSearchConnection, frmModelSearch, frmEditSavedModel, uChatContextManager,
  uBrowserReadConfig, uLlmClient, uLlmProviderCatalog, uWebSearchConfig, uWebSearchSecrets,
  uWebSearchManager, uWebSearchHttp, uLlmCacheCapabilities, uLlmCacheUsage;

function TSettingsForm.CurrentDialogProvider: TLlmProvider;
begin
  Result := TLlmProvider(cboProvider.ItemIndex);
end;

function TSettingsForm.SavedModelLine(const M: TSavedModel): string;
begin
  if (Trim(M.DisplayName) <> '') and not SameText(M.DisplayName, M.ModelId) then
    Result := M.DisplayName + ' — ' + M.ModelId
  else
    Result := M.ModelId;
end;

class function TSettingsForm.Execute(AState: TWorkspaceState; ARegistry: TWorkspaceRegistry): Boolean;
var
  Dlg: TSettingsForm;
begin
  Dlg := TSettingsForm.Create(nil);
  try
    Dlg.FState := AState;
    Dlg.FRegistry := ARegistry;
    Dlg.FCurrentTheme := AState.Theme;
    Dlg.LoadFromState;
    Result := (Dlg.ShowModal = mrOk);
    if Result then begin
      Dlg.SaveToState;
      AState.Save;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TSettingsForm.FormShow(Sender: TObject);
begin
  ApplyTheme(FCurrentTheme);
  ApplyFormPlatformThemes(Self, FCurrentTheme);
end;

procedure TSettingsForm.FormCreate(Sender: TObject);
begin
  Caption := 'LazyCodingAgent Settings';
  FCurrentTheme := tkDark;
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
end;

procedure TSettingsForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then begin
    Key := 0;
    btnCancelClick(Self);
  end else if (Key = VK_RETURN) and not (ssCtrl in Shift) and not (ssAlt in Shift) then begin
    if not (ActiveControl is TComboBox) then begin
      Key := 0;
      btnOKClick(Self);
    end;
  end;
end;

procedure TSettingsForm.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FCurrentTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.Background;
  Font.Color := P.Text;
  Font.Name := 'Segoe UI';
  pnlBottom.Color := P.Surface;

  ApplyThemedForm(Self, ATheme);
  pnlBottom.Color := P.Surface;
  if Assigned(scrAgentTab) then begin
    scrAgentTab.Color := P.Surface;
    scrAgentTab.ParentColor := False;
  end;
  if Assigned(pnlTabAgent) then begin
    pnlTabAgent.Color := P.Surface;
    pnlTabAgent.ParentColor := False;
    if Assigned(pnlAgentCoreEdits) then begin
      pnlAgentCoreEdits.Color := P.Surface;
      pnlAgentCoreEdits.ParentColor := False;
    end;
    if Assigned(pnlAgentLlmNetwork) then begin
      pnlAgentLlmNetwork.Color := P.Surface;
      pnlAgentLlmNetwork.ParentColor := False;
    end;
    if Assigned(pnlAgentToolCalling) then begin
      pnlAgentToolCalling.Color := P.Surface;
      pnlAgentToolCalling.ParentColor := False;
    end;
    if Assigned(pnlAgentNativeBlock) then begin
      pnlAgentNativeBlock.Color := P.Surface;
      pnlAgentNativeBlock.ParentColor := False;
      pnlAgentNativeRow.Color := P.Surface;
      pnlAgentNativeRow.ParentColor := False;
    end;
    if Assigned(pnlAgentTextToolBlock) then begin
      pnlAgentTextToolBlock.Color := P.Surface;
      pnlAgentTextToolBlock.ParentColor := False;
      pnlAgentTextToolRow.Color := P.Surface;
      pnlAgentTextToolRow.ParentColor := False;
    end;
    if Assigned(pnlAgentStreamingBlock) then begin
      pnlAgentStreamingBlock.Color := P.Surface;
      pnlAgentStreamingBlock.ParentColor := False;
      pnlAgentStreamingRow.Color := P.Surface;
      pnlAgentStreamingRow.ParentColor := False;
    end;
    if Assigned(pnlAgentRunBehavior) then begin
      pnlAgentRunBehavior.Color := P.Surface;
      pnlAgentRunBehavior.ParentColor := False;
    end;
    if Assigned(pnlAgentDebuggingBlock) then begin
      pnlAgentDebuggingBlock.Color := P.Surface;
      pnlAgentDebuggingBlock.ParentColor := False;
      pnlAgentDebuggingRow.Color := P.Surface;
      pnlAgentDebuggingRow.ParentColor := False;
    end;
    if Assigned(pnlAgentLearnBlock) then begin
      pnlAgentLearnBlock.Color := P.Surface;
      pnlAgentLearnBlock.ParentColor := False;
      pnlAgentLearnRow.Color := P.Surface;
      pnlAgentLearnRow.ParentColor := False;
    end;
    if Assigned(pnlAgentAutoSumBlock) then begin
      pnlAgentAutoSumBlock.Color := P.Surface;
      pnlAgentAutoSumBlock.ParentColor := False;
      pnlAgentAutoSumRow.Color := P.Surface;
      pnlAgentAutoSumRow.ParentColor := False;
    end;
    if Assigned(pnlAgentContext) then begin
      pnlAgentContext.Color := P.Surface;
      pnlAgentContext.ParentColor := False;
    end;
    if Assigned(pnlAgentBrowser) then begin
      pnlAgentBrowser.Color := P.Surface;
      pnlAgentBrowser.ParentColor := False;
    end;
  end;
  if Assigned(scrToolsTab) then begin
    scrToolsTab.Color := P.Background;
    scrToolsTab.ParentColor := False;
  end;
  if Assigned(pnlToolsContent) then begin
    pnlToolsContent.Color := P.Background;
    pnlToolsHeader.Color := P.Background;
    pnlToolsConnections.Color := P.Background;
    pnlToolsFooter.Color := P.Background;
    pnlToolsConnButtons.Color := P.Background;
  end;
  if Assigned(wsMemoConnStatus) then begin
    wsMemoConnStatus.Color := P.SurfaceAlt;
    wsMemoConnStatus.Font.Color := P.Text;
  end;
  if Assigned(wsEdtMaxResults) then begin
    wsEdtMaxResults.Color := P.SurfaceAlt;
    wsEdtMaxResults.Font.Color := P.Text;
    wsEdtTotalTimeoutSec.Color := P.SurfaceAlt;
    wsEdtTotalTimeoutSec.Font.Color := P.Text;
  end;
  if Assigned(wsLvConnections) then begin
    wsLvConnections.Color := P.SurfaceAlt;
    wsLvConnections.Font.Color := P.Text;
  end;
  if Assigned(scrPerformanceTab) then begin
    scrPerformanceTab.Color := P.Surface;
    scrPerformanceTab.ParentColor := False;
  end;
  if Assigned(pnlPerformanceContent) then
    pnlPerformanceContent.Color := P.Surface;
  if Assigned(pcLblHint) then
    pcLblHint.Font.Color := P.TextMuted;

  edtApiKey.Color := P.SurfaceAlt;
  edtApiKey.Font.Color := P.Text;
  edtBaseUrl.Color := P.SurfaceAlt;
  edtBaseUrl.Font.Color := P.Text;
  if Assigned(edtCustomName) then begin
    edtCustomName.Color := P.SurfaceAlt;
    edtCustomName.Font.Color := P.Text;
  end;
  ApplyPlatformChrome(Self, ATheme);
  ApplyPlatformScrollableThemeRecursive(Self, ATheme);
  ConfigureThemedListBox(lstModels, ATheme);
  lstModels.OnDrawItem := @lstModelsDrawItem;
  lstModels.Invalidate;

  edtTemp.Color := P.SurfaceAlt;
  edtTemp.Font.Color := P.Text;
  edtMaxTokens.Color := P.SurfaceAlt;
  edtMaxTokens.Font.Color := P.Text;
  edtMaxSteps.Color := P.SurfaceAlt;
  edtMaxSteps.Font.Color := P.Text;
  edtLlmConnectTimeoutSec.Color := P.SurfaceAlt;
  edtLlmConnectTimeoutSec.Font.Color := P.Text;
  edtLlmReadTimeoutSec.Color := P.SurfaceAlt;
  edtLlmReadTimeoutSec.Font.Color := P.Text;
  edtLlmHttpRetries.Color := P.SurfaceAlt;
  edtLlmHttpRetries.Font.Color := P.Text;
  edtContextWindow.Color := P.SurfaceAlt;
  edtContextWindow.Font.Color := P.Text;
  edtSummarizeThreshold.Color := P.SurfaceAlt;
  edtSummarizeThreshold.Font.Color := P.Text;

  edtWorkspaceRoot.Color := P.SurfaceAlt;
  edtWorkspaceRoot.Font.Color := P.Text;
  edtWorkspaceName.Color := P.SurfaceAlt;
  edtWorkspaceName.Font.Color := P.Text;

  if Assigned(lblNotice) then
    lblNotice.Font.Color := P.TextMuted;
  if Assigned(lblDebuggingHint) then
    lblDebuggingHint.Font.Color := P.TextMuted;
  if Assigned(lblLearnModeHint) then
    lblLearnModeHint.Font.Color := P.TextMuted;
  if Assigned(lblAutoSummarizeHint) then
    lblAutoSummarizeHint.Font.Color := P.TextMuted;
  if Assigned(lblMaxTokensHint) then
    lblMaxTokensHint.Font.Color := P.TextMuted;
  StyleThemedToggleCaptionLabel(lblDebuggingMode, ATheme);
  StyleThemedToggleCaptionLabel(lblLearnMode, ATheme);
  StyleThemedToggleCaptionLabel(lblAutoSummarizeContext, ATheme);
  StyleThemedToggleCaptionLabel(lblLlmNativeToolCalling, ATheme);
  StyleThemedToggleCaptionLabel(lblLlmTextToolCompat, ATheme);
  StyleThemedToggleCaptionLabel(lblLlmStreamingEnabled, ATheme);
  if Assigned(lblLlmNativeToolHint) then
    lblLlmNativeToolHint.Font.Color := P.TextMuted;
  if Assigned(lblLlmTextToolHint) then
    lblLlmTextToolHint.Font.Color := P.TextMuted;
  if Assigned(lblLlmStreamingHint) then
    lblLlmStreamingHint.Font.Color := P.TextMuted;

  StyleThemedToggleCaptionLabel(wsLblWebSearchEnabled, ATheme);
  StyleThemedToggleCaptionLabel(wsLblAutoFallback, ATheme);
  StyleThemedToggleCaptionLabel(wsLblFallbackEmpty, ATheme);
  StyleThemedToggleCaptionLabel(wsLblAllowPrivateInstances, ATheme);
  StyleThemedToggleCaptionLabel(pcLblEnabled, ATheme);
  StyleThemedToggleCaptionLabel(pcLblRbAutomatic, ATheme);
  StyleThemedToggleCaptionLabel(pcLblRbExplicit, ATheme);
  StyleThemedToggleCaptionLabel(pcLblRbDisabled, ATheme);
  StyleThemedToggleCaptionLabel(pcLblChkSystem, ATheme);
  StyleThemedToggleCaptionLabel(pcLblChkTools, ATheme);
  StyleThemedToggleCaptionLabel(pcLblChkProject, ATheme);
  StyleThemedToggleCaptionLabel(pcLblChkHistory, ATheme);

  Invalidate;
end;

procedure TSettingsForm.lblAgentToggleCheckClick(Sender: TObject);
begin
  if Sender = lblDebuggingMode then
    chkDebuggingMode.Checked := not chkDebuggingMode.Checked
  else if Sender = lblLearnMode then
    chkLearnMode.Checked := not chkLearnMode.Checked
  else if Sender = lblAutoSummarizeContext then
    chkAutoSummarizeContext.Checked := not chkAutoSummarizeContext.Checked
  else if Sender = lblLlmNativeToolCalling then
    chkLlmNativeToolCalling.Checked := not chkLlmNativeToolCalling.Checked
  else if Sender = lblLlmTextToolCompat then
    chkLlmTextToolCompat.Checked := not chkLlmTextToolCompat.Checked
  else if Sender = lblLlmStreamingEnabled then
    chkLlmStreamingEnabled.Checked := not chkLlmStreamingEnabled.Checked;
end;

procedure TSettingsForm.pnlSettingsTabsHostClick(Sender: TObject);
begin

end;

procedure TSettingsForm.UpdateMaxTokensHint;
var
  V: Integer;
begin
  if not Assigned(lblMaxTokensHint) then Exit;
  V := StrToIntDef(edtMaxTokens.Text, DEFAULT_MAX_OUTPUT_TOKENS);
  if V < RECOMMENDED_MIN_OUTPUT_TOKENS then
    lblMaxTokensHint.Caption :=
      'Values below 2048 may truncate tool-call JSON and break agent steps.'
  else
    lblMaxTokensHint.Caption := '';
end;

procedure TSettingsForm.ReadLlmTimeoutFieldsFromForm(out AConnectMs, AReadMs: Integer);
var
  ConnectSec, ReadSec: Integer;
begin
  ConnectSec := StrToIntDef(Trim(edtLlmConnectTimeoutSec.Text),
    DEFAULT_LLM_CONNECT_TIMEOUT_MS div 1000);
  ReadSec := StrToIntDef(Trim(edtLlmReadTimeoutSec.Text),
    DEFAULT_LLM_READ_TIMEOUT_MS div 1000);
  AConnectMs := ClampLlmConnectTimeoutMs(ConnectSec * 1000);
  AReadMs := ClampLlmReadTimeoutMs(ReadSec * 1000);
end;

procedure TSettingsForm.WriteLlmTimeoutFieldsToForm(AConnectMs, AReadMs: Integer);
begin
  edtLlmConnectTimeoutSec.Text := IntToStr(ClampLlmConnectTimeoutMs(AConnectMs) div 1000);
  edtLlmReadTimeoutSec.Text := IntToStr(ClampLlmReadTimeoutMs(AReadMs) div 1000);
end;

procedure TSettingsForm.WriteLlmHttpRetryField(AValue: Integer);
begin
  edtLlmHttpRetries.Text := IntToStr(ClampLlmHttpRetryCount(AValue));
end;

function TSettingsForm.ReadLlmHttpRetryField: Integer;
begin
  Result := ClampLlmHttpRetryCount(StrToIntDef(Trim(edtLlmHttpRetries.Text),
    DEFAULT_LLM_HTTP_RETRY_COUNT));
end;

procedure TSettingsForm.FlushCredentialsToState(AProv: TLlmProvider);
begin
  if not Assigned(FState) then Exit;
  FState.SetProviderCredentials(AProv, Trim(edtApiKey.Text), Trim(edtBaseUrl.Text));
  if LlmProviderIsCustom(AProv) then
    FState.SetProviderCustomDisplayName(AProv, Trim(edtCustomName.Text));
end;

procedure TSettingsForm.RefreshProviderComboItem;
var
  CustomName: string;
begin
  if not Assigned(FState) then Exit;
  CustomName := FState.GetProviderCustomDisplayName(lpCustom);
  PopulateLlmProviderCombo(cboProvider.Items, CustomName);
  if (Ord(FDialogProvider) >= 0) and (Ord(FDialogProvider) < cboProvider.Items.Count) then
    cboProvider.ItemIndex := Ord(FDialogProvider);
end;

procedure TSettingsForm.UpdateProviderAuxiliaryFields(AProv: TLlmProvider);
var
  PortalUrl: string;
  ShowCustom: Boolean;
begin
  ShowCustom := LlmProviderIsCustom(AProv);
  if Assigned(lblCustomName) then
    lblCustomName.Visible := ShowCustom;
  if Assigned(edtCustomName) then
    edtCustomName.Visible := ShowCustom;
  PortalUrl := LlmProviderRegistrationUrl(AProv);
  if Assigned(btnOpenProviderPortal) then
    btnOpenProviderPortal.Visible := (not ShowCustom) and (Trim(PortalUrl) <> '');
end;

procedure TSettingsForm.LoadProviderTab(AProv: TLlmProvider);
var
  Key, Url: string;
begin
  if not Assigned(FState) then Exit;
  FState.GetProviderCredentials(AProv, Key, Url);
  edtApiKey.Text := Key;
  if Trim(Url) = '' then
    Url := LlmProviderDefaultApiBaseUrl(AProv);
  edtBaseUrl.Text := Url;
  if Assigned(edtCustomName) then
    edtCustomName.Text := FState.GetProviderCustomDisplayName(lpCustom);
  UpdateProviderAuxiliaryFields(AProv);
  RefreshModelList;
  UpdatePromptCacheCapabilityUi;
end;

procedure TSettingsForm.btnOpenProviderPortalClick(Sender: TObject);
var
  Url: string;
begin
  Url := LlmProviderRegistrationUrl(CurrentDialogProvider);
  if Trim(Url) <> '' then
    OpenURL(Url);
end;

procedure TSettingsForm.RefreshModelList;
var
  I, SelIdx: Integer;
  M: TSavedModel;
  Prov: TLlmProvider;
begin
  if not Assigned(FState) then Exit;
  Prov := CurrentDialogProvider;
  lstModels.Items.BeginUpdate;
  try
    lstModels.Items.Clear;
    SelIdx := -1;
    for I := 0 to FState.SavedModelCount(Prov) - 1 do begin
      M := FState.GetSavedModel(Prov, I);
      lstModels.Items.Add(SavedModelLine(M));
      if SameText(M.ModelId, FDefaultModelId) then
        SelIdx := I;
    end;
    if SelIdx >= 0 then
      lstModels.ItemIndex := SelIdx
    else if lstModels.Items.Count > 0 then begin
      lstModels.ItemIndex := 0;
      FDefaultModelId := FState.GetSavedModel(Prov, 0).ModelId;
    end else
      FDefaultModelId := '';
  finally
    lstModels.Items.EndUpdate;
  end;
end;

procedure TSettingsForm.LoadFromState;
begin
  if not Assigned(FState) then Exit;

  FSwitchingProvider := True;
  try
    FDialogProvider := FState.Provider;
    FDefaultModelId := FState.Model;
    RefreshProviderComboItem;
    LoadProviderTab(FDialogProvider);
  finally
    FSwitchingProvider := False;
  end;

  edtTemp.Text := FloatToStr(FState.Temperature);
  edtMaxTokens.Text := IntToStr(FState.MaxTokens);
  edtMaxSteps.Text := IntToStr(FState.MaxSteps);
  WriteLlmTimeoutFieldsToForm(FState.LlmConnectTimeoutMs, FState.LlmReadTimeoutMs);
  WriteLlmHttpRetryField(FState.LlmHttpRetryCount);
  chkLlmNativeToolCalling.Checked := FState.LlmNativeToolCalling;
  chkLlmTextToolCompat.Checked := FState.LlmTextToolCompat;
  chkLlmStreamingEnabled.Checked := FState.LlmStreamingEnabled;
  chkDebuggingMode.Checked := FState.DebuggingMode;
  chkLearnMode.Checked := FState.LearnMode;
  chkAutoSummarizeContext.Checked := FState.AutoSummarizeContext;
  edtContextWindow.Text := IntToStr(FState.ContextWindowTokens);
  edtSummarizeThreshold.Text := FloatToStr(FState.SummarizeThreshold);
  UpdateMaxTokensHint;

  edtWorkspaceRoot.Text := FState.WorkspaceRoot;
  edtWorkspaceName.Text := FState.WorkspaceName;
  edtBrowserExecutable.Text := LoadBrowserReadConfig.ExecutablePath;

  LoadWebSearchTab;
  LoadPromptCacheTab(FState.PromptCacheSettings);
  UpdatePromptCacheCapabilityUi;

  if Assigned(pgcSettings) then
    pgcSettings.ActivePageIndex := 0;
end;

procedure TSettingsForm.SaveToState;
var
  Prov: TLlmProvider;
  ConnectMs, ReadMs: Integer;
begin
  if not Assigned(FState) then Exit;

  FlushCredentialsToState(FDialogProvider);

  Prov := CurrentDialogProvider;
  FState.Provider := Prov;
  FState.ActivateProvider(Prov);
  FState.CommitActiveProviderCredentials(Trim(edtApiKey.Text), Trim(edtBaseUrl.Text));
  FState.SetModel(FDefaultModelId);

  FState.Temperature := StrToFloatDef(edtTemp.Text, 0.2);
  FState.MaxTokens := ClampMaxOutputTokens(StrToIntDef(edtMaxTokens.Text, DEFAULT_MAX_OUTPUT_TOKENS));
  edtMaxTokens.Text := IntToStr(FState.MaxTokens);
  FState.MaxSteps := StrToIntDef(edtMaxSteps.Text, DEFAULT_MAX_AGENT_STEPS);
  ReadLlmTimeoutFieldsFromForm(ConnectMs, ReadMs);
  FState.LlmConnectTimeoutMs := ConnectMs;
  FState.LlmReadTimeoutMs := ReadMs;
  WriteLlmTimeoutFieldsToForm(FState.LlmConnectTimeoutMs, FState.LlmReadTimeoutMs);
  FState.LlmHttpRetryCount := ReadLlmHttpRetryField;
  WriteLlmHttpRetryField(FState.LlmHttpRetryCount);
  FState.LlmNativeToolCalling := chkLlmNativeToolCalling.Checked;
  FState.LlmTextToolCompat := chkLlmTextToolCompat.Checked;
  FState.LlmStreamingEnabled := chkLlmStreamingEnabled.Checked;
  FState.DebuggingMode := chkDebuggingMode.Checked;
  FState.LearnMode := chkLearnMode.Checked;
  FState.AutoSummarizeContext := chkAutoSummarizeContext.Checked;
  FState.ContextWindowTokens := StrToIntDef(edtContextWindow.Text, DEFAULT_CONTEXT_WINDOW_TOKENS);
  if FState.ContextWindowTokens < 4096 then
    FState.ContextWindowTokens := DEFAULT_CONTEXT_WINDOW_TOKENS;
  FState.SummarizeThreshold := StrToFloatDef(edtSummarizeThreshold.Text, DEFAULT_SUMMARIZE_THRESHOLD);
  if FState.SummarizeThreshold <= 0 then
    FState.SummarizeThreshold := DEFAULT_SUMMARIZE_THRESHOLD;
  if FState.SummarizeThreshold > 0.98 then
    FState.SummarizeThreshold := 0.98;
  UpdateMaxTokensHint;

  FState.WorkspaceRoot := Trim(edtWorkspaceRoot.Text);
  FState.WorkspaceName := Trim(edtWorkspaceName.Text);
  SaveBrowserReadExecutablePath(Trim(edtBrowserExecutable.Text));

  SaveWebSearchTab;
  FState.PromptCacheSettings := SavePromptCacheTab;

  if Assigned(FRegistry) and FState.HasActiveWorkspace then
    FRegistry.UpdateWorkspace(FState.ActiveWorkspaceId, FState.WorkspaceName, FState.WorkspaceRoot);
end;

procedure TSettingsForm.cboProviderChange(Sender: TObject);
var
  NewProv: TLlmProvider;
begin
  if FSwitchingProvider then Exit;
  NewProv := CurrentDialogProvider;
  if NewProv = FDialogProvider then Exit;

  FlushCredentialsToState(FDialogProvider);
  FDialogProvider := NewProv;
  RefreshProviderComboItem;
  LoadProviderTab(FDialogProvider);
end;

procedure TSettingsForm.lstModelsDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
begin
  ThemedListBoxDrawItem(Control, Index, ARect, State, FCurrentTheme);
end;

procedure TSettingsForm.lstModelsClick(Sender: TObject);
var
  Idx: Integer;
  Prov: TLlmProvider;
begin
  Idx := lstModels.ItemIndex;
  if Idx < 0 then Exit;
  Prov := CurrentDialogProvider;
  if Idx >= FState.SavedModelCount(Prov) then Exit;
  FDefaultModelId := FState.GetSavedModel(Prov, Idx).ModelId;
  UpdatePromptCacheCapabilityUi;
end;

procedure TSettingsForm.ModelSearchAdd(Sender: TObject; const AModelId, ADisplayName: string);
var
  Prov: TLlmProvider;
begin
  Prov := CurrentDialogProvider;
  FState.AddSavedModel(Prov, AModelId, ADisplayName);
end;

procedure TSettingsForm.btnFetchModelsClick(Sender: TObject);
var
  Client: TLlmClient;
  ListResult: TLlmModelListResult;
  OldCursor: TCursor;
  ConnectMs, ReadMs: Integer;
begin
  if not Assigned(FState) then Exit;

  FlushCredentialsToState(FDialogProvider);

  Client := TLlmClient.Create;
  try
    Client.Provider := CurrentDialogProvider;
    Client.ApiKey := Trim(edtApiKey.Text);
    Client.BaseUrl := Trim(edtBaseUrl.Text);
    ReadLlmTimeoutFieldsFromForm(ConnectMs, ReadMs);
    Client.ConnectTimeoutMs := ConnectMs;
    Client.ReadTimeoutMs := ReadMs;
    Client.HttpRetryCount := ReadLlmHttpRetryField;

    OldCursor := Screen.Cursor;
    Screen.Cursor := crHourGlass;
    Application.ProcessMessages;
    try
      ListResult := Client.ListModels;
    finally
      Screen.Cursor := OldCursor;
    end;

    if not ListResult.Success then begin
      LcaShowMessage(ListResult.ErrorMessage, FCurrentTheme);
      Exit;
    end;

    if Length(ListResult.Models) = 0 then begin
      LcaShowMessage('No models returned by the provider.', FCurrentTheme);
      Exit;
    end;

    TModelSearchForm.ShowModalSearch(Self, FCurrentTheme, ListResult.Models, @ModelSearchAdd);
    RefreshModelList;
  finally
    Client.Free;
  end;
end;

procedure TSettingsForm.btnEditModelClick(Sender: TObject);
var
  Idx: Integer;
  Prov: TLlmProvider;
  M, NewName, NewId: string;
  Cur: TSavedModel;
begin
  Idx := lstModels.ItemIndex;
  if Idx < 0 then begin
    LcaShowMessage('Select a model to edit.', FCurrentTheme);
    Exit;
  end;
  Prov := CurrentDialogProvider;
  Cur := FState.GetSavedModel(Prov, Idx);
  if TEditSavedModelForm.Execute(Self, FCurrentTheme, Cur.DisplayName, Cur.ModelId, M, NewId) then begin
    if not FState.UpdateSavedModel(Prov, Idx, NewId, M) then begin
      LcaShowMessage('Could not update model. The model id may already exist in this provider list.',
        FCurrentTheme);
      Exit;
    end;
    if SameText(FDefaultModelId, Cur.ModelId) then
      FDefaultModelId := NewId;
    RefreshModelList;
  end;
end;

procedure TSettingsForm.btnDeleteModelClick(Sender: TObject);
var
  Idx: Integer;
  Prov: TLlmProvider;
  DelId: string;
begin
  Idx := lstModels.ItemIndex;
  if Idx < 0 then begin
    LcaShowMessage('Select a model to delete.', FCurrentTheme);
    Exit;
  end;
  Prov := CurrentDialogProvider;
  DelId := FState.GetSavedModel(Prov, Idx).ModelId;
  if LcaMessageDlg('Settings', 'Remove this model from your saved list?', mtConfirmation,
    [mbYes, mbNo], FCurrentTheme) <> mrYes then
    Exit;
  FState.DeleteSavedModel(Prov, Idx);
  if SameText(FDefaultModelId, DelId) then begin
    if FState.SavedModelCount(Prov) > 0 then
      FDefaultModelId := FState.GetSavedModel(Prov, 0).ModelId
    else
      FDefaultModelId := '';
  end;
  RefreshModelList;
end;

{ --- Web search (Tools tab) --- }

procedure TSettingsForm.wsLblToggleCheckClick(Sender: TObject);
begin
  if Sender = wsLblWebSearchEnabled then
    wsChkWebSearchEnabled.Checked := not wsChkWebSearchEnabled.Checked
  else if Sender = wsLblAutoFallback then
    wsChkAutoFallback.Checked := not wsChkAutoFallback.Checked
  else if Sender = wsLblFallbackEmpty then
    wsChkFallbackEmpty.Checked := not wsChkFallbackEmpty.Checked
  else if Sender = wsLblAllowPrivateInstances then
    wsChkAllowPrivateInstances.Checked := not wsChkAllowPrivateInstances.Checked;
end;

procedure TSettingsForm.LoadWebSearchTab;
begin
  FWebSearchConfig := LoadWebSearchConfig;
  wsChkWebSearchEnabled.Checked := FWebSearchConfig.Enabled;
  wsEdtMaxResults.Text := IntToStr(FWebSearchConfig.MaxResults);
  wsEdtTotalTimeoutSec.Text := IntToStr(FWebSearchConfig.TotalTimeoutMs div 1000);
  wsChkAutoFallback.Checked := FWebSearchConfig.AutomaticFallback;
  wsChkFallbackEmpty.Checked := FWebSearchConfig.FallbackOnEmptyResults;
  wsChkAllowPrivateInstances.Checked := FWebSearchConfig.AllowPrivateInstances;
  RefreshWebSearchConnectionList;
  if Assigned(wsMemoConnStatus) then
    wsMemoConnStatus.Clear;
end;

procedure TSettingsForm.ApplyWebSearchUiToConfig;
begin
  FWebSearchConfig.Enabled := wsChkWebSearchEnabled.Checked;
  FWebSearchConfig.MaxResults := StrToIntDef(Trim(wsEdtMaxResults.Text), WEB_SEARCH_DEFAULT_MAX_RESULTS);
  if FWebSearchConfig.MaxResults < 1 then FWebSearchConfig.MaxResults := 1;
  if FWebSearchConfig.MaxResults > 50 then FWebSearchConfig.MaxResults := 50;
  FWebSearchConfig.TotalTimeoutMs := StrToIntDef(Trim(wsEdtTotalTimeoutSec.Text), 30) * 1000;
  if FWebSearchConfig.TotalTimeoutMs < 1000 then FWebSearchConfig.TotalTimeoutMs := 1000;
  FWebSearchConfig.AutomaticFallback := wsChkAutoFallback.Checked;
  FWebSearchConfig.FallbackOnEmptyResults := wsChkFallbackEmpty.Checked;
  FWebSearchConfig.AllowPrivateInstances := wsChkAllowPrivateInstances.Checked;
end;

procedure TSettingsForm.SaveWebSearchTab;
begin
  ApplyWebSearchUiToConfig;
  SaveWebSearchConfig(FWebSearchConfig);
end;

procedure TSettingsForm.AdjustWebSearchListColumns;
var
  I, Fixed, LastW: Integer;
begin
  if wsLvConnections.Columns.Count < 2 then Exit;
  Fixed := 0;
  for I := 0 to wsLvConnections.Columns.Count - 2 do
    Fixed := Fixed + wsLvConnections.Columns[I].Width;
  LastW := wsLvConnections.ClientWidth - Fixed - 6;
  if LastW < 64 then LastW := 64;
  wsLvConnections.Columns[wsLvConnections.Columns.Count - 1].Width := LastW;
end;

procedure TSettingsForm.wsLvConnectionsResize(Sender: TObject);
begin
  AdjustWebSearchListColumns;
end;

procedure TSettingsForm.RefreshWebSearchConnectionList;
var
  I: Integer;
  Item: TListItem;
  Conn: TWebSearchConnection;
begin
  wsLvConnections.Items.Clear;
  wsLvConnections.Columns.Clear;
  with wsLvConnections.Columns.Add do begin
    Caption := 'Priority';
    Width := 64;
  end;
  with wsLvConnections.Columns.Add do begin
    Caption := 'Enabled';
    Width := 64;
  end;
  with wsLvConnections.Columns.Add do begin
    Caption := 'Name';
    Width := 180;
  end;
  with wsLvConnections.Columns.Add do begin
    Caption := 'Provider';
    Width := 100;
  end;
  for I := 0 to High(FWebSearchConfig.Connections) do begin
    Conn := FWebSearchConfig.Connections[I];
    Item := wsLvConnections.Items.Add;
    Item.Caption := IntToStr(Conn.Priority);
    Item.SubItems.Add(IfThen(Conn.Enabled, 'Yes', 'No'));
    Item.SubItems.Add(Conn.Name);
    Item.SubItems.Add(WebSearchProviderDisplayName(Conn.Kind));
    Item.Data := Pointer(I);
  end;
  AdjustWebSearchListColumns;
end;

function TSettingsForm.WebSearchSelectedConnectionIndex: Integer;
begin
  if wsLvConnections.Selected = nil then Exit(-1);
  Result := Integer(wsLvConnections.Selected.Data);
end;

procedure TSettingsForm.RenumberWebSearchPriorities;
var
  I: Integer;
begin
  for I := 0 to High(FWebSearchConfig.Connections) do
    FWebSearchConfig.Connections[I].Priority := I + 1;
end;

procedure TSettingsForm.wsBtnAddConnClick(Sender: TObject);
var
  Conn, OutConn: TWebSearchConnection;
  Key: string;
  ApiKeyChanged: Boolean;
begin
  FillChar(Conn, SizeOf(Conn), 0);
  Conn.Id := NewWebSearchConnectionId;
  Conn.Name := 'New connection';
  Conn.Kind := wspkBrave;
  Conn.Enabled := True;
  Conn.TimeoutMs := WEB_SEARCH_DEFAULT_CONNECTION_TIMEOUT_MS;
  Conn.Priority := Length(FWebSearchConfig.Connections) + 1;
  if TWebSearchConnectionForm.Execute(Self, FCurrentTheme, Conn, True, OutConn, Key, ApiKeyChanged) then begin
    SetLength(FWebSearchConfig.Connections, Length(FWebSearchConfig.Connections) + 1);
    FWebSearchConfig.Connections[High(FWebSearchConfig.Connections)] := OutConn;
    if ApiKeyChanged then
      SetWebSearchApiKey(OutConn.Id, Key);
    RenumberWebSearchPriorities;
    RefreshWebSearchConnectionList;
  end;
end;

procedure TSettingsForm.wsBtnEditConnClick(Sender: TObject);
var
  Idx: Integer;
  OutConn: TWebSearchConnection;
  Key: string;
  ApiKeyChanged: Boolean;
begin
  Idx := WebSearchSelectedConnectionIndex;
  if Idx < 0 then Exit;
  if TWebSearchConnectionForm.Execute(Self, FCurrentTheme, FWebSearchConfig.Connections[Idx], False,
    OutConn, Key, ApiKeyChanged) then begin
    FWebSearchConfig.Connections[Idx] := OutConn;
    if ApiKeyChanged then
      SetWebSearchApiKey(OutConn.Id, Key);
    RefreshWebSearchConnectionList;
  end;
end;

procedure TSettingsForm.wsBtnRemoveConnClick(Sender: TObject);
var
  Idx, I, J: Integer;
begin
  Idx := WebSearchSelectedConnectionIndex;
  if Idx < 0 then Exit;
  if LcaMessageDlg('Web Search', 'Remove connection "' + FWebSearchConfig.Connections[Idx].Name + '"?',
    mtConfirmation, [mbYes, mbNo], FCurrentTheme) <> mrYes then Exit;
  ClearWebSearchApiKey(FWebSearchConfig.Connections[Idx].Id);
  J := 0;
  for I := 0 to High(FWebSearchConfig.Connections) do
    if I <> Idx then begin
      FWebSearchConfig.Connections[J] := FWebSearchConfig.Connections[I];
      Inc(J);
    end;
  SetLength(FWebSearchConfig.Connections, J);
  RenumberWebSearchPriorities;
  RefreshWebSearchConnectionList;
end;

procedure TSettingsForm.wsBtnTestConnClick(Sender: TObject);
var
  Idx: Integer;
  TestRes: TConnectionTestResult;
  Transport: IWebSearchTransport;
  Line, PopupText, ConnName: string;
begin
  Idx := WebSearchSelectedConnectionIndex;
  if Idx < 0 then begin
    LcaMessageDlg('Web Search', 'Select a connection to test.', mtWarning, [mbOK], FCurrentTheme);
    Exit;
  end;
  ConnName := FWebSearchConfig.Connections[Idx].Name;
  ApplyWebSearchUiToConfig;
  wsMemoConnStatus.Lines.Add('Testing "' + ConnName + '"...');
  Transport := TWebSearchProductionTransport.Create;
  TestRes := TestWebSearchConnection(FWebSearchConfig, FWebSearchConfig.Connections[Idx].Id, Transport, nil);
  if TestRes.Success then begin
    Line := Format('%s: OK (%d ms, %d results)',
      [ConnName, TestRes.ResponseTimeMs, TestRes.ResultCount]);
    PopupText := Format('Connection "%s" passed.' + LineEnding + LineEnding +
      'Response time: %d ms' + LineEnding + 'Results: %d',
      [ConnName, TestRes.ResponseTimeMs, TestRes.ResultCount]);
    LcaMessageDlg('Web Search', PopupText, mtInformation, [mbOK], FCurrentTheme);
  end else begin
    Line := Format('%s: Failed (%s) %s',
      [ConnName, TestRes.ErrorCode, TestRes.ErrorMessage]);
    PopupText := 'Connection "' + ConnName + '" failed.' + LineEnding + LineEnding;
    if Trim(TestRes.ErrorCode) <> '' then
      PopupText := PopupText + TestRes.ErrorCode;
    if Trim(TestRes.ErrorMessage) <> '' then begin
      if Trim(TestRes.ErrorCode) <> '' then
        PopupText := PopupText + LineEnding;
      PopupText := PopupText + TestRes.ErrorMessage;
    end;
    LcaMessageDlg('Web Search', PopupText, mtError, [mbOK], FCurrentTheme);
  end;
  wsMemoConnStatus.Lines.Add(Line);
end;

procedure TSettingsForm.wsBtnMoveUpClick(Sender: TObject);
var
  Idx: Integer;
  Tmp: TWebSearchConnection;
begin
  Idx := WebSearchSelectedConnectionIndex;
  if (Idx <= 0) or (Idx > High(FWebSearchConfig.Connections)) then Exit;
  Tmp := FWebSearchConfig.Connections[Idx - 1];
  FWebSearchConfig.Connections[Idx - 1] := FWebSearchConfig.Connections[Idx];
  FWebSearchConfig.Connections[Idx] := Tmp;
  RenumberWebSearchPriorities;
  RefreshWebSearchConnectionList;
  if Idx - 1 < wsLvConnections.Items.Count then
    wsLvConnections.Items[Idx - 1].Selected := True;
end;

procedure TSettingsForm.wsBtnMoveDownClick(Sender: TObject);
var
  Idx: Integer;
  Tmp: TWebSearchConnection;
begin
  Idx := WebSearchSelectedConnectionIndex;
  if (Idx < 0) or (Idx >= High(FWebSearchConfig.Connections)) then Exit;
  Tmp := FWebSearchConfig.Connections[Idx + 1];
  FWebSearchConfig.Connections[Idx + 1] := FWebSearchConfig.Connections[Idx];
  FWebSearchConfig.Connections[Idx] := Tmp;
  RenumberWebSearchPriorities;
  RefreshWebSearchConnectionList;
  if Idx + 1 < wsLvConnections.Items.Count then
    wsLvConnections.Items[Idx + 1].Selected := True;
end;

{ --- Prompt cache (Performance tab) --- }

procedure TSettingsForm.pcLblToggleCheckClick(Sender: TObject);
begin
  if Sender = pcLblEnabled then
    pcChkEnabled.Checked := not pcChkEnabled.Checked
  else if Sender = pcLblChkSystem then
    pcChkSystem.Checked := not pcChkSystem.Checked
  else if Sender = pcLblChkTools then
    pcChkTools.Checked := not pcChkTools.Checked
  else if Sender = pcLblChkProject then
    pcChkProject.Checked := not pcChkProject.Checked
  else if Sender = pcLblChkHistory then
    pcChkHistory.Checked := not pcChkHistory.Checked;
end;

procedure TSettingsForm.pcLblSelectRadioClick(Sender: TObject);
begin
  if Sender = pcLblRbAutomatic then
    pcRbAutomatic.Checked := True
  else if Sender = pcLblRbExplicit then
    pcRbExplicit.Checked := True
  else if Sender = pcLblRbDisabled then
    pcRbDisabled.Checked := True;
end;

procedure TSettingsForm.UpdatePromptCacheCapabilityUi;
var
  Wire: TLlmWireFormat;
  Caps: TPromptCacheCapabilities;
  BaseUrl, Model: string;
begin
  if not Assigned(FState) then Exit;
  BaseUrl := Trim(edtBaseUrl.Text);
  Model := FDefaultModelId;
  Wire := ResolveLlmWireFormat(FDialogProvider, BaseUrl, Model);
  Caps := ResolveCacheCapabilities(FDialogProvider, BaseUrl, Model, Wire);
  pcRbExplicit.Enabled := Caps.SupportsExplicitCaching;
  pcCboRetention.Enabled := Caps.SupportsRetentionControl;
  if not pcRbExplicit.Enabled and pcRbExplicit.Checked then
    pcRbAutomatic.Checked := True;
  RefreshPromptCacheStats;
end;

procedure TSettingsForm.RefreshPromptCacheStats;
var
  Snap: TPromptCacheStatsSnapshot;
  Ratio: Double;
begin
  Snap := GlobalPromptCacheStats.Snapshot;
  if Snap.MetricsKnownRequestCount = 0 then begin
    pcLblInputTokens.Caption := 'Input tokens: —';
    pcLblCachedTokens.Caption := 'Cached read tokens: —';
    pcLblHitRatio.Caption := 'Cache hit ratio: —';
  end else begin
    pcLblInputTokens.Caption := Format('Input tokens: %d', [Snap.TotalInputTokens]);
    pcLblCachedTokens.Caption := Format('Cached read tokens: %d', [Snap.TotalCachedReadTokens]);
    Ratio := GlobalPromptCacheStats.CacheHitRatio(Snap);
    if Ratio < 0 then
      pcLblHitRatio.Caption := 'Cache hit ratio: —'
    else
      pcLblHitRatio.Caption := Format('Cache hit ratio: %.1f%%', [Ratio]);
  end;
  pcLblSavings.Caption := 'Estimated savings: Provider-dependent';
end;

procedure TSettingsForm.LoadPromptCacheTab(const ASettings: TPromptCacheSettings);
begin
  case ASettings.Mode of
    pcmDisabled: pcRbDisabled.Checked := True;
    pcmExplicit: pcRbExplicit.Checked := True;
  else
    pcRbAutomatic.Checked := True;
  end;
  pcChkEnabled.Checked := ASettings.Mode <> pcmDisabled;
  pcCboRetention.ItemIndex := Ord(ASettings.Retention);
  pcChkSystem.Checked := ASettings.CacheSystemInstructions;
  pcChkTools.Checked := ASettings.CacheToolDefinitions;
  pcChkProject.Checked := ASettings.CacheProjectContext;
  pcChkHistory.Checked := ASettings.CacheConversationHistory;
end;

function TSettingsForm.SavePromptCacheTab: TPromptCacheSettings;
begin
  Result := DefaultPromptCacheSettings;
  if not pcChkEnabled.Checked then
    Result.Mode := pcmDisabled
  else if pcRbExplicit.Checked then
    Result.Mode := pcmExplicit
  else if pcRbDisabled.Checked then
    Result.Mode := pcmDisabled
  else
    Result.Mode := pcmAutomatic;
  if (pcCboRetention.ItemIndex >= Ord(Low(TPromptCacheRetention))) and
     (pcCboRetention.ItemIndex <= Ord(High(TPromptCacheRetention))) then
    Result.Retention := TPromptCacheRetention(pcCboRetention.ItemIndex);
  Result.CacheSystemInstructions := pcChkSystem.Checked;
  Result.CacheToolDefinitions := pcChkTools.Checked;
  Result.CacheProjectContext := pcChkProject.Checked;
  Result.CacheConversationHistory := pcChkHistory.Checked;
end;

procedure TSettingsForm.pcBtnResetStatsClick(Sender: TObject);
begin
  GlobalPromptCacheStats.Reset;
  RefreshPromptCacheStats;
end;

procedure TSettingsForm.btnBrowseWorkspaceClick(Sender: TObject);
var
  Dir: string;
begin
  Dir := edtWorkspaceRoot.Text;
  if SelectDirectory('Select Workspace Directory', '', Dir) then begin
    edtWorkspaceRoot.Text := Dir;
    if edtWorkspaceName.Text = '' then
      edtWorkspaceName.Text := ExtractFileName(Dir);
  end;
end;

procedure TSettingsForm.btnOKClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TSettingsForm.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
