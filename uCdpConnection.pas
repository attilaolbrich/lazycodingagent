unit uCdpConnection;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, fpjson, jsonparser, uCdpWebSocket, uBrowserReadTypes;

type
  TCdpEventHandler = procedure(Sender: TObject; const Method, ParamsJson: AnsiString) of object;

  ICdpTransport = interface
    ['{B8A2F4E1-9C3D-4A5B-8E7F-1D2C3B4A5968}']
    function Connected: Boolean;
    function SendText(const Text: UTF8String): Boolean;
    function TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean;
    procedure Disconnect;
  end;

  TCdpWebSocketTransport = class(TInterfacedObject, ICdpTransport)
  private
    FSocket: TCdpWebSocket;
  public
    constructor Create(ASocket: TCdpWebSocket);
    function Connected: Boolean;
    function SendText(const Text: UTF8String): Boolean;
    function TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean;
    procedure Disconnect;
  end;

  TCdpConnection = class
  private
    FTransport: ICdpTransport;
    FNextId: Integer;
    FOnEvent: TCdpEventHandler;
    FSessionId: string;
    FTag: PtrUInt;
    FReadLock: TCriticalSection;
    FPending: TStringList;
    function WaitForResponse(AId: Integer; TimeoutMs: Integer;
      CancelCheck: TBrowserReadCancelCheck; out ResultObj: TJSONObject): Boolean;
    procedure ClearPending;
    procedure StorePendingResponse(AId: Integer; const Root: TJSONObject);
    function TakePendingResponse(AId: Integer; out ResultObj: TJSONObject): Boolean;
    function BuildResultFromRoot(const Root: TJSONObject; out ResultObj: TJSONObject): Boolean;
    procedure DispatchEvent(const Root: TJSONObject);
    function RouteIncomingRoot(const Root: TJSONObject; AWaitId: Integer;
      out Matched: Boolean; out ResultObj: TJSONObject): Boolean;
    function ReadAndRouteOne(TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
      AWaitId: Integer; out Matched: Boolean; out ResultObj: TJSONObject): Boolean;
  public
    constructor Create(ATransport: ICdpTransport);
    destructor Destroy; override;
    property OnEvent: TCdpEventHandler read FOnEvent write FOnEvent;
    property SessionId: string read FSessionId write FSessionId;
    property Tag: PtrUInt read FTag write FTag;
    procedure NotifyEvent(const Method, ParamsJson: AnsiString);
    function ConnectLoopAlive: Boolean;
    function SendCommand(const Method: string; const Params: TJSONObject;
      TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
      out ResultObj: TJSONObject): Boolean;
    procedure PumpEvents(TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck);
    procedure DrainEvents(MaxMessages: Integer; CancelCheck: TBrowserReadCancelCheck);
    procedure Disconnect;
  private
    function ProcessOneEventMessage(TimeoutMs: Integer;
      CancelCheck: TBrowserReadCancelCheck): Boolean;
  end;

implementation

uses
  DateUtils;

constructor TCdpWebSocketTransport.Create(ASocket: TCdpWebSocket);
begin
  inherited Create;
  FSocket := ASocket;
end;

function TCdpWebSocketTransport.Connected: Boolean;
begin
  Result := Assigned(FSocket) and FSocket.Connected;
end;

function TCdpWebSocketTransport.SendText(const Text: UTF8String): Boolean;
begin
  if Assigned(FSocket) then
    Result := FSocket.SendText(Text)
  else
    Result := False;
end;

function TCdpWebSocketTransport.TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean;
begin
  if Assigned(FSocket) then
    Result := FSocket.TryReceiveText(Text, TimeoutMs)
  else
    Result := False;
end;

procedure TCdpWebSocketTransport.Disconnect;
begin
  if Assigned(FSocket) then
    FSocket.Disconnect;
end;

