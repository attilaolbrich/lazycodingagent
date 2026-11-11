unit LcaSurfacePanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, ExtCtrls, Graphics, LcaTheme;

type
  TLcaSurfacePanel = class(TPanel)
  private
    FThemeKind: TThemeKind;
    FShowAccentBorder: Boolean;
    procedure SetThemeKind(AValue: TThemeKind);
    procedure SetShowAccentBorder(AValue: Boolean);
  protected
    procedure Loaded; override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
  published
    property ThemeKind: TThemeKind read FThemeKind write SetThemeKind default tkDark;
    property ShowAccentBorder: Boolean read FShowAccentBorder write SetShowAccentBorder default False;
  end;

implementation

uses
  LcaPaintPrimitives;

procedure TLcaSurfacePanel.SetThemeKind(AValue: TThemeKind);
begin
  if FThemeKind = AValue then Exit;
  FThemeKind := AValue;
  ApplyTheme(FThemeKind);
end;

procedure TLcaSurfacePanel.SetShowAccentBorder(AValue: Boolean);
begin
  if FShowAccentBorder = AValue then Exit;
  FShowAccentBorder := AValue;
  Invalidate;
end;

constructor TLcaSurfacePanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FThemeKind := tkDark;
  FShowAccentBorder := False;
  DoubleBuffered := True;
end;

procedure TLcaSurfacePanel.Loaded;
begin
  inherited Loaded;
  ApplyTheme(FThemeKind);
end;

procedure TLcaSurfacePanel.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FThemeKind := ATheme;
  P := ThemePalette(EffectiveControlTheme(Self, ATheme));
  Color := P.CardBg;
  Font.Color := P.Text;
  Invalidate;
end;

procedure TLcaSurfacePanel.Paint;
var
  P: TThemePalette;
  R: TRect;
begin
  inherited Paint;
  P := ThemePalette(EffectiveControlTheme(Self, FThemeKind));
  R := ClientRect;
  StrokeRoundRect(Canvas, R, 4, BlendRgb(P.Border, P.CardBg, 0.45), 1);
  if FShowAccentBorder then begin
    R := ClientStrokeRect(R);
    Canvas.Pen.Color := P.Accent;
    Canvas.Pen.Width := 1;
    Canvas.MoveTo(R.Left, R.Bottom);
    Canvas.LineTo(R.Right, R.Bottom);
  end;
end;

end.
