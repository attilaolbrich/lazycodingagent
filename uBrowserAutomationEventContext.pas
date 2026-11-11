unit uBrowserAutomationEventContext;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uCdpConnection, uBrowserNetworkGuard, uBrowserNavigate,
  uBrowserConsoleCollector, uBrowserNetworkCollector;

type
  TBrowserAutomationEventContext = class
  public
    NetGuard: TBrowserNetworkGuard;
    PageNav: TBrowserNavigator;
    ConsoleLog: TBrowserConsoleCollector;
    NetworkLog: TBrowserNetworkCollector;
    OnExtraEvent: TCdpEventHandler;
    procedure OnCdpEvent(Sender: TObject; const Method, ParamsJson: AnsiString);
  end;

implementation

procedure TBrowserAutomationEventContext.OnCdpEvent(Sender: TObject;
  const Method, ParamsJson: AnsiString);
begin
  if Assigned(NetGuard) then
    NetGuard.HandleEvent(Method, ParamsJson);
  if Assigned(PageNav) then
    PageNav.HandleEvent(Method, ParamsJson);
  if Assigned(ConsoleLog) then
    ConsoleLog.HandleEvent(Method, ParamsJson);
  if Assigned(NetworkLog) then
    NetworkLog.HandleEvent(Method, ParamsJson);
  if Assigned(OnExtraEvent) then
    OnExtraEvent(Sender, Method, ParamsJson);
end;

end.
