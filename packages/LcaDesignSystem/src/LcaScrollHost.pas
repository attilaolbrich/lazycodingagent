unit LcaScrollHost;

{$mode objfpc}{$H+}

{ TLcaScrollHost — themed scroll container with painted scrollbars (delivery 005).
  Designer: drop a child on the host (stays a direct child in the object tree). At run time
  the child moves into an internal viewport for clipping/scrolling. Or set Content to pick
  the scrollable control. Use Align = alNone and explicit Height/Width, or ContentHeight.
  When wrapping native scrollables, set ScrollBars := ssNone on the child. }

interface

uses
  Classes, Controls, ExtCtrls, Graphics, Types, LcaThemedControl, LcaTheme;

type
  TLcaScrollAxis = (lsaNone, lsaVertical, lsaHorizontal);

  TLcaScrollHost = class;

  { Thin panel on top of the host chrome so scrollbars paint above the viewport on Qt/GTK. }
  TLcaScrollViewport = class(TPanel)
  private
    FHost: TLcaScrollHost;
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent; AHost: TLcaScrollHost); reintroduce;
  end;

  TLcaScrollGutter = class(TPanel)
  private
    FHost: TLcaScrollHost;
    FAxis: TLcaScrollAxis;
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent; AHost: TLcaScrollHost; AAxis: TLcaScrollAxis); reintroduce;
  end;

  TLcaScrollHost = class(TLcaThemedControl)
  private
    FViewport: TLcaScrollViewport;
    FVGutter: TLcaScrollGutter;
    FHGutter: TLcaScrollGutter;
    FContent: TControl;
    FContentWidth: Integer;
    FContentHeight: Integer;
    FIntrinsicContentW: Integer;
    FIntrinsicContentH: Integer;
    FScrollX: Integer;
    FScrollY: Integer;
    FLayoutGuard: Boolean;
    FDragAxis: TLcaScrollAxis;
    FDragThumbOffset: Integer;
    FShowVBar: Boolean;
    FShowHBar: Boolean;
    FViewportW: Integer;
    FViewportH: Integer;
    FViewportFillColor: TColor;
    FLastLayoutViewportW: Integer;
    FLastLayoutViewportH: Integer;
    FLastLayoutScrollX: Integer;
    FLastLayoutScrollY: Integer;
    FLastLayoutShowVBar: Boolean;
    FLastLayoutShowHBar: Boolean;
    FLastContentLayoutBounds: TRect;
    FWheelAccumX: Integer;
    FWheelAccumY: Integer;
    FWheelFlushQueued: Boolean;
    FViewportOnlyContent: Boolean;
    FOnScrollPositionChange: TNotifyEvent;
    procedure SetViewportOnlyContent(AValue: Boolean);
    procedure NotifyScrollPositionChange;
    procedure ScheduleWheelFlush;
    procedure WheelFlush(Data: PtrInt);
    procedure InvalidateScrollGutters;
    function ClientAreaFillColor(const P: TThemePalette): TColor;
    procedure SetContent(AValue: TControl);
    procedure SetContentWidth(AValue: Integer);
    procedure SetContentHeight(AValue: Integer);
    procedure CaptureIntrinsicExtentFrom(AControl: TControl);
    function MeasureContentExtent(AControl: TControl): TPoint;
    function InDesignMode: Boolean;
    function IsInternalChrome(AControl: TControl): Boolean;
    procedure RefreshContentReference;
    procedure AttachContentToViewport;
    function ScrollbarThickness: Integer;
    function EffectiveContentWidth: Integer;
    function EffectiveContentHeight: Integer;
    procedure ComputeScrollLayout;
    function ShowVerticalBar: Boolean;
    function ShowHorizontalBar: Boolean;
    function MaxScrollX: Integer;
    function MaxScrollY: Integer;
    procedure ClampScroll;
    procedure LayoutFromScroll;
    function VerticalTrackRect: TRect;
    function HorizontalTrackRect: TRect;
    function VerticalThumbRect: TRect;
    function HorizontalThumbRect: TRect;
    function ThumbRectInGutter(AGutter: TLcaScrollGutter): TRect;
    procedure PaintScrollbarTrack(ACanvas: TCanvas; const ARect: TRect; const P: TThemePalette);
    procedure PaintScrollbarThumb(ACanvas: TCanvas; const ARect: TRect; const P: TThemePalette);
    function HostPointFromGutter(AGutter: TControl; X, Y: Integer): TPoint;
    function HitOnVerticalThumb(X, Y: Integer): Boolean;
    function HitOnHorizontalThumb(X, Y: Integer): Boolean;
    procedure ScrollByDelta(ADeltaX, ADeltaY: Integer);
    procedure PageScrollVertical(ADown: Boolean);
    procedure PageScrollHorizontal(ARight: Boolean);
    procedure HandleHostMouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure HandleHostMouseMove(Shift: TShiftState; X, Y: Integer);
    procedure HandleHostMouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    function HostClientWidth: Integer;
    function HostClientHeight: Integer;
  protected
    procedure DoApplyThemeColors(const P: TThemePalette); override;
    procedure PaintThemedClient(const ARect: TRect; const P: TThemePalette); override;
    procedure Loaded; override;
    procedure Resize; override;
    procedure ChangeScale(M, D: Integer); override;
    procedure CreateWnd; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function HandleHostWheel(Shift: TShiftState; WheelDelta: Integer): Boolean;
    procedure UpdateContentExtent(AWidth, AHeight: Integer);
    procedure PaintGutter(AGutter: TLcaScrollGutter; ACanvas: TCanvas);
    function ViewportClientSize: TSize;
    function LayoutViewportSize: TSize;
    function ScrollPosition: TPoint;
    function MaxScrollPosition: TPoint;
    procedure SetScrollPosition(AX, AY: Integer);
    procedure ScrollContentToEnd;
    function ContentScrolledToEnd: Boolean;
    function SyncedContentExtent: TSize;
    procedure SetViewportFillColor(AColor: TColor);
    function ViewportFillColor: TColor;
  published
    property ViewportOnlyContent: Boolean read FViewportOnlyContent
      write SetViewportOnlyContent default False;
    property OnScrollPositionChange: TNotifyEvent read FOnScrollPositionChange
      write FOnScrollPositionChange;
    property Content: TControl read FContent write SetContent;
    property ContentWidth: Integer read FContentWidth write SetContentWidth default 0;
    property ContentHeight: Integer read FContentHeight write SetContentHeight default 0;
    property Align;
    property Anchors;
    property Left;
    property Top;
    property Width;
    property Height;
    property Visible;
    property TabOrder;
    property ThemeKind;
  end;

