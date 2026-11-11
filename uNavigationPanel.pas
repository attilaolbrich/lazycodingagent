unit uNavigationPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, StdCtrls, Graphics, Dialogs,
  ComCtrls, Menus, LCLType, uAppTypes, LcaTheme, LcaPaintButton, LcaThemedMessageBox,
  uCodingAgentPresets,
  uAgentExecutionLog, uAgentToolErrorLog, LcaPaintNavList,
  uOsShell, FileUtil;

type
  TNavWorkspaceSelectEvent = procedure(Sender: TObject; const AWorkspaceId: string) of object;
  TNavWorkspaceActionEvent = procedure(Sender: TObject) of object;
  TNavWorkspaceDeleteEvent = procedure(Sender: TObject; const AWorkspaceId: string) of object;
  TNavSessionSelectEvent = procedure(Sender: TObject; const ASessionId: string) of object;
  TNavSessionActionEvent = procedure(Sender: TObject) of object;
  TNavSessionArchiveEvent = procedure(Sender: TObject; const ASessionId: string) of object;
  TNavFileOpenEvent = procedure(Sender: TObject; const AFilePath: string) of object;
  TNavLogEntrySelectedEvent = procedure(Sender: TObject; AIndex: Integer) of object;
  TNavExecutionLogClearEvent = procedure(Sender: TObject) of object;
  TNavToolErrorLogClearEvent = procedure(Sender: TObject) of object;

  { Binds designer-placed nav controls; does not create visual children. }
  TNavContentControl = class(TComponent)
  private
    FSelected: TNavigationItem;
    FTheme: TThemeKind;
    FWorkspaceName: string;
    FWorkspaceRoot: string;

    FTitleLabel: TLabel;
    FSubLabel: TLabel;
    FComingSoonLabel: TLabel;
    FFileList: TControl;
    FTreeView: TTreeView;
    FLogList: TControl;
    FErrorLogList: TControl;
    FExecutionLog: TAgentExecutionLog;
    FToolErrorLog: TAgentToolErrorLog;
    FActionBtn: TLcaPaintButton;
    FSecondaryActionBtn: TLcaPaintButton;
    FWorkspaceIds: TStringList;
    FSessionIds: TStringList;
    FSessionArchived: TStringList;
    FActiveWorkspaceId: string;
    FActiveSessionId: string;
    FLastPopulatedRoot: string;
    FSessionTaskCaptions: TStringList;
    FProjectsTreePopup: TPopupMenu;
    FMnuTreeOpenInApp: TMenuItem;
    FMnuTreeOpenInFileManager: TMenuItem;
    FMnuTreeOpenDefault: TMenuItem;
    FContextTreeNode: TTreeNode;
    FSessionsListPopup: TPopupMenu;
    FMnuSessionArchive: TMenuItem;
    FMnuSessionRestore: TMenuItem;
    FMnuSessionDeletePermanent: TMenuItem;

    FOnWorkspaceSelect: TNavWorkspaceSelectEvent;
    FOnWorkspaceNew: TNavWorkspaceActionEvent;
    FOnWorkspaceDelete: TNavWorkspaceDeleteEvent;
    FOnSessionSelect: TNavSessionSelectEvent;
    FOnSessionNew: TNavSessionActionEvent;
    FOnSessionArchive: TNavSessionArchiveEvent;
    FOnSessionRestore: TNavSessionArchiveEvent;
    FOnSessionDelete: TNavSessionArchiveEvent;
    FOnFileOpen: TNavFileOpenEvent;
    FOnLogEntrySelected: TNavLogEntrySelectedEvent;
    FOnClearExecutionLog: TNavExecutionLogClearEvent;
    FOnClearToolErrorLog: TNavToolErrorLogClearEvent;
    FOnToolErrorEntrySelected: TNavLogEntrySelectedEvent;
    FOnTasksRefresh: TNotifyEvent;

    procedure ActionBtnClick(Sender: TObject);
    procedure FillTaskListBox;
    procedure LogListClick(Sender: TObject);
    procedure ErrorLogListClick(Sender: TObject);
    procedure SecondaryActionBtnClick(Sender: TObject);
    procedure UpdateSessionSecondaryAction;
    procedure UpdateWorkspaceSecondaryAction;
    procedure FileListClick(Sender: TObject);
    procedure FileListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FileListDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure PopulateFileTree(const ARoot: string);
    procedure FreeFileTreeNodePaths;
    procedure TreeViewDblClick(Sender: TObject);
    procedure TreeViewKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TreeViewMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure ProjectsTreeMenuPopup(Sender: TObject);
    procedure MnuTreeOpenInAppClick(Sender: TObject);
    procedure MnuTreeOpenInFileManagerClick(Sender: TObject);
    procedure MnuTreeOpenDefaultClick(Sender: TObject);
    procedure SessionsListMenuPopup(Sender: TObject);
    procedure MnuSessionArchiveMenuClick(Sender: TObject);
    procedure MnuSessionRestoreMenuClick(Sender: TObject);
    procedure MnuSessionDeletePermanentMenuClick(Sender: TObject);
    procedure ApplyNavFileListPopupMenu;
    function TreeNodeDisplaySegment(const ACaption: string): string;
    function TreeNodeAbsolutePath(ANode: TTreeNode): string;
    function IsTreePathAFile(const APath: string): Boolean;
    procedure TryOpenSelectedTreeFile;
    procedure TryOpenTreePathInApp(const APath: string);
    procedure RebuildView;
    procedure MaybePopulateProjectsTree;
    procedure ApplyNavListMetrics;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Bind(ATitle: TLabel; ASub: TLabel; AComingSoon: TLabel; AFileList: TControl;
      ATree: TTreeView; ALogList, AErrorLogList: TControl; APrimaryBtn, ASecondaryBtn: TLcaPaintButton);
    procedure BindProjectsTreeContextMenu(APopup: TPopupMenu; AOpenInApp, AOpenInFileManager,
      AOpenDefault: TMenuItem);
    procedure BindSessionsListContextMenu(APopup: TPopupMenu; AArchive, ARestore,
      ADeletePermanent: TMenuItem);
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure ApplyPlatformChrome(ATheme: TThemeKind);
    procedure SetSelected(AItem: TNavigationItem; const AWorkspaceName, AWorkspaceRoot: string);
    procedure SetWorkspaceList(const ACaptions, AIds: TStrings; const AActiveId: string);
    procedure SetSessionList(const ACaptions, AIds, AArchived: TStrings; const AActiveId: string);
    procedure BindExecutionLog(ALog: TAgentExecutionLog);
    procedure RefreshExecutionLogList;
    procedure AppendExecutionLogEntry(AIndex: Integer; AFollowSelection: Boolean = True);
    procedure BindToolErrorLog(ALog: TAgentToolErrorLog);
    procedure RefreshToolErrorLogList;
    procedure AppendToolErrorLogEntry(AIndex: Integer);
    procedure UpdateSessionTasks(const ACaptions: TStrings);
    procedure SetCenterAddTabAvailable(AAvailable: Boolean);

    property OnWorkspaceSelect: TNavWorkspaceSelectEvent read FOnWorkspaceSelect write FOnWorkspaceSelect;
    property OnWorkspaceNew: TNavWorkspaceActionEvent read FOnWorkspaceNew write FOnWorkspaceNew;
    property OnWorkspaceDelete: TNavWorkspaceDeleteEvent read FOnWorkspaceDelete write FOnWorkspaceDelete;
    property OnSessionSelect: TNavSessionSelectEvent read FOnSessionSelect write FOnSessionSelect;
    property OnSessionNew: TNavSessionActionEvent read FOnSessionNew write FOnSessionNew;
    property OnSessionArchive: TNavSessionArchiveEvent read FOnSessionArchive write FOnSessionArchive;
    property OnSessionRestore: TNavSessionArchiveEvent read FOnSessionRestore write FOnSessionRestore;
    property OnSessionDelete: TNavSessionArchiveEvent read FOnSessionDelete write FOnSessionDelete;
    property OnFileOpen: TNavFileOpenEvent read FOnFileOpen write FOnFileOpen;
    property OnLogEntrySelected: TNavLogEntrySelectedEvent read FOnLogEntrySelected
      write FOnLogEntrySelected;
    property OnClearExecutionLog: TNavExecutionLogClearEvent read FOnClearExecutionLog
      write FOnClearExecutionLog;
    property OnClearToolErrorLog: TNavToolErrorLogClearEvent read FOnClearToolErrorLog
      write FOnClearToolErrorLog;
    property OnToolErrorEntrySelected: TNavLogEntrySelectedEvent read FOnToolErrorEntrySelected
      write FOnToolErrorEntrySelected;
    property OnTasksRefresh: TNotifyEvent read FOnTasksRefresh write FOnTasksRefresh;
  end;

