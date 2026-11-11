unit LcaThemedGroupBox;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Graphics, Types, LcaThemedControl, LcaTheme;

const
  ThemedGroupBoxCaptionBandBase = 20;
  ThemedGroupBoxCaptionInsetBase = 9;
  ThemedGroupBoxCaptionGapBase = 4;

type
  TLcaThemedGroupBox = class(TLcaThemedControl)
  protected
    procedure DoApplyThemeColors(const P: TThemePalette); override;
    procedure PaintThemedClient(const ARect: TRect; const P: TThemePalette); override;
    procedure TextChanged; override;
  public
    constructor Create(AOwner: TComponent); override;
    function CaptionBandHeight: Integer;
    class function DefaultCaptionBandHeight(AControl: TControl): Integer;
  published
    property Caption;
    property Align;
    property Anchors;
    property Enabled;
    property Left;
    property Top;
    property Width;
    property Height;
    property Visible;
    property TabOrder;
    property TabStop;
    property ThemeKind;
  end;

implementation

uses
  Math, SysUtils;

constructor TLcaThemedGroupBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 280;
  Height := 120;
  Caption := 'Group';
end;

class function TLcaThemedGroupBox.DefaultCaptionBandHeight(AControl: TControl): Integer;
begin
  Result := ScaledLayoutMetric(AControl, ThemedGroupBoxCaptionBandBase);
end;

function TLcaThemedGroupBox.CaptionBandHeight: Integer;
begin
  Result := DefaultCaptionBandHeight(Self);
end;

procedure TLcaThemedGroupBox.DoApplyThemeColors(const P: TThemePalette);
begin
  Color := P.Surface;
  Font.Name := 'Segoe UI';
  Font.Color := P.Text;
end;

procedure TLcaThemedGroupBox.TextChanged;
begin
  inherited TextChanged;
  Invalidate;
end;

procedure TLcaThemedGroupBox.PaintThemedClient(const ARect: TRect; const P: TThemePalette);
var
  CapH, Inset, GapPad, TextW, TextH, CapMidY, CapTop, CapEndX: Integer;
  CapText: string;
  BorderColor, TextColor: TColor;
  CapBg: TRect;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ARect);

  CapH := CaptionBandHeight;
  Inset := ScaledLayoutMetric(Self, ThemedGroupBoxCaptionInsetBase);
  GapPad := ScaledLayoutMetric(Self, ThemedGroupBoxCaptionGapBase);
  CapMidY := ARect.Top + (CapH div 2);
  BorderColor := P.Border;
  Canvas.Pen.Color := BorderColor;
  Canvas.Pen.Width := 1;

  CapText := Caption;
  if CapText <> '' then begin
    Canvas.Font.Assign(Font);
    if Enabled then
      TextColor := P.Text
    else
      TextColor := P.TextMuted;
    Canvas.Font.Color := TextColor;
    TextW := Canvas.TextWidth(CapText);
    TextH := Canvas.TextHeight(CapText);
    CapTop := ARect.Top + Max(0, (CapH - TextH) div 2);
    CapEndX := ARect.Left + Inset + TextW + GapPad * 2;
    CapBg := Rect(ARect.Left + Inset, CapTop, CapEndX, CapTop + TextH);
    Canvas.Brush.Color := Color;
    Canvas.FillRect(CapBg);
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(ARect.Left + Inset + GapPad, CapTop, CapText);

    Canvas.MoveTo(ARect.Left, CapMidY);
    Canvas.LineTo(ARect.Left + Inset - GapPad, CapMidY);
    Canvas.MoveTo(CapEndX, CapMidY);
    Canvas.LineTo(ARect.Right - 1, CapMidY);
  end else begin
    Canvas.MoveTo(ARect.Left, CapMidY);
    Canvas.LineTo(ARect.Right - 1, CapMidY);
  end;

  Canvas.MoveTo(ARect.Right - 1, CapMidY);
  Canvas.LineTo(ARect.Right - 1, ARect.Bottom - 1);
  Canvas.LineTo(ARect.Left, ARect.Bottom - 1);
  Canvas.LineTo(ARect.Left, CapMidY);
end;

end.