constructor TCdpConnection.Create(ATransport: ICdpTransport);
begin
  inherited Create;
  FTransport := ATransport;
  FNextId := 1;
  FSessionId := '';
  FReadLock := TCriticalSection.Create;
  FPending := TStringList.Create;
  FPending.Sorted := True;
  FPending.Duplicates := dupError;
end;

destructor TCdpConnection.Destroy;
begin
  Disconnect;
  FreeAndNil(FPending);
  FreeAndNil(FReadLock);
  inherited Destroy;
end;

procedure TCdpConnection.ClearPending;
var
  I: Integer;
  Obj: TJSONObject;
begin
  if FPending = nil then Exit;
  if Assigned(FReadLock) then
    FReadLock.Enter;
  try
    for I := 0 to FPending.Count - 1 do
    begin
      Obj := TJSONObject(FPending.Objects[I]);
      if Assigned(Obj) then
        Obj.Free;
    end;
    FPending.Clear;
  finally
    if Assigned(FReadLock) then
      FReadLock.Leave;
  end;
end;

procedure TCdpConnection.Disconnect;
begin
  if Assigned(FTransport) then
  begin
    FTransport.Disconnect;
    FTransport := nil;
  end;
  ClearPending;
end;

procedure TCdpConnection.NotifyEvent(const Method, ParamsJson: AnsiString);
begin
  if Assigned(FOnEvent) then
    FOnEvent(Self, Method, ParamsJson);
end;

function TCdpConnection.ConnectLoopAlive: Boolean;
begin
  Result := Assigned(FTransport) and FTransport.Connected;
end;

function TCdpConnection.BuildResultFromRoot(const Root: TJSONObject;
  out ResultObj: TJSONObject): Boolean;
var
  Err: TJSONObject;
begin
  ResultObj := nil;
  Result := False;
  if Root.Find('error') <> nil then
  begin
    Err := TJSONObject(Root.Find('error'));
    ResultObj := TJSONObject.Create;
    ResultObj.Add('error', Err.Clone);
    Exit(True);
  end;
  if Root.Find('result') <> nil then
  begin
    ResultObj := TJSONObject(TJSONObject(Root.Find('result')).Clone);
    Exit(True);
  end;
end;

procedure TCdpConnection.StorePendingResponse(AId: Integer; const Root: TJSONObject);
var
  Payload: TJSONObject;
  Key: string;
  Idx: Integer;
begin
  if not BuildResultFromRoot(Root, Payload) then
    Exit;
  Key := IntToStr(AId);
  FReadLock.Enter;
  try
    Idx := FPending.IndexOf(Key);
    if Idx >= 0 then
    begin
      TJSONObject(FPending.Objects[Idx]).Free;
      FPending.Delete(Idx);
    end;
    FPending.AddObject(Key, Payload);
  finally
    FReadLock.Leave;
  end;
end;

function TCdpConnection.TakePendingResponse(AId: Integer;
  out ResultObj: TJSONObject): Boolean;
var
  Key: string;
  Idx: Integer;
begin
  Result := False;
  ResultObj := nil;
  Key := IntToStr(AId);
  FReadLock.Enter;
  try
    Idx := FPending.IndexOf(Key);
    if Idx < 0 then Exit;
    ResultObj := TJSONObject(FPending.Objects[Idx]);
    FPending.Objects[Idx] := nil;
    FPending.Delete(Idx);
    Result := Assigned(ResultObj);
  finally
    FReadLock.Leave;
  end;
end;

procedure TCdpConnection.DispatchEvent(const Root: TJSONObject);
var
  Method: string;
  Params: TJSONObject;
begin
  Method := Root.Get('method', '');
  if Method = '' then Exit;
  if Root.Find('params') <> nil then
    Params := TJSONObject(Root.Find('params').Clone)
  else
    Params := TJSONObject.Create;
  try
    if Assigned(FOnEvent) then
      FOnEvent(Self, AnsiString(Method), AnsiString(Params.AsJSON));
  finally
    Params.Free;
  end;
end;

