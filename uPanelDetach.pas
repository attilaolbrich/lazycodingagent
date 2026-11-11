unit uPanelDetach;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, ComCtrls, Types, uAppTypes, uWorkspaceState, LcaTheme;

type
  TPanelFloatEvent = procedure(Sender: TObject; AId: TPanelId; AFloating: Boolean) of object;

  TPanelDetachManager = class
  private
    FOwner: TComponent;
    FMainForm: TForm;
    FState: TWorkspaceState;
    FDockHost: array[TPanelId] of TPanel;
    FContent: array[TPanelId] of TWinControl;
    FFloatForm: array[TPanelId] of TForm;
    FBound: array[TPanelId] of Boolean;
    FFloatFormThemed: array[TPanelId] of Boolean;
    FFloatCloseAttachEnabled: array[TPanelId] of Boolean;
    FEnableCloseTimer: TTimer;
    FEnableClosePendingId: TPanelId;
    FInToggle: Boolean;
    FOnPanelFloat: TPanelFloatEvent;
    procedure FloatFormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FloatFormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FloatFormBoundsChanged(Sender: TObject);
    function IsContentOnFloat(AId: TPanelId): Boolean;
    procedure EnsureFloatForm(AId: TPanelId);
    procedure DetachPanel(AId: TPanelId);
    procedure ReparentContent(AContent: TWinControl; ANewParent: TWinControl);
    procedure EnforcePageControlsInTree(ARoot: TWinControl);
    procedure ClampFloatBoundsToWorkArea(var ALeft, ATop, AWidth, AHeight: Integer);
    function DefaultFloatBounds(AId: TPanelId; out ALeft, ATop, AWidth, AHeight: Integer): Boolean;
    procedure NotifyPanelFloat(AId: TPanelId; AFloating: Boolean);
    procedure EnableCloseTimerExpired(Sender: TObject);
    procedure QueueEnableFloatCloseAttach(AId: TPanelId);
  public
    procedure AttachPanel(AId: TPanelId);
    constructor Create(AOwner: TComponent; AMainForm: TForm; AState: TWorkspaceState);
    destructor Destroy; override;
    procedure Bind(AId: TPanelId; ADockHost: TPanel; AContent: TWinControl);
    procedure ToggleDetach(AId: TPanelId);
    procedure ApplyLayout;
    procedure ApplyThemes(ATheme: TThemeKind);
    procedure RaiseFloatingForms;
    procedure AttachAll;
    procedure FinalizeOnClose;
    property OnPanelFloat: TPanelFloatEvent read FOnPanelFloat write FOnPanelFloat;
  end;

implementation

uses
  Math;

const
  FLOAT_MIN_WIDTH = 280;
  FLOAT_MIN_HEIGHT = 200;

procedure TPanelDetachManager.NotifyPanelFloat(AId: TPanelId; AFloating: Boolean);
begin
  if Assigned(FOnPanelFloat) then
    FOnPanelFloat(Self, AId, AFloating);
end;

procedure TPanelDetachManager.EnableCloseTimerExpired(Sender: TObject);
begin
  if Assigned(FEnableCloseTimer) then
    FEnableCloseTimer.Enabled := False;
  FFloatCloseAttachEnabled[FEnableClosePendingId] := True;
end;

procedure TPanelDetachManager.QueueEnableFloatCloseAttach(AId: TPanelId);
begin
  FEnableClosePendingId := AId;
  if not Assigned(FEnableCloseTimer) then begin
    FFloatCloseAttachEnabled[AId] := True;
    Exit;
  end;
  FEnableCloseTimer.Enabled := False;
  FEnableCloseTimer.Enabled := True;
end;

procedure TPanelDetachManager.EnforcePageControlsInTree(ARoot: TWinControl);
var
  I: Integer;
  Child: TWinControl;
begin
  if not Assigned(ARoot) then Exit;
  if ARoot is TPageControl then
    EnforcePageControlHiddenTabs(TPageControl(ARoot));
  for I := 0 to ARoot.ControlCount - 1 do
    if ARoot.Controls[I] is TWinControl then begin
      Child := TWinControl(ARoot.Controls[I]);
      EnforcePageControlsInTree(Child);
    end;
end;

procedure TPanelDetachManager.ClampFloatBoundsToWorkArea(var ALeft, ATop, AWidth,
  AHeight: Integer);
var
  Mon: TMonitor;
  WA: TRect;
  R: TRect;
begin
  if AWidth < FLOAT_MIN_WIDTH then
    AWidth := FLOAT_MIN_WIDTH;
  if AHeight < FLOAT_MIN_HEIGHT then
    AHeight := FLOAT_MIN_HEIGHT;
  R := Rect(ALeft, ATop, ALeft + AWidth, ATop + AHeight);
  Mon := Screen.MonitorFromRect(R);
  if Mon = nil then
    Mon := Screen.PrimaryMonitor;
  if Mon = nil then Exit;
  WA := Mon.WorkareaRect;
  if ALeft < WA.Left then
    ALeft := WA.Left;
  if ATop < WA.Top then
    ATop := WA.Top;
  if ALeft + AWidth > WA.Right then
    ALeft := Max(WA.Left, WA.Right - AWidth);
  if ATop + AHeight > WA.Bottom then
    ATop := Max(WA.Top, WA.Bottom - AHeight);