implementation

uses
  SysUtils, Math, LCLType, Forms, LcaUiPaintProfile, LcaUiScrollBuffer, LcaPaintPrimitives;

const
  LCA_SCROLL_HOST_MAX_CONTROL_SPAN = 32767;

function ClampScrollHostControlSpan(AValue: Integer): Integer;
begin
  if AValue <= 0 then
    Result := AValue
  else if AValue > LCA_SCROLL_HOST_MAX_CONTROL_SPAN then
    Result := LCA_SCROLL_HOST_MAX_CONTROL_SPAN
  else
    Result := AValue;
end;

{ TLcaScrollViewport }

constructor TLcaScrollViewport.Create(AOwner: TComponent; AHost: TLcaScrollHost);
begin
  inherited Create(AOwner);
  FHost := AHost;
  BevelOuter := bvNone;
  Caption := '';
  ControlStyle := ControlStyle + [csAcceptsControls, csCaptureMouse, csClickEvents];
  Parent := AHost;
  Align := alNone;
  Anchors := [akLeft, akTop];
  Visible := False;
  DoubleBuffered := True;
  ControlStyle := ControlStyle + [csOpaque];
  SetSubComponent(True);
end;

function TLcaScrollViewport.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
begin
  if Assigned(FHost) then
    Exit(FHost.HandleHostWheel(Shift, WheelDelta));
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
end;

{ TLcaScrollGutter }

constructor TLcaScrollGutter.Create(AOwner: TComponent; AHost: TLcaScrollHost;
  AAxis: TLcaScrollAxis);
begin
  inherited Create(AOwner);
  FHost := AHost;
  FAxis := AAxis;
  BevelOuter := bvNone;
  Caption := '';
  Parent := AHost;
  Align := alNone;
  AutoSize := False;
  SetSubComponent(True);
end;

function TLcaScrollGutter.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
begin
  if Assigned(FHost) then
    Exit(FHost.HandleHostWheel(Shift, WheelDelta));
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
end;

procedure TLcaScrollGutter.Paint;
var
  T0, Elapsed: QWord;
begin
  T0 := GetTickCount64;
  if Assigned(FHost) then
    FHost.PaintGutter(Self, Canvas)
  else
    inherited Paint;
  Elapsed := GetTickCount64 - T0;
  LcaUiProfileRecordGutterPaint(Elapsed);
end;

procedure TLcaScrollGutter.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
begin
  inherited MouseDown(Button, Shift, X, Y);
  P := FHost.HostPointFromGutter(Self, X, Y);
  FHost.HandleHostMouseDown(Button, Shift, P.X, P.Y);
end;

procedure TLcaScrollGutter.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
begin
  inherited MouseMove(Shift, X, Y);
  P := FHost.HostPointFromGutter(Self, X, Y);
  FHost.HandleHostMouseMove(Shift, P.X, P.Y);
end;

procedure TLcaScrollGutter.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
begin
  inherited MouseUp(Button, Shift, X, Y);
  P := FHost.HostPointFromGutter(Self, X, Y);
  FHost.HandleHostMouseUp(Button, Shift, P.X, P.Y);
end;

{ TLcaScrollHost }

function TLcaScrollHost.ScrollbarThickness: Integer;
begin
  Result := ScaledThemedScrollbarThickness(Self);
