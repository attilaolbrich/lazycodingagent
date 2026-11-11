unit LcaPaintComboBox;

{$mode objfpc}{$H+}

{ TLcaPaintComboBox — painted drop-down list combo (delivery 009).
  Geometry: streamed Height / ItemHeight; ApplyTheme does not resize. }

interface

uses
  Classes, Controls, Graphics, LMessages, LcaThemedControl, LcaTheme;

type
  TLcaPaintComboBox = class(TLcaThemedControl)
  private
    FItems: TStrings;
    FItemIndex: Integer;
    FItemHeight: Integer;
    FShowFocusRing: Boolean;
    FDroppedDown: Boolean;
    FDropDown: TObject;
    FOnChange: TNotifyEvent;
    FOnSelect: TNotifyEvent;
    procedure DeferredFireSelectionEvents({%H-}Data: PtrInt);
    procedure DetachDropDownInstance(ADropDown: TObject);
    procedure SetItemIndex(AValue: Integer);
    procedure SetItemHeight(AValue: Integer);
    procedure SetShowFocusRing(AValue: Boolean);
    procedure SetText(const AValue: string);
    function GetText: string;
    procedure ItemsChanged(Sender: TObject);
    procedure ChangeSelection(AIndex: Integer; AFireEvents: Boolean);
    procedure CloseDropDown;
    procedure OpenDropDown;
  protected
    procedure DoApplyThemeColors(const P: TThemePalette); override;
    procedure PaintThemedClient(const ARect: TRect; const P: TThemePalette); override;
    procedure Loaded; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure CMEnter(var Message: TLMessage); message CM_ENTER;
    procedure CMExit(var Message: TLMessage); message CM_EXIT;
    procedure CMFocusChanged(var Message: TLMessage); message CM_FOCUSCHANGED;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyTheme(ATheme: TThemeKind); override;
    function DisplayText: string;
    procedure NotifyDropDownSelected(AIndex: Integer);
    procedure NotifyDropDownClosed;
    procedure NotifyDropDownOpened;
    procedure SetItemIndexSilent(AValue: Integer);
  published
    property Items: TStrings read FItems;
    property ItemIndex: Integer read FItemIndex write SetItemIndex default -1;
    property ItemHeight: Integer read FItemHeight write SetItemHeight;
    property Text: string read GetText write SetText;
    property ShowFocusRing: Boolean read FShowFocusRing write SetShowFocusRing default True;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnSelect: TNotifyEvent read FOnSelect write FOnSelect;
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
  SysUtils, Types, LCLType, LCLIntf, Forms, ExtCtrls, LCLProc, Math;

const
  cComboDropDownMaxVisibleRows = 8;
  cComboDropDownBorder = 1;

type
  TComboDropDownHookHelper = class
    procedure UserInput(Sender: TObject; Msg: Cardinal);
    procedure KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  end;

  { Themed dropdown list host — not on the palette. }
  TLcaPaintComboDropDown = class(TPanel)
  private
    FCombo: TLcaPaintComboBox;
    FTheme: TThemeKind;
    FHostForm: TCustomForm;
    FItemHeight: Integer;
    FHighlightIndex: Integer;
    FTopIndex: Integer;
    FVisibleRowCount: Integer;
    procedure LayoutSize;
    function RowAt(X, Y: Integer): Integer;
    procedure CommitIndex(AIndex: Integer);
    procedure CancelDropDown;
  protected
    procedure Paint; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure ShowForCombo(ACombo: TLcaPaintComboBox);
    procedure HideDropDown;
    class procedure CloseAll;
    class function DropDownAtScreenPos(const P: TPoint): TLcaPaintComboDropDown;
  end;

var
  GComboDropDowns: array of TLcaPaintComboDropDown;
  GComboDropDownHooksInstalled: Boolean = False;
  GComboDropDownHookHelper: TComboDropDownHookHelper;
  GComboDropDownDismissSuppressUntil: QWord = 0;

function ComboDropDownPanel(ACombo: TLcaPaintComboBox): TLcaPaintComboDropDown;
begin
  Result := nil;
  if not Assigned(ACombo) then Exit;
  if ACombo.FDropDown is TLcaPaintComboDropDown then
    Result := TLcaPaintComboDropDown(ACombo.FDropDown);
