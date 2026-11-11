unit uWebFetchTypes;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  WEB_FETCH_USER_AGENT =
    'Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0';
  WEB_FETCH_DEFAULT_FORMAT = 'markdown';
  WEB_FETCH_DEFAULT_MAX_LENGTH = 20000;
  WEB_FETCH_CONNECT_TIMEOUT_MS = 10000;
  WEB_FETCH_REQUEST_TIMEOUT_MS = 30000;
  WEB_FETCH_MAX_REDIRECTS = 5;
  WEB_FETCH_MAX_BODY_BYTES = 5 * 1024 * 1024;

type
  TWebFetchErrorKind = (
    wfekNone,
    wfekInvalidUrl,
    wfekBlockedDestination,
    wfekDnsFailure,
    wfekTlsFailure,
    wfekTimeout,
    wfekHttpError,
    wfekUnsupportedContentType,
    wfekContentTooLarge,
    wfekTooManyRedirects,
    wfekCancelled,
    wfekInternal
  );

  TWebFetchConfig = record
    ConnectTimeoutMs: Integer;
    RequestTimeoutMs: Integer;
    MaxRedirects: Integer;
    MaxBodyBytes: Integer;
  end;

  TWebFetchResult = record
    Success: Boolean;
    Url: string;
    FinalUrl: string;
    Title: string;
    ContentType: string;
    Format: string;
    Content: string;
    Truncated: Boolean;
    HttpStatus: Integer;
    ErrorKind: TWebFetchErrorKind;
    ErrorMessage: string;
  end;

  TWebFetchCancelCheck = function: Boolean;

  THttpFetchResponse = record
    StatusCode: Integer;
    ContentType: string;
    Body: RawByteString;
    Location: string;
  end;

function DefaultWebFetchConfig: TWebFetchConfig;
function WebFetchErrorKindToCode(AKind: TWebFetchErrorKind): string;
procedure InitWebFetchResult(out R: TWebFetchResult);

implementation

function DefaultWebFetchConfig: TWebFetchConfig;
begin
  Result.ConnectTimeoutMs := WEB_FETCH_CONNECT_TIMEOUT_MS;
  Result.RequestTimeoutMs := WEB_FETCH_REQUEST_TIMEOUT_MS;
  Result.MaxRedirects := WEB_FETCH_MAX_REDIRECTS;
  Result.MaxBodyBytes := WEB_FETCH_MAX_BODY_BYTES;
end;

function WebFetchErrorKindToCode(AKind: TWebFetchErrorKind): string;
begin
  case AKind of
    wfekInvalidUrl: Result := 'invalid_url';
    wfekBlockedDestination: Result := 'blocked_destination';
    wfekDnsFailure: Result := 'dns_failure';
    wfekTlsFailure: Result := 'tls_failure';
    wfekTimeout: Result := 'timeout';
    wfekHttpError: Result := 'http_error';
    wfekUnsupportedContentType: Result := 'unsupported_content_type';
    wfekContentTooLarge: Result := 'content_too_large';
    wfekTooManyRedirects: Result := 'too_many_redirects';
    wfekCancelled: Result := 'cancelled';
    wfekInternal: Result := 'internal';
  else
    Result := '';
  end;
end;

procedure InitWebFetchResult(out R: TWebFetchResult);
begin
  R.Success := False;
  R.Url := '';
  R.FinalUrl := '';
  R.Title := '';
  R.ContentType := '';
  R.Format := '';
  R.Content := '';
  R.Truncated := False;
  R.HttpStatus := 0;
  R.ErrorKind := wfekNone;
  R.ErrorMessage := '';
end;

end.
