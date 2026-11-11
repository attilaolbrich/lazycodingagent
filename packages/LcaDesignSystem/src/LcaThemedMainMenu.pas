unit LcaThemedMainMenu;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Forms, Menus, LMessages, LCLType;

type
  TLcaThemedMainMenuChanged = procedure(Sender: TObject) of object;

  { Menu model for TLcaThemedMenuBar — do not assign to TCustomForm.Menu. }
  TLcaThemedMainMenu = class(TMainMenu)
  private
    FOwnerForm: TCustomForm;
    FPrevFormShortCut: TShortCutEvent;
    FOnMenuChanged: TLcaThemedMainMenuChanged;
    procedure HookOwnerFormShortCut;
    procedure UnhookOwnerFormShortCut;
    procedure FormShortCut(var Msg: TLMKey; var Handled: Boolean);
    function ResolveOwnerForm: TCustomForm;
  protected
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    destructor Destroy; override;
    procedure MenuStructureChanged;
  published
    property OnMenuChanged: TLcaThemedMainMenuChanged read FOnMenuChanged write FOnMenuChanged;
  end;

implementation

procedure TLcaThemedMainMenu.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opInsert) and (AComponent is TCustomForm) and
     (TCustomForm(AComponent).Menu = Self) then
    TCustomForm(AComponent).Menu := nil;
end;

function TLcaThemedMainMenu.ResolveOwnerForm: TCustomForm;
var
  C: TComponent;
begin
  Result := nil;
  C := Owner;
  while C <> nil do begin
    if C is TCustomForm then
      Exit(TCustomForm(C));
    C := C.Owner;
  end;
end;

procedure TLcaThemedMainMenu.HookOwnerFormShortCut;
var
  F: TCustomForm;
begin
  F := ResolveOwnerForm;
  if F = nil then Exit;
  if FOwnerForm = F then Exit;
  UnhookOwnerFormShortCut;
  FOwnerForm := F;
  FPrevFormShortCut := F.OnShortCut;
  F.OnShortCut := @FormShortCut;
end;

procedure TLcaThemedMainMenu.UnhookOwnerFormShortCut;
begin
  if FOwnerForm = nil then Exit;
  if FOwnerForm.OnShortCut = @FormShortCut then
    FOwnerForm.OnShortCut := FPrevFormShortCut;
  FPrevFormShortCut := nil;
  FOwnerForm := nil;
end;

procedure TLcaThemedMainMenu.FormShortCut(var Msg: TLMKey; var Handled: Boolean);
begin
  if not Handled and IsShortCut(Msg) then
    Handled := True
  else if Assigned(FPrevFormShortCut) then
    FPrevFormShortCut(Msg, Handled);
end;

procedure TLcaThemedMainMenu.Loaded;
begin
  inherited Loaded;
  HookOwnerFormShortCut;
end;

destructor TLcaThemedMainMenu.Destroy;
begin
  UnhookOwnerFormShortCut;
  inherited Destroy;
end;

procedure TLcaThemedMainMenu.MenuStructureChanged;
begin
  if Assigned(FOnMenuChanged) then
    FOnMenuChanged(Self);
end;

end.
