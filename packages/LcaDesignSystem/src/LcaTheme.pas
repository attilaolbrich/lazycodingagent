unit LcaTheme;

{$mode objfpc}{$H+}
{$IFDEF LCLcocoa}{$modeswitch objectivec1}{$ENDIF}

interface

uses
  Classes, Controls, Graphics, Forms, StdCtrls, ExtCtrls, ComCtrls, Buttons,
  Menus, LCLType, Types;

type
  TThemeKind = (tkDark, tkLight);
  TThemedButtonRole = (tbrPrimary, tbrCancel, tbrDestructive, tbrGhost);

  TThemePalette = record
    Background: TColor;      // Main background (e.g. deepest charcoal / soft light gray)
    Surface: TColor;         // Panel surface
    SurfaceAlt: TColor;      // Input / secondary surface
    HeaderBg: TColor;        // Header strip background
    TitleBarBg: TColor;      // Frameless title bar (menu + window buttons)
    MenuFlyoutBg: TColor;    // Main menu dropdown panel
    RailBg: TColor;          // Left navigation rail background
    RailActiveBg: TColor;    // Selected nav rail cell
    Border: TColor;          // Visible crisp boundary borders
    BorderStrong: TColor;    // Prominent boundary / active splitters
    Text: TColor;            // Primary high-contrast text
    TextMuted: TColor;       // Secondary / hint text
    { Chat history labels in TLcaMarkdownView (You / Agent / tool / thinking). }
    ChatLabelUser: TColor;
    ChatLabelAgent: TColor;
    ChatLabelTool: TColor;
    ChatLabelThinking: TColor;
    Accent: TColor;          // Vivid brand / active blue
    AccentHover: TColor;     // Hover state blue
    AccentActive: TColor;    // Active tab / item background
    AccentText: TColor;      // Text on accent
    SplitterColor: TColor;   // Resizing splitter bar
    CardBg: TColor;          // Cards and message pill background
  end;

function ThemePalette(ATheme: TThemeKind): TThemePalette;
{ True when the control or an owner is on a form open in the Lazarus designer. }
function LcaComponentOrOwnerDesigning(AComponent: TComponent): Boolean;
{ Form designer, IDE-hosted preview, or JIT .lfm load before csDesigning is set. }
function LcaInDesignContext(const AComponent: TComponent): Boolean;
{ Lazarus designer uses the light palette so streamed dark-theme forms stay readable. }
function EffectiveControlTheme(const AComponent: TComponent; AStored: TThemeKind): TThemeKind;
{ True when ParamStr(0) is the lazarus or startlazarus IDE binary. }
function LazarusIdeHostExecutable: Boolean;
function ParentFormHandlesReady(AControl: TControl): Boolean;

const
  { Layout metrics (delivery 002+): logical px at 96 DPI — scale with ScaledLayoutMetric.
    Geometry owner = streamed .lfm Width/Height/Align/Anchors plus these tokens.
    Theme/paint helpers must not SetBounds on controls whose geometry lives in .lfm. }
  { Fallback until the widget handle exists; GTK/Qt often normalize to 25. }
  ThemedComboBoxHeight = 25;
  ThemedComboBoxItemHeight = 22;
  ThemedTabBarBaseHeight = 38;
  ThemedMenuBarBaseHeight = 36;
  ThemedMenuPopupItemBaseHeight = 28;
  { Menu bar caption — logical pt like ThemedTabFontSize (not PPI-scaled again). }
  ThemedMenuBarFontSizeBase = 10;
  { Logical pt for combo/list metrics — do not PPI-scale ad hoc. }
  ThemedTabFontSize = 9;
  { Close column and min tab width at 96 DPI — scaled via ScaledThemedTabMetric. }
  ThemedTabCloseColumnBase = 28;
  ThemedTabHorizPadBase = 8;
  ThemedTabMinWidthBase = 72;
  ThemedTabMinWidthClosableBase = 96;
  ThemedTabAddMinWidthBase = 48;
  ThemedTabVertInsetBase = 2;
  ThemedTabBetweenGapBase = 4;
  ThemedButtonCornerBase = 8;
  ThemedComboCornerBase = 6;
  ThemedComboChevronGutterBase = 22;
  { Logical pt for button captions — like ThemedTabFontSize; LCL scales on DPI-aware forms. }
  ThemedButtonFontSizeBase = 9;
  { TLcaMarkdownView body — logical pt; do not MulDiv (LCL scales on DPI-aware forms). }
  ThemedMarkdownBodyFontSizeBase = 11;
  ThemedButtonHorizPadBase = 14;
  ThemedButtonVertPadBase = 2;
  ThemedButtonDescentSafetyBase = 1;
  ThemedButtonHeightBase = 28;
  { SynEdit + terminal — logical pt; LCL scales on DPI-aware forms; do not MulDiv. }
  ThemedEditorFontSizeBase = 11;
  { Utility Execution Detail memo — logical pt; LCL scales on DPI-aware forms (no MulDiv). }
  ThemedExecDetailFontSizeBase = 10;
  { Main form left nav list boxes — owner-draw row metrics. }
  ThemedNavListItemHeight = 32;
  ThemedNavListPadLeft = 14;
  ThemedNavListPadV = 2;
  ThemedNavListRowGap = 0;
  { Painted scroll host (TLcaScrollHost) — bar thickness at 96 DPI. }
  ThemedScrollbarThicknessBase = 12;
  { Frameless title bar window buttons (min/max/close). }
  ThemedWindowChromeButtonBaseWidth = 46;

function ThemedLayoutPixelsPerInch(AControl: TControl): Integer;
function ScaledLayoutMetric(AControl: TControl; ABaseAt96: Integer): Integer;
function ScaledThemedTabMetric(AControl: TControl; ABaseAt96: Integer): Integer;
function ScaledThemedScrollbarThickness(AControl: TControl): Integer;
function ScaledThemedNavListItemHeight(AControl: TControl): Integer;
function ScaledThemedNavListPadLeft(AControl: TControl): Integer;
function ScaledThemedNavListPadV(AControl: TControl): Integer;
function ScaledThemedNavListRowGap(AControl: TControl): Integer;
function ThemedButtonCornerRadius(AControl: TControl): Integer;
function ThemedButtonFontSize(AControl: TControl): Integer;
function ThemedMarkdownBodyFontSize(AControl: TControl): Integer;
function ThemedButtonHorizPad(AControl: TControl): Integer;
function ThemedButtonVertPad(AControl: TControl): Integer;
function ScaledThemedButtonHeight(AControl: TControl): Integer;
function MeasureThemedButtonWidth(AControl: TControl; const ACaption: string;
  ARole: TThemedButtonRole; AMinWidth: Integer = 0): Integer;
function ScaledThemedTabBarHeight(AControl: TControl): Integer;
function ThemedTabCloseColumn(AControl: TControl): Integer;
function ThemedTabAddMinWidth(AControl: TControl): Integer;
function ThemedTabHorizPad(AControl: TControl): Integer;
function ThemedTabVertInset(AControl: TControl): Integer;
function ThemedTabBetweenGap(AControl: TControl): Integer;
function ThemedTabCloseHitRect(const ARect: TRect; AControl: TControl): TRect;
function ScaledThemedMenuBarHeight(AControl: TControl): Integer;
function ScaledThemedWindowChromeButtonWidth(AControl: TControl): Integer;
function ScaledThemedMenuPopupItemHeight(AControl: TControl): Integer;
function MenuItemDisplayCaption(const ACaption: string): string;
function ThemedEditorFontSize(AControl: TControl): Integer;
function ScaledEditorFontSize(AControl: TControl): Integer;
function ThemedMonospaceFontName: string;
function ThemedUiFontName: string;
procedure ApplyThemedMonospaceFont(AFont: TFont; AMetricsControl: TControl);
function ThemedComboCornerRadius(AControl: TControl): Integer;
function ThemedComboChevronGutter(AControl: TControl): Integer;

procedure PaintThemedMenuBarItem(Canvas: TCanvas; const ARect: TRect; const ACaption: string;
  ASelected: Boolean; ATheme: TThemeKind; AFontSize: Integer; AChromeBg: TColor = clNone);
procedure ThemedMenuPopupDrawItem(ACanvas: TCanvas; const ARect: TRect;
  State: TOwnerDrawState; ATheme: TThemeKind; ASource: TMenuItem);

// Owner-draw colors/font for ComboBox; preserves Height/ItemHeight from the form resource.
procedure StyleComboBox(ACombo: TComboBox; ATheme: TThemeKind);
// Read-only row height estimate for panels around a combo (do not pass to SetBounds height).
function EffectiveThemedComboBoxHeight(ACombo: TComboBox): Integer;
function ThemedComboItemHeightForControl(ADesignHeight, ADesignItemHeight: Integer): Integer;
// Unified DrawItem handler for styled ComboBoxes (Black style on dark mode, clean on light mode)
procedure StyleComboBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState; ATheme: TThemeKind);
procedure PaintThemedComboListItem(Canvas: TCanvas; const ARect: TRect;
  const AText: string; State: TOwnerDrawState; ATheme: TThemeKind);

procedure StylePageControl(APageControl: TPageControl; ATheme: TThemeKind);
{ Re-apply ShowTabs=False for TLcaThemedPageTabBar hosts (GTK may ignore until relayout). }
procedure EnforcePageControlHiddenTabs(APageControl: TPageControl);
procedure ApplyControlTheme(AControl: TControl; ATheme: TThemeKind);

procedure PaintThemedTab(Canvas: TCanvas; const ARect: TRect; const ACaption: string;
  AActive, AHover: Boolean; AShowClose, ACloseHover: Boolean; ATheme: TThemeKind;
  AMetricsControl: TControl = nil; ACenterCaption: Boolean = False);

procedure PaintThemedButton(Canvas: TCanvas; const ARect: TRect; ATheme: TThemeKind;
  ARole: TThemedButtonRole; const ACaption: string; AEnabled, AHover, APressed, AFocused: Boolean;
  ACornerRadius, AFontSize, AHorizPad: Integer; AMetricsControl: TControl = nil);

procedure PaintThemedComboField(Canvas: TCanvas; const ARect: TRect; ATheme: TThemeKind;
  const AText: string; AEnabled, AFocused, ADropped, AShowFocusRing: Boolean;
  ACornerRadius, AChevronGutter: Integer);

procedure StyleThemedButtonRole(ABtn: TButton; ATheme: TThemeKind; ARole: TThemedButtonRole);
procedure StylePrimaryButton(ABtn: TButton; ATheme: TThemeKind);
procedure StyleCancelButton(ABtn: TButton; ATheme: TThemeKind);
procedure StyleDestructiveButton(ABtn: TButton; ATheme: TThemeKind);
procedure StyleGhostButton(ABtn: TButton; ATheme: TThemeKind);

procedure ConfigureThemedListBox(AList: TListBox; ATheme: TThemeKind);
procedure ConfigureThemedTreeView(ATree: TTreeView; ATheme: TThemeKind);
procedure ConfigureThemedCheckBox(ACheck: TCheckBox; ATheme: TThemeKind);
procedure ConfigureThemedRadioButton(ARadio: TRadioButton; ATheme: TThemeKind);
{ Checkbox/radio caption on a TLabel avoids Win32 black caption text on dark tab pages. }
procedure StyleThemedToggleCaptionLabel(ALabel: TLabel; ATheme: TThemeKind);
procedure StyleThemedSectionLabel(ALabel: TLabel; ATheme: TThemeKind);
procedure ConfigureThemedMemo(AMemo: TCustomMemo; ATheme: TThemeKind;
  const AFontName: string = 'Segoe UI'; ABackground: TColor = clNone);
