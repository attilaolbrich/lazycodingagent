unit frmTheBrainConfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  LcaPaintButton, uAppTypes, LcaTheme, uFutureFeatureFormCommon;

type
  { TTheBrainConfigForm }
  TTheBrainConfigForm = class(TForm)
    lblTitle: TLabel;
    lblComingSoon: TLabel;
    lblSubtitle: TLabel;
    chkEnableBrain: TCheckBox;
    lblMemories: TLabel;
    lstMemories: TListBox;
    pnlActions: TPanel;
    btnReviewMemories: TLcaPaintButton;
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

class function TTheBrainConfigForm.Execute(AOwner: TComponent; ATheme: TThemeKind;
  const AWorkspaceName: string): Boolean;
var
  Dlg: TTheBrainConfigForm;
begin
  Dlg := TTheBrainConfigForm.Create(AOwner);
  try
    Dlg.FTheme := ATheme;
    if Trim(AWorkspaceName) <> '' then
      Dlg.lblSubtitle.Caption := 'Workspace: ' + AWorkspaceName +
        '. Learning and memory require explicit user approval (coming soon).'
    else
      Dlg.lblSubtitle.Caption :=
        'Optional adaptive learning for this workspace (coming soon).';
    Dlg.ApplyTheme(ATheme);
    Dlg.ShowModal;
    Result := True;
  finally
    Dlg.Free;
  end;
end;

procedure TTheBrainConfigForm.ApplyTheme(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  ApplyFutureFeatureDialogTheme(Self, ATheme, lblComingSoon, lblTitle, lblSubtitle,
    memRoadmap, pnlBottom);
  pnlActions.Color := ThemePalette(ATheme).Surface;
  lblMemories.Font.Color := ThemePalette(ATheme).Text;
  chkEnableBrain.Font.Color := ThemePalette(ATheme).Text;
  ConfigureThemedListBox(lstMemories, ATheme);
end;

procedure TTheBrainConfigForm.FormShow(Sender: TObject);
begin
  lblTitle.Caption := NavigationFutureFeatureTitle(niTheBrain);
  FillFutureFeatureRoadmapMemo(niTheBrain, memRoadmap);
  chkEnableBrain.Checked := False;
  chkEnableBrain.Enabled := False;
  lstMemories.Items.Clear;
  lstMemories.Items.Add('(sample) Prefer existing project abstractions');
  lstMemories.Items.Add('(sample) Use Pascal naming conventions in .pas files');
  lstMemories.Enabled := False;
  btnReviewMemories.Enabled := False;
  memRoadmap.ReadOnly := True;
end;

procedure TTheBrainConfigForm.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
