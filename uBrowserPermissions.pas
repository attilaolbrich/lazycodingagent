unit uBrowserPermissions;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBrowserSensitiveConfirmEvent = procedure(const AMessage: string;
    var AApproved, AAllowForSession: Boolean) of object;
  TBrowserPermissionConfirmEvent = procedure(const AMessage: string;
    var AApproved, AAllowForSession: Boolean) of object;
  TBrowserPermissionPersistEvent = procedure(const AChatSessionId: string; AValue: Boolean) of object;

procedure SetBrowserSensitiveConfirmHandler(AHandler: TBrowserSensitiveConfirmEvent);
procedure SetBrowserInteractiveConfirmHandler(AHandler: TBrowserPermissionConfirmEvent);
procedure SetBrowserLocalhostConfirmHandler(AHandler: TBrowserPermissionConfirmEvent);
procedure SetBrowserInteractivePersistHandler(AHandler: TBrowserPermissionPersistEvent);
procedure SetBrowserLocalhostPersistHandler(AHandler: TBrowserPermissionPersistEvent);
procedure BrowserPermissionPersistInteractive(const AChatSessionId: string; AValue: Boolean);
procedure BrowserPermissionPersistLocalhost(const AChatSessionId: string; AValue: Boolean);

function BrowserConfirmRequestSessionId: string;

function RequestBrowserSensitiveConfirm(const AMessage: string;
  var AAllowForSession: Boolean; const AChatSessionId: string = ''): Boolean;
function RequestBrowserInteractiveConfirm(const AMessage: string;
  var AAllowForSession: Boolean; const AChatSessionId: string = ''): Boolean;
function RequestBrowserLocalhostConfirm(const AMessage: string;
  var AAllowForSession: Boolean; const AChatSessionId: string = ''): Boolean;

implementation

uses
  {$IFDEF LCL}
  Forms,
  {$ENDIF}
  SyncObjs;

var
  GSensitiveHandler: TBrowserSensitiveConfirmEvent;
  GInteractiveHandler: TBrowserPermissionConfirmEvent;
  GLocalhostHandler: TBrowserPermissionConfirmEvent;
  GPersistInteractive: TBrowserPermissionPersistEvent;
  GPersistLocalhost: TBrowserPermissionPersistEvent;

type
  TConfirmSyncData = record
    Message: string;
    ChatSessionId: string;
    Approved: Boolean;
    AllowForSession: Boolean;
  end;

  TConfirmThreadBridge = class
  public
    Data: TConfirmSyncData;
    Handler: TBrowserPermissionConfirmEvent;
    SensitiveHandler: TBrowserSensitiveConfirmEvent;
    UseSensitive: Boolean;
    procedure SyncConfirm;
  end;

var
  GConfirmBridge: TConfirmThreadBridge;
  GConfirmLock: TCriticalSection;

procedure SetBrowserSensitiveConfirmHandler(AHandler: TBrowserSensitiveConfirmEvent);
begin
  GSensitiveHandler := AHandler;
end;

procedure SetBrowserInteractiveConfirmHandler(AHandler: TBrowserPermissionConfirmEvent);
begin
  GInteractiveHandler := AHandler;
end;

procedure SetBrowserLocalhostConfirmHandler(AHandler: TBrowserPermissionConfirmEvent);
begin
  GLocalhostHandler := AHandler;
end;

procedure SetBrowserInteractivePersistHandler(AHandler: TBrowserPermissionPersistEvent);
begin
  GPersistInteractive := AHandler;
end;

procedure SetBrowserLocalhostPersistHandler(AHandler: TBrowserPermissionPersistEvent);
begin
  GPersistLocalhost := AHandler;
end;

procedure BrowserPermissionPersistInteractive(const AChatSessionId: string; AValue: Boolean);
begin
  if Assigned(GPersistInteractive) then
    GPersistInteractive(AChatSessionId, AValue);
end;

procedure BrowserPermissionPersistLocalhost(const AChatSessionId: string; AValue: Boolean);
begin
  if Assigned(GPersistLocalhost) then
    GPersistLocalhost(AChatSessionId, AValue);
end;

function BrowserConfirmRequestSessionId: string;
begin
  Result := '';
  if Assigned(GConfirmBridge) then
    Result := GConfirmBridge.Data.ChatSessionId;
end;

procedure TConfirmThreadBridge.SyncConfirm;
var
  Allow: Boolean;
begin
  Data.Approved := False;
  Data.AllowForSession := False;
  if UseSensitive then
  begin
    if Assigned(SensitiveHandler) then
      SensitiveHandler(Data.Message, Data.Approved, Allow);
  end
  else if Assigned(Handler) then
    Handler(Data.Message, Data.Approved, Allow);
  if Allow then
    Data.AllowForSession := True;
end;

function RequestPermissionConfirm(AHandler: TBrowserPermissionConfirmEvent;
  const AMessage: string; var AAllowForSession: Boolean; const AChatSessionId: string): Boolean;
begin
  if not Assigned(AHandler) then
    Exit(False);
  GConfirmLock.Enter;
  try
    GConfirmBridge.UseSensitive := False;
    GConfirmBridge.Handler := AHandler;
    GConfirmBridge.Data.Message := AMessage;
    GConfirmBridge.Data.ChatSessionId := AChatSessionId;
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
  finally
    GConfirmLock.Leave;
  end;
end;

function RequestBrowserSensitiveConfirm(const AMessage: string;
  var AAllowForSession: Boolean; const AChatSessionId: string): Boolean;
begin
  if not Assigned(GSensitiveHandler) then
    Exit(False);
  GConfirmLock.Enter;
  try
    GConfirmBridge.UseSensitive := True;
    GConfirmBridge.SensitiveHandler := GSensitiveHandler;
    GConfirmBridge.Data.Message := AMessage;
    GConfirmBridge.Data.ChatSessionId := AChatSessionId;
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
  finally
    GConfirmLock.Leave;
  end;
end;

function RequestBrowserInteractiveConfirm(const AMessage: string;
  var AAllowForSession: Boolean; const AChatSessionId: string): Boolean;
begin
  Result := RequestPermissionConfirm(GInteractiveHandler, AMessage, AAllowForSession,
    AChatSessionId);
end;

function RequestBrowserLocalhostConfirm(const AMessage: string;
  var AAllowForSession: Boolean; const AChatSessionId: string): Boolean;
begin
  Result := RequestPermissionConfirm(GLocalhostHandler, AMessage, AAllowForSession,
    AChatSessionId);
end;

initialization
  GConfirmBridge := TConfirmThreadBridge.Create;
  GConfirmLock := TCriticalSection.Create;

finalization
  GConfirmLock.Free;
  GConfirmBridge.Free;

end.