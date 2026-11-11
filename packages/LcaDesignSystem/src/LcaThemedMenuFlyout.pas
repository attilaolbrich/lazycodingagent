unit LcaThemedMenuFlyout;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, Menus, Forms, Graphics, LCLType,
  LMessages, LCLProc, LcaTheme;

type
  { Borderless themed menu dropdown; not on the component palette. }
  TLcaThemedMenuFlyout = class(TPanel)
  private
    FTheme: TThemeKind;
    FHostForm: TCustomForm;
    FParentMenuItem: TMenuItem;
    FRowItems: array of TMenuItem;
    FHoverRow: Integer;
    FRowHeight: Integer;
    FSubFlyout: TLcaThemedMenuFlyout;
    FOwnerFlyout: TLcaThemedMenuFlyout;
    procedure DetachFromOwnerFlyout;
    procedure RebuildRows;
    procedure LayoutFlyoutSize;
    function RowAt(X, Y: Integer): Integer;
    procedure ExecuteSourceItem(ASource: TMenuItem);
    procedure OpenSubMenuForRow(ARowIndex: Integer);
    procedure CloseSubFlyout;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure ShowForMenuItem(AParentItem: TMenuItem; AScreenOrigin: TPoint;
      ATheme: TThemeKind; AHostForm: TCustomForm);
    procedure HideFlyout;
    class procedure CloseAllFlyouts;
  end;

implementation

type
  TMenuFlyoutHookHelper = class
    procedure UserInput(Sender: TObject; Msg: Cardinal);
    procedure KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  end;

var
  GMenuFlyouts: array of TLcaThemedMenuFlyout;
  GMenuFlyoutHooksInstalled: Boolean = False;
  GMenuFlyoutDismissSuppressUntil: QWord = 0;
  GMenuFlyoutHookHelper: TMenuFlyoutHookHelper;

function FlyoutRectOnScreen(AFlyout: TLcaThemedMenuFlyout): TRect;
var
  TL, BR: TPoint;
begin
  TL := AFlyout.ClientToScreen(Point(0, 0));
  BR := AFlyout.ClientToScreen(Point(AFlyout.Width, AFlyout.Height));
  Result := Rect(TL.X, TL.Y, BR.X, BR.Y);
end;

function FlyoutAtScreenPosInTree(AFlyout: TLcaThemedMenuFlyout;
  const P: TPoint): TLcaThemedMenuFlyout;
begin
  Result := nil;
  if not Assigned(AFlyout) or not AFlyout.Visible then Exit;
  if Assigned(AFlyout.FSubFlyout) then begin
    Result := FlyoutAtScreenPosInTree(AFlyout.FSubFlyout, P);
    if Result <> nil then Exit;
  end;
  if PtInRect(FlyoutRectOnScreen(AFlyout), P) then
    Result := AFlyout;
end;

function FlyoutAtScreenPos(const P: TPoint): TLcaThemedMenuFlyout;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to High(GMenuFlyouts) do begin
    Result := FlyoutAtScreenPosInTree(GMenuFlyouts[I], P);
    if Result <> nil then Exit;
  end;
end;

procedure TMenuFlyoutHookHelper.UserInput(Sender: TObject; Msg: Cardinal);
begin
  if Length(GMenuFlyouts) = 0 then Exit;
  if Msg = LM_LBUTTONDOWN then begin
    if GetTickCount64 < GMenuFlyoutDismissSuppressUntil then Exit;
    if FlyoutAtScreenPos(Mouse.CursorPos) = nil then
      TLcaThemedMenuFlyout.CloseAllFlyouts;
  end;
end;

procedure TMenuFlyoutHookHelper.KeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    TLcaThemedMenuFlyout.CloseAllFlyouts;
end;

procedure InstallFlyoutHooks;
begin
  if GMenuFlyoutHooksInstalled then Exit;
  if GMenuFlyoutHookHelper = nil then
    GMenuFlyoutHookHelper := TMenuFlyoutHookHelper.Create;
  GMenuFlyoutHooksInstalled := True;
  Application.AddOnUserInputHandler(@GMenuFlyoutHookHelper.UserInput, True);
  Application.AddOnKeyDownHandler(@GMenuFlyoutHookHelper.KeyDown, True);
end;

procedure UninstallFlyoutHooksIfIdle;
begin
  if Length(GMenuFlyouts) > 0 then Exit;
  if not GMenuFlyoutHooksInstalled then Exit;
  GMenuFlyoutHooksInstalled := False;
  Application.RemoveOnUserInputHandler(@GMenuFlyoutHookHelper.UserInput);
  Application.RemoveOnKeyDownHandler(@GMenuFlyoutHookHelper.KeyDown);
end;

procedure RegisterFlyout(AFlyout: TLcaThemedMenuFlyout);
var
  N: Integer;
