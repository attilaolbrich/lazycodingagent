unit LcaThemedButtonPaint;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, StdCtrls, LMessages, LcaTheme;

function ThemedButtonDisplayCaption(const ACaption: string): string;
procedure ApplyThemedButtonPaint(ABtn: TButton; ATheme: TThemeKind; ARole: TThemedButtonRole);

implementation

uses
  SysUtils, Graphics, LCLIntf, Forms, LCLType
  {$IFDEF WINDOWS}, LcaThemeWin32Buttons{$ENDIF}
  {$IFDEF LCLGtk2}, gtk2, gdk2, glib2{$ENDIF}
  {$IFDEF LCLGtk3}, gtk3widgets, LazGtk3{$ENDIF}
  {$IFDEF LCLQt5}, Qt5, QtWidgets{$ENDIF}
  ;

{$IFNDEF WINDOWS}

function NativeButtonColorToStyleHex(AColor: TColor): string;
begin
  Result := '#' + LowerCase(IntToHex(Red(AColor), 2) + IntToHex(Green(AColor), 2) +
    IntToHex(Blue(AColor), 2));
end;

procedure ResolveThemedButtonNativeColors(ATheme: TThemeKind; ARole: TThemedButtonRole; AEnabled: Boolean;
  out FillNormal, TextNormal, FillHover, TextHover, FillPressed, TextPressed: TColor);
var
  P: TThemePalette;
begin
  P := ThemePalette(ATheme);
  FillNormal := P.Surface;
  TextNormal := P.TextMuted;
  FillHover := P.SurfaceAlt;
  TextHover := P.Text;
  FillPressed := P.Border;
  TextPressed := P.Text;

  case ARole of
    tbrPrimary:
      begin
        FillNormal := P.Accent;
        TextNormal := P.AccentText;
        FillHover := P.AccentHover;
        TextHover := P.AccentText;
        FillPressed := P.AccentHover;
        TextPressed := P.AccentText;
      end;
    tbrDestructive:
      begin
        if ATheme = tkDark then begin
          FillNormal := RGBToColor(72, 32, 36);
          TextNormal := RGBToColor(248, 113, 113);
          FillHover := RGBToColor(92, 42, 48);
          FillPressed := RGBToColor(62, 28, 32);
        end else begin
          FillNormal := RGBToColor(254, 226, 226);
          TextNormal := RGBToColor(185, 28, 28);
          FillHover := RGBToColor(252, 210, 210);
          FillPressed := RGBToColor(248, 200, 200);
        end;
        TextHover := TextNormal;
        TextPressed := TextNormal;
      end;
    tbrGhost:
      begin
        FillNormal := P.HeaderBg;
        if ATheme = tkDark then
          TextNormal := P.Text
        else
          TextNormal := P.TextMuted;
        FillHover := P.SurfaceAlt;
        TextHover := P.Text;
        FillPressed := P.Border;
        TextPressed := P.Text;
      end;
  else
    begin
      if ATheme = tkDark then
        FillNormal := P.SurfaceAlt
      else
        FillNormal := P.Surface;
      TextNormal := P.TextMuted;
      FillHover := P.Border;
      TextHover := P.Text;
      FillPressed := P.Border;
      TextPressed := P.Text;
    end;
  end;

  if not AEnabled then begin
    FillNormal := P.SurfaceAlt;
    TextNormal := P.TextMuted;
    FillHover := FillNormal;
    TextHover := TextNormal;
    FillPressed := FillNormal;
    TextPressed := TextNormal;
  end;
end;

{$IFDEF LCLGtk2}
procedure TColorToGdkColor(AColor: TColor; out AGdk: TGdkColor);
begin
  AGdk.pixel := 0;
  AGdk.red := Word(Red(AColor) * 257);
  AGdk.green := Word(Green(AColor) * 257);
  AGdk.blue := Word(Blue(AColor) * 257);
end;

procedure Gtk2SetWidgetFgBg(AWidget: PGtkWidget; AState: TGtkStateType; AFg, ABg: TColor);
var
  Fg, Bg: TGdkColor;
