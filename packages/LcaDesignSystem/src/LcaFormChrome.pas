unit LcaFormChrome;

{$mode objfpc}{$H+}
{$IFDEF LCLcocoa}{$modeswitch objectivec1}{$ENDIF}

interface

uses
  Classes, SysUtils, Controls, Forms, LCLType, LCLIntf, LCLProc, LMessages, Types;

type
  TLcaFormChrome = class(TComponent)
  private
    FForm: TCustomForm;
    FOldWindowProc: TWndMethod;
    FBorderlessApplied: Boolean;
    FCocoaPlatformChromeApplied: Boolean;
    procedure WndProc(var Message: TLMessage);
    function EdgeHitTestClient(const P: TPoint): PtrInt;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Attach(AForm: TCustomForm);
    procedure ApplyFrameless;
    procedure EnsurePlatformChrome;
    class procedure BeginMove(AForm: TCustomForm; AButton: TMouseButton;
      const AScreenPos: TPoint); static;
    class function FormIsMaximized(AForm: TCustomForm): Boolean; static;
    class procedure SetFormMaximized(AForm: TCustomForm; AMaximized: Boolean); static;
    class procedure SetFormMinimized(AForm: TCustomForm); static;
    class procedure ToggleFormMaximize(AForm: TCustomForm); static;
    class procedure EnsureWidgetGeometry(AForm: TCustomForm); static;
    class procedure DebugDumpQt5ChromeState(AForm: TCustomForm;
      const ATag: string); static;
  end;

function AttachLcaFormChrome(AForm: TCustomForm): TLcaFormChrome;
function LcaControlIsThemedWindowButton(AControl: TControl): Boolean;

implementation

uses
  Math
  {$IFDEF WINDOWS}, Windows{$ENDIF}
  {$IFDEF LCLGtk2}, Gtk2, Gdk2{$ENDIF}
  {$IFDEF LCLGtk3}, LazGtk3, LazGdk3, LazGObject2{$ENDIF}
  {$IFDEF LCLQt5}, QtWidgets, qt5{$ENDIF}
  {$IFDEF LCLcocoa}, CocoaAll, Cocoa_Extra{$ENDIF}
  ;

const
  HTCLIENT = 1;
  HTLEFT = 10;
  HTRIGHT = 11;
  HTTOP = 12;
  HTTOPLEFT = 13;
  HTTOPRIGHT = 14;
  HTBOTTOM = 15;
  HTBOTTOMLEFT = 16;
  HTBOTTOMRIGHT = 17;

type
  TFormChromeInputHelper = class
    procedure UserInputBefore(Sender: TObject; Msg: Cardinal);
    procedure UserInputAfter(Sender: TObject; Msg: Cardinal);
  end;

var
  GFormChromeInputHelper: TFormChromeInputHelper = nil;
  GFormChromeInputHookInstalled: Boolean = False;
  GEdgeResizeCursorActive: Boolean = False;
  GFramelessForms: array of TCustomForm;
  GDragForm: TCustomForm = nil;
  GDragStartCursor: TPoint;
  GDragStartFormPos: TPoint;
  GResizeForm: TCustomForm = nil;
  GResizeHit: Integer;
  GResizeStartCursor: TPoint;
  GResizeStartBounds: TRect;
  GManualLeftDown: Boolean = False;

{$IFDEF LCLQt5}
const
  Qt5WidgetSizeMax = 16777215;

var
  GQt5ChromeX11Warned: Boolean = False;
{$ENDIF}

procedure AlignLclWindowState(AForm: TCustomForm; AMaximized: Boolean); forward;
{$IFDEF LCLQt5}
function Qt5FormWidget(AForm: TCustomForm): TQtWidget; forward;
procedure Qt5SyncLclBoundsFromWidget(AForm: TCustomForm); forward;
procedure Qt5ReleaseFixedSize(AForm: TCustomForm); forward;
{$ENDIF}

function EdgeSize(AForm: TCustomForm): Integer;
begin
  Result := MulDiv(8, AForm.PixelsPerInch, 96);
  if Result < 4 then
    Result := 4;
end;

function EdgeHitTestOnForm(AForm: TCustomForm; const P: TPoint): PtrInt;
var
  E, W, H: Integer;
begin
  Result := HTCLIENT;
  if AForm = nil then Exit;
  W := AForm.ClientWidth;
  H := AForm.ClientHeight;
  E := EdgeSize(AForm);
  if (P.X < 0) or (P.Y < 0) or (P.X >= W) or (P.Y >= H) then Exit;
  if P.Y < E then begin
    if P.X < E then Exit(HTTOPLEFT);
    if P.X >= W - E then Exit(HTTOPRIGHT);
    Exit(HTTOP);
  end;
  if P.Y >= H - E then begin
    if P.X < E then Exit(HTBOTTOMLEFT);
    if P.X >= W - E then Exit(HTBOTTOMRIGHT);
    Exit(HTBOTTOM);
  end;
  if P.X < E then Exit(HTLEFT);
  if P.X >= W - E then Exit(HTRIGHT);
end;

procedure ApplyCursorForHit(AHit: Integer);
begin
  if AHit <> HTCLIENT then begin
    case AHit of
      HTLEFT, HTRIGHT: Screen.Cursor := crSizeWE;
      HTTOP, HTBOTTOM: Screen.Cursor := crSizeNS;
      HTTOPLEFT, HTBOTTOMRIGHT: Screen.Cursor := crSizeNWSE;
      HTTOPRIGHT, HTBOTTOMLEFT: Screen.Cursor := crSizeNESW;
    else
      Exit;
    end;
    GEdgeResizeCursorActive := True;
  end else if GEdgeResizeCursorActive then begin
    Screen.Cursor := crDefault;
    GEdgeResizeCursorActive := False;
  end;