procedure ConfigureThemedExecDetailMemo(AMemo: TCustomMemo; ATheme: TThemeKind);
procedure SyncThemedMemoWidget(AMemo: TCustomMemo);
procedure SyncThemedEditWidget(AEdit: TCustomEdit);
procedure SyncThemedListBoxWidget(AList: TCustomListBox);
procedure ThemedListBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState; ATheme: TThemeKind);
procedure ThemedNavListBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState; ATheme: TThemeKind);
procedure PaintThemedNavListItem(Canvas: TCanvas; const ARect: TRect;
  const AText: string; State: TOwnerDrawState; ATheme: TThemeKind;
  AMetricsControl: TControl = nil);
procedure PaintThemedNavRailCell(Canvas: TCanvas; const ARect: TRect; const P: TThemePalette;
  AActive, AHover, APressed: Boolean);

procedure ApplyWin32ScrollableTheme(AControl: TWinControl; ATheme: TThemeKind);
procedure ApplyWin32ScrollableThemeRecursive(AControl: TWinControl; ATheme: TThemeKind);
procedure ApplyWin32FormChrome(AForm: TForm; ATheme: TThemeKind);

procedure ApplyPlatformScrollableTheme(AControl: TWinControl; ATheme: TThemeKind);
procedure ApplyPlatformScrollableThemeRecursive(AControl: TWinControl; ATheme: TThemeKind);
procedure ApplyFormPlatformThemes(AForm: TCustomForm; ATheme: TThemeKind);
procedure ApplyPlatformChrome(AForm: TForm; ATheme: TThemeKind);

type
  TThemeCustomApplyProc = function(AControl: TControl; ATheme: TThemeKind): Boolean of object;

procedure RegisterThemeCustomApply(const AProc: TThemeCustomApplyProc);
procedure ApplyThemedButtonControl(ABtn: TButton; ATheme: TThemeKind);
procedure ApplyThemedControlTree(ARoot: TWinControl; ATheme: TThemeKind);
procedure ApplyThemedForm(AForm: TCustomForm; ATheme: TThemeKind);
{ Ensures panel background paints on Cocoa/GTK (ParentColor off) and sets default text color. }
procedure ApplyThemedPanelColors(APanel: TPanel; AColor: TColor; ATheme: TThemeKind);

type
  TThemedButtonFrameApplyProc = procedure(AControl: TControl; ATheme: TThemeKind);

var
  ThemedButtonFrameApplyTheme: TThemedButtonFrameApplyProc = nil;

implementation

uses
  Math, SysUtils, LCLIntf, LCLProc, LcaPaintPrimitives, LcaThemedButton, LcaThemedComboBox,
  LcaThemedButtonPaint
  {$IFDEF WINDOWS}, LcaThemeWin32Buttons{$ENDIF}
  {$IFDEF LCLQt5}, Qt5, QtWidgets{$ENDIF}
  {$IFDEF LCLGtk3}, LazGtk3, LazGdk3, LazGObject2{$ENDIF}
  {$IFDEF LCLGtk2}, gtk2, gdk2, glib2{$ENDIF}
  {$IFDEF LCLcocoa}, CocoaAll, CocoaUtils{$ENDIF}
  ;

procedure ApplyWin32ToggleCaptionOpaqueStyle(AWin: TWinControl);
begin
  if not Assigned(AWin) then Exit;
  { Win32 tab pages: without csOpaque, WM_CTLCOLORBTN parent-paint path skips SetTextColor. }
  AWin.ControlStyle := AWin.ControlStyle + [csOpaque] - [csParentBackground];
{$IFDEF WINDOWS}
  if AWin.HandleAllocated then
    RecreateWnd(AWin);
{$ENDIF}
end;

function ParentFormHandlesReady(AControl: TControl): Boolean;
var
  F: TCustomForm;
begin
  if not Assigned(AControl) then
    Exit(False);
  F := GetParentForm(AControl);
  Result := Assigned(F) and F.HandleAllocated;
end;

function ThemedLayoutPixelsPerInch(AControl: TControl): Integer;
var
  F: TCustomForm;
begin
  Result := 96;
  if not Assigned(AControl) then Exit;
  F := GetParentForm(AControl);
  if (F <> nil) and (F.PixelsPerInch > 0) then
    Exit(F.PixelsPerInch);
  if Screen.PixelsPerInch > 0 then
    Result := Screen.PixelsPerInch;
end;

function ScaledLayoutMetric(AControl: TControl; ABaseAt96: Integer): Integer;
begin
  Result := MulDiv(ABaseAt96, ThemedLayoutPixelsPerInch(AControl), 96);
end;

function ScaledThemedTabMetric(AControl: TControl; ABaseAt96: Integer): Integer;
begin
  Result := ScaledLayoutMetric(AControl, ABaseAt96);
end;

function ScaledThemedScrollbarThickness(AControl: TControl): Integer;
begin
  Result := ScaledLayoutMetric(AControl, ThemedScrollbarThicknessBase);
end;

function ScaledThemedNavListItemHeight(AControl: TControl): Integer;
begin
  Result := ScaledLayoutMetric(AControl, ThemedNavListItemHeight);
end;

function ScaledThemedNavListPadLeft(AControl: TControl): Integer;
begin
  Result := ScaledLayoutMetric(AControl, ThemedNavListPadLeft);
end;

function ScaledThemedNavListPadV(AControl: TControl): Integer;
begin
  Result := ScaledLayoutMetric(AControl, ThemedNavListPadV);
end;

function ScaledThemedNavListRowGap(AControl: TControl): Integer;
begin
  Result := ScaledLayoutMetric(AControl, ThemedNavListRowGap);
end;

function ScaledThemedTabBarHeight(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedTabBarBaseHeight);
end;

function ThemedTabCloseColumn(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedTabCloseColumnBase);
end;

function ThemedTabAddMinWidth(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedTabAddMinWidthBase);
end;

function ThemedTabHorizPad(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedTabHorizPadBase);
end;

function ThemedTabVertInset(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedTabVertInsetBase);
end;

function ThemedTabBetweenGap(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedTabBetweenGapBase);
end;

function ThemedTabCloseHitRect(const ARect: TRect; AControl: TControl): TRect;
var
  R: TRect;
  CloseCol, EdgePad, VertPad: Integer;
begin
  R := ARect;
  Dec(R.Right);
  Dec(R.Bottom);
  CloseCol := ThemedTabCloseColumn(AControl);
  EdgePad := ScaledThemedTabMetric(AControl, 4);
  VertPad := ScaledThemedTabMetric(AControl, 3);
  Result.Left := R.Right - CloseCol;
  Result.Top := R.Top + VertPad;
  Result.Right := R.Right - EdgePad;
  Result.Bottom := R.Bottom - VertPad;
end;

function ScaledThemedMenuBarHeight(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedMenuBarBaseHeight);
end;

function ScaledThemedWindowChromeButtonWidth(AControl: TControl): Integer;
begin
  Result := ScaledLayoutMetric(AControl, ThemedWindowChromeButtonBaseWidth);
end;

function ScaledThemedMenuPopupItemHeight(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedMenuPopupItemBaseHeight);
end;

function MenuItemDisplayCaption(const ACaption: string): string;
var
  I: Integer;
begin
  Result := ACaption;
  I := 1;
  while I <= Length(Result) do begin
    if Result[I] = '&' then
      Delete(Result, I, 1)
    else
      Inc(I);
  end;
end;

function ThemedEditorFontSize({%H-}AControl: TControl): Integer;
begin
  Result := ThemedEditorFontSizeBase;
end;

{ Legacy name — returns logical pt only; no PPI MulDiv. }
function ScaledEditorFontSize(AControl: TControl): Integer;
begin
  Result := ThemedEditorFontSize(AControl);
end;

function ThemedMonospaceFontName: string;

  function PickFirstAvailable(const ANames: array of string): string;
  var
    I: Integer;
  begin
    for I := Low(ANames) to High(ANames) do
      if Screen.Fonts.IndexOf(ANames[I]) >= 0 then
        Exit(ANames[I]);
    Result := 'Monospace';
  end;

begin
  {$IFDEF LCLcocoa}
  Result := PickFirstAvailable(['Menlo', 'SF Mono', 'Monaco', 'Courier New', 'Monospace']);
  {$ELSE}
  {$IFDEF WINDOWS}
  Result := PickFirstAvailable(['Cascadia Mono', 'Consolas', 'Courier New', 'DejaVu Sans Mono']);
  {$ELSE}
  Result := PickFirstAvailable(['DejaVu Sans Mono', 'Liberation Mono', 'FreeMono', 'Monospace',
    'Courier New']);
  {$ENDIF}
  {$ENDIF}
end;

function ThemedUiFontName: string;

  function PickFirstAvailable(const ANames: array of string): string;
  var
    I: Integer;
  begin
    for I := Low(ANames) to High(ANames) do
      if Screen.Fonts.IndexOf(ANames[I]) >= 0 then
        Exit(ANames[I]);
    Result := 'sans-serif';
  end;

begin
  {$IFDEF LCLcocoa}
  Result := PickFirstAvailable(['.AppleSystemUIFont', 'SF Pro Text', 'Helvetica Neue', 'Helvetica']);
  {$ELSE}
  {$IFDEF WINDOWS}
  Result := PickFirstAvailable(['Segoe UI', 'Tahoma', 'Arial']);
  {$ELSE}
  Result := PickFirstAvailable(['Segoe UI', 'Ubuntu', 'Cantarell', 'DejaVu Sans', 'sans-serif']);
  {$ENDIF}
  {$ENDIF}
end;

procedure ApplyThemedMonospaceFont(AFont: TFont; AMetricsControl: TControl);
begin
  if not Assigned(AFont) then Exit;
  AFont.Name := ThemedMonospaceFontName;
  AFont.Pitch := fpFixed;
  AFont.Size := ThemedEditorFontSize(AMetricsControl);
end;

function ThemedComboCornerRadius(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedComboCornerBase);
end;

function ThemedComboChevronGutter(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedComboChevronGutterBase);
end;

function ThemedButtonCornerRadius(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedButtonCornerBase);
end;

function ThemedButtonFontSize({%H-}AControl: TControl): Integer;
begin
  Result := ThemedButtonFontSizeBase;
end;

function ThemedMarkdownBodyFontSize({%H-}AControl: TControl): Integer;
begin
  Result := ThemedMarkdownBodyFontSizeBase;
end;

function ThemedButtonHorizPad(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedButtonHorizPadBase);
end;

function ThemedButtonVertPad(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedButtonVertPadBase);
end;

function ScaledThemedButtonHeight(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, ThemedButtonHeightBase);
end;

function MeasureThemedButtonWidth(AControl: TControl; const ACaption: string;
  ARole: TThemedButtonRole; AMinWidth: Integer): Integer;
var
  Bmp: TBitmap;
  TextW, Pad: Integer;
