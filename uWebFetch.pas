unit uWebFetch;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uWebFetchTypes, uWebFetchUrl, uWebFetchHttp, uWebContentExtract;

type
  IWebFetchTransport = interface
    function Fetch(const RequestUrl: string; const Parsed: TWebFetchUrl;
      const ConnectIP, VHost: string; const Config: TWebFetchConfig;
      CancelCheck: TWebFetchCancelCheck; out Resp: THttpFetchResponse;
      out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;
  end;

  TWebFetchProductionTransport = class(TInterfacedObject, IWebFetchTransport)
  public
    function Fetch(const RequestUrl: string; const Parsed: TWebFetchUrl;
      const ConnectIP, VHost: string; const Config: TWebFetchConfig;
      CancelCheck: TWebFetchCancelCheck; out Resp: THttpFetchResponse;
      out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;
  end;

function FetchWebContent(const Url, Format: string; MaxLength: Integer;
  const Config: TWebFetchConfig; CancelCheck: TWebFetchCancelCheck;
  ATransport: IWebFetchTransport): TWebFetchResult;

function WebFetchResultToJson(const R: TWebFetchResult): string;

implementation

uses
  fpjson;

function FetchWebContent(const Url, Format: string; MaxLength: Integer;
  const Config: TWebFetchConfig; CancelCheck: TWebFetchCancelCheck;
  ATransport: IWebFetchTransport): TWebFetchResult;
var
  Parsed: TWebFetchUrl;
  CurrentUrl, ConnectIP, NextUrl: string;
  Resp: THttpFetchResponse;
  ErrKind: TWebFetchErrorKind;
  ErrMsg: string;
  Redirects: Integer;
  Transport: IWebFetchTransport;
  Fmt: string;
begin
  InitWebFetchResult(Result);
  Result.Url := Trim(Url);
  Result.Format := Format;
  if MaxLength <= 0 then
    MaxLength := WEB_FETCH_DEFAULT_MAX_LENGTH;

  if Assigned(ATransport) then
    Transport := ATransport
  else
    Transport := TWebFetchProductionTransport.Create;

  if not ParseWebFetchUrl(Url, Parsed, ErrKind, ErrMsg) then
  begin
    Result.ErrorKind := ErrKind;
    Result.ErrorMessage := ErrMsg;
    Exit;
  end;

  if not ValidateWebFetchTarget(Parsed, ErrKind, ErrMsg) then
  begin
    Result.ErrorKind := ErrKind;
    Result.ErrorMessage := ErrMsg;
    Exit;
  end;

  CurrentUrl := Parsed.OriginalUrl;
  Redirects := 0;

  while True do
  begin
    if Assigned(CancelCheck) and CancelCheck() then
    begin
      Result.ErrorKind := wfekCancelled;
      Result.ErrorMessage := 'Request cancelled';
      Exit;
    end;

    if not ParseWebFetchUrl(CurrentUrl, Parsed, ErrKind, ErrMsg) then
    begin
      Result.ErrorKind := ErrKind;
      Result.ErrorMessage := ErrMsg;
      Exit;
    end;

    if not SelectConnectAddress(Parsed, ConnectIP, ErrKind, ErrMsg) then
    begin
      Result.ErrorKind := ErrKind;
      Result.ErrorMessage := ErrMsg;
      Exit;
    end;

    if not Transport.Fetch(CurrentUrl, Parsed, ConnectIP, Parsed.Host, Config, CancelCheck,
      Resp, ErrKind, ErrMsg) then
    begin
      Result.ErrorKind := ErrKind;
      Result.ErrorMessage := ErrMsg;
      Exit;
    end;

    Result.FinalUrl := CurrentUrl;
    Result.HttpStatus := Resp.StatusCode;
    Result.ContentType := Resp.ContentType;

    if (Resp.StatusCode >= 300) and (Resp.StatusCode < 400) then
    begin
      Inc(Redirects);
      if Redirects > Config.MaxRedirects then
      begin
        Result.ErrorKind := wfekTooManyRedirects;
        Result.ErrorMessage := 'Too many redirects';
        Exit;
      end;
      if Trim(Resp.Location) = '' then
      begin
        Result.ErrorKind := wfekHttpError;
        Result.ErrorMessage := 'Redirect without location';
        Result.HttpStatus := Resp.StatusCode;
        Exit;
      end;
      if not ResolveRedirectUrl(CurrentUrl, Resp.Location, NextUrl, ErrKind, ErrMsg) then
      begin
        Result.ErrorKind := ErrKind;
        Result.ErrorMessage := ErrMsg;
        Exit;
      end;
      CurrentUrl := NextUrl;
      Continue;
    end;

    if (Resp.StatusCode < 200) or (Resp.StatusCode >= 300) then
    begin
      Result.ErrorKind := wfekHttpError;
      if Resp.StatusCode > 0 then
        Result.ErrorMessage := 'HTTP ' + IntToStr(Resp.StatusCode)
      else
        Result.ErrorMessage := 'HTTP error';
      Result.HttpStatus := Resp.StatusCode;
      Exit;
    end;

    Fmt := Format;
    if Fmt = '' then Fmt := WEB_FETCH_DEFAULT_FORMAT;
    if not ExtractWebContent(Resp.Body, Resp.ContentType, Fmt, MaxLength,
      Result.Title, Result.Content, Result.Truncated, ErrKind, ErrMsg) then
    begin
      Result.ErrorKind := ErrKind;
      Result.ErrorMessage := ErrMsg;
      Exit;
    end;

    Result.Success := True;
    Result.Format := Fmt;
    Break;
  end;
end;

function TWebFetchProductionTransport.Fetch(const RequestUrl: string;
  const Parsed: TWebFetchUrl; const ConnectIP, VHost: string;
  const Config: TWebFetchConfig; CancelCheck: TWebFetchCancelCheck;
  out Resp: THttpFetchResponse; out ErrKind: TWebFetchErrorKind;
  out ErrMsg: string): Boolean;
begin
  Result := HttpFetchUrl(RequestUrl, Parsed, ConnectIP, VHost, Config, CancelCheck,
    Resp, ErrKind, ErrMsg);
end;

function WebFetchResultToJson(const R: TWebFetchResult): string;
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
      O.Add('content_type', R.ContentType);
      O.Add('format', R.Format);
      O.Add('content', R.Content);
      O.Add('truncated', R.Truncated);
      O.Add('http_status', R.HttpStatus);
    end
    else
    begin
      O.Add('error', R.ErrorMessage);
      if WebFetchErrorKindToCode(R.ErrorKind) <> '' then
        O.Add('error_kind', WebFetchErrorKindToCode(R.ErrorKind));
      if R.Url <> '' then
        O.Add('url', R.Url);
      if R.HttpStatus > 0 then
        O.Add('http_status', R.HttpStatus);
    end;
    Result := O.AsJSON;
  finally
    O.Free;
  end;
end;

end.
