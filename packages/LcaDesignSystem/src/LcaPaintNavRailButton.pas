unit LcaPaintNavRailButton;

{$mode objfpc}{$H+}

{ TLcaPaintNavRailButton — custom-painted nav rail cell (delivery 007).
  Paint parity with TLcaNavRailButton; no TSpeedButton native styling. }

interface

uses
  Classes, Controls, ExtCtrls, Graphics, Forms, LcaThemedControl, LcaTheme;

type
  TLcaPaintNavRailButton = class(TLcaThemedControl)
  private
    FNavCaption: string;
    FActive: Boolean;
    FCaption: string;
    FGlyph: TBitmap;
    FSpacing: Integer;
    FPressed: Boolean;
    FHover: Boolean;
    FInClick: Boolean;
    FOnClick: TNotifyEvent;
    procedure SetNavCaption(const AValue: string);
    procedure SetActive(AValue: Boolean);
    procedure SetCaption(const AValue: string);
    procedure SetGlyph(AValue: TBitmap);
    function IsOnDesignerSurface: Boolean;
    function DesignerBackgroundColor: TColor;
    function DesignerForegroundColor: TColor;
    procedure SyncParentRailHostForDesigner;
    procedure PaintButtonContent(const AR: TRect; AFg: TColor);
    procedure PaintDesignerSurface;
    procedure PaintRuntimeSurface(const AR: TRect; const P: TThemePalette);
  protected
    procedure DoApplyThemeColors(const P: TThemePalette); override;
    procedure PaintThemedClient(const ARect: TRect; const P: TThemePalette); override;
    procedure Paint; override;
    procedure Loaded; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Click; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyTheme(ATheme: TThemeKind); override;
  published
    property NavCaption: string read FNavCaption write SetNavCaption;
    property Active: Boolean read FActive write SetActive default False;
    property Caption: string read FCaption write SetCaption;
    property Glyph: TBitmap read FGlyph write SetGlyph;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property Align;
    property Anchors;
    property Left;
    property Top;
    property Width;
    property Height;
    property Visible;
    property Enabled;
    property Font;
    property Hint;
    property ShowHint;
    property ThemeKind;
  end;

implementation

uses
  SysUtils, Types, LCLType;

procedure TLcaPaintNavRailButton.SetNavCaption(const AValue: string);
begin
  if FNavCaption = AValue then Exit;
  FNavCaption := AValue;
  if FNavCaption <> '' then
    Hint := FNavCaption;
  Invalidate;
end;

procedure TLcaPaintNavRailButton.SetActive(AValue: Boolean);
begin
  if FActive = AValue then Exit;
  FActive := AValue;
  if IsOnDesignerSurface then
    Invalidate
  else
    ApplyTheme(ThemeKind);
end;

procedure TLcaPaintNavRailButton.SetCaption(const AValue: string);
begin
  if FCaption = AValue then Exit;
  FCaption := AValue;
  Invalidate;
end;

procedure TLcaPaintNavRailButton.SetGlyph(AValue: TBitmap);
begin
  if AValue = FGlyph then Exit;
  if Assigned(AValue) then
    FGlyph.Assign(AValue)
  else
    FGlyph.SetSize(0, 0);
  Invalidate;
end;

constructor TLcaPaintNavRailButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGlyph := TBitmap.Create;
  FSpacing := 4;
  FActive := False;
  Width := 76;
  Height := 40;
  Cursor := crHandPoint;
  TabStop := False;
end;

destructor TLcaPaintNavRailButton.Destroy;
begin
  FGlyph.Free;
  inherited Destroy;
end;

function TLcaPaintNavRailButton.IsOnDesignerSurface: Boolean;
begin
  if csDesigning in ComponentState then
    Exit(True);
  if LcaComponentOrOwnerDesigning(Self) then
    Exit(True);
  if Assigned(Application) and (csDesigning in Application.ComponentState) then
    Exit(True);
  if LcaInDesignContext(Self) then
    Exit(True);
  if LazarusIdeHostExecutable and (GetParentForm(Self) <> nil) then
    Exit(True);
  Result := False;
end;

function TLcaPaintNavRailButton.DesignerBackgroundColor: TColor;
begin
  if ParentColor and Assigned(Parent) then
    Result := Parent.Color
  else
    Result := Color;
  if Result = clDefault then
    Result := clBtnFace;
end;

function TLcaPaintNavRailButton.DesignerForegroundColor: TColor;
begin
  Result := Font.Color;
  if Result = clDefault then
    Result := clWindowText;
end;

procedure TLcaPaintNavRailButton.SyncParentRailHostForDesigner;
begin
  if not IsOnDesignerSurface then Exit;
  if not (Parent is TPanel) then Exit;
  if TPanel(Parent).Color = DesignerBackgroundColor then Exit;
  TPanel(Parent).Color := DesignerBackgroundColor;