implementation

const
  NavListFontSize = 11;

function NavListItems(ACtrl: TControl): TStrings;
begin
  if not Assigned(ACtrl) then Exit(nil);
  if ACtrl is TLcaPaintNavList then
    Exit(TLcaPaintNavList(ACtrl).Items);
  if ACtrl is TListBox then
    Exit(TListBox(ACtrl).Items);
  Result := nil;
end;

function NavListItemIndex(ACtrl: TControl): Integer;
begin
  if ACtrl is TLcaPaintNavList then
    Exit(TLcaPaintNavList(ACtrl).ItemIndex);
  if ACtrl is TListBox then
    Exit(TListBox(ACtrl).ItemIndex);
  Result := -1;
end;

procedure NavListSetItemIndex(ACtrl: TControl; AIndex: Integer);
begin
  if ACtrl is TLcaPaintNavList then
    TLcaPaintNavList(ACtrl).ItemIndex := AIndex
  else if ACtrl is TListBox then
    TListBox(ACtrl).ItemIndex := AIndex;
end;

procedure NavListItemsBeginUpdate(ACtrl: TControl);
var
  S: TStrings;
begin
  S := NavListItems(ACtrl);
  if Assigned(S) then
    S.BeginUpdate;
end;

procedure NavListItemsEndUpdate(ACtrl: TControl);
var
  S: TStrings;
begin
  S := NavListItems(ACtrl);
  if Assigned(S) then
    S.EndUpdate;
end;

procedure NavListApplyMetrics(ACtrl: TControl; ATheme: TThemeKind);
begin
  if not Assigned(ACtrl) then Exit;
  if ACtrl is TLcaPaintNavList then begin
    TLcaPaintNavList(ACtrl).Font.Size := NavListFontSize;
    TLcaPaintNavList(ACtrl).ItemHeight := ThemedNavListItemHeight;
    TLcaPaintNavList(ACtrl).ApplyTheme(ATheme);
  end else if ACtrl is TListBox then begin
    ConfigureThemedListBox(TListBox(ACtrl), ATheme);
    TListBox(ACtrl).Font.Size := NavListFontSize;
    TListBox(ACtrl).ItemHeight := ThemedNavListItemHeight;
  end;
end;

procedure NavListWireClick(ACtrl: TControl; AHandler: TNotifyEvent);
begin
  if ACtrl is TLcaPaintNavList then
    TLcaPaintNavList(ACtrl).OnClick := AHandler
  else if ACtrl is TListBox then
    TListBox(ACtrl).OnClick := AHandler;
end;

