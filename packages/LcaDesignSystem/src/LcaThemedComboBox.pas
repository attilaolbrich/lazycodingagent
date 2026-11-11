unit LcaThemedComboBox;

{$mode objfpc}{$H+}

interface

uses
  Classes, Types, StdCtrls, Controls, Forms, LcaTheme;

type
  TLcaThemedComboBox = class(TComboBox)
  private
    FThemeKind: TThemeKind;
    FShowFocusRing: Boolean;
    procedure SetThemeKind(AValue: TThemeKind);
    procedure SetShowFocusRing(AValue: Boolean);
    procedure ThemedDrawItem(Control: TWinControl; Index: Integer; ARect: TRect;
      State: TOwnerDrawState);
    function CanApplyRuntimeTheme: Boolean;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
  published
    property ThemeKind: TThemeKind read FThemeKind write SetThemeKind default tkDark;
    property ShowFocusRing: Boolean read FShowFocusRing write SetShowFocusRing default True;
  end;

implementation

uses
  SysUtils
  {$IFDEF WINDOWS}, LcaThemeWin32Combo{$ENDIF}
  ;

procedure TLcaThemedComboBox.SetThemeKind(AValue: TThemeKind);
begin
  if FThemeKind = AValue then Exit;
  FThemeKind := AValue;
  ApplyTheme(FThemeKind);
end;

procedure TLcaThemedComboBox.SetShowFocusRing(AValue: Boolean);
begin
  if FShowFocusRing = AValue then Exit;
  FShowFocusRing := AValue;
  Invalidate;
end;

constructor TLcaThemedComboBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FThemeKind := tkDark;
  FShowFocusRing := True;
end;

function TLcaThemedComboBox.CanApplyRuntimeTheme: Boolean;
var
  F: TCustomForm;
begin
  if LcaInDesignContext(Self) then
    Exit(False);
  if csLoading in ComponentState then
    Exit(False);
  if csReading in ComponentState then
    Exit(False);
  F := GetParentForm(Self);
  if (F = nil) or not F.HandleAllocated then
    Exit(False);
  if not HandleAllocated then
    Exit(False);
  Result := True;
end;

procedure TLcaThemedComboBox.ThemedDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
begin
  StyleComboBoxDrawItem(Control, Index, ARect, State, FThemeKind);
end;

procedure TLcaThemedComboBox.Loaded;
begin
  inherited Loaded;
  if LcaInDesignContext(Self) then
    ApplyTheme(FThemeKind);
end;

procedure TLcaThemedComboBox.ApplyTheme(ATheme: TThemeKind);
var
  EffTheme: TThemeKind;
begin
  FThemeKind := ATheme;
  if LcaInDesignContext(Self) then begin
    EffTheme := EffectiveControlTheme(Self, ATheme);
    StyleComboBox(Self, EffTheme);
    OnDrawItem := @ThemedDrawItem;
    Invalidate;
    Exit;
  end;
  if not CanApplyRuntimeTheme then
    Exit;
  StyleComboBox(Self, ATheme);
  OnDrawItem := @ThemedDrawItem;
  {$IFDEF WINDOWS}
  ApplyWin32ThemedComboPaint(Self, ATheme);
  {$ENDIF}
  Invalidate;
end;

end.