begin
  if AWidget = nil then Exit;
  TColorToGdkColor(AFg, Fg);
  gtk_widget_modify_fg(AWidget, AState, @Fg);
  if ABg <> clNone then begin
    TColorToGdkColor(ABg, Bg);
    gtk_widget_modify_bg(AWidget, AState, @Bg);
  end;
end;

procedure ApplyGtk2NativeButtonTheme(ABtn: TButton; ATheme: TThemeKind; ARole: TThemedButtonRole);
var
  EventBox, BtnWidget, LblWidget: PGtkWidget;
  FillNormal, TextNormal, FillHover, TextHover, FillPressed, TextPressed: TColor;
  LabelUtf8: UTF8String;
begin
  if not Assigned(ABtn) or not ABtn.HandleAllocated then Exit;
  ResolveThemedButtonNativeColors(ATheme, ARole, ABtn.Enabled, FillNormal, TextNormal, FillHover,
    TextHover, FillPressed, TextPressed);

  EventBox := PGtkWidget(Pointer(ABtn.Handle));
  if (EventBox = nil) or not GTK_IS_BIN(EventBox) then Exit;
  BtnWidget := GTK_BIN(EventBox)^.child;
  if BtnWidget = nil then Exit;

  gtk_button_set_relief(PGtkButton(BtnWidget), GTK_RELIEF_NONE);

  Gtk2SetWidgetFgBg(BtnWidget, GTK_STATE_NORMAL, TextNormal, FillNormal);
  Gtk2SetWidgetFgBg(BtnWidget, GTK_STATE_PRELIGHT, TextHover, FillHover);
  Gtk2SetWidgetFgBg(BtnWidget, GTK_STATE_ACTIVE, TextPressed, FillPressed);
  Gtk2SetWidgetFgBg(BtnWidget, GTK_STATE_INSENSITIVE, TextNormal, FillNormal);

  LabelUtf8 := UTF8Encode(ThemedButtonDisplayCaption(ABtn.Caption));
  gtk_button_set_label(PGtkButton(BtnWidget), PAnsiChar(LabelUtf8));

  if GTK_IS_BIN(BtnWidget) then begin
    LblWidget := GTK_BIN(BtnWidget)^.child;
    if (LblWidget <> nil) and GTK_IS_LABEL(LblWidget) then begin
      Gtk2SetWidgetFgBg(LblWidget, GTK_STATE_NORMAL, TextNormal, clNone);
      Gtk2SetWidgetFgBg(LblWidget, GTK_STATE_PRELIGHT, TextHover, clNone);
      Gtk2SetWidgetFgBg(LblWidget, GTK_STATE_ACTIVE, TextPressed, clNone);
      Gtk2SetWidgetFgBg(LblWidget, GTK_STATE_INSENSITIVE, TextNormal, clNone);
    end;
  end;

  gtk_widget_queue_draw(BtnWidget);
end;
{$ENDIF}

{$IFDEF LCLGtk3}
procedure ApplyGtk3NativeButtonTheme(ABtn: TButton; ATheme: TThemeKind; ARole: TThemedButtonRole);
var
  GtkBtn: TGtk3Button;
  FillNormal, TextNormal, FillHover, TextHover, FillPressed, TextPressed: TColor;
  LabelUtf8: UTF8String;
begin
  if not Assigned(ABtn) or not ABtn.HandleAllocated then Exit;
  ResolveThemedButtonNativeColors(ATheme, ARole, ABtn.Enabled, FillNormal, TextNormal, FillHover,
    TextHover, FillPressed, TextPressed);

  GtkBtn := TGtk3Button(Pointer(ABtn.Handle));
  if (GtkBtn = nil) or not GtkBtn.IsWidgetOk then Exit;

  gtk_button_set_relief(PGtkButton(GtkBtn.Widget), GTK_RELIEF_NONE);
  LabelUtf8 := UTF8Encode(ThemedButtonDisplayCaption(ABtn.Caption));
  gtk_button_set_label(PGtkButton(GtkBtn.Widget), PAnsiChar(LabelUtf8));
  GtkBtn.Color := FillNormal;
  GtkBtn.FontColor := TextNormal;
  gtk_widget_queue_draw(GtkBtn.Widget);
