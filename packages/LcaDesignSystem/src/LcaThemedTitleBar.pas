unit LcaThemedTitleBar;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, ExtCtrls, Graphics, Forms, LCLType, Menus,
  LcaTheme, LcaThemedMainMenu, LcaThemedMenuBar, LcaThemedWindowButton, LcaFormChrome;

type
  TLcaThemedTitleBar = class(TPanel)
  private
    FTheme: TThemeKind;
    FMainMenu: TLcaThemedMainMenu;
    FShowLogo: Boolean;
    FMenuBar: TLcaThemedMenuBar;
    FImgLogo: TImage;
    FDragPanel: TPanel;
    FBtnMin: TLcaThemedWindowButton;
    FBtnMax: TLcaThemedWindowButton;
    FBtnClose: TLcaThemedWindowButton;
    FLayoutGuard: Boolean;
    procedure SetThemeKind(AValue: TThemeKind);
    procedure SetMainMenu(AValue: TLcaThemedMainMenu);
    procedure SetShowLogo(AValue: Boolean);
    procedure MainMenuChanged(Sender: TObject);
    procedure LayoutChildren;
    procedure DragPanelMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DragPanelDblClick(Sender: TObject);
    procedure TitleBarMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormWindowStateChanged(Sender: TObject);
    procedure SyncMaximizeButton;
    procedure BeginDragIfLeft(Sender: TObject; Button: TMouseButton; X, Y: Integer);
    function HostForm: TCustomForm;
    procedure LoadOwlPicture;
  protected
    procedure Loaded; override;
    procedure Resize; override;
    procedure ChangeScale(M, D: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure RefreshFromMainMenu;
    function MenuBar: TLcaThemedMenuBar;
  published
    property ThemeKind: TThemeKind read FTheme write SetThemeKind default tkDark;
    property MainMenu: TLcaThemedMainMenu read FMainMenu write SetMainMenu;
    property ShowLogo: Boolean read FShowLogo write SetShowLogo default True;
  end;

function ScaledTitleBarLogoWidth(AControl: TControl): Integer;

implementation

uses
  Math, LcaOwlIconRes;

const
  TitleBarLogoBaseWidth = 36;

function ScaledTitleBarLogoWidth(AControl: TControl): Integer;
begin
  Result := ScaledThemedTabMetric(AControl, TitleBarLogoBaseWidth);
end;

function TLcaThemedTitleBar.HostForm: TCustomForm;
begin
  Result := GetParentForm(Self);
end;

function TLcaThemedTitleBar.MenuBar: TLcaThemedMenuBar;
begin
  Result := FMenuBar;
end;

procedure TLcaThemedTitleBar.SetThemeKind(AValue: TThemeKind);
begin
  if FTheme = AValue then Exit;
  FTheme := AValue;
  ApplyTheme(FTheme);
end;

procedure TLcaThemedTitleBar.SetShowLogo(AValue: Boolean);
begin
  if FShowLogo = AValue then Exit;
  FShowLogo := AValue;
  if Assigned(FImgLogo) then
    FImgLogo.Visible := FShowLogo;
  LayoutChildren;
end;

procedure TLcaThemedTitleBar.SetMainMenu(AValue: TLcaThemedMainMenu);
begin
  if FMainMenu = AValue then Exit;
  if Assigned(FMainMenu) then
    FMainMenu.OnMenuChanged := nil;
  FMainMenu := AValue;
  if Assigned(FMainMenu) then
    FMainMenu.OnMenuChanged := @MainMenuChanged;
  if Assigned(FMenuBar) then
    FMenuBar.MainMenu := FMainMenu;
  RefreshFromMainMenu;
end;

procedure TLcaThemedTitleBar.MainMenuChanged(Sender: TObject);
begin
  RefreshFromMainMenu;
end;

procedure TLcaThemedTitleBar.LoadOwlPicture;
begin
  if not Assigned(FImgLogo) then Exit;
  if LcaShouldSkipOwlIconLoad(Self) then
  begin
    FImgLogo.Picture.Clear;
    Exit;
  end;
  if not TryLoadOwlIconInto(FImgLogo.Picture) then
    FImgLogo.Picture.Clear;
end;

constructor TLcaThemedTitleBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  ControlStyle := ControlStyle + [csOpaque];
  Align := alTop;
  DoubleBuffered := True;
  FTheme := tkDark;
  FShowLogo := True;
  Height := ScaledThemedMenuBarHeight(Self);

  FImgLogo := TImage.Create(Self);
  FImgLogo.Parent := Self;
  FImgLogo.Stretch := True;
  FImgLogo.Proportional := True;
  FImgLogo.Center := True;
  FImgLogo.OnMouseDown := @TitleBarMouseDown;
  FImgLogo.OnDblClick := @DragPanelDblClick;

  FMenuBar := TLcaThemedMenuBar.Create(Self);
  FMenuBar.Parent := Self;
  FMenuBar.Align := alNone;

  FDragPanel := TPanel.Create(Self);
  FDragPanel.Parent := Self;
  FDragPanel.Align := alNone;
  FDragPanel.BevelOuter := bvNone;
  FDragPanel.Caption := '';
  FDragPanel.OnMouseDown := @DragPanelMouseDown;
  FDragPanel.OnDblClick := @DragPanelDblClick;

  FBtnMin := TLcaThemedWindowButton.Create(Self);
  FBtnMin.Parent := Self;
  FBtnMin.Align := alNone;
  FBtnMin.ButtonRole := twbMinimize;

  FBtnMax := TLcaThemedWindowButton.Create(Self);
  FBtnMax.Parent := Self;
  FBtnMax.Align := alNone;
  FBtnMax.ButtonRole := twbMaximize;

  FBtnClose := TLcaThemedWindowButton.Create(Self);
  FBtnClose.Parent := Self;
  FBtnClose.Align := alNone;
  FBtnClose.ButtonRole := twbClose;

  OnMouseDown := @TitleBarMouseDown;
  OnDblClick := @DragPanelDblClick;
end;

destructor TLcaThemedTitleBar.Destroy;
var
  F: TCustomForm;
begin
  F := HostForm;
  if Assigned(F) and (F.OnWindowStateChange = @FormWindowStateChanged) then
    F.OnWindowStateChange := nil;
  inherited Destroy;
end;

procedure TLcaThemedTitleBar.Loaded;
var
  F: TCustomForm;
begin
  inherited Loaded;
  LoadOwlPicture;
  F := HostForm;
  if Assigned(F) then
    F.OnWindowStateChange := @FormWindowStateChanged;
  if Assigned(FMenuBar) and Assigned(FMainMenu) then
    FMenuBar.MainMenu := FMainMenu;
  ApplyTheme(FTheme);
  SyncMaximizeButton;
  LayoutChildren;
end;

procedure TLcaThemedTitleBar.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
  EffTheme: TThemeKind;
begin
  FTheme := ATheme;
  EffTheme := EffectiveControlTheme(Self, ATheme);
  P := ThemePalette(EffTheme);
  Color := P.TitleBarBg;
  Font.Color := P.Text;
  if Assigned(FDragPanel) then begin
    FDragPanel.Color := P.TitleBarBg;
    FDragPanel.Font.Color := P.Text;
  end;
  if Assigned(FMenuBar) then
    FMenuBar.ApplyTheme(ATheme);
  if Assigned(FBtnMin) then FBtnMin.ApplyTheme(ATheme);
  if Assigned(FBtnMax) then FBtnMax.ApplyTheme(ATheme);
  if Assigned(FBtnClose) then FBtnClose.ApplyTheme(ATheme);
  Invalidate;
end;

procedure TLcaThemedTitleBar.RefreshFromMainMenu;
begin
  if Assigned(FMenuBar) then
    FMenuBar.RefreshFromMainMenu;
  LayoutChildren;
end;

procedure TLcaThemedTitleBar.SyncMaximizeButton;
var
  F: TCustomForm;
begin
  if not Assigned(FBtnMax) then Exit;
  F := HostForm;
  if (F <> nil) and (F.WindowState = wsMaximized) then
    FBtnMax.ButtonRole := twbRestore
  else
    FBtnMax.ButtonRole := twbMaximize;
end;

procedure TLcaThemedTitleBar.FormWindowStateChanged(Sender: TObject);
begin
  SyncMaximizeButton;
end;

procedure TLcaThemedTitleBar.BeginDragIfLeft(Sender: TObject; Button: TMouseButton;
  X, Y: Integer);
var
  S: TPoint;
  F: TCustomForm;
begin
  if Button <> mbLeft then Exit;
  F := HostForm;
  if F = nil then Exit;
  if Sender is TControl then begin
    S := TControl(Sender).ClientToScreen(Types.Point(X, Y));
  end else
    S := Mouse.CursorPos;
  TLcaFormChrome.BeginMove(F, Button, S);
end;

procedure TLcaThemedTitleBar.TitleBarMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  BeginDragIfLeft(Sender, Button, X, Y);
end;

procedure TLcaThemedTitleBar.DragPanelMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  BeginDragIfLeft(Sender, Button, X, Y);
end;

procedure TLcaThemedTitleBar.DragPanelDblClick(Sender: TObject);
var
  F: TCustomForm;
begin
  F := HostForm;
  if F = nil then Exit;
  if F.WindowState = wsMaximized then
    F.WindowState := wsNormal
  else
    F.WindowState := wsMaximized;
  SyncMaximizeButton;
end;

procedure TLcaThemedTitleBar.LayoutChildren;
var
  H, LogoW, BtnW, TotalBtnW, MenuW, X: Integer;
begin
  if FLayoutGuard then Exit;
  if not HandleAllocated then Exit;
  FLayoutGuard := True;
  try
    H := ClientHeight;
    LogoW := 0;
    if FShowLogo then
      LogoW := H;
    BtnW := ScaledWindowChromeButtonWidth(Self);
    TotalBtnW := BtnW * 3;

    if Assigned(FImgLogo) then begin
      FImgLogo.Visible := FShowLogo;
      FImgLogo.SetBounds(0, 0, LogoW, H);
    end;

    MenuW := 0;
    if Assigned(FMenuBar) then begin
      MenuW := FMenuBar.PreferredWidth;
      if MenuW < 1 then
        MenuW := ScaledThemedTabMetric(Self, 40);
      FMenuBar.SetBounds(LogoW, 0, MenuW, H);
    end;

    X := ClientWidth - TotalBtnW;
    if Assigned(FBtnMin) then
      FBtnMin.SetBounds(X, 0, BtnW, H);
    Inc(X, BtnW);
    if Assigned(FBtnMax) then
      FBtnMax.SetBounds(X, 0, BtnW, H);
    Inc(X, BtnW);
    if Assigned(FBtnClose) then
      FBtnClose.SetBounds(X, 0, BtnW, H);

    if Assigned(FDragPanel) then
      FDragPanel.SetBounds(LogoW + MenuW, 0, Max(0, ClientWidth - LogoW - MenuW - TotalBtnW), H);
  finally
    FLayoutGuard := False;
  end;
end;

procedure TLcaThemedTitleBar.Resize;
begin
  inherited Resize;
  LayoutChildren;
end;

procedure TLcaThemedTitleBar.ChangeScale(M, D: Integer);
begin
  inherited ChangeScale(M, D);
  Height := ScaledThemedMenuBarHeight(Self);
  LayoutChildren;
end;

end.
