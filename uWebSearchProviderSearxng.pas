unit uWebSearchProviderSearxng;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uWebSearchTypes, uWebSearchHttp, uWebSearchProvider;

type
  TSearxngWebSearchProvider = class(TInterfacedObject, IWebSearchProvider)
  public
    function GetProviderType: string;
    function Search(const AConn: TWebSearchConnection; const ARequest: TWebSearchRequest;
      const AApiKey: string; AAllowPrivate: Boolean; ATransport: IWebSearchTransport;
      CancelCheck: TWebSearchCancelCheck; out AResponse: TWebSearchResponse): Boolean;
    function TestConnection(const AConn: TWebSearchConnection; const AApiKey: string;
      AAllowPrivate: Boolean; ATransport: IWebSearchTransport;
      CancelCheck: TWebSearchCancelCheck): TConnectionTestResult;
  end;

function SearxngBuildSearchUrl(const ABaseUrl: string; const ARequest: TWebSearchRequest): string;
function SearxngParseSearchResponse(const ABody: RawByteString; const AContentType: string;
  AMaxResults: Integer; out AResults: TWebSearchResultArray;
  out ErrCode, ErrMsg: string): Boolean;
function SearxngMapTimeRange(const ARecency: string): string;

implementation

uses
  fpjson, jsonparser, uWebSearchUrl, uWebSearchNormalize;

function SearxngMapTimeRange(const ARecency: string): string;
begin
  case LowerCase(Trim(ARecency)) of
    'day': Result := 'day';
    'week': Result := 'week';
    'month': Result := 'month';
    'year': Result := 'year';
  else
    Result := '';
  end;
end;

function SearxngBuildSearchUrl(const ABaseUrl: string; const ARequest: TWebSearchRequest): string;
var
  Base, Tr: string;
begin
  Base := Trim(ABaseUrl);
  if Base = '' then Exit('');
  Result := Base + '/search?q=' + UrlEncodeQueryComponent(ARequest.Query) +
    '&format=json';
  Tr := SearxngMapTimeRange(ARequest.Recency);
  if Tr <> '' then
    Result := Result + '&time_range=' + Tr;
end;

function JsonStringField(AObj: TJSONObject; const AName: string): string;
var
  D: TJSONData;
begin
  D := AObj.Find(AName);
  if not Assigned(D) or (D is TJSONNull) then Exit('');
  Result := D.AsString;
end;

function SearxngParseSearchResponse(const ABody: RawByteString; const AContentType: string;
  AMaxResults: Integer; out AResults: TWebSearchResultArray;
  out ErrCode, ErrMsg: string): Boolean;
var
  Data: TJSONData;
  Root, Item: TJSONObject;
  Arr: TJSONArray;
  I, N: Integer;
  R: TWebSearchResult;
  Preview: string;
begin
  Result := False;
  SetLength(AResults, 0);
  ErrCode := WEB_SEARCH_ERR_INVALID_RESPONSE;
  ErrMsg := 'Invalid JSON response';
  if Length(ABody) = 0 then Exit;
  if (Pos('text/html', LowerCase(AContentType)) > 0) or
     ((Length(ABody) > 0) and (ABody[1] = '<')) then begin
    ErrMsg := 'SearXNG instance did not return JSON (JSON API may be disabled)';
    Exit;
  end;
  try
    Data := GetJSON(ABody);
  except
    if Length(ABody) > 80 then
      Preview := Copy(string(ABody), 1, 80)
    else
      Preview := string(ABody);
    if Pos('<html', LowerCase(Preview)) > 0 then
      ErrMsg := 'SearXNG instance returned HTML instead of JSON';
    Exit;
  end;
  try
    if not (Data is TJSONObject) then Exit;
    Root := TJSONObject(Data);
    Arr := Root.Find('results') as TJSONArray;
    if Arr = nil then begin
      Result := True;
      ErrCode := '';
      ErrMsg := '';
      Exit;
    end;
    N := 0;
    for I := 0 to Arr.Count - 1 do begin
      if N >= AMaxResults then Break;
      if not (Arr.Items[I] is TJSONObject) then Continue;
      Item := TJSONObject(Arr.Items[I]);
      R.Title := JsonStringField(Item, 'title');
      R.URL := JsonStringField(Item, 'url');
      R.Snippet := JsonStringField(Item, 'content');
      if R.Snippet = '' then
        R.Snippet := JsonStringField(Item, 'snippet');
      R.PublishedAt := '';
      SetLength(AResults, N + 1);
      AResults[N] := R;
      Inc(N);
    end;
    DedupeWebSearchResults(AResults);
    Result := True;
    ErrCode := '';
    ErrMsg := '';
  finally
    Data.Free;
  end;