end;

procedure InstallComboDropDownHooks;
begin
  if GComboDropDownHooksInstalled then Exit;
  if GComboDropDownHookHelper = nil then
    GComboDropDownHookHelper := TComboDropDownHookHelper.Create;
  GComboDropDownHooksInstalled := True;
  Application.AddOnUserInputHandler(@GComboDropDownHookHelper.UserInput, True);
  Application.AddOnKeyDownHandler(@GComboDropDownHookHelper.KeyDown, True);
end;

procedure UninstallComboDropDownHooksIfIdle;
begin
  if Length(GComboDropDowns) > 0 then Exit;
  if not GComboDropDownHooksInstalled then Exit;
  GComboDropDownHooksInstalled := False;
  Application.RemoveOnUserInputHandler(@GComboDropDownHookHelper.UserInput);
  Application.RemoveOnKeyDownHandler(@GComboDropDownHookHelper.KeyDown);
end;

procedure RegisterComboDropDown(ADropDown: TLcaPaintComboDropDown);
var
  N: Integer;
begin
  N := Length(GComboDropDowns);
  SetLength(GComboDropDowns, N + 1);
  GComboDropDowns[N] := ADropDown;
  InstallComboDropDownHooks;
end;

procedure UnregisterComboDropDown(ADropDown: TLcaPaintComboDropDown);
var
  I, N: Integer;
begin
  N := Length(GComboDropDowns);
  for I := 0 to N - 1 do
    if GComboDropDowns[I] = ADropDown then begin
      if I < N - 1 then
        GComboDropDowns[I] := GComboDropDowns[N - 1];
      SetLength(GComboDropDowns, N - 1);
      Break;
    end;
end;

procedure TComboDropDownHookHelper.UserInput(Sender: TObject; Msg: Cardinal);
begin
  if Length(GComboDropDowns) = 0 then Exit;
  if Msg = LM_LBUTTONDOWN then begin
    if GetTickCount64 < GComboDropDownDismissSuppressUntil then Exit;
    if TLcaPaintComboDropDown.DropDownAtScreenPos(Mouse.CursorPos) = nil then
      TLcaPaintComboDropDown.CloseAll;
  end;
end;

procedure TComboDropDownHookHelper.KeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    TLcaPaintComboDropDown.CloseAll;
end;

class function TLcaPaintComboDropDown.DropDownAtScreenPos(const P: TPoint): TLcaPaintComboDropDown;
var
  I: Integer;
  R: TRect;
  TL, BR: TPoint;
begin
  Result := nil;
  for I := 0 to High(GComboDropDowns) do begin
    if not GComboDropDowns[I].Visible then Continue;
    TL := GComboDropDowns[I].ClientToScreen(Point(0, 0));
    BR := GComboDropDowns[I].ClientToScreen(Point(GComboDropDowns[I].Width, GComboDropDowns[I].Height));
    R := Rect(TL.X, TL.Y, BR.X, BR.Y);
    if PtInRect(R, P) then
      Exit(GComboDropDowns[I]);
  end;
end;

class procedure TLcaPaintComboDropDown.CloseAll;
var
  Copy: array of TLcaPaintComboDropDown;
  I: Integer;
begin
  SetLength(Copy, Length(GComboDropDowns));
  for I := 0 to High(GComboDropDowns) do
    Copy[I] := GComboDropDowns[I];
  for I := 0 to High(Copy) do
    if Assigned(Copy[I]) then
      Copy[I].HideDropDown;
  UninstallComboDropDownHooksIfIdle;
end;

constructor TLcaPaintComboDropDown.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  ControlStyle := ControlStyle + [csOpaque];
  Visible := False;
  DoubleBuffered := True;
  TabStop := True;
  FHighlightIndex := -1;
  FTopIndex := 0;
  FItemHeight := ThemedComboBoxItemHeight;
end;

destructor TLcaPaintComboDropDown.Destroy;
begin
  UnregisterComboDropDown(Self);
  if Assigned(FCombo) then
    FCombo.DetachDropDownInstance(Self);
  inherited Destroy;
