unit frmHelp;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, LCLType, LcaPaintButton, LcaPaintComboBox,
  LcaTheme, uHelpContent, LcaMarkdownView;

type
  { THelpForm }
  THelpForm = class(TForm)
    pnlTop: TPanel;
    lblSearch: TLabel;
    edtSearch: TEdit;
    splMain: TSplitter;
    pnlTopics: TPanel;
    lstTopics: TListBox;
    pnlPreviewHost: TPanel;
    pnlBottom: TPanel;
    btnClose: TLcaPaintButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure lstTopicsClick(Sender: TObject);
    procedure lstTopicsDrawItem(Control: TWinControl; Index: Integer; ARect: TRect;
      State: TOwnerDrawState);
    procedure btnCloseClick(Sender: TObject);
  private
    FTheme: TThemeKind;
    FCatalog: THelpCatalog;
    FPreview: TLcaMarkdownView;
    FFilteredIndices: THelpTopicIndexArray;
    procedure EnsurePreview;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure RebuildFilteredList;
    procedure ShowTopicAtListIndex(AListIndex: Integer);
  public
    destructor Destroy; override;
    class procedure ShowGuide(AOwner: TComponent; ATheme: TThemeKind);
  end;

implementation

{$R *.lfm}

class procedure THelpForm.ShowGuide(AOwner: TComponent; ATheme: TThemeKind);
var
  Dlg: THelpForm;
begin
  Dlg := THelpForm.Create(AOwner);
  try
    Dlg.FTheme := ATheme;
    Dlg.FCatalog := THelpCatalog.Create;
    Dlg.FCatalog.LoadResolved;
    Dlg.ApplyTheme(ATheme);
    Dlg.RebuildFilteredList;
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

destructor THelpForm.Destroy;
begin
  FPreview := nil;
  FCatalog.Free;
  inherited Destroy;
end;

procedure THelpForm.EnsurePreview;
begin
  if Assigned(FPreview) then Exit;
  if not Assigned(pnlPreviewHost) then Exit;
  FPreview := TLcaMarkdownView.Create(Self);
  FPreview.Parent := pnlPreviewHost;
  FPreview.Align := alClient;
end;

procedure THelpForm.FormCreate(Sender: TObject);
begin
  FCatalog := nil;
  KeyPreview := True;
end;

procedure THelpForm.FormShow(Sender: TObject);
begin
  ApplyTheme(FTheme);
  ApplyFormPlatformThemes(Self, FTheme);
  pnlBottom.BringToFront;
  if lstTopics.ItemIndex < 0 then
    RebuildFilteredList;
end;

procedure THelpForm.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.Background;
  Font.Color := P.Text;
  pnlTop.Color := P.Surface;
  pnlTopics.Color := P.Surface;
  pnlPreviewHost.Color := P.Background;
  pnlBottom.Color := P.Surface;
  ApplyThemedForm(Self, ATheme);
  pnlTop.Color := P.Surface;
  pnlTopics.Color := P.Surface;
  pnlPreviewHost.Color := P.Background;
  pnlBottom.Color := P.Surface;
  lblSearch.Font.Color := P.TextMuted;
  edtSearch.Color := P.SurfaceAlt;
  edtSearch.Font.Color := P.Text;
  ApplyPlatformChrome(Self, ATheme);
  ApplyPlatformScrollableThemeRecursive(Self, ATheme);
  ConfigureThemedListBox(lstTopics, ATheme);
  lstTopics.OnDrawItem := @lstTopicsDrawItem;
  EnsurePreview;
  if Assigned(FPreview) then
    FPreview.ApplyTheme(ATheme);
  lstTopics.Invalidate;
end;

procedure THelpForm.RebuildFilteredList;
var
  I, TopicIdx: Integer;
  Topic: THelpTopic;
begin
  if FCatalog = nil then Exit;
  FFilteredIndices := FCatalog.SearchIndices(edtSearch.Text);
  lstTopics.Items.BeginUpdate;
  try
    lstTopics.Items.Clear;
    for I := 0 to High(FFilteredIndices) do begin
      TopicIdx := FFilteredIndices[I];
      Topic := FCatalog.GetTopic(TopicIdx);
      lstTopics.Items.AddObject(Topic.Title, TObject(PtrUInt(TopicIdx)));
    end;
    if lstTopics.Items.Count > 0 then begin
      lstTopics.ItemIndex := 0;
      ShowTopicAtListIndex(0);
    end else begin
      EnsurePreview;
      if Assigned(FPreview) then
        FPreview.SetMarkdown('# No matching topics' + LineEnding + LineEnding +
          'Try a different search term.');
    end;
  finally
    lstTopics.Items.EndUpdate;
  end;
end;

procedure THelpForm.ShowTopicAtListIndex(AListIndex: Integer);
var
  TopicIdx: Integer;
  Topic: THelpTopic;
begin
  if FCatalog = nil then Exit;
  if (AListIndex < 0) or (AListIndex >= lstTopics.Items.Count) then Exit;
  TopicIdx := Integer(PtrUInt(lstTopics.Items.Objects[AListIndex]));
  Topic := FCatalog.GetTopic(TopicIdx);
  EnsurePreview;
  if Assigned(FPreview) then
    FPreview.SetMarkdown(Topic.Body);
end;

procedure THelpForm.edtSearchChange(Sender: TObject);
begin
  RebuildFilteredList;
end;

procedure THelpForm.lstTopicsClick(Sender: TObject);
begin
  ShowTopicAtListIndex(lstTopics.ItemIndex);
end;

procedure THelpForm.lstTopicsDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
begin
  ThemedListBoxDrawItem(Control, Index, ARect, State, FTheme);
end;

procedure THelpForm.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
