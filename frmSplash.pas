unit frmSplash;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, ComCtrls,
  uAppTypes, LcaTheme, LCLIntf;

const
  SplashPostLoadDelayMs = 1000;
  { Progress bar geometry at DesignTimePPI 96; matches frmSplash.lfm artwork slot. }
  SplashDesignW = 2048;
  SplashDesignH = 1228;
  SplashProgLeft = 202;
  SplashProgHeight = 22;
  SplashProgBottomMargin = 264;
  SplashProgRightMargin = 182;

type
  TSplashForm = class(TForm)
    pnlClient: TPanel;
    imgSplash: TImage;
    progLoad: TProgressBar;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FTheme: TThemeKind;
    FLoadPercent: Integer;
    procedure LoadSplashPictureIfNeeded;
    procedure FitClientToImage(AWidth, AHeight: Integer);
    procedure StyleProgressBar;
    procedure LayoutSplashChrome;
    procedure PushProgressToWidget(APercent: Integer);
  public
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure SetLoadProgress(APercent: Integer);
    procedure HoldVisible(AMs: QWord);
  end;

procedure SetActiveSplashForm(AForm: TSplashForm);
procedure ReportSplashLoadProgress(APercent: Integer);
function SplashImagePath: string;

implementation

{$R *.lfm}

var
  GActiveSplash: TSplashForm = nil;

procedure SetActiveSplashForm(AForm: TSplashForm);
begin
  GActiveSplash := AForm;
end;

procedure ReportSplashLoadProgress(APercent: Integer);
begin
  if Assigned(GActiveSplash) then
    GActiveSplash.SetLoadProgress(APercent);
end;

function SplashAssetsDirectory: string;
var
  Dir: string;
begin
  if Assigned(Application) then begin
    Dir := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'assets';
    if DirectoryExists(Dir) then
      Exit(Dir);
  end;
  Dir := IncludeTrailingPathDelimiter(GetCurrentDir) + 'assets';
  if DirectoryExists(Dir) then
    Exit(Dir);
  Dir := ExpandFileName(IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'assets');
  if DirectoryExists(Dir) then
    Exit(Dir);
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'assets';
end;

function SplashImagePath: string;
const
  Names: array[0..2] of string = ('splash.png', 'splash.jpg', 'splash.bmp');
var
  Base, Candidate: string;
  I: Integer;
begin
  Base := IncludeTrailingPathDelimiter(SplashAssetsDirectory);
  for I := Low(Names) to High(Names) do begin
    Candidate := Base + Names[I];
    if FileExists(Candidate) then
      Exit(Candidate);
  end;
  Result := Base + Names[0];
end;

procedure TSplashForm.FitClientToImage(AWidth, AHeight: Integer);
const
  Margin = 40;
var
  MaxW, MaxH, W, H: Integer;
begin
  MaxW := Screen.Width - Margin;
  MaxH := Screen.Height - Margin;
  if MaxW < 320 then MaxW := 320;
  if MaxH < 240 then MaxH := 240;
  W := AWidth;
  H := AHeight;
  if W > MaxW then begin
    H := Integer(Int64(H) * MaxW div W);
    W := MaxW;
  end;
  if H > MaxH then begin
    W := Integer(Int64(W) * MaxH div H);
    H := MaxH;
  end;
  ClientWidth := W;
  ClientHeight := H;
  Position := poScreenCenter;
  LayoutSplashChrome;
end;

procedure TSplashForm.LayoutSplashChrome;
var
  W, H, L, R, T, BarH, BarW: Integer;
begin
  if not Assigned(pnlClient) or not Assigned(progLoad) then Exit;
  W := pnlClient.ClientWidth;
  H := pnlClient.ClientHeight;
  if (W < 1) or (H < 1) then Exit;
  BarH := (SplashProgHeight * H + SplashDesignH div 2) div SplashDesignH;
  if BarH < 2 then BarH := 2;
  L := (SplashProgLeft * W + SplashDesignW div 2) div SplashDesignW;
  R := (SplashProgRightMargin * W + SplashDesignW div 2) div SplashDesignW;
  T := H - (SplashProgBottomMargin * H + SplashDesignH div 2) div SplashDesignH - BarH;
  if T < 0 then T := 0;
  BarW := W - L - R;
  if BarW < 8 then BarW := 8;
  progLoad.SetBounds(L, T, BarW, BarH);