end;

function FramelessEdgeHitAtScreen(const AScreenPos: TPoint): Integer;
var
  I: Integer;
  F: TCustomForm;
  ClientP: TPoint;
begin
  Result := HTCLIENT;
  for I := 0 to High(GFramelessForms) do begin
    F := GFramelessForms[I];
    if not F.Visible then Continue;
    if not PtInRect(F.BoundsRect, AScreenPos) then Continue;
    ClientP := F.ScreenToClient(AScreenPos);
    Result := EdgeHitTestOnForm(F, ClientP);
    if Result <> HTCLIENT then Exit;
  end;
end;

procedure UpdateFramelessEdgeCursor;
begin
  if Length(GFramelessForms) = 0 then Exit;
  ApplyCursorForHit(FramelessEdgeHitAtScreen(Mouse.CursorPos));
end;

function ManualDragResizeActive: Boolean;
begin
  Result := GManualLeftDown or ((GetKeyState(VK_LBUTTON) and $8000) <> 0);
end;

procedure RegisterFramelessForm(AForm: TCustomForm);
var
  I, N: Integer;
begin
  if AForm = nil then Exit;
  for I := 0 to High(GFramelessForms) do
    if GFramelessForms[I] = AForm then Exit;
  N := Length(GFramelessForms);
  SetLength(GFramelessForms, N + 1);
  GFramelessForms[N] := AForm;
end;

procedure UnregisterFramelessForm(AForm: TCustomForm);
var
  I, N: Integer;
begin
  N := Length(GFramelessForms);
  for I := 0 to N - 1 do
    if GFramelessForms[I] = AForm then begin
      if I < N - 1 then
        GFramelessForms[I] := GFramelessForms[N - 1];
      SetLength(GFramelessForms, N - 1);
      Exit;
    end;
end;

procedure EnsureFormChromeInputHook;
begin
  if GFormChromeInputHookInstalled then Exit;
  if GFormChromeInputHelper = nil then
    GFormChromeInputHelper := TFormChromeInputHelper.Create;
  Application.AddOnUserInputHandler(@GFormChromeInputHelper.UserInputBefore, True);
  Application.AddOnUserInputHandler(@GFormChromeInputHelper.UserInputAfter, False);
  GFormChromeInputHookInstalled := True;
end;

procedure StopDrag;
var
  F: TCustomForm;
begin
  F := GDragForm;
  GDragForm := nil;
  if GResizeForm = nil then
    GManualLeftDown := False;
  {$IFDEF LCLQt5}
  if F <> nil then
    Qt5SyncLclBoundsFromWidget(F);
  {$ENDIF}
end;

procedure StopResize;
begin
  GResizeForm := nil;
  GResizeHit := HTCLIENT;
  if GDragForm = nil then
    GManualLeftDown := False;
end;

procedure ApplyResizeBounds(AForm: TCustomForm; var R: TRect);
var
  MinW, MinH: Integer;
begin
  MinW := AForm.Constraints.MinWidth;
  MinH := AForm.Constraints.MinHeight;
  if MinW <= 0 then MinW := 200;
  if MinH <= 0 then MinH := 120;
  if R.Width < MinW then begin
    if GResizeHit in [HTLEFT, HTTOPLEFT, HTBOTTOMLEFT] then
      R.Left := R.Right - MinW;
    R.Right := R.Left + MinW;
  end;
  if R.Height < MinH then begin
    if GResizeHit in [HTTOP, HTTOPLEFT, HTTOPRIGHT] then
      R.Top := R.Bottom - MinH;
    R.Bottom := R.Top + MinH;
  end;
end;

procedure UpdateDragPosition;
var
  P: TPoint;
  NewLeft, NewTop: Integer;
begin
  if GDragForm = nil then Exit;
  P := Mouse.CursorPos;
  NewLeft := GDragStartFormPos.X + (P.X - GDragStartCursor.X);
  NewTop := GDragStartFormPos.Y + (P.Y - GDragStartCursor.Y);
  GDragForm.SetBounds(NewLeft, NewTop, GDragForm.Width, GDragForm.Height);
end;

procedure UpdateResizeBounds;
var
  P: TPoint;
  R: TRect;
  DX, DY: Integer;
begin
  if GResizeForm = nil then Exit;
  P := Mouse.CursorPos;
  DX := P.X - GResizeStartCursor.X;
  DY := P.Y - GResizeStartCursor.Y;
  R := GResizeStartBounds;
  case GResizeHit of
    HTLEFT, HTTOPLEFT, HTBOTTOMLEFT:
      R.Left := GResizeStartBounds.Left + DX;
    HTRIGHT, HTTOPRIGHT, HTBOTTOMRIGHT:
      R.Right := GResizeStartBounds.Right + DX;
  end;
  case GResizeHit of
    HTTOP, HTTOPLEFT, HTTOPRIGHT:
      R.Top := GResizeStartBounds.Top + DY;
    HTBOTTOM, HTBOTTOMLEFT, HTBOTTOMRIGHT:
      R.Bottom := GResizeStartBounds.Bottom + DY;
  end;
  ApplyResizeBounds(GResizeForm, R);
  GResizeForm.SetBounds(R.Left, R.Top, R.Width, R.Height);