end;

procedure TLcaPaintComboDropDown.LayoutSize;
var
  Count: Integer;
begin
  if not Assigned(FCombo) then Exit;
  Count := FCombo.Items.Count;
  if Count = 0 then begin
    FVisibleRowCount := 0;
    Width := Max(80, FCombo.Width);
    Height := 0;
    Exit;
  end;
  FVisibleRowCount := Min(Count, cComboDropDownMaxVisibleRows);
  if FItemHeight < 8 then
    FItemHeight := ScaledLayoutMetric(FCombo, ThemedComboBoxItemHeight);
  Width := Max(80, FCombo.Width);
  Height := FVisibleRowCount * FItemHeight + cComboDropDownBorder * 2;
  if Height < 32 then
    Height := 32;
  if FHighlightIndex >= Count then
    FHighlightIndex := Count - 1;
  if FHighlightIndex < 0 then
    FHighlightIndex := 0;
  if FHighlightIndex < FTopIndex then
    FTopIndex := FHighlightIndex;
  if FHighlightIndex >= FTopIndex + FVisibleRowCount then
    FTopIndex := FHighlightIndex - FVisibleRowCount + 1;
  if FTopIndex < 0 then
    FTopIndex := 0;
  if FTopIndex + FVisibleRowCount > Count then
    FTopIndex := Max(0, Count - FVisibleRowCount);
end;

function TLcaPaintComboDropDown.RowAt(X, Y: Integer): Integer;
var
  RelY: Integer;
begin
  Result := -1;
  if (Y < cComboDropDownBorder) or (FItemHeight <= 0) then Exit;
  RelY := Y - cComboDropDownBorder;
  Result := FTopIndex + RelY div FItemHeight;
  if Result >= FCombo.Items.Count then
    Result := -1;
end;

procedure TLcaPaintComboDropDown.CommitIndex(AIndex: Integer);
var
  Combo: TLcaPaintComboBox;
begin
  Combo := FCombo;
  HideDropDown;
  if Assigned(Combo) then
    Combo.NotifyDropDownSelected(AIndex);
end;

procedure TLcaPaintComboDropDown.CancelDropDown;
begin
  if Assigned(FCombo) then
    FCombo.NotifyDropDownClosed;
  HideDropDown;
end;

procedure TLcaPaintComboDropDown.ShowForCombo(ACombo: TLcaPaintComboBox);
var
  Origin, P: TPoint;
  WorkArea: TRect;
  F: TCustomForm;
  Mon: TMonitor;
begin
  if not Assigned(ACombo) then Exit;
  F := GetParentForm(ACombo);
  if F = nil then Exit;

  CloseAll;
  FCombo := ACombo;
  FHostForm := F;
  FTheme := ACombo.ThemeKind;
  FItemHeight := ACombo.ItemHeight;
  if FItemHeight < 8 then
    FItemHeight := ScaledLayoutMetric(ACombo, ThemedComboBoxItemHeight);
  FHighlightIndex := ACombo.ItemIndex;
  if (FHighlightIndex < 0) and (ACombo.Items.Count > 0) then
    FHighlightIndex := 0;
  FTopIndex := 0;

  Parent := FHostForm;
  ApplyTheme(FTheme);
  LayoutSize;
  if Height = 0 then Exit;

  Origin := ACombo.ClientToScreen(Point(0, ACombo.Height));
  Mon := Screen.MonitorFromPoint(Origin);
  if Mon <> nil then
    WorkArea := Mon.WorkareaRect
  else
    WorkArea := Screen.DesktopRect;
  if Origin.X + Width > WorkArea.Right then
    Origin.X := WorkArea.Right - Width;
  if Origin.Y + Height > WorkArea.Bottom then begin
    Origin.Y := ACombo.ClientToScreen(Point(0, 0)).Y - Height;
    if Origin.Y < WorkArea.Top then
      Origin.Y := WorkArea.Top;
  end;
  if Origin.X < WorkArea.Left then
    Origin.X := WorkArea.Left;

  P := FHostForm.ScreenToClient(Origin);
  SetBounds(P.X, P.Y, Width, Height);
  BringToFront;
  Show;
  RegisterComboDropDown(Self);
  GComboDropDownDismissSuppressUntil := GetTickCount64 + 150;
  SetFocus;
  Invalidate;
  if Assigned(FCombo) then
    FCombo.NotifyDropDownOpened;
