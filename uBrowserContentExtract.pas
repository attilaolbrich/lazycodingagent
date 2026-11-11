unit uBrowserContentExtract;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uCdpConnection, uBrowserReadTypes, uWebFetchTypes;

function ExtractRenderedContent(AConnection: TCdpConnection; const Format: string;
  MaxLength: Integer; DeadlineTick: QWord; CancelCheck: TBrowserReadCancelCheck;
  out Title, Content: string; out Truncated: Boolean;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;

implementation

uses
  fpjson, uWebContentExtract;

function CdpEvaluateAwaitPromise(AConnection: TCdpConnection; const Expr: string;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck): Boolean;
var
  Params, ResultObj: TJSONObject;
begin
  Result := False;
  if TimeoutMs <= 0 then Exit;
  Params := TJSONObject.Create;
  try
    Params.Add('expression', Expr);
    Params.Add('awaitPromise', True);
    Params.Add('returnByValue', True);
    if not AConnection.SendCommand('Runtime.evaluate', Params, TimeoutMs, CancelCheck, ResultObj) then
      Exit;
    try
      if ResultObj.Find('exceptionDetails') <> nil then
        Exit;
      Result := True;
    finally
      ResultObj.Free;
    end;
  finally
    Params.Free;
  end;
end;

function CdpEvaluate(AConnection: TCdpConnection; const Expr: string; TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck): string;
var
  Params, ResultObj, Val: TJSONObject;
begin
  Result := '';
  Params := TJSONObject.Create;
  try
    Params.Add('expression', Expr);
    Params.Add('returnByValue', True);
    if not AConnection.SendCommand('Runtime.evaluate', Params, TimeoutMs, CancelCheck, ResultObj) then
      Exit;
    try
      if ResultObj.Find('exceptionDetails') <> nil then
        Exit;
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

function ExtractRenderedContent(AConnection: TCdpConnection; const Format: string;
  MaxLength: Integer; DeadlineTick: QWord; CancelCheck: TBrowserReadCancelCheck;
  out Title, Content: string; out Truncated: Boolean;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  HtmlBody, TextBody, Fmt: string;
  WfKind: TWebFetchErrorKind;
  EvalTimeout, SettleTimeout: Integer;
const
  JsSettleExpr =
    '(function(){return new Promise(function(r){' +
    'function done(){r(true);}' +
    'if(document.readyState==="complete"){' +
    'requestAnimationFrame(function(){requestAnimationFrame(done);});return;}' +
    'var t=Date.now();' +
    '(function poll(){if(document.readyState==="complete"){done();return;}' +
    'if(Date.now()-t>2500){done();return;}setTimeout(poll,50);})();' +
    '});})()';
begin
  Title := '';
  Content := '';
  Truncated := False;
  ErrKind := brekNone;
  ErrMsg := '';

  if BrowserReadRemainingMs(DeadlineTick) < 500 then
  begin
    ErrKind := brekNavigationTimeout;
    ErrMsg := 'Timed out before content extraction';
    Exit(False);
  end;

  SettleTimeout := BrowserReadRemainingMs(DeadlineTick);
  if SettleTimeout > BROWSER_JS_SETTLE_MAX_MS then
    SettleTimeout := BROWSER_JS_SETTLE_MAX_MS;
  if SettleTimeout >= 500 then
    CdpEvaluateAwaitPromise(AConnection, JsSettleExpr, SettleTimeout, CancelCheck);

  EvalTimeout := BrowserReadEvalTimeoutMs(DeadlineTick);
  if EvalTimeout <= 0 then
  begin
    ErrKind := brekNavigationTimeout;
    ErrMsg := 'Timed out before content extraction';
    Exit(False);
  end;

  Title := CdpEvaluate(AConnection, 'document.title || ""', EvalTimeout, CancelCheck);
  EvalTimeout := BrowserReadEvalTimeoutMs(DeadlineTick);
  if EvalTimeout <= 0 then
  begin
    ErrKind := brekNavigationTimeout;
    ErrMsg := 'Timed out during content extraction';
    Exit(False);
  end;
  HtmlBody := CdpEvaluate(AConnection,
    'document.documentElement ? document.documentElement.outerHTML : ""',
    EvalTimeout, CancelCheck);
  EvalTimeout := BrowserReadEvalTimeoutMs(DeadlineTick);
  if EvalTimeout <= 0 then
  begin
    ErrKind := brekNavigationTimeout;
    ErrMsg := 'Timed out during content extraction';
    Exit(False);
  end;
  TextBody := CdpEvaluate(AConnection,
    'document.body ? document.body.innerText : ""',
    EvalTimeout, CancelCheck);

  if (HtmlBody = '') and (TextBody = '') then
  begin
    ErrKind := brekContentExtractionFailed;
    ErrMsg := 'No content extracted from page';
    Exit(False);
  end;

  Fmt := LowerCase(Format);
  if Fmt = 'html' then
    Content := HtmlBody
  else if Fmt = 'text' then
    Content := TextBody
  else
  begin
    if not ExtractWebContent(RawByteString(UTF8Encode(HtmlBody)), 'text/html',
      'markdown', MaxLength, Title, Content, Truncated, WfKind, ErrMsg) then
    begin
      ErrKind := brekContentExtractionFailed;
      if WfKind <> wfekNone then
        ErrMsg := 'Content extraction failed: ' + ErrMsg;
      Exit(False);
    end;
  end;

  if (Fmt = 'html') or (Fmt = 'text') then
  begin
    if Length(Content) > MaxLength then
    begin
      SetLength(Content, MaxLength);
      Truncated := True;
    end;
  end;

  Result := True;
end;

end.