end;

procedure StartManualDrag(AForm: TCustomForm; const AScreenPos: TPoint);
{$IFDEF LCLQt5}
var
  W: TQtWidget;
{$ENDIF}
begin
  StopResize;
  {$IFDEF LCLQt5}
  W := Qt5FormWidget(AForm);
  if (W <> nil) and W.isMaximized then begin
    W.ShowNormal;
    Application.ProcessMessages;
    Qt5SyncLclBoundsFromWidget(AForm);
  end;
  {$ENDIF}
  GDragForm := AForm;
  GDragStartCursor := AScreenPos;
  GDragStartFormPos.X := AForm.Left;
  GDragStartFormPos.Y := AForm.Top;
  GManualLeftDown := True;
  EnsureFormChromeInputHook;
end;

procedure StartManualResize(AForm: TCustomForm; AHit: Integer; const AScreenPos: TPoint);
begin
  StopDrag;
  GResizeForm := AForm;
  GResizeHit := AHit;
  GResizeStartCursor := AScreenPos;
  GResizeStartBounds.Left := AForm.Left;
  GResizeStartBounds.Top := AForm.Top;
  GResizeStartBounds.Right := AForm.Left + AForm.Width;
  GResizeStartBounds.Bottom := AForm.Top + AForm.Height;
  GManualLeftDown := True;
  EnsureFormChromeInputHook;
end;

{$IFDEF LCLGtk2}
function Gtk2FormIsMaximized(AForm: TCustomForm): Boolean;
var
  W: PGtkWidget;
  AFlags: TGdkWindowState;
begin
  Result := False;
  if AForm = nil then Exit;
  if not AForm.HandleAllocated then Exit;
  W := PGtkWidget(Pointer(AForm.Handle));
  if W = nil then Exit;
  if not GTK_IS_WINDOW(W) then Exit;
  if PGtkWidget(W)^.window = nil then Exit;
  AFlags := gdk_window_get_state(PGtkWidget(W)^.window);
  Result := (AFlags and GDK_WINDOW_STATE_MAXIMIZED) <> 0;
end;
{$ENDIF}

{$IFDEF LCLGtk3}
function TryGtk3BeginMove(AForm: TCustomForm; AButton: TMouseButton;
  const AScreenPos: TPoint): Boolean;
var
  W: PGtkWidget;
  Btn: Integer;
begin
  Result := False;
  if AForm = nil then Exit;
  if not AForm.HandleAllocated then Exit;
  W := PGtkWidget(Pointer(AForm.Handle));
  if W = nil then Exit;
  if not gtk_type_is_a(gtk_widget_get_type(W), gtk_window_get_type()) then Exit;
  Btn := 1;
  if AButton = mbRight then Btn := 3
  else if AButton = mbMiddle then Btn := 2;
  gtk_window_begin_move_drag(PGtkWindow(W), Btn, AScreenPos.X, AScreenPos.Y, 0);
  Result := True;
end;

function Gtk3FormIsMaximized(AForm: TCustomForm): Boolean;
var
  W: PGtkWidget;
begin
  Result := False;
  if AForm = nil then Exit;
  if not AForm.HandleAllocated then Exit;
  W := PGtkWidget(Pointer(AForm.Handle));
  if W = nil then Exit;
  if not gtk_type_is_a(gtk_widget_get_type(W), gtk_window_get_type()) then Exit;
  Result := gtk_window_is_maximized(PGtkWindow(W));
end;

function TryGtk3SetMaximized(AForm: TCustomForm; AMaximized: Boolean): Boolean;
var
  W: PGtkWidget;
begin
  Result := False;
  if AForm = nil then Exit;
  if not AForm.HandleAllocated then Exit;
  W := PGtkWidget(Pointer(AForm.Handle));
  if W = nil then Exit;
  if not gtk_type_is_a(gtk_widget_get_type(W), gtk_window_get_type()) then Exit;
  if AMaximized then
    gtk_window_maximize(PGtkWindow(W))
  else
    gtk_window_unmaximize(PGtkWindow(W));
  Result := True;
end;

function TryGtk3BeginResize(AForm: TCustomForm; AHit: Integer;
  const AScreenPos: TPoint): Boolean;
var
  W: PGtkWidget;
  Edge: TGdkWindowEdge;
begin
  Result := False;
  if AForm = nil then Exit;
  if not AForm.HandleAllocated then Exit;
  W := PGtkWidget(Pointer(AForm.Handle));
  if W = nil then Exit;
  if not gtk_type_is_a(gtk_widget_get_type(W), gtk_window_get_type()) then Exit;
  case AHit of
    HTLEFT: Edge := GDK_WINDOW_EDGE_WEST;
    HTRIGHT: Edge := GDK_WINDOW_EDGE_EAST;
    HTTOP: Edge := GDK_WINDOW_EDGE_NORTH;
    HTBOTTOM: Edge := GDK_WINDOW_EDGE_SOUTH;
    HTTOPLEFT: Edge := GDK_WINDOW_EDGE_NORTH_WEST;
    HTTOPRIGHT: Edge := GDK_WINDOW_EDGE_NORTH_EAST;
    HTBOTTOMLEFT: Edge := GDK_WINDOW_EDGE_SOUTH_WEST;
    HTBOTTOMRIGHT: Edge := GDK_WINDOW_EDGE_SOUTH_EAST;
  else
    Exit;
  end;
  gtk_window_begin_resize_drag(PGtkWindow(W), Edge, 1, AScreenPos.X, AScreenPos.Y, 0);
  Result := True;
