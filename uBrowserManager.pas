unit uBrowserManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, fpjson,
  uBrowserReadTypes, uCdpConnection, uCdpWebSocket, uBrowserProcess,
  uBrowserSession, uBrowserNetworkGuard, uBrowserNavigate,
  uBrowserAutomationEventContext, uBrowserConsoleCollector, uBrowserNetworkCollector;

type
  TBrowserManagedSession = class
  public
    Id: string;
    WorkspaceRoot: string;
    ChatSessionId: string;
    AllowLocalhost: Boolean;
    Visible: Boolean;
    AutomationPaused: Boolean;
    FetchGuardEnabled: Boolean;
    LastActivity: TDateTime;
    Browser: TBrowserProcess;
    Socket: TCdpWebSocket;
    Connection: TCdpConnection;
    PageSession: TBrowserSession;
    Guard: TBrowserNetworkGuard;
    Navigator: TBrowserNavigator;
    EventCtx: TBrowserAutomationEventContext;
    ConsoleLog: TBrowserConsoleCollector;
    NetworkLog: TBrowserNetworkCollector;
    RefMap: TStringList;
    RefCounter: Integer;
    FastTeardown: Boolean;
    Lock: TCriticalSection;
    destructor Destroy; override;
    procedure Touch;
    function WithLock: TCriticalSection;
  end;

  TBrowserCdpPumpThread = class(TThread)
  protected
    procedure Execute; override;
  end;

function BrowserManagerTryAcquire(const Config: TBrowserReadConfig;
  CancelCheck: TBrowserReadCancelCheck; out ErrMsg: string): Boolean;
procedure BrowserManagerRelease;
procedure BrowserManagerShutdownAll;

