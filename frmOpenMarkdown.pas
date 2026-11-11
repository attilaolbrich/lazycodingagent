unit frmOpenMarkdown;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, LcaPaintButton, LcaPaintComboBox,
  uAppTypes, LcaTheme;

type
  TMarkdownOpenChoice = (mocCancel, mocPreview, mocSource);

  { TOpenMarkdownForm }
  TOpenMarkdownForm = class(TForm)
    lblFile: TLabel;
    lblHint: TLabel;
    pnlActions: TPanel;
    btnPreview: TLcaPaintButton;
    btnSource: TLcaPaintButton;
    pnlBottom: TPanel;
    btnCancel: TLcaPaintButton;
    procedure btnPreviewClick(Sender: TObject);
    procedure btnSourceClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FTheme: TThemeKind;
    FChoice: TMarkdownOpenChoice;
    procedure ApplyTheme(ATheme: TThemeKind);
  public
    class function Execute(AOwner: TComponent; ATheme: TThemeKind;
      const AFilePath: string): TMarkdownOpenChoice;
  end;

implementation

{$R *.lfm}

class function TOpenMarkdownForm.Execute(AOwner: TComponent; ATheme: TThemeKind;
  const AFilePath: string): TMarkdownOpenChoice;
var
  Dlg: TOpenMarkdownForm;
begin
  Dlg := TOpenMarkdownForm.Create(AOwner);
  try
    Dlg.FTheme := ATheme;
    Dlg.FChoice := mocCancel;
    Dlg.lblFile.Caption := ExtractFileName(AFilePath);
    Dlg.lblFile.Hint := AFilePath;
    Dlg.lblFile.ShowHint := True;
    Dlg.ApplyTheme(ATheme);
    Dlg.ShowModal;
    Result := Dlg.FChoice;
  finally
    Dlg.Free;
  end;
end;

procedure TOpenMarkdownForm.FormShow(Sender: TObject);
begin
  ApplyTheme(FTheme);
  ApplyFormPlatformThemes(Self, FTheme);
end;

procedure TOpenMarkdownForm.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.Surface;
  lblFile.Font.Color := P.Text;
  lblFile.Font.Style := [fsBold];
  lblHint.Font.Color := P.TextMuted;
  ApplyThemedForm(Self, ATheme);
end;

procedure TOpenMarkdownForm.btnPreviewClick(Sender: TObject);
begin
  FChoice := mocPreview;
  Close;
end;

procedure TOpenMarkdownForm.btnSourceClick(Sender: TObject);
begin
  FChoice := mocSource;
  Close;
end;

procedure TOpenMarkdownForm.btnCancelClick(Sender: TObject);
begin
  FChoice := mocCancel;
  Close;
end;

end.
