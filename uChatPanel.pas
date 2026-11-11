unit uChatPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, StdCtrls, Graphics, Dialogs, Forms, Buttons,
  LCLType, Clipbrd, fpjson, jsonparser,
  uAppTypes, LcaTheme, LcaPaintButton, LcaPaintComboBox, LcaThemedMessageBox, uAgentTypes,
  uWorkspaceState,
  LcaMarkdownView;

const
  CHAT_HISTORY_REFRESH_MIN_MS = 200;

type
  TPromptEvent = procedure(Sender: TObject; const APrompt: string;
    const AAttachments: array of TChatAttachment; AMode: TWorkspaceMode;
    const AModel: string) of object;
  TModeChangeEvent = procedure(Sender: TObject; AMode: TWorkspaceMode) of object;
  TModelChangeEvent = procedure(Sender: TObject; const AModel: string) of object;
  TCancelEvent = procedure(Sender: TObject) of object;

  { Binds designer-placed chat controls; Markdown subset in TLcaMarkdownView on host panel. }
  TChatPanel = class(TComponent)
  private
    FWorkspaceName: string;
    FTheme: TThemeKind;
    FMode: TWorkspaceMode;
    FModel: string;
    FIsRunning: Boolean;
    FHistoryText: string;
    FHistoryRefreshQueued: Boolean;
    FHistoryScrollToEndPending: Boolean;
    FHistoryRefreshDueTick: QWord;
    FHistoryRefreshThrottleQueued: Boolean;
    FLastAppendWasTrace: Boolean;
    FEphemeralThinkingActive: Boolean;
    FBatchHistoryReload: Boolean;
    FHistoryViewSyncedLen: Integer;

    FOnPrompt: TPromptEvent;
    FOnModeChange: TModeChangeEvent;
    FOnModelChange: TModelChangeEvent;
    FOnCancel: TCancelEvent;

    FHeading: TLabel;
    FSubHeading: TLabel;
    FSessionLabel: TLabel;
    FHistoryHost: TPanel;
    FHistoryView: TLcaMarkdownView;
    FWorkspaceTag: TLabel;
    FPromptMemo: TMemo;
    FModeCombo: TLcaPaintComboBox;
    FModelCombo: TLcaPaintComboBox;
    FModelIds: TStringList;
    FSendBtn: TLcaPaintButton;
    FStopBtn: TLcaPaintButton;
    FAttachBtn: TLcaPaintButton;
    FAttachmentStrip: TPanel;
    FAllowModifyOutsideCheck: TCheckBox;
    FAllowModifyOutsideLabel: TLabel;
    FUpdatingAllowModifyOutside: Boolean;

    FSessionId: string;
    FPendingImagePaths: TStringList;
    FOpenImageDialog: TOpenDialog;

    procedure ModeComboChange(Sender: TObject);
    procedure ModelComboChange(Sender: TObject);
    procedure SendBtnClick(Sender: TObject);
    procedure StopBtnClick(Sender: TObject);
    procedure AttachBtnClick(Sender: TObject);
    procedure PromptMemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PendingRemoveClick(Sender: TObject);
    function TryAddPendingImagePath(const APath: string): Boolean;
    procedure ClearPendingImages;
    procedure RefreshAttachmentStrip;
    function FinalizeAttachmentsForSend(out AAttachments: TChatAttachmentArray): string;
    function FormatUserMessageBody(const AMsg: TChatMessage): string;
    function FilePathToFileUrl(const APath: string): string;
    procedure UpdateHeading;
    procedure UpdateSessionLabel(const ACaption: string);
    procedure InitWelcomeText;
    procedure EnsureHistoryView;
    procedure AppendToHistory(const ARoleLabel, ABody: string);
    procedure ApplyHistoryViewNow(AScrollToEnd: Boolean);
    procedure ScheduleHistoryRefresh;
    procedure ScheduleThrottledHistoryRefresh;
    procedure DeferredHistoryRefresh(Data: PtrInt);
    procedure DeferredThrottledHistoryRefresh(Data: PtrInt);
    procedure FlushHistoryView;
    procedure RefreshHistoryView;
    function ToolMessageBody(const AMsg: TChatMessage): string;
    procedure RemoveEphemeralThinkingLine;
    procedure AppendTraceLineWithPrefix(const APrefix, AText: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Bind(AHeading, ASubHeading, ASessionLabel: TLabel; AHistoryHost: TPanel;
      APrompt: TMemo; AWorkspaceTag: TLabel; AModeCombo, AModelCombo: TLcaPaintComboBox;
      ASendBtn, AStopBtn, AAttachBtn: TLcaPaintButton; AAttachmentStrip: TPanel;
      AAllowModifyOutside: TCheckBox; AAllowModifyOutsideLabel: TLabel = nil);
    procedure SetAllowModifyOutsideChecked(AValue: Boolean);
    function GetAllowModifyOutsideChecked: Boolean;
    procedure SetSessionId(const ASessionId: string);
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure ApplyPlatformChrome(ATheme: TThemeKind);
    procedure SetWorkspace(const AName: string);
    procedure SetSessionCaption(const ACaption: string);
    procedure SetMode(AMode: TWorkspaceMode);
    procedure SetModel(const AModel: string);
    procedure SetAvailableModels(const AModels: array of TSavedModel);
    procedure SetRunning(ARunning: Boolean);

    procedure AppendMessage(const AMsg: TChatMessage);
    procedure AppendToolMessage(const AMsg: TChatMessage; ADebuggingMode: Boolean);
    procedure AppendText(const AText: string);
    procedure AppendTraceLine(const AText: string);
    procedure AppendToolActivityLine(const AToolName, AArgsJson: string);
    procedure SetAgentThinkingInChat(AVisible: Boolean);
    procedure ClearHistory;
    procedure ReloadFromMessages(const AMessages: TChatMessageArray; ADebuggingMode: Boolean);
    procedure SetComposerEnabled(AEnabled: Boolean);
    procedure SubmitPrompt(const APrompt: string);

    property Mode: TWorkspaceMode read FMode write SetMode;
    property Model: string read FModel write SetModel;
    property IsRunning: Boolean read FIsRunning write SetRunning;
    property OnModeChange: TModeChangeEvent read FOnModeChange write FOnModeChange;
    property OnModelChange: TModelChangeEvent read FOnModelChange write FOnModelChange;
    property OnPrompt: TPromptEvent read FOnPrompt write FOnPrompt;
    property OnCancel: TCancelEvent read FOnCancel write FOnCancel;
  end;

implementation

uses
  uChatImageStore, uAgentExecutionLog;

const
  MaxToolBodyInChat = 1200;
  ChatTracePrefixTool = '@tool ';
  ChatTracePrefixThinking = '@think ';
  ChatThinkingTraceText = 'Thinking...';

function ExtractToolErrorLine(const AJson: string): string;
var
  Data: TJSONData;
  Obj: TJSONObject;
begin
  Result := '';
  try
    Data := GetJSON(AJson);
    try
      if Data is TJSONObject then begin
        Obj := TJSONObject(Data);
        Result := Obj.Get('error', '');
        if Result = '' then
          Result := Obj.Get('message', '');
      end;
    finally
      Data.Free;
    end;
  except
    Result := '';
  end;
end;

function ModelComboCaption(const M: TSavedModel): string;
begin
  if (Trim(M.DisplayName) <> '') and not SameText(M.DisplayName, M.ModelId) then
    Result := M.DisplayName
  else
    Result := M.ModelId;
end;

constructor TChatPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTheme := tkDark;
  FWorkspaceName := 'LazyCodingAgent';
  FMode := wmAgent;
  FModel := '';
  FModelIds := TStringList.Create;
  FPendingImagePaths := TStringList.Create;
  FOpenImageDialog := TOpenDialog.Create(nil);
  FOpenImageDialog.Title := 'Attach image';
  FOpenImageDialog.Filter :=
    'Images|*.png;*.jpg;*.jpeg;*.webp;*.gif|PNG (*.png)|*.png|JPEG (*.jpg)|*.jpg;*.jpeg';
  FOpenImageDialog.Options := [ofFileMustExist, ofHideReadOnly];
  FHistoryViewSyncedLen := 0;
  InitWelcomeText;
end;

destructor TChatPanel.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  FHistoryView := nil;
  FOpenImageDialog.Free;
  FPendingImagePaths.Free;
  FModelIds.Free;
  inherited Destroy;
end;

procedure TChatPanel.EnsureHistoryView;
var
  I: Integer;
  C: TControl;
  OwnerComp: TComponent;
begin
  if Assigned(FHistoryView) then Exit;
  if not Assigned(FHistoryHost) then Exit;
  for I := 0 to FHistoryHost.ControlCount - 1 do begin
    C := FHistoryHost.Controls[I];
    if C is TLcaMarkdownView then begin
      FHistoryView := TLcaMarkdownView(C);
      Exit;
    end;
  end;
  if FHistoryHost.Owner is TComponent then
    OwnerComp := TComponent(FHistoryHost.Owner)
  else
    OwnerComp := Self;
  FHistoryView := TLcaMarkdownView.Create(OwnerComp);
  FHistoryView.Parent := FHistoryHost;
  FHistoryView.Align := alClient;
  FHistoryView.ApplyTheme(FTheme);
end;

procedure TChatPanel.Bind(AHeading, ASubHeading, ASessionLabel: TLabel; AHistoryHost: TPanel;
  APrompt: TMemo; AWorkspaceTag: TLabel; AModeCombo, AModelCombo: TLcaPaintComboBox;
  ASendBtn, AStopBtn, AAttachBtn: TLcaPaintButton; AAttachmentStrip: TPanel;
  AAllowModifyOutside: TCheckBox; AAllowModifyOutsideLabel: TLabel);
var
  M: TWorkspaceMode;
begin
  FHeading := AHeading;
  FSubHeading := ASubHeading;
  FSessionLabel := ASessionLabel;
  FHistoryHost := AHistoryHost;
  FPromptMemo := APrompt;
  FWorkspaceTag := AWorkspaceTag;
  FModeCombo := AModeCombo;
  FModelCombo := AModelCombo;
  FSendBtn := ASendBtn;
  FStopBtn := AStopBtn;
  FAttachBtn := AAttachBtn;
  FAttachmentStrip := AAttachmentStrip;
  FAllowModifyOutsideCheck := AAllowModifyOutside;
  FAllowModifyOutsideLabel := AAllowModifyOutsideLabel;

  EnsureHistoryView;

  if Assigned(FModeCombo) then begin
    FModeCombo.Items.Clear;
    for M := Low(TWorkspaceMode) to High(TWorkspaceMode) do
      FModeCombo.Items.Add(WorkspaceModeCaption(M));
    FModeCombo.ItemIndex := Ord(FMode);
    FModeCombo.OnChange := @ModeComboChange;
  end;
  if Assigned(FModelCombo) then begin
    FModelCombo.OnChange := @ModelComboChange;
  end;
  if Assigned(FSendBtn) then
    FSendBtn.OnClick := @SendBtnClick;
  if Assigned(FStopBtn) then begin
    FStopBtn.OnClick := @StopBtnClick;
    FStopBtn.Visible := False;
  end;
  if Assigned(FAttachBtn) then
    FAttachBtn.OnClick := @AttachBtnClick;
  if Assigned(FPromptMemo) then
    FPromptMemo.OnKeyDown := @PromptMemoKeyDown;

  UpdateHeading;
  RefreshHistoryView;
  RefreshAttachmentStrip;
end;

procedure TChatPanel.SetSessionId(const ASessionId: string);
begin
  FSessionId := ASessionId;
end;

function TChatPanel.FilePathToFileUrl(const APath: string): string;
begin
  Result := 'file:///' + StringReplace(ExpandFileName(APath), '\', '/', [rfReplaceAll]);
end;

function TChatPanel.TryAddPendingImagePath(const APath: string): Boolean;
var
  Expanded: string;
begin
  Result := False;
  Expanded := ExpandFileName(Trim(APath));
  if not FileExists(Expanded) then Exit;
  if not IsAllowedImageFileName(Expanded) then begin
    LcaShowMessage('Unsupported image type (use PNG, JPEG, WebP, or GIF).', FTheme);
    Exit;
  end;
  if FPendingImagePaths.Count >= CHAT_IMAGE_MAX_COUNT then begin
    LcaShowMessage(Format('At most %d images per message.', [CHAT_IMAGE_MAX_COUNT]), FTheme);
    Exit;
  end;
  if FPendingImagePaths.IndexOf(Expanded) >= 0 then
    Exit(True);
  FPendingImagePaths.Add(Expanded);
  RefreshAttachmentStrip;
  Result := True;
end;

procedure TChatPanel.ClearPendingImages;
begin
  FPendingImagePaths.Clear;
  RefreshAttachmentStrip;
end;

procedure TChatPanel.RefreshAttachmentStrip;
var
  I, X: Integer;
  Btn: TSpeedButton;
  P: TThemePalette;
begin
  if not Assigned(FAttachmentStrip) then Exit;
  while FAttachmentStrip.ControlCount > 0 do
    FAttachmentStrip.Controls[0].Free;
  if FPendingImagePaths.Count = 0 then begin
    FAttachmentStrip.Visible := False;
    Exit;
  end;
  FAttachmentStrip.Visible := True;
  P := ThemePalette(FTheme);
  FAttachmentStrip.Color := P.Surface;
  X := 4;
  for I := 0 to FPendingImagePaths.Count - 1 do begin
    Btn := TSpeedButton.Create(FAttachmentStrip);
    Btn.Parent := FAttachmentStrip;
    Btn.Left := X;
    Btn.Top := 4;
    Btn.Height := 28;
    Btn.Caption := ExtractFileName(FPendingImagePaths[I]) + '  x';
    Btn.Tag := I;
    Btn.Flat := True;
    Btn.Font.Color := P.Text;
    Btn.OnClick := @PendingRemoveClick;
    Btn.ShowHint := True;
    Btn.Hint := FPendingImagePaths[I];
    Inc(X, Btn.Width + 6);
  end;
end;

procedure TChatPanel.PendingRemoveClick(Sender: TObject);
var
  Idx: Integer;
begin
  if not (Sender is TSpeedButton) then Exit;
  Idx := TSpeedButton(Sender).Tag;
  if (Idx >= 0) and (Idx < FPendingImagePaths.Count) then begin
    FPendingImagePaths.Delete(Idx);
    RefreshAttachmentStrip;
  end;
end;

procedure TChatPanel.AttachBtnClick(Sender: TObject);
begin
  if FIsRunning then Exit;
  if not Assigned(FOpenImageDialog) then Exit;
  if FOpenImageDialog.Execute then
    TryAddPendingImagePath(FOpenImageDialog.FileName);
end;

procedure TChatPanel.PromptMemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  TempPath: string;
  Pic: TPicture;
begin
  if FIsRunning then Exit;
  if not (Key = VK_V) then Exit;
  if not (ssCtrl in Shift) then Exit;
  if not (Clipboard.HasFormat(CF_Picture) or Clipboard.HasFormat(CF_BITMAP)) then Exit;

  TempPath := IncludeTrailingPathDelimiter(GetTempDir) +
    'lca-paste-' + IntToHex(GetTickCount64, 16) + '.png';
  Pic := TPicture.Create;
  try
    try
      Pic.Assign(Clipboard);
      Pic.SaveToFile(TempPath);
      if TryAddPendingImagePath(TempPath) then
        Key := 0;
    except
      on E: Exception do
        LcaShowMessage('Could not paste image: ' + E.Message, FTheme);
    end;
  finally
    Pic.Free;
  end;
end;

function TChatPanel.FinalizeAttachmentsForSend(out AAttachments: TChatAttachmentArray): string;
var
  I: Integer;
  Att: TChatAttachment;
begin
  Result := '';
  AAttachments := nil;
  SetLength(AAttachments, 0);
  if FPendingImagePaths.Count = 0 then Exit;
  if Trim(FSessionId) = '' then begin
    Result := 'No active chat session for image attachment.';
    Exit;
  end;
  SetLength(AAttachments, FPendingImagePaths.Count);
  for I := 0 to FPendingImagePaths.Count - 1 do begin
    Result := ImportImageToSidecar(FPendingImagePaths[I], FSessionId, Att);
    if Result <> '' then begin
      SetLength(AAttachments, 0);
      Exit;
    end;
    AAttachments[I] := Att;
  end;
end;

function TChatPanel.FormatUserMessageBody(const AMsg: TChatMessage): string;
var
  I: Integer;
  AbsPath, Url, Alt: string;
  Parts: TStringList;
begin
  Parts := TStringList.Create;
  try
    if Trim(AMsg.Content) <> '' then
      Parts.Add(AMsg.Content);
    for I := 0 to High(AMsg.Attachments) do begin
      AbsPath := AttachmentAbsolutePath(AMsg.Attachments[I].RelativePath);
      Url := FilePathToFileUrl(AbsPath);
      if AMsg.Attachments[I].OriginalName <> '' then
        Alt := AMsg.Attachments[I].OriginalName
      else
        Alt := ExtractFileName(AbsPath);
      Parts.Add('![' + Alt + '](' + Url + ')');
    end;
    Result := Parts.Text;
    Result := Trim(Result);
  finally
    Parts.Free;
  end;
end;

procedure TChatPanel.InitWelcomeText;
begin
  FHistoryText :=
    '# Welcome to LazyCodingAgent!' + LineEnding + LineEnding +
    'Type a prompt below or pick a mode (Ask, Plan, Agent) to start building.';
  FLastAppendWasTrace := False;
end;

procedure TChatPanel.UpdateHeading;
begin
  if Assigned(FHeading) then
    FHeading.Caption := Format('What should we build in %s?', [FWorkspaceName]);
  if Assigned(FWorkspaceTag) then
    FWorkspaceTag.Caption := Format('PROJECT: %s  •  MODE: %s', [FWorkspaceName, WorkspaceModeCaption(FMode)]);
end;

procedure TChatPanel.UpdateSessionLabel(const ACaption: string);
begin
  if Assigned(FSessionLabel) then
    FSessionLabel.Caption := ACaption;
end;

procedure TChatPanel.SetSessionCaption(const ACaption: string);
begin
  UpdateSessionLabel(ACaption);
end;

procedure TChatPanel.SetRunning(ARunning: Boolean);
begin
  if (not ARunning) and FIsRunning then
    FlushHistoryView;
  FIsRunning := ARunning;
  if Assigned(FStopBtn) then
    FStopBtn.Visible := ARunning;
  if Assigned(FSendBtn) then
    FSendBtn.Enabled := not ARunning;
  SetComposerEnabled(FPromptMemo.Enabled);
end;

procedure TChatPanel.ApplyHistoryViewNow(AScrollToEnd: Boolean);
var
  Delta: string;
begin
  EnsureHistoryView;
  if not Assigned(FHistoryView) then Exit;
  if (FHistoryViewSyncedLen <= 0) or (FHistoryViewSyncedLen > Length(FHistoryText)) then begin
    FHistoryView.SetMarkdown(FHistoryText, AScrollToEnd);
    FHistoryViewSyncedLen := Length(FHistoryText);
    if FEphemeralThinkingActive then
      FHistoryView.SetEphemeralThinkingVisible(True);
  end else if FHistoryViewSyncedLen < Length(FHistoryText) then begin
    Delta := Copy(FHistoryText, FHistoryViewSyncedLen + 1, MaxInt);
    FHistoryView.AppendMarkdownTail(Delta, AScrollToEnd);
    FHistoryViewSyncedLen := Length(FHistoryText);
    if FEphemeralThinkingActive then
      FHistoryView.SetEphemeralThinkingVisible(True);
  end else if AScrollToEnd then
    FHistoryView.ScrollToEndIfAutoScroll;
  FHistoryRefreshDueTick := GetTickCount64 + CHAT_HISTORY_REFRESH_MIN_MS;
end;

procedure TChatPanel.ScheduleThrottledHistoryRefresh;
begin
  if FHistoryRefreshThrottleQueued then Exit;
  if csDestroying in ComponentState then Exit;
  FHistoryRefreshThrottleQueued := True;
  Application.QueueAsyncCall(@DeferredThrottledHistoryRefresh, PtrInt(Self));
end;

procedure TChatPanel.DeferredThrottledHistoryRefresh(Data: PtrInt);
begin
  FHistoryRefreshThrottleQueued := False;
  if PtrInt(Self) <> Data then Exit;
  if csDestroying in ComponentState then Exit;
  if GetTickCount64 < FHistoryRefreshDueTick then begin
    ScheduleThrottledHistoryRefresh;
    Exit;
  end;
  ScheduleHistoryRefresh;
end;

procedure TChatPanel.ScheduleHistoryRefresh;
begin
  if FHistoryRefreshQueued then Exit;
  if csDestroying in ComponentState then Exit;
  if FIsRunning and (FHistoryRefreshDueTick <> 0) and (GetTickCount64 < FHistoryRefreshDueTick) then begin
    ScheduleThrottledHistoryRefresh;
    Exit;
  end;
  FHistoryRefreshQueued := True;
  Application.QueueAsyncCall(@DeferredHistoryRefresh, PtrInt(Self));
end;

procedure TChatPanel.DeferredHistoryRefresh(Data: PtrInt);
var
  Scroll: Boolean;
begin
  FHistoryRefreshQueued := False;
  if PtrInt(Self) <> Data then Exit;
  if csDestroying in ComponentState then Exit;
  Scroll := FHistoryScrollToEndPending;
  FHistoryScrollToEndPending := False;
  ApplyHistoryViewNow(Scroll);
end;

procedure TChatPanel.FlushHistoryView;
begin
  FHistoryRefreshThrottleQueued := False;
  FHistoryRefreshQueued := False;
  FHistoryRefreshDueTick := 0;
  ApplyHistoryViewNow(FHistoryScrollToEndPending);
  FHistoryScrollToEndPending := False;
end;

procedure TChatPanel.RefreshHistoryView;
begin
  if FBatchHistoryReload then Exit;
  FHistoryScrollToEndPending := FIsRunning;
  ScheduleHistoryRefresh;
end;

procedure TChatPanel.RemoveEphemeralThinkingLine;
var
  Marker: string;
begin
  if not FEphemeralThinkingActive then Exit;
  EnsureHistoryView;
  if Assigned(FHistoryView) then
    FHistoryView.SetEphemeralThinkingVisible(False);
  FEphemeralThinkingActive := False;
  Marker := ChatTracePrefixThinking + ChatThinkingTraceText;
  if (Length(FHistoryText) >= Length(Marker)) and
     (Copy(FHistoryText, Length(FHistoryText) - Length(Marker) + 1, Length(Marker)) = Marker) then begin
    SetLength(FHistoryText, Length(FHistoryText) - Length(Marker));
    if (Length(FHistoryText) >= Length(LineEnding)) and
       (Copy(FHistoryText, Length(FHistoryText) - Length(LineEnding) + 1, Length(LineEnding)) = LineEnding) then
      SetLength(FHistoryText, Length(FHistoryText) - Length(LineEnding));
    FHistoryViewSyncedLen := 0;
  end;
end;

procedure TChatPanel.AppendTraceLineWithPrefix(const APrefix, AText: string);
var
  Line: string;
begin
  Line := Trim(AText);
  if Line = '' then Exit;
  if FHistoryText <> '' then begin
    if FLastAppendWasTrace then
      FHistoryText := FHistoryText + LineEnding
    else
      FHistoryText := FHistoryText + LineEnding + LineEnding;
  end;
  FHistoryText := FHistoryText + APrefix + Line;
  FLastAppendWasTrace := True;
  RefreshHistoryView;
end;

procedure TChatPanel.AppendToHistory(const ARoleLabel, ABody: string);
begin
  if Trim(ABody) = '' then Exit;
  RemoveEphemeralThinkingLine;
  if FHistoryText <> '' then
    FHistoryText := FHistoryText + LineEnding + LineEnding;
  FHistoryText := FHistoryText + '### ' + ARoleLabel + LineEnding + LineEnding + ABody;
  FLastAppendWasTrace := False;
  RefreshHistoryView;
end;

function TChatPanel.ToolMessageBody(const AMsg: TChatMessage): string;
var
  ErrLine: string;
  ResultText: string;
begin
  ResultText := Trim(AMsg.Content);
  if (Length(ResultText) > MaxToolBodyInChat) or
     ((Length(ResultText) > 80) and (Pos('"error"', LowerCase(ResultText)) > 0)) then begin
    ErrLine := ExtractToolErrorLine(ResultText);
    if ErrLine <> '' then
      Result := ErrLine
    else if Length(ResultText) > MaxToolBodyInChat then
      Result := Copy(ResultText, 1, MaxToolBodyInChat) + '…'
    else if AMsg.VisualSummary <> '' then
      Result := AMsg.VisualSummary
    else
      Result := ResultText;
  end else
    Result := ResultText;
end;

procedure TChatPanel.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(FTheme);
  if Assigned(FHeading) then
    FHeading.Font.Color := P.Text;
  if Assigned(FSubHeading) then
    FSubHeading.Font.Color := P.TextMuted;
  if Assigned(FSessionLabel) then
    FSessionLabel.Font.Color := P.TextMuted;
  EnsureHistoryView;
  if Assigned(FHistoryView) then begin
    FHistoryView.ApplyTheme(ATheme);
    FHistoryViewSyncedLen := 0;
    ApplyHistoryViewNow(False);
  end;
  if Assigned(FHistoryHost) then
    FHistoryHost.Color := P.Surface;
  if Assigned(FWorkspaceTag) then
    FWorkspaceTag.Font.Color := P.Accent;
  if Assigned(FPromptMemo) then
    ConfigureThemedMemo(FPromptMemo, ATheme);
  if Assigned(FModeCombo) then
    FModeCombo.ApplyTheme(ATheme);
  if Assigned(FModelCombo) then
    FModelCombo.ApplyTheme(ATheme);
  if Assigned(FSendBtn) then
    FSendBtn.ApplyTheme(ATheme);
  if Assigned(FStopBtn) then
    FStopBtn.ApplyTheme(ATheme);
  if Assigned(FAttachBtn) then
    FAttachBtn.ApplyTheme(ATheme);
  if Assigned(FAllowModifyOutsideCheck) then
    ConfigureThemedCheckBox(FAllowModifyOutsideCheck, ATheme);
  if Assigned(FAllowModifyOutsideLabel) then
    FAllowModifyOutsideLabel.Font.Color := P.Text;
  RefreshAttachmentStrip;
  RefreshHistoryView;
end;

procedure TChatPanel.ApplyPlatformChrome(ATheme: TThemeKind);
begin
  if Assigned(FPromptMemo) then
    ApplyPlatformScrollableTheme(FPromptMemo, ATheme);
end;

procedure TChatPanel.SetWorkspace(const AName: string);
begin
  FWorkspaceName := AName;
  UpdateHeading;
end;

procedure TChatPanel.SetMode(AMode: TWorkspaceMode);
begin
  FMode := AMode;
  if Assigned(FModeCombo) then
    FModeCombo.ItemIndex := Ord(AMode);
  UpdateHeading;
  if Assigned(FSendBtn) then
    case FMode of
      wmAsk: FSendBtn.Caption := 'Ask Question';
      wmPlan: FSendBtn.Caption := 'Create Plan';
      wmAgent: FSendBtn.Caption := 'Run Agent';
    end;
end;

procedure TChatPanel.SetAvailableModels(const AModels: array of TSavedModel);
var
  I, SelIdx: Integer;
  Cap: string;
begin
  if not Assigned(FModelCombo) then Exit;
  FModelCombo.Items.BeginUpdate;
  FModelIds.BeginUpdate;
  try
    FModelCombo.Items.Clear;
    FModelIds.Clear;
    SelIdx := -1;
    for I := 0 to High(AModels) do begin
      Cap := ModelComboCaption(AModels[I]);
      FModelCombo.Items.Add(Cap);
      FModelIds.Add(AModels[I].ModelId);
      if SameText(AModels[I].ModelId, FModel) then
        SelIdx := I;
    end;
    if SelIdx >= 0 then
      FModelCombo.SetItemIndexSilent(SelIdx)
    else if FModelCombo.Items.Count > 0 then begin
      FModelCombo.SetItemIndexSilent(0);
      FModel := FModelIds[0];
    end else begin
      FModelCombo.SetItemIndexSilent(-1);
      FModel := '';
    end;
  finally
    FModelIds.EndUpdate;
    FModelCombo.Items.EndUpdate;
  end;
end;

procedure TChatPanel.SetModel(const AModel: string);
var
  Idx: Integer;
begin
  FModel := AModel;
  Idx := FModelIds.IndexOf(AModel);
  if Assigned(FModelCombo) then begin
    if Idx >= 0 then
      FModelCombo.SetItemIndexSilent(Idx)
    else if FModel = '' then
      FModelCombo.SetItemIndexSilent(-1);
  end;
end;

procedure TChatPanel.ClearHistory;
begin
  FHistoryText := '';
  FHistoryViewSyncedLen := 0;
  FLastAppendWasTrace := False;
  FEphemeralThinkingActive := False;
  InitWelcomeText;
  RefreshHistoryView;
end;

procedure TChatPanel.AppendToolMessage(const AMsg: TChatMessage; ADebuggingMode: Boolean);
var
  RoleLabel, Body: string;
begin
  if ADebuggingMode then begin
    if AMsg.VisualSummary <> '' then
      RoleLabel := 'Tool Result [' + AMsg.VisualSummary + ']'
    else
      RoleLabel := 'Tool Result';
    Body := Trim(AMsg.Content);
    if Body = '' then Exit;
    AppendToHistory(RoleLabel, Body);
    Exit;
  end;

  if Pos('"error"', LowerCase(AMsg.Content)) = 0 then
    Exit;

  if AMsg.VisualSummary <> '' then
    RoleLabel := 'Tool Error [' + AMsg.VisualSummary + ']'
  else
    RoleLabel := 'Tool Error';
  Body := ToolMessageBody(AMsg);
  if Trim(Body) = '' then Exit;
  AppendToHistory(RoleLabel, Body);
end;

procedure TChatPanel.AppendMessage(const AMsg: TChatMessage);
var
  RoleLabel, Body: string;
begin
  if AMsg.Role = crSystem then
    Exit;

  case AMsg.Role of
    crUser:
      begin
        RoleLabel := 'You';
        Body := FormatUserMessageBody(AMsg);
      end;
    crAssistant:
      begin
        RoleLabel := 'Agent';
        Body := AMsg.Content;
        if (Trim(Body) = '') and (Length(AMsg.ToolCalls) > 0) then
          Exit;
      end;
    crTool:
      begin
        if AMsg.VisualSummary <> '' then
          RoleLabel := 'Tool [' + AMsg.VisualSummary + ']'
        else
          RoleLabel := 'Tool';
        Body := ToolMessageBody(AMsg);
      end;
  else
    Body := AMsg.Content;
    RoleLabel := 'Message';
  end;
  AppendToHistory(RoleLabel, Body);
end;

procedure TChatPanel.AppendTraceLine(const AText: string);
begin
  RemoveEphemeralThinkingLine;
  AppendTraceLineWithPrefix(ChatTracePrefixTool, AText);
end;

procedure TChatPanel.AppendToolActivityLine(const AToolName, AArgsJson: string);
begin
  if Trim(AToolName) = '' then Exit;
  RemoveEphemeralThinkingLine;
  AppendTraceLineWithPrefix(ChatTracePrefixTool,
    FormatToolCallActivityLine(AToolName, AArgsJson));
end;

procedure TChatPanel.SetAgentThinkingInChat(AVisible: Boolean);
begin
  EnsureHistoryView;
  if not Assigned(FHistoryView) then Exit;
  if AVisible then begin
    if FEphemeralThinkingActive then Exit;
    FEphemeralThinkingActive := True;
    FHistoryView.SetEphemeralThinkingVisible(True);
  end else
    RemoveEphemeralThinkingLine;
end;

procedure TChatPanel.AppendText(const AText: string);
begin
  if Trim(AText) = '' then Exit;
  RemoveEphemeralThinkingLine;
  if FHistoryText <> '' then
    FHistoryText := FHistoryText + LineEnding + LineEnding;
  FHistoryText := FHistoryText + AText;
  FLastAppendWasTrace := False;
  RefreshHistoryView;
end;

procedure TChatPanel.ModeComboChange(Sender: TObject);
begin
  if not Assigned(FModeCombo) then Exit;
  if (FModeCombo.ItemIndex < Ord(Low(TWorkspaceMode))) or
     (FModeCombo.ItemIndex > Ord(High(TWorkspaceMode))) then
    Exit;
  FMode := TWorkspaceMode(FModeCombo.ItemIndex);
  UpdateHeading;
  if Assigned(FOnModeChange) then
    FOnModeChange(Self, FMode);
end;

procedure TChatPanel.ModelComboChange(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := FModelCombo.ItemIndex;
  if (Idx >= 0) and (Idx < FModelIds.Count) then
    FModel := FModelIds[Idx]
  else
    FModel := '';
  if Assigned(FOnModelChange) then
    FOnModelChange(Self, FModel);
end;

procedure TChatPanel.SetAllowModifyOutsideChecked(AValue: Boolean);
begin
  FUpdatingAllowModifyOutside := True;
  try
    if Assigned(FAllowModifyOutsideCheck) then
      FAllowModifyOutsideCheck.Checked := AValue;
  finally
    FUpdatingAllowModifyOutside := False;
  end;
end;

function TChatPanel.GetAllowModifyOutsideChecked: Boolean;
begin
  if Assigned(FAllowModifyOutsideCheck) then
    Exit(FAllowModifyOutsideCheck.Checked);
  Result := False;
end;

procedure TChatPanel.SetComposerEnabled(AEnabled: Boolean);
begin
  if Assigned(FPromptMemo) then
    FPromptMemo.Enabled := AEnabled;
  if Assigned(FModeCombo) then
    FModeCombo.Enabled := AEnabled;
  if Assigned(FModelCombo) then
    FModelCombo.Enabled := AEnabled;
  if Assigned(FSendBtn) then
    FSendBtn.Enabled := AEnabled and not FIsRunning;
  if Assigned(FAttachBtn) then
    FAttachBtn.Enabled := AEnabled and not FIsRunning;
  if Assigned(FAllowModifyOutsideCheck) then
    FAllowModifyOutsideCheck.Enabled := AEnabled and not FIsRunning;
  if Assigned(FAllowModifyOutsideLabel) then
    FAllowModifyOutsideLabel.Enabled := AEnabled and not FIsRunning;
end;

procedure TChatPanel.ReloadFromMessages(const AMessages: TChatMessageArray; ADebuggingMode: Boolean);
var
  I: Integer;
begin
  FHistoryText := '';
  FHistoryViewSyncedLen := 0;
  FLastAppendWasTrace := False;
  FEphemeralThinkingActive := False;
  FBatchHistoryReload := True;
  try
    for I := 0 to High(AMessages) do begin
      if AMessages[I].Role = crTool then
        AppendToolMessage(AMessages[I], ADebuggingMode)
      else
        AppendMessage(AMessages[I]);
    end;
  finally
    FBatchHistoryReload := False;
  end;
  if FHistoryText = '' then
    InitWelcomeText;
  ApplyHistoryViewNow(False);
end;

procedure TChatPanel.SubmitPrompt(const APrompt: string);
var
  Attachments: TChatAttachmentArray;
  Err, Prompt: string;
begin
  Prompt := Trim(APrompt);
  if (Prompt = '') and (FPendingImagePaths.Count = 0) then Exit;
  if FIsRunning then Exit;
  if Assigned(FPromptMemo) and not FPromptMemo.Enabled then Exit;

  Err := FinalizeAttachmentsForSend(Attachments);
  if Err <> '' then begin
    LcaShowMessage(Err, FTheme);
    Exit;
  end;

  ClearPendingImages;
  if Assigned(FOnPrompt) then
    FOnPrompt(Self, Prompt, Attachments, FMode, FModel);
end;

procedure TChatPanel.SendBtnClick(Sender: TObject);
var
  Prompt: string;
begin
  if not Assigned(FPromptMemo) then Exit;
  Prompt := Trim(FPromptMemo.Text);
  if (Prompt = '') and (FPendingImagePaths.Count = 0) then Exit;
  FPromptMemo.Text := '';
  SubmitPrompt(Prompt);
end;

procedure TChatPanel.StopBtnClick(Sender: TObject);
begin
  if Assigned(FOnCancel) then
    FOnCancel(Self);
end;

end.
