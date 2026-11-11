unit uBrowserPermissions;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBrowserSensitiveConfirmEvent = procedure(const AMessage: string;
    var AApproved, AAllowForSession: Boolean) of object;

procedure SetBrowserSensitiveConfirmHandler(AHandler: TBrowserSensitiveConfirmEvent);

function RequestBrowserSensitiveConfirm(const AMessage: string;
  var AAllowForSession: Boolean): Boolean;

implementation

uses
  {$IFDEF LCL}
  Forms,
  {$ENDIF}
  SyncObjs;

var
  GHandler: TBrowserSensitiveConfirmEvent;

type
  TConfirmSyncData = record
    Message: string;
    Approved: Boolean;
    AllowForSession: Boolean;
  end;

  TConfirmThreadBridge = class
  public
    Data: TConfirmSyncData;
    procedure SyncConfirm;
  end;

var
  GConfirmBridge: TConfirmThreadBridge;

procedure SetBrowserSensitiveConfirmHandler(AHandler: TBrowserSensitiveConfirmEvent);
begin
  GHandler := AHandler;
end;

procedure TConfirmThreadBridge.SyncConfirm;
var
  Allow: Boolean;
begin
  Data.Approved := False;
  Data.AllowForSession := False;
  if Assigned(GHandler) then
    GHandler(Data.Message, Data.Approved, Allow);
  if Allow then
    Data.AllowForSession := True;
end;

function RequestBrowserSensitiveConfirm(const AMessage: string;
  var AAllowForSession: Boolean): Boolean;
begin
  if not Assigned(GHandler) then
    Exit(False);
  GConfirmBridge.Data.Message := AMessage;
  GConfirmBridge.Data.Approved := False;
  GConfirmBridge.Data.AllowForSession := False;
  {$IFDEF LCL}
  if Assigned(Application) and (GetCurrentThreadId <> MainThreadID) then
    TThread.Synchronize(nil, @GConfirmBridge.SyncConfirm)
  else
  {$ENDIF}
    GConfirmBridge.SyncConfirm;
  AAllowForSession := GConfirmBridge.Data.AllowForSession;
  Result := GConfirmBridge.Data.Approved;
end;

initialization
  GConfirmBridge := TConfirmThreadBridge.Create;

finalization
  GConfirmBridge.Free;

end.