end;
{$ELSE}
{$Push}
{$H-}
function TryGtk3BeginMove(AForm: TCustomForm; AButton: TMouseButton;
  const AScreenPos: TPoint): Boolean;
begin
  Result := False;
end;

function Gtk3FormIsMaximized(AForm: TCustomForm): Boolean;
begin
  Result := False;
end;

function TryGtk3SetMaximized(AForm: TCustomForm; AMaximized: Boolean): Boolean;
begin
  Result := False;
end;

function TryGtk3BeginResize(AForm: TCustomForm; AHit: Integer;
  const AScreenPos: TPoint): Boolean;
begin
  Result := False;
end;
{$Pop}
{$ENDIF}

{$IFDEF LCLcocoa}
function CocoaFormWindow(AForm: TCustomForm): NSWindow;
var
  V: NSView;
begin
  Result := nil;
  if AForm = nil then Exit;
  if not AForm.HandleAllocated then Exit;
  V := NSView(AForm.Handle);
  if V = nil then Exit;
  Result := V.window;
end;

procedure HideCocoaStandardWindowButtons(AWindow: NSWindow);
var
  Btn: NSButton;
begin
  if AWindow = nil then Exit;
  Btn := AWindow.standardWindowButton(NSWindowCloseButton);
  if Btn <> nil then
    Btn.setHidden(True);
  Btn := AWindow.standardWindowButton(NSWindowMiniaturizeButton);
  if Btn <> nil then
    Btn.setHidden(True);
  Btn := AWindow.standardWindowButton(NSWindowZoomButton);
  if Btn <> nil then
    Btn.setHidden(True);
end;

function ApplyCocoaFramelessChrome(AForm: TCustomForm): Boolean;
var
  W: NSWindow;
  Mask: NSUInteger;
begin
  Result := False;
  if AForm = nil then Exit;
  if not AForm.HandleAllocated then
    AForm.HandleNeeded;
  W := CocoaFormWindow(AForm);
  if W = nil then Exit;
  Mask := W.styleMask;
  Mask := Mask or NSTitledWindowMask or NSResizableWindowMask or
    NSFullSizeContentViewWindowMask;
  W.setStyleMask(Mask);
  W.setTitlebarAppearsTransparent(True);
  W.setTitleVisibility(NSWindowTitleHidden);
  HideCocoaStandardWindowButtons(W);
  Result := True;
end;

function TryCocoaBeginMove(AForm: TCustomForm): Boolean;
var
  W: NSWindow;
  Ev: NSEvent;
  EvType: NSUInteger;
begin
  Result := False;
  if AForm = nil then Exit;
  if not AForm.HandleAllocated then
    AForm.HandleNeeded;
  Ev := NSApplication.sharedApplication.currentEvent;
  if Ev = nil then Exit;
  EvType := Ev.type_;
  if (EvType <> NSLeftMouseDown) and (EvType <> NSLeftMouseDragged) then Exit;
  W := CocoaFormWindow(AForm);
  if W = nil then Exit;
  NSWindowFix(W).performWindowDragWithEvent(Ev);
  Result := True;
end;

function TryCocoaSetMaximized(AForm: TCustomForm; AMaximized: Boolean): Boolean;
var
  W: NSWindow;
begin
  Result := False;
  if AForm = nil then Exit;
  if not AForm.HandleAllocated then
    AForm.HandleNeeded;
  W := CocoaFormWindow(AForm);
  if W = nil then Exit;
  if AMaximized then begin
    if not W.isZoomed then
      W.performZoom(nil);
  end else begin
    if W.isZoomed then
      W.performZoom(nil);
  end;
  Result := True;
end;
{$ELSE}
function ApplyCocoaFramelessChrome(AForm: TCustomForm): Boolean;
begin
  Result := False;
end;

function TryCocoaBeginMove(AForm: TCustomForm): Boolean;
begin
  Result := False;
end;

function TryCocoaSetMaximized(AForm: TCustomForm; AMaximized: Boolean): Boolean;
begin
  Result := False;
end;
{$ENDIF}

function ClientControlOnForm(AForm: TCustomForm; const ClientP: TPoint): TControl;
begin
  Result := nil;
  if not (AForm is TWinControl) then Exit;
  Result := TWinControl(AForm).ControlAtPos(ClientP, False);
end;

function LcaControlIsThemedWindowButton(AControl: TControl): Boolean;
begin
  Result := Assigned(AControl) and
    (CompareText(AControl.ClassName, 'TLcaThemedWindowButton') = 0);
end;

{$IFDEF LCLQt5}
{$IFDEF UNIX}
{$linklib X11}

type
  TQt5XDisplay = Pointer;
  TQt5XWindow = PtrUInt;
  TQt5XDrawable = PtrUInt;
  PTQt5XWindow = ^TQt5XWindow;

function XDefaultRootWindow(display: TQt5XDisplay): TQt5XWindow; cdecl; external 'X11';
function XGetGeometry(display: TQt5XDisplay; d: TQt5XDrawable; root_return: PTQt5XWindow;
  x, y, width, height, border_width, depth: PInteger): Integer; cdecl; external 'X11';