function NewBrowserSessionId: string;
function BrowserSessionCreate(const WorkspaceRoot, ChatSessionId: string;
  AllowLocalhost: Boolean; AVisible: Boolean; const Config: TBrowserReadConfig;
  CancelCheck: TBrowserReadCancelCheck; out Session: TBrowserManagedSession;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
function BrowserSessionFind(const SessionId: string): TBrowserManagedSession;
function BrowserSessionClose(const SessionId: string;
  CancelCheck: TBrowserReadCancelCheck): Boolean;
procedure BrowserSessionPurgeIdle(const Config: TBrowserReadConfig);
function BrowserOpenSessionsJson: string;
procedure BrowserSessionCloseForChatSession(const ChatSessionId: string);

implementation

uses
  DateUtils, Math,
  uBrowserDiscovery, uBrowserRead;

function NewBrowserSessionId: string;
begin
  Result := 'bs_' + IntToHex(GetTickCount64, 16) + '_' + IntToHex(Random($7FFFFFFF), 8);
end;

var
  GLock: TCriticalSection;
  GActive: Integer;
  GMaxConcurrent: Integer;
  GSessions: TList;
  GSessionLock: TCriticalSection;
  GPumpThread: TBrowserCdpPumpThread;
  GPumpStop: Boolean;

procedure BrowserCdpPumpSessionsOnce;
var
  I: Integer;
  S: TBrowserManagedSession;
  Snapshot: TList;
begin
  if GSessionLock = nil then Exit;
  Snapshot := TList.Create;
  try
    GSessionLock.Enter;
    try
      for I := 0 to GSessions.Count - 1 do
        Snapshot.Add(GSessions[I]);
    finally
      GSessionLock.Leave;
    end;
    for I := 0 to Snapshot.Count - 1 do
    begin
      S := TBrowserManagedSession(Snapshot[I]);
      if not S.FetchGuardEnabled then Continue;
      if not Assigned(S.Connection) then Continue;
      S.Lock.Enter;
      try
        if S.Connection.ConnectLoopAlive then
          S.Connection.DrainEvents(32, nil);
      finally
        S.Lock.Leave;
      end;
    end;
  finally
    Snapshot.Free;
  end;
end;

procedure TBrowserCdpPumpThread.Execute;
begin
  while not GPumpStop do
  begin
    BrowserCdpPumpSessionsOnce;
    Sleep(25);
  end;
end;

procedure StartBrowserCdpPump;
begin
  if GPumpThread <> nil then Exit;
  GPumpStop := False;
  GPumpThread := TBrowserCdpPumpThread.Create(True);
  GPumpThread.FreeOnTerminate := False;
  GPumpThread.Start;
end;

procedure StopBrowserCdpPump;
var
  T: TBrowserCdpPumpThread;
begin
  GPumpStop := True;
  T := GPumpThread;
  GPumpThread := nil;
  if T <> nil then
  begin
    T.WaitFor;
    T.Free;
  end;
end;

procedure MaybeStopBrowserCdpPump;
begin
  if GSessionLock = nil then Exit;
  GSessionLock.Enter;
  try
    if (GSessions = nil) or (GSessions.Count = 0) then
      StopBrowserCdpPump;
  finally
    GSessionLock.Leave;
  end;
end;

destructor TBrowserManagedSession.Destroy;
var
  Conn: TCdpConnection;
begin
  Lock.Enter;
  try
    FetchGuardEnabled := False;
    Conn := Connection;
    Connection := nil;
    if Assigned(Conn) then
    begin
      Conn.OnEvent := nil;
      Conn.Disconnect;
    end;
    if (not FastTeardown) and Assigned(PageSession) then
      PageSession.ClosePage(nil);
    FreeAndNil(PageSession);
    FreeAndNil(Navigator);
    FreeAndNil(Guard);
    FreeAndNil(EventCtx);
    FreeAndNil(ConsoleLog);
    FreeAndNil(NetworkLog);
    FreeAndNil(RefMap);
  finally
    Lock.Leave;
  end;
  FreeAndNil(Conn);
  FreeAndNil(Socket);
  FreeAndNil(Browser);
  Lock.Free;
  inherited Destroy;
end;

procedure FreeBrowserSessionsList(AList: TList);
var
  I: Integer;
  S: TBrowserManagedSession;
begin
  if AList = nil then Exit;
  for I := 0 to AList.Count - 1 do
  begin
    S := TBrowserManagedSession(AList[I]);
    S.FastTeardown := True;
    S.Free;
  end;
  AList.Free;
end;

function BrowserOpenSessionsJson: string;
var
  I: Integer;
  S: TBrowserManagedSession;
  Root, Item: TJSONObject;
  Arr: TJSONArray;
begin
  Arr := TJSONArray.Create;
  if GSessionLock <> nil then
  begin
    GSessionLock.Enter;
    try
      for I := 0 to GSessions.Count - 1 do
      begin
        S := TBrowserManagedSession(GSessions[I]);
        Item := TJSONObject.Create;
        Item.Add('session_id', S.Id);
        Item.Add('visible', S.Visible);
        Item.Add('automation_paused', S.AutomationPaused);
        Item.Add('last_activity', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', S.LastActivity));
        Arr.Add(Item);
      end;
    finally
      GSessionLock.Leave;
    end;
  end;
  Root := TJSONObject.Create;
  try
    Root.Add('sessions', Arr);
    Result := Root.AsJSON;
  finally
    Root.Free;
  end;
end;

function BrowserOpenSessionIdsHint: string;
var
  I: Integer;
  S: TBrowserManagedSession;
  Parts: TStringList;
begin
  Result := '';
  if (GSessionLock = nil) or (GSessions = nil) or (GSessions.Count = 0) then Exit;
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ',';
    GSessionLock.Enter;
    try
      for I := 0 to GSessions.Count - 1 do
      begin
        S := TBrowserManagedSession(GSessions[I]);
        Parts.Add(S.Id);
      end;
    finally
      GSessionLock.Leave;
    end;
    Result := ' Open session_id(s): ' + Parts.DelimitedText + '.';
  finally
    Parts.Free;
  end;
end;

procedure TBrowserManagedSession.Touch;
begin
  LastActivity := Now;
end;

function TBrowserManagedSession.WithLock: TCriticalSection;
begin
  Result := Lock;
end;

function BrowserManagerTryAcquire(const Config: TBrowserReadConfig;
  CancelCheck: TBrowserReadCancelCheck; out ErrMsg: string): Boolean;
var
  Start: QWord;
  WaitMs: Integer;
begin
  ErrMsg := '';
  if GLock = nil then
    GLock := TCriticalSection.Create;
  GMaxConcurrent := Config.MaxConcurrent;
  if GMaxConcurrent < 1 then
    GMaxConcurrent := 1;
  { An open session holds the slot until browser_close. Waiting out MaxTimeoutMs
    (up to 120s) only delays the error that tells the model to close or reuse it. }
  WaitMs := Config.MaxTimeoutMs;
  if WaitMs < 1 then
    WaitMs := 1;
  if WaitMs > 1000 then
    WaitMs := 1000;
  Start := GetTickCount64;
  while GetTickCount64 - Start < QWord(WaitMs) do
  begin
    if Assigned(CancelCheck) and CancelCheck() then
    begin
      ErrMsg := 'Cancelled';
      Exit(False);
    end;
    GLock.Enter;
    try
      if GActive < GMaxConcurrent then
      begin
        Inc(GActive);
        Exit(True);
      end;
    finally
      GLock.Leave;
    end;
    Sleep(50);
  end;
  ErrMsg := Format(
    'Timed out waiting for a browser slot (max concurrent %d). ' +
    'Close other sessions with browser_close or retry later.', [GMaxConcurrent]) +
    BrowserOpenSessionIdsHint;
  Result := False;
end;

procedure BrowserManagerRelease;
begin
  if GLock = nil then Exit;
  GLock.Enter;
  try
    if GActive > 0 then
      Dec(GActive);
  finally
    GLock.Leave;
  end;
end;

procedure BrowserSessionPurgeIdle(const Config: TBrowserReadConfig);
var
  I, PurgedCount: Integer;
  S: TBrowserManagedSession;
  Cutoff: TDateTime;
  ToFree: TList;
begin
  if GSessionLock = nil then Exit;
  ToFree := TList.Create;
  Cutoff := IncMilliSecond(Now, -Config.IdleTimeoutMs);
  GSessionLock.Enter;
  try
    for I := GSessions.Count - 1 downto 0 do
    begin
      S := TBrowserManagedSession(GSessions[I]);
      if S.Visible then
        Continue;
      if S.LastActivity < Cutoff then
      begin
        GSessions.Delete(I);
        ToFree.Add(S);
        BrowserManagerRelease;
      end;
    end;
    PurgedCount := ToFree.Count;
  finally
    GSessionLock.Leave;
  end;
  FreeBrowserSessionsList(ToFree);
  if PurgedCount > 0 then
    MaybeStopBrowserCdpPump;
end;

procedure BrowserManagerShutdownAll;
var
  N: Integer;
  ToFree: TList;
begin
  StopBrowserCdpPump;
  if GSessionLock = nil then Exit;
  ToFree := TList.Create;
  GSessionLock.Enter;
  try
    N := GSessions.Count;
    ToFree.Assign(GSessions);
    GSessions.Clear;
    if N > 0 then
    begin
      if GLock = nil then
        GLock := TCriticalSection.Create;
      GLock.Enter;
      try
        while (N > 0) and (GActive > 0) do
        begin
          Dec(GActive);
          Dec(N);
        end;
      finally
        GLock.Leave;
      end;
    end;
  finally
    GSessionLock.Leave;
  end;
  FreeBrowserSessionsList(ToFree);
end;

function BrowserSessionFind(const SessionId: string): TBrowserManagedSession;
var
  I: Integer;
  S: TBrowserManagedSession;
begin
  Result := nil;
  if (SessionId = '') or (GSessionLock = nil) then Exit;
  GSessionLock.Enter;
  try
    for I := 0 to GSessions.Count - 1 do
    begin
      S := TBrowserManagedSession(GSessions[I]);
      if SameText(S.Id, SessionId) then
        Exit(S);
    end;
  finally
    GSessionLock.Leave;
  end;
end;

function BrowserSessionCreate(const WorkspaceRoot, ChatSessionId: string;
  AllowLocalhost: Boolean; AVisible: Boolean; const Config: TBrowserReadConfig;
  CancelCheck: TBrowserReadCancelCheck; out Session: TBrowserManagedSession;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  Executable, WsUrl, Host, Path: string;
  Port: Word;
  Transport: ICdpTransport;
  EnableParams, ResultObj: TJSONObject;
  I: Integer;
begin
  Session := nil;
  ErrKind := brekNone;
  ErrMsg := '';
  BrowserSessionPurgeIdle(Config);

  if GSessionLock = nil then
    GSessionLock := TCriticalSection.Create;
  if GSessions = nil then
    GSessions := TList.Create;

  GSessionLock.Enter;
  try
    if GSessions.Count >= Config.MaxSessions then
    begin
      ErrKind := brekInternal;
      ErrMsg := 'Maximum browser sessions reached';
      Exit(False);
    end;
  finally
    GSessionLock.Leave;
  end;

  if not DiscoverChromiumExecutable(Config, Executable, ErrMsg) then
  begin
    ErrKind := brekBrowserNotFound;
    Exit(False);
  end;

  if not BrowserManagerTryAcquire(Config, CancelCheck, ErrMsg) then
  begin
    ErrKind := brekInternal;
    if Trim(ErrMsg) = '' then
      ErrMsg := 'Could not acquire browser slot';
    Exit(False);
  end;
  Session := TBrowserManagedSession.Create;
  Session.Id := NewBrowserSessionId;
  Session.WorkspaceRoot := WorkspaceRoot;
  Session.ChatSessionId := ChatSessionId;
  Session.AllowLocalhost := AllowLocalhost;
  Session.Visible := AVisible;
  Session.AutomationPaused := AVisible;
  Session.FetchGuardEnabled := False;
  Session.LastActivity := Now;
  Session.Lock := TCriticalSection.Create;
  Session.RefMap := TStringList.Create;
  Session.RefCounter := 0;
  Session.Browser := TBrowserProcess.Create;
  Session.Socket := TCdpWebSocket.Create;

  try
    if Assigned(CancelCheck) and CancelCheck() then
    begin
      ErrKind := brekCancelled;
      ErrMsg := 'Cancelled';
      Exit(False);
    end;

    if not Session.Browser.Start(Executable, Config.MaxTimeoutMs, not AVisible,
      CancelCheck, WsUrl, ErrKind, ErrMsg) then
      Exit(False);

    if not ParseBrowserWebSocketEndpoint(WsUrl, Host, Port, Path) then
    begin
      ErrKind := brekCdpConnectionFailed;
      ErrMsg := 'Invalid debugger WebSocket URL';
      Exit(False);
    end;

    if not Session.Socket.Connect(Host, Port, Path, Min(Config.MaxTimeoutMs, 15000), ErrMsg) then
    begin
      ErrKind := brekCdpConnectionFailed;
      if Trim(ErrMsg) = '' then
        ErrMsg := 'WebSocket connection failed';
      Exit(False);
    end;

    Transport := TCdpWebSocketTransport.Create(Session.Socket);
    Session.Connection := TCdpConnection.Create(Transport);
    Session.Guard := TBrowserNetworkGuard.Create(Session.Connection, AllowLocalhost,
      Session.WorkspaceRoot);
    Session.Navigator := TBrowserNavigator.Create(Session.Connection);
    Session.ConsoleLog := TBrowserConsoleCollector.Create;
    Session.NetworkLog := TBrowserNetworkCollector.Create;
    Session.EventCtx := TBrowserAutomationEventContext.Create;
    Session.EventCtx.NetGuard := Session.Guard;
    Session.EventCtx.PageNav := Session.Navigator;
    Session.EventCtx.ConsoleLog := Session.ConsoleLog;
    Session.EventCtx.NetworkLog := Session.NetworkLog;
    Session.Connection.OnEvent := @Session.EventCtx.OnCdpEvent;
    Session.Connection.Tag := PtrUInt(Session);

    Session.PageSession := TBrowserSession.Create(Session.Connection);
    if not Session.PageSession.OpenBlankPage(CancelCheck, ErrKind, ErrMsg) then
      Exit(False);

    if not Session.Guard.Enable(CancelCheck) then
    begin
      ErrKind := brekCdpConnectionFailed;
      ErrMsg := 'Network guard failed';
      Exit(False);
    end;
    Session.FetchGuardEnabled := True;

    EnableParams := TJSONObject.Create;
    try
      if not Session.Connection.SendCommand('Network.enable', EnableParams, 10000,
        CancelCheck, ResultObj) then
      begin
        ErrKind := brekCdpConnectionFailed;
        ErrMsg := 'Network.enable failed';
        Exit(False);
      end;
      ResultObj.Free;
      if not Session.Connection.SendCommand('Log.enable', EnableParams, 10000,
        CancelCheck, ResultObj) then
      begin
        ErrKind := brekCdpConnectionFailed;
        ErrMsg := 'Log.enable failed';
        Exit(False);
      end;
      ResultObj.Free;
    finally
      EnableParams.Free;
    end;

    GSessionLock.Enter;
    try
      GSessions.Add(Session);
      StartBrowserCdpPump;
    finally
      GSessionLock.Leave;
    end;
    Result := True;
  except
    on E: Exception do
    begin
      ErrKind := brekInternal;
      ErrMsg := E.Message;
      Result := False;
    end;
  end;

  if not Result then
  begin
    GSessionLock.Enter;
    try
      I := GSessions.IndexOf(Session);
      if I >= 0 then
        GSessions.Delete(I);
    finally
      GSessionLock.Leave;
    end;
    Session.FastTeardown := True;
    Session.Free;
    Session := nil;
    BrowserManagerRelease;
  end;
end;

procedure BrowserSessionCloseForChatSession(const ChatSessionId: string);
var
  I, ClosedCount: Integer;
  S: TBrowserManagedSession;
  ToFree: TList;
begin
  if (ChatSessionId = '') or (GSessionLock = nil) then Exit;
  ToFree := TList.Create;
  GSessionLock.Enter;
  try
    for I := GSessions.Count - 1 downto 0 do
    begin
      S := TBrowserManagedSession(GSessions[I]);
      if SameText(S.ChatSessionId, ChatSessionId) then
      begin
        GSessions.Delete(I);
        ToFree.Add(S);
        BrowserManagerRelease;
      end;
    end;
    ClosedCount := ToFree.Count;
  finally
    GSessionLock.Leave;
  end;
  FreeBrowserSessionsList(ToFree);
  if ClosedCount > 0 then
    MaybeStopBrowserCdpPump;
end;

function BrowserSessionClose(const SessionId: string;
  CancelCheck: TBrowserReadCancelCheck): Boolean;
var
  I: Integer;
  S: TBrowserManagedSession;
begin
  Result := False;
  S := nil;
  if (SessionId = '') or (GSessionLock = nil) then Exit;
  GSessionLock.Enter;
  try
    for I := 0 to GSessions.Count - 1 do
    begin
      if SameText(TBrowserManagedSession(GSessions[I]).Id, SessionId) then
      begin
        S := TBrowserManagedSession(GSessions[I]);
        GSessions.Delete(I);
        BrowserManagerRelease;
        Result := True;
        Break;
      end;
    end;
  finally
    GSessionLock.Leave;
  end;
  if S <> nil then
  begin
    S.FastTeardown := True;
    S.Free;
    MaybeStopBrowserCdpPump;
  end;
end;

initialization
  Randomize;

finalization
  BrowserManagerShutdownAll;
  StopBrowserCdpPump;
  GSessions.Free;
  GSessionLock.Free;
  GLock.Free;

end.
