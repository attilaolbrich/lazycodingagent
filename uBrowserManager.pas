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
begin
  if GSessionLock = nil then Exit;
  GSessionLock.Enter;
  try
    for I := 0 to GSessions.Count - 1 do
    begin
      S := TBrowserManagedSession(GSessions[I]);
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
    GSessionLock.Leave;
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
begin
  Lock.Enter;
  try
    if Assigned(PageSession) then
      PageSession.ClosePage(nil);
    PageSession.Free;
    Navigator.Free;
    Guard.Free;
    EventCtx.Free;
    ConsoleLog.Free;
    NetworkLog.Free;
    RefMap.Free;
    if Assigned(Connection) then
      Connection.Free;
    Socket.Free;
    Browser.Free;
  finally
    Lock.Leave;
  end;
  Lock.Free;
  inherited Destroy;
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
  WaitMs := Config.MaxTimeoutMs;
  if WaitMs < 1000 then
    WaitMs := 60000;
  if WaitMs > 120000 then
    WaitMs := 120000;
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
    'Close other sessions with browser_close or retry later.', [GMaxConcurrent]);
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
  I: Integer;
  S: TBrowserManagedSession;
  Cutoff: TDateTime;
  Purged: Boolean;
begin
  if GSessionLock = nil then Exit;
  Purged := False;
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
        S.Free;
        BrowserManagerRelease;
        Purged := True;
      end;
    end;
  finally
    GSessionLock.Leave;
  end;
  if Purged then
    MaybeStopBrowserCdpPump;
end;

procedure BrowserManagerShutdownAll;
var
  I, N: Integer;
begin
  StopBrowserCdpPump;
  if GSessionLock = nil then Exit;
  GSessionLock.Enter;
  try
    N := GSessions.Count;
    for I := GSessions.Count - 1 downto 0 do
      TBrowserManagedSession(GSessions[I]).Free;
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
    Session.Free;
    Session := nil;
    BrowserManagerRelease;
  end;
end;

function BrowserSessionClose(const SessionId: string;
  CancelCheck: TBrowserReadCancelCheck): Boolean;
var
  I: Integer;
  S: TBrowserManagedSession;
  Closed: Boolean;
begin
  Result := False;
  Closed := False;
  if GSessionLock = nil then Exit;
  GSessionLock.Enter;
  try
    for I := 0 to GSessions.Count - 1 do
    begin
      S := TBrowserManagedSession(GSessions[I]);
      if SameText(S.Id, SessionId) then
      begin
        GSessions.Delete(I);
        S.Free;
        BrowserManagerRelease;
        Closed := True;
        Result := True;
        Break;
      end;
    end;
  finally
    GSessionLock.Leave;
  end;
  if Closed then
    MaybeStopBrowserCdpPump;
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
