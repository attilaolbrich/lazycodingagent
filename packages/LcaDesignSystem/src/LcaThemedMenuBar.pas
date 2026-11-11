unit LcaThemedMenuBar;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, Menus, Forms, Graphics, LCLType,
  LcaTheme, LcaThemedMainMenu, LcaThemedMenuFlyout, LcaFormChrome;

type
  TLcaThemedMenuBar = class(TPanel)
  private
    FMainMenu: TLcaThemedMainMenu;
    FTheme: TThemeKind;
    FHoverIndex: Integer;
    FTopLevelMenuIndex: array of Integer;
    FItemRects: array of TRect;
    FFlyout: TLcaThemedMenuFlyout;
    FBarFontSize: Integer;
    procedure SetMainMenu(AValue: TLcaThemedMainMenu);
    procedure SetThemeKind(AValue: TThemeKind);
    procedure MainMenuChanged(Sender: TObject);
    procedure LayoutTopLevelItems;
    function VisibleBarSlotAt(X, Y: Integer): Integer;
    function MenuIndexForBarSlot(ASlot: Integer): Integer;
    procedure ShowPopupForMenuIndex(AMenuIndex: Integer);
    function HostForm: TCustomForm;
    function InTitleBar: Boolean;
  protected
    procedure Loaded; override;
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    procedure ChangeScale(M, D: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure RefreshFromMainMenu;
    function PreferredWidth: Integer;
  published
    property ThemeKind: TThemeKind read FTheme write SetThemeKind default tkDark;
    property MainMenu: TLcaThemedMainMenu read FMainMenu write SetMainMenu;
  end;

implementation

function TLcaThemedMenuBar.HostForm: TCustomForm;
begin
  Result := GetParentForm(Self);
end;

function TLcaThemedMenuBar.InTitleBar: Boolean;
begin
  Result := Assigned(Parent) and (CompareText(Parent.ClassName, 'TLcaThemedTitleBar') = 0);
end;

procedure TLcaThemedMenuBar.SetThemeKind(AValue: TThemeKind);
begin
  if FTheme = AValue then Exit;
  FTheme := AValue;
  ApplyTheme(FTheme);
end;

procedure TLcaThemedMenuBar.SetMainMenu(AValue: TLcaThemedMainMenu);
begin
  if FMainMenu = AValue then Exit;
  if Assigned(FMainMenu) then
    FMainMenu.OnMenuChanged := nil;
  FMainMenu := AValue;
  if Assigned(FMainMenu) then
    FMainMenu.OnMenuChanged := @MainMenuChanged;
  RefreshFromMainMenu;
end;

procedure TLcaThemedMenuBar.MainMenuChanged(Sender: TObject);
begin
  RefreshFromMainMenu;
end;

procedure TLcaThemedMenuBar.LayoutTopLevelItems;
var
  I, X, W, Slot: Integer;
  Item: TMenuItem;
  Cap: string;
begin
  SetLength(FItemRects, 0);
  SetLength(FTopLevelMenuIndex, 0);
  if not Assigned(FMainMenu) then Exit;

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := FBarFontSize;

  X := 0;
  Slot := 0;
  for I := 0 to FMainMenu.Items.Count - 1 do begin
    Item := FMainMenu.Items[I];
    if not Item.Visible then Continue;
    Cap := MenuItemDisplayCaption(Item.Caption);
    if Cap = '' then Continue;
    W := Canvas.TextWidth(Cap) + 20;
    SetLength(FItemRects, Slot + 1);
    SetLength(FTopLevelMenuIndex, Slot + 1);
    FItemRects[Slot] := Rect(X, 0, X + W, ClientHeight);
    FTopLevelMenuIndex[Slot] := I;
    Inc(X, W);
    Inc(Slot);
  end;
end;

function TLcaThemedMenuBar.VisibleBarSlotAt(X, Y: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  if (Y < 0) or (Y >= ClientHeight) then Exit;
  for I := 0 to High(FItemRects) do
    if (X >= FItemRects[I].Left) and (X < FItemRects[I].Right) then
      Exit(I);
end;

function TLcaThemedMenuBar.MenuIndexForBarSlot(ASlot: Integer): Integer;
begin
  if (ASlot < 0) or (ASlot > High(FTopLevelMenuIndex)) then
    Exit(-1);
  Result := FTopLevelMenuIndex[ASlot];
end;

procedure TLcaThemedMenuBar.ShowPopupForMenuIndex(AMenuIndex: Integer);
var
  Item: TMenuItem;
  P: TPoint;
  Slot, I: Integer;
  F: TCustomForm;
begin
  if not Assigned(FMainMenu) then Exit;
  if (AMenuIndex < 0) or (AMenuIndex >= FMainMenu.Items.Count) then Exit;
  Item := FMainMenu.Items[AMenuIndex];

  if Item.Count = 0 then begin
    if Assigned(Item.OnClick) then
      Item.OnClick(Item)
    else
      Item.Click;
    Exit;
  end;

  Slot := -1;
  for I := 0 to High(FTopLevelMenuIndex) do
    if FTopLevelMenuIndex[I] = AMenuIndex then begin
      Slot := I;
      Break;
    end;
  if Slot < 0 then Exit;

  F := HostForm;
  if F = nil then Exit;

  P := ClientToScreen(Point(FItemRects[Slot].Left, Height));
  FFlyout.ShowForMenuItem(Item, P, FTheme, F);
end;

constructor TLcaThemedMenuBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  ControlStyle := ControlStyle + [csOpaque];
  if not (Assigned(AOwner) and (CompareText(AOwner.ClassName, 'TLcaThemedTitleBar') = 0)) then
    Align := alTop;
  FTheme := tkDark;
  FHoverIndex := -1;
  FBarFontSize := ThemedMenuBarFontSizeBase;
  Height := ScaledThemedMenuBarHeight(Self);
  DoubleBuffered := True;
  FFlyout := TLcaThemedMenuFlyout.Create(nil);
end;

destructor TLcaThemedMenuBar.Destroy;
begin
  FFlyout.HideFlyout;
  FFlyout.Free;
  inherited Destroy;
end;

procedure TLcaThemedMenuBar.Loaded;
begin
  inherited Loaded;
  ApplyTheme(FTheme);
end;

procedure TLcaThemedMenuBar.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
  EffTheme: TThemeKind;
begin
  FTheme := ATheme;
  EffTheme := EffectiveControlTheme(Self, ATheme);
  P := ThemePalette(EffTheme);
  if InTitleBar then
    Color := P.TitleBarBg
  else
    Color := P.HeaderBg;
  Font.Color := P.Text;
  FBarFontSize := ThemedMenuBarFontSizeBase;
  if FFlyout.Visible then
    FFlyout.ApplyTheme(ATheme);
  Invalidate;
end;

procedure TLcaThemedMenuBar.RefreshFromMainMenu;
begin
  LayoutTopLevelItems;
  Invalidate;
end;

function TLcaThemedMenuBar.PreferredWidth: Integer;
var
  I: Integer;
begin
  LayoutTopLevelItems;
  Result := 0;
  for I := 0 to High(FItemRects) do
    if FItemRects[I].Right > Result then
      Result := FItemRects[I].Right;
  if Result = 0 then
    Result := ScaledThemedTabMetric(Self, 8);
end;

procedure TLcaThemedMenuBar.Paint;
var
  P: TThemePalette;
  EffTheme: TThemeKind;
  I, MenuIdx: Integer;
  Selected: Boolean;
  Item: TMenuItem;
begin
  inherited Paint;
  EffTheme := EffectiveControlTheme(Self, FTheme);
  P := ThemePalette(EffTheme);
  if InTitleBar then
    Canvas.Brush.Color := P.TitleBarBg
  else
    Canvas.Brush.Color := P.HeaderBg;
  Canvas.FillRect(ClientRect);

  if not Assigned(FMainMenu) then Exit;
  LayoutTopLevelItems;

  for I := 0 to High(FItemRects) do begin
    MenuIdx := FTopLevelMenuIndex[I];
    Item := FMainMenu.Items[MenuIdx];
    Selected := (I = FHoverIndex);
    if InTitleBar then
      PaintThemedMenuBarItem(Canvas, FItemRects[I], Item.Caption, Selected, EffTheme,
        FBarFontSize, P.TitleBarBg)
    else
      PaintThemedMenuBarItem(Canvas, FItemRects[I], Item.Caption, Selected, EffTheme,
        FBarFontSize);
  end;
end;

procedure TLcaThemedMenuBar.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewHover: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  NewHover := VisibleBarSlotAt(X, Y);
  if NewHover <> FHoverIndex then begin
    FHoverIndex := NewHover;
    Invalidate;
  end;
end;

procedure TLcaThemedMenuBar.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  Slot, MenuIdx: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  Slot := VisibleBarSlotAt(X, Y);
  if Slot < 0 then begin
    TLcaFormChrome.BeginMove(HostForm, Button, ClientToScreen(Types.Point(X, Y)));
    Exit;
  end;
  MenuIdx := MenuIndexForBarSlot(Slot);
  if MenuIdx >= 0 then
    ShowPopupForMenuIndex(MenuIdx);
end;

procedure TLcaThemedMenuBar.MouseLeave;
begin
  inherited MouseLeave;
  if FHoverIndex >= 0 then begin
    FHoverIndex := -1;
    Invalidate;
  end;
end;

procedure TLcaThemedMenuBar.ChangeScale(M, D: Integer);
begin
  inherited ChangeScale(M, D);
  FBarFontSize := ThemedMenuBarFontSizeBase;
  if Align = alNone then
    Height := ScaledThemedMenuBarHeight(Self);
end;

end.