begin
  Result := AMinWidth;
  Bmp := TBitmap.Create;
  try
    Bmp.Canvas.Font.Name := 'Segoe UI';
    Bmp.Canvas.Font.Size := ThemedButtonFontSize(AControl);
    if ARole in [tbrPrimary, tbrDestructive] then
      Bmp.Canvas.Font.Style := [fsBold]
    else
      Bmp.Canvas.Font.Style := [];
    TextW := Bmp.Canvas.TextWidth(ACaption);
    Pad := ThemedButtonHorizPad(AControl);
    Result := TextW + Pad * 2;
    if Result < AMinWidth then
      Result := AMinWidth;
  finally
    Bmp.Free;
  end;
end;

function ColorToStyleHex(AColor: TColor): string;
begin
  Result := '#' + LowerCase(IntToHex(Red(AColor), 2) + IntToHex(Green(AColor), 2) +
    IntToHex(Blue(AColor), 2));
end;

{$IFDEF LCLQt5}
type
  { Access StyleSheet on LCL-created TQtMenuBar instances. }
  TQtMenuBarStyleAccess = class(TQtMenuBar)
  public
    procedure ApplyMenuStyleSheet(const ASheet: WideString);
  end;

var
  FQt5MenuBarLastHandle: PtrUInt;
  FQt5MenuBarLastTheme: TThemeKind;
  FQt5MenuBarThemeSet: Boolean;

procedure TQtMenuBarStyleAccess.ApplyMenuStyleSheet(const ASheet: WideString);
begin
  StyleSheet := ASheet;
end;

procedure ApplyQt5MenuBarTheme(AForm: TForm; ATheme: TThemeKind);
var
  P: TThemePalette;
  MenuBar: TQtMenuBar;
  Sheet: WideString;
  MenuHandle: PtrUInt;
begin
  if not Assigned(AForm) or not AForm.HandleAllocated then Exit;
  if AForm.Menu = nil then Exit;
  if not AForm.Menu.HandleAllocated then Exit;

  MenuHandle := PtrUInt(AForm.Menu.Handle);
  if FQt5MenuBarThemeSet and (FQt5MenuBarLastHandle = MenuHandle) and
     (FQt5MenuBarLastTheme = ATheme) then
    Exit;

  MenuBar := TQtMenuBar(Pointer(MenuHandle));
  P := ThemePalette(ATheme);
  Sheet := WideString(
    'QMenuBar { background-color: ' + ColorToStyleHex(P.HeaderBg) +
    '; color: ' + ColorToStyleHex(P.Text) + '; } ' +
    'QMenuBar::item { background: transparent; color: ' + ColorToStyleHex(P.Text) + '; } ' +
    'QMenuBar::item:selected { background-color: ' + ColorToStyleHex(P.AccentActive) + '; }');
  TQtMenuBarStyleAccess(MenuBar).ApplyMenuStyleSheet(Sheet);

  FQt5MenuBarLastHandle := MenuHandle;
  FQt5MenuBarLastTheme := ATheme;
  FQt5MenuBarThemeSet := True;
end;
{$ENDIF}

{$IFDEF LCLGtk3}
var
  FGtkMenuBarCssProvider: PGtkCssProvider;
  FGtkMenuBarCssTheme: TThemeKind;
  FGtkMenuBarCssThemeSet: Boolean;

procedure Gtk3ApplyMenuBarCssToContext(AContext: PGtkStyleContext; const ACss: string);
var
  Provider: PGtkCssProvider;
begin
  if AContext = nil then Exit;
  Provider := gtk_css_provider_new();
  gtk_css_provider_load_from_data(Provider, PChar(ACss), -1, nil);
  gtk_style_context_add_provider(AContext, PGtkStyleProvider(Provider),
    GTK_STYLE_PROVIDER_PRIORITY_USER);
  g_object_unref(Provider);
end;

procedure ApplyGtk3MenuBarTheme(AForm: TForm; ATheme: TThemeKind);
var
  P: TThemePalette;
  Css: string;
  Screen: PGdkScreen;
  MenuBar: PGtkWidget;
  MenuContext: PGtkStyleContext;
begin
  if FGtkMenuBarCssThemeSet and (FGtkMenuBarCssTheme = ATheme) then
    Exit;

  P := ThemePalette(ATheme);
  Css :=
    'menubar, .menubar { ' +
    'background-color: ' + ColorToStyleHex(P.HeaderBg) + '; ' +
    'color: ' + ColorToStyleHex(P.Text) + '; } ' +
    'menubar > menuitem { ' +
    'color: ' + ColorToStyleHex(P.Text) + ' !important; } ' +
    'menubar > menuitem label { ' +
    'color: ' + ColorToStyleHex(P.Text) + ' !important; } ' +
    'menubar > menuitem:hover { ' +
    'background-color: ' + ColorToStyleHex(P.AccentActive) + '; }';

  Screen := gdk_screen_get_default();
  if Screen = nil then Exit;

  if FGtkMenuBarCssProvider <> nil then begin
    gtk_style_context_remove_provider_for_screen(Screen,
      PGtkStyleProvider(FGtkMenuBarCssProvider));
    g_object_unref(FGtkMenuBarCssProvider);
    FGtkMenuBarCssProvider := nil;
  end;

  FGtkMenuBarCssProvider := gtk_css_provider_new();
  gtk_css_provider_load_from_data(FGtkMenuBarCssProvider, PChar(Css), -1, nil);
  gtk_style_context_add_provider_for_screen(Screen,
    PGtkStyleProvider(FGtkMenuBarCssProvider),
    GTK_STYLE_PROVIDER_PRIORITY_USER);

  if Assigned(AForm) and Assigned(AForm.Menu) and AForm.Menu.HandleAllocated then begin
    MenuBar := PGtkWidget(Pointer(AForm.Menu.Handle));
    if gtk_type_is_a(gtk_widget_get_type(MenuBar), gtk_menu_bar_get_type()) then begin
      MenuContext := gtk_widget_get_style_context(MenuBar);
      Gtk3ApplyMenuBarCssToContext(MenuContext, Css);
    end;
  end;

  FGtkMenuBarCssTheme := ATheme;
  FGtkMenuBarCssThemeSet := True;
end;
{$ENDIF}

{$IFDEF LCLGtk2}
procedure TColorToGdkColor(AColor: TColor; out AGdk: TGdkColor);
begin
  AGdk.pixel := 0;
  AGdk.red := Word(Red(AColor) * 257);
  AGdk.green := Word(Green(AColor) * 257);
  AGdk.blue := Word(Blue(AColor) * 257);
end;

procedure Gtk2ApplyMenuBarWidgetColors(AWidget: PGtkWidget; AFg, ABg: TColor);
var
  Fg, Bg: TGdkColor;
  List, Node: PGList;
  Child: PGtkWidget;
begin
  if AWidget = nil then Exit;
  TColorToGdkColor(AFg, Fg);
  TColorToGdkColor(ABg, Bg);
  gtk_widget_modify_fg(AWidget, GTK_STATE_NORMAL, @Fg);
  gtk_widget_modify_fg(AWidget, GTK_STATE_PRELIGHT, @Fg);
  gtk_widget_modify_bg(AWidget, GTK_STATE_NORMAL, @Bg);

  if not GTK_IS_CONTAINER(AWidget) then Exit;
  List := gtk_container_get_children(GTK_CONTAINER(AWidget));
  Node := List;
  while Node <> nil do begin
    Child := PGtkWidget(Node^.data);
    gtk_widget_modify_fg(Child, GTK_STATE_NORMAL, @Fg);
    gtk_widget_modify_fg(Child, GTK_STATE_PRELIGHT, @Fg);
    Node := Node^.next;
  end;
  g_list_free(List);
end;

procedure ApplyGtk2MenuBarTheme(AForm: TForm; ATheme: TThemeKind);
var
  P: TThemePalette;
  MenuBar: PGtkWidget;
begin
  if not Assigned(AForm) or not AForm.HandleAllocated then Exit;
  if AForm.Menu = nil then Exit;
  if not AForm.Menu.HandleAllocated then Exit;

  MenuBar := PGtkWidget(Pointer(AForm.Menu.Handle));
  if not GTK_IS_MENU_BAR(MenuBar) then Exit;

  P := ThemePalette(ATheme);
  Gtk2ApplyMenuBarWidgetColors(MenuBar, P.Text, P.HeaderBg);
end;
{$ENDIF}

{ Legacy LCL Form.Menu chrome (Qt/GTK). Main app uses TLcaThemedMenuBar instead. }
procedure ApplyPlatformMenuChrome(AForm: TForm; ATheme: TThemeKind);
begin
{$IFDEF LCLQt5}
  ApplyQt5MenuBarTheme(AForm, ATheme);
{$ENDIF}
{$IFDEF LCLGtk3}
  ApplyGtk3MenuBarTheme(AForm, ATheme);
{$ENDIF}
{$IFDEF LCLGtk2}
  ApplyGtk2MenuBarTheme(AForm, ATheme);
{$ENDIF}
end;

{$IFDEF WINDOWS}
type
  TWinHwnd = PtrUInt;

procedure SetWindowTheme(hwnd: TWinHwnd; pszSubAppName, pszSubIdList: PWideChar); stdcall;
  external 'uxtheme' name 'SetWindowTheme';

function DwmSetWindowAttribute(hwnd: TWinHwnd; dwAttribute: LongWord;
  pvAttribute: Pointer; cbAttribute: LongWord): LongInt; stdcall;
  external 'dwmapi' name 'DwmSetWindowAttribute';

procedure ApplyWin32ExplorerControlTheme(AHandle: TWinHwnd; ATheme: TThemeKind);
var
  ThemeId: PWideChar;
begin
  if AHandle = 0 then Exit;
  if ATheme = tkDark then
    ThemeId := 'DarkMode_Explorer'
  else
    ThemeId := 'Explorer';
  SetWindowTheme(AHandle, ThemeId, nil);
end;
{$ENDIF}

function LazarusIdeHostExecutable: Boolean;
var
  N: string;
begin
  N := LowerCase(ExtractFileName(ParamStr(0)));
  Result := (N = 'lazarus') or (N = 'startlazarus');
end;

function LcaComponentOrOwnerDesigning(AComponent: TComponent): Boolean;
var
  C: TComponent;
begin
  C := AComponent;
  while C <> nil do begin
    if csDesigning in C.ComponentState then
      Exit(True);
    C := C.Owner;
  end;
  Result := False;
end;

function LcaInDesignContext(const AComponent: TComponent): Boolean;
var
  F: TCustomForm;
begin
  if LcaComponentOrOwnerDesigning(AComponent) then
    Exit(True);
  if Assigned(Application) and (csDesigning in Application.ComponentState) then
    Exit(True);
  if LazarusIdeHostExecutable and (AComponent is TControl) then begin
    F := GetParentForm(TControl(AComponent));
    if Assigned(F) then
      Exit(True);
  end;
  Result := False;
end;

function EffectiveControlTheme(const AComponent: TComponent; AStored: TThemeKind): TThemeKind;
begin
  if LcaInDesignContext(AComponent) then
    Result := tkLight
  else
    Result := AStored;
end;

