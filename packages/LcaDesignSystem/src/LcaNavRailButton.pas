unit LcaNavRailButton;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Buttons, ExtCtrls, Graphics, Forms, LCLType, LcaTheme;

type
  TLcaNavRailButton = class(TSpeedButton)
  private
    FThemeKind: TThemeKind;
    FNavCaption: string;
    FActive: Boolean;
    procedure SetThemeKind(AValue: TThemeKind);
    procedure SetNavCaption(const AValue: string);
    procedure SetActive(AValue: Boolean);
    function IsOnDesignerSurface: Boolean;
    function DesignerBackgroundColor: TColor;
    function DesignerForegroundColor: TColor;
    procedure PaintDesignerSurface;
    procedure PaintThemedSurface;
    procedure PaintButtonContent(const AR: TRect; AFg: TColor);
    procedure SyncParentRailHostForDesigner;
  protected
    procedure Loaded; override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
  published
    property ThemeKind: TThemeKind read FThemeKind write SetThemeKind default tkDark;
    property NavCaption: string read FNavCaption write SetNavCaption;
    property Active: Boolean read FActive write SetActive default False;
  end;

implementation

uses
  SysUtils, Types;

procedure TLcaNavRailButton.SetThemeKind(AValue: TThemeKind);
begin
  if FThemeKind = AValue then Exit;
  FThemeKind := AValue;
  ApplyTheme(FThemeKind);
end;

procedure TLcaNavRailButton.SetNavCaption(const AValue: string);
begin
  if FNavCaption = AValue then Exit;
  FNavCaption := AValue;
  if FNavCaption <> '' then
    Hint := FNavCaption;
  Invalidate;
end;

procedure TLcaNavRailButton.SetActive(AValue: Boolean);
begin
  if FActive = AValue then Exit;
  FActive := AValue;
  if IsOnDesignerSurface then
    Invalidate
  else
    ApplyTheme(FThemeKind);
end;

constructor TLcaNavRailButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  Flat := True;
  AllowAllUp := True;
  FThemeKind := tkDark;
  FActive := False;
  Layout := blGlyphTop;
  Spacing := 4;
end;

function TLcaNavRailButton.IsOnDesignerSurface: Boolean;
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

function TLcaNavRailButton.DesignerBackgroundColor: TColor;
begin
  if ParentColor and Assigned(Parent) then
    Result := Parent.Color
  else
    Result := Color;
  if Result = clDefault then
    Result := clBtnFace;
end;

function TLcaNavRailButton.DesignerForegroundColor: TColor;
begin
  Result := Font.Color;
  if Result = clDefault then
    Result := clWindowText;
end;

procedure TLcaNavRailButton.SyncParentRailHostForDesigner;
begin
  if not IsOnDesignerSurface then Exit;
  if not (Parent is TPanel) then Exit;
  if TPanel(Parent).Color = DesignerBackgroundColor then Exit;
  TPanel(Parent).Color := DesignerBackgroundColor;
end;

procedure TLcaNavRailButton.Loaded;
begin
  inherited Loaded;
  if IsOnDesignerSurface then begin
    SyncParentRailHostForDesigner;
    Invalidate;
    Exit;
  end;
  ApplyTheme(FThemeKind);
end;

procedure TLcaNavRailButton.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FThemeKind := ATheme;
  if IsOnDesignerSurface then begin
    Invalidate;
    Exit;
  end;
  P := ThemePalette(ATheme);
  Color := P.RailBg;
  if FActive then
    Font.Color := P.Accent
  else
    Font.Color := P.TextMuted;
  Invalidate;
end;

procedure TLcaNavRailButton.PaintButtonContent(const AR: TRect; AFg: TColor);
var
  CaptionStr: string;
  GlyphH, TextH, TotalH, Y, TextX: Integer;
begin
  Canvas.Font := Font;
  Canvas.Font.Color := AFg;
  Canvas.Brush.Style := bsClear;

  CaptionStr := Caption;
  if (Glyph <> nil) and (Glyph.Width > 0) and (Glyph.Height > 0) then begin
    GlyphH := Glyph.Height;
    TextH := 0;
    if CaptionStr <> '' then
      TextH := Canvas.TextHeight(CaptionStr) + Spacing;
    TotalH := GlyphH + TextH;
    Y := AR.Top + (AR.Height - TotalH) div 2;
    Canvas.Draw(AR.Left + (AR.Width - Glyph.Width) div 2, Y, Glyph);
    if CaptionStr <> '' then begin
      Y := Y + GlyphH + Spacing;
      TextX := AR.Left + (AR.Width - Canvas.TextWidth(CaptionStr)) div 2;
      Canvas.TextOut(TextX, Y, CaptionStr);
    end;
  end else if CaptionStr <> '' then begin
    TextX := AR.Left + (AR.Width - Canvas.TextWidth(CaptionStr)) div 2;
    Y := AR.Top + (AR.Height - Canvas.TextHeight(CaptionStr)) div 2;
    Canvas.TextOut(TextX, Y, CaptionStr);
  end;
end;

procedure TLcaNavRailButton.PaintDesignerSurface;
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

procedure TLcaNavRailButton.PaintThemedSurface;
var
  P: TThemePalette;
  R: TRect;
  TextColor: TColor;
begin
  P := ThemePalette(FThemeKind);
  R := ClientRect;
  PaintThemedNavRailCell(Canvas, R, P, FActive, False, False);

  if FActive then
    TextColor := P.Accent
  else
    TextColor := P.TextMuted;

  PaintButtonContent(R, TextColor);
end;

procedure TLcaNavRailButton.Paint;
begin
  if IsOnDesignerSurface then
    PaintDesignerSurface
  else
    PaintThemedSurface;
end;

end.