end;

function TLcaScrollHost.HostClientWidth: Integer;
var
  R: TRect;
begin
  R := ClientRect;
  Result := R.Right - R.Left;
  if Result <= 0 then
    Result := Width;
  if Result <= 0 then
    Result := ClientWidth;
end;

function TLcaScrollHost.HostClientHeight: Integer;
var
  R: TRect;
begin
  R := ClientRect;
  Result := R.Bottom - R.Top;
  if Result <= 0 then
    Result := Height;
  if Result <= 0 then
    Result := ClientHeight;
end;

function TLcaScrollHost.MeasureContentExtent(AControl: TControl): TPoint;
var
  I, MaxR, MaxB: Integer;
  W: TWinControl;
begin
  MaxR := AControl.Width;
  MaxB := AControl.Height;
  if AControl is TWinControl then begin
    W := TWinControl(AControl);
    for I := 0 to W.ControlCount - 1 do
      with W.Controls[I] do begin
        MaxR := Max(MaxR, Left + Width);
        MaxB := Max(MaxB, Top + Height);
      end;
  end;
  Result := Point(MaxR, MaxB);
end;

function TLcaScrollHost.EffectiveContentWidth: Integer;
var
  M: TPoint;
  W: Integer;
begin
  if FContentWidth > 0 then
    Exit(FContentWidth);
  W := FIntrinsicContentW;
  if Assigned(FContent) then begin
    M := MeasureContentExtent(FContent);
    W := Max(W, M.X);
    W := Max(W, FContent.Width);
  end;
  Result := W;
end;

function TLcaScrollHost.EffectiveContentHeight: Integer;
var
  M: TPoint;
  H: Integer;
begin
  if FContentHeight > 0 then
    Exit(FContentHeight);
  H := FIntrinsicContentH;
  if Assigned(FContent) then begin
    M := MeasureContentExtent(FContent);
    H := Max(H, M.Y);
    H := Max(H, FContent.Height);
  end;
  Result := H;
end;

procedure TLcaScrollHost.CaptureIntrinsicExtentFrom(AControl: TControl);
var
  M: TPoint;
begin
  if not Assigned(AControl) then Exit;
  M := MeasureContentExtent(AControl);
  if FContentWidth = 0 then
    FIntrinsicContentW := Max(FIntrinsicContentW, M.X);
  if FContentHeight = 0 then
    FIntrinsicContentH := Max(FIntrinsicContentH, M.Y);
end;

function TLcaScrollHost.InDesignMode: Boolean;
begin
  Result := (csDesigning in ComponentState) or LcaInDesignContext(Self);
end;

function TLcaScrollHost.IsInternalChrome(AControl: TControl): Boolean;
begin
  Result := (AControl = FViewport) or (AControl = FVGutter) or (AControl = FHGutter);
end;

procedure TLcaScrollHost.RefreshContentReference;
var
  I: Integer;
  C: TControl;
begin
  if Assigned(FContent) and not IsInternalChrome(FContent) then begin
    CaptureIntrinsicExtentFrom(FContent);
    Exit;
  end;
  FContent := nil;
  for I := 0 to ControlCount - 1 do begin
    C := Controls[I];
    if IsInternalChrome(C) then Continue;
    FContent := C;
    CaptureIntrinsicExtentFrom(FContent);
    Exit;
  end;
  if not Assigned(FViewport) then Exit;
  for I := 0 to FViewport.ControlCount - 1 do begin
    C := FViewport.Controls[I];
    if IsInternalChrome(C) then Continue;
    FContent := C;
    CaptureIntrinsicExtentFrom(FContent);
    Exit;
  end;
end;

procedure TLcaScrollHost.AttachContentToViewport;
begin
  if InDesignMode then Exit;
  RefreshContentReference;
  if not Assigned(FContent) or not Assigned(FViewport) then Exit;
  FViewport.Visible := True;
  if FContent.Parent <> FViewport then begin
    FContent.Parent := FViewport;
    FContent.Align := alNone;
  end;
end;

procedure TLcaScrollHost.ComputeScrollLayout;
var
  BarW, CW, CH: Integer;
begin
  BarW := ScrollbarThickness;
  CW := EffectiveContentWidth;
  CH := EffectiveContentHeight;
  FViewportW := HostClientWidth;
  FViewportH := HostClientHeight;
  FShowVBar := CH > FViewportH;
  if FShowVBar then
    Dec(FViewportW, BarW);
  if FViewportW < 0 then
    FViewportW := 0;
  FShowHBar := CW > FViewportW;
  if FShowHBar then
    Dec(FViewportH, BarW);
  if FViewportH < 0 then
    FViewportH := 0;
end;

function TLcaScrollHost.ShowVerticalBar: Boolean;
begin
  Result := FShowVBar;
end;

function TLcaScrollHost.ShowHorizontalBar: Boolean;
begin
  Result := FShowHBar;
end;

