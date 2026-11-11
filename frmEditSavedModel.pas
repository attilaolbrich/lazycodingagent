unit frmEditSavedModel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, LcaPaintButton, LcaPaintComboBox,
  uAppTypes, LcaTheme, LcaThemedMessageBox;

type
  { TEditSavedModelForm }
  TEditSavedModelForm = class(TForm)
    lblDisplayName: TLabel;
    edtDisplayName: TEdit;
    lblModelId: TLabel;
    edtModelId: TEdit;
    pnlBottom: TPanel;
    btnOK: TLcaPaintButton;
    btnCancel: TLcaPaintButton;
    procedure FormShow(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FTheme: TThemeKind;
    procedure ApplyTheme(ATheme: TThemeKind);
  public
    class function Execute(AOwner: TComponent; ATheme: TThemeKind;
      const ADisplayName, AModelId: string; out ANewDisplayName, ANewModelId: string): Boolean;
  end;

implementation

{$R *.lfm}

class function TEditSavedModelForm.Execute(AOwner: TComponent; ATheme: TThemeKind;
  const ADisplayName, AModelId: string; out ANewDisplayName, ANewModelId: string): Boolean;
var
  Dlg: TEditSavedModelForm;
begin
  Dlg := TEditSavedModelForm.Create(AOwner);
  try
    Dlg.FTheme := ATheme;
    Dlg.edtDisplayName.Text := ADisplayName;
    Dlg.edtModelId.Text := AModelId;
    Dlg.ApplyTheme(ATheme);
    Result := Dlg.ShowModal = mrOk;
    if Result then begin
      ANewDisplayName := Trim(Dlg.edtDisplayName.Text);
      ANewModelId := Trim(Dlg.edtModelId.Text);
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TEditSavedModelForm.FormShow(Sender: TObject);
begin
  ApplyTheme(FTheme);
  ApplyFormPlatformThemes(Self, FTheme);
end;

procedure TEditSavedModelForm.ApplyTheme(ATheme: TThemeKind);
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
  edtDisplayName.Color := P.SurfaceAlt;
  edtDisplayName.Font.Color := P.Text;
  edtModelId.Color := P.SurfaceAlt;
  edtModelId.Font.Color := P.Text;
  ApplyPlatformChrome(Self, ATheme);
end;

procedure TEditSavedModelForm.btnOKClick(Sender: TObject);
begin
  if Trim(edtModelId.Text) = '' then begin
    LcaShowMessage('Model id is required.', FTheme);
    Exit;
  end;
  ModalResult := mrOk;
end;

procedure TEditSavedModelForm.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