procedure NavListWireKeyDown(ACtrl: TControl; AHandler: TKeyEvent);
begin
  if ACtrl is TLcaPaintNavList then
    TLcaPaintNavList(ACtrl).OnKeyDown := AHandler
  else if ACtrl is TListBox then
    TListBox(ACtrl).OnKeyDown := AHandler;
end;

procedure NavListWireDrawItem(ACtrl: TControl; AHandler: TDrawItemEvent);
begin
  if ACtrl is TListBox then
    TListBox(ACtrl).OnDrawItem := AHandler;
end;

procedure NavListSetPopupMenu(ACtrl: TControl; APopup: TPopupMenu);
begin
  if ACtrl is TLcaPaintNavList then
    TLcaPaintNavList(ACtrl).PopupMenu := APopup
  else if ACtrl is TListBox then
    TListBox(ACtrl).PopupMenu := APopup;
end;

constructor TNavContentControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTheme := tkDark;
  FSelected := niHome;
  FWorkspaceIds := TStringList.Create;
  FSessionIds := TStringList.Create;
  FSessionArchived := TStringList.Create;
  FSessionTaskCaptions := TStringList.Create;
end;

destructor TNavContentControl.Destroy;
begin
  FreeFileTreeNodePaths;
  FWorkspaceIds.Free;
  FSessionIds.Free;
  FSessionArchived.Free;
  FSessionTaskCaptions.Free;
  inherited Destroy;
end;

procedure TNavContentControl.Bind(ATitle: TLabel; ASub: TLabel; AComingSoon: TLabel;
  AFileList: TControl; ATree: TTreeView; ALogList, AErrorLogList: TControl;
  APrimaryBtn, ASecondaryBtn: TLcaPaintButton);
begin
  FTitleLabel := ATitle;
  FSubLabel := ASub;
  FComingSoonLabel := AComingSoon;
  FFileList := AFileList;
  FTreeView := ATree;
  FLogList := ALogList;
  FErrorLogList := AErrorLogList;
  FActionBtn := APrimaryBtn;
  FSecondaryActionBtn := ASecondaryBtn;

  if Assigned(FFileList) then begin
    NavListWireDrawItem(FFileList, @FileListDrawItem);
    NavListWireClick(FFileList, @FileListClick);
    NavListWireKeyDown(FFileList, @FileListKeyDown);
  end;
  if Assigned(FTreeView) then begin
    FTreeView.OnDblClick := @TreeViewDblClick;
    FTreeView.OnKeyDown := @TreeViewKeyDown;
    FTreeView.OnMouseDown := @TreeViewMouseDown;
  end;
  if Assigned(FLogList) then begin
    NavListWireClick(FLogList, @LogListClick);
    NavListWireDrawItem(FLogList, @FileListDrawItem);
  end;
  if Assigned(FErrorLogList) then begin
    NavListWireClick(FErrorLogList, @ErrorLogListClick);
    NavListWireDrawItem(FErrorLogList, @FileListDrawItem);
  end;
  if Assigned(FActionBtn) then
    FActionBtn.OnClick := @ActionBtnClick;
  if Assigned(FSecondaryActionBtn) then
    FSecondaryActionBtn.OnClick := @SecondaryActionBtnClick;

  ApplyNavListMetrics;
  RebuildView;
end;

procedure TNavContentControl.SetWorkspaceList(const ACaptions, AIds: TStrings; const AActiveId: string);
var
  I, SelIdx: Integer;
begin
  FActiveWorkspaceId := AActiveId;
  FWorkspaceIds.Clear;
  if Assigned(ACaptions) and Assigned(AIds) then begin
    for I := 0 to ACaptions.Count - 1 do begin
      if I >= AIds.Count then Break;
      FWorkspaceIds.Add(AIds[I]);
    end;
  end;
  if FSelected <> niHome then Exit;

  NavListItemsBeginUpdate(FFileList);
  try
    NavListItems(FFileList).Clear;
    if Assigned(ACaptions) then
      NavListItems(FFileList).Assign(ACaptions);
    SelIdx := -1;
    for I := 0 to FWorkspaceIds.Count - 1 do
      if SameText(FWorkspaceIds[I], AActiveId) then begin
        SelIdx := I;
        Break;
      end;
    NavListSetItemIndex(FFileList, SelIdx);
  finally
    NavListItemsEndUpdate(FFileList);
  end;
  UpdateWorkspaceSecondaryAction;
end;

procedure TNavContentControl.SetSessionList(const ACaptions, AIds, AArchived: TStrings;
  const AActiveId: string);
var
  I, SelIdx: Integer;
begin
  FActiveSessionId := AActiveId;
  FSessionIds.Clear;
  FSessionArchived.Clear;
  if Assigned(AIds) then
    FSessionIds.Assign(AIds);
  if Assigned(AArchived) then
    FSessionArchived.Assign(AArchived);
  if FSelected <> niSessions then Exit;

  NavListItemsBeginUpdate(FFileList);
  try
    NavListItems(FFileList).Clear;
    if Assigned(ACaptions) then
      NavListItems(FFileList).Assign(ACaptions);
    SelIdx := -1;
    for I := 0 to FSessionIds.Count - 1 do
      if SameText(FSessionIds[I], AActiveId) then begin
        SelIdx := I;
        Break;
      end;
    NavListSetItemIndex(FFileList, SelIdx);
  finally
    NavListItemsEndUpdate(FFileList);
  end;
  UpdateSessionSecondaryAction;
end;

procedure TNavContentControl.UpdateWorkspaceSecondaryAction;
var
  Idx: Integer;