end;

procedure TPanelDetachManager.ReparentContent(AContent: TWinControl; ANewParent: TWinControl);
begin
  if not Assigned(AContent) or not Assigned(ANewParent) then Exit;
  AContent.Visible := True;
  AContent.DisableAlign;
  try
    if AContent.Parent <> ANewParent then begin
      AContent.Parent := nil;
      AContent.Parent := ANewParent;
    end;
    AContent.Align := alClient;
  finally
    AContent.EnableAlign;
  end;
  ANewParent.Realign;
  AContent.Update;
end;

procedure TPanelDetachManager.Bind(AId: TPanelId; ADockHost: TPanel; AContent: TWinControl);
begin
  FDockHost[AId] := ADockHost;
  FContent[AId] := AContent;
  FBound[AId] := Assigned(ADockHost) and Assigned(AContent);
end;

constructor TPanelDetachManager.Create(AOwner: TComponent; AMainForm: TForm;
  AState: TWorkspaceState);
var
  P: TPanelId;
begin
  inherited Create;
  FOwner := AOwner;
  FMainForm := AMainForm;
  FState := AState;
  for P := Low(TPanelId) to High(TPanelId) do begin
    FBound[P] := False;
    FFloatFormThemed[P] := False;
    FFloatCloseAttachEnabled[P] := True;
  end;
  FEnableClosePendingId := Low(TPanelId);
  if Assigned(AOwner) then begin
    FEnableCloseTimer := TTimer.Create(AOwner);
    FEnableCloseTimer.Interval := 500;
    FEnableCloseTimer.Enabled := False;
    FEnableCloseTimer.OnTimer := @EnableCloseTimerExpired;
  end else
    FEnableCloseTimer := nil;
end;

destructor TPanelDetachManager.Destroy;
var
  P: TPanelId;
begin
  FreeAndNil(FEnableCloseTimer);
  for P := Low(TPanelId) to High(TPanelId) do
    FreeAndNil(FFloatForm[P]);
  inherited Destroy;
end;

function TPanelDetachManager.DefaultFloatBounds(AId: TPanelId; out ALeft, ATop, AWidth,
  AHeight: Integer): Boolean;
var
  DockW, DockH: Integer;
begin
  Result := False;
  if not FBound[AId] then Exit;
  DockW := FDockHost[AId].Width;
  DockH := FDockHost[AId].Height;
  if AId = piTerminal then begin
    AWidth := 960;
    AHeight := DockH;
    if AHeight < 360 then
      AHeight := 360;
    if DockW >= FMainForm.Width - 48 then begin
      if AHeight < 360 then
        AHeight := 360;
    end;
  end else begin
    AWidth := DockW;
    AHeight := DockH;
    if AWidth < FLOAT_MIN_WIDTH then AWidth := 420;
    if AHeight < FLOAT_MIN_HEIGHT then AHeight := 480;
  end;
  ALeft := FMainForm.Left + FMainForm.Width + 12;
  ATop := FMainForm.Top;
  if ALeft + AWidth > Screen.WorkareaRect.Right then
    ALeft := Max(Screen.WorkareaRect.Left, FMainForm.Left + 24);
  Result := True;
end;

procedure TPanelDetachManager.EnsureFloatForm(AId: TPanelId);
var
  FF: TForm;
begin
  if Assigned(FFloatForm[AId]) then begin
    FFloatForm[AId].OnCloseQuery := @FloatFormCloseQuery;
    Exit;
  end;
  if Assigned(Application) then
    FF := TForm.CreateNew(Application)
  else
    FF := TForm.CreateNew(nil);
  FF.Caption := PanelCaption(AId);
  FF.Position := poDesigned;
  FF.FormStyle := fsNormal;
  FF.ShowInTaskBar := stDefault;
  FF.Tag := Ord(AId);
  FF.OnClose := @FloatFormClose;
  FF.OnCloseQuery := @FloatFormCloseQuery;
  FF.OnResize := @FloatFormBoundsChanged;
  FFloatForm[AId] := FF;
  FFloatFormThemed[AId] := False;
end;

procedure TPanelDetachManager.FloatFormBoundsChanged(Sender: TObject);
var
  FF: TForm;
  Id: TPanelId;
begin
  if not (Sender is TForm) then Exit;
  FF := TForm(Sender);
  Id := TPanelId(FF.Tag);
  FState.SetPanelBounds(Id, FF.Left, FF.Top, FF.Width, FF.Height);
end;

function TPanelDetachManager.IsContentOnFloat(AId: TPanelId): Boolean;
begin
  Result := FBound[AId] and Assigned(FContent[AId]) and Assigned(FFloatForm[AId]) and
    (FContent[AId].Parent = FFloatForm[AId]);
end;

