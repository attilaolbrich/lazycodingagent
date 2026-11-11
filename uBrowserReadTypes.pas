unit uBrowserReadTypes;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  BROWSER_READ_DEFAULT_FORMAT = 'markdown';
  BROWSER_READ_DEFAULT_WAIT_STRATEGY = 'domcontentloaded';
  BROWSER_READ_DEFAULT_TIMEOUT_MS = 30000;
  BROWSER_LOAD_GRACE_AFTER_DOM_MS = 8000;
  BROWSER_CDP_EVAL_TIMEOUT_CAP_MS = 15000;
  BROWSER_JS_SETTLE_MAX_MS = 3000;
  BROWSER_READ_MAX_TIMEOUT_MS = 120000;
  BROWSER_READ_DEFAULT_MAX_LENGTH = 20000;
  BROWSER_READ_MAX_MAX_LENGTH = 100000;
  BROWSER_READ_DEFAULT_MAX_CONCURRENT = 1;
  BROWSER_DEFAULT_MAX_SESSIONS = 4;
  BROWSER_DEFAULT_IDLE_TIMEOUT_MS = 300000;
  BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS = 30000;

type
  TBrowserReadWaitStrategy = (
    brwsDomContentLoaded,
    brwsLoad,
    brwsSelector
  );

  TBrowserReadErrorKind = (
    brekNone,
    brekBrowserNotFound,
    brekBrowserStartFailed,
    brekCdpConnectionFailed,
    brekNavigationFailed,
    brekNavigationTimeout,
    brekSelectorTimeout,
    brekAccessDenied,
    brekContentExtractionFailed,
    brekBrowserCrashed,
    brekCancelled,
    brekInvalidUrl,
    brekInvalidArgument,
    brekInternal,
    brekSessionNotFound,
    brekAmbiguousSelector,
    brekElementNotFound,
    brekElementNotInteractable,
    brekUserDenied
  );

  TBrowserReadConfig = record
    ExecutablePath: string;
    MaxConcurrent: Integer;
    MaxSessions: Integer;
    IdleTimeoutMs: Integer;
    MaxTimeoutMs: Integer;
    MaxMaxLength: Integer;
    AllowLocalhost: Boolean;
  end;

  TBrowserReadCancelCheck = function: Boolean of object;

  TBrowserReadResult = record
    Success: Boolean;
    Url: string;
    FinalUrl: string;
    Title: string;
    Format: string;
    Content: string;
    Truncated: Boolean;
    Rendered: Boolean;
    ElapsedMs: Int64;
    ErrorKind: TBrowserReadErrorKind;
    ErrorMessage: string;
  end;

function DefaultBrowserReadConfig: TBrowserReadConfig;
function BrowserReadErrorKindToCode(AKind: TBrowserReadErrorKind): string;
procedure InitBrowserReadResult(out R: TBrowserReadResult);
function ParseBrowserReadWaitStrategy(const S: string;
  out Strategy: TBrowserReadWaitStrategy): Boolean;
function ParseBrowserReadFormat(const S: string; out Fmt: string): Boolean;
function BrowserReadRemainingMs(DeadlineTick: QWord): Integer;
function BrowserReadEvalTimeoutMs(DeadlineTick: QWord): Integer;

implementation

function BrowserReadRemainingMs(DeadlineTick: QWord): Integer;
var
  Now: QWord;
  Rem: QWord;
begin
  Now := GetTickCount64;
  if DeadlineTick <= Now then
    Exit(0);
  Rem := DeadlineTick - Now;
  if Rem > High(Integer) then
    Result := High(Integer)
  else
    Result := Integer(Rem);
end;

function BrowserReadEvalTimeoutMs(DeadlineTick: QWord): Integer;
begin
  Result := BrowserReadRemainingMs(DeadlineTick);
  if Result <= 0 then
    Exit(0);
  if Result > BROWSER_CDP_EVAL_TIMEOUT_CAP_MS then
    Result := BROWSER_CDP_EVAL_TIMEOUT_CAP_MS;
end;


function DefaultBrowserReadConfig: TBrowserReadConfig;
begin
  Result.ExecutablePath := '';
  Result.MaxConcurrent := BROWSER_READ_DEFAULT_MAX_CONCURRENT;
  Result.MaxSessions := BROWSER_DEFAULT_MAX_SESSIONS;
  Result.IdleTimeoutMs := BROWSER_DEFAULT_IDLE_TIMEOUT_MS;
  Result.MaxTimeoutMs := BROWSER_READ_MAX_TIMEOUT_MS;
  Result.MaxMaxLength := BROWSER_READ_MAX_MAX_LENGTH;
  Result.AllowLocalhost := False;
end;

function BrowserReadErrorKindToCode(AKind: TBrowserReadErrorKind): string;
begin
  case AKind of
    brekBrowserNotFound: Result := 'BROWSER_NOT_FOUND';
    brekBrowserStartFailed: Result := 'BROWSER_START_FAILED';
    brekCdpConnectionFailed: Result := 'CDP_CONNECTION_FAILED';
    brekNavigationFailed: Result := 'NAVIGATION_FAILED';
    brekNavigationTimeout: Result := 'NAVIGATION_TIMEOUT';
    brekSelectorTimeout: Result := 'SELECTOR_TIMEOUT';
    brekAccessDenied: Result := 'ACCESS_DENIED';
    brekContentExtractionFailed: Result := 'CONTENT_EXTRACTION_FAILED';
    brekBrowserCrashed: Result := 'BROWSER_CRASHED';
    brekCancelled: Result := 'CANCELLED';
    brekInvalidUrl: Result := 'INVALID_URL';
    brekInvalidArgument: Result := 'INVALID_ARGUMENT';
    brekInternal: Result := 'INTERNAL';
    brekSessionNotFound: Result := 'SESSION_NOT_FOUND';
    brekAmbiguousSelector: Result := 'AMBIGUOUS_SELECTOR';
    brekElementNotFound: Result := 'ELEMENT_NOT_FOUND';
    brekElementNotInteractable: Result := 'ELEMENT_NOT_INTERACTABLE';
    brekUserDenied: Result := 'USER_DENIED';
  else
    Result := '';
  end;
end;

procedure InitBrowserReadResult(out R: TBrowserReadResult);
begin
  R.Success := False;
  R.Url := '';
  R.FinalUrl := '';
  R.Title := '';
  R.Format := '';
  R.Content := '';
  R.Truncated := False;
  R.Rendered := False;
  R.ElapsedMs := 0;
  R.ErrorKind := brekNone;
  R.ErrorMessage := '';
end;

function ParseBrowserReadWaitStrategy(const S: string;
  out Strategy: TBrowserReadWaitStrategy): Boolean;
var
  L: string;
begin
  L := LowerCase(Trim(S));
  if L = '' then
  begin
    Strategy := brwsLoad;
    Exit(True);
  end;
  if L = 'domcontentloaded' then
  begin
    Strategy := brwsDomContentLoaded;
    Exit(True);
  end;
  if L = 'load' then
  begin
    Strategy := brwsLoad;
    Exit(True);
  end;
  if L = 'selector' then
  begin
    Strategy := brwsSelector;
    Exit(True);
  end;
  Result := False;
end;

function ParseBrowserReadFormat(const S: string; out Fmt: string): Boolean;
var
  L: string;
begin
  L := LowerCase(Trim(S));
  if L = '' then
  begin
    Fmt := BROWSER_READ_DEFAULT_FORMAT;
    Exit(True);
  end;
  if (L = 'markdown') or (L = 'text') or (L = 'html') then
  begin
    Fmt := L;
    Exit(True);
  end;
  Result := False;
end;

end.