begin
  if not Assigned(FSecondaryActionBtn) then Exit;
  if FSelected <> niHome then Exit;
  FSecondaryActionBtn.Caption := 'Remove from List';
  Idx := NavListItemIndex(FFileList);
  FSecondaryActionBtn.Enabled := (Idx >= 0) and (Idx < FWorkspaceIds.Count);
end;

procedure TNavContentControl.UpdateSessionSecondaryAction;
var
  Idx: Integer;
  Archived: Boolean;
begin
  if not Assigned(FSecondaryActionBtn) then Exit;
  Idx := NavListItemIndex(FFileList);
  Archived := False;
  if (Idx >= 0) and (Idx < FSessionArchived.Count) then
    Archived := SameText(FSessionArchived[Idx], '1');
  if Archived then
    FSecondaryActionBtn.Caption := 'Restore Session'
  else
    FSecondaryActionBtn.Caption := 'Archive Session';
end;

procedure TNavContentControl.SecondaryActionBtnClick(Sender: TObject);
var
  Idx: Integer;
  Archived: Boolean;
begin
  if FSelected = niHome then begin
    Idx := NavListItemIndex(FFileList);
    if (Idx < 0) or (Idx >= FWorkspaceIds.Count) then Exit;
    if Assigned(FOnWorkspaceDelete) then
      FOnWorkspaceDelete(Self, FWorkspaceIds[Idx]);
    Exit;
  end;
  if FSelected <> niSessions then Exit;
  Idx := NavListItemIndex(FFileList);
  if (Idx < 0) or (Idx >= FSessionIds.Count) then Exit;
  Archived := (Idx < FSessionArchived.Count) and SameText(FSessionArchived[Idx], '1');
  if Archived then begin
    if Assigned(FOnSessionRestore) then
      FOnSessionRestore(Self, FSessionIds[Idx]);
  end else if Assigned(FOnSessionArchive) then
    FOnSessionArchive(Self, FSessionIds[Idx]);
end;

procedure TNavContentControl.FileListClick(Sender: TObject);
var
  Idx: Integer;
begin
  if FSelected = niHome then begin
    Idx := NavListItemIndex(FFileList);
    if (Idx < 0) or (Idx >= FWorkspaceIds.Count) then Exit;
    if Assigned(FOnWorkspaceSelect) then
      FOnWorkspaceSelect(Self, FWorkspaceIds[Idx]);
    UpdateWorkspaceSecondaryAction;
  end else if FSelected = niSessions then begin
    Idx := NavListItemIndex(FFileList);
    if (Idx < 0) or (Idx >= FSessionIds.Count) then Exit;
    if Assigned(FOnSessionSelect) then
      FOnSessionSelect(Self, FSessionIds[Idx]);
    UpdateSessionSecondaryAction;
  end;
end;

procedure TNavContentControl.FileListKeyDown(Sender: TObject; var Key: Word; {%H-}Shift: TShiftState);
var
  Idx: Integer;
begin
  if Key <> VK_DELETE then Exit;
  if FSelected = niHome then begin
    Idx := NavListItemIndex(FFileList);
    if (Idx < 0) or (Idx >= FWorkspaceIds.Count) then Exit;
    if Assigned(FOnWorkspaceDelete) then
      FOnWorkspaceDelete(Self, FWorkspaceIds[Idx]);
  end else if FSelected = niSessions then begin
    Idx := NavListItemIndex(FFileList);
    if (Idx < 0) or (Idx >= FSessionIds.Count) then Exit;
    if Assigned(FOnSessionDelete) then
      FOnSessionDelete(Self, FSessionIds[Idx]);
  end;
end;

procedure TNavContentControl.FileListDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
begin
  ThemedNavListBoxDrawItem(Control, Index, ARect, State, FTheme);
end;

procedure TNavContentControl.ApplyNavListMetrics;
begin
  NavListApplyMetrics(FFileList, FTheme);
  NavListApplyMetrics(FLogList, FTheme);
  NavListApplyMetrics(FErrorLogList, FTheme);
  if Assigned(FTreeView) then begin
    ConfigureThemedTreeView(FTreeView, FTheme);
    FTreeView.Font.Size := NavListFontSize;
    FTreeView.Options := FTreeView.Options - [tvoAutoItemHeight];
    FTreeView.DefaultItemHeight := ThemedNavListItemHeight;
  end;
end;

procedure TNavContentControl.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(FTheme);
  if Assigned(FTitleLabel) then
    FTitleLabel.Font.Color := P.Text;
  if Assigned(FSubLabel) then
    FSubLabel.Font.Color := P.TextMuted;
  if Assigned(FComingSoonLabel) then begin
    FComingSoonLabel.Font.Style := [fsBold];
    FComingSoonLabel.Font.Color := P.Accent;
  end;
  ApplyNavListMetrics;
  if Assigned(FActionBtn) then
    FActionBtn.ApplyTheme(ATheme);
  if Assigned(FSecondaryActionBtn) then
    FSecondaryActionBtn.ApplyTheme(ATheme);
end;

procedure TNavContentControl.ApplyPlatformChrome(ATheme: TThemeKind);
begin
  if Assigned(FFileList) and (FFileList is TWinControl) and not (FFileList is TLcaPaintNavList) then
    ApplyPlatformScrollableTheme(TWinControl(FFileList), ATheme);
  if Assigned(FTreeView) then
    ApplyPlatformScrollableTheme(FTreeView, ATheme);
  if Assigned(FLogList) and (FLogList is TWinControl) and not (FLogList is TLcaPaintNavList) then
    ApplyPlatformScrollableTheme(TWinControl(FLogList), ATheme);
  if Assigned(FErrorLogList) and (FErrorLogList is TWinControl) and
     not (FErrorLogList is TLcaPaintNavList) then
    ApplyPlatformScrollableTheme(TWinControl(FErrorLogList), ATheme);