function TLcaScrollHost.MaxScrollX: Integer;
begin
  Result := Max(0, EffectiveContentWidth - FViewportW);
end;

function TLcaScrollHost.MaxScrollY: Integer;
begin
  Result := Max(0, EffectiveContentHeight - FViewportH);
end;

procedure TLcaScrollHost.ClampScroll;
begin
  if FScrollX < 0 then FScrollX := 0;
  if FScrollY < 0 then FScrollY := 0;
  if FScrollX > MaxScrollX then FScrollX := MaxScrollX;
  if FScrollY > MaxScrollY then FScrollY := MaxScrollY;
end;

procedure TLcaScrollHost.SetContent(AValue: TControl);
begin
  if FContent = AValue then Exit;
  CaptureIntrinsicExtentFrom(AValue);
  FContent := AValue;
  if InDesignMode then
    Exit;
  AttachContentToViewport;
  LayoutFromScroll;
end;

procedure TLcaScrollHost.SetContentWidth(AValue: Integer);
begin
  if FContentWidth = AValue then Exit;
  FContentWidth := AValue;
  if InDesignMode then Exit;
  LayoutFromScroll;
end;

procedure TLcaScrollHost.SetContentHeight(AValue: Integer);
begin
  if FContentHeight = AValue then Exit;
  FContentHeight := AValue;
  if InDesignMode then Exit;
  LayoutFromScroll;
end;

procedure TLcaScrollHost.UpdateContentExtent(AWidth, AHeight: Integer);
begin
  FContentWidth := ClampScrollHostControlSpan(AWidth);
  FContentHeight := ClampScrollHostControlSpan(AHeight);
  LayoutFromScroll;
end;

function TLcaScrollHost.ViewportClientSize: TSize;
begin
  if InDesignMode then
    Exit(Size(Max(0, ClientWidth), Max(0, ClientHeight)));
  ComputeScrollLayout;
  Result := Size(FViewportW, FViewportH);
end;

function TLcaScrollHost.LayoutViewportSize: TSize;
var
  BarW, W, H: Integer;
begin
  W := HostClientWidth;
  H := HostClientHeight;
  if W < 0 then W := 0;
  if H < 0 then H := 0;
  if InDesignMode then
    Exit(Size(W, H));
  BarW := ScrollbarThickness;
  if W > BarW then
    Dec(W, BarW)
  else
    W := 0;
  Result := Size(W, H);
end;

function TLcaScrollHost.ScrollPosition: TPoint;
begin
  Result := Point(FScrollX, FScrollY);
end;

function TLcaScrollHost.MaxScrollPosition: TPoint;
begin
  ComputeScrollLayout;
  Result := Point(MaxScrollX, MaxScrollY);
end;

procedure TLcaScrollHost.SetScrollPosition(AX, AY: Integer);
begin
  if InDesignMode then Exit;
  FScrollX := AX;
  FScrollY := AY;
  ClampScroll;
  LayoutFromScroll;
end;

procedure TLcaScrollHost.ScrollContentToEnd;
var
  MaxP: TPoint;
begin
  MaxP := MaxScrollPosition;
  SetScrollPosition(ScrollPosition.X, MaxP.Y);
end;

function TLcaScrollHost.ContentScrolledToEnd: Boolean;
var
  MaxY: Integer;
begin
  MaxY := MaxScrollPosition.Y;
  if MaxY <= 0 then
    Exit(True);
  Result := FScrollY >= MaxY;
end;

function TLcaScrollHost.SyncedContentExtent: TSize;
begin
  Result := Size(FContentWidth, FContentHeight);
end;

procedure TLcaScrollHost.InvalidateScrollGutters;
begin
  if Assigned(FVGutter) and FVGutter.Visible then
    FVGutter.Invalidate;
  if Assigned(FHGutter) and FHGutter.Visible then
    FHGutter.Invalidate;
end;

procedure TLcaScrollHost.LayoutFromScroll;
var
  CW, CH: Integer;
  VTrack, HTrack: TRect;
  ShowV, ShowH: Boolean;
  ContentBounds: TRect;
  NeedHostPaint: Boolean;
  ScrollChanged: Boolean;
  VGutterChanged, HGutterChanged: Boolean;
  PriorContentBounds: TRect;
  ContentSetBounds: Boolean;
  T0, Elapsed: QWord;
