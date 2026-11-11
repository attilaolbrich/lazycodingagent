unit uThemeHooks;

{$mode objfpc}{$H+}

interface

uses
  SynEdit, LcaTheme, LcaThemeHooks;

procedure RegisterThemeCustomHooks;
procedure ApplySynEditGutterTheme(AEd: TSynEdit; ATheme: TThemeKind);

implementation

uses
  Classes, SysUtils, Controls, Graphics;

type
  TThemeHookRegistry = class
  public
    function HookSynEdit(AControl: TControl; ATheme: TThemeKind): Boolean;
  end;

var
  ThemeHookRegistry: TThemeHookRegistry;
  GThemeHooksRegistered: Boolean = False;

procedure ApplySynEditGutterTheme(AEd: TSynEdit; ATheme: TThemeKind);
var
  P: TThemePalette;
  GutterBg, LineNumFg: TColor;
begin
  if not Assigned(AEd) then Exit;
  if not Assigned(AEd.Gutter) then Exit;
  P := ThemePalette(ATheme);
  if ATheme = tkDark then begin
    GutterBg := P.Background;
    LineNumFg := clWhite;
  end else begin
    GutterBg := clWhite;
    LineNumFg := clBlack;
  end;
  AEd.Gutter.Color := GutterBg;
  if Assigned(AEd.Gutter.LineNumberPart) then begin
    AEd.Gutter.LineNumberPart.MarkupInfo.Background := GutterBg;
    AEd.Gutter.LineNumberPart.MarkupInfo.Foreground := LineNumFg;
  end;
  if Assigned(AEd.Gutter.MarksPart) then
    AEd.Gutter.MarksPart.MarkupInfo.Background := GutterBg;
  if Assigned(AEd.Gutter.SeparatorPart) then begin
    AEd.Gutter.SeparatorPart.MarkupInfo.Background := GutterBg;
    AEd.Gutter.SeparatorPart.MarkupInfo.Foreground := P.TextMuted;
  end;
  if Assigned(AEd.Gutter.CodeFoldPart) then
    AEd.Gutter.CodeFoldPart.MarkupInfo.Foreground := P.TextMuted;
end;

function TThemeHookRegistry.HookSynEdit(AControl: TControl; ATheme: TThemeKind): Boolean;
var
  P: TThemePalette;
  Ed: TSynEdit;
begin
  Result := False;
  if not (AControl is TSynEdit) then Exit;
  Ed := TSynEdit(AControl);
  P := ThemePalette(ATheme);
  Ed.Color := P.SurfaceAlt;
  Ed.Font.Color := P.Text;
  ApplyThemedMonospaceFont(Ed.Font, Ed);
  Ed.ExtraCharSpacing := 0;
  if Ed.HandleAllocated then begin
    ApplySynEditGutterTheme(Ed, ATheme);
    ApplyPlatformScrollableTheme(Ed, ATheme);
    Ed.Invalidate;
  end;
  Result := True;
end;

procedure RegisterThemeCustomHooks;
begin
  if GThemeHooksRegistered then Exit;
  GThemeHooksRegistered := True;
  RegisterLcaThemeHooks;
  RegisterThemeCustomApply(@ThemeHookRegistry.HookSynEdit);
end;

initialization
  ThemeHookRegistry := TThemeHookRegistry.Create;

finalization
  FreeAndNil(ThemeHookRegistry);

end.