procedure TPanelDetachManager.FloatFormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  Id: TPanelId;
begin
  CanClose := True;
  if not (Sender is TForm) then Exit;
  Id := TPanelId(TForm(Sender).Tag);
  CanClose := FFloatCloseAttachEnabled[Id];
end;

procedure TPanelDetachManager.FloatFormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  Id: TPanelId;
begin
  CloseAction := caHide;
  if not (Sender is TForm) then Exit;
  Id := TPanelId(TForm(Sender).Tag);
  if not FFloatCloseAttachEnabled[Id] then Exit;
  AttachPanel(Id);
end;

procedure TPanelDetachManager.DetachPanel(AId: TPanelId);
var
  L, T, W, H: Integer;
  FF: TForm;
begin
  if not FBound[AId] then Exit;
  if not FState.IsPanelVisible(AId) then
    FState.SetPanelVisible(AId, True);

  EnsureFloatForm(AId);
  FF := FFloatForm[AId];
  FFloatCloseAttachEnabled[AId] := False;
  try
    if not FFloatFormThemed[AId] then begin
      ApplyThemedForm(FF, FState.Theme);
      FFloatFormThemed[AId] := True;
    end;

    if not FState.GetPanelBounds(AId, L, T, W, H) or (W < 200) or (H < 120) then
      DefaultFloatBounds(AId, L, T, W, H);
    ClampFloatBoundsToWorkArea(L, T, W, H);
    FF.SetBounds(L, T, W, H);

    if not FState.IsPanelFloating(AId) then begin
      FState.SetPanelFloating(AId, True);
      NotifyPanelFloat(AId, True);
    end;

    ReparentContent(FContent[AId], FF);
    EnforcePageControlsInTree(FContent[AId]);

    if not FF.HandleAllocated then
      FF.HandleNeeded;
    ApplyLayout;
    if not FF.Visible then
      FF.Show;
    FF.BringToFront;
    ApplyLayout;
  finally
    QueueEnableFloatCloseAttach(AId);
  end;
end;

procedure TPanelDetachManager.AttachPanel(AId: TPanelId);
var
  FF: TForm;
  WasFloating: Boolean;
begin
  if not FBound[AId] then Exit;
  if not Assigned(FMainForm) or (csDestroying in FMainForm.ComponentState) then Exit;
  WasFloating := FState.IsPanelFloating(AId);
  if not WasFloating then Exit;

  FF := FFloatForm[AId];
  FFloatCloseAttachEnabled[AId] := False;
  try
    if Assigned(FF) then
      FF.Hide;

    ReparentContent(FContent[AId], FDockHost[AId]);
    EnforcePageControlsInTree(FContent[AId]);

    FState.SetPanelFloating(AId, False);
    if WasFloating then
      NotifyPanelFloat(AId, False);
    ApplyLayout;
  finally
    QueueEnableFloatCloseAttach(AId);
  end;
end;

procedure TPanelDetachManager.ToggleDetach(AId: TPanelId);
begin
  if FInToggle then Exit;
  FInToggle := True;
  try
    if FState.IsPanelFloating(AId) then
      AttachPanel(AId)
    else
      DetachPanel(AId);
  finally
    FInToggle := False;
  end;
end;

procedure TPanelDetachManager.ApplyLayout;
var
  P: TPanelId;
  FF: TForm;
begin
  for P := Low(TPanelId) to High(TPanelId) do begin
    if not FBound[P] then Continue;

    if (FState.IsPanelVisible(P) and FState.IsPanelFloating(P)) or IsContentOnFloat(P) then begin
      FDockHost[P].Visible := False;
      FF := FFloatForm[P];
      if Assigned(FF) then
        FF.Visible := True;
    end else begin
      FF := FFloatForm[P];
      if Assigned(FF) and not IsContentOnFloat(P) then
        FF.Visible := False;
    end;
  end;
end;

procedure TPanelDetachManager.ApplyThemes(ATheme: TThemeKind);
var
  P: TPanelId;
  FF: TForm;
begin
  for P := Low(TPanelId) to High(TPanelId) do begin
    FF := FFloatForm[P];
    if not Assigned(FF) then Continue;
    ApplyThemedForm(FF, ATheme);
    FFloatFormThemed[P] := True;
  end;
end;

procedure TPanelDetachManager.RaiseFloatingForms;
var
  P: TPanelId;
begin
  for P := Low(TPanelId) to High(TPanelId) do begin
    if not FBound[P] then Continue;
    if FState.IsPanelVisible(P) and FState.IsPanelFloating(P) then
      DetachPanel(P);
  end;
end;

procedure TPanelDetachManager.AttachAll;
var
  P: TPanelId;
begin
  if not Assigned(FMainForm) or (csDestroying in FMainForm.ComponentState) then Exit;
  for P := Low(TPanelId) to High(TPanelId) do
    if FState.IsPanelFloating(P) then
      AttachPanel(P);
end;

procedure TPanelDetachManager.FinalizeOnClose;
var
  P: TPanelId;
begin
  AttachAll;
  for P := Low(TPanelId) to High(TPanelId) do
    FreeAndNil(FFloatForm[P]);
end;

end.
