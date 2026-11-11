unit LcaPaintPrimitives;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Graphics, Types, LCLType;

function BlendRgb(AColor1, AColor2: TColor; ARatio: Double): TColor;
function LightenColor(AColor: TColor; AAmount: Byte): TColor;
function DarkenColor(AColor: TColor; AAmount: Byte): TColor;

function ClientStrokeRect(const ARect: TRect): TRect;
function ClampRoundRadius(ARect: TRect; ARadius: Integer): Integer;

procedure FillRoundRect(ACanvas: TCanvas; const ARect: TRect; ARadius: Integer; AColor: TColor);
procedure StrokeRoundRect(ACanvas: TCanvas; const ARect: TRect; ARadius: Integer;
  AColor: TColor; APenWidth: Integer = 1);
procedure PaintFocusRing(ACanvas: TCanvas; const ARect: TRect; ARadius: Integer; AColor: TColor);
procedure PaintSubtleTopHighlight(ACanvas: TCanvas; const ARect: TRect; ARadius: Integer;
  AHighlightColor: TColor);

procedure PaintSelectionPill(ACanvas: TCanvas; const ARect: TRect; AFillColor: TColor;
  AHorizInset, AVertInset, ARadius: Integer);

procedure PaintThemedScrollbarTrack(ACanvas: TCanvas; const ARect: TRect; ATrackColor: TColor);
procedure PaintThemedScrollbarThumb(ACanvas: TCanvas; const ARect: TRect; AThumbColor: TColor;
  AHover: Boolean);

procedure ApplyThemedUiFont(ACanvas: TCanvas; AMetricsControl: TControl; ASize: Integer;
  AStyle: TFontStyles = []);

implementation

uses
  Math, LcaTheme;

function ColorChannel(AValue: Integer; AAmount: Byte; AAdd: Boolean): Byte;
var
  V: Integer;
begin
  V := AValue;
  if AAdd then
    V := V + AAmount
  else
    V := V - AAmount;
  if V < 0 then V := 0;
  if V > 255 then V := 255;
  Result := Byte(V);
end;

function BlendRgb(AColor1, AColor2: TColor; ARatio: Double): TColor;
var
  T: Double;
  R1, G1, B1, R2, G2, B2: Byte;
begin
  if ARatio <= 0 then Exit(AColor1);
  if ARatio >= 1 then Exit(AColor2);
  T := ARatio;
  R1 := Red(AColor1); G1 := Green(AColor1); B1 := Blue(AColor1);
  R2 := Red(AColor2); G2 := Green(AColor2); B2 := Blue(AColor2);
  Result := RGBToColor(
    Round(R1 + (R2 - R1) * T),
    Round(G1 + (G2 - G1) * T),
    Round(B1 + (B2 - B1) * T));
end;

function LightenColor(AColor: TColor; AAmount: Byte): TColor;
begin
  Result := RGBToColor(
    ColorChannel(Red(AColor), AAmount, True),
    ColorChannel(Green(AColor), AAmount, True),
    ColorChannel(Blue(AColor), AAmount, True));
end;

function DarkenColor(AColor: TColor; AAmount: Byte): TColor;
begin
  Result := RGBToColor(
    ColorChannel(Red(AColor), AAmount, False),
    ColorChannel(Green(AColor), AAmount, False),
    ColorChannel(Blue(AColor), AAmount, False));
end;

function ClientStrokeRect(const ARect: TRect): TRect;
begin
  Result := ARect;
  Dec(Result.Right);
  Dec(Result.Bottom);
end;

function ClampRoundRadius(ARect: TRect; ARadius: Integer): Integer;
var
  MaxR: Integer;
begin
  Result := ARadius;
  if Result < 2 then Result := 2;
  MaxR := Min((ARect.Right - ARect.Left) div 2, (ARect.Bottom - ARect.Top) div 2);
  if MaxR < 2 then
    Result := 2
  else if Result > MaxR then
    Result := MaxR;
end;

procedure FillRoundRect(ACanvas: TCanvas; const ARect: TRect; ARadius: Integer; AColor: TColor);
var
  R: TRect;
  Rad: Integer;