end;
{$ENDIF}

{$IFDEF LCLQt5}
procedure ApplyQt5NativeButtonTheme(ABtn: TButton; ATheme: TThemeKind; ARole: TThemedButtonRole);
var
  QtBtn: TQtPushButton;
  FillNormal, TextNormal, FillHover, TextHover, FillPressed, TextPressed: TColor;
  BorderColor: TColor;
  Sheet: WideString;
  BorderRule, Radius: string;
begin
  if not Assigned(ABtn) or not ABtn.HandleAllocated then Exit;
  ResolveThemedButtonNativeColors(ATheme, ARole, ABtn.Enabled, FillNormal, TextNormal, FillHover,
    TextHover, FillPressed, TextPressed);

  QtBtn := TQtPushButton(Pointer(ABtn.Handle));
  if QtBtn = nil then Exit;

  QPushButton_setFlat(QPushButtonH(QtBtn.Widget), ARole = tbrGhost);

  if ARole = tbrCancel then begin
    if ATheme = tkDark then
      BorderColor := ThemePalette(ATheme).BorderStrong
    else
      BorderColor := ThemePalette(ATheme).Border;
    BorderRule := 'border: 1px solid ' + NativeButtonColorToStyleHex(BorderColor) + '; ';
  end else
    BorderRule := 'border: none; ';

  Radius := '6px';

  Sheet := WideString(
    'QPushButton { color: ' + NativeButtonColorToStyleHex(TextNormal) + ' !important; ' +
    'background-color: ' + NativeButtonColorToStyleHex(FillNormal) + ' !important; ' +
    BorderRule + 'border-radius: ' + Radius + '; padding: 0; min-height: 0; } ' +
    'QPushButton:hover { color: ' + NativeButtonColorToStyleHex(TextHover) + ' !important; ' +
    'background-color: ' + NativeButtonColorToStyleHex(FillHover) + ' !important; } ' +
    'QPushButton:pressed { color: ' + NativeButtonColorToStyleHex(TextPressed) + ' !important; ' +
    'background-color: ' + NativeButtonColorToStyleHex(FillPressed) + ' !important; } ' +
    'QPushButton:disabled { color: ' + NativeButtonColorToStyleHex(TextNormal) + ' !important; ' +
    'background-color: ' + NativeButtonColorToStyleHex(FillNormal) + ' !important; }');
  QtBtn.StyleSheet := Sheet;
end;
{$ENDIF}

procedure ApplyNativePlatformButtonTheme(ABtn: TButton; ATheme: TThemeKind; ARole: TThemedButtonRole);
begin
  {$IFDEF LCLGtk2}
  ApplyGtk2NativeButtonTheme(ABtn, ATheme, ARole);
  {$ENDIF}
  {$IFDEF LCLGtk3}
  ApplyGtk3NativeButtonTheme(ABtn, ATheme, ARole);
  {$ENDIF}
  {$IFDEF LCLQt5}
  ApplyQt5NativeButtonTheme(ABtn, ATheme, ARole);
  {$ENDIF}
end;

type
  TLclThemedButtonPaint = class(TComponent)
  private
    FButton: TButton;
    FTheme: TThemeKind;
    FRole: TThemedButtonRole;
    FHover: Boolean;
    FPressed: Boolean;
    FChainedWindowProc: Boolean;
    FPrevWindowProc: TWndMethod;
    FPrevOnMouseDown: TMouseEvent;
    FPrevOnMouseUp: TMouseEvent;
    FPrevOnMouseLeave: TNotifyEvent;
    FPrevOnMouseEnter: TNotifyEvent;
    procedure ButtonWindowProc(var Message: TLMessage);
    procedure HookMouseEvents;
    procedure MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer);
    procedure MouseEnter(Sender: TObject);
    procedure MouseLeave(Sender: TObject);
    procedure InvalidateButton;
    procedure PaintClient;
    function ParentBackgroundColor: TColor;
    function DisplayCaption: string;
    function IsPressed: Boolean;
  public
    constructor Create(AOwner: TButton); reintroduce;
    destructor Destroy; override;
    procedure Apply(ATheme: TThemeKind; ARole: TThemedButtonRole);
    class function FindOnButton(ABtn: TButton): TLclThemedButtonPaint;
  end;

