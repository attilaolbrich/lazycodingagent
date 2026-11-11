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
    function SendText(const Text: UTF8String): Boolean;
    function TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean;
    procedure Disconnect;
    procedure Enqueue(const Msg: string);
  end;

  TMockTransportWithPending = class(TMockTransport)
  public
    function SendText(const Text: UTF8String): Boolean;
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

begin
  TestDestroyRoundTrip;
  TestDestroyWithPendingStored;
  WriteLn('OK: cdp connection tests passed');
end.
