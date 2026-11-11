unit LcaThemeHooks;

{$mode objfpc}{$H+}

interface

procedure RegisterLcaThemeHooks;

implementation

uses
  Classes, SysUtils, Controls, Terminal.View.LCL, LcaTheme, LcaThemedPageTabBar, LcaThemedButton,
  LcaThemedComboBox, LcaNavRailButton, LcaSurfacePanel, LcaMarkdownView, LcaTerminalPanel,
  LcaThemedMenuBar, LcaThemedTitleBar, LcaScrollHost, LcaThemedControl,
  LcaThemedGroupBox;

type
  TLcaThemeHookRegistry = class
  public
    function HookLcaControl(AControl: TControl; ATheme: TThemeKind): Boolean;
    function HookTerminalView(AControl: TControl; ATheme: TThemeKind): Boolean;
  end;

var
  LcaThemeHookRegistry: TLcaThemeHookRegistry;
  GLcaThemeHooksRegistered: Boolean = False;

function TLcaThemeHookRegistry.HookLcaControl(AControl: TControl; ATheme: TThemeKind): Boolean;
begin
  Result := False;
  if not Assigned(AControl) then Exit;
  if AControl is TLcaThemedPageTabBar then begin
    TLcaThemedPageTabBar(AControl).ApplyTheme(ATheme);
    Exit(True);
  end;
  if AControl is TLcaThemedButton then begin
    TLcaThemedButton(AControl).ApplyTheme(ATheme);
    Exit(True);
  end;
  if AControl is TLcaThemedComboBox then begin
    TLcaThemedComboBox(AControl).ApplyTheme(ATheme);
    Exit(True);
  end;
  if AControl is TLcaNavRailButton then begin
    TLcaNavRailButton(AControl).ApplyTheme(ATheme);
    Exit(True);
  end;
  if AControl is TLcaSurfacePanel then begin
    TLcaSurfacePanel(AControl).ApplyTheme(ATheme);
    Exit(True);
  end;
  if AControl is TLcaMarkdownView then begin
    TLcaMarkdownView(AControl).ApplyTheme(ATheme);
    Exit(True);
  end;
  if AControl is TLcaTerminalPanel then begin
    TLcaTerminalPanel(AControl).ApplyTheme(ATheme);
    Exit(True);
  end;
  if AControl is TLcaThemedMenuBar then begin
    TLcaThemedMenuBar(AControl).ApplyTheme(ATheme);
    Exit(True);
  end;
  if AControl is TLcaThemedTitleBar then begin
    TLcaThemedTitleBar(AControl).ApplyTheme(ATheme);
    Exit(True);
  end;
  if AControl is TLcaScrollHost then begin
    TLcaScrollHost(AControl).ApplyTheme(ATheme);
    Exit(True);
  end;
  if AControl is TLcaThemedGroupBox then begin
    TLcaThemedGroupBox(AControl).ApplyTheme(ATheme);
    Exit(True);
  end;
  if AControl is TLcaThemedControl then begin
    TLcaThemedControl(AControl).ApplyTheme(ATheme);
    Exit(True);
  end;
end;

function TLcaThemeHookRegistry.HookTerminalView(AControl: TControl; ATheme: TThemeKind): Boolean;
var
  P: TThemePalette;
  View: TTerminalLCLView;
begin
  Result := False;
  if not (AControl is TTerminalLCLView) then Exit;
  View := TTerminalLCLView(AControl);
  P := ThemePalette(ATheme);
  View.Color := P.SurfaceAlt;
  View.Font.Color := P.Text;
  View.FontName := ThemedMonospaceFontName;
  View.FontSize := ScaledEditorFontSize(View);
  View.Invalidate;
  Result := True;
end;

procedure RegisterLcaThemeHooks;
begin
  if GLcaThemeHooksRegistered then Exit;
  GLcaThemeHooksRegistered := True;
  RegisterThemeCustomApply(@LcaThemeHookRegistry.HookLcaControl);
  RegisterThemeCustomApply(@LcaThemeHookRegistry.HookTerminalView);
end;

initialization
  LcaThemeHookRegistry := TLcaThemeHookRegistry.Create;

finalization
  FreeAndNil(LcaThemeHookRegistry);

end.