end;

procedure TLcaPaintNavRailButton.Loaded;
begin
  inherited Loaded;
  if IsOnDesignerSurface then begin
    SyncParentRailHostForDesigner;
    Invalidate;
    Exit;
  end;
  ApplyTheme(ThemeKind);
end;

procedure TLcaPaintNavRailButton.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  inherited ApplyTheme(ATheme);
  if IsOnDesignerSurface then
    Exit;
  P := ThemePalette(ATheme);
  if FActive then
    Font.Color := P.Accent
  else
    Font.Color := P.TextMuted;
  Invalidate;
end;

procedure TLcaPaintNavRailButton.DoApplyThemeColors(const {%H-}P: TThemePalette);
begin
  if FActive then
    Font.Color := P.Accent
  else
    Font.Color := P.TextMuted;
end;

procedure TLcaPaintNavRailButton.PaintButtonContent(const AR: TRect; AFg: TColor);
var
  CaptionStr: string;
  GlyphH, TextH, TotalH, Y, TextX: Integer;
begin
  Canvas.Font := Font;
  Canvas.Font.Color := AFg;
  Canvas.Brush.Style := bsClear;

  CaptionStr := FCaption;
  if (FGlyph <> nil) and (FGlyph.Width > 0) and (FGlyph.Height > 0) then begin
    GlyphH := FGlyph.Height;
    TextH := 0;
    if CaptionStr <> '' then
      TextH := Canvas.TextHeight(CaptionStr) + FSpacing;
    TotalH := GlyphH + TextH;
    Y := AR.Top + (AR.Height - TotalH) div 2;
    Canvas.Draw(AR.Left + (AR.Width - FGlyph.Width) div 2, Y, FGlyph);
    if CaptionStr <> '' then begin
      Y := Y + GlyphH + FSpacing;
      TextX := AR.Left + (AR.Width - Canvas.TextWidth(CaptionStr)) div 2;
      Canvas.TextOut(TextX, Y, CaptionStr);
    end;
  end else if CaptionStr <> '' then begin
    TextX := AR.Left + (AR.Width - Canvas.TextWidth(CaptionStr)) div 2;
    Y := AR.Top + (AR.Height - Canvas.TextHeight(CaptionStr)) div 2;
    Canvas.TextOut(TextX, Y, CaptionStr);
  end;
end;

procedure TLcaPaintNavRailButton.PaintDesignerSurface;
var
  R: TRect;
  Bg, Fg: TColor;
  P: TThemePalette;
begin
  R := ClientRect;
  Bg := DesignerBackgroundColor;
  Fg := DesignerForegroundColor;

  Canvas.Brush.Color := Bg;
  Canvas.FillRect(R);

  if FActive then begin
    P := ThemePalette(tkLight);
    Fg := P.Accent;
    Canvas.Pen.Color := P.Accent;
    Canvas.Pen.Width := 3;
    Canvas.MoveTo(0, R.Top + 4);
    Canvas.LineTo(0, R.Bottom - 4);
    Canvas.Pen.Width := 1;
  end;

  PaintButtonContent(R, Fg);
end;

procedure TLcaPaintNavRailButton.PaintRuntimeSurface(const AR: TRect; const P: TThemePalette);
var
  TextColor: TColor;
begin
  PaintThemedNavRailCell(Canvas, AR, P, FActive, FHover and Enabled, FPressed and Enabled);

  if FActive then
    TextColor := P.Accent
  else if FHover and Enabled then
    TextColor := P.Text
  else
    TextColor := P.TextMuted;

  PaintButtonContent(AR, TextColor);
end;

procedure TLcaPaintNavRailButton.PaintThemedClient(const ARect: TRect; const {%H-}P: TThemePalette);
begin
  PaintRuntimeSurface(ARect, P);
end;

procedure TLcaPaintNavRailButton.Paint;
var
  P: TThemePalette;
  R: TRect;
begin
  if IsOnDesignerSurface then
    PaintDesignerSurface
  else begin
    P := EffectivePalette;
    R := ClientRect;
    PaintThemedClient(R, P);
  end;
end;

procedure TLcaPaintNavRailButton.MouseEnter;
begin
  inherited MouseEnter;
  FHover := True;
  Invalidate;
end;

procedure TLcaPaintNavRailButton.MouseLeave;
begin
  inherited MouseLeave;
  FHover := False;
  FPressed := False;
  Invalidate;
end;

procedure TLcaPaintNavRailButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
    FPressed := True;
end;

procedure TLcaPaintNavRailButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if Button = mbLeft then
    FPressed := False;
end;

procedure TLcaPaintNavRailButton.Click;
begin
  if FInClick then Exit;
  FInClick := True;
  try
    inherited Click;
    if Assigned(FOnClick) then
      FOnClick(Self);
  finally
    FInClick := False;
  end;
end;

end.