begin
  N := Length(GMenuFlyouts);
  SetLength(GMenuFlyouts, N + 1);
  GMenuFlyouts[N] := AFlyout;
  InstallFlyoutHooks;
end;

procedure UnregisterFlyout(AFlyout: TLcaThemedMenuFlyout);
var
  I, N: Integer;
begin
  N := Length(GMenuFlyouts);
  for I := 0 to N - 1 do
    if GMenuFlyouts[I] = AFlyout then begin
      if I < N - 1 then
        GMenuFlyouts[I] := GMenuFlyouts[N - 1];
      SetLength(GMenuFlyouts, N - 1);
      Break;
    end;
end;

constructor TLcaThemedMenuFlyout.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  ControlStyle := ControlStyle + [csOpaque];
  Visible := False;
  FHoverRow := -1;
  FRowHeight := 28;
  DoubleBuffered := True;
  TabStop := False;
end;

destructor TLcaThemedMenuFlyout.Destroy;
begin
  CloseSubFlyout;
  if Visible then
    UnregisterFlyout(Self);
  inherited Destroy;
end;

procedure TLcaThemedMenuFlyout.DetachFromOwnerFlyout;
begin
  if Assigned(FOwnerFlyout) and (FOwnerFlyout.FSubFlyout = Self) then
    FOwnerFlyout.FSubFlyout := nil;
  FOwnerFlyout := nil;
end;

procedure TLcaThemedMenuFlyout.CloseSubFlyout;
var
  Sub: TLcaThemedMenuFlyout;
begin
  if not Assigned(FSubFlyout) then Exit;
  if FSubFlyout.FOwnerFlyout <> Self then begin
    FSubFlyout := nil;
    Exit;
  end;
  Sub := FSubFlyout;
  FSubFlyout := nil;
  Sub.HideFlyout;
  Sub.Free;
end;

procedure TLcaThemedMenuFlyout.HideFlyout;
begin
  DetachFromOwnerFlyout;
  CloseSubFlyout;
  if Visible then begin
    Visible := False;
    UnregisterFlyout(Self);
  end;
  FParentMenuItem := nil;
  SetLength(FRowItems, 0);
  FHoverRow := -1;
  UninstallFlyoutHooksIfIdle;
end;

class procedure TLcaThemedMenuFlyout.CloseAllFlyouts;
begin
  while Length(GMenuFlyouts) > 0 do
    GMenuFlyouts[High(GMenuFlyouts)].HideFlyout;
  UninstallFlyoutHooksIfIdle;
end;

procedure TLcaThemedMenuFlyout.RebuildRows;
var
  I, N: Integer;
  Child: TMenuItem;
begin
  SetLength(FRowItems, 0);
  if not Assigned(FParentMenuItem) then Exit;
  N := 0;
  for I := 0 to FParentMenuItem.Count - 1 do begin
    Child := FParentMenuItem.Items[I];
    if not Child.Visible then Continue;
    SetLength(FRowItems, N + 1);
    FRowItems[N] := Child;
    Inc(N);
  end;
end;

procedure TLcaThemedMenuFlyout.LayoutFlyoutSize;
var
  I, W, MaxW, Pad: Integer;
  Cap, ShortStr: string;
  Measure: TCanvas;
  Bmp: TBitmap;
begin
  FRowHeight := ScaledThemedMenuPopupItemHeight(Self);
  MaxW := 120;
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(1, 1);
    Measure := Bmp.Canvas;
    Measure.Font.Name := 'Segoe UI';
    Measure.Font.Size := 9;
    Pad := 48;
    for I := 0 to High(FRowItems) do begin
      Cap := MenuItemDisplayCaption(FRowItems[I].Caption);
      W := Measure.TextWidth(Cap) + Pad;
      if FRowItems[I].ShortCut <> 0 then begin
        ShortStr := ShortCutToText(FRowItems[I].ShortCut);
        Inc(W, Measure.TextWidth(ShortStr));
      end;
      if FRowItems[I].Count > 0 then
        Inc(W, 16);
      if W > MaxW then
        MaxW := W;
    end;
  finally
    Bmp.Free;
  end;
  Width := MaxW;
  if Length(FRowItems) = 0 then
    Height := 0
  else
    Height := Length(FRowItems) * FRowHeight;
end;

function TLcaThemedMenuFlyout.RowAt(X, Y: Integer): Integer;
begin
  if (Y < 0) or (FRowHeight <= 0) then
    Exit(-1);
  Result := Y div FRowHeight;
  if Result > High(FRowItems) then
    Result := -1;
end;

procedure TLcaThemedMenuFlyout.ExecuteSourceItem(ASource: TMenuItem);
begin
  if not Assigned(ASource) then Exit;
  if ASource.AutoCheck then
    ASource.Checked := not ASource.Checked;
  if Assigned(ASource.OnClick) then
    ASource.OnClick(ASource)
  else
    ASource.Click;
end;

