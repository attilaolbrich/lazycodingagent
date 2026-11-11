unit uFutureFeatureFormCommon;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, LcaTheme,
  uAppTypes, uNavFuturePlaceholder;

procedure ApplyFutureFeatureDialogTheme(AForm: TForm; ATheme: TThemeKind;
  AComingSoon, ATitle, ASubtitle: TLabel; AMemo: TMemo; ABottomPanel: TPanel);
procedure FillFutureFeatureRoadmapMemo(ANavItem: TNavigationItem; AMemo: TMemo);

implementation

procedure ApplyFutureFeatureDialogTheme(AForm: TForm; ATheme: TThemeKind;
  AComingSoon, ATitle, ASubtitle: TLabel; AMemo: TMemo; ABottomPanel: TPanel);
var
  P: TThemePalette;
begin
  P := ThemePalette(ATheme);
  AForm.Color := P.Background;
  AForm.Font.Color := P.Text;
  AForm.Font.Name := 'Segoe UI';
  if Assigned(ABottomPanel) then
    ABottomPanel.Color := P.Surface;
  ApplyThemedForm(AForm, ATheme);
  if Assigned(ATitle) then
    ATitle.Font.Color := P.Text;
  if Assigned(ASubtitle) then
    ASubtitle.Font.Color := P.TextMuted;
  if Assigned(AComingSoon) then begin
    AComingSoon.Font.Color := P.Accent;
    AComingSoon.Font.Style := [fsBold];
  end;
  if Assigned(AMemo) then begin
    AMemo.Color := P.Surface;
    AMemo.Font.Color := P.Text;
  end;
  ApplyPlatformChrome(AForm, ATheme);
end;

procedure FillFutureFeatureRoadmapMemo(ANavItem: TNavigationItem; AMemo: TMemo);
var
  Lines: TStringList;
begin
  if not Assigned(AMemo) then Exit;
  Lines := TStringList.Create;
  try
    PopulateFutureFeatureNavList(ANavItem, Lines);
    AMemo.Lines.Assign(Lines);
  finally
    Lines.Free;
  end;
end;

end.
