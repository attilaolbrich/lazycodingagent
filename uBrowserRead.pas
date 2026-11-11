unit uBrowserRead;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson, uBrowserReadTypes;

function BrowserReadContent(const Url: string; const Format: string;
  Strategy: TBrowserReadWaitStrategy; const WaitSelector: string;
  TimeoutMs, MaxLength: Integer; const WorkspaceRoot: string;
  const Config: TBrowserReadConfig; CancelCheck: TBrowserReadCancelCheck): TBrowserReadResult;

function BrowserReadResultToJson(const R: TBrowserReadResult): string;

function ParseBrowserWebSocketEndpoint(const Url: string; out Host: string;
  out Port: Word; out Path: string): Boolean;

implementation

uses
  DateUtils, Classes, Math,
  uBrowserDiscovery, uBrowserProcess, uCdpWebSocket, uCdpConnection,
  uBrowserSession, uBrowserNetworkGuard, uBrowserNavigate,
  uBrowserContentExtract, uBrowserReadUrl, uBrowserManager;

type
  TReadContext = class
  public
    NetGuard: TBrowserNetworkGuard;
    PageNav: TBrowserNavigator;
    procedure OnCdpEvent(Sender: TObject; const Method, ParamsJson: AnsiString);
  end;

procedure TReadContext.OnCdpEvent(Sender: TObject; const Method, ParamsJson: AnsiString);
begin
  if Assigned(NetGuard) then
    NetGuard.HandleEvent(Method, ParamsJson);
  if Assigned(PageNav) then
    PageNav.HandleEvent(Method, ParamsJson);
end;

function ParseBrowserWebSocketEndpoint(const Url: string; out Host: string;
  out Port: Word; out Path: string): Boolean;
var
  S: string;
  P: SizeInt;
begin
  Host := '';
  Port := 0;
  Path := '/';
  S := Url;
  if not SameText(Copy(S, 1, 5), 'ws://') then Exit(False);
  Delete(S, 1, 5);
  P := Pos('/', S);
  if P > 0 then
  begin
    Path := Copy(S, P, MaxInt);
    S := Copy(S, 1, P - 1);
  end;
  P := Pos(':', S);
  if P > 0 then
  begin
    Host := Copy(S, 1, P - 1);
    Port := StrToIntDef(Copy(S, P + 1, MaxInt), 0);
  end
  else
  begin
    Host := S;
    Port := 80;
  end;
  if SameText(Host, 'localhost') then
    Host := '127.0.0.1';
  Result := (Host <> '') and (Port > 0) and (Host = '127.0.0.1');
end;

function BrowserReadContent(const Url: string; const Format: string;
  Strategy: TBrowserReadWaitStrategy; const WaitSelector: string;
  TimeoutMs, MaxLength: Integer; const WorkspaceRoot: string;
  const Config: TBrowserReadConfig; CancelCheck: TBrowserReadCancelCheck): TBrowserReadResult;
var
  Start: QWord;
  Executable, WsUrl, Host, Path, FinalUrl, Content: string;
  Port: Word;
  Browser: TBrowserProcess;
  Socket: TCdpWebSocket;
  Transport: ICdpTransport;
  Connection: TCdpConnection;
  Session: TBrowserSession;
  Guard: TBrowserNetworkGuard;
  Navigator: TBrowserNavigator;
  Ctx: TReadContext;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
  Truncated: Boolean;
  Title: string;
  Deadline: QWord;
