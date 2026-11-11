unit frmEditRule;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, LCLType,
  LcaPaintButton, LcaPaintComboBox,
  uAppTypes, LcaTheme, LcaThemedMessageBox;

type
  { TEditRuleForm }
  TEditRuleForm = class(TForm)
    memoRule: TMemo;
    pnlBottom: TPanel;
    btnOK: TLcaPaintButton;
    btnCancel: TLcaPaintButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FTheme: TThemeKind;
    procedure ApplyTheme(ATheme: TThemeKind);
  public
    class function Execute(AOwner: TComponent; ATheme: TThemeKind; const ACaption, AInitialText: string;
      out ANewText: string): Boolean;
  end;

implementation

{$R *.lfm}

class function TEditRuleForm.Execute(AOwner: TComponent; ATheme: TThemeKind; const ACaption,
  AInitialText: string; out ANewText: string): Boolean;
var
  Dlg: TEditRuleForm;
begin
  Dlg := TEditRuleForm.Create(AOwner);
  try
    Dlg.Caption := ACaption;
    Dlg.FTheme := ATheme;
    Dlg.memoRule.Text := AInitialText;
    Dlg.ApplyTheme(ATheme);
    Result := Dlg.ShowModal = mrOk;
    if Result then
      ANewText := Dlg.memoRule.Text;
  finally
    Dlg.Free;
  end;
end;

procedure TEditRuleForm.FormCreate(Sender: TObject);
begin
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
end;

procedure TEditRuleForm.FormShow(Sender: TObject);
begin
  ApplyTheme(FTheme);
  ApplyFormPlatformThemes(Self, FTheme);
end;

procedure TEditRuleForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then begin
    Key := 0;
    btnCancelClick(Self);
  end else if (Key = VK_RETURN) and not (ssCtrl in Shift) and not (ssAlt in Shift) then begin
    if ActiveControl <> memoRule then begin
      Key := 0;
      btnOKClick(Self);
    end;
  end;
end;

procedure TEditRuleForm.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.Background;
  Font.Color := P.Text;
  Font.Name := 'Segoe UI';
  pnlBottom.Color := P.Surface;
  ApplyThemedForm(Self, ATheme);
  ConfigureThemedMemo(memoRule, ATheme);
  btnOK.ModalResult := mrOk;
  btnCancel.ModalResult := mrCancel;
  ApplyPlatformChrome(Self, ATheme);
  ApplyPlatformScrollableTheme(memoRule, ATheme);
end;

procedure TEditRuleForm.btnOKClick(Sender: TObject);
begin
  if Trim(memoRule.Text) = '' then begin
    LcaShowMessage('Enter a rule description.', FTheme);
    Exit;
  end;
  ModalResult := mrOk;
end;

procedure TEditRuleForm.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