function XTranslateCoordinates(display: TQt5XDisplay; src_w, dest_w: TQt5XWindow;
  src_x, src_y: Integer; dest_x_return, dest_y_return: PInteger;
  child_return: PTQt5XWindow): Integer; cdecl; external 'X11';

function Qt5X11WindowBoundsOnRoot(AWidget: QWidgetH; out R: TRect): Boolean;
var
  Dpy: TQt5XDisplay;
  Root, Win: TQt5XWindow;
  X, Y, W, H, BW, Depth: Integer;
  AbsX, AbsY: Integer;
  Child: TQt5XWindow;
begin
  Result := False;
  FillChar(R, SizeOf(R), 0);
  Dpy := QX11Info_display();
  if Dpy = nil then Exit;
  Win := QWidget_winId(AWidget);
  if Win = 0 then Exit;
  Root := XDefaultRootWindow(Dpy);
  if XGetGeometry(Dpy, Win, @Root, @X, @Y, @W, @H, @BW, @Depth) = 0 then Exit;
  if XTranslateCoordinates(Dpy, Win, Root, 0, 0, @AbsX, @AbsY, @Child) = 0 then Exit;
  R := Bounds(AbsX, AbsY, W, H);
  Result := (W > 0) and (H > 0);
end;
{$ENDIF}

function Qt5RectUsable(const R: TRect): Boolean;
begin
  Result := (R.Width > 0) and (R.Height > 0);
end;

procedure Qt5ChromeDebug(const AMsg: string);
begin
  if GetEnvironmentVariable('LAZY_DEBUG_CHROME') = '' then Exit;
  WriteLn(StdErr, 'Qt5 chrome: ', AMsg);
end;

procedure Qt5LogX11DisplayIfDebug;
begin
  if GQt5ChromeX11Warned then Exit;
  if GetEnvironmentVariable('LAZY_DEBUG_CHROME') = '' then Exit;
  GQt5ChromeX11Warned := True;
  if QX11Info_display() = nil then
    Qt5ChromeDebug('QX11 display missing; check QT_QPA_PLATFORM=xcb');
end;

function TryQt5BeginMove(AForm: TCustomForm; AButton: TMouseButton;
  const AScreenPos: TPoint): Boolean;
begin
  // QWindow::startSystemMove is not in LCL qt5 bindings; manual drag uses LCL SetBounds.
  Result := False;
  if AForm = nil then Exit;
  if AButton <> mbLeft then Exit;
end;

function Qt5FormWidget(AForm: TCustomForm): TQtWidget;
begin
  Result := nil;
  if AForm = nil then Exit;
  if not AForm.HandleAllocated then Exit;
  Result := TQtWidget(AForm.Handle);
end;

procedure Qt5EnsureFramelessFlags(AForm: TCustomForm);
var
  W: TQtWidget;
  Wanted, Current: QtWindowFlags;
  WasVisible: Boolean;
begin
  W := Qt5FormWidget(AForm);
  if W = nil then Exit;
  Wanted := QtWindow or QtFramelessWindowHint;
  Current := W.windowFlags;
  if (Current and Wanted) = Wanted then Exit;
  WasVisible := W.getVisible;
  W.setWindowFlags(Wanted);
  if WasVisible then
    W.setVisible(True);
end;

procedure Qt5ReleaseFixedSize(AForm: TCustomForm);
var
  W: TQtWidget;
  MinW, MinH: Integer;
begin
  W := Qt5FormWidget(AForm);
  if W = nil then Exit;
  MinW := AForm.Constraints.MinWidth;
  MinH := AForm.Constraints.MinHeight;
  if MinW < 0 then
    MinW := 0;
  if MinH < 0 then
    MinH := 0;
  W.setMinimumSize(MinW, MinH);
  W.setMaximumSize(Qt5WidgetSizeMax, Qt5WidgetSizeMax);
end;

procedure Qt5SyncLclBoundsFromWidget(AForm: TCustomForm);
var
  W: TQtWidget;
  R: TRect;
begin
  W := Qt5FormWidget(AForm);
  if W = nil then Exit;
  R := W.getFrameGeometry;
  if not Qt5RectUsable(R) then Exit;
  if (AForm.Left <> R.Left) or (AForm.Top <> R.Top) or
     (AForm.Width <> R.Width) or (AForm.Height <> R.Height) then
    AForm.SetBounds(R.Left, R.Top, R.Width, R.Height);
end;

procedure Qt5ChromeDumpState(AForm: TCustomForm; const ATag: string);
var
  W: TQtWidget;
  B, WinR: TRect;
  QtState: QtWindowStates;
  WinROk: Boolean;
  LclState: string;
begin
  if GetEnvironmentVariable('LAZY_DEBUG_CHROME') = '' then Exit;
  if AForm = nil then Exit;
  B := AForm.BoundsRect;
  case AForm.WindowState of
    wsMinimized: LclState := 'wsMinimized';
    wsMaximized: LclState := 'wsMaximized';
    wsFullScreen: LclState := 'wsFullScreen';
  else
    LclState := 'wsNormal';
  end;
  W := Qt5FormWidget(AForm);
  FillChar(WinR, SizeOf(WinR), 0);
  WinROk := False;
  if W = nil then begin
    Qt5ChromeDebug(Format('%s: bounds %d,%d %dx%d lcl=%s (no widget)',
      [ATag, B.Left, B.Top, B.Width, B.Height, LclState]));
    Exit;
  end;
  QtState := W.getWindowState;
  Qt5ChromeDebug(Format(
    '%s: bounds %d,%d %dx%d lcl=%s qtMax=%s qtMin=%s qtState=$%x',
    [ATag, B.Left, B.Top, B.Width, B.Height, LclState,
     BoolToStr(W.isMaximized, True), BoolToStr(W.isMinimized, True),
     Integer(QtState)]));
  {$IFDEF UNIX}
  WinROk := Qt5X11WindowBoundsOnRoot(W.Widget, WinR);
  {$ENDIF}
  if WinROk then
    Qt5ChromeDebug(Format('%s: winR %d,%d %dx%d',
      [ATag, WinR.Left, WinR.Top, WinR.Width, WinR.Height]));
