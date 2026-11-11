unit LcaPaintNavList;

{$mode objfpc}{$H+}

{ TLcaPaintNavList — painted navigation list with TLcaScrollHost (delivery 011).
  Stream Align/Anchors on the outer control; inner scroll host fills the client via anchors.
  TListBox-compatible subset: Items, ItemIndex, OnClick, OnKeyDown. }

interface

uses
  Classes, Controls, Graphics, Menus, LcaThemedControl, LcaTheme, LcaScrollHost;

type
  TLcaPaintNavList = class;

  TLcaPaintNavListContent = class(TCustomControl)
  private
    FList: TLcaPaintNavList;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent; AList: TLcaPaintNavList); reintroduce;
  end;

  TLcaPaintNavList = class(TLcaThemedControl)
  private
    FItems: TStrings;
    FItemIndex: Integer;
    FItemHeight: Integer;
    FScrollHost: TLcaScrollHost;
    FContent: TLcaPaintNavListContent;
    FLayoutGuard: Boolean;
    FOnClick: TNotifyEvent;
    FOnKeyDown: TKeyEvent;
    FUpdateLock: Integer;
    procedure SetItemIndex(AValue: Integer);
    procedure SetItemHeight(AValue: Integer);
    procedure ItemsChanged(Sender: TObject);
    procedure EnsureChrome;
    procedure EnsureScrollHostFillsClient;
    function EffectiveTheme: TThemeKind;
    function ScaledRowStride: Integer;
    function ContentPixelHeight: Integer;
    function ContentScrollY: Integer;
    procedure SyncContentLayout;
    procedure ChangeItemIndex(AValue: Integer; AScrollIntoView: Boolean; AFireClick: Boolean);
    function IndexAtContentY(Y: Integer): Integer;
    procedure ContentMouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    function ForwardWheel(Shift: TShiftState; WheelDelta: Integer): Boolean;
  protected
    procedure DoApplyThemeColors(const P: TThemePalette); override;
    procedure PaintThemedClient(const ARect: TRect; const P: TThemePalette); override;
    procedure Paint; override;
    procedure Loaded; override;
    procedure CreateWnd; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure Resize; override;
    procedure ChangeScale(M, D: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    function CanFocus: Boolean; override;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyTheme(ATheme: TThemeKind); override;
    procedure EnsureItemVisible(AIndex: Integer);
    function RowRect(AIndex: Integer): TRect;
  published
    property Items: TStrings read FItems;
    property ItemIndex: Integer read FItemIndex write SetItemIndex default -1;
    property ItemHeight: Integer read FItemHeight write SetItemHeight;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property OnKeyDown: TKeyEvent read FOnKeyDown write FOnKeyDown;
    property PopupMenu;
    property Align;
    property Anchors;
    property Left;
    property Top;
    property Width;
    property Height;
    property Visible;
    property Enabled;
    property TabOrder;
    property TabStop default True;
    property ThemeKind;
  end;

implementation

uses
  SysUtils, Types, LCLType, Math;

const
  cDesignerPlaceholderRows = 3;

{ TLcaPaintNavListContent }

constructor TLcaPaintNavListContent.Create(AOwner: TComponent; AList: TLcaPaintNavList);
begin
  inherited Create(AOwner);
  FList := AList;
  ControlStyle := ControlStyle + [csOpaque, csAcceptsControls];
  {$IFDEF LCA_SCROLL_HOST_FORCE_DOUBLEBUFFER}
  DoubleBuffered := True;
  {$ELSE}
  {$IFDEF LCLwin32}
  DoubleBuffered := False;
  {$ELSE}
  DoubleBuffered := True;
  {$ENDIF}
  {$ENDIF}
  BorderStyle := bsNone;
  AutoSize := False;
  SetSubComponent(True);
end;

procedure TLcaPaintNavListContent.Paint;
var
  I, Count, RowH, FirstRow, LastRow, ScrollY: Integer;
  R: TRect;
  State: TOwnerDrawState;
  Cap: string;
  EffTheme: TThemeKind;
begin
  if not Assigned(FList) then Exit;
  Canvas.Font.Assign(FList.Font);
  EffTheme := FList.EffectiveTheme;
  RowH := FList.ScaledRowStride;
  if csDesigning in FList.ComponentState then begin
    Count := cDesignerPlaceholderRows;
    for I := 0 to Count - 1 do begin
      R := Rect(0, I * RowH, Width, (I + 1) * RowH);
      State := [];
      if I = 0 then
        Include(State, odSelected);
      Cap := Format('Nav item %d', [I + 1]);
      PaintThemedNavListItem(Canvas, R, Cap, State, EffTheme, FList);
    end;
    Exit;
  end;
  Count := FList.Items.Count;
  if Count <= 0 then Exit;
  ScrollY := FList.ContentScrollY;
  FirstRow := ScrollY div RowH;
  if FirstRow < 0 then FirstRow := 0;
  LastRow := (ScrollY + Height + RowH - 1) div RowH;
  if LastRow >= Count then LastRow := Count - 1;
  for I := FirstRow to LastRow do begin
    if I >= FList.Items.Count then Break;
    R := Rect(0, I * RowH, Width, (I + 1) * RowH);
    State := [];
    if I = FList.ItemIndex then
      Include(State, odSelected);
    Cap := FList.Items[I];
    PaintThemedNavListItem(Canvas, R, Cap, State, EffTheme, FList);
  end;
end;

procedure TLcaPaintNavListContent.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Assigned(FList) then
    FList.ContentMouseDown(Button, Shift, X, Y);
end;

function TLcaPaintNavListContent.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
begin
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if Assigned(FList) then
    Result := FList.ForwardWheel(Shift, WheelDelta) or Result;
end;

{ TLcaPaintNavList }

constructor TLcaPaintNavList.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TStringList.Create;
  TStringList(FItems).OnChange := @ItemsChanged;
  FItemIndex := -1;
  FItemHeight := ThemedNavListItemHeight;
  Font.Name := 'Segoe UI';
  Font.Size := 11;
  TabStop := True;
  Width := 200;
  Height := 240;
end;

destructor TLcaPaintNavList.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

function TLcaPaintNavList.EffectiveTheme: TThemeKind;
begin
  Result := EffectiveControlTheme(Self, ThemeKind);
end;

function TLcaPaintNavList.ScaledRowStride: Integer;
begin
  Result := ScaledLayoutMetric(Self, FItemHeight);
  if Result < 1 then
    Result := 1;
end;

function TLcaPaintNavList.ContentScrollY: Integer;
begin
  Result := 0;
  if Assigned(FScrollHost) then
    Result := FScrollHost.ScrollPosition.Y;
end;

function TLcaPaintNavList.ContentPixelHeight: Integer;
var
  Count: Integer;
begin
  if csDesigning in ComponentState then
    Count := cDesignerPlaceholderRows
  else
    Count := FItems.Count;
  if Count <= 0 then
    Exit(ScaledRowStride);
  Result := Count * ScaledRowStride;
end;

procedure TLcaPaintNavList.SetItemHeight(AValue: Integer);
begin
  if FItemHeight = AValue then Exit;
  FItemHeight := AValue;
  SyncContentLayout;
end;

procedure TLcaPaintNavList.SetItemIndex(AValue: Integer);
begin
  ChangeItemIndex(AValue, True, False);
end;

procedure TLcaPaintNavList.ChangeItemIndex(AValue: Integer; AScrollIntoView: Boolean;
  AFireClick: Boolean);
var
  MaxIdx: Integer;
begin
  MaxIdx := FItems.Count - 1;
  if MaxIdx < 0 then
    AValue := -1
  else if AValue > MaxIdx then
    AValue := MaxIdx;
  if FItemIndex = AValue then Exit;
  FItemIndex := AValue;
  if Assigned(FContent) then
    FContent.Invalidate;
  if AScrollIntoView and (FItemIndex >= 0) then
    EnsureItemVisible(FItemIndex);
  if AFireClick and Assigned(FOnClick) then
    FOnClick(Self);
end;

procedure TLcaPaintNavList.ItemsChanged({%H-}Sender: TObject);
begin
  if FUpdateLock > 0 then Exit;
  if FItemIndex >= FItems.Count then
    FItemIndex := FItems.Count - 1;
  SyncContentLayout;
  if Assigned(FContent) then
    FContent.Invalidate;
end;

procedure TLcaPaintNavList.DoApplyThemeColors(const P: TThemePalette);
begin
  Color := P.Surface;
  Font.Color := P.Text;
  if Assigned(FScrollHost) then
    FScrollHost.ApplyTheme(ThemeKind);
  if Assigned(FContent) then
    FContent.Invalidate;
end;

procedure TLcaPaintNavList.PaintThemedClient(const ARect: TRect; const P: TThemePalette);
begin
  Canvas.Brush.Color := P.Surface;
  Canvas.FillRect(ARect);
end;

procedure TLcaPaintNavList.EnsureScrollHostFillsClient;
begin
  if not Assigned(FScrollHost) then Exit;
  if (ClientWidth <= 0) or (ClientHeight <= 0) then Exit;
  if FScrollHost.Align <> alNone then
    FScrollHost.Align := alNone;
  FScrollHost.Anchors := [akLeft, akTop, akRight, akBottom];
  FScrollHost.SetBounds(0, 0, ClientWidth, ClientHeight);
end;

procedure TLcaPaintNavList.SyncContentLayout;
var
  ViewW, CH: Integer;
  ViewSz: TSize;
begin
  if FLayoutGuard then Exit;
  if csDesigning in ComponentState then begin
    if Assigned(FContent) then
      FContent.Invalidate;
    Exit;
  end;
  if not Assigned(FScrollHost) or not Assigned(FContent) then Exit;
  FLayoutGuard := True;
  try
    EnsureScrollHostFillsClient;
    ViewSz := FScrollHost.LayoutViewportSize;
    ViewW := Max(1, ViewSz.cx);
    CH := Max(ScaledRowStride, ContentPixelHeight);
    if (FContent.Width <> ViewW) or (FContent.Height <> CH) then
      FContent.SetBounds(0, 0, ViewW, CH);
    FScrollHost.UpdateContentExtent(ViewW, CH);
  finally
    FLayoutGuard := False;
  end;
end;

procedure TLcaPaintNavList.EnsureChrome;
begin
  if csDestroying in ComponentState then Exit;
  if not HandleAllocated then Exit;
  if Assigned(FScrollHost) then Exit;
  DisableAutoSizing;
  try
    FScrollHost := TLcaScrollHost.Create(Self);
    FScrollHost.Parent := Self;
    FScrollHost.ThemeKind := ThemeKind;
    FScrollHost.AutoSize := False;
    EnsureScrollHostFillsClient;
    FContent := TLcaPaintNavListContent.Create(Self, Self);
    FContent.Parent := FScrollHost;
    FScrollHost.Content := FContent;
    SyncContentLayout;
  finally
    EnableAutoSizing;
  end;
end;

function TLcaPaintNavList.ForwardWheel(Shift: TShiftState; WheelDelta: Integer): Boolean;
begin
  Result := False;
  if Assigned(FScrollHost) then
    Result := FScrollHost.HandleHostWheel(Shift, WheelDelta);
end;

function TLcaPaintNavList.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
begin
  Result := ForwardWheel(Shift, WheelDelta);
  if not Result then
    Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
end;

procedure TLcaPaintNavList.Paint;
var
  P: TThemePalette;
  R, RowR: TRect;
  I, RowH: Integer;
  State: TOwnerDrawState;
  Cap: string;
  EffTheme: TThemeKind;
begin
  if csDesigning in ComponentState then begin
    P := EffectivePalette;
    R := ClientRect;
    PaintThemedClient(R, P);
    Canvas.Font.Assign(Font);
    EffTheme := EffectiveTheme;
    RowH := ScaledRowStride;
    for I := 0 to cDesignerPlaceholderRows - 1 do begin
      RowR := Rect(4, 4 + I * RowH, ClientWidth - 4, 4 + (I + 1) * RowH);
      State := [];
      if I = 0 then
        Include(State, odSelected);
      Cap := Format('Nav item %d', [I + 1]);
      PaintThemedNavListItem(Canvas, RowR, Cap, State, EffTheme, Self);
    end;
  end else
    inherited Paint;
end;

procedure TLcaPaintNavList.Loaded;
begin
  inherited Loaded;
  if not (csDesigning in ComponentState) then
    EnsureChrome;
end;

procedure TLcaPaintNavList.CreateWnd;
begin
  inherited CreateWnd;
  if not (csDesigning in ComponentState) then
    EnsureChrome;
end;

procedure TLcaPaintNavList.Resize;
begin
  inherited Resize;
  EnsureScrollHostFillsClient;
  SyncContentLayout;
end;

procedure TLcaPaintNavList.ChangeScale(M, D: Integer);
begin
  inherited ChangeScale(M, D);
  SyncContentLayout;
end;

procedure TLcaPaintNavList.ApplyTheme(ATheme: TThemeKind);
begin
  inherited ApplyTheme(ATheme);
  if Assigned(FScrollHost) then
    FScrollHost.ApplyTheme(ATheme);
  if Assigned(FContent) then
    FContent.Invalidate;
end;

function TLcaPaintNavList.CanFocus: Boolean;
begin
  Result := inherited CanFocus and Enabled and Visible;
end;

function TLcaPaintNavList.IndexAtContentY(Y: Integer): Integer;
var
  RowH: Integer;
begin
  RowH := ScaledRowStride;
  if RowH <= 0 then
    Exit(-1);
  Result := Y div RowH;
  if Result >= FItems.Count then
    Result := -1;
  if Result < 0 then
    Result := -1;
end;

procedure TLcaPaintNavList.ContentMouseDown(Button: TMouseButton; {%H-}Shift: TShiftState;
  {%H-}X, Y: Integer);
var
  Idx: Integer;
begin
  if Button = mbRight then begin
    SetFocus;
    Idx := IndexAtContentY(Y);
    if Idx >= 0 then
      ChangeItemIndex(Idx, True, False);
    if Assigned(PopupMenu) then
      PopupMenu.Popup(Mouse.CursorPos.X, Mouse.CursorPos.Y);
    Exit;
  end;
  if Button <> mbLeft then Exit;
  SetFocus;
  Idx := IndexAtContentY(Y);
  if Idx < 0 then Exit;
  ChangeItemIndex(Idx, True, True);
end;

procedure TLcaPaintNavList.EnsureItemVisible(AIndex: Integer);
var
  RowH, TopY, BottomY, ViewH, ScrollY: Integer;
  MaxY: TPoint;
begin
  if not Assigned(FScrollHost) then Exit;
  if AIndex < 0 then Exit;
  RowH := ScaledRowStride;
  TopY := AIndex * RowH;
  BottomY := TopY + RowH;
  ViewH := FScrollHost.LayoutViewportSize.cy;
  ScrollY := FScrollHost.ScrollPosition.Y;
  if TopY < ScrollY then
    FScrollHost.SetScrollPosition(FScrollHost.ScrollPosition.X, TopY)
  else if BottomY > ScrollY + ViewH then
    FScrollHost.SetScrollPosition(FScrollHost.ScrollPosition.X, BottomY - ViewH);
  MaxY := FScrollHost.MaxScrollPosition;
  if FScrollHost.ScrollPosition.Y > MaxY.Y then
    FScrollHost.SetScrollPosition(FScrollHost.ScrollPosition.X, MaxY.Y);
end;

function TLcaPaintNavList.RowRect(AIndex: Integer): TRect;
var
  RowH: Integer;
begin
  RowH := ScaledRowStride;
  Result := Rect(0, AIndex * RowH, Width, (AIndex + 1) * RowH);
end;

procedure TLcaPaintNavList.KeyDown(var Key: Word; Shift: TShiftState);
var
  Idx: Integer;
  Count: Integer;
begin
  inherited KeyDown(Key, Shift);
  Count := FItems.Count;
  case Key of
    VK_UP:
      if Count > 0 then begin
        if FItemIndex <= 0 then
          Idx := 0
        else
          Idx := FItemIndex - 1;
        ChangeItemIndex(Idx, True, False);
        Key := 0;
      end;
    VK_DOWN:
      if Count > 0 then begin
        if FItemIndex < 0 then
          Idx := 0
        else if FItemIndex >= Count - 1 then
          Idx := Count - 1
        else
          Idx := FItemIndex + 1;
        ChangeItemIndex(Idx, True, False);
        Key := 0;
      end;
    VK_HOME:
      if Count > 0 then begin
        ChangeItemIndex(0, True, False);
        Key := 0;
      end;
    VK_END:
      if Count > 0 then begin
        ChangeItemIndex(Count - 1, True, False);
        Key := 0;
      end;
    VK_RETURN:
      if Assigned(FOnClick) then begin
        FOnClick(Self);
        Key := 0;
      end;
  end;
  if (Key <> 0) and Assigned(FOnKeyDown) then
    FOnKeyDown(Self, Key, Shift);
end;

end.