begin
  if FLayoutGuard or InDesignMode then Exit;
  FLayoutGuard := True;
  T0 := GetTickCount64;
  ContentSetBounds := False;
  try
    AttachContentToViewport;
    RefreshContentReference;
    ComputeScrollLayout;
    ClampScroll;
    ShowV := ShowVerticalBar;
    ShowH := ShowHorizontalBar;
    ScrollChanged := (FScrollX <> FLastLayoutScrollX) or (FScrollY <> FLastLayoutScrollY);
    NeedHostPaint := (FViewportW <> FLastLayoutViewportW) or (FViewportH <> FLastLayoutViewportH) or
      (ShowV <> FLastLayoutShowVBar) or (ShowH <> FLastLayoutShowHBar);
    if Assigned(FViewport) then begin
      if (FViewport.Width <> FViewportW) or (FViewport.Height <> FViewportH) then
        FViewport.SetBounds(0, 0, FViewportW, FViewportH);
    end;
    CW := ClampScrollHostControlSpan(EffectiveContentWidth);
    CH := ClampScrollHostControlSpan(EffectiveContentHeight);
    PriorContentBounds := FLastContentLayoutBounds;
    if FViewportOnlyContent then
      ContentBounds := Rect(0, 0, FViewportW, FViewportH)
    else
      ContentBounds := Rect(-FScrollX, -FScrollY, -FScrollX + CW, -FScrollY + CH);
    if Assigned(FContent) then begin
      if not EqualRect(ContentBounds, PriorContentBounds) then begin
        if FViewportOnlyContent then
          FContent.SetBounds(0, 0, FViewportW, FViewportH)
        else
          FContent.SetBounds(-FScrollX, -FScrollY, CW, CH);
        ContentSetBounds := True;
      end;
    end;
    FLastContentLayoutBounds := ContentBounds;
    VGutterChanged := False;
    HGutterChanged := False;
    if Assigned(FVGutter) then begin
      if ShowV then begin
        VTrack := VerticalTrackRect;
        FVGutter.Align := alNone;
        if ShowH then
          FVGutter.Anchors := [akTop, akRight]
        else
          FVGutter.Anchors := [akTop, akRight, akBottom];
        if (FVGutter.Left <> VTrack.Left) or (FVGutter.Top <> VTrack.Top) or
           (FVGutter.Width <> VTrack.Width) or (FVGutter.Height <> VTrack.Bottom - VTrack.Top) or
           not FVGutter.Visible then begin
          FVGutter.SetBounds(VTrack.Left, VTrack.Top, VTrack.Width, VTrack.Bottom - VTrack.Top);
          VGutterChanged := True;
        end;
        FVGutter.Visible := True;
        FVGutter.BringToFront;
      end else if FVGutter.Visible then begin
        FVGutter.Visible := False;
        VGutterChanged := True;
      end;
    end;
    if Assigned(FHGutter) then begin
      if ShowH then begin
        HTrack := HorizontalTrackRect;
        if (FHGutter.Left <> HTrack.Left) or (FHGutter.Top <> HTrack.Top) or
           (FHGutter.Width <> HTrack.Width) or (FHGutter.Height <> HTrack.Height) or
           not FHGutter.Visible then begin
          FHGutter.SetBounds(HTrack.Left, HTrack.Top, HTrack.Width, HTrack.Height);
          HGutterChanged := True;
        end;
        FHGutter.Visible := True;
        FHGutter.BringToFront;
      end else if FHGutter.Visible then begin
        FHGutter.Visible := False;
        HGutterChanged := True;
      end;
    end;
    FLastLayoutViewportW := FViewportW;
    FLastLayoutViewportH := FViewportH;
    FLastLayoutScrollX := FScrollX;
    FLastLayoutScrollY := FScrollY;
    FLastLayoutShowVBar := ShowV;
    FLastLayoutShowHBar := ShowH;
    if NeedHostPaint then
      Invalidate;
    if VGutterChanged or HGutterChanged then
      InvalidateScrollGutters
    else if ScrollChanged and (ShowV or ShowH) then
      InvalidateScrollGutters;
    if ScrollChanged then
      NotifyScrollPositionChange;
  finally
    FLayoutGuard := False;
    Elapsed := GetTickCount64 - T0;
    LcaUiProfileRecordLayoutFromScroll(Elapsed, ContentSetBounds);
  end;
end;

function TLcaScrollHost.VerticalTrackRect: TRect;
var
  BarW, TopY, BottomY: Integer;
begin
  BarW := ScrollbarThickness;
  TopY := 0;
  BottomY := HostClientHeight;
  if ShowHorizontalBar then
    Dec(BottomY, BarW);
  Result := Rect(HostClientWidth - BarW, TopY, HostClientWidth, BottomY);
end;

function TLcaScrollHost.HorizontalTrackRect: TRect;
var
  BarW, LeftX, RightX, HostH: Integer;
begin
  BarW := ScrollbarThickness;
  LeftX := 0;
  RightX := HostClientWidth;
  HostH := HostClientHeight;
  if ShowVerticalBar then
    Dec(RightX, BarW);
  Result := Rect(LeftX, HostH - BarW, RightX, HostH);
end;

function TLcaScrollHost.VerticalThumbRect: TRect;
var
  TrackR: TRect;
  ThumbH, ThumbY, MinThumb: Integer;
  MaxS: Integer;