end;

procedure Qt5ApplyWidgetBounds(AForm: TCustomForm; const R: TRect);
var
  W: TQtWidget;
begin
  if (R.Width < 1) or (R.Height < 1) then Exit;
  W := Qt5FormWidget(AForm);
  if W = nil then Exit;
  W.BeginUpdate;
  try
    W.move(R.Left, R.Top);
    W.resize(R.Width, R.Height);
  finally
    W.EndUpdate;
  end;
  AForm.SetBounds(R.Left, R.Top, R.Width, R.Height);
end;

function Qt5FormIsMaximized(AForm: TCustomForm): Boolean;
var
  W: TQtWidget;
begin
  W := Qt5FormWidget(AForm);
  if W <> nil then
    Exit(W.isMaximized);
  Result := AForm.WindowState = wsMaximized;
end;

function Qt5FormIsMinimized(AForm: TCustomForm): Boolean;
var
  W: TQtWidget;
begin
  W := Qt5FormWidget(AForm);
  if W = nil then Exit(False);
  Result := W.isMinimized;
end;

procedure Qt5SetFormMaximized(AForm: TCustomForm; AMaximized: Boolean);
var
  W: TQtWidget;
begin
  W := Qt5FormWidget(AForm);
  if W = nil then Exit;
  Qt5ReleaseFixedSize(AForm);
  if AMaximized then
    W.ShowMaximized
  else
    W.ShowNormal;
  if AMaximized then
    Qt5ChromeDumpState(AForm, 'SetFormMaximized')
  else
    Qt5ChromeDumpState(AForm, 'SetFormRestore');
end;

procedure Qt5SetFormMinimized(AForm: TCustomForm);
var
  W: TQtWidget;
begin
  W := Qt5FormWidget(AForm);
  if W = nil then Exit;
  Qt5EnsureFramelessFlags(AForm);
  W.ShowMinimized;
end;
{$ENDIF}

class procedure TLcaFormChrome.DebugDumpQt5ChromeState(AForm: TCustomForm;
  const ATag: string);
begin
  {$IFDEF LCLQt5}
  Qt5ChromeDumpState(AForm, ATag);
  {$ENDIF}
end;

procedure AlignLclWindowStateMinimized(AForm: TCustomForm);
begin
  if AForm = nil then Exit;
  {$IFDEF LCLQt5}
  if AForm.HandleAllocated and Qt5FormIsMinimized(AForm) then begin
    if AForm.WindowState <> wsMinimized then
      AForm.WindowState := wsMinimized;
    Exit;
  end;
  {$ENDIF}
  if AForm.WindowState <> wsMinimized then
    AForm.WindowState := wsMinimized;
end;

procedure AlignLclWindowState(AForm: TCustomForm; AMaximized: Boolean);
var
  Target: TWindowState;
begin
  if AForm = nil then Exit;
  {$IFDEF LCLQt5}
  if AForm.HandleAllocated then
    AMaximized := Qt5FormIsMaximized(AForm);
  {$ENDIF}
  if AMaximized then
    Target := wsMaximized
  else
    Target := wsNormal;
  if AForm.WindowState <> Target then
    AForm.WindowState := Target;
end;

procedure TryStartEdgeResize(AForm: TCustomForm; const AScreenPos: TPoint);
var
  ClientP: TPoint;
  Hit: Integer;
begin
  if AForm = nil then Exit;
  ClientP := AForm.ScreenToClient(AScreenPos);
  Hit := EdgeHitTestOnForm(AForm, ClientP);
  if Hit = HTCLIENT then Exit;
  {$IFDEF WINDOWS}
  ReleaseCapture;
  SendMessage(AForm.Handle, WM_NCLBUTTONDOWN, Hit, MakeLParam(AScreenPos.X, AScreenPos.Y));
  {$ELSE}
  {$IFDEF LCLGtk3}
  if TryGtk3BeginResize(AForm, Hit, AScreenPos) then Exit;
  {$ENDIF}
  StartManualResize(AForm, Hit, AScreenPos);
  {$ENDIF}
end;

procedure TFormChromeInputHelper.UserInputBefore(Sender: TObject; Msg: Cardinal);
var
  I: Integer;
  F: TCustomForm;
  P, ClientP: TPoint;
  Hit: Integer;