end;

procedure TLcaPaintComboDropDown.HideDropDown;
begin
  if Visible then begin
    Visible := False;
    UnregisterComboDropDown(Self);
  end;
  FCombo := nil;
  FHostForm := nil;
  UninstallComboDropDownHooksIfIdle;
end;

procedure TLcaPaintComboDropDown.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
  EffTheme: TThemeKind;
begin
  FTheme := ATheme;
  EffTheme := EffectiveControlTheme(Self, ATheme);
  P := ThemePalette(EffTheme);
  Color := P.SurfaceAlt;
  Invalidate;
end;

procedure TLcaPaintComboDropDown.Paint;
var
  P: TThemePalette;
  EffTheme: TThemeKind;
  I, AbsIdx: Integer;
  R: TRect;
  State: TOwnerDrawState;
  Cap: string;
begin
  inherited Paint;
  if not Assigned(FCombo) then Exit;
  EffTheme := EffectiveControlTheme(Self, FTheme);
  P := ThemePalette(EffTheme);
  Canvas.Brush.Color := P.SurfaceAlt;
  Canvas.FillRect(ClientRect);
  Canvas.Pen.Color := P.Border;
  Canvas.Pen.Width := 1;
  Canvas.Brush.Style := bsClear;
  R := ClientRect;
  Dec(R.Right);
  Dec(R.Bottom);
  Canvas.Rectangle(R);

  for I := 0 to FVisibleRowCount - 1 do begin
    AbsIdx := FTopIndex + I;
    if AbsIdx >= FCombo.Items.Count then Break;
    R := Rect(cComboDropDownBorder, cComboDropDownBorder + I * FItemHeight,
      Width - cComboDropDownBorder, cComboDropDownBorder + (I + 1) * FItemHeight);
    State := [];
    if AbsIdx = FHighlightIndex then
      Include(State, odSelected);
    Cap := FCombo.Items[AbsIdx];
    PaintThemedComboListItem(Canvas, R, Cap, State, EffTheme);
  end;
end;

procedure TLcaPaintComboDropDown.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Row: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  Row := RowAt(X, Y);
  if Row <> FHighlightIndex then begin
    FHighlightIndex := Row;
    Invalidate;
  end;
end;

procedure TLcaPaintComboDropDown.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  Row: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  Row := RowAt(X, Y);
  if Row < 0 then Exit;
  CommitIndex(Row);
end;

function TLcaPaintComboDropDown.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
var
  Count, MaxTop: Integer;
begin
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if not Assigned(FCombo) then Exit(Result);
  Count := FCombo.Items.Count;
  if Count <= FVisibleRowCount then Exit(Result);
  MaxTop := Count - FVisibleRowCount;
  if WheelDelta > 0 then
    FTopIndex := Max(0, FTopIndex - 1)
  else
    FTopIndex := Min(MaxTop, FTopIndex + 1);
  Invalidate;
  Result := True;
end;

procedure TLcaPaintComboDropDown.KeyDown(var Key: Word; Shift: TShiftState);
var
  Count: Integer;
begin
  inherited KeyDown(Key, Shift);
  if not Assigned(FCombo) then Exit;
  Count := FCombo.Items.Count;
  if Count = 0 then Exit;

  case Key of
    VK_ESCAPE:
      CancelDropDown;
    VK_RETURN:
      if (FHighlightIndex >= 0) and (FHighlightIndex < Count) then
        CommitIndex(FHighlightIndex);
    VK_UP:
      if FHighlightIndex > 0 then begin
        Dec(FHighlightIndex);
        if FHighlightIndex < FTopIndex then
          FTopIndex := FHighlightIndex;
        Invalidate;
      end;
    VK_DOWN:
      if FHighlightIndex < Count - 1 then begin
        if FHighlightIndex < 0 then
          FHighlightIndex := 0
        else
          Inc(FHighlightIndex);
        if FHighlightIndex >= FTopIndex + FVisibleRowCount then
          FTopIndex := FHighlightIndex - FVisibleRowCount + 1;
        Invalidate;
      end;
    VK_HOME:
      begin
        FHighlightIndex := 0;
        FTopIndex := 0;
        Invalidate;
      end;
    VK_END:
      begin
        FHighlightIndex := Count - 1;
        if Count > FVisibleRowCount then
          FTopIndex := Count - FVisibleRowCount;
        Invalidate;
      end;
  end;