function ThemePalette(ATheme: TThemeKind): TThemePalette;
begin
  if ATheme = tkDark then begin
    // Neutral IDE dark (VS Code–like neutrals, restrained blue accent)
    Result.Background     := RGBToColor(30, 30, 30);       // #1E1E1E
    Result.Surface        := RGBToColor(37, 37, 38);       // #252526
    Result.SurfaceAlt     := RGBToColor(45, 45, 48);       // #2D2D30
    Result.HeaderBg       := RGBToColor(37, 37, 38);       // #252526
    Result.TitleBarBg     := RGBToColor(30, 30, 30);       // #1E1E1E
    Result.MenuFlyoutBg   := RGBToColor(45, 45, 48);       // #2D2D30
    Result.RailBg         := RGBToColor(30, 30, 30);       // #1E1E1E
    Result.RailActiveBg   := RGBToColor(45, 45, 48);       // #2D2D30
    Result.Border         := RGBToColor(62, 62, 66);       // #3E3E42
    Result.BorderStrong   := RGBToColor(86, 86, 92);       // #56565C
    Result.Text           := RGBToColor(204, 204, 204);    // #CCCCCC
    Result.TextMuted      := RGBToColor(133, 133, 133);    // #858585
    Result.ChatLabelUser  := RGBToColor(78, 175, 130);     // muted green
    Result.ChatLabelAgent := RGBToColor(55, 148, 255);     // match Accent
    Result.ChatLabelTool  := RGBToColor(210, 153, 72);     // muted amber
    Result.ChatLabelThinking := RGBToColor(156, 142, 200); // muted violet
    Result.Accent         := RGBToColor(55, 148, 255);     // #3794FF
    Result.AccentHover    := RGBToColor(74, 158, 255);     // #4A9EFF
    Result.AccentActive   := RGBToColor(51, 62, 82);       // selection wash
    Result.AccentText     := RGBToColor(255, 255, 255);
    Result.SplitterColor  := RGBToColor(51, 51, 51);        // #333333
    Result.CardBg         := RGBToColor(40, 40, 40);       // #282828
  end else begin
    // Neutral IDE light
    Result.Background     := RGBToColor(243, 243, 243);   // #F3F3F3
    Result.Surface        := RGBToColor(255, 255, 255);   // #FFFFFF
    Result.SurfaceAlt     := RGBToColor(247, 247, 247);   // #F7F7F7
    Result.HeaderBg       := RGBToColor(243, 243, 243);   // #F3F3F3
    Result.TitleBarBg     := RGBToColor(243, 243, 243);
    Result.MenuFlyoutBg   := RGBToColor(252, 252, 252);   // #FCFCFC
    Result.RailBg         := RGBToColor(243, 243, 243);
    Result.RailActiveBg   := RGBToColor(232, 232, 232);   // #E8E8E8
    Result.Border         := RGBToColor(225, 225, 225);   // #E1E1E1
    Result.BorderStrong   := RGBToColor(200, 200, 200);   // #C8C8C8
    Result.Text           := RGBToColor(51, 51, 51);      // #333333
    Result.TextMuted      := RGBToColor(110, 110, 110);   // #6E6E6E
    Result.ChatLabelUser  := RGBToColor(16, 120, 84);     // #107854
    Result.ChatLabelAgent := RGBToColor(0, 102, 204);     // match Accent
    Result.ChatLabelTool  := RGBToColor(161, 98, 7);      // #A16207
    Result.ChatLabelThinking := RGBToColor(92, 45, 145);  // #5C2D91
    Result.Accent         := RGBToColor(0, 102, 204);     // #0066CC
    Result.AccentHover    := RGBToColor(0, 90, 181);      // #005AB5
    Result.AccentActive   := RGBToColor(225, 236, 248);   // #E1ECF8
    Result.AccentText     := clWhite;
    Result.SplitterColor  := RGBToColor(230, 230, 230);
    Result.CardBg         := RGBToColor(250, 250, 250);   // #FAFAFA
  end;
end;

function EffectiveThemedComboBoxHeight(ACombo: TComboBox): Integer;
const
  MIN_COMBO_H = 20;
  MAX_COMBO_H = 40;
begin
  if not Assigned(ACombo) then
    Exit(ThemedComboBoxHeight);
  if not ACombo.HandleAllocated then
    Exit(ThemedComboBoxHeight);
  Result := ACombo.Height;
  if (Result < MIN_COMBO_H) or (Result > MAX_COMBO_H) then
    Result := ThemedComboBoxHeight;
end;

function ThemedComboItemHeightForControl(ADesignHeight,
  ADesignItemHeight: Integer): Integer;
const
  MIN_ITEM_H = 8;
begin
  if ADesignItemHeight > 0 then
    Exit(ADesignItemHeight);
  if ADesignHeight > 0 then
    Exit(Max(MIN_ITEM_H, ADesignHeight - 6));
  Result := ThemedComboBoxItemHeight;
end;

procedure RestoreComboDesignerBounds(ACombo: TComboBox; ASavedH: Integer);
begin
  if Assigned(ACombo) and (ACombo.Height <> ASavedH) then
    ACombo.Height := ASavedH;
end;

procedure StyleComboBox(ACombo: TComboBox; ATheme: TThemeKind);
var
  P: TThemePalette;
  Changed: Boolean;
  SavedH, SavedItemH, TargetItemH: Integer;
begin
  if not Assigned(ACombo) then Exit;
  SavedH := ACombo.Height;
  SavedItemH := ACombo.ItemHeight;
  P := ThemePalette(ATheme);
  Changed := False;

  if ACombo.Style <> csOwnerDrawFixed then begin
    ACombo.Style := csOwnerDrawFixed;
    Changed := True;
  end;
  TargetItemH := ThemedComboItemHeightForControl(SavedH, SavedItemH);
  if ACombo.ItemHeight <> TargetItemH then begin
    ACombo.ItemHeight := TargetItemH;
    Changed := True;
  end;
  if ACombo.Color <> P.SurfaceAlt then begin
    ACombo.Color := P.SurfaceAlt;
    Changed := True;
  end;
  if ACombo.Font.Color <> P.Text then begin
    ACombo.Font.Color := P.Text;
    Changed := True;
  end;
  if ACombo.Font.Name <> 'Segoe UI' then begin
    ACombo.Font.Name := 'Segoe UI';
    Changed := True;
  end;
  if ACombo.Font.Size <> 9 then begin
    ACombo.Font.Size := 9;
    Changed := True;
  end;
  if ACombo.Height <> SavedH then begin
    RestoreComboDesignerBounds(ACombo, SavedH);
    Changed := True;
  end;
  if Changed then
    ACombo.Invalidate;
end;

procedure PaintThemedComboListItem(Canvas: TCanvas; const ARect: TRect;
  const AText: string; State: TOwnerDrawState; ATheme: TThemeKind);
var
  P: TThemePalette;
  TextTop: Integer;
  Selected: Boolean;
  HorizInset: Integer;
begin
  P := ThemePalette(ATheme);
  Canvas.Brush.Color := P.SurfaceAlt;
  Canvas.FillRect(ARect);
  Selected := (odSelected in State) or (odFocused in State);
  if Selected then begin
    HorizInset := 4;
    PaintSelectionPill(Canvas, ARect, P.AccentActive, HorizInset, 2, 4);
  end;
  if AText = '' then Exit;
  ApplyThemedUiFont(Canvas, nil, 9);
  if Selected then
    Canvas.Font.Color := P.Accent
  else
    Canvas.Font.Color := P.Text;
  TextTop := ARect.Top + ((ARect.Bottom - ARect.Top - Canvas.TextHeight(AText)) div 2);
  Canvas.TextRect(ARect, ARect.Left + 8, TextTop, AText);
end;

procedure StyleComboBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState; ATheme: TThemeKind);
var
  Combo: TComboBox;
  TextStr: string;
begin
  if not (Control is TComboBox) then Exit;
  Combo := TComboBox(Control);
  if (Index >= 0) and (Index < Combo.Items.Count) then
    TextStr := Combo.Items[Index]
  else
    TextStr := '';
  PaintThemedComboListItem(Combo.Canvas, ARect, TextStr, State, ATheme);
end;

procedure StylePageControl(APageControl: TPageControl; ATheme: TThemeKind);
var
  P: TThemePalette;
  I: Integer;
begin
  if not Assigned(APageControl) then Exit;
  P := ThemePalette(ATheme);

  APageControl.Color := P.Background;
  APageControl.Font.Color := P.Text;

  for I := 0 to APageControl.PageCount - 1 do begin
    APageControl.Pages[I].Color := P.Surface;
    APageControl.Pages[I].Font.Color := P.Text;
  end;

  APageControl.Invalidate;
  EnforcePageControlHiddenTabs(APageControl);
end;

procedure EnforcePageControlHiddenTabs(APageControl: TPageControl);
begin
  if not Assigned(APageControl) then Exit;
  if csDestroying in APageControl.ComponentState then Exit;
  if not ParentFormHandlesReady(APageControl) then Exit;
  if not APageControl.HandleAllocated then
    APageControl.HandleNeeded;
  if not APageControl.HandleAllocated then Exit;
  APageControl.ShowTabs := False;
  {$IFDEF LCLGtk2}
  gtk_notebook_set_show_tabs(PGtkNotebook(APageControl.Handle), GFalse);
  gtk_notebook_set_show_border(PGtkNotebook(APageControl.Handle), GFalse);
  {$ENDIF}
  {$IFDEF LCLGtk3}
  gtk_notebook_set_show_tabs(PGtkNotebook(APageControl.Handle), False);
  gtk_notebook_set_show_border(PGtkNotebook(APageControl.Handle), False);
  {$ENDIF}
  {$IFDEF LCLQt5}
  if TQtWidget(APageControl.Handle).ChildOfComplexWidget <> ccwTTabControl then begin
    with TQtTabWidget(APageControl.Handle) do
      if TabBar <> nil then
        ShowTabs := False;
  end;
  {$ENDIF}
end;

procedure PaintThemedTab(Canvas: TCanvas; const ARect: TRect; const ACaption: string;
  AActive, AHover: Boolean; AShowClose, ACloseHover: Boolean; ATheme: TThemeKind;
  AMetricsControl: TControl; ACenterCaption: Boolean);
var
  P: TThemePalette;
  R, TextR, CloseR: TRect;
  FillColor, TextColor: TColor;
  TextTop, TextLeft, Rad, CloseCol, HorizPad, CloseW, CloseH, CloseX, CapW, CapH: Integer;
  CloseCaption: string;
