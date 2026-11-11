unit frmSyntaxSchemes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, LcaPaintButton, LcaPaintComboBox,
  uAppTypes, LcaTheme, LcaThemedMessageBox, uSyntaxSchemeRegistry;

type
  { TSyntaxSchemesForm }
  TSyntaxSchemesForm = class(TForm)
    lblHint: TLabel;
    lstSchemes: TListBox;
    pnlActions: TPanel;
    btnAdd: TLcaPaintButton;
    btnRemove: TLcaPaintButton;
    btnSetActive: TLcaPaintButton;
    pnlBottom: TPanel;
    btnClose: TLcaPaintButton;
    procedure btnAddClick(Sender: TObject);
    procedure btnRemoveClick(Sender: TObject);
    procedure btnSetActiveClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure lstSchemesClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FTheme: TThemeKind;
    FRegistry: TSyntaxSchemeRegistry;
    FChanged: Boolean;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure RefreshList;
    function SelectedIndex: Integer;
  public
    class function Execute(AOwner: TComponent; ATheme: TThemeKind;
      ARegistry: TSyntaxSchemeRegistry; out AChanged: Boolean): Boolean;
  end;

implementation

{$R *.lfm}

class function TSyntaxSchemesForm.Execute(AOwner: TComponent; ATheme: TThemeKind;
  ARegistry: TSyntaxSchemeRegistry; out AChanged: Boolean): Boolean;
var
  Dlg: TSyntaxSchemesForm;
begin
  AChanged := False;
  Dlg := TSyntaxSchemesForm.Create(AOwner);
  try
    Dlg.FTheme := ATheme;
    Dlg.FRegistry := ARegistry;
    Dlg.ApplyTheme(ATheme);
    Dlg.RefreshList;
    Dlg.ShowModal;
    AChanged := Dlg.FChanged;
    Result := True;
  finally
    Dlg.Free;
  end;
end;

function TSyntaxSchemesForm.SelectedIndex: Integer;
begin
  Result := lstSchemes.ItemIndex;
end;

procedure TSyntaxSchemesForm.RefreshList;
var
  I: Integer;
  E: TSyntaxSchemeEntry;
  Cap: string;
begin
  if FRegistry = nil then Exit;
  lstSchemes.Items.BeginUpdate;
  try
    lstSchemes.Items.Clear;
    for I := 0 to FRegistry.Count - 1 do begin
      E := FRegistry.GetEntry(I);
      Cap := E.Name;
      if SameText(E.Id, FRegistry.ActiveId) then
        Cap := '● ' + Cap;
      if E.BuiltIn then
        Cap := Cap + ' (built-in)';
      lstSchemes.Items.AddObject(Cap, TObject(PtrInt(I)));
    end;
  finally
    lstSchemes.Items.EndUpdate;
  end;
  lstSchemesClick(Self);
end;

procedure TSyntaxSchemesForm.lstSchemesClick(Sender: TObject);
var
  Idx: Integer;
  E: TSyntaxSchemeEntry;
begin
  Idx := SelectedIndex;
  btnSetActive.Enabled := Idx >= 0;
  btnRemove.Enabled := False;
  if Idx < 0 then Exit;
  E := FRegistry.GetEntry(PtrInt(lstSchemes.Items.Objects[Idx]));
  btnRemove.Enabled := not E.BuiltIn;
  btnSetActive.Enabled := not SameText(E.Id, FRegistry.ActiveId);
end;

procedure TSyntaxSchemesForm.FormShow(Sender: TObject);
begin
  ApplyTheme(FTheme);
  ApplyFormPlatformThemes(Self, FTheme);
end;

procedure TSyntaxSchemesForm.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.Surface;
  lblHint.Font.Color := P.TextMuted;
  ConfigureThemedListBox(lstSchemes, ATheme);
  ApplyThemedForm(Self, ATheme);
end;

procedure TSyntaxSchemesForm.btnAddClick(Sender: TObject);
var
  Dlg: TOpenDialog;
  Err, NewId: string;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Title := 'Import syntax scheme (VS Code tokenColors JSON)';
    Dlg.Filter := 'JSON files (*.json)|*.json|All files (*.*)|*.*';
    if not Dlg.Execute then Exit;
    NewId := FRegistry.ImportFromFile(Dlg.FileName, Err);
    if NewId = '' then begin
      LcaMessageDlg('Syntax Schemes', 'Import failed: ' + Err, mtError, [mbOK], FTheme);
      Exit;
    end;
    FChanged := True;
    RefreshList;
  finally
    Dlg.Free;
  end;
end;

procedure TSyntaxSchemesForm.btnRemoveClick(Sender: TObject);
var
  Idx: Integer;
  E: TSyntaxSchemeEntry;
  Err: string;
begin
  Idx := SelectedIndex;
  if Idx < 0 then Exit;
  E := FRegistry.GetEntry(PtrInt(lstSchemes.Items.Objects[Idx]));
  if not FRegistry.Remove(E.Id, Err) then begin
    LcaMessageDlg('Syntax Schemes', Err, mtError, [mbOK], FTheme);
    Exit;
  end;
  FChanged := True;
  RefreshList;
end;

procedure TSyntaxSchemesForm.btnSetActiveClick(Sender: TObject);
var
  Idx: Integer;
  E: TSyntaxSchemeEntry;
begin
  Idx := SelectedIndex;
  if Idx < 0 then Exit;
  E := FRegistry.GetEntry(PtrInt(lstSchemes.Items.Objects[Idx]));
  FRegistry.SetActive(E.Id);
  FChanged := True;
  RefreshList;
end;

procedure TSyntaxSchemesForm.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