end;

{ TLcaPaintComboBox }

procedure TLcaPaintComboBox.SetItemIndex(AValue: Integer);
begin
  if (AValue < -1) or (Assigned(FItems) and (AValue >= FItems.Count)) then Exit;
  ChangeSelection(AValue, True);
end;

procedure TLcaPaintComboBox.SetItemHeight(AValue: Integer);
begin
  if FItemHeight = AValue then Exit;
  FItemHeight := AValue;
  Invalidate;
end;

procedure TLcaPaintComboBox.SetShowFocusRing(AValue: Boolean);
begin
  if FShowFocusRing = AValue then Exit;
  FShowFocusRing := AValue;
  Invalidate;
end;

function TLcaPaintComboBox.GetText: string;
begin
  Result := DisplayText;
end;

procedure TLcaPaintComboBox.SetText(const AValue: string);
var
  I: Integer;
begin
  if not Assigned(FItems) then Exit;
  for I := 0 to FItems.Count - 1 do
    if FItems[I] = AValue then begin
      SetItemIndex(I);
      Exit;
    end;
end;

procedure TLcaPaintComboBox.ItemsChanged(Sender: TObject);
begin
  if FItemIndex >= FItems.Count then
    FItemIndex := FItems.Count - 1;
  CloseDropDown;
  Invalidate;
end;

procedure TLcaPaintComboBox.ChangeSelection(AIndex: Integer; AFireEvents: Boolean);
begin
  if FItemIndex = AIndex then Exit;
  FItemIndex := AIndex;
  Invalidate;
  if not AFireEvents then Exit;
  if Assigned(FOnSelect) then
    FOnSelect(Self);
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TLcaPaintComboBox.CloseDropDown;
var
  DD: TLcaPaintComboDropDown;
begin
  FDroppedDown := False;
  DD := ComboDropDownPanel(Self);
  if Assigned(DD) and DD.Visible then
    DD.HideDropDown;
  Invalidate;
end;

procedure TLcaPaintComboBox.OpenDropDown;
var
  DD: TLcaPaintComboDropDown;
begin
  if not Enabled then Exit;
  if not Assigned(FItems) or (FItems.Count = 0) then Exit;
  if FDropDown = nil then
    FDropDown := TLcaPaintComboDropDown.Create(Self);
  FDroppedDown := True;
  Invalidate;
  DD := ComboDropDownPanel(Self);
  if Assigned(DD) then
    DD.ShowForCombo(Self);
end;

constructor TLcaPaintComboBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TStringList.Create;
  FItems.Add('Item 1');
  FItems.Add('Item 2');
  TStringList(FItems).OnChange := @ItemsChanged;
  FItemIndex := 0;
  FItemHeight := ScaledLayoutMetric(Self, ThemedComboBoxItemHeight);
  FShowFocusRing := True;
  TabStop := True;
  Cursor := crHandPoint;
  Width := 160;
  Height := ScaledLayoutMetric(Self, ThemedComboBoxHeight);
end;

destructor TLcaPaintComboBox.Destroy;
begin
  if Assigned(Application) then
    Application.RemoveAsyncCalls(Self);
  CloseDropDown;
  FreeAndNil(FDropDown);
  FreeAndNil(FItems);
  inherited Destroy;
end;

procedure TLcaPaintComboBox.DoApplyThemeColors(const {%H-}P: TThemePalette);
begin
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  Font.Color := P.Text;
  Color := P.SurfaceAlt;
end;