begin
  P := ThemePalette(ATheme);
  R := ClientStrokeRect(ARect);
  Rad := 6;

  if AActive then begin
    FillColor := P.Surface;
    TextColor := P.Text;
  end else if AHover then begin
    FillColor := P.SurfaceAlt;
    TextColor := P.Text;
  end else begin
    FillColor := P.HeaderBg;
    TextColor := P.TextMuted;
  end;

  FillRoundRect(Canvas, ARect, Rad, FillColor);
  if AHover and not AActive then
    StrokeRoundRect(Canvas, ARect, Rad, P.Border, 1);

  if AActive then begin
    Canvas.Pen.Color := P.Accent;
    Canvas.Pen.Width := 2;
    Canvas.MoveTo(R.Left + Rad, R.Bottom);
    Canvas.LineTo(R.Right, R.Bottom);
    Canvas.Pen.Width := 1;
  end;

  ApplyThemedUiFont(Canvas, AMetricsControl, ThemedTabFontSize);
  Canvas.Font.Color := TextColor;

  CloseCol := ThemedTabCloseColumn(AMetricsControl);
  HorizPad := ThemedTabHorizPad(AMetricsControl);

  TextR := R;
  if AShowClose then
    Dec(TextR.Right, CloseCol);
  if ACenterCaption then begin
    CapW := Canvas.TextWidth(ACaption);
    CapH := Canvas.TextHeight(ACaption);
    TextLeft := R.Left + ((R.Right - R.Left - CapW) div 2);
    TextTop := R.Top + ((R.Bottom - R.Top - CapH) div 2);
    Canvas.TextOut(TextLeft, TextTop, ACaption);
  end else begin
    Inc(TextR.Left, HorizPad);
    TextTop := TextR.Top + ((TextR.Bottom - TextR.Top - Canvas.TextHeight(ACaption)) div 2);
    Canvas.TextRect(TextR, TextR.Left, TextTop, ACaption);
  end;

  if AShowClose then begin
    CloseR := ThemedTabCloseHitRect(ARect, AMetricsControl);
    if ACloseHover then
      FillRoundRect(Canvas, CloseR, 4, BlendRgb(P.SurfaceAlt, P.Border, 0.35));
    CloseCaption := '✕';
    Canvas.Font.Size := 9;
    if ACloseHover then
      Canvas.Font.Color := P.Accent
    else if AActive then
      Canvas.Font.Color := P.Text
    else
      Canvas.Font.Color := P.TextMuted;
    CloseW := Canvas.TextWidth(CloseCaption);
    CloseH := Canvas.TextHeight(CloseCaption);
    CloseX := CloseR.Left + ((CloseR.Right - CloseR.Left - CloseW) div 2);
    TextTop := CloseR.Top + ((CloseR.Bottom - CloseR.Top - CloseH) div 2);
    Canvas.TextOut(CloseX, TextTop, CloseCaption);
  end;
end;

procedure ApplyControlTheme(AControl: TControl; ATheme: TThemeKind);
var
  P: TThemePalette;
  I: Integer;
  WinCtrl: TWinControl;
begin
  if not Assigned(AControl) then Exit;
  P := ThemePalette(ATheme);

  if AControl is TCustomEdit then begin
    TCustomEdit(AControl).Color := P.SurfaceAlt;
    TCustomEdit(AControl).Font.Color := P.Text;
  end else if AControl is TLabel then begin
    TLabel(AControl).Font.Color := P.Text;
  end else if AControl is TPageControl then begin
    StylePageControl(TPageControl(AControl), ATheme);
  end else if Assigned(ThemedButtonFrameApplyTheme) and (AControl <> nil) and
    AControl.ClassNameIs('TThemedButtonFrame') then
    ThemedButtonFrameApplyTheme(AControl, ATheme);

  if AControl is TWinControl then begin
    WinCtrl := TWinControl(AControl);
    for I := 0 to WinCtrl.ControlCount - 1 do
      ApplyControlTheme(WinCtrl.Controls[I], ATheme);
  end;
end;

{$IFDEF WINDOWS}
procedure ApplyWin32UnthemedButton(ABtn: TButton);
begin
  if Assigned(ABtn) and ABtn.HandleAllocated then
    SetWindowTheme(ABtn.Handle, '', '');
end;
{$ELSE}
procedure ApplyWin32UnthemedButton(ABtn: TButton);
begin
end;
{$ENDIF}

{$IFNDEF WINDOWS}
procedure ApplyWin32ThemedComboPaint(ACombo: TComboBox; ATheme: TThemeKind);
begin
end;
{$ENDIF}

procedure PaintThemedButton(Canvas: TCanvas; const ARect: TRect; ATheme: TThemeKind;
  ARole: TThemedButtonRole; const ACaption: string; AEnabled, AHover, APressed, AFocused: Boolean;
  ACornerRadius, AFontSize, AHorizPad: Integer; AMetricsControl: TControl);
var
  P: TThemePalette;
  R, TextR: TRect;
  FillColor, TextColor, BorderColor: TColor;
  DrawBorder: Boolean;
  TextTop, TextH, LayoutH, VertPad, DescentSafety: Integer;
  Rad: Integer;
  Ext: TSize;
  PrimaryHighlight: Boolean;
begin
  P := ThemePalette(ATheme);
  R := ClientStrokeRect(ARect);
  if ACornerRadius < 2 then
    Rad := 6
  else
    Rad := ACornerRadius;

  DrawBorder := False;
  BorderColor := P.Border;
  PrimaryHighlight := False;

  case ARole of
    tbrPrimary:
      begin
        FillColor := P.Accent;
        TextColor := P.AccentText;
        if APressed and AEnabled then
          FillColor := DarkenColor(P.Accent, 20)
        else if AHover and AEnabled then
          FillColor := P.AccentHover;
        PrimaryHighlight := AEnabled and not APressed;
      end;
    tbrCancel:
      begin
        DrawBorder := True;
        FillColor := P.SurfaceAlt;
        BorderColor := P.Border;
        TextColor := P.TextMuted;
        if APressed and AEnabled then begin
          FillColor := P.Border;
          TextColor := P.Text;
        end else if AHover and AEnabled then
          TextColor := P.Text;
      end;
    tbrDestructive:
      begin
        if ATheme = tkDark then begin
          FillColor := RGBToColor(72, 32, 36);
          TextColor := RGBToColor(248, 113, 113);
        end else begin
          FillColor := RGBToColor(254, 226, 226);
          TextColor := RGBToColor(185, 28, 28);
        end;
        if APressed and AEnabled then begin
          if ATheme = tkDark then
            FillColor := RGBToColor(62, 28, 32)
          else
            FillColor := RGBToColor(248, 200, 200);
        end else if AHover and AEnabled then begin
          if ATheme = tkDark then
            FillColor := RGBToColor(92, 42, 48)
          else
            FillColor := RGBToColor(252, 210, 210);
        end;
      end;
    tbrGhost:
      begin
        DrawBorder := False;
        FillColor := P.HeaderBg;
        TextColor := P.TextMuted;
        if APressed and AEnabled then begin
          FillColor := P.Border;
          TextColor := P.Text;
        end else if AHover and AEnabled then begin
          FillColor := P.SurfaceAlt;
          TextColor := P.Text;
        end;
      end;
  end;

  if not AEnabled then begin
    FillColor := P.SurfaceAlt;
    TextColor := P.TextMuted;
    DrawBorder := ARole = tbrCancel;
    if ARole = tbrGhost then
      DrawBorder := False;
    PrimaryHighlight := False;
  end;

  FillRoundRect(Canvas, ARect, Rad, FillColor);
  if DrawBorder then
    StrokeRoundRect(Canvas, ARect, Rad, BorderColor, 1);
  if PrimaryHighlight then
    PaintSubtleTopHighlight(Canvas, ARect, Rad, LightenColor(FillColor, 24));
  if AFocused and AEnabled then
    PaintFocusRing(Canvas, ARect, Rad, P.Accent);

  if AFontSize > 0 then
    ApplyThemedUiFont(Canvas, AMetricsControl, AFontSize)
  else
    ApplyThemedUiFont(Canvas, AMetricsControl, ThemedButtonFontSizeBase);
  if ARole in [tbrPrimary, tbrDestructive] then
    Canvas.Font.Style := [fsBold]
  else
    Canvas.Font.Style := [];
  Canvas.Font.Color := TextColor;

  TextR := R;
  if Assigned(AMetricsControl) then begin
    VertPad := ThemedButtonVertPad(AMetricsControl);
    Inc(TextR.Top, VertPad);
    Dec(TextR.Bottom, VertPad);
  end;
  if TextR.Bottom <= TextR.Top then
    TextR := R;

  TextH := Canvas.TextHeight(ACaption);
  Ext := Canvas.TextExtent(ACaption);
  LayoutH := Max(TextH, Ext.Cy);
  if Assigned(AMetricsControl) then
    DescentSafety := ScaledThemedTabMetric(AMetricsControl, ThemedButtonDescentSafetyBase)
  else
    DescentSafety := 0;
  TextTop := TextR.Top + Max(0, (TextR.Bottom - TextR.Top - LayoutH - DescentSafety) div 2);

  if (AHorizPad > 0) and (TextR.Width > AHorizPad * 2) then
    Canvas.TextRect(TextR, TextR.Left + AHorizPad +
      Max(0, (TextR.Width - AHorizPad * 2 - Canvas.TextWidth(ACaption)) div 2),
      TextTop, ACaption)
  else
    Canvas.TextRect(TextR, TextR.Left + (TextR.Width - Canvas.TextWidth(ACaption)) div 2,
      TextTop, ACaption);
end;

procedure PaintThemedComboChevron(Canvas: TCanvas; const ARect: TRect; AColor: TColor);
var
  CX, CY, HalfW, Drop: Integer;
begin
  CX := (ARect.Left + ARect.Right) div 2;
  CY := (ARect.Top + ARect.Bottom) div 2;
  HalfW := Max(3, (ARect.Right - ARect.Left) div 6);
  Drop := Max(2, (ARect.Bottom - ARect.Top) div 8);
  Canvas.Pen.Color := AColor;
  Canvas.Pen.Width := 1;
  Canvas.MoveTo(CX - HalfW, CY - Drop div 2);
  Canvas.LineTo(CX, CY + Drop);
  Canvas.LineTo(CX + HalfW, CY - Drop div 2);
end;

procedure PaintThemedComboField(Canvas: TCanvas; const ARect: TRect; ATheme: TThemeKind;
  const AText: string; AEnabled, AFocused, ADropped, AShowFocusRing: Boolean;
  ACornerRadius, AChevronGutter: Integer);
var
  P: TThemePalette;
  R, TextR, ChevR: TRect;
  Rad, TextTop, PadLeft: Integer;
  BorderColor, FillColor, TextColor, ChevColor: TColor;
begin
  P := ThemePalette(ATheme);
  R := ARect;
  Dec(R.Right);
  Dec(R.Bottom);
  if ACornerRadius < 2 then
    Rad := 6
  else
    Rad := ACornerRadius;

  FillColor := P.SurfaceAlt;
  BorderColor := P.Border;
  TextColor := P.Text;
  ChevColor := P.TextMuted;
  if ADropped and AEnabled then
    BorderColor := P.Accent;
  if AFocused and AEnabled and AShowFocusRing then
    BorderColor := P.Accent;
  if not AEnabled then begin
    FillColor := P.Surface;
    TextColor := P.TextMuted;
    ChevColor := P.TextMuted;
    BorderColor := P.Border;
  end;

  FillRoundRect(Canvas, ARect, Rad, FillColor);
  StrokeRoundRect(Canvas, ARect, Rad, BorderColor, 1);

  ChevR := R;
  ChevR.Left := ChevR.Right - AChevronGutter + 1;
  TextR := R;
  Dec(TextR.Right, AChevronGutter);
  PadLeft := 10;
  ApplyThemedUiFont(Canvas, nil, 9);
  Canvas.Font.Color := TextColor;
  if AText <> '' then begin
    TextTop := TextR.Top + ((TextR.Bottom - TextR.Top - Canvas.TextHeight(AText)) div 2);
    Canvas.TextRect(TextR, TextR.Left + PadLeft, TextTop, AText);
  end;
  PaintThemedComboChevron(Canvas, ChevR, ChevColor);
