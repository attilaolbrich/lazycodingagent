unit LcaThemedMessageBox;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Dialogs, LcaTheme, frmThemedMessage;

function LcaMessageDlg(const ACaption, AText: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; ATheme: TThemeKind): Integer;

procedure LcaShowMessage(const AText: string; ATheme: TThemeKind);

implementation

const
  DefaultAppCaption = 'LazyCodingAgent';

function LcaMessageDlg(const ACaption, AText: string; DlgType: TMsgDlgType;
  Buttons: TMsgDlgButtons; ATheme: TThemeKind): Integer;
var
  Dlg: TThemedMessageForm;
  Cap: string;
begin
  Cap := ACaption;
  if Cap = '' then
    Cap := DefaultAppCaption;
  Dlg := TThemedMessageForm.Create(Application);
  try
    Result := Dlg.Execute(Cap, AText, DlgType, Buttons, ATheme);
  finally
    Dlg.Free;
  end;
end;

procedure LcaShowMessage(const AText: string; ATheme: TThemeKind);
begin
  LcaMessageDlg(DefaultAppCaption, AText, mtInformation, [mbOK], ATheme);
end;

end.