procedure TLcaThemedMenuFlyout.OpenSubMenuForRow(ARowIndex: Integer);
var
  Src: TMenuItem;
  P: TPoint;
  R: TRect;
begin
  if (ARowIndex < 0) or (ARowIndex > High(FRowItems)) then Exit;
  Src := FRowItems[ARowIndex];
  if Src.Count = 0 then Exit;

  CloseSubFlyout;
  FSubFlyout := TLcaThemedMenuFlyout.Create(FHostForm);
  FSubFlyout.FOwnerFlyout := Self;
  R := Rect(0, ARowIndex * FRowHeight, Width, (ARowIndex + 1) * FRowHeight);
  P := ClientToScreen(Point(R.Right, R.Top));
  FSubFlyout.ShowForMenuItem(Src, P, FTheme, FHostForm);
end;

procedure TLcaThemedMenuFlyout.ShowForMenuItem(AParentItem: TMenuItem;
  AScreenOrigin: TPoint; ATheme: TThemeKind; AHostForm: TCustomForm);
var
  P: TPoint;
  WorkArea: TRect;
begin
  if not Assigned(AParentItem) or not Assigned(AHostForm) then Exit;
  if AParentItem.Count = 0 then begin
    ExecuteSourceItem(AParentItem);
    Exit;
  end;

  FHostForm := AHostForm;
  FParentMenuItem := AParentItem;
  FTheme := ATheme;
  Parent := AHostForm;
  ApplyTheme(ATheme);
  RebuildRows;
  LayoutFlyoutSize;
  if Height = 0 then Exit;

  WorkArea := Screen.MonitorFromPoint(AScreenOrigin).WorkareaRect;
  if AScreenOrigin.X + Width > WorkArea.Right then
    AScreenOrigin.X := WorkArea.Right - Width;
  if AScreenOrigin.Y + Height > WorkArea.Bottom then
    AScreenOrigin.Y := WorkArea.Bottom - Height;
  if AScreenOrigin.X < WorkArea.Left then
    AScreenOrigin.X := WorkArea.Left;
  if AScreenOrigin.Y < WorkArea.Top then
    AScreenOrigin.Y := WorkArea.Top;
  P := AHostForm.ScreenToClient(AScreenOrigin);
  SetBounds(P.X, P.Y, Width, Height);

  BringToFront;
  Show;
  RegisterFlyout(Self);
  GMenuFlyoutDismissSuppressUntil := GetTickCount64 + 150;
  Invalidate;
end;

procedure TLcaThemedMenuFlyout.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
  EffTheme: TThemeKind;
begin
  FTheme := ATheme;
  EffTheme := EffectiveControlTheme(Self, ATheme);
  P := ThemePalette(EffTheme);
  Color := P.MenuFlyoutBg;
  FRowHeight := ScaledThemedMenuPopupItemHeight(Self);
  Invalidate;
  if Assigned(FSubFlyout) then
    FSubFlyout.ApplyTheme(ATheme);
end;

procedure TLcaThemedMenuFlyout.Paint;
var
  P: TThemePalette;
  EffTheme: TThemeKind;
  I: Integer;
  R: TRect;
  State: TOwnerDrawState;
begin
  inherited Paint;
  EffTheme := EffectiveControlTheme(Self, FTheme);
  P := ThemePalette(EffTheme);
  Canvas.Brush.Color := P.MenuFlyoutBg;
  Canvas.FillRect(ClientRect);
  Canvas.Pen.Color := P.Border;
  Canvas.Pen.Width := 1;
  Canvas.Brush.Style := bsClear;
  R := ClientRect;
  Dec(R.Right);
  Dec(R.Bottom);
  Canvas.Rectangle(R);

  for I := 0 to High(FRowItems) do begin
    R := Rect(0, I * FRowHeight, Width, (I + 1) * FRowHeight);
    State := [];
    if I = FHoverRow then
      Include(State, odSelected);
    ThemedMenuPopupDrawItem(Canvas, R, State, EffTheme, FRowItems[I]);
  end;
end;

procedure TLcaThemedMenuFlyout.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewRow: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  NewRow := RowAt(X, Y);
  if NewRow <> FHoverRow then begin
    FHoverRow := NewRow;
    Invalidate;
  end;
  if (NewRow >= 0) and (NewRow <= High(FRowItems)) and (FRowItems[NewRow].Count > 0) then
    OpenSubMenuForRow(NewRow)
  else
    CloseSubFlyout;
end;

procedure TLcaThemedMenuFlyout.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  Row: Integer;
  Src: TMenuItem;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  Row := RowAt(X, Y);
  if Row < 0 then Exit;
  Src := FRowItems[Row];
  if Src.Count > 0 then begin
    OpenSubMenuForRow(Row);
    Exit;
  end;
  CloseAllFlyouts;
  ExecuteSourceItem(Src);
end;

procedure TLcaThemedMenuFlyout.MouseLeave;
begin
  inherited MouseLeave;
end;

end.