end;

procedure RestoreButtonDesignerBounds(ABtn: TButton; ASavedW, ASavedH: Integer);
begin
  if (ABtn.Width <> ASavedW) or (ABtn.Height <> ASavedH) then begin
    ABtn.Width := ASavedW;
    ABtn.Height := ASavedH;
  end;
end;

procedure StyleThemedButtonRole(ABtn: TButton; ATheme: TThemeKind; ARole: TThemedButtonRole);
var
  P: TThemePalette;
  SavedW, SavedH: Integer;
begin
  if not Assigned(ABtn) then Exit;
  SavedW := ABtn.Width;
  SavedH := ABtn.Height;
  P := ThemePalette(ATheme);
  case ARole of
    tbrPrimary:
      begin
        ABtn.Font.Color := P.AccentText;
        ABtn.Color := P.Accent;
      end;
    tbrDestructive:
      if ATheme = tkDark then begin
        ABtn.Color := RGBToColor(72, 32, 36);
        ABtn.Font.Color := RGBToColor(248, 113, 113);
      end else begin
        ABtn.Color := RGBToColor(254, 226, 226);
        ABtn.Font.Color := RGBToColor(185, 28, 28);
      end;
    tbrGhost:
      begin
        ABtn.Color := P.HeaderBg;
        if ATheme = tkDark then
          ABtn.Font.Color := P.Text
        else
          ABtn.Font.Color := P.TextMuted;
      end;
  else
    if ATheme = tkDark then begin
      ABtn.Color := P.SurfaceAlt;
      ABtn.Font.Color := P.TextMuted;
    end else begin
      ABtn.Color := P.Surface;
      ABtn.Font.Color := P.TextMuted;
    end;
  end;
  RestoreButtonDesignerBounds(ABtn, SavedW, SavedH);
  ApplyWin32UnthemedButton(ABtn);
  ApplyThemedButtonPaint(ABtn, ATheme, ARole);
  RestoreButtonDesignerBounds(ABtn, SavedW, SavedH);
  ABtn.Invalidate;
end;

procedure StylePrimaryButton(ABtn: TButton; ATheme: TThemeKind);
begin
  StyleThemedButtonRole(ABtn, ATheme, tbrPrimary);
end;

procedure StyleCancelButton(ABtn: TButton; ATheme: TThemeKind);
begin
  StyleThemedButtonRole(ABtn, ATheme, tbrCancel);
end;

procedure StyleDestructiveButton(ABtn: TButton; ATheme: TThemeKind);
begin
  StyleThemedButtonRole(ABtn, ATheme, tbrDestructive);
end;

procedure StyleGhostButton(ABtn: TButton; ATheme: TThemeKind);
begin
  StyleThemedButtonRole(ABtn, ATheme, tbrGhost);
end;