begin
  if (GDragForm <> nil) or (GResizeForm <> nil) then begin
    case Msg of
      LM_MOUSEMOVE:
        begin
          if not ManualDragResizeActive then begin
            StopDrag;
            StopResize;
            Exit;
          end;
          if GDragForm <> nil then
            UpdateDragPosition
          else if GResizeForm <> nil then
            UpdateResizeBounds;
        end;
      LM_LBUTTONUP:
        begin
          GManualLeftDown := False;
          StopDrag;
          StopResize;
        end;
    end;
    Exit;
  end;

  if Msg = LM_LBUTTONDOWN then begin
    P := Mouse.CursorPos;
    for I := 0 to High(GFramelessForms) do begin
      F := GFramelessForms[I];
      if not F.Visible then Continue;
      if not PtInRect(F.BoundsRect, P) then Continue;
      ClientP := F.ScreenToClient(P);
      Hit := EdgeHitTestOnForm(F, ClientP);
      if Hit <> HTCLIENT then begin
        if LcaControlIsThemedWindowButton(ClientControlOnForm(F, ClientP)) then
          Continue;
        TryStartEdgeResize(F, P);
        Exit;
      end;
    end;
  end;
end;

procedure TFormChromeInputHelper.UserInputAfter(Sender: TObject; Msg: Cardinal);
begin
  if Msg <> LM_MOUSEMOVE then Exit;
  if Length(GFramelessForms) = 0 then Exit;
  if GResizeForm <> nil then begin
    ApplyCursorForHit(GResizeHit);
    Exit;
  end;
  if GDragForm <> nil then Exit;
  UpdateFramelessEdgeCursor;
end;

constructor TLcaFormChrome.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBorderlessApplied := False;
  FCocoaPlatformChromeApplied := False;
end;

destructor TLcaFormChrome.Destroy;
begin
  if Assigned(FForm) then begin
    UnregisterFramelessForm(FForm);
    if Assigned(FOldWindowProc) then
      FForm.WindowProc := FOldWindowProc;
  end;
  inherited Destroy;
end;

procedure TLcaFormChrome.Attach(AForm: TCustomForm);
begin
  if FForm = AForm then Exit;
  if Assigned(FForm) then begin
    UnregisterFramelessForm(FForm);
    if Assigned(FOldWindowProc) then
      FForm.WindowProc := FOldWindowProc;
  end;
  FForm := AForm;
  if FForm = nil then Exit;
  FOldWindowProc := FForm.WindowProc;
  FForm.WindowProc := @WndProc;
  ApplyFrameless;
  RegisterFramelessForm(FForm);
  EnsureFormChromeInputHook;
  EnsurePlatformChrome;
end;

procedure TLcaFormChrome.EnsurePlatformChrome;
begin
  if FForm = nil then Exit;
  {$IFDEF LCLQt5}
  if not FForm.HandleAllocated then
    FForm.HandleNeeded;
  Qt5EnsureFramelessFlags(FForm);
  {$IFDEF UNIX}
  Qt5LogX11DisplayIfDebug;
  {$ENDIF}
  {$ENDIF}
  {$IFDEF LCLcocoa}
  if not FForm.HandleAllocated then
    FForm.HandleNeeded;
  if ApplyCocoaFramelessChrome(FForm) then
    FCocoaPlatformChromeApplied := True;
  {$ENDIF}
end;

procedure TLcaFormChrome.ApplyFrameless;
begin
  if FForm = nil then Exit;
  FForm.BorderStyle := bsNone;
  FForm.BorderIcons := [];
  FBorderlessApplied := True;
end;

class procedure TLcaFormChrome.BeginMove(AForm: TCustomForm; AButton: TMouseButton;
  const AScreenPos: TPoint);
begin
  if AForm = nil then Exit;
  if AButton <> mbLeft then Exit;
  if not AForm.HandleAllocated then
    AForm.HandleNeeded;
  {$IFDEF WINDOWS}
  ReleaseCapture;
  SendMessage(AForm.Handle, WM_SYSCOMMAND, SC_MOVE or $0002, 0);
  {$ELSE}
  {$IFDEF LCLGtk3}
  if TryGtk3BeginMove(AForm, AButton, AScreenPos) then Exit;
  {$ENDIF}
  {$IFDEF LCLcocoa}
  if TryCocoaBeginMove(AForm) then Exit;
  {$ENDIF}
  {$IFDEF LCLQt5}
  if TryQt5BeginMove(AForm, AButton, AScreenPos) then Exit;
  {$ENDIF}
  StartManualDrag(AForm, AScreenPos);
  {$ENDIF}
end;

class function TLcaFormChrome.FormIsMaximized(AForm: TCustomForm): Boolean;
begin
  Result := False;
  if AForm = nil then Exit;
  {$IFDEF LCLGtk2}
  if AForm.HandleAllocated then
    Exit(Gtk2FormIsMaximized(AForm));
  {$ENDIF}
  {$IFDEF LCLGtk3}
  if AForm.HandleAllocated then
    Exit(Gtk3FormIsMaximized(AForm));
  {$ENDIF}
  {$IFDEF LCLQt5}
  if AForm.HandleAllocated then
    Exit(Qt5FormIsMaximized(AForm));
  {$ENDIF}
  {$IFDEF LCLcocoa}
  if AForm.HandleAllocated then
    Exit(CocoaFormWindow(AForm).isZoomed);
  {$ENDIF}
  Result := AForm.WindowState = wsMaximized;
end;