end;

procedure TNavContentControl.SetSelected(AItem: TNavigationItem; const AWorkspaceName,
  AWorkspaceRoot: string);
begin
  FSelected := AItem;
  FWorkspaceName := AWorkspaceName;
  FWorkspaceRoot := AWorkspaceRoot;
  if Trim(AWorkspaceRoot) = '' then
    FLastPopulatedRoot := '';
  RebuildView;
end;

procedure TNavContentControl.BindExecutionLog(ALog: TAgentExecutionLog);
begin
  FExecutionLog := ALog;
  RefreshExecutionLogList;
end;

procedure TNavContentControl.RefreshExecutionLogList;
var
  I: Integer;
begin
  if not Assigned(FLogList) then Exit;
  NavListItems(FLogList).Clear;
  if not Assigned(FExecutionLog) then Exit;
  for I := 0 to FExecutionLog.Count - 1 do
    NavListItems(FLogList).Add(FExecutionLog.Entry(I).Caption);
end;

procedure TNavContentControl.AppendExecutionLogEntry(AIndex: Integer; AFollowSelection: Boolean);
begin
  if not Assigned(FExecutionLog) or not Assigned(FLogList) then Exit;
  if (AIndex < 0) or (AIndex >= FExecutionLog.Count) then Exit;
  if NavListItems(FLogList).Count <> FExecutionLog.Count then
    RefreshExecutionLogList
  else
    NavListItems(FLogList)[AIndex] := FExecutionLog.Entry(AIndex).Caption;
  if AFollowSelection and (AIndex < NavListItems(FLogList).Count) then
    NavListSetItemIndex(FLogList, AIndex);
end;

procedure TNavContentControl.LogListClick(Sender: TObject);
begin
  if not Assigned(FOnLogEntrySelected) then Exit;
  if NavListItemIndex(FLogList) < 0 then Exit;
  FOnLogEntrySelected(Self, NavListItemIndex(FLogList));
end;

procedure TNavContentControl.ErrorLogListClick(Sender: TObject);
begin
  if not Assigned(FOnToolErrorEntrySelected) then Exit;
  if NavListItemIndex(FErrorLogList) < 0 then Exit;
  FOnToolErrorEntrySelected(Self, NavListItemIndex(FErrorLogList));
end;

procedure TNavContentControl.BindToolErrorLog(ALog: TAgentToolErrorLog);
begin
  FToolErrorLog := ALog;
  RefreshToolErrorLogList;
end;

procedure TNavContentControl.RefreshToolErrorLogList;
var
  I: Integer;
begin
  if not Assigned(FErrorLogList) then Exit;
  NavListItems(FErrorLogList).Clear;
  if not Assigned(FToolErrorLog) then Exit;
  for I := 0 to FToolErrorLog.Count - 1 do
    NavListItems(FErrorLogList).Add(FToolErrorLog.Entry(I).Caption);
end;

procedure TNavContentControl.AppendToolErrorLogEntry(AIndex: Integer);
begin
  if not Assigned(FToolErrorLog) or not Assigned(FErrorLogList) then Exit;
  if (AIndex < 0) or (AIndex >= FToolErrorLog.Count) then Exit;
  if NavListItems(FErrorLogList).Count <> FToolErrorLog.Count then
    RefreshToolErrorLogList
  else
    NavListItems(FErrorLogList)[AIndex] := FToolErrorLog.Entry(AIndex).Caption;
  if AIndex < NavListItems(FErrorLogList).Count then
    NavListSetItemIndex(FErrorLogList, AIndex);
end;

procedure TNavContentControl.FreeFileTreeNodePaths;
var
  N: TTreeNode;
begin
  if not Assigned(FTreeView) then Exit;
  N := FTreeView.Items.GetFirstNode;
  while N <> nil do begin
    if N.Data <> nil then begin
      StrDispose(PChar(N.Data));
      N.Data := nil;
    end;
    N := N.GetNext;
  end;
end;

function TNavContentControl.TreeNodeDisplaySegment(const ACaption: string): string;
var
  P: Integer;
begin
  P := Pos(' ', ACaption);
  if P > 0 then
    Result := Copy(ACaption, P + 1, MaxInt)
  else
    Result := ACaption;
end;

function TNavContentControl.TreeNodeAbsolutePath(ANode: TTreeNode): string;
var
  Parts: TStringList;
  N: TTreeNode;
  Seg: string;
  Root: string;
  I: Integer;
begin
  Result := '';
  if ANode = nil then Exit;
  if ANode.Data <> nil then
    Exit(string(PChar(ANode.Data)));
  Root := Trim(FWorkspaceRoot);
  if Root = '' then Exit;
  Parts := TStringList.Create;
  try
    N := ANode;
    while N <> nil do begin
      Seg := Trim(TreeNodeDisplaySegment(N.Text));
      if Seg <> '' then
        Parts.Insert(0, Seg);
      N := N.Parent;
    end;
    if Parts.Count = 0 then Exit;
    if SameText(Parts[0], ExtractFileName(Root)) then
      Parts.Delete(0);
    Result := Root;
    for I := 0 to Parts.Count - 1 do
      Result := IncludeTrailingPathDelimiter(Result) + Parts[I];
    Result := ExpandFileName(Result);
  finally
    Parts.Free;
  end;
end;

function TNavContentControl.IsTreePathAFile(const APath: string): Boolean;
begin
  Result := (APath <> '') and FileExists(APath) and not DirectoryExists(APath);
end;

procedure TNavContentControl.TryOpenTreePathInApp(const APath: string);
begin
  if not IsTreePathAFile(APath) then Exit;
  if Assigned(FOnFileOpen) then
    FOnFileOpen(Self, APath);