end;

procedure TSplashForm.LoadSplashPictureIfNeeded;
var
  Path: string;
  P: TThemePalette;
begin
  if Assigned(imgSplash.Picture.Graphic) and (not imgSplash.Picture.Graphic.Empty) then begin
    FitClientToImage(imgSplash.Picture.Width, imgSplash.Picture.Height);
    Exit;
  end;
  Path := SplashImagePath;
  if not FileExists(Path) then Exit;
  imgSplash.Picture.LoadFromFile(Path);
  if not Assigned(imgSplash.Picture.Graphic) or imgSplash.Picture.Graphic.Empty then Exit;
  FitClientToImage(imgSplash.Picture.Width, imgSplash.Picture.Height);
  P := ThemePalette(FTheme);
  Color := P.Background;
  pnlClient.Color := P.Background;
end;

procedure TSplashForm.PushProgressToWidget(APercent: Integer);
var
  V: Integer;
begin
  if APercent < progLoad.Min then
    V := progLoad.Min
  else if APercent > progLoad.Max then
    V := progLoad.Max
  else
    V := APercent;
  progLoad.Position := V;
  if not progLoad.HandleAllocated then
    Exit;
  { LCL skips ApplyChanges when Position is unchanged; Qt/GTK may still show a stale fill. }
  if progLoad.Position = V then begin
    if V < progLoad.Max then
      progLoad.Position := V + 1
    else if V > progLoad.Min then
      progLoad.Position := V - 1
    else
      progLoad.Max := 101;
    progLoad.Max := 100;
  end;
  progLoad.Position := V;
  progLoad.Update;
end;

procedure TSplashForm.StyleProgressBar;
var
  P: TThemePalette;
begin
  P := ThemePalette(FTheme);
  progLoad.Min := 0;
  progLoad.Max := 100;
  progLoad.Smooth := True;
  {$IFDEF WINDOWS}
  progLoad.Color := P.SurfaceAlt;
  {$ENDIF}
  PushProgressToWidget(FLoadPercent);
end;

procedure TSplashForm.FormCreate(Sender: TObject);
begin
  Scaled := False;
  FTheme := tkDark;
  FLoadPercent := 0;
  imgSplash.Stretch := True;
  imgSplash.Proportional := True;
  imgSplash.Center := True;
  LoadSplashPictureIfNeeded;
  StyleProgressBar;
  LayoutSplashChrome;
end;

procedure TSplashForm.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.Background;
  Font.Color := P.Text;
  pnlClient.Color := P.Background;
  LoadSplashPictureIfNeeded;
  StyleProgressBar;
  LayoutSplashChrome;
  if (not Assigned(imgSplash.Picture.Graphic)) or imgSplash.Picture.Graphic.Empty then
    ApplyThemedForm(Self, ATheme);
  if HandleAllocated then
    ApplyPlatformChrome(Self, ATheme);
end;

procedure TSplashForm.SetLoadProgress(APercent: Integer);
begin
  FLoadPercent := APercent;
  PushProgressToWidget(APercent);
  if HandleAllocated then begin
    LayoutSplashChrome;
    Update;
  end;
  Application.ProcessMessages;
end;

procedure TSplashForm.HoldVisible(AMs: QWord);
var
  UntilTick: QWord;
begin
  if AMs = 0 then Exit;
  UntilTick := GetTickCount64 + AMs;
  while GetTickCount64 < UntilTick do
    Application.ProcessMessages;
end;

procedure TSplashForm.FormShow(Sender: TObject);
begin
  ApplyTheme(FTheme);
  ApplyFormPlatformThemes(Self, FTheme);
  LayoutSplashChrome;
  PushProgressToWidget(FLoadPercent);
end;

end.
