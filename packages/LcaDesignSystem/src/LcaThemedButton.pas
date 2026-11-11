unit LcaThemedButton;

{$mode objfpc}{$H+}

interface

uses
  Classes, StdCtrls, Controls, Forms, LMessages, LcaTheme;

type
  TLcaThemedButton = class(TButton)
  private
    FThemeKind: TThemeKind;
    FButtonRole: TThemedButtonRole;
    procedure SetThemeKind(AValue: TThemeKind);
    procedure SetButtonRole(AValue: TThemedButtonRole);
  protected
    procedure Loaded; override;
    procedure CreateWnd; override;
    procedure CMShowingChanged(var Message: TLMessage); message CM_SHOWINGCHANGED;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyTheme(ATheme: TThemeKind);
  published
    property ThemeKind: TThemeKind read FThemeKind write SetThemeKind default tkDark;
    property ButtonRole: TThemedButtonRole read FButtonRole write SetButtonRole default tbrCancel;
  end;

implementation

procedure TLcaThemedButton.SetThemeKind(AValue: TThemeKind);
begin
  if FThemeKind = AValue then Exit;
  FThemeKind := AValue;
  ApplyTheme(FThemeKind);
end;

procedure TLcaThemedButton.SetButtonRole(AValue: TThemedButtonRole);
begin
  if FButtonRole = AValue then Exit;
  FButtonRole := AValue;
  ApplyTheme(FThemeKind);
end;

constructor TLcaThemedButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FThemeKind := tkDark;
  FButtonRole := tbrCancel;
end;

procedure TLcaThemedButton.CreateWnd;
begin
  inherited CreateWnd;
  if LcaInDesignContext(Self) then Exit;
  StyleThemedButtonRole(Self, FThemeKind, FButtonRole);
end;

procedure TLcaThemedButton.Loaded;
begin
  inherited Loaded;
  if LcaInDesignContext(Self) then
    StyleThemedButtonRole(Self, EffectiveControlTheme(Self, FThemeKind), FButtonRole);
end;

procedure TLcaThemedButton.ApplyTheme(ATheme: TThemeKind);
begin
  FThemeKind := ATheme;
  if LcaInDesignContext(Self) then begin
    StyleThemedButtonRole(Self, EffectiveControlTheme(Self, ATheme), FButtonRole);
    Exit;
  end;
  if csLoading in ComponentState then Exit;
  if csReading in ComponentState then Exit;
  if not HandleAllocated then Exit;
  StyleThemedButtonRole(Self, FThemeKind, FButtonRole);
end;

procedure TLcaThemedButton.CMShowingChanged(var Message: TLMessage);
begin
  inherited CMShowingChanged(Message);
  if Showing and HandleAllocated and not (csDesigning in ComponentState) then
    StyleThemedButtonRole(Self, FThemeKind, FButtonRole);
end;

end.
