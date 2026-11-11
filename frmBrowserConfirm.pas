unit frmBrowserConfirm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, LCLType,
  LcaPaintButton, uAppTypes, LcaTheme, LcaFormChrome;

function ConfirmSensitiveBrowserAction(const AMessage: string; ATheme: TThemeKind;
  out AAllowForSession: Boolean): Boolean;

type
  { TBrowserConfirmForm }
  TBrowserConfirmForm = class(TForm)
    lblMessage: TLabel;
    chkAllowForSession: TCheckBox;
    lblAllowForSession: TLabel;
    pnlBottom: TPanel;
    btnOk: TLcaPaintButton;
    btnCancel: TLcaPaintButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnOkClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure lblAllowForSessionClick(Sender: TObject);
  private
    FTheme: TThemeKind;
    procedure ApplyTheme(ATheme: TThemeKind);
  public
    class function Execute(AOwner: TComponent; const AMessage: string; ATheme: TThemeKind;
      out AAllowForSession: Boolean): Boolean;
  end;

implementation

{$R *.lfm}

function ConfirmSensitiveBrowserAction(const AMessage: string; ATheme: TThemeKind;
  out AAllowForSession: Boolean): Boolean;
begin
  Result := TBrowserConfirmForm.Execute(nil, AMessage, ATheme, AAllowForSession);
end;

class function TBrowserConfirmForm.Execute(AOwner: TComponent; const AMessage: string;
  ATheme: TThemeKind; out AAllowForSession: Boolean): Boolean;
var
  Dlg: TBrowserConfirmForm;
begin
  AAllowForSession := False;
  Dlg := TBrowserConfirmForm.Create(AOwner);
  try
    Dlg.lblMessage.Caption := AMessage;
    Dlg.FTheme := ATheme;
    Dlg.ApplyTheme(ATheme);
    Result := Dlg.ShowModal = mrOk;
    if Result then
      AAllowForSession := Dlg.chkAllowForSession.Checked;
  finally
    Dlg.Free;
  end;
end;

procedure TBrowserConfirmForm.FormCreate(Sender: TObject);
begin
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
end;

procedure TBrowserConfirmForm.FormShow(Sender: TObject);
begin
  ApplyTheme(FTheme);
  ApplyFormPlatformThemes(Self, FTheme);
end;

procedure TBrowserConfirmForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then begin
    Key := 0;
    btnCancelClick(Self);
  end else if (Key = VK_RETURN) and not (ssCtrl in Shift) and not (ssAlt in Shift) then begin
    Key := 0;
    btnOkClick(Self);
  end;
end;

procedure TBrowserConfirmForm.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  P := ThemePalette(ATheme);
  ApplyThemedForm(Self, ATheme);
  Color := P.Surface;
  if Assigned(pnlBottom) then
    pnlBottom.Color := P.Surface;
  if Assigned(chkAllowForSession) then
    ConfigureThemedCheckBox(chkAllowForSession, ATheme);
  if Assigned(lblAllowForSession) then
    lblAllowForSession.Font.Color := P.Text;
  if Assigned(lblMessage) then
    lblMessage.Font.Color := P.Text;
  if Assigned(btnOk) then
    btnOk.ApplyTheme(ATheme);
  if Assigned(btnCancel) then
    btnCancel.ApplyTheme(ATheme);
end;

procedure TBrowserConfirmForm.btnOkClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TBrowserConfirmForm.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TBrowserConfirmForm.lblAllowForSessionClick(Sender: TObject);
begin
  if Assigned(chkAllowForSession) then
    chkAllowForSession.Checked := not chkAllowForSession.Checked;
end;

end.