class function TLclThemedButtonPaint.FindOnButton(ABtn: TButton): TLclThemedButtonPaint;
var
  I: Integer;
begin
  Result := nil;
  if not Assigned(ABtn) then Exit;
  for I := 0 to ABtn.ComponentCount - 1 do
    if ABtn.Components[I] is TLclThemedButtonPaint then
      Exit(TLclThemedButtonPaint(ABtn.Components[I]));
end;

constructor TLclThemedButtonPaint.Create(AOwner: TButton);
begin
  inherited Create(AOwner);
  FButton := AOwner;
  FHover := False;
  FPressed := False;
  FChainedWindowProc := False;
end;

destructor TLclThemedButtonPaint.Destroy;
begin
  if Assigned(FButton) then begin
    if FChainedWindowProc then
      FButton.WindowProc := FPrevWindowProc;
    if Assigned(FPrevOnMouseDown) then
      FButton.OnMouseDown := FPrevOnMouseDown;
    if Assigned(FPrevOnMouseUp) then
      FButton.OnMouseUp := FPrevOnMouseUp;
    if Assigned(FPrevOnMouseLeave) then
      FButton.OnMouseLeave := FPrevOnMouseLeave;
    if Assigned(FPrevOnMouseEnter) then
      FButton.OnMouseEnter := FPrevOnMouseEnter;
  end;
  inherited Destroy;
end;

procedure TLclThemedButtonPaint.InvalidateButton;
begin
  if Assigned(FButton) then
    FButton.Invalidate;
end;

function TLclThemedButtonPaint.ParentBackgroundColor: TColor;
begin
  if Assigned(FButton.Parent) then
    Result := FButton.Parent.Color
  else
    Result := clBtnFace;
end;

function TLclThemedButtonPaint.DisplayCaption: string;
begin
  Result := ThemedButtonDisplayCaption(FButton.Caption);
end;

function TLclThemedButtonPaint.IsPressed: Boolean;
begin
  Result := FPressed and FButton.Enabled;
end;

procedure TLclThemedButtonPaint.PaintClient;
var
  R: TRect;
  Canvas: TControlCanvas;
  Enabled, Focused: Boolean;
begin
  if not Assigned(FButton) then Exit;
  Canvas := TControlCanvas.Create;
  try
    Canvas.Control := FButton;
    R := FButton.ClientRect;
    Canvas.Brush.Color := ParentBackgroundColor;
    Canvas.FillRect(R);
    Enabled := FButton.Enabled;
    Focused := FButton.Focused;
    Canvas.Font.Assign(FButton.Font);
    PaintThemedButton(Canvas, R, FTheme, FRole, DisplayCaption, Enabled, FHover and Enabled,
      IsPressed, Focused, ThemedButtonCornerRadius(FButton), FButton.Font.Size, 0, FButton);
  finally
    Canvas.Free;
  end;
end;

procedure TLclThemedButtonPaint.ButtonWindowProc(var Message: TLMessage);
begin
  case Message.Msg of
    LM_ERASEBKGND:
      begin
        Message.Result := 1;
        Exit;
      end;
    LM_PAINT:
      begin
        PaintClient;
        Message.Result := 0;
        Exit;
      end;
    LM_SETFOCUS, LM_KILLFOCUS, LM_ENABLE:
      InvalidateButton;
  end;
  if Assigned(FPrevWindowProc) then
    FPrevWindowProc(Message);
end;

procedure TLclThemedButtonPaint.MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then begin
    FPressed := True;
    InvalidateButton;
  end;
  if Assigned(FPrevOnMouseDown) then
    FPrevOnMouseDown(Sender, Button, Shift, X, Y);
end;

procedure TLclThemedButtonPaint.MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then begin
    FPressed := False;
    InvalidateButton;
  end;
  if Assigned(FPrevOnMouseUp) then
    FPrevOnMouseUp(Sender, Button, Shift, X, Y);
