unit frmWorkspaceRules;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, LcaPaintButton, LcaPaintComboBox,
  uAppTypes, LcaTheme, LcaThemedMessageBox, uAgentRules, frmEditRule;

type
  { TWorkspaceRulesForm }
  TWorkspaceRulesForm = class(TForm)
    lblRules: TLabel;
    lstRules: TListBox;
    pnlActions: TPanel;
    btnAddRule: TLcaPaintButton;
    btnEditRule: TLcaPaintButton;
    btnDeleteRule: TLcaPaintButton;
    pnlBottom: TPanel;
    btnClose: TLcaPaintButton;
    procedure btnAddRuleClick(Sender: TObject);
    procedure btnEditRuleClick(Sender: TObject);
    procedure btnDeleteRuleClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure lstRulesDblClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FTheme: TThemeKind;
    FProjectRoot: string;
    FRuleFiles: TStringList;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure RefreshRules;
  public
    destructor Destroy; override;
    class function Execute(AOwner: TComponent; ATheme: TThemeKind; const AWorkspaceRoot: string): Boolean;
  end;

implementation

{$R *.lfm}

class function TWorkspaceRulesForm.Execute(AOwner: TComponent; ATheme: TThemeKind;
  const AWorkspaceRoot: string): Boolean;
var
  Dlg: TWorkspaceRulesForm;
begin
  Dlg := TWorkspaceRulesForm.Create(AOwner);
  try
    Dlg.FTheme := ATheme;
    Dlg.FProjectRoot := AWorkspaceRoot;
    Dlg.ApplyTheme(ATheme);
    Dlg.RefreshRules;
    Dlg.ShowModal;
    Result := True;
  finally
    Dlg.Free;
  end;
end;

destructor TWorkspaceRulesForm.Destroy;
begin
  FRuleFiles.Free;
  inherited Destroy;
end;

procedure TWorkspaceRulesForm.RefreshRules;
var
  I, BreakAt: Integer;
  Content, Summary: string;
begin
  if FRuleFiles = nil then
    FRuleFiles := TStringList.Create;
  TAgentRules.ListFiles(FProjectRoot, FRuleFiles);
  lstRules.Items.BeginUpdate;
  try
    lstRules.Items.Clear;
    for I := 0 to FRuleFiles.Count - 1 do begin
      Content := Trim(TAgentRules.ReadFile(FRuleFiles[I]));
      BreakAt := Pos(LineEnding, Content);
      if BreakAt = 0 then
        BreakAt := Pos(#10, Content);
      if BreakAt > 0 then
        Content := Copy(Content, 1, BreakAt - 1);
      Summary := Trim(Content);
      if Length(Summary) > 72 then
        Summary := Copy(Summary, 1, 69) + '...';
      if Summary = '' then
        Summary := '(empty rule)';
      lstRules.Items.Add(ExtractFileName(FRuleFiles[I]) + ' — ' + Summary);
    end;
  finally
    lstRules.Items.EndUpdate;
  end;
  btnEditRule.Enabled := lstRules.Items.Count > 0;
  btnDeleteRule.Enabled := lstRules.Items.Count > 0;
end;

procedure TWorkspaceRulesForm.FormShow(Sender: TObject);
begin
  ApplyTheme(FTheme);
  ApplyFormPlatformThemes(Self, FTheme);
end;

procedure TWorkspaceRulesForm.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.Background;
  Font.Color := P.Text;
  Font.Name := 'Segoe UI';
  pnlBottom.Color := P.Surface;
  pnlActions.Color := P.Surface;
  ApplyThemedForm(Self, ATheme);
  ConfigureThemedListBox(lstRules, ATheme);
  lblRules.Font.Color := P.Text;
  ApplyPlatformChrome(Self, ATheme);
end;

procedure TWorkspaceRulesForm.btnAddRuleClick(Sender: TObject);
var
  Content: string;
begin
  if not TEditRuleForm.Execute(Self, FTheme, 'Add Project Rule', '', Content) then Exit;
  try
    TAgentRules.CreateRule(FProjectRoot, Content);
    RefreshRules;
    lstRules.ItemIndex := lstRules.Items.Count - 1;
  except
    on E: Exception do
      LcaShowMessage('Could not add rule: ' + E.Message, FTheme);
  end;
end;

procedure TWorkspaceRulesForm.btnEditRuleClick(Sender: TObject);
var
  I: Integer;
  Content, UpdatedContent: string;
begin
  I := lstRules.ItemIndex;
  if (I < 0) or (I >= FRuleFiles.Count) then Exit;
  Content := TAgentRules.ReadFile(FRuleFiles[I]);
  if not TEditRuleForm.Execute(Self, FTheme, 'Edit Project Rule', Content, UpdatedContent) then Exit;
  try
    TAgentRules.WriteFile(FRuleFiles[I], UpdatedContent);
    RefreshRules;
    lstRules.ItemIndex := I;
  except
    on E: Exception do
      LcaShowMessage('Could not update rule: ' + E.Message, FTheme);
  end;
end;

procedure TWorkspaceRulesForm.btnDeleteRuleClick(Sender: TObject);
var
  I: Integer;
begin
  I := lstRules.ItemIndex;
  if (I < 0) or (I >= FRuleFiles.Count) then Exit;
  if LcaMessageDlg('Project Rules', 'Delete this project rule?', mtConfirmation,
    [mbYes, mbNo], FTheme) <> mrYes then Exit;
  try
    if not DeleteFile(FRuleFiles[I]) then
      raise Exception.Create('Could not delete rule file.');
    RefreshRules;
  except
    on E: Exception do
      LcaShowMessage('Could not delete rule: ' + E.Message, FTheme);
  end;
end;

procedure TWorkspaceRulesForm.lstRulesDblClick(Sender: TObject);
begin
  if btnEditRule.Enabled then
    btnEditRuleClick(Sender);
end;

procedure TWorkspaceRulesForm.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