begin
  R := ClientStrokeRect(ARect);
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit;
  Rad := ClampRoundRadius(R, ARadius);
  ACanvas.Brush.Color := AColor;
  ACanvas.Pen.Color := AColor;
  ACanvas.Pen.Width := 1;
  ACanvas.RoundRect(R.Left, R.Top, R.Right + 1, R.Bottom + 1, Rad, Rad);
end;

procedure StrokeRoundRect(ACanvas: TCanvas; const ARect: TRect; ARadius: Integer;
  AColor: TColor; APenWidth: Integer);
var
  R: TRect;
  Rad: Integer;
begin
  R := ClientStrokeRect(ARect);
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit;
  Rad := ClampRoundRadius(R, ARadius);
  ACanvas.Brush.Style := bsClear;
  ACanvas.Pen.Color := AColor;
  ACanvas.Pen.Width := APenWidth;
  ACanvas.RoundRect(R.Left, R.Top, R.Right + 1, R.Bottom + 1, Rad, Rad);
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Pen.Width := 1;
end;

procedure PaintFocusRing(ACanvas: TCanvas; const ARect: TRect; ARadius: Integer; AColor: TColor);
var
  R: TRect;
  Rad: Integer;
begin
  R := ClientStrokeRect(ARect);
  if (R.Right - R.Left < 4) or (R.Bottom - R.Top < 4) then Exit;
  InflateRect(R, -1, -1);
  Rad := Max(2, ClampRoundRadius(R, ARadius - 1));
  StrokeRoundRect(ACanvas, R, Rad, AColor, 1);
end;

procedure PaintSubtleTopHighlight(ACanvas: TCanvas; const ARect: TRect; ARadius: Integer;
  AHighlightColor: TColor);
var
  R: TRect;
  Rad: Integer;
begin
  R := ClientStrokeRect(ARect);
  if R.Bottom - R.Top < 4 then Exit;
  Rad := ClampRoundRadius(R, ARadius);
  ACanvas.Pen.Color := AHighlightColor;
  ACanvas.Pen.Width := 1;
  ACanvas.MoveTo(R.Left + Rad, R.Top + 1);
  ACanvas.LineTo(R.Right - Rad, R.Top + 1);
  ACanvas.Pen.Width := 1;
end;

procedure PaintSelectionPill(ACanvas: TCanvas; const ARect: TRect; AFillColor: TColor;
  AHorizInset, AVertInset, ARadius: Integer);
var
  Pill: TRect;
begin
  Pill := ARect;
  Pill.Left := Pill.Left + AHorizInset;
  Pill.Right := Pill.Right - AHorizInset;
  Pill.Top := Pill.Top + AVertInset;
  Pill.Bottom := Pill.Bottom - AVertInset;
  if Pill.Bottom <= Pill.Top then
    Pill := ARect;
  FillRoundRect(ACanvas, Pill, ARadius, AFillColor);
end;

procedure PaintThemedScrollbarTrack(ACanvas: TCanvas; const ARect: TRect; ATrackColor: TColor);
begin
  ACanvas.Brush.Color := ATrackColor;
  ACanvas.FillRect(ARect);
end;

procedure PaintThemedScrollbarThumb(ACanvas: TCanvas; const ARect: TRect; AThumbColor: TColor;
  AHover: Boolean);
var
  Thumb: TRect;
  ThumbColor: TColor;
  Rad: Integer;
begin
  Thumb := ARect;
  if (Thumb.Right - Thumb.Left <= 4) or (Thumb.Bottom - Thumb.Top <= 4) then begin
    ACanvas.Brush.Color := AThumbColor;
    ACanvas.FillRect(Thumb);
    Exit;
  end;
  InflateRect(Thumb, -2, -2);
  if AHover then
    ThumbColor := LightenColor(AThumbColor, 18)
  else
    ThumbColor := AThumbColor;
  Rad := ClampRoundRadius(Thumb, 4);
  FillRoundRect(ACanvas, Thumb, Rad, ThumbColor);
end;

procedure ApplyThemedUiFont(ACanvas: TCanvas; AMetricsControl: TControl; ASize: Integer;
  AStyle: TFontStyles);
begin
  ACanvas.Font.Name := ThemedUiFontName;
  ACanvas.Font.Size := ASize;
  ACanvas.Font.Style := AStyle;
  if Assigned(AMetricsControl) then
    ACanvas.Font.PixelsPerInch := AMetricsControl.Font.PixelsPerInch;
end;

end.