class procedure TLcaFormChrome.SetFormMaximized(AForm: TCustomForm; AMaximized: Boolean);
begin
  if AForm = nil then Exit;
  if not AForm.HandleAllocated then
    AForm.HandleNeeded;
  {$IFDEF WINDOWS}
  ReleaseCapture;
  if AMaximized then
    SendMessage(AForm.Handle, WM_SYSCOMMAND, SC_MAXIMIZE, 0)
  else
    SendMessage(AForm.Handle, WM_SYSCOMMAND, SC_RESTORE, 0);
  Exit;
  {$ENDIF}
  {$IFDEF LCLGtk3}
  if TryGtk3SetMaximized(AForm, AMaximized) then begin
    Application.ProcessMessages;
    AlignLclWindowState(AForm, AMaximized);
    Exit;
  end;
  {$ENDIF}
  {$IFDEF LCLGtk2}
  if AMaximized then
    ShowWindow(AForm.Handle, SW_SHOWMAXIMIZED)
  else
    ShowWindow(AForm.Handle, SW_SHOWNORMAL);
  Application.ProcessMessages;
  AlignLclWindowState(AForm, AMaximized);
  Exit;
  {$ENDIF}
  {$IFDEF LCLQt5}
  Qt5SetFormMaximized(AForm, AMaximized);
  Application.ProcessMessages;
  AlignLclWindowState(AForm, AMaximized);
  Exit;
  {$ENDIF}
  {$IFDEF LCLcocoa}
  if TryCocoaSetMaximized(AForm, AMaximized) then begin
    Application.ProcessMessages;
    AlignLclWindowState(AForm, AMaximized);
    Exit;
  end;
  {$ENDIF}
  if AMaximized then
    AForm.WindowState := wsMaximized
  else
    AForm.WindowState := wsNormal;
end;

class procedure TLcaFormChrome.ToggleFormMaximize(AForm: TCustomForm);
begin
  SetFormMaximized(AForm, not FormIsMaximized(AForm));
end;

class procedure TLcaFormChrome.SetFormMinimized(AForm: TCustomForm);
begin
  if AForm = nil then Exit;
  if not AForm.HandleAllocated then
    AForm.HandleNeeded;
  {$IFDEF WINDOWS}
  ReleaseCapture;
  SendMessage(AForm.Handle, WM_SYSCOMMAND, SC_MINIMIZE, 0);
  Exit;
  {$ENDIF}
  {$IFDEF LCLGtk3}
  ShowWindow(AForm.Handle, SW_SHOWMINIMIZED);
  Application.ProcessMessages;
  AlignLclWindowStateMinimized(AForm);
  Exit;
  {$ENDIF}
  {$IFDEF LCLGtk2}
  ShowWindow(AForm.Handle, SW_SHOWMINIMIZED);
  Application.ProcessMessages;
  AlignLclWindowStateMinimized(AForm);
  Exit;
  {$ENDIF}
  {$IFDEF LCLQt5}
  Qt5SetFormMinimized(AForm);
  Application.ProcessMessages;
  AlignLclWindowStateMinimized(AForm);
  Exit;
  {$ENDIF}
  AForm.WindowState := wsMinimized;
end;

class procedure TLcaFormChrome.EnsureWidgetGeometry(AForm: TCustomForm);
var
  R: TRect;
begin
  if AForm = nil then Exit;
  if not AForm.HandleAllocated then Exit;
  {$IFDEF LCLQt5}
  if Qt5FormIsMaximized(AForm) or Qt5FormIsMinimized(AForm) then Exit;
  if AForm.WindowState in [wsMaximized, wsMinimized] then Exit;
  Qt5EnsureFramelessFlags(AForm);
  R := Bounds(AForm.Left, AForm.Top, AForm.Width, AForm.Height);
  Qt5ApplyWidgetBounds(AForm, R);
  Application.ProcessMessages;
  Exit;
  {$ENDIF}
  if AForm.WindowState <> wsNormal then Exit;
  AForm.SetBounds(AForm.Left, AForm.Top, AForm.Width, AForm.Height);
end;

function TLcaFormChrome.EdgeHitTestClient(const P: TPoint): PtrInt;
begin
  Result := EdgeHitTestOnForm(FForm, P);
end;

procedure TLcaFormChrome.WndProc(var Message: TLMessage);
var
  P: TPoint;
  Hit: PtrInt;
begin
  if FBorderlessApplied and Assigned(FForm) then begin
    {$IFDEF LCLcocoa}
    if (Message.Msg = CM_SHOWINGCHANGED) and FForm.Showing then
      EnsurePlatformChrome;
    {$ENDIF}
    {$IFDEF WINDOWS}
    case Message.Msg of
      WM_NCHITTEST:
        begin
          P.X := LongInt(SmallInt(LoWord(LongInt(Message.LParam))));
          P.Y := LongInt(SmallInt(HiWord(LongInt(Message.LParam))));
          P := FForm.ScreenToClient(P);
          if (P.X >= 0) and (P.Y >= 0) and (P.X < FForm.ClientWidth) and
            (P.Y < FForm.ClientHeight) then
          begin
            Hit := EdgeHitTestClient(P);
            if Hit <> HTCLIENT then begin
              Message.Result := Hit;
              Exit;
            end;
          end;
        end;
    end;
    {$ENDIF}
  end;
  FOldWindowProc(Message);
  {$IFDEF LCLQt5}
  if FBorderlessApplied and Assigned(FForm) and (Message.Msg = LM_SIZE) then
    Qt5ReleaseFixedSize(FForm);
  {$ENDIF}
end;

function AttachLcaFormChrome(AForm: TCustomForm): TLcaFormChrome;
var
  Chrome: TLcaFormChrome;
begin
  Chrome := TLcaFormChrome.Create(AForm);
  Chrome.Attach(AForm);
  Result := Chrome;
end;

end.