begin
  TrackR := VerticalTrackRect;
  Result := TrackR;
  if not ShowVerticalBar then Exit;
  MaxS := MaxScrollY;
  if MaxS <= 0 then Exit;
  MinThumb := Max(ScrollbarThickness, ScaledLayoutMetric(Self, 20));
  ThumbH := Max(MinThumb, MulDiv(TrackR.Height, FViewportH, EffectiveContentHeight));
  if ThumbH > TrackR.Height then
    ThumbH := TrackR.Height;
  ThumbY := TrackR.Top;
  if TrackR.Height > ThumbH then
    ThumbY := TrackR.Top + MulDiv(TrackR.Height - ThumbH, FScrollY, MaxS);
  Result := Rect(TrackR.Left, ThumbY, TrackR.Right, ThumbY + ThumbH);
end;

function TLcaScrollHost.HorizontalThumbRect: TRect;
var
  TrackR: TRect;
  ThumbW, ThumbX, MinThumb: Integer;
  MaxS: Integer;
begin
  TrackR := HorizontalTrackRect;
  Result := TrackR;
  if not ShowHorizontalBar then Exit;
  MaxS := MaxScrollX;
  if MaxS <= 0 then Exit;
  MinThumb := Max(ScrollbarThickness, ScaledLayoutMetric(Self, 20));
  ThumbW := Max(MinThumb, MulDiv(TrackR.Width, FViewportW, EffectiveContentWidth));
  if ThumbW > TrackR.Width then
    ThumbW := TrackR.Width;
  ThumbX := TrackR.Left;
  if TrackR.Width > ThumbW then
    ThumbX := TrackR.Left + MulDiv(TrackR.Width - ThumbW, FScrollX, MaxS);
  Result := Rect(ThumbX, TrackR.Top, ThumbX + ThumbW, TrackR.Bottom);
end;

function TLcaScrollHost.ThumbRectInGutter(AGutter: TLcaScrollGutter): TRect;
var
  HostThumb, GutterBounds: TRect;
  R: TRect;
begin
  R := Rect(0, 0, 0, 0);
  if not Assigned(AGutter) then Exit(R);
  if AGutter = FVGutter then
    HostThumb := VerticalThumbRect
  else if AGutter = FHGutter then
    HostThumb := HorizontalThumbRect
  else
    Exit(R);
  GutterBounds := AGutter.BoundsRect;
  R := Rect(
    HostThumb.Left - GutterBounds.Left,
    HostThumb.Top - GutterBounds.Top,
    HostThumb.Right - GutterBounds.Left,
    HostThumb.Bottom - GutterBounds.Top);
  if not IntersectRect(Result, R, AGutter.ClientRect) then
    Result := Rect(0, 0, 0, 0);
end;

function TLcaScrollHost.HostPointFromGutter(AGutter: TControl; X, Y: Integer): TPoint;
var
  S: TPoint;
begin
  S := AGutter.ClientToScreen(Point(X, Y));
  Result := ScreenToClient(S);
end;

function TLcaScrollHost.HitOnVerticalThumb(X, Y: Integer): Boolean;
var
  R: TRect;
begin
  if not ShowVerticalBar then Exit(False);
  R := VerticalThumbRect;
  Result := PtInRect(R, Point(X, Y));
end;

function TLcaScrollHost.HitOnHorizontalThumb(X, Y: Integer): Boolean;
var
  R: TRect;
begin
  if not ShowHorizontalBar then Exit(False);
  R := HorizontalThumbRect;
  Result := PtInRect(R, Point(X, Y));
end;

procedure TLcaScrollHost.ScrollByDelta(ADeltaX, ADeltaY: Integer);
begin
  if (ADeltaX = 0) and (ADeltaY = 0) then Exit;
  FScrollX := FScrollX + ADeltaX;
  FScrollY := FScrollY + ADeltaY;
  LayoutFromScroll;
end;

procedure TLcaScrollHost.PageScrollVertical(ADown: Boolean);
var
  Step: Integer;
begin
  Step := Max(1, FViewportH);
  if ADown then
    ScrollByDelta(0, Step)
  else
    ScrollByDelta(0, -Step);
end;

procedure TLcaScrollHost.PageScrollHorizontal(ARight: Boolean);
var
  Step: Integer;
begin
  Step := Max(1, FViewportW);
  if ARight then
    ScrollByDelta(Step, 0)
  else
    ScrollByDelta(-Step, 0);
end;

procedure TLcaScrollHost.SetViewportOnlyContent(AValue: Boolean);
begin
  if FViewportOnlyContent = AValue then Exit;
  FViewportOnlyContent := AValue;
  if InDesignMode then Exit;
  LayoutFromScroll;
end;

procedure TLcaScrollHost.NotifyScrollPositionChange;
begin
  if Assigned(FOnScrollPositionChange) then
    FOnScrollPositionChange(Self);
end;