procedure ConfigureThemedListBox(AList: TListBox; ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  if not Assigned(AList) then Exit;
  P := ThemePalette(ATheme);
  AList.ItemHeight := 22;
  AList.Style := lbOwnerDrawFixed;
  AList.BorderStyle := bsNone;
  AList.MultiSelect := False;
  AList.ExtendedSelect := False;
  AList.Color := P.Surface;
  AList.Font.Name := 'Segoe UI';
  AList.Font.Size := 9;
  AList.Font.Color := P.Text;
  if AList.HandleAllocated then
    SyncThemedListBoxWidget(AList);
  AList.Invalidate;
end;

procedure ConfigureThemedTreeView(ATree: TTreeView; ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  if not Assigned(ATree) then Exit;
  P := ThemePalette(ATheme);
  ATree.BorderStyle := bsNone;
  ATree.Color := P.Surface;
  ATree.BackgroundColor := P.Surface;
  ATree.Font.Name := 'Segoe UI';
  ATree.Font.Size := 9;
  ATree.Font.Color := P.Text;
  ATree.HideSelection := True;
  ATree.Options := ATree.Options - [tvoThemedDraw];
  ATree.TreeLineColor := P.Border;
  ATree.ExpandSignColor := P.TextMuted;
  ATree.SelectionColor := P.AccentActive;
  ATree.SelectionFontColor := P.Text;
  ATree.SelectionFontColorUsed := True;
  ATree.Invalidate;
end;

procedure ConfigureThemedCheckBox(ACheck: TCheckBox; ATheme: TThemeKind);
var
  P: TThemePalette;
  Bg: TColor;
begin
  if not Assigned(ACheck) then Exit;
  P := ThemePalette(ATheme);
  ApplyWin32ToggleCaptionOpaqueStyle(ACheck);
  ACheck.ParentFont := False;
  ACheck.Font.Name := 'Segoe UI';
  ACheck.Font.Color := P.Text;
  ACheck.ParentColor := False;
  if Assigned(ACheck.Parent) then
    Bg := TControl(ACheck.Parent).Color
  else
    Bg := P.Surface;
  ACheck.Color := Bg;
{$IFDEF WINDOWS}
  if ACheck.HandleAllocated then
    ApplyWin32ExplorerControlTheme(ACheck.Handle, ATheme);
{$ENDIF}
  ACheck.Invalidate;
end;

procedure ConfigureThemedRadioButton(ARadio: TRadioButton; ATheme: TThemeKind);
var
  P: TThemePalette;
  Bg: TColor;
begin
  if not Assigned(ARadio) then Exit;
  P := ThemePalette(ATheme);
  ApplyWin32ToggleCaptionOpaqueStyle(ARadio);
  ARadio.ParentFont := False;
  ARadio.Font.Name := 'Segoe UI';
  ARadio.Font.Color := P.Text;
  ARadio.ParentColor := False;
  if Assigned(ARadio.Parent) then
    Bg := TControl(ARadio.Parent).Color
  else
    Bg := P.Surface;
  ARadio.Color := Bg;
{$IFDEF WINDOWS}
  if ARadio.HandleAllocated then
    ApplyWin32ExplorerControlTheme(ARadio.Handle, ATheme);
{$ENDIF}
  ARadio.Invalidate;
end;

procedure StyleThemedToggleCaptionLabel(ALabel: TLabel; ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  if not Assigned(ALabel) then Exit;
  P := ThemePalette(ATheme);
  ALabel.ParentFont := False;
  ALabel.Font.Name := 'Segoe UI';
  ALabel.Font.Color := P.Text;
  if ALabel.Cursor <> crHandPoint then
    ALabel.Cursor := crHandPoint;
end;

procedure StyleThemedSectionLabel(ALabel: TLabel; ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  if not Assigned(ALabel) then Exit;
  P := ThemePalette(ATheme);
  ALabel.ParentFont := False;
  ALabel.Font.Name := 'Segoe UI';
  ALabel.Font.Color := P.Text;
  ALabel.Font.Style := [fsBold];
end;

procedure ConfigureThemedGroupBox(AGroup: TCustomGroupBox; ATheme: TThemeKind);
var
  P: TThemePalette;
  Bg: TColor;
begin
  if not Assigned(AGroup) then Exit;
  P := ThemePalette(ATheme);
  if AGroup is TGroupBox then begin
    TGroupBox(AGroup).ParentFont := False;
    TGroupBox(AGroup).ParentColor := False;
  end;
  AGroup.Font.Name := 'Segoe UI';
  AGroup.Font.Color := P.Text;
  if Assigned(AGroup.Parent) then
    Bg := AGroup.Parent.Color
  else
    Bg := P.Surface;
  AGroup.Color := Bg;
{$IFDEF WINDOWS}
  if AGroup.HandleAllocated then
    ApplyWin32ExplorerControlTheme(AGroup.Handle, ATheme);
{$ENDIF}
  AGroup.Invalidate;
end;

procedure ConfigureThemedMemo(AMemo: TCustomMemo; ATheme: TThemeKind;
  const AFontName: string = 'Segoe UI'; ABackground: TColor = clNone);
var
  P: TThemePalette;
begin
  if not Assigned(AMemo) then Exit;
  P := ThemePalette(ATheme);
  if ABackground = clNone then
    AMemo.Color := P.SurfaceAlt
  else
    AMemo.Color := ABackground;
  AMemo.Font.Color := P.Text;
  if AFontName <> '' then
    AMemo.Font.Name := AFontName;
end;

procedure ConfigureThemedExecDetailMemo(AMemo: TCustomMemo; ATheme: TThemeKind);
begin
  ConfigureThemedMemo(AMemo, ATheme, 'Consolas');
  if Assigned(AMemo) then
    AMemo.Font.Size := ThemedExecDetailFontSizeBase;
end;

procedure SyncThemedMemoWidget(AMemo: TCustomMemo);
begin
  if not Assigned(AMemo) then Exit;
  if not AMemo.HandleAllocated then Exit;
  AMemo.Font.Assign(AMemo.Font);
  AMemo.Invalidate;
end;

procedure SyncThemedEditWidget(AEdit: TCustomEdit);
begin
  if not Assigned(AEdit) then Exit;
  if not AEdit.HandleAllocated then Exit;
  AEdit.Font.Assign(AEdit.Font);
  AEdit.Invalidate;
end;

procedure SyncThemedListBoxWidget(AList: TCustomListBox);
{$IFDEF LCLGtk2}
var
  Bg: TGdkColor;
  W: PGtkWidget;
{$ENDIF}
{$IFDEF LCLGtk3}
var
  W: PGtkWidget;
  Rgba: TGdkRGBA;
{$ENDIF}
{$IFDEF LCLQt5}
var
  QtWidget: TQtWidget;
  Sheet: WideString;
{$ENDIF}
{$IFDEF LCLcocoa}
var
  Scroll: NSScrollView;
  Table: NSTableView;
  Clip: NSClipView;
  Bg: NSColor;
{$ENDIF}
begin
  if not Assigned(AList) then Exit;
  if not AList.HandleAllocated then Exit;
  {$IFDEF LCLGtk2}
  W := PGtkWidget(Pointer(AList.Handle));
  if W <> nil then begin
    TColorToGdkColor(AList.Color, Bg);
    gtk_widget_modify_bg(W, GTK_STATE_NORMAL, @Bg);
  end;
  {$ENDIF}
  {$IFDEF LCLGtk3}
  W := PGtkWidget(Pointer(AList.Handle));
  if (W <> nil) and gdk_rgba_parse(@Rgba, PChar(ColorToStyleHex(AList.Color))) then
    gtk_widget_override_background_color(W, GTK_STATE_FLAG_NORMAL, @Rgba);
  {$ENDIF}
  {$IFDEF LCLQt5}
  QtWidget := TQtWidget(Pointer(AList.Handle));
  Sheet := WideString(
    'QListWidget { color: ' + ColorToStyleHex(AList.Font.Color) +
    '; background-color: ' + ColorToStyleHex(AList.Color) + '; }');
  QtWidget.StyleSheet := Sheet;
  {$ENDIF}
  {$IFDEF LCLcocoa}
  Scroll := NSScrollView(Pointer(AList.Handle));
  if Scroll <> nil then begin
    Bg := TCocoaColorUtil.toColor(ColorToRGB(AList.Color));
    Table := NSTableView(Scroll.documentView);
    if Table <> nil then
      Table.setBackgroundColor(Bg);
    Clip := NSClipView(Scroll.contentView);
    if Clip <> nil then begin
      Clip.setDrawsBackground(True);
      Clip.setBackgroundColor(Bg);
    end;
    Scroll.setDrawsBackground(True);
    Scroll.setBackgroundColor(Bg);
  end;
  {$ENDIF}
  AList.Invalidate;
end;

{$IFDEF LCLQt5}
procedure ApplyQt5MemoTheme(AMemo: TCustomMemo; ATheme: TThemeKind);
var
  QtWidget: TQtWidget;
  Sheet: WideString;
begin
  if not Assigned(AMemo) then Exit;
  if not AMemo.HandleAllocated then Exit;
  QtWidget := TQtWidget(Pointer(AMemo.Handle));
  Sheet := WideString(
    'QTextEdit { color: ' + ColorToStyleHex(AMemo.Font.Color) +
    '; background-color: ' + ColorToStyleHex(AMemo.Color) + '; }');
  QtWidget.StyleSheet := Sheet;
  SyncThemedMemoWidget(AMemo);
end;

procedure ApplyQt5EditTheme(AEdit: TCustomEdit; ATheme: TThemeKind);
var
  QtWidget: TQtWidget;
  P: TThemePalette;
  Sheet: WideString;
begin
  if not Assigned(AEdit) then Exit;
  if not AEdit.HandleAllocated then Exit;
  P := ThemePalette(ATheme);
  QtWidget := TQtWidget(Pointer(AEdit.Handle));
  Sheet := WideString(
    'QLineEdit { color: ' + ColorToStyleHex(AEdit.Font.Color) +
    '; background-color: ' + ColorToStyleHex(AEdit.Color) +
    '; selection-background-color: ' + ColorToStyleHex(P.AccentActive) + '; }');
  QtWidget.StyleSheet := Sheet;
  SyncThemedEditWidget(AEdit);
end;

procedure ApplyQt5ComboBoxTheme(ACombo: TComboBox; ATheme: TThemeKind);
var
  QtWidget: TQtWidget;
  Sheet: WideString;
begin
  if not Assigned(ACombo) then Exit;
  if not ACombo.HandleAllocated then Exit;
  QtWidget := TQtWidget(Pointer(ACombo.Handle));
  Sheet := WideString(
    'QComboBox { color: ' + ColorToStyleHex(ACombo.Font.Color) +
    '; background-color: ' + ColorToStyleHex(ACombo.Color) + '; } ' +
    'QComboBox QAbstractItemView { color: ' + ColorToStyleHex(ACombo.Font.Color) +
    '; background-color: ' + ColorToStyleHex(ACombo.Color) + '; }');
  QtWidget.StyleSheet := Sheet;
  ACombo.Invalidate;
end;
{$ENDIF}

procedure PaintThemedMenuBarItem(Canvas: TCanvas; const ARect: TRect; const ACaption: string;
  ASelected: Boolean; ATheme: TThemeKind; AFontSize: Integer; AChromeBg: TColor);
var
  P: TThemePalette;
  R: TRect;
  TextStr: string;
  TextTop: Integer;
  ChromeBg: TColor;
begin
  P := ThemePalette(ATheme);
  R := ARect;
  if AChromeBg = clNone then
    ChromeBg := P.HeaderBg
  else
    ChromeBg := AChromeBg;
  Canvas.Brush.Color := ChromeBg;
  Canvas.FillRect(R);
  if ASelected then
    PaintSelectionPill(Canvas, R, P.AccentActive, 4, 3, 4);

  TextStr := MenuItemDisplayCaption(ACaption);
  if TextStr = '' then Exit;
  ApplyThemedUiFont(Canvas, nil, AFontSize);
  Canvas.Font.Color := P.Text;
  TextTop := R.Top + ((R.Bottom - R.Top - Canvas.TextHeight(TextStr)) div 2);
  Canvas.TextRect(R, R.Left + 10, TextTop, TextStr);
end;

procedure ThemedMenuPopupDrawItem(ACanvas: TCanvas; const ARect: TRect;
  State: TOwnerDrawState; ATheme: TThemeKind; ASource: TMenuItem);
var
  P: TThemePalette;
  TextStr, ShortStr: string;
  TextTop, CheckLeft, SepY: Integer;
  TextColor: TColor;
  R: TRect;
  CheckPad: Integer;
begin
  if not Assigned(ASource) then Exit;

  P := ThemePalette(ATheme);
  R := ARect;

  ACanvas.Brush.Color := P.MenuFlyoutBg;
  ACanvas.FillRect(R);
  if (odSelected in State) and ASource.Enabled then
    PaintSelectionPill(ACanvas, R, P.AccentActive, 6, 2, 4);

  if ASource.Caption = '-' then begin
    SepY := R.Top + (R.Bottom - R.Top) div 2;
    ACanvas.Pen.Color := P.Border;
    ACanvas.MoveTo(R.Left + 8, SepY);
    ACanvas.LineTo(R.Right - 8, SepY);
    Exit;
  end;

  ApplyThemedUiFont(ACanvas, nil, 9);

  if ASource.Enabled then
    TextColor := P.Text
  else
    TextColor := P.TextMuted;
  ACanvas.Font.Color := TextColor;

  CheckPad := ACanvas.TextWidth('✓') + 4;
  CheckLeft := R.Left + 8;
  TextStr := MenuItemDisplayCaption(ASource.Caption);
  TextTop := R.Top + ((R.Bottom - R.Top - ACanvas.TextHeight(TextStr)) div 2);

  if ASource.Checked then begin
    ACanvas.Font.Color := P.Accent;
    ACanvas.TextOut(CheckLeft, TextTop, '✓');
    Inc(CheckLeft, CheckPad);
  end else
    Inc(CheckLeft, CheckPad);

  ACanvas.Font.Color := TextColor;
  ACanvas.TextRect(R, CheckLeft, TextTop, TextStr);

  if ASource.ShortCut <> 0 then begin
    ShortStr := ShortCutToText(ASource.ShortCut);
    ACanvas.Font.Color := P.TextMuted;
    ACanvas.TextOut(R.Right - ACanvas.TextWidth(ShortStr) - 12, TextTop, ShortStr);
  end;

  if ASource.Count > 0 then begin
    ACanvas.Font.Color := P.TextMuted;
    ACanvas.TextOut(R.Right - 20, TextTop, '›');
  end;
end;

procedure ThemedListBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState; ATheme: TThemeKind);
var
  LBox: TListBox;
  P: TThemePalette;
  TextStr: string;
  TextColor: TColor;
  TextTop: Integer;
begin
  if not (Control is TListBox) then Exit;
  LBox := TListBox(Control);
  P := ThemePalette(ATheme);

  LBox.Canvas.Brush.Style := bsSolid;
  LBox.Canvas.Brush.Color := LBox.Color;
  LBox.Canvas.Pen.Color := LBox.Color;
  LBox.Canvas.FillRect(ARect);

  if (Index < 0) or (Index >= LBox.Items.Count) then Exit;

  TextStr := LBox.Items[Index];
  LBox.Canvas.Font.Assign(LBox.Font);

  if (odSelected in State) or (odFocused in State) then
    TextColor := P.Accent
  else
    TextColor := P.Text;
  LBox.Canvas.Font.Color := TextColor;

  TextTop := ARect.Top + ((ARect.Bottom - ARect.Top - LBox.Canvas.TextHeight(TextStr)) div 2);
  LBox.Canvas.TextRect(ARect, ARect.Left + 8, TextTop, TextStr);
end;

procedure PaintThemedNavListItem(Canvas: TCanvas; const ARect: TRect;
  const AText: string; State: TOwnerDrawState; ATheme: TThemeKind;
  AMetricsControl: TControl);
var
  P: TThemePalette;
  TextColor: TColor;
  TextTop: Integer;
  ContentRect: TRect;
  InsetV, PadLeft: Integer;
  Selected: Boolean;
  BgColor: TColor;
begin
  P := ThemePalette(ATheme);
  if Assigned(AMetricsControl) then begin
    InsetV := ScaledThemedNavListPadV(AMetricsControl) +
      (ScaledThemedNavListRowGap(AMetricsControl) div 2);
    PadLeft := ScaledThemedNavListPadLeft(AMetricsControl);
    BgColor := AMetricsControl.Color;
  end else begin
    InsetV := ThemedNavListPadV + (ThemedNavListRowGap div 2);
    PadLeft := ThemedNavListPadLeft;
    BgColor := P.Surface;
  end;

  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := BgColor;
  Canvas.Pen.Color := BgColor;
  Canvas.FillRect(ARect);

  ContentRect := ARect;
  ContentRect.Top := ContentRect.Top + InsetV;
  ContentRect.Bottom := ContentRect.Bottom - InsetV;
  if ContentRect.Bottom <= ContentRect.Top then
    ContentRect := ARect;

  Selected := (odSelected in State) or (odFocused in State);
  if Selected then
    PaintSelectionPill(Canvas, ContentRect, P.AccentActive, 6, 0, 5)
  else if odHotLight in State then
    PaintSelectionPill(Canvas, ContentRect, BlendRgb(BgColor, P.SurfaceAlt, 0.65), 6, 0, 5);

  if AText = '' then Exit;

  if Selected then
    TextColor := P.Accent
  else
    TextColor := P.Text;
  Canvas.Font.Color := TextColor;

  TextTop := ContentRect.Top +
    ((ContentRect.Bottom - ContentRect.Top - Canvas.TextHeight(AText)) div 2);
  Canvas.TextRect(ContentRect, ContentRect.Left + PadLeft, TextTop, AText);
end;

procedure PaintThemedNavRailCell(Canvas: TCanvas; const ARect: TRect; const P: TThemePalette;
  AActive, AHover, APressed: Boolean);
var
  R: TRect;
  BgColor: TColor;
  BarTop, BarBottom: Integer;
begin
  R := ARect;
  if AActive then
    BgColor := P.RailActiveBg
  else if APressed then
    BgColor := BlendRgb(P.RailBg, P.SurfaceAlt, 0.55)
  else if AHover then
    BgColor := BlendRgb(P.RailBg, P.SurfaceAlt, 0.35)
  else
    BgColor := P.RailBg;

  Canvas.Brush.Color := BgColor;
  Canvas.FillRect(R);

  if not AActive then Exit;
  Canvas.Pen.Color := P.Accent;
  Canvas.Pen.Width := 2;
  BarTop := R.Top + 6;
  BarBottom := R.Bottom - 6;
  if BarBottom <= BarTop then begin
    BarTop := R.Top + 4;
    BarBottom := R.Bottom - 4;
  end;
  Canvas.MoveTo(0, BarTop);
  Canvas.LineTo(0, BarBottom);
  Canvas.Pen.Width := 1;
end;

procedure ThemedNavListBoxDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState; ATheme: TThemeKind);
var
  LBox: TListBox;
  TextStr: string;
begin
  if not (Control is TListBox) then Exit;
  LBox := TListBox(Control);
  if (Index < 0) or (Index >= LBox.Items.Count) then begin
    PaintThemedNavListItem(LBox.Canvas, ARect, '', State, ATheme, LBox);
    Exit;
  end;
  TextStr := LBox.Items[Index];
  LBox.Canvas.Font.Assign(LBox.Font);
  PaintThemedNavListItem(LBox.Canvas, ARect, TextStr, State, ATheme, LBox);
end;

procedure ApplyWin32ScrollableTheme(AControl: TWinControl; ATheme: TThemeKind);
begin
  if not Assigned(AControl) then Exit;
  if not AControl.HandleAllocated then Exit;
{$IFDEF WINDOWS}
  if (AControl is TComboBox) or (AControl is TEdit) then
    ApplyWin32ExplorerControlTheme(AControl.Handle, ATheme)
  else if AControl is TCheckBox then
    ConfigureThemedCheckBox(TCheckBox(AControl), ATheme)
  else if AControl is TRadioButton then
    ConfigureThemedRadioButton(TRadioButton(AControl), ATheme);
{$ENDIF}
  AControl.Invalidate;
end;

procedure ApplyWin32ScrollableThemeRecursive(AControl: TWinControl; ATheme: TThemeKind);
var
  I: Integer;
  Child: TControl;
begin
  if not Assigned(AControl) then Exit;
  ApplyWin32ScrollableTheme(AControl, ATheme);
  for I := 0 to AControl.ControlCount - 1 do begin
    Child := AControl.Controls[I];
    if Child is TWinControl then
      ApplyWin32ScrollableThemeRecursive(TWinControl(Child), ATheme);
  end;
end;

procedure ApplyWin32FormChrome(AForm: TForm; ATheme: TThemeKind);
{$IFDEF WINDOWS}
var
  UseDark: LongBool;
{$ENDIF}
begin
  if not Assigned(AForm) then Exit;
  if not AForm.HandleAllocated then Exit;
{$IFDEF WINDOWS}
  UseDark := ATheme = tkDark;
  DwmSetWindowAttribute(AForm.Handle, 20, @UseDark, SizeOf(UseDark));
{$ENDIF}
end;

procedure ApplyPlatformScrollableTheme(AControl: TWinControl; ATheme: TThemeKind);
begin
  if not Assigned(AControl) then Exit;
{$IFDEF WINDOWS}
  ApplyWin32ScrollableTheme(AControl, ATheme);
  if AControl is TCustomMemo then
    SyncThemedMemoWidget(TCustomMemo(AControl));
{$ELSE}
  {$IFDEF LCLQt5}
  if AControl is TCustomMemo then begin
    ApplyQt5MemoTheme(TCustomMemo(AControl), ATheme);
    Exit;
  end;
  if AControl is TCustomEdit then begin
    ApplyQt5EditTheme(TCustomEdit(AControl), ATheme);
    Exit;
  end;
  if AControl is TComboBox then begin
    ApplyQt5ComboBoxTheme(TComboBox(AControl), ATheme);
    Exit;
  end;
  {$ENDIF}
  if AControl is TCustomListBox then begin
    SyncThemedListBoxWidget(TCustomListBox(AControl));
    Exit;
  end;
  // GTK/Cocoa: scrollbars follow the OS widget theme; keep client colors via ApplyTheme.
  AControl.Invalidate;
{$ENDIF}
end;

procedure ApplyThemedButtonsRecursive(ARoot: TWinControl; ATheme: TThemeKind);
var
  I: Integer;
  C: TControl;
  Child: TWinControl;
begin
  if not Assigned(ARoot) then Exit;
  for I := 0 to ARoot.ControlCount - 1 do begin
    C := ARoot.Controls[I];
    if C is TLcaThemedButton then
      TLcaThemedButton(C).ApplyTheme(ATheme)
    else if C is TButton then
      ApplyThemedButtonControl(TButton(C), ATheme);
    if C is TWinControl then begin
      Child := TWinControl(C);
      if Child.ControlCount > 0 then
        ApplyThemedButtonsRecursive(Child, ATheme);
    end;
  end;
end;

procedure ApplyFormPlatformThemes(AForm: TCustomForm; ATheme: TThemeKind);
begin
  if not Assigned(AForm) or not AForm.HandleAllocated then Exit;
  ApplyPlatformScrollableThemeRecursive(AForm, ATheme);
  ApplyThemedButtonsRecursive(AForm, ATheme);
end;

procedure ApplyPlatformScrollableThemeRecursive(AControl: TWinControl; ATheme: TThemeKind);
var
  I: Integer;
  Child: TControl;
begin
  if not Assigned(AControl) then Exit;
{$IFDEF WINDOWS}
  ApplyWin32ScrollableThemeRecursive(AControl, ATheme);
{$ELSE}
  ApplyPlatformScrollableTheme(AControl, ATheme);
  for I := 0 to AControl.ControlCount - 1 do begin
    Child := AControl.Controls[I];
    if Child is TWinControl then
      ApplyPlatformScrollableThemeRecursive(TWinControl(Child), ATheme);
  end;
{$ENDIF}
end;

procedure ApplyPlatformChrome(AForm: TForm; ATheme: TThemeKind);
begin
{$IFDEF WINDOWS}
  ApplyWin32FormChrome(AForm, ATheme);
{$ELSE}
  ApplyPlatformMenuChrome(AForm, ATheme);
  // macOS/Linux: title bar and scrollbars use system appearance unless the OS is in dark mode.
  if Assigned(AForm) then
    AForm.Invalidate;
{$ENDIF}
end;

type
  TThemedDrawHandlers = class
  public
    procedure ComboDrawItem(Control: TWinControl; Index: Integer; ARect: TRect;
      State: TOwnerDrawState);
    procedure ListDrawItem(Control: TWinControl; Index: Integer; ARect: TRect;
      State: TOwnerDrawState);
  end;

var
  ThemeCustomApplies: array of TThemeCustomApplyProc;
  InternalThemeApplyContext: TThemeKind = tkDark;
  ThemedDrawHandlers: TThemedDrawHandlers;

procedure RegisterThemeCustomApply(const AProc: TThemeCustomApplyProc);
begin
  SetLength(ThemeCustomApplies, Length(ThemeCustomApplies) + 1);
  ThemeCustomApplies[High(ThemeCustomApplies)] := AProc;
end;

function TryThemeCustomApply(AControl: TControl; ATheme: TThemeKind): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(ThemeCustomApplies) do
    if Assigned(ThemeCustomApplies[I]) and ThemeCustomApplies[I](AControl, ATheme) then
      Exit(True);
end;

procedure TThemedDrawHandlers.ComboDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
begin
  StyleComboBoxDrawItem(Control, Index, ARect, State, InternalThemeApplyContext);
end;

procedure TThemedDrawHandlers.ListDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
begin
  ThemedListBoxDrawItem(Control, Index, ARect, State, InternalThemeApplyContext);
end;

function ResolveThemedButtonRole(ABtn: TButton): TThemedButtonRole;
begin
  if ABtn is TLcaThemedButton then
    Exit(TLcaThemedButton(ABtn).ButtonRole);
  case ABtn.Tag of
    1: Exit(tbrPrimary);
    2: Exit(tbrDestructive);
  else
    Exit(tbrCancel);
  end;
end;

procedure ApplyThemedButtonControl(ABtn: TButton; ATheme: TThemeKind);
begin
  if not Assigned(ABtn) then Exit;
  StyleThemedButtonRole(ABtn, ATheme, ResolveThemedButtonRole(ABtn));
end;

procedure ApplyThemedPanelColors(APanel: TPanel; AColor: TColor; ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  if not Assigned(APanel) then Exit;
  P := ThemePalette(ATheme);
  APanel.Color := AColor;
  APanel.ParentColor := False;
  {$IFDEF WINDOWS}
  APanel.ParentBackground := False;
  {$ENDIF}
  APanel.Font.Color := P.Text;
  APanel.Invalidate;
end;

procedure ApplyThemedControlTree(ARoot: TWinControl; ATheme: TThemeKind);
var
  P: TThemePalette;
  I: Integer;
  C: TControl;
  Child: TWinControl;
begin
  if not Assigned(ARoot) then Exit;
  InternalThemeApplyContext := ATheme;
  P := ThemePalette(ATheme);

  for I := 0 to ARoot.ControlCount - 1 do begin
    C := ARoot.Controls[I];
    if TryThemeCustomApply(C, ATheme) then
      Continue;

    if C is TLcaThemedButton then
      TLcaThemedButton(C).ApplyTheme(ATheme)
    else if C is TButton then
      ApplyThemedButtonControl(TButton(C), ATheme)
    else if C is TLcaThemedComboBox then
      TLcaThemedComboBox(C).ApplyTheme(ATheme)
    else if C is TComboBox then begin
      StyleComboBox(TComboBox(C), ATheme);
      TComboBox(C).OnDrawItem := @ThemedDrawHandlers.ComboDrawItem;
    end else if C is TListBox then begin
      ConfigureThemedListBox(TListBox(C), ATheme);
      TListBox(C).OnDrawItem := @ThemedDrawHandlers.ListDrawItem;
      TListBox(C).Invalidate;
    end else if C is TTreeView then
      ConfigureThemedTreeView(TTreeView(C), ATheme)
    else if C is TCustomMemo then
      ConfigureThemedMemo(TCustomMemo(C), ATheme)
    else if C is TCustomEdit then begin
      TCustomEdit(C).Color := P.SurfaceAlt;
      TCustomEdit(C).Font.Color := P.Text;
    end else if C is TLabel then
      TLabel(C).Font.Color := P.Text
    else if C is TPanel then begin
      if Pos('Chrome', C.Name) > 0 then
        ApplyThemedPanelColors(TPanel(C), P.HeaderBg, ATheme)
      else
        ApplyThemedPanelColors(TPanel(C), P.Surface, ATheme);
    end
    else if C is TScrollBox then begin
      TScrollBox(C).Color := P.Surface;
      TScrollBox(C).ParentColor := False;
    end
    else if C is TPageControl then
      StylePageControl(TPageControl(C), ATheme)
    else if C is TSplitter then
      TSplitter(C).Color := P.Border
    else if C is TStatusBar then begin
      TStatusBar(C).Color := P.Surface;
      TStatusBar(C).Font.Color := P.TextMuted;
    end else if C is TCheckBox then
      ConfigureThemedCheckBox(TCheckBox(C), ATheme)
    else if C is TRadioButton then
      ConfigureThemedRadioButton(TRadioButton(C), ATheme)
    else if C is TCustomGroupBox then
      ConfigureThemedGroupBox(TCustomGroupBox(C), ATheme)
    else if C is TSpeedButton then begin
      TSpeedButton(C).Font.Color := P.TextMuted;
      TSpeedButton(C).Color := P.RailBg;
    end;

    if C is TWinControl then begin
      Child := TWinControl(C);
      if Child.ControlCount > 0 then
        ApplyThemedControlTree(Child, ATheme);
    end;
  end;
end;

procedure ApplyThemedForm(AForm: TCustomForm; ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  if not Assigned(AForm) then Exit;
  InternalThemeApplyContext := ATheme;
  P := ThemePalette(ATheme);
  AForm.Color := P.Background;
  AForm.Font.Color := P.Text;
  ApplyThemedControlTree(AForm, ATheme);
end;

initialization
  ThemedDrawHandlers := TThemedDrawHandlers.Create;

finalization
  FreeAndNil(ThemedDrawHandlers);

end.