end;

procedure TNavContentControl.TryOpenSelectedTreeFile;
var
  N: TTreeNode;
  Path: string;
begin
  if not Assigned(FTreeView) then Exit;
  N := FTreeView.Selected;
  if N = nil then Exit;
  Path := TreeNodeAbsolutePath(N);
  TryOpenTreePathInApp(Path);
end;

procedure TNavContentControl.BindProjectsTreeContextMenu(APopup: TPopupMenu; AOpenInApp,
  AOpenInFileManager, AOpenDefault: TMenuItem);
begin
  FProjectsTreePopup := APopup;
  FMnuTreeOpenInApp := AOpenInApp;
  FMnuTreeOpenInFileManager := AOpenInFileManager;
  FMnuTreeOpenDefault := AOpenDefault;
  if not Assigned(FTreeView) then Exit;
  FTreeView.PopupMenu := APopup;
  if Assigned(APopup) then
    APopup.OnPopup := @ProjectsTreeMenuPopup;
  if Assigned(AOpenInApp) then
    AOpenInApp.OnClick := @MnuTreeOpenInAppClick;
  if Assigned(AOpenInFileManager) then
    AOpenInFileManager.OnClick := @MnuTreeOpenInFileManagerClick;
  if Assigned(AOpenDefault) then
    AOpenDefault.OnClick := @MnuTreeOpenDefaultClick;
end;

procedure TNavContentControl.BindSessionsListContextMenu(APopup: TPopupMenu; AArchive,
  ARestore, ADeletePermanent: TMenuItem);
begin
  FSessionsListPopup := APopup;
  FMnuSessionArchive := AArchive;
  FMnuSessionRestore := ARestore;
  FMnuSessionDeletePermanent := ADeletePermanent;
  if Assigned(APopup) then
    APopup.OnPopup := @SessionsListMenuPopup;
  if Assigned(AArchive) then
    AArchive.OnClick := @MnuSessionArchiveMenuClick;
  if Assigned(ARestore) then
    ARestore.OnClick := @MnuSessionRestoreMenuClick;
  if Assigned(ADeletePermanent) then
    ADeletePermanent.OnClick := @MnuSessionDeletePermanentMenuClick;
  ApplyNavFileListPopupMenu;
end;

procedure TNavContentControl.ApplyNavFileListPopupMenu;
begin
  if not Assigned(FFileList) then Exit;
  if FSelected = niSessions then
    NavListSetPopupMenu(FFileList, FSessionsListPopup)
  else
    NavListSetPopupMenu(FFileList, nil);
end;

procedure TNavContentControl.SessionsListMenuPopup(Sender: TObject);
var
  Idx: Integer;
  Archived: Boolean;
  OnSessions: Boolean;
begin
  OnSessions := FSelected = niSessions;
  if Assigned(FMnuSessionArchive) then
    FMnuSessionArchive.Visible := OnSessions;
  if Assigned(FMnuSessionRestore) then
    FMnuSessionRestore.Visible := OnSessions;
  if Assigned(FMnuSessionDeletePermanent) then
    FMnuSessionDeletePermanent.Visible := OnSessions;
  if not OnSessions then Exit;
  Idx := NavListItemIndex(FFileList);
  Archived := (Idx >= 0) and (Idx < FSessionArchived.Count) and
    SameText(FSessionArchived[Idx], '1');
  if Assigned(FMnuSessionArchive) then begin
    FMnuSessionArchive.Visible := not Archived;
    FMnuSessionArchive.Enabled := (Idx >= 0) and (Idx < FSessionIds.Count);
  end;
  if Assigned(FMnuSessionRestore) then begin
    FMnuSessionRestore.Visible := Archived;
    FMnuSessionRestore.Enabled := (Idx >= 0) and (Idx < FSessionIds.Count);
  end;
  if Assigned(FMnuSessionDeletePermanent) then
    FMnuSessionDeletePermanent.Enabled := (Idx >= 0) and (Idx < FSessionIds.Count);
end;

procedure TNavContentControl.MnuSessionArchiveMenuClick(Sender: TObject);
var
  Idx: Integer;
begin
  if FSelected <> niSessions then Exit;
  Idx := NavListItemIndex(FFileList);
  if (Idx < 0) or (Idx >= FSessionIds.Count) then Exit;
  if Assigned(FOnSessionArchive) then
    FOnSessionArchive(Self, FSessionIds[Idx]);
end;

procedure TNavContentControl.MnuSessionRestoreMenuClick(Sender: TObject);
var
  Idx: Integer;
begin
  if FSelected <> niSessions then Exit;
  Idx := NavListItemIndex(FFileList);
  if (Idx < 0) or (Idx >= FSessionIds.Count) then Exit;
  if Assigned(FOnSessionRestore) then
    FOnSessionRestore(Self, FSessionIds[Idx]);
end;

procedure TNavContentControl.MnuSessionDeletePermanentMenuClick(Sender: TObject);
var
  Idx: Integer;
begin
  if FSelected <> niSessions then Exit;
  Idx := NavListItemIndex(FFileList);
  if (Idx < 0) or (Idx >= FSessionIds.Count) then Exit;
  if Assigned(FOnSessionDelete) then
    FOnSessionDelete(Self, FSessionIds[Idx]);
end;

