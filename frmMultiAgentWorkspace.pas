unit frmMultiAgentWorkspace;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  LcaPaintButton, LcaPaintComboBox, uAppTypes, LcaTheme, uFutureFeatureFormCommon;

type
  { TMultiAgentWorkspaceForm }
  TMultiAgentWorkspaceForm = class(TForm)
    lblTitle: TLabel;
    lblComingSoon: TLabel;
    lblSubtitle: TLabel;
    lblAgents: TLabel;
    lstAgents: TListBox;
    lblWorkflow: TLabel;
    cboWorkflow: TLcaPaintComboBox;
    pnlActions: TPanel;
    btnAddAgent: TLcaPaintButton;
    btnEditWorkflow: TLcaPaintButton;
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

class function TMultiAgentWorkspaceForm.Execute(AOwner: TComponent; ATheme: TThemeKind;
  const AWorkspaceName: string): Boolean;
var
  Dlg: TMultiAgentWorkspaceForm;
begin
  Dlg := TMultiAgentWorkspaceForm.Create(AOwner);
  try
    Dlg.FTheme := ATheme;
    if Trim(AWorkspaceName) <> '' then
      Dlg.lblSubtitle.Caption := 'Workspace: ' + AWorkspaceName +
        ' — preview only; agents and orchestration are not available yet.'
    else
      Dlg.lblSubtitle.Caption :=
        'Select a workspace to configure multi-agent workflows (coming soon).';
    Dlg.ApplyTheme(ATheme);
    Dlg.ShowModal;
    Result := True;
  finally
    Dlg.Free;
  end;
end;

procedure TMultiAgentWorkspaceForm.ApplyTheme(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  ApplyFutureFeatureDialogTheme(Self, ATheme, lblComingSoon, lblTitle, lblSubtitle,
    memRoadmap, pnlBottom);
  pnlActions.Color := ThemePalette(ATheme).Surface;
  lblAgents.Font.Color := ThemePalette(ATheme).Text;
  lblWorkflow.Font.Color := ThemePalette(ATheme).Text;
  ConfigureThemedListBox(lstAgents, ATheme);
end;

procedure TMultiAgentWorkspaceForm.FormShow(Sender: TObject);
begin
  lblTitle.Caption := NavigationFutureFeatureTitle(niMultiAgent);
  FillFutureFeatureRoadmapMemo(niMultiAgent, memRoadmap);
  lstAgents.Items.Clear;
  lstAgents.Items.Add('Planner — draft execution plans');
  lstAgents.Items.Add('Coder — implement approved scope');
  lstAgents.Items.Add('Red-Pen Reviewer — challenge assumptions');
  lstAgents.Items.Add('Code Reviewer — correctness and maintainability');
  cboWorkflow.Items.Clear;
  cboWorkflow.Items.Add('Sequential: Plan → Approve → Code → Review');
  cboWorkflow.ItemIndex := 0;
  lstAgents.Enabled := False;
  cboWorkflow.Enabled := False;
  btnAddAgent.Enabled := False;
  btnEditWorkflow.Enabled := False;
  memRoadmap.ReadOnly := True;
end;

procedure TMultiAgentWorkspaceForm.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