function TLcaPaintComboBox.DisplayText: string;
begin
  if Assigned(FItems) and (FItemIndex >= 0) and (FItemIndex < FItems.Count) then
    Exit(FItems[FItemIndex]);
  if LcaInDesignContext(Self) and Assigned(FItems) and (FItems.Count > 0) then
    Exit(FItems[0]);
  Result := '';
end;

procedure TLcaPaintComboBox.PaintThemedClient(const ARect: TRect; const {%H-}P: TThemePalette);
var
  EffTheme: TThemeKind;
  FieldFocused: Boolean;
begin
  EffTheme := EffectiveControlTheme(Self, ThemeKind);
  FieldFocused := Self.Focused;
  PaintThemedComboField(Canvas, ARect, EffTheme, DisplayText, Enabled, FieldFocused,
    FDroppedDown, FShowFocusRing, ThemedComboCornerRadius(Self),
    ThemedComboChevronGutter(Self));
end;

procedure TLcaPaintComboBox.Loaded;
begin
  inherited Loaded;
  if FItemHeight <= 0 then
    FItemHeight := ThemedComboItemHeightForControl(Height, 0);
end;

procedure TLcaPaintComboBox.ApplyTheme(ATheme: TThemeKind);
var
  DD: TLcaPaintComboDropDown;
begin
  inherited ApplyTheme(ATheme);
  DD := ComboDropDownPanel(Self);
  if Assigned(DD) and DD.Visible then
    DD.ApplyTheme(ATheme);
end;

procedure TLcaPaintComboBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  if not Focused then
    SetFocus;
  if FDroppedDown then
    CloseDropDown
  else
    OpenDropDown;
end;

procedure TLcaPaintComboBox.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if not Enabled then Exit;
  case Key of
    VK_F4, VK_DOWN:
      if (Key = VK_F4) or ((Key = VK_DOWN) and (ssAlt in Shift)) then begin
        if FDroppedDown then
          CloseDropDown
        else
          OpenDropDown;
        Key := 0;
      end;
    VK_SPACE:
      if not FDroppedDown then begin
        OpenDropDown;
        Key := 0;
      end;
    VK_ESCAPE:
      if FDroppedDown then begin
        CloseDropDown;
        Key := 0;
      end;
  end;
end;

procedure TLcaPaintComboBox.CMEnter(var {%H-}Message: TLMessage);
begin
  inherited;
  Invalidate;
end;

procedure TLcaPaintComboBox.CMExit(var {%H-}Message: TLMessage);
begin
  inherited;
  Invalidate;
end;

procedure TLcaPaintComboBox.CMFocusChanged(var {%H-}Message: TLMessage);
begin
  inherited;
  Invalidate;
end;

procedure TLcaPaintComboBox.SetItemIndexSilent(AValue: Integer);
begin
  if (AValue < -1) or (Assigned(FItems) and (AValue >= FItems.Count)) then Exit;
  ChangeSelection(AValue, False);
end;

procedure TLcaPaintComboBox.DetachDropDownInstance(ADropDown: TObject);
begin
  if FDropDown = ADropDown then
    FDropDown := nil;
  FDroppedDown := False;
end;

procedure TLcaPaintComboBox.DeferredFireSelectionEvents({%H-}Data: PtrInt);
begin
  if csDestroying in ComponentState then Exit;
  if Assigned(FOnSelect) then
    FOnSelect(Self);
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TLcaPaintComboBox.NotifyDropDownSelected(AIndex: Integer);
var
  IndexChanged: Boolean;
begin
  FDroppedDown := False;
  IndexChanged := FItemIndex <> AIndex;
  ChangeSelection(AIndex, False);
  Invalidate;
  if IndexChanged and Assigned(Application) then
    Application.QueueAsyncCall(@DeferredFireSelectionEvents, 0);
end;

procedure TLcaPaintComboBox.NotifyDropDownClosed;
begin
  FDroppedDown := False;
  Invalidate;
end;

procedure TLcaPaintComboBox.NotifyDropDownOpened;
begin
  FDroppedDown := True;
  Invalidate;
end;

initialization
  GComboDropDownHookHelper := TComboDropDownHookHelper.Create;

finalization
  FreeAndNil(GComboDropDownHookHelper);

end.
