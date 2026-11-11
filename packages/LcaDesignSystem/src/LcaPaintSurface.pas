unit LcaPaintSurface;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Graphics, LcaThemedControl, LcaTheme;

type
  TLcaPaintSurface = class(TLcaThemedControl)
  private
    FShowAccentBorder: Boolean;
    procedure SetShowAccentBorder(AValue: Boolean);
  protected
    procedure PaintThemedClient(const ARect: TRect; const P: TThemePalette); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property ShowAccentBorder: Boolean read FShowAccentBorder write SetShowAccentBorder default False;
    property Align;
    property Anchors;
    property Left;
    property Top;
    property Width;
    property Height;
    property Visible;
    property TabOrder;
    property ThemeKind;
  end;

implementation

uses
  Types, LcaPaintPrimitives;

procedure TLcaPaintSurface.SetShowAccentBorder(AValue: Boolean);
begin
  if FShowAccentBorder = AValue then Exit;
  FShowAccentBorder := AValue;
  Invalidate;
end;

constructor TLcaPaintSurface.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FShowAccentBorder := False;
end;

procedure TLcaPaintSurface.PaintThemedClient(const ARect: TRect; const P: TThemePalette);
var
  R: TRect;
begin
  inherited PaintThemedClient(ARect, P);
  if not FShowAccentBorder then Exit;
  R := ARect;
  Dec(R.Right);
  Dec(R.Bottom);
  Canvas.Pen.Color := P.Accent;
  Canvas.Pen.Width := 1;
  Canvas.MoveTo(R.Left, R.Bottom);
  Canvas.LineTo(R.Right, R.Bottom);
end;

end.