end;

procedure TLclThemedButtonPaint.MouseEnter(Sender: TObject);
begin
  FHover := True;
  InvalidateButton;
  if Assigned(FPrevOnMouseEnter) then
    FPrevOnMouseEnter(Sender);
end;

procedure TLclThemedButtonPaint.MouseLeave(Sender: TObject);
begin
  FHover := False;
  FPressed := False;
  InvalidateButton;
  if Assigned(FPrevOnMouseLeave) then
    FPrevOnMouseLeave(Sender);
end;

procedure TLclThemedButtonPaint.HookMouseEvents;
begin
  if not Assigned(FButton) then Exit;
  FPrevOnMouseDown := FButton.OnMouseDown;
  FPrevOnMouseUp := FButton.OnMouseUp;
  FPrevOnMouseLeave := FButton.OnMouseLeave;
  FPrevOnMouseEnter := FButton.OnMouseEnter;
  FButton.OnMouseDown := @MouseDown;
  FButton.OnMouseUp := @MouseUp;
  FButton.OnMouseLeave := @MouseLeave;
  FButton.OnMouseEnter := @MouseEnter;
end;

procedure TLclThemedButtonPaint.Apply(ATheme: TThemeKind; ARole: TThemedButtonRole);
begin
  FTheme := ATheme;
  FRole := ARole;
  if Assigned(FButton) then
    ApplyNativePlatformButtonTheme(FButton, ATheme, ARole);
  if not FChainedWindowProc and Assigned(FButton) then begin
    FPrevWindowProc := FButton.WindowProc;
    FButton.WindowProc := @ButtonWindowProc;
    FChainedWindowProc := True;
    HookMouseEvents;
    FButton.ControlStyle := FButton.ControlStyle + [csOpaque];
  end;
  if Assigned(FButton) then
    FButton.Invalidate;
end;

procedure ApplyLclThemedButtonPaint(ABtn: TButton; ATheme: TThemeKind; ARole: TThemedButtonRole);
var
  Helper: TLclThemedButtonPaint;
begin
  if not Assigned(ABtn) then Exit;
  if csDesigning in ABtn.ComponentState then Exit;
  if csLoading in ABtn.ComponentState then Exit;
  if csReading in ABtn.ComponentState then Exit;
  if not ABtn.HandleAllocated then Exit;
  Helper := TLclThemedButtonPaint.FindOnButton(ABtn);
  if Helper = nil then
    Helper := TLclThemedButtonPaint.Create(ABtn);
  Helper.Apply(ATheme, ARole);
end;

{$ENDIF}

function ThemedButtonDisplayCaption(const ACaption: string): string;
var
  P: Integer;
begin
  Result := ACaption;
  P := Pos('&', Result);
  while P > 0 do begin
    if (P < Length(Result)) and (Result[P + 1] = '&') then
      Delete(Result, P, 1)
    else
      Delete(Result, P, 1);
    P := Pos('&', Result);
  end;
end;

procedure ApplyThemedButtonPaint(ABtn: TButton; ATheme: TThemeKind; ARole: TThemedButtonRole);
begin
  if not Assigned(ABtn) then Exit;
  if csDesigning in ABtn.ComponentState then Exit;
  if csLoading in ABtn.ComponentState then Exit;
  if csReading in ABtn.ComponentState then Exit;
  {$IFDEF WINDOWS}
  ApplyWin32ThemedButtonPaint(ABtn, ATheme, ARole);
  {$ELSE}
  if not ABtn.HandleAllocated then Exit;
  {$IFDEF LCLGtk2}
  ApplyNativePlatformButtonTheme(ABtn, ATheme, ARole);
  {$ELSE}
  {$IFDEF LCLGtk3}
  ApplyNativePlatformButtonTheme(ABtn, ATheme, ARole);
  {$ELSE}
  {$IFDEF LCLQt5}
  ApplyNativePlatformButtonTheme(ABtn, ATheme, ARole);
  {$ELSE}
  ApplyLclThemedButtonPaint(ABtn, ATheme, ARole);
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
end;

end.
