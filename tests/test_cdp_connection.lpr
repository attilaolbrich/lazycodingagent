program test_cdp_connection;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, fpjson, jsonparser,
  uCdpConnection, uBrowserReadTypes;

procedure Fail(const Msg: string);
begin
  WriteLn('FAIL: ', Msg);
  Halt(1);
end;

type
  TMockTransport = class(TInterfacedObject, ICdpTransport)
  private
    FQueue: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    function Connected: Boolean;
    function SendText(const Text: UTF8String): Boolean; virtual;
    function TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean; virtual;
    procedure Disconnect;
    procedure Enqueue(const Msg: string);
  end;

  TMockTransportWithPending = class(TMockTransport)
  public
    function SendText(const Text: UTF8String): Boolean; override;
  end;

constructor TMockTransport.Create;
begin
  inherited Create;
  FQueue := TStringList.Create;
end;

destructor TMockTransport.Destroy;
begin
  FQueue.Free;
  inherited Destroy;
end;

function TMockTransport.Connected: Boolean;
begin
  Result := True;
end;

function TMockTransport.SendText(const Text: UTF8String): Boolean;
var
  O: TJSONObject;
  Id: Integer;
begin
  O := TJSONObject(GetJSON(Text));
  try
    Id := O.Get('id', 0);
    Enqueue('{"id":' + IntToStr(Id) + ',"result":{}}');
  finally
    O.Free;
  end;
  Result := True;
end;

function TMockTransport.TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean;
begin
  if FQueue.Count = 0 then Exit(False);
  Text := UTF8String(FQueue[0]);
  FQueue.Delete(0);
  Result := True;
end;

procedure TMockTransport.Disconnect;
begin
end;

procedure TMockTransport.Enqueue(const Msg: string);
begin
  FQueue.Add(Msg);
end;

function TMockTransportWithPending.SendText(const Text: UTF8String): Boolean;
var
  O: TJSONObject;
  Id: Integer;
begin
  O := TJSONObject(GetJSON(Text));
  try
    Id := O.Get('id', 0);
    Enqueue('{"id":' + IntToStr(Id + 1) + ',"result":{"orphan":true}}');
    Enqueue('{"id":' + IntToStr(Id) + ',"result":{}}');
  finally
    O.Free;
  end;
  Result := True;
end;

type
  { Queues an event ahead of the command result. The event handler drains the
    socket the way the browser pump does, which stores the matching result in
    FPending while WaitForResponse is already in progress. }
  TPumpStealTransport = class(TMockTransport)
  public
    Conn: TCdpConnection;
    Drained: Boolean;
    function SendText(const Text: UTF8String): Boolean; override;
    procedure HandleEvent(Sender: TObject; const Method, ParamsJson: AnsiString);
  end;

function TPumpStealTransport.SendText(const Text: UTF8String): Boolean;
var
  O: TJSONObject;
  Id: Integer;
begin
  O := TJSONObject(GetJSON(Text));
  try
    Id := O.Get('id', 0);
    Enqueue('{"method":"Fetch.requestPaused","params":{"requestId":"r1"}}');
    Enqueue('{"id":' + IntToStr(Id) + ',"result":{"marker":"tab"}}');
  finally
    O.Free;
  end;
  Result := True;
end;

procedure TPumpStealTransport.HandleEvent(Sender: TObject;
  const Method, ParamsJson: AnsiString);
begin
  if Drained or (Conn = nil) then Exit;
  Drained := True;
  Conn.DrainEvents(4, nil);
end;

type
  TForgetTransport = class(TMockTransport)
  public
    Receives: Integer;
    ForgottenId: Integer;
    function SendText(const Text: UTF8String): Boolean; override;
    function TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean; override;
  end;

function TForgetTransport.SendText(const Text: UTF8String): Boolean;
var
  O: TJSONObject;
  Id: Integer;
  Method: string;