begin
  InitBrowserReadResult(Result);
  Result.Url := Trim(Url);
  Result.Format := Format;
  Start := GetTickCount64;
  Deadline := Start + QWord(TimeoutMs);

  if not ValidateBrowserReadUrl(Url, Config.AllowLocalhost, WorkspaceRoot, ErrKind,
    ErrMsg) then
  begin
    Result.ErrorKind := ErrKind;
    Result.ErrorMessage := ErrMsg;
    Exit;
  end;

  if Strategy = brwsSelector then
  begin
    if Trim(WaitSelector) = '' then
    begin
      Result.ErrorKind := brekInvalidArgument;
      Result.ErrorMessage := 'wait_selector is required when wait_strategy is selector';
      Exit;
    end;
  end;

  if not DiscoverChromiumExecutable(Config, Executable, ErrMsg) then
  begin
    Result.ErrorKind := brekBrowserNotFound;
    Result.ErrorMessage := ErrMsg;
    Exit;
  end;

  if not BrowserManagerTryAcquire(Config, CancelCheck, ErrMsg) then
  begin
    Result.ErrorKind := brekInternal;
    if Trim(ErrMsg) = '' then
      Result.ErrorMessage := 'Could not acquire browser slot'
    else
      Result.ErrorMessage := ErrMsg;
    Exit;
  end;
  Browser := TBrowserProcess.Create;
  Socket := TCdpWebSocket.Create;
  Connection := nil;
  Session := nil;
  Guard := nil;
  Navigator := nil;
  Ctx := nil;
  try
    if Assigned(CancelCheck) and CancelCheck() then
    begin
      Result.ErrorKind := brekCancelled;
      Result.ErrorMessage := 'Cancelled';
      Exit;
    end;

    if not Browser.Start(Executable, TimeoutMs, True, CancelCheck, WsUrl, ErrKind,
      ErrMsg) then
    begin
      Result.ErrorKind := ErrKind;
      Result.ErrorMessage := ErrMsg;
      Exit;
    end;

    if not ParseBrowserWebSocketEndpoint(WsUrl, Host, Port, Path) then
    begin
      Result.ErrorKind := brekCdpConnectionFailed;
      Result.ErrorMessage := 'Invalid debugger WebSocket URL';
      Exit;
    end;

    if not Socket.Connect(Host, Port, Path, Min(TimeoutMs, 15000), ErrMsg) then
    begin
      Result.ErrorKind := brekCdpConnectionFailed;
      if Trim(ErrMsg) <> '' then
        Result.ErrorMessage := 'WebSocket connection to browser failed: ' + ErrMsg
      else
        Result.ErrorMessage := 'WebSocket connection to browser failed';
      Exit;
    end;

    Transport := TCdpWebSocketTransport.Create(Socket);
    Connection := TCdpConnection.Create(Transport);
    Guard := TBrowserNetworkGuard.Create(Connection, Config.AllowLocalhost, WorkspaceRoot);
    Navigator := TBrowserNavigator.Create(Connection);
    Ctx := TReadContext.Create;
    Ctx.NetGuard := Guard;
    Ctx.PageNav := Navigator;
    Connection.Tag := PtrUInt(Ctx);
    Connection.OnEvent := @Ctx.OnCdpEvent;

    Session := TBrowserSession.Create(Connection);
    if not Session.OpenBlankPage(CancelCheck, ErrKind, ErrMsg) then
    begin
      Result.ErrorKind := ErrKind;
      Result.ErrorMessage := ErrMsg;
      Exit;
    end;

    if not Guard.Enable(CancelCheck) then
    begin
      Result.ErrorKind := brekCdpConnectionFailed;
      Result.ErrorMessage := 'Fetch.enable failed';
      Exit;
    end;

    if not Navigator.Navigate(Url, Strategy, WaitSelector, Deadline, CancelCheck,
      FinalUrl, ErrKind, ErrMsg) then
    begin
      Result.ErrorKind := ErrKind;
      Result.ErrorMessage := ErrMsg;
      Exit;
    end;

    if not ValidateBrowserReadUrl(FinalUrl, Config.AllowLocalhost, WorkspaceRoot, ErrKind,
      ErrMsg) then
    begin
      Result.ErrorKind := brekAccessDenied;
      Result.ErrorMessage := 'Final URL is not allowed: ' + ErrMsg;
      Exit;
    end;

    if not ExtractRenderedContent(Connection, Format, MaxLength, Deadline, CancelCheck,
      Title, Content, Truncated, ErrKind, ErrMsg) then
    begin
      Result.ErrorKind := ErrKind;
      Result.ErrorMessage := ErrMsg;
      Exit;
    end;

    Result.Success := True;
    Result.FinalUrl := FinalUrl;
    Result.Title := Title;
    Result.Content := Content;
    Result.Truncated := Truncated;
    Result.Rendered := True;
  finally
    if Assigned(Session) then
      Session.ClosePage(CancelCheck);
    if Assigned(Ctx) then
      Ctx.Free;
    Session.Free;
    Navigator.Free;
    Guard.Free;
    if Assigned(Connection) then
      Connection.Free;
    Socket.Free;
    Browser.Free;
    BrowserManagerRelease;
    Result.ElapsedMs := GetTickCount64 - Start;
  end;
end;

function BrowserReadResultToJson(const R: TBrowserReadResult): string;
var
  O: TJSONObject;
begin
  O := TJSONObject.Create;
  try
    O.Add('success', R.Success);
    if R.Success then
    begin
      O.Add('url', R.Url);
      O.Add('final_url', R.FinalUrl);
      if R.Title <> '' then
        O.Add('title', R.Title);
      O.Add('format', R.Format);
      O.Add('content', R.Content);
      O.Add('truncated', R.Truncated);
      O.Add('rendered', R.Rendered);
      O.Add('elapsed_ms', R.ElapsedMs);
    end
    else
    begin
      O.Add('error', R.ErrorMessage);
      if BrowserReadErrorKindToCode(R.ErrorKind) <> '' then
        O.Add('error_code', BrowserReadErrorKindToCode(R.ErrorKind));
      if R.Url <> '' then
        O.Add('url', R.Url);
      if R.ElapsedMs > 0 then
        O.Add('elapsed_ms', R.ElapsedMs);
    end;
    Result := O.AsJSON;
  finally
    O.Free;
  end;
end;

end.
