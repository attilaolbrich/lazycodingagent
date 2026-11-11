unit frmPlanBuildConfirm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, LCLType,
  LcaPaintButton, uAppTypes, LcaTheme, LcaFormChrome;

type
  { TPlanBuildConfirmForm }
  TPlanBuildConfirmForm = class(TForm)
    lblMessage: TLabel;
    chkAllowModifyOutside: TCheckBox;
    lblAllowModifyOutside: TLabel;
    pnlBottom: TPanel;
    btnBuild: TLcaPaintButton;
    btnCancel: TLcaPaintButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnBuildClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure lblAllowModifyOutsideClick(Sender: TObject);
  private
    FTheme: TThemeKind;
    procedure ApplyTheme(ATheme: TThemeKind);
  public
    class function Execute(AOwner: TComponent; ATheme: TThemeKind;
      out AAllowModifyOutside: Boolean): Boolean;
  end;

implementation

{$R *.lfm}

class function TPlanBuildConfirmForm.Execute(AOwner: TComponent; ATheme: TThemeKind;
  out AAllowModifyOutside: Boolean): Boolean;
var
  Dlg: TPlanBuildConfirmForm;
begin
  AAllowModifyOutside := False;
  Dlg := TPlanBuildConfirmForm.Create(AOwner);
  try
    Dlg.FTheme := ATheme;
    Dlg.ApplyTheme(ATheme);
    Result := Dlg.ShowModal = mrOk;
    if Result then
      AAllowModifyOutside := Dlg.chkAllowModifyOutside.Checked;
  finally
    Dlg.Free;
  end;
end;

procedure TPlanBuildConfirmForm.FormCreate(Sender: TObject);
begin
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
end;

procedure TPlanBuildConfirmForm.FormShow(Sender: TObject);
begin
  ApplyTheme(FTheme);
  ApplyFormPlatformThemes(Self, FTheme);
end;

procedure TPlanBuildConfirmForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then begin
    Key := 0;
    btnCancelClick(Self);
  end else if (Key = VK_RETURN) and not (ssCtrl in Shift) and not (ssAlt in Shift) then begin
    Key := 0;
    btnBuildClick(Self);
  end;
end;

procedure TPlanBuildConfirmForm.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  P := ThemePalette(ATheme);
  ApplyThemedForm(Self, ATheme);
  Color := P.Surface;
  if Assigned(pnlBottom) then
    pnlBottom.Color := P.Surface;
  if Assigned(chkAllowModifyOutside) then
    ConfigureThemedCheckBox(chkAllowModifyOutside, ATheme);
  if Assigned(lblAllowModifyOutside) then
    lblAllowModifyOutside.Font.Color := P.Text;
  if Assigned(btnBuild) then
    btnBuild.ApplyTheme(ATheme);
  if Assigned(btnCancel) then
    btnCancel.ApplyTheme(ATheme);
end;

procedure TPlanBuildConfirmForm.btnBuildClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TPlanBuildConfirmForm.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TPlanBuildConfirmForm.lblAllowModifyOutsideClick(Sender: TObject);
begin
  if Assigned(chkAllowModifyOutside) then
    chkAllowModifyOutside.Checked := not chkAllowModifyOutside.Checked;
end;

end.