begin
  O := TJSONObject(GetJSON(Text));
  try
    Id := O.Get('id', 0);
    Method := O.Get('method', '');
    if Method = 'Fetch.continueRequest' then
      ForgottenId := Id
    else
      Enqueue('{"id":' + IntToStr(Id) + ',"result":{"marker":"keep"}}');
  finally
    O.Free;
  end;
  Result := True;
end;

function TForgetTransport.TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean;
begin
  Inc(Receives);
  Result := inherited TryReceiveText(Text, TimeoutMs);
end;

procedure TestDestroyRoundTrip;
var
  Transport: ICdpTransport;
  Conn: TCdpConnection;
  Params, Res: TJSONObject;
begin
  Transport := TMockTransport.Create;
  Conn := TCdpConnection.Create(Transport);
  try
    Params := TJSONObject.Create;
    try
      if not Conn.SendCommand('Page.navigate', Params, 5000, nil, Res) then
        Fail('SendCommand failed');
      if Res = nil then
        Fail('nil result');
    finally
      Params.Free;
      if Assigned(Res) then Res.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TestDestroyWithPendingStored;
var
  Transport: ICdpTransport;
  Conn: TCdpConnection;
  Params, Res: TJSONObject;
begin
  Transport := TMockTransportWithPending.Create;
  Conn := TCdpConnection.Create(Transport);
  try
    Params := TJSONObject.Create;
    try
      if not Conn.SendCommand('Page.navigate', Params, 5000, nil, Res) then
        Fail('SendCommand with pending failed');
    finally
      Params.Free;
      if Assigned(Res) then Res.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TestPumpStealsResponseIntoPending;
var
  Raw: TPumpStealTransport;
  Transport: ICdpTransport;
  Conn: TCdpConnection;
  Params, Res: TJSONObject;
begin
  Raw := TPumpStealTransport.Create;
  Transport := Raw;
  Conn := TCdpConnection.Create(Transport);
  try
    Raw.Conn := Conn;
    Conn.OnEvent := @Raw.HandleEvent;
    Params := TJSONObject.Create;
    try
      if not Conn.SendCommand('Target.createTarget', Params, 2000, nil, Res) then
        Fail('SendCommand missed response stored by DrainEvents');
      if (Res = nil) or (Res.Get('marker', '') <> 'tab') then
        Fail('pending response payload mismatch');
    finally
      Params.Free;
      if Assigned(Res) then Res.Free;
    end;
    if not Raw.Drained then
      Fail('event handler did not drain the stolen response');
  finally
    Conn.Free;
  end;
end;

procedure TestSendCommandForgetDropsReply;
var
  Raw: TForgetTransport;
  Transport: ICdpTransport;
  Conn: TCdpConnection;
  Params, Res: TJSONObject;
  Started: QWord;
begin
  Raw := TForgetTransport.Create;
  Transport := Raw;
  Conn := TCdpConnection.Create(Transport);
  try
    Params := TJSONObject.Create;
    try
      Started := GetTickCount64;
      if not Conn.SendCommandForget('Fetch.continueRequest', Params) then
        Fail('SendCommandForget failed');
      if GetTickCount64 - Started > 500 then
        Fail('SendCommandForget blocked');
      if Raw.Receives <> 0 then
        Fail('SendCommandForget waited for a reply');
      Raw.Enqueue('{"id":' + IntToStr(Raw.ForgottenId) + ',"result":{"marker":"drop"}}');
      if not Conn.SendCommand('Page.navigate', Params, 2000, nil, Res) then
        Fail('SendCommand after forgotten reply failed');
      if (Res = nil) or (Res.Get('marker', '') <> 'keep') then
        Fail('forgotten Fetch reply was delivered as the next command result');
    finally
      Params.Free;
      if Assigned(Res) then Res.Free;
    end;
  finally
    Conn.Free;
  end;
end;

begin
  TestDestroyRoundTrip;
  TestDestroyWithPendingStored;
  TestPumpStealsResponseIntoPending;
  TestSendCommandForgetDropsReply;
  WriteLn('OK: cdp connection tests passed');
end.