procedure TNavContentControl.TreeViewMouseDown(Sender: TObject; Button: TMouseButton;
  {%H-}Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbRight then Exit;
  if not Assigned(FTreeView) then Exit;
  FContextTreeNode := FTreeView.GetNodeAt(X, Y);
end;

procedure TNavContentControl.ProjectsTreeMenuPopup(Sender: TObject);
var
  Path: string;
  Valid: Boolean;
begin
  if FSelected <> niProjects then begin
    if Assigned(FMnuTreeOpenInApp) then FMnuTreeOpenInApp.Visible := False;
    if Assigned(FMnuTreeOpenInFileManager) then FMnuTreeOpenInFileManager.Visible := False;
    if Assigned(FMnuTreeOpenDefault) then FMnuTreeOpenDefault.Visible := False;
    Exit;
  end;
  if FContextTreeNode = nil then begin
    if Assigned(FTreeView) then begin
      FContextTreeNode := FTreeView.GetNodeAt(
        FTreeView.ScreenToClient(Mouse.CursorPos).X,
        FTreeView.ScreenToClient(Mouse.CursorPos).Y);
    end;
  end;
  Path := TreeNodeAbsolutePath(FContextTreeNode);
  Valid := (Path <> '') and (FileExists(Path) or DirectoryExists(Path));
  if Assigned(FMnuTreeOpenInApp) then begin
    FMnuTreeOpenInApp.Visible := Valid;
    FMnuTreeOpenInApp.Enabled := IsTreePathAFile(Path);
  end;
  if Assigned(FMnuTreeOpenInFileManager) then begin
    FMnuTreeOpenInFileManager.Visible := Valid;
    FMnuTreeOpenInFileManager.Enabled := Valid;
  end;
  if Assigned(FMnuTreeOpenDefault) then begin
    FMnuTreeOpenDefault.Visible := Valid;
    FMnuTreeOpenDefault.Enabled := Valid;
  end;
end;

procedure TNavContentControl.MnuTreeOpenInAppClick(Sender: TObject);
var
  Path: string;
begin
  Path := TreeNodeAbsolutePath(FContextTreeNode);
  TryOpenTreePathInApp(Path);
end;

procedure TNavContentControl.MnuTreeOpenInFileManagerClick(Sender: TObject);
var
  Path: string;
begin
  Path := TreeNodeAbsolutePath(FContextTreeNode);
  if Path = '' then Exit;
  if not RevealPathInFileManager(Path) then
    LcaShowMessage('Could not open the file manager for this path.', FTheme);
end;

procedure TNavContentControl.MnuTreeOpenDefaultClick(Sender: TObject);
var
  Path: string;
begin
  Path := TreeNodeAbsolutePath(FContextTreeNode);
  if Path = '' then Exit;
  if not OpenPathWithDefaultApplication(Path) then
    LcaShowMessage('Could not open this path with the default application.', FTheme);
end;

procedure TNavContentControl.TreeViewDblClick(Sender: TObject);
begin
  if FSelected = niProjects then
    TryOpenSelectedTreeFile;
end;

procedure TNavContentControl.TreeViewKeyDown(Sender: TObject; var Key: Word; {%H-}Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (FSelected = niProjects) then
    TryOpenSelectedTreeFile;
end;

procedure TNavContentControl.PopulateFileTree(const ARoot: string);
var
  RootNode: TTreeNode;

  procedure AddFolder(AParentNode: TTreeNode; const ADir: string);
  var
    Rec: TSearchRec;
    ChildNode: TTreeNode;
    FullPath: string;
  begin
    if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*', faAnyFile, Rec) = 0 then begin
      repeat
        if (Rec.Name = '.') or (Rec.Name = '..') or (Rec.Name = '.git') or (Rec.Name = 'lib') or
           (Rec.Name = 'backup') then
          Continue;

        if (Rec.Attr and faDirectory) <> 0 then begin
          FullPath := IncludeTrailingPathDelimiter(ADir) + Rec.Name;
          ChildNode := FTreeView.Items.AddChild(AParentNode, '📁 ' + Rec.Name);
          ChildNode.Data := StrNew(PChar(FullPath));
          AddFolder(ChildNode, FullPath);
        end else begin
          FullPath := IncludeTrailingPathDelimiter(ADir) + Rec.Name;
          ChildNode := FTreeView.Items.AddChild(AParentNode, '📄 ' + Rec.Name);
          ChildNode.Data := StrNew(PChar(FullPath));
        end;
      until FindNext(Rec) <> 0;
      FindClose(Rec);
    end;
  end;

begin
  FreeFileTreeNodePaths;
  FTreeView.Items.Clear;
  RootNode := FTreeView.Items.Add(nil, '📦 ' + ExtractFileName(ARoot));
  RootNode.Data := StrNew(PChar(ExcludeTrailingPathDelimiter(ARoot)));
  AddFolder(RootNode, ARoot);
  RootNode.Expand(False);
end;

procedure TNavContentControl.ActionBtnClick(Sender: TObject);
begin
  case FSelected of
    niHome:
      if Assigned(FOnWorkspaceNew) then
        FOnWorkspaceNew(Self);
    niProjects:
      begin
        if Trim(FWorkspaceRoot) = '' then begin
          LcaShowMessage('Select a workspace first.', FTheme);
          Exit;
        end;
        PopulateFileTree(FWorkspaceRoot);
        FLastPopulatedRoot := FWorkspaceRoot;
      end;
    niSessions:
      if Assigned(FOnSessionNew) then
        FOnSessionNew(Self);
    niBots:
      LcaShowMessage('Configure Agent Models in Settings menu.', FTheme);
    niTools:
      if Assigned(FOnClearExecutionLog) then
        FOnClearExecutionLog(Self);
    niTasks:
      begin
        if Assigned(FOnTasksRefresh) then
          FOnTasksRefresh(Self);
        FillTaskListBox;
      end;
    niToolErrors:
      if Assigned(FOnClearToolErrorLog) then
        FOnClearToolErrorLog(Self);
  end;
end;

procedure TNavContentControl.MaybePopulateProjectsTree;
var
  Root: string;
begin
  Root := Trim(FWorkspaceRoot);
  if Root = '' then Exit;
  if (FTreeView.Items.Count = 0) or not SameText(Root, FLastPopulatedRoot) then begin
    PopulateFileTree(Root);
    FLastPopulatedRoot := Root;
  end;
end;

procedure TNavContentControl.FillTaskListBox;
begin
  if not Assigned(FFileList) then Exit;
  NavListItems(FFileList).Assign(FSessionTaskCaptions);
end;

procedure TNavContentControl.UpdateSessionTasks(const ACaptions: TStrings);
begin
  FSessionTaskCaptions.Clear;
  if Assigned(ACaptions) then
    FSessionTaskCaptions.Assign(ACaptions);
  if FSelected = niTasks then
    FillTaskListBox;
end;

procedure TNavContentControl.RebuildView;
var
  I: Integer;
  Preset: TCodingAgentPreset;
begin
  if not Assigned(FFileList) then Exit;
  FFileList.Visible := False;
  if Assigned(FTreeView) then FTreeView.Visible := False;
  if Assigned(FLogList) then FLogList.Visible := False;
  if Assigned(FErrorLogList) then FErrorLogList.Visible := False;
  if (FSelected <> niSessions) and (FSelected <> niHome) and Assigned(FSecondaryActionBtn) then
    FSecondaryActionBtn.Visible := False;
  if Assigned(FActionBtn) then
    FActionBtn.Visible := True;
  if Assigned(FComingSoonLabel) then
    FComingSoonLabel.Visible := False;

  case FSelected of
    niHome:
      begin
        FFileList.Visible := True;
        FTitleLabel.Caption := 'Workspaces';
        if FWorkspaceIds.Count = 0 then
          FSubLabel.Caption := 'No workspace yet — create or open a project folder.'
        else
          FSubLabel.Caption := 'Select a workspace to switch. Active: ' + FWorkspaceName +
            '. Remove with the button below or Delete.';
        FActionBtn.Caption := '+ New Workspace';
        if Assigned(FSecondaryActionBtn) then
          FSecondaryActionBtn.Visible := FWorkspaceIds.Count > 0;
        UpdateWorkspaceSecondaryAction;
      end;
    niProjects:
      begin
        FTreeView.Visible := True;
        FTitleLabel.Caption := 'Project Explorer';
        if Trim(FWorkspaceRoot) = '' then
          FSubLabel.Caption := 'No project folder (select a workspace)'
        else
          FSubLabel.Caption := 'Workspace Tree';
        MaybePopulateProjectsTree;
        FTreeView.Invalidate;
        FActionBtn.Caption := '↻ Refresh Tree';
      end;
    niSessions:
      begin
        FFileList.Visible := True;
        FTitleLabel.Caption := 'Chat Sessions';
        if Trim(FWorkspaceName) = '' then
          FSubLabel.Caption := 'Select a workspace to manage sessions'
        else
          FSubLabel.Caption := 'History for ' + FWorkspaceName;
        FActionBtn.Caption := '+ New Chat Session';
        FSecondaryActionBtn.Visible := True;
        UpdateSessionSecondaryAction;
      end;
    niBots:
      begin
        FFileList.Visible := True;
        FTitleLabel.Caption := 'Coding Agent Personas';
        FSubLabel.Caption := 'Modes & pre-defined models (OpenRouter)';
        NavListItems(FFileList).Clear;
        NavListItems(FFileList).Add('⚡ Autopilot Agent (wmAgent)');
        NavListItems(FFileList).Add('📋 Architect & Planner (wmPlan)');
        NavListItems(FFileList).Add('💡 Code Assistant & Q&A (wmAsk)');
        NavListItems(FFileList).Add('');
        NavListItems(FFileList).Add('── Pre-defined coding agents ──');
        for I := 0 to CodingAgentPresetCount - 1 do begin
          Preset := GetCodingAgentPreset(I);
          NavListItems(FFileList).Add(Format('🧠 %s — %s (%s)', [Preset.Vendor, Preset.Caption, Preset.ModelId]));
        end;
        FActionBtn.Caption := '⚙ Agent Settings...';
      end;
    niTools:
      begin
        FLogList.Visible := True;
        FTitleLabel.Caption := 'Tool Execution & Logs';
        FSubLabel.Caption := 'Click an entry to inspect full prompt / tool I/O';
        FSubLabel.Hint := '';
        FActionBtn.Caption := '🗑 Clear Tool Logs';
        RefreshExecutionLogList;
      end;
    niToolErrors:
      begin
        FErrorLogList.Visible := True;
        FTitleLabel.Caption := 'Tool Errors';
        FSubLabel.Caption := TruncateLogCaption(ToolErrorLogFilePath, 72);
        FSubLabel.Hint := ToolErrorLogFilePath;
        FSubLabel.ShowHint := True;
        FActionBtn.Caption := '🗑 Clear Session Errors';
        RefreshToolErrorLogList;
      end;
    niTasks:
      begin
        FFileList.Visible := True;
        FTitleLabel.Caption := 'Task List & Checklist';
        FSubLabel.Caption := 'Chat-local tasks from the todo tool';
        FillTaskListBox;
        if NavListItems(FFileList).Count = 0 then
          NavListItems(FFileList).Add('No tasks tracked for this session.');
        FActionBtn.Caption := '🔄 Refresh Tasks';
      end;
  end;
  ApplyNavFileListPopupMenu;
end;

procedure TNavContentControl.SetCenterAddTabAvailable(AAvailable: Boolean);
begin
  { Reserved: center tab [+] mirrors new-session when chat panel is visible. }
  if not Assigned(FActionBtn) then Exit;
  if FSelected = niSessions then
    FActionBtn.Enabled := AAvailable;
end;

end.
