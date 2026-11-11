unit LcaThemedPageTabBar;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ComCtrls, Graphics, LCLType, LcaThemedControl, LcaTheme;

type
  TLcaTabCloseEvent = procedure(Sender: TObject; TabSheet: TTabSheet;
    var AllowClose: Boolean) of object;
  TLcaAddTabEvent = procedure(Sender: TObject) of object;
  TLcaManualTabSelectEvent = procedure(Sender: TObject; ATabIndex: Integer) of object;
  TLcaManualTabCloseEvent = procedure(Sender: TObject; ATabIndex: Integer;
    var AllowClose: Boolean) of object;

  { Themed tab strip for a PageControl with ShowTabs = False, or manual captions when
    PageControl is nil. }
  TLcaThemedPageTabBar = class(TLcaThemedControl)
  private
    FPageControl: TPageControl;
    FShowAddTab: Boolean;
    FAddTabCaption: string;
    FHoverTabIndex: Integer;
    FHoverCloseIndex: Integer;
    FOnTabClose: TLcaTabCloseEvent;
    FOnAddTab: TLcaAddTabEvent;
    FOnManualTabSelect: TLcaManualTabSelectEvent;
    FOnManualTabClose: TLcaManualTabCloseEvent;
    FTabRects: array of TRect;
    FAddTabRect: TRect;
    FManualCaptions: TStringList;
    FManualAllowClose: array of Boolean;
    FManualSelectedIndex: Integer;
    function IsManualMode: Boolean;
    function VisibleTabCount: Integer;
    function TabCaptionAt(AVisibleIndex: Integer): string;
    function TabAllowCloseAt(AVisibleIndex: Integer): Boolean;
    function TabIsSelectedAt(AVisibleIndex: Integer): Boolean;
    function VisibleTabSheetAt(AVisibleIndex: Integer): TTabSheet;
    function IndexOfTabSheet(ASheet: TTabSheet): Integer;
    procedure LayoutTabs;
    procedure LayoutAddTabRect(const AMeasureCanvas: TControlCanvas; var AX: Integer);
    procedure PaintTabStrip;
    procedure SetPageControl(AControl: TPageControl);
    function UsesParentForHeight: Boolean;
    class function FindMetaIndex(ASheet: TTabSheet): Integer; static;
    class procedure EnsureMeta(ASheet: TTabSheet); static;
  protected
    procedure DoApplyThemeColors(const P: TThemePalette); override;
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure ChangeScale(M, D: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RefreshFromPageControl;
    procedure SetManualTabs(const ACaptions: array of string;
      const AAllowClose: array of Boolean; ASelectedIndex: Integer);
    class procedure SetTabAllowsClose(ASheet: TTabSheet; AValue: Boolean); static;
    class procedure SetTabHidden(ASheet: TTabSheet; AValue: Boolean); static;
    class function TabIsHidden(ASheet: TTabSheet): Boolean; static;
    class function TabAllowsClose(ASheet: TTabSheet): Boolean; static;
  published
    property PageControl: TPageControl read FPageControl write SetPageControl;
    property ShowAddTab: Boolean read FShowAddTab write FShowAddTab;
    property AddTabCaption: string read FAddTabCaption write FAddTabCaption;
    property OnTabClose: TLcaTabCloseEvent read FOnTabClose write FOnTabClose;
    property OnAddTab: TLcaAddTabEvent read FOnAddTab write FOnAddTab;
    property OnManualTabSelect: TLcaManualTabSelectEvent read FOnManualTabSelect
      write FOnManualTabSelect;
    property OnManualTabClose: TLcaManualTabCloseEvent read FOnManualTabClose
      write FOnManualTabClose;
    property Align;
    property Anchors;
    property Left;
    property Top;
    property Width;
    property Height;
    property Visible;
    property Enabled;
    property TabOrder;
    property Font;
    property Hint;
    property ShowHint;
    property ThemeKind;
  end;

implementation

type
  TThemedTabMeta = record
    Sheet: TTabSheet;
    AllowClose: Boolean;
    Hidden: Boolean;
  end;

var
  GThemedTabMeta: array of TThemedTabMeta;

class function TLcaThemedPageTabBar.FindMetaIndex(ASheet: TTabSheet): Integer;
var
  I: Integer;
begin
  Result := -1;
  if not Assigned(ASheet) then Exit;
  for I := 0 to High(GThemedTabMeta) do
    if GThemedTabMeta[I].Sheet = ASheet then
      Exit(I);
end;

class procedure TLcaThemedPageTabBar.EnsureMeta(ASheet: TTabSheet);
var
  N: Integer;
begin
  if not Assigned(ASheet) then Exit;
  if FindMetaIndex(ASheet) >= 0 then Exit;
  N := Length(GThemedTabMeta);
  SetLength(GThemedTabMeta, N + 1);
  GThemedTabMeta[N].Sheet := ASheet;
  GThemedTabMeta[N].AllowClose := False;
  GThemedTabMeta[N].Hidden := False;
end;

class procedure TLcaThemedPageTabBar.SetTabAllowsClose(ASheet: TTabSheet; AValue: Boolean);
var
  I: Integer;
begin
  EnsureMeta(ASheet);
  I := FindMetaIndex(ASheet);
  if I >= 0 then
    GThemedTabMeta[I].AllowClose := AValue;
end;

class procedure TLcaThemedPageTabBar.SetTabHidden(ASheet: TTabSheet; AValue: Boolean);
var
  I: Integer;
begin
  EnsureMeta(ASheet);
  I := FindMetaIndex(ASheet);
  if I >= 0 then
    GThemedTabMeta[I].Hidden := AValue;
  if Assigned(ASheet) then
    ASheet.TabVisible := not AValue;
end;

class function TLcaThemedPageTabBar.TabIsHidden(ASheet: TTabSheet): Boolean;
var
  I: Integer;
begin
  I := FindMetaIndex(ASheet);
  if I < 0 then
    Result := False
  else
    Result := GThemedTabMeta[I].Hidden;
end;

class function TLcaThemedPageTabBar.TabAllowsClose(ASheet: TTabSheet): Boolean;
var
  I: Integer;
begin
  I := FindMetaIndex(ASheet);
  if I < 0 then
    Result := False
  else
    Result := GThemedTabMeta[I].AllowClose;
end;

function TLcaThemedPageTabBar.UsesParentForHeight: Boolean;
begin
  Result := Align in [alClient, alTop, alBottom];
end;

constructor TLcaThemedPageTabBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FHoverTabIndex := -1;
  FHoverCloseIndex := -1;
  FShowAddTab := False;
  FAddTabCaption := '+';
  FManualSelectedIndex := -1;
  FManualCaptions := TStringList.Create;
  if not UsesParentForHeight then
    Height := ScaledThemedTabBarHeight(Self);
end;

destructor TLcaThemedPageTabBar.Destroy;
begin
  FManualCaptions.Free;
  inherited Destroy;
end;

function TLcaThemedPageTabBar.IsManualMode: Boolean;
begin
  Result := not Assigned(FPageControl);
end;

procedure TLcaThemedPageTabBar.SetManualTabs(const ACaptions: array of string;
  const AAllowClose: array of Boolean; ASelectedIndex: Integer);
var
  I: Integer;
begin
  FManualCaptions.Clear;
  SetLength(FManualAllowClose, Length(ACaptions));
  for I := 0 to High(ACaptions) do begin
    FManualCaptions.Add(ACaptions[I]);
    if I <= High(AAllowClose) then
      FManualAllowClose[I] := AAllowClose[I]
    else
      FManualAllowClose[I] := False;
  end;
  FManualSelectedIndex := ASelectedIndex;
  LayoutTabs;
  Invalidate;
end;

procedure TLcaThemedPageTabBar.SetPageControl(AControl: TPageControl);
begin
  if FPageControl = AControl then Exit;
  FPageControl := AControl;
  if Assigned(FPageControl) then begin
    FManualCaptions.Clear;
    SetLength(FManualAllowClose, 0);
    FManualSelectedIndex := -1;
    EnforcePageControlHiddenTabs(FPageControl);
  end;
  RefreshFromPageControl;
end;

procedure TLcaThemedPageTabBar.DoApplyThemeColors(const {%H-}P: TThemePalette);
begin
  Color := P.HeaderBg;
  Font.Color := P.Text;
end;

function TLcaThemedPageTabBar.VisibleTabCount: Integer;
var
  I: Integer;
  Sheet: TTabSheet;
begin
  if IsManualMode then begin
    Result := FManualCaptions.Count;
    Exit;
  end;
  Result := 0;
  if not Assigned(FPageControl) then Exit;
  for I := 0 to FPageControl.PageCount - 1 do begin
    Sheet := FPageControl.Pages[I];
    if not TabIsHidden(Sheet) then
      Inc(Result);
  end;
end;

function TLcaThemedPageTabBar.TabCaptionAt(AVisibleIndex: Integer): string;
var
  Sheet: TTabSheet;
begin
  if IsManualMode then begin
    if (AVisibleIndex >= 0) and (AVisibleIndex < FManualCaptions.Count) then
      Result := FManualCaptions[AVisibleIndex]
    else
      Result := '';
    Exit;
  end;
  Sheet := VisibleTabSheetAt(AVisibleIndex);
  if Assigned(Sheet) then
    Result := Sheet.Caption
  else
    Result := '';
end;

function TLcaThemedPageTabBar.TabAllowCloseAt(AVisibleIndex: Integer): Boolean;
var
  Sheet: TTabSheet;
begin
  if IsManualMode then begin
    if (AVisibleIndex >= 0) and (AVisibleIndex <= High(FManualAllowClose)) then
      Result := FManualAllowClose[AVisibleIndex]
    else
      Result := False;
    Exit;
  end;
  Sheet := VisibleTabSheetAt(AVisibleIndex);
  Result := TabAllowsClose(Sheet);
end;

function TLcaThemedPageTabBar.TabIsSelectedAt(AVisibleIndex: Integer): Boolean;
var
  Sheet: TTabSheet;
begin
  if IsManualMode then
    Exit(AVisibleIndex = FManualSelectedIndex);
  Sheet := VisibleTabSheetAt(AVisibleIndex);
  Result := Assigned(FPageControl) and Assigned(Sheet) and (FPageControl.ActivePage = Sheet);
end;

function TLcaThemedPageTabBar.VisibleTabSheetAt(AVisibleIndex: Integer): TTabSheet;
var
  I, N: Integer;
  Sheet: TTabSheet;
begin
  Result := nil;
  if not Assigned(FPageControl) then Exit;
  N := 0;
  for I := 0 to FPageControl.PageCount - 1 do begin
    Sheet := FPageControl.Pages[I];
    if TabIsHidden(Sheet) then Continue;
    if N = AVisibleIndex then
      Exit(Sheet);
    Inc(N);
  end;
end;

function TLcaThemedPageTabBar.IndexOfTabSheet(ASheet: TTabSheet): Integer;
var
  I, N: Integer;
  Sheet: TTabSheet;
begin
  Result := -1;
  if not Assigned(FPageControl) or not Assigned(ASheet) then Exit;
  N := 0;
  for I := 0 to FPageControl.PageCount - 1 do begin
    Sheet := FPageControl.Pages[I];
    if TabIsHidden(Sheet) then Continue;
    if Sheet = ASheet then
      Exit(N);
    Inc(N);
  end;
end;

procedure TLcaThemedPageTabBar.LayoutAddTabRect(const AMeasureCanvas: TControlCanvas; var AX: Integer);
var
  TabW, VertInset, HorizPad, MinW: Integer;
begin
  FAddTabRect := Rect(0, 0, 0, 0);
  if not FShowAddTab then Exit;
  VertInset := ThemedTabVertInset(Self);
  HorizPad := ThemedTabHorizPad(Self);
  MinW := ThemedTabAddMinWidth(Self);
  TabW := AMeasureCanvas.TextWidth(FAddTabCaption) + HorizPad * 2;
  if TabW < MinW then
    TabW := MinW;
  FAddTabRect.Left := AX;
  FAddTabRect.Top := VertInset;
  FAddTabRect.Right := AX + TabW;
  FAddTabRect.Bottom := Height - VertInset;
end;

procedure TLcaThemedPageTabBar.LayoutTabs;
var
  I, Count, TabW, X, Pad, MinW, MinWClose, HorizPad, CloseCol, VertInset, TabGap: Integer;
  MeasureCanvas: TControlCanvas;
begin
  SetLength(FTabRects, 0);
  FAddTabRect := Rect(0, 0, 0, 0);
  Count := VisibleTabCount;
  if (Count = 0) and not FShowAddTab then Exit;

  VertInset := ThemedTabVertInset(Self);
  TabGap := ThemedTabBetweenGap(Self);
  MeasureCanvas := TControlCanvas.Create;
  try
    MeasureCanvas.Control := Self;
    MeasureCanvas.Font.Name := ThemedUiFontName;
    MeasureCanvas.Font.Size := ThemedTabFontSize;
    Pad := ThemedTabHorizPad(Self);
    HorizPad := Pad;
    CloseCol := ThemedTabCloseColumn(Self);
    MinW := ScaledThemedTabMetric(Self, ThemedTabMinWidthBase);
    MinWClose := ScaledThemedTabMetric(Self, ThemedTabMinWidthClosableBase);
    X := Pad;
    if Count > 0 then begin
      SetLength(FTabRects, Count);
      for I := 0 to Count - 1 do begin
        TabW := MeasureCanvas.TextWidth(TabCaptionAt(I)) + HorizPad * 2;
        if TabAllowCloseAt(I) then
          Inc(TabW, CloseCol)
        else
          Inc(TabW, HorizPad);
        if TabAllowCloseAt(I) then begin
          if TabW < MinWClose then
            TabW := MinWClose;
        end else if TabW < MinW then
          TabW := MinW;
        FTabRects[I].Left := X;
        FTabRects[I].Top := VertInset;
        FTabRects[I].Right := X + TabW;
        FTabRects[I].Bottom := Height - VertInset;
        X := FTabRects[I].Right + TabGap;
      end;
    end;
    LayoutAddTabRect(MeasureCanvas, X);
  finally
    MeasureCanvas.Free;
  end;
end;

procedure TLcaThemedPageTabBar.RefreshFromPageControl;
begin
  LayoutTabs;
  Invalidate;
end;

procedure TLcaThemedPageTabBar.PaintTabStrip;
var
  I: Integer;
  EffTheme: TThemeKind;
begin
  EffTheme := EffectiveControlTheme(Self, ThemeKind);
  LayoutTabs;
  for I := 0 to High(FTabRects) do
    PaintThemedTab(Canvas, FTabRects[I], TabCaptionAt(I), TabIsSelectedAt(I),
      FHoverTabIndex = I, TabAllowCloseAt(I), FHoverCloseIndex = I, EffTheme, Self);
  if FShowAddTab and (FAddTabRect.Right > FAddTabRect.Left) then
    PaintThemedTab(Canvas, FAddTabRect, FAddTabCaption, False, FHoverTabIndex = VisibleTabCount,
      False, False, EffTheme, Self, True);
end;

procedure TLcaThemedPageTabBar.Paint;
var
  P: TThemePalette;
  R: TRect;
begin
  P := EffectivePalette;
  R := ClientRect;
  Canvas.Brush.Color := P.HeaderBg;
  Canvas.FillRect(R);
  PaintTabStrip;
end;

procedure TLcaThemedPageTabBar.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  I, OldTab, OldClose: Integer;
  R: TRect;
  CloseR: TRect;
begin
  inherited MouseMove(Shift, X, Y);
  OldTab := FHoverTabIndex;
  OldClose := FHoverCloseIndex;
  FHoverTabIndex := -1;
  FHoverCloseIndex := -1;
  LayoutTabs;
  for I := 0 to High(FTabRects) do begin
    R := FTabRects[I];
    if PtInRect(R, Point(X, Y)) then begin
      FHoverTabIndex := I;
      if TabAllowCloseAt(I) then begin
        CloseR := ThemedTabCloseHitRect(R, Self);
        if PtInRect(CloseR, Point(X, Y)) then
          FHoverCloseIndex := I;
      end;
      Break;
    end;
  end;
  if FShowAddTab and PtInRect(FAddTabRect, Point(X, Y)) then
    FHoverTabIndex := VisibleTabCount;
  if (FHoverTabIndex <> OldTab) or (FHoverCloseIndex <> OldClose) then
    Invalidate;
end;

procedure TLcaThemedPageTabBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  Sheet: TTabSheet;
  AllowClose: Boolean;
  CloseR: TRect;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  LayoutTabs;

  if FShowAddTab and PtInRect(FAddTabRect, Point(X, Y)) then begin
    if Assigned(FOnAddTab) then
      FOnAddTab(Self);
    Exit;
  end;

  for I := 0 to High(FTabRects) do begin
    if not PtInRect(FTabRects[I], Point(X, Y)) then Continue;
    if TabAllowCloseAt(I) then begin
      CloseR := ThemedTabCloseHitRect(FTabRects[I], Self);
      if PtInRect(CloseR, Point(X, Y)) then begin
        AllowClose := True;
        if IsManualMode then begin
          if Assigned(FOnManualTabClose) then
            FOnManualTabClose(Self, I, AllowClose);
          if AllowClose then
            Invalidate;
        end else begin
          Sheet := VisibleTabSheetAt(I);
          if Assigned(FOnTabClose) then
            FOnTabClose(Self, Sheet, AllowClose);
          if AllowClose then
            RefreshFromPageControl;
        end;
        Exit;
      end;
    end;
    if IsManualMode then begin
      if Assigned(FOnManualTabSelect) then
        FOnManualTabSelect(Self, I);
      FManualSelectedIndex := I;
      Invalidate;
    end else begin
      Sheet := VisibleTabSheetAt(I);
      if Assigned(FPageControl) then
        FPageControl.ActivePage := Sheet;
      RefreshFromPageControl;
    end;
    Exit;
  end;
end;

procedure TLcaThemedPageTabBar.MouseLeave;
begin
  inherited MouseLeave;
  if (FHoverTabIndex >= 0) or (FHoverCloseIndex >= 0) then begin
    FHoverTabIndex := -1;
    FHoverCloseIndex := -1;
    Invalidate;
  end;
end;

procedure TLcaThemedPageTabBar.ChangeScale(M, D: Integer);
begin
  inherited ChangeScale(M, D);
  if not UsesParentForHeight then
    Height := ScaledThemedTabBarHeight(Self);
end;

end.
