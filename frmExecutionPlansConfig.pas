unit frmExecutionPlansConfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  LcaPaintButton, uAppTypes, LcaTheme, uFutureFeatureFormCommon;

type
  { TExecutionPlansConfigForm }
  TExecutionPlansConfigForm = class(TForm)
    lblTitle: TLabel;
    lblComingSoon: TLabel;
    lblSubtitle: TLabel;
    lblPlans: TLabel;
    lstPlans: TListBox;
    pnlActions: TPanel;
    btnNewPlan: TLcaPaintButton;
    btnOpenTracker: TLcaPaintButton;
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

class function TExecutionPlansConfigForm.Execute(AOwner: TComponent; ATheme: TThemeKind;
  const AWorkspaceName: string): Boolean;
var
  Dlg: TExecutionPlansConfigForm;
begin
  Dlg := TExecutionPlansConfigForm.Create(AOwner);
  try
    Dlg.FTheme := ATheme;
    if Trim(AWorkspaceName) <> '' then
      Dlg.lblSubtitle.Caption := 'Workspace: ' + AWorkspaceName +
        '. Session tasks stay under Tasks & Plans in the nav rail; this dialog is for future project-level execution plans.'
    else
      Dlg.lblSubtitle.Caption :=
        'Project-level execution plans (coming soon). Use Tasks & Plans in the nav rail for live session todos.';
    Dlg.ApplyTheme(ATheme);
    Dlg.ShowModal;
    Result := True;
  finally
    Dlg.Free;
  end;
end;

procedure TExecutionPlansConfigForm.ApplyTheme(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  ApplyFutureFeatureDialogTheme(Self, ATheme, lblComingSoon, lblTitle, lblSubtitle,
    memRoadmap, pnlBottom);
  pnlActions.Color := ThemePalette(ATheme).Surface;
  lblPlans.Font.Color := ThemePalette(ATheme).Text;
  ConfigureThemedListBox(lstPlans, ATheme);
end;

procedure TExecutionPlansConfigForm.FormShow(Sender: TObject);
begin
  lblTitle.Caption := NavigationFutureFeatureTitle(niExecutionPlans);
  FillFutureFeatureRoadmapMemo(niExecutionPlans, memRoadmap);
  lstPlans.Items.Clear;
  lstPlans.Items.Add('001 — Authentication refresh (3/12 tasks)');
  lstPlans.Items.Add('002 — Knowledge base MVP (0/8 tasks)');
  lstPlans.Enabled := False;
  btnNewPlan.Enabled := False;
  btnOpenTracker.Enabled := False;
  memRoadmap.ReadOnly := True;
end;

procedure TExecutionPlansConfigForm.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