constructor TLcaScrollHost.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  AutoSize := False;
  FViewportOnlyContent := False;
  ControlStyle := ControlStyle + [csAcceptsControls, csCaptureMouse, csClickEvents,
    csDoubleClicks];
  FContentWidth := 0;
  FContentHeight := 0;
  FScrollX := 0;
  FScrollY := 0;
  FDragAxis := lsaNone;
  FViewportFillColor := clNone;
  FLastLayoutViewportW := -1;
  FLastLayoutViewportH := -1;
  FLastLayoutScrollX := -1;
  FLastLayoutScrollY := -1;
  FLastContentLayoutBounds := Rect(-1, -1, -1, -1);

  FViewport := TLcaScrollViewport.Create(Self, Self);
  ApplyScrollHostDoubleBufferPolicy(Self, FViewport);
  FWheelAccumX := 0;
  FWheelAccumY := 0;
  FWheelFlushQueued := False;

  FVGutter := TLcaScrollGutter.Create(Self, Self, lsaVertical);
  FHGutter := TLcaScrollGutter.Create(Self, Self, lsaHorizontal);
  FVGutter.Visible := False;
  FHGutter.Visible := False;
end;

function TLcaScrollHost.ClientAreaFillColor(const P: TThemePalette): TColor;
begin
  if FViewportFillColor <> clNone then
    Result := FViewportFillColor
  else
    Result := P.CardBg;
end;

function TLcaScrollHost.ViewportFillColor: TColor;
begin
  Result := FViewportFillColor;
end;

procedure TLcaScrollHost.SetViewportFillColor(AColor: TColor);
begin
  if FViewportFillColor = AColor then Exit;
  FViewportFillColor := AColor;
  if not (csLoading in ComponentState) and HandleAllocated then
    ApplyTheme(ThemeKind);
end;

procedure TLcaScrollHost.DoApplyThemeColors(const P: TThemePalette);
var
  Fill: TColor;
begin
  inherited DoApplyThemeColors(P);
  Fill := ClientAreaFillColor(P);
  Color := Fill;
  if Assigned(FViewport) then begin
    FViewport.Color := Fill;
    FViewport.Font.Color := P.Text;
  end;
  if Assigned(FVGutter) then begin
    FVGutter.Color := P.SurfaceAlt;
    FVGutter.Font.Color := P.Text;
  end;
  if Assigned(FHGutter) then begin
    FHGutter.Color := P.SurfaceAlt;
    FHGutter.Font.Color := P.Text;
  end;
end;

procedure TLcaScrollHost.PaintScrollbarTrack(ACanvas: TCanvas; const ARect: TRect;
  const P: TThemePalette);
begin
  PaintThemedScrollbarTrack(ACanvas, ARect, P.SurfaceAlt);
end;

procedure TLcaScrollHost.PaintScrollbarThumb(ACanvas: TCanvas; const ARect: TRect;
  const P: TThemePalette);
var
  ThumbColor: TColor;
begin
  ThumbColor := BlendRgb(P.Border, P.TextMuted, 0.35);
  PaintThemedScrollbarThumb(ACanvas, ARect, ThumbColor, False);
end;

procedure TLcaScrollHost.PaintGutter(AGutter: TLcaScrollGutter; ACanvas: TCanvas);
var
  P: TThemePalette;
  TrackR, ThumbR: TRect;
begin
  ComputeScrollLayout;
  P := EffectivePalette;
  TrackR := AGutter.ClientRect;
  PaintScrollbarTrack(ACanvas, TrackR, P);
  ThumbR := ThumbRectInGutter(AGutter);
  if (ThumbR.Right > ThumbR.Left) and (ThumbR.Bottom > ThumbR.Top) then
    PaintScrollbarThumb(ACanvas, ThumbR, P);
end;

procedure TLcaScrollHost.PaintThemedClient(const ARect: TRect; const P: TThemePalette);
begin
  Canvas.Brush.Color := ClientAreaFillColor(P);
  Canvas.FillRect(ARect);
  if LcaInDesignContext(Self) and (csDesigning in ComponentState) then begin
    Canvas.Font.Color := P.TextMuted;
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(4, 4, ClassName);
  end;
end;

procedure TLcaScrollHost.Loaded;
begin
  inherited Loaded;
  RefreshContentReference;
  if InDesignMode then begin
    if Assigned(FViewport) then
      FViewport.Visible := False;
    if Assigned(FVGutter) then
      FVGutter.Visible := False;
    if Assigned(FHGutter) then
      FHGutter.Visible := False;
    Exit;
  end;
  AttachContentToViewport;
  LayoutFromScroll;
end;

procedure TLcaScrollHost.Resize;
begin
  inherited Resize;
  if FLayoutGuard or InDesignMode then Exit;
  LayoutFromScroll;
end;

procedure TLcaScrollHost.ChangeScale(M, D: Integer);
begin
  inherited ChangeScale(M, D);
  if InDesignMode then Exit;
  LayoutFromScroll;
end;

procedure TLcaScrollHost.CreateWnd;
begin
  inherited CreateWnd;
  if InDesignMode then Exit;
  AttachContentToViewport;
  LayoutFromScroll;
end;

