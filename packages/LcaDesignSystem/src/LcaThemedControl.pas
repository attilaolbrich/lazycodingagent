unit LcaThemedControl;

{$mode objfpc}{$H+}

{ Base for custom-painted LCA controls (delivery 001+).
  Descendants: override DoApplyThemeColors / PaintThemedClient; use EffectivePalette in Paint.
  Geometry: streamed .lfm Align/Anchors/Width/Height — do not mix Align with manual SetBounds here.
  DPI chrome: ChangeScale calls inherited only; use ScaledLayoutMetric / ScaledThemed* from LcaTheme. }

interface

uses
  Classes, Controls, Graphics, LcaTheme;

type
  TLcaThemedControl = class(TCustomControl)
  private
    FThemeKind: TThemeKind;
    procedure SetThemeKind(AValue: TThemeKind);
  protected
    function EffectivePalette: TThemePalette;
    procedure DoApplyThemeColors(const P: TThemePalette); virtual;
    procedure PaintThemedClient(const ARect: TRect; const P: TThemePalette); virtual;
    procedure Loaded; override;
    procedure Paint; override;
    procedure ChangeScale(M, D: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind); virtual;
  published
    property ThemeKind: TThemeKind read FThemeKind write SetThemeKind default tkDark;
  end;

implementation

uses
  SysUtils, Types, LcaUiPaintProfile, LcaPaintPrimitives;

procedure TLcaThemedControl.SetThemeKind(AValue: TThemeKind);
begin
  if FThemeKind = AValue then Exit;
  FThemeKind := AValue;
  ApplyTheme(FThemeKind);
end;

constructor TLcaThemedControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  FThemeKind := tkDark;
  Width := 120;
  Height := 80;
end;

function TLcaThemedControl.EffectivePalette: TThemePalette;
begin
  Result := ThemePalette(EffectiveControlTheme(Self, FThemeKind));
end;

procedure TLcaThemedControl.DoApplyThemeColors(const P: TThemePalette);
begin
  Color := P.CardBg;
  Font.Color := P.Text;
end;

procedure TLcaThemedControl.PaintThemedClient(const ARect: TRect; const P: TThemePalette);
begin
  FillRoundRect(Canvas, ARect, 4, P.CardBg);
  StrokeRoundRect(Canvas, ARect, 4, BlendRgb(P.Border, P.CardBg, 0.45), 1);
end;

procedure TLcaThemedControl.Loaded;
begin
  inherited Loaded;
  ApplyTheme(FThemeKind);
end;

procedure TLcaThemedControl.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FThemeKind := ATheme;
  P := ThemePalette(EffectiveControlTheme(Self, ATheme));
  DoApplyThemeColors(P);
  Invalidate;
end;

procedure TLcaThemedControl.Paint;
var
  P: TThemePalette;
  R: TRect;
  T0, Elapsed: QWord;
begin
  T0 := GetTickCount64;
  P := EffectivePalette;
  R := ClientRect;
  PaintThemedClient(R, P);

  if LcaInDesignContext(Self) and (csDesigning in ComponentState) then begin
    Canvas.Font.Color := P.TextMuted;
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(4, 4, ClassName);
  end;
  Elapsed := GetTickCount64 - T0;
  LcaUiProfileRecordThemedPaint(Elapsed);
end;

procedure TLcaThemedControl.ChangeScale(M, D: Integer);
begin
  inherited ChangeScale(M, D);
end;

end.
