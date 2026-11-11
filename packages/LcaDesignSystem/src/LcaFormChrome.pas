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
  end;

function AttachLcaFormChrome(AForm: TCustomForm): TLcaFormChrome;

implementation

uses
  Math
  {$IFDEF WINDOWS}, Windows{$ENDIF}
  {$IFDEF LCLGtk3}, LazGtk3, LazGdk3, LazGObject2{$ENDIF}
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
begin
  GDragForm := nil;
  if GResizeForm = nil then
    GManualLeftDown := False;
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
begin
  StopResize;
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
{$ELSE}
function ApplyCocoaFramelessChrome(AForm: TCustomForm): Boolean;
begin
  Result := False;
end;

function TryCocoaBeginMove(AForm: TCustomForm): Boolean;
begin
  Result := False;
end;
{$ENDIF}

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
  StartManualDrag(AForm, AScreenPos);
  {$ENDIF}
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