procedure TLcaScrollHost.ScheduleWheelFlush;
begin
  if FWheelFlushQueued then Exit;
  FWheelFlushQueued := True;
  Application.QueueAsyncCall(@WheelFlush, PtrInt(Self));
end;

procedure TLcaScrollHost.WheelFlush(Data: PtrInt);
var
  DX, DY: Integer;
begin
  FWheelFlushQueued := False;
  if PtrInt(Self) <> Data then Exit;
  if csDestroying in ComponentState then Exit;
  DX := FWheelAccumX;
  DY := FWheelAccumY;
  FWheelAccumX := 0;
  FWheelAccumY := 0;
  if (DX = 0) and (DY = 0) then Exit;
  ScrollByDelta(DX, DY);
end;

destructor TLcaScrollHost.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  inherited Destroy;
end;

function TLcaScrollHost.HandleHostWheel(Shift: TShiftState; WheelDelta: Integer): Boolean;
var
  Step: Integer;
  Delta: Integer;
begin
  Step := ScaledLayoutMetric(Self, 24);
  Delta := MulDiv(WheelDelta, Step, 120);
  if ssShift in Shift then
    Inc(FWheelAccumX, -Delta)
  else
    Inc(FWheelAccumY, -Delta);
  ScheduleWheelFlush;
  Result := True;
end;

function TLcaScrollHost.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
begin
  Result := HandleHostWheel(Shift, WheelDelta);
end;

procedure TLcaScrollHost.HandleHostMouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  VThumb, HThumb: TRect;
  TrackMid: Integer;
begin
  if Button <> mbLeft then Exit;
  if HitOnVerticalThumb(X, Y) then begin
    FDragAxis := lsaVertical;
    VThumb := VerticalThumbRect;
    FDragThumbOffset := Y - VThumb.Top;
    MouseCapture := True;
    Exit;
  end;
  if HitOnHorizontalThumb(X, Y) then begin
    FDragAxis := lsaHorizontal;
    HThumb := HorizontalThumbRect;
    FDragThumbOffset := X - HThumb.Left;
    MouseCapture := True;
    Exit;
  end;
  if ShowVerticalBar and PtInRect(VerticalTrackRect, Point(X, Y)) then begin
    VThumb := VerticalThumbRect;
    TrackMid := (VThumb.Top + VThumb.Bottom) div 2;
    if Y < TrackMid then
      PageScrollVertical(False)
    else
      PageScrollVertical(True);
    Exit;
  end;
  if ShowHorizontalBar and PtInRect(HorizontalTrackRect, Point(X, Y)) then begin
    HThumb := HorizontalThumbRect;
    TrackMid := (HThumb.Left + HThumb.Right) div 2;
    if X < TrackMid then
      PageScrollHorizontal(False)
    else
      PageScrollHorizontal(True);
  end;
end;

procedure TLcaScrollHost.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  HandleHostMouseDown(Button, Shift, X, Y);
end;

procedure TLcaScrollHost.HandleHostMouseMove(Shift: TShiftState; X, Y: Integer);
var
  TrackR, ThumbR: TRect;
  MaxS, ThumbSpan, NewPos: Integer;
begin
  if FDragAxis = lsaNone then Exit;
  if not (ssLeft in Shift) then Exit;

  if FDragAxis = lsaVertical then begin
    MaxS := MaxScrollY;
    if MaxS <= 0 then Exit;
    TrackR := VerticalTrackRect;
    ThumbR := VerticalThumbRect;
    ThumbSpan := TrackR.Height - (ThumbR.Bottom - ThumbR.Top);
    if ThumbSpan <= 0 then Exit;
    NewPos := Y - FDragThumbOffset - TrackR.Top;
    if NewPos < 0 then NewPos := 0;
    if NewPos > ThumbSpan then NewPos := ThumbSpan;
    FScrollY := MulDiv(NewPos, MaxS, ThumbSpan);
    LayoutFromScroll;
    Exit;
  end;

  if FDragAxis = lsaHorizontal then begin
    MaxS := MaxScrollX;
    if MaxS <= 0 then Exit;
    TrackR := HorizontalTrackRect;
    ThumbR := HorizontalThumbRect;
    ThumbSpan := TrackR.Width - (ThumbR.Right - ThumbR.Left);
    if ThumbSpan <= 0 then Exit;
    NewPos := X - FDragThumbOffset - TrackR.Left;
    if NewPos < 0 then NewPos := 0;
    if NewPos > ThumbSpan then NewPos := ThumbSpan;
    FScrollX := MulDiv(NewPos, MaxS, ThumbSpan);
    LayoutFromScroll;
  end;
end;

procedure TLcaScrollHost.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  HandleHostMouseMove(Shift, X, Y);
end;

procedure TLcaScrollHost.HandleHostMouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  if Button = mbLeft then begin
    FDragAxis := lsaNone;
    MouseCapture := False;
  end;
end;

procedure TLcaScrollHost.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  HandleHostMouseUp(Button, Shift, X, Y);
end;

end.
