unit uBrowserNavigate;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson, uCdpConnection, uBrowserReadTypes;

type
  TBrowserNavigator = class
  private
    FConnection: TCdpConnection;
    FDomContentLoaded: Boolean;
    FDomContentLoadedTick: QWord;
    FLoadEventFired: Boolean;
    FNavFailed: Boolean;
    FNavErrorText: string;
    function EvaluateBoolExpression(const Expr: string; TimeoutMs: Integer;
      CancelCheck: TBrowserReadCancelCheck): Boolean;
  public
    constructor Create(AConnection: TCdpConnection);
    procedure HandleEvent(const Method, ParamsJson: AnsiString);
    function Navigate(const Url: string; Strategy: TBrowserReadWaitStrategy;
      const WaitSelector: string; DeadlineTick: QWord;
      CancelCheck: TBrowserReadCancelCheck; out FinalUrl: string;
      out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
    function EvaluateString(const Expr: string; TimeoutMs: Integer;
      CancelCheck: TBrowserReadCancelCheck): string;
  end;

implementation

uses
  DateUtils, Classes, Math;

constructor TBrowserNavigator.Create(AConnection: TCdpConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

procedure TBrowserNavigator.HandleEvent(const Method, ParamsJson: AnsiString);
var
  Params: TJSONObject;
begin
  if Method = 'Page.domContentEventFired' then
  begin
    if not FDomContentLoaded then
    begin
      FDomContentLoaded := True;
      FDomContentLoadedTick := GetTickCount64;
    end;
  end
  else if Method = 'Page.loadEventFired' then
    FLoadEventFired := True
  else if Method = 'Page.frameStoppedLoading' then
  begin
    Params := TJSONObject(GetJSON(ParamsJson));
    try
      // navigation failure hints
    finally
      Params.Free;
    end;
  end;
end;

function TBrowserNavigator.EvaluateString(const Expr: string; TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck): string;
var
  Params, ResultObj, RemoteObj, Val: TJSONObject;
  ExprEsc: string;
begin
  Result := '';
  Params := TJSONObject.Create;
  try
    ExprEsc := StringReplace(Expr, '\', '\\', [rfReplaceAll]);
    ExprEsc := StringReplace(ExprEsc, '"', '\"', [rfReplaceAll]);
    Params.Add('expression', Expr);
    Params.Add('returnByValue', True);
    if not FConnection.SendCommand('Runtime.evaluate', Params, TimeoutMs, CancelCheck, ResultObj) then
      Exit;
    try
      if ResultObj.Find('result') = nil then Exit;
      Val := TJSONObject(ResultObj.Find('result'));
      if Val.Find('value') <> nil then
        Result := Val.Get('value', '');
    finally
      ResultObj.Free;
    end;
  finally
    Params.Free;
  end;
end;

function TBrowserNavigator.EvaluateBoolExpression(const Expr: string; TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck): Boolean;
var
  S: string;
begin
  S := EvaluateString(Expr, Min(TimeoutMs, 5000), CancelCheck);
  Result := SameText(S, 'true');
end;

function TBrowserNavigator.Navigate(const Url: string; Strategy: TBrowserReadWaitStrategy;
  const WaitSelector: string; DeadlineTick: QWord;
  CancelCheck: TBrowserReadCancelCheck; out FinalUrl: string;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  Params, ResultObj: TJSONObject;
  SelectorExpr: string;
  SelEsc: string;
  CmdTimeout: Integer;
begin
  FinalUrl := '';
  ErrKind := brekNone;
  ErrMsg := '';
  FDomContentLoaded := False;
  FDomContentLoadedTick := 0;
  FLoadEventFired := False;
  FNavFailed := False;

  if BrowserReadRemainingMs(DeadlineTick) <= 0 then
  begin
    ErrKind := brekNavigationTimeout;
    ErrMsg := 'Navigation timed out';
    Exit(False);
  end;

  CmdTimeout := BrowserReadEvalTimeoutMs(DeadlineTick);
  if CmdTimeout <= 0 then
    CmdTimeout := 1000;

  Params := TJSONObject.Create;
  try
    Params.Add('url', Url);
    if not FConnection.SendCommand('Page.navigate', Params, CmdTimeout, CancelCheck, ResultObj) then
    begin
      ErrKind := brekNavigationFailed;
      ErrMsg := 'Page.navigate failed';
      Exit(False);
    end;
    try
      if ResultObj.Find('errorText') <> nil then
      begin
        ErrKind := brekNavigationFailed;
        ErrMsg := ResultObj.Get('errorText', 'Navigation failed');
        Exit(False);
      end;
    finally
      ResultObj.Free;
    end;
  finally
    Params.Free;
  end;

  while BrowserReadRemainingMs(DeadlineTick) > 0 do
  begin
    if Assigned(CancelCheck) and CancelCheck() then
    begin
      ErrKind := brekCancelled;
      ErrMsg := 'Cancelled';
      Exit(False);
    end;
    FConnection.DrainEvents(32, CancelCheck);

    case Strategy of
      brwsDomContentLoaded:
        if FDomContentLoaded then Break;
      brwsLoad:
        if FLoadEventFired then Break
        else if FDomContentLoaded and (FDomContentLoadedTick > 0) and
          (GetTickCount64 - FDomContentLoadedTick >= QWord(BROWSER_LOAD_GRACE_AFTER_DOM_MS)) then
          Break;
      brwsSelector:
        begin
          SelEsc := StringReplace(WaitSelector, '\', '\\', [rfReplaceAll]);
          SelEsc := StringReplace(SelEsc, '"', '\"', [rfReplaceAll]);
          SelectorExpr := '(() => { try { return document.querySelector("' + SelEsc +
            '") !== null; } catch(e) { return false; } })()';
          if EvaluateBoolExpression(SelectorExpr,
            Min(2000, BrowserReadRemainingMs(DeadlineTick)), CancelCheck) then
            Break;
        end;
    end;
    Sleep(50);
  end;

  if BrowserReadRemainingMs(DeadlineTick) <= 0 then
  begin
    if Strategy = brwsSelector then
    begin
      ErrKind := brekSelectorTimeout;
      ErrMsg := 'Timed out waiting for selector';
    end
    else
    begin
      ErrKind := brekNavigationTimeout;
      ErrMsg := 'Navigation timed out';
    end;
    Exit(False);
  end;

  CmdTimeout := BrowserReadEvalTimeoutMs(DeadlineTick);
  if CmdTimeout <= 0 then CmdTimeout := 1000;
  FinalUrl := EvaluateString('location.href', Min(5000, CmdTimeout), CancelCheck);
  Result := True;
end;

end.
