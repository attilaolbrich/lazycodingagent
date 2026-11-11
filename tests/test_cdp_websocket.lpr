program test_cdp_websocket;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils,
  uCdpWebSocket, uBrowserRead, uBrowserProcess, uBrowserReadConfig, uBrowserReadTypes,
  uBrowserDiscovery;

procedure Fail(const Msg: string);
begin
  WriteLn('FAIL: ', Msg);
  Halt(1);
end;

procedure TestRfc6455Accept;
const
  KEY = 'dGhlIHNhbXBsZSBub25jZQ==';
  EXPECTED = 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=';
begin
  if CdpWebSocketAcceptKey(KEY) <> EXPECTED then
    Fail('RFC6455 Sec-WebSocket-Accept mismatch, got: ' + CdpWebSocketAcceptKey(KEY));
end;

procedure TestParseLocalhost;
var
  Host: string;
  Port: Word;
  Path: string;
begin
  if not ParseBrowserWebSocketEndpoint('ws://localhost:9222/devtools/browser/abc', Host, Port, Path) then
    Fail('localhost ws url should parse');
  if Host <> '127.0.0.1' then
    Fail('localhost should normalize to 127.0.0.1');
  if Port <> 9222 then
    Fail('port mismatch');
end;

procedure TestLiveCdpConnect;
var
  Config: TBrowserReadConfig;
  Executable, WsUrl, Host, Path, ConnectErr: string;
  Port: Word;
  Browser: TBrowserProcess;
  Socket: TCdpWebSocket;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
begin
  Config := LoadBrowserReadConfig;
  if not DiscoverChromiumExecutable(Config, Executable, ErrMsg) then
    Fail('no browser for live CDP test: ' + ErrMsg);

  Browser := TBrowserProcess.Create;
  Socket := TCdpWebSocket.Create;
  try
    if not Browser.Start(Executable, Config.MaxTimeoutMs, True, nil, WsUrl, ErrKind,
      ErrMsg) then
      Fail('browser start: ' + ErrMsg);
    if not ParseBrowserWebSocketEndpoint(WsUrl, Host, Port, Path) then
      Fail('invalid ws url: ' + WsUrl);
    if not Socket.Connect(Host, Port, Path, 15000, ConnectErr) then
      Fail('websocket connect: ' + ConnectErr);
  finally
    Socket.Free;
    Browser.Free;
  end;
end;

begin
  TestRfc6455Accept;
  TestParseLocalhost;
  if SameText(GetEnvironmentVariable('LCA_LIVE_CDP'), '1') then
    TestLiveCdpConnect;
  WriteLn('CDP websocket tests passed.');
end.