end;

function MapHttpStatusToError(AStatus: Integer; out ErrCode: string): Boolean;
begin
  Result := True;
  case AStatus of
    401, 403:
      ErrCode := WEB_SEARCH_ERR_AUTH;
    429:
      ErrCode := WEB_SEARCH_ERR_RATE_LIMIT;
    500..599:
      ErrCode := WEB_SEARCH_ERR_CONNECTION;
  else
    if (AStatus >= 400) and (AStatus < 500) then
      ErrCode := WEB_SEARCH_ERR_INVALID_RESPONSE
    else
      Result := False;
  end;
end;

function TSearxngWebSearchProvider.GetProviderType: string;
begin
  Result := 'searxng';
end;

function TSearxngWebSearchProvider.Search(const AConn: TWebSearchConnection;
  const ARequest: TWebSearchRequest; const AApiKey: string; AAllowPrivate: Boolean;
  ATransport: IWebSearchTransport; CancelCheck: TWebSearchCancelCheck;
  out AResponse: TWebSearchResponse): Boolean;
var
  Base, Url: string;
  Err: string;
  Hdr: array of string;
  HttpResp: TWebSearchHttpResponse;
  ErrCode, ErrMsg: string;
  Parsed: Boolean;
begin
  InitWebSearchResponse(AResponse);
  Result := False;
  if not ValidateSearxngInstanceUrl(AConn.InstanceUrl, AAllowPrivate, Base, Err) then begin
    AResponse.ErrorCode := WEB_SEARCH_ERR_CONNECTION;
    AResponse.ErrorMessage := Err;
    Exit;
  end;
  Url := SearxngBuildSearchUrl(Base, ARequest);
  if Trim(AConn.CustomHeaderName) <> '' then
    Hdr := [AConn.CustomHeaderName + ': ' + AConn.CustomHeaderValue]
  else
    Hdr := [];
  if not ATransport.Request('GET', Url, Hdr, '', AConn.TimeoutMs, CancelCheck, HttpResp,
    ErrCode, ErrMsg) then begin
    AResponse.ErrorCode := ErrCode;
    AResponse.ErrorMessage := ErrMsg;
    Exit;
  end;
  if HttpResp.StatusCode = 200 then begin
    Parsed := SearxngParseSearchResponse(HttpResp.Body, HttpResp.ContentType,
      ARequest.MaxResults, AResponse.Results, AResponse.ErrorCode, AResponse.ErrorMessage);
    if Parsed then begin
      AResponse.Success := True;
      Result := True;
    end;
    Exit;
  end;
  if MapHttpStatusToError(HttpResp.StatusCode, AResponse.ErrorCode) then begin
    AResponse.ErrorMessage := 'SearXNG returned HTTP ' + IntToStr(HttpResp.StatusCode);
    Exit;
  end;
  AResponse.ErrorCode := WEB_SEARCH_ERR_INVALID_RESPONSE;
  AResponse.ErrorMessage := 'Unexpected HTTP status ' + IntToStr(HttpResp.StatusCode);
end;

function TSearxngWebSearchProvider.TestConnection(const AConn: TWebSearchConnection;
  const AApiKey: string; AAllowPrivate: Boolean; ATransport: IWebSearchTransport;
  CancelCheck: TWebSearchCancelCheck): TConnectionTestResult;
var
  Req: TWebSearchRequest;
  Resp: TWebSearchResponse;
  StartMs: QWord;
begin
  FillChar(Result, SizeOf(Result), 0);
  Req.Query := 'test';
  Req.MaxResults := 1;
  Req.Recency := 'any';
  StartMs := GetTickCount64;
  if Search(AConn, Req, AApiKey, AAllowPrivate, ATransport, CancelCheck, Resp) then begin
    Result.Success := True;
    Result.ResultCount := Length(Resp.Results);
  end else begin
    Result.ErrorCode := Resp.ErrorCode;
    Result.ErrorMessage := Resp.ErrorMessage;
  end;
  Result.ResponseTimeMs := Integer(GetTickCount64 - StartMs);
end;

end.