function TCdpConnection.RouteIncomingRoot(const Root: TJSONObject; AWaitId: Integer;
  out Matched: Boolean; out ResultObj: TJSONObject): Boolean;
var
  IdVal: TJSONNumber;
  MsgId: Integer;
begin
  Matched := False;
  ResultObj := nil;
  Result := True;
  if Root.Find('id') <> nil then
  begin
    IdVal := TJSONNumber(Root.Find('id'));
    MsgId := IdVal.AsInteger;
    if (AWaitId >= 0) and (MsgId = AWaitId) then
    begin
      Matched := BuildResultFromRoot(Root, ResultObj);
      Exit;
    end;
    StorePendingResponse(MsgId, Root);
    Exit;
  end;
  DispatchEvent(Root);
end;

function TCdpConnection.ReadAndRouteOne(TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck; AWaitId: Integer; out Matched: Boolean;
  out ResultObj: TJSONObject): Boolean;
var
  Text: UTF8String;
  Root: TJSONObject;
begin
  Matched := False;
  ResultObj := nil;
  Result := False;
  if not ConnectLoopAlive then Exit;
  if Assigned(CancelCheck) and CancelCheck() then Exit;
  FReadLock.Enter;
  try
    if not FTransport.TryReceiveText(Text, TimeoutMs) then Exit;
  finally
    FReadLock.Leave;
  end;
  Root := TJSONObject(GetJSON(Text));
  try
    Result := RouteIncomingRoot(Root, AWaitId, Matched, ResultObj);
  finally
    Root.Free;
  end;
end;

function TCdpConnection.ProcessOneEventMessage(TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck): Boolean;
var
  Matched: Boolean;
  Dummy: TJSONObject;
begin
  Result := ReadAndRouteOne(TimeoutMs, CancelCheck, -1, Matched, Dummy);
  if Assigned(Dummy) then
    Dummy.Free;
end;

procedure TCdpConnection.PumpEvents(TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck);
begin
  ProcessOneEventMessage(TimeoutMs, CancelCheck);
end;

procedure TCdpConnection.DrainEvents(MaxMessages: Integer;
  CancelCheck: TBrowserReadCancelCheck);
var
  N: Integer;
begin
  if MaxMessages < 1 then
    MaxMessages := 32;
  N := 0;
  while N < MaxMessages do
  begin
    if not ProcessOneEventMessage(50, CancelCheck) then
      Break;
    Inc(N);
  end;
end;

function TCdpConnection.WaitForResponse(AId: Integer; TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck; out ResultObj: TJSONObject): Boolean;
var
  Start: QWord;
  Matched: Boolean;
begin
  ResultObj := nil;
  Result := False;
  if TakePendingResponse(AId, ResultObj) then
    Exit(True);
  Start := GetTickCount64;
  while GetTickCount64 - Start < QWord(TimeoutMs) do
  begin
    if Assigned(CancelCheck) and CancelCheck() then Exit;
    if not ConnectLoopAlive then Exit;
    if ReadAndRouteOne(200, CancelCheck, AId, Matched, ResultObj) then
    begin
      if Matched then
        Exit(True);
    end;
  end;
end;

function TCdpConnection.SendCommand(const Method: string; const Params: TJSONObject;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out ResultObj: TJSONObject): Boolean;
var
  Cmd: TJSONObject;
  Id: Integer;
  Payload: string;
begin
  ResultObj := nil;
  if not ConnectLoopAlive then Exit(False);
  Id := FNextId;
  Inc(FNextId);
  Cmd := TJSONObject.Create;
  try
    Cmd.Add('id', Id);
    Cmd.Add('method', Method);
    if FSessionId <> '' then
      Cmd.Add('sessionId', FSessionId);
    if Assigned(Params) then
      Cmd.Add('params', Params.Clone);
    Payload := Cmd.AsJSON;
  finally
    Cmd.Free;
  end;
  if not FTransport.SendText(Payload) then Exit(False);
  Result := WaitForResponse(Id, TimeoutMs, CancelCheck, ResultObj);
end;

end.
