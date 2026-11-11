unit LcaPaintButton;

{$mode objfpc}{$H+}

{ TLcaPaintButton — fully custom-painted themed button (delivery 006).
  Uses PaintThemedButton from LcaTheme; no native Qt/GTK/Win32 button styling. }

interface

uses
  Classes, Controls, Graphics, Forms, LMessages, LcaThemedControl, LcaTheme, LcaThemedButtonPaint;

type
  TLcaPaintButton = class(TLcaThemedControl)
  private
    FCaption: string;
    FButtonRole: TThemedButtonRole;
    FShowFocusRing: Boolean;
    FHover: Boolean;
    FPressed: Boolean;
    FInClick: Boolean;
    FOnClick: TNotifyEvent;
    FModalResult: TModalResult;
    procedure SetCaption(const AValue: string);
    procedure SetModalResult(AValue: TModalResult);
    procedure SetButtonRole(AValue: TThemedButtonRole);
    procedure SetShowFocusRing(AValue: Boolean);
  protected
    procedure DoApplyThemeColors(const P: TThemePalette); override;
    procedure PaintThemedClient(const ARect: TRect; const P: TThemePalette); override;
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure Click; override;
    procedure CMEnabledChanged(var Message: TLMessage); message CM_ENABLEDCHANGED;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Caption: string read FCaption write SetCaption;
    property ButtonRole: TThemedButtonRole read FButtonRole write SetButtonRole default tbrCancel;
    property ShowFocusRing: Boolean read FShowFocusRing write SetShowFocusRing default True;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property ModalResult: TModalResult read FModalResult write SetModalResult default mrNone;
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
  SysUtils, Types, LCLType, LCLIntf, Math;

procedure TLcaPaintButton.SetCaption(const AValue: string);
begin
  if FCaption = AValue then Exit;
  FCaption := AValue;
  Invalidate;
end;

procedure TLcaPaintButton.SetButtonRole(AValue: TThemedButtonRole);
begin
  if FButtonRole = AValue then Exit;
  FButtonRole := AValue;
  Invalidate;
end;

procedure TLcaPaintButton.SetShowFocusRing(AValue: Boolean);
begin
  if FShowFocusRing = AValue then Exit;
  FShowFocusRing := AValue;
  Invalidate;
end;

procedure TLcaPaintButton.SetModalResult(AValue: TModalResult);
begin
  FModalResult := AValue;
end;

constructor TLcaPaintButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCaption := 'Button';
  FModalResult := mrNone;
  FButtonRole := tbrCancel;
  FShowFocusRing := True;
  TabStop := True;
  Cursor := crHandPoint;
  Height := ScaledThemedButtonHeight(Self);
  Width := Max(MeasureThemedButtonWidth(Self, FCaption, FButtonRole), 80);
end;

procedure TLcaPaintButton.DoApplyThemeColors(const {%H-}P: TThemePalette);
begin
  Font.Name := ThemedUiFontName;
  Font.Size := ThemedButtonFontSize(Self);
  if FButtonRole in [tbrPrimary, tbrDestructive] then
    Font.Style := [fsBold]
  else
    Font.Style := [];
end;

procedure TLcaPaintButton.PaintThemedClient(const ARect: TRect; const {%H-}P: TThemePalette);
var
  Theme: TThemeKind;
  ShowFocus: Boolean;
begin
  Theme := EffectiveControlTheme(Self, ThemeKind);
  ShowFocus := FShowFocusRing and Focused;
  PaintThemedButton(Canvas, ARect, Theme, FButtonRole, ThemedButtonDisplayCaption(FCaption),
    Enabled, FHover and Enabled, FPressed and Enabled, ShowFocus,
    ThemedButtonCornerRadius(Self), ThemedButtonFontSize(Self),
    ThemedButtonHorizPad(Self), Self);
end;

procedure TLcaPaintButton.Paint;
var
  P: TThemePalette;
  R: TRect;
begin
  P := EffectivePalette;
  R := ClientRect;
  PaintThemedClient(R, P);
end;

procedure TLcaPaintButton.MouseEnter;
begin
  inherited MouseEnter;
  FHover := True;
  Invalidate;
end;

procedure TLcaPaintButton.MouseLeave;
begin
  inherited MouseLeave;
  FHover := False;
  FPressed := False;
  Invalidate;
end;

procedure TLcaPaintButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then begin
    FPressed := True;
    Invalidate;
  end;
end;

procedure TLcaPaintButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button = mbLeft then begin
    FPressed := False;
    Invalidate;
  end;
end;

procedure TLcaPaintButton.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if not Enabled then Exit;
  if (Key = VK_SPACE) or (Key = VK_RETURN) then begin
    Key := 0;
    Click;
  end;
end;

procedure TLcaPaintButton.Click;
var
  F: TCustomForm;
begin
  if FInClick then Exit;
  FInClick := True;
  try
    inherited Click;
    if Assigned(FOnClick) then
      FOnClick(Self);
    if FModalResult <> mrNone then begin
      F := GetParentForm(Self);
      if Assigned(F) then
        F.ModalResult := FModalResult;
    end;
  finally
    FInClick := False;
  end;
end;

procedure TLcaPaintButton.CMEnabledChanged(var {%H-}Message: TLMessage);
begin
  inherited CMEnabledChanged(Message);
  if FPressed or FHover then begin
    FPressed := False;
    FHover := False;
  end;
  Invalidate;
end;

end.
