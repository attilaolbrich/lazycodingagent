unit frmKnowledgeBaseConfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  LcaPaintButton, LcaPaintComboBox, uAppTypes, LcaTheme, uFutureFeatureFormCommon;

type
  { TKnowledgeBaseConfigForm }
  TKnowledgeBaseConfigForm = class(TForm)
    lblTitle: TLabel;
    lblComingSoon: TLabel;
    lblSubtitle: TLabel;
    lblSources: TLabel;
    lstSources: TListBox;
    lblSourceType: TLabel;
    cboSourceType: TLcaPaintComboBox;
    pnlActions: TPanel;
    btnAddSource: TLcaPaintButton;
    btnReindex: TLcaPaintButton;
    memRoadmap: TMemo;
    pnlBottom: TPanel;
    btnClose: TLcaPaintButton;
    procedure FormShow(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    FTheme: TThemeKind;
    procedure ApplyTheme(ATheme: TThemeKind);
  public
    class function Execute(AOwner: TComponent; ATheme: TThemeKind;
      const AWorkspaceName: string): Boolean;
  end;

implementation

{$R *.lfm}

class function TKnowledgeBaseConfigForm.Execute(AOwner: TComponent; ATheme: TThemeKind;
  const AWorkspaceName: string): Boolean;
var
  Dlg: TKnowledgeBaseConfigForm;
begin
  Dlg := TKnowledgeBaseConfigForm.Create(AOwner);
  try
    Dlg.FTheme := ATheme;
    if Trim(AWorkspaceName) <> '' then
      Dlg.lblSubtitle.Caption := 'Workspace: ' + AWorkspaceName +
        ' — knowledge sources and RAG indexing are not available yet.'
    else
      Dlg.lblSubtitle.Caption :=
        'Configure workspace knowledge sources (coming soon).';
    Dlg.ApplyTheme(ATheme);
    Dlg.ShowModal;
    Result := True;
  finally
    Dlg.Free;
  end;
end;

procedure TKnowledgeBaseConfigForm.ApplyTheme(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  ApplyFutureFeatureDialogTheme(Self, ATheme, lblComingSoon, lblTitle, lblSubtitle,
    memRoadmap, pnlBottom);
  pnlActions.Color := ThemePalette(ATheme).Surface;
  lblSources.Font.Color := ThemePalette(ATheme).Text;
  lblSourceType.Font.Color := ThemePalette(ATheme).Text;
  ConfigureThemedListBox(lstSources, ATheme);
end;

procedure TKnowledgeBaseConfigForm.FormShow(Sender: TObject);
begin
  lblTitle.Caption := NavigationFutureFeatureTitle(niKnowledgeBase);
  FillFutureFeatureRoadmapMemo(niKnowledgeBase, memRoadmap);
  lstSources.Items.Clear;
  lstSources.Items.Add('README.md (Markdown — sample)');
  lstSources.Items.Add('https://example.com/docs (URL — sample)');
  cboSourceType.Items.Clear;
  cboSourceType.Items.Add('Website URL');
  cboSourceType.Items.Add('Markdown file');
  cboSourceType.Items.Add('PDF document');
  cboSourceType.Items.Add('Free-text entry');
  cboSourceType.Items.Add('Confluence space');
  cboSourceType.ItemIndex := 0;
  lstSources.Enabled := False;
  cboSourceType.Enabled := False;
  btnAddSource.Enabled := False;
  btnReindex.Enabled := False;
  memRoadmap.ReadOnly := True;
end;

procedure TKnowledgeBaseConfigForm.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
