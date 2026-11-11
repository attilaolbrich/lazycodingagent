unit uWebSearchProviderBrave;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uWebSearchTypes, uWebSearchHttp, uWebSearchProvider;

type
  TBraveWebSearchProvider = class(TInterfacedObject, IWebSearchProvider)
  public
    function GetProviderType: string;
    function Search(const AConn: TWebSearchConnection; const ARequest: TWebSearchRequest;
      const AApiKey: string; AAllowPrivate: Boolean; ATransport: IWebSearchTransport;
      CancelCheck: TWebSearchCancelCheck; out AResponse: TWebSearchResponse): Boolean;
    function TestConnection(const AConn: TWebSearchConnection; const AApiKey: string;
      AAllowPrivate: Boolean; ATransport: IWebSearchTransport;
      CancelCheck: TWebSearchCancelCheck): TConnectionTestResult;
  end;

function BraveBuildSearchUrl(const ARequest: TWebSearchRequest; ACount: Integer): string;
function BraveParseSearchResponse(const ABody: RawByteString; AMaxResults: Integer;
  out AResults: TWebSearchResultArray; out ErrCode, ErrMsg: string): Boolean;
function BraveMapRecency(const ARecency: string): string;

implementation

uses
  fpjson, jsonparser, uWebSearchUrl, uWebSearchNormalize;

const
  BRAVE_API_BASE = 'https://api.search.brave.com/res/v1/web/search';

function BraveMapRecency(const ARecency: string): string;
begin
  case LowerCase(Trim(ARecency)) of
    'day': Result := 'pd';
    'week': Result := 'pw';
    'month': Result := 'pm';
    'year': Result := 'py';
  else
    Result := '';
  end;
end;

function BraveBuildSearchUrl(const ARequest: TWebSearchRequest; ACount: Integer): string;
var
  Fresh: string;
begin
  if ACount < 1 then ACount := 1;
  if ACount > 20 then ACount := 20;
  Result := BRAVE_API_BASE + '?q=' + UrlEncodeQueryComponent(ARequest.Query) +
    '&count=' + IntToStr(ACount);
  Fresh := BraveMapRecency(ARequest.Recency);
  if Fresh <> '' then
    Result := Result + '&freshness=' + Fresh;
end;

function JsonStringField(AObj: TJSONObject; const AName: string): string;
var
  D: TJSONData;
begin
  D := AObj.Find(AName);
  if not Assigned(D) or (D is TJSONNull) then Exit('');
  Result := D.AsString;
end;

function BraveParseSearchResponse(const ABody: RawByteString; AMaxResults: Integer;
  out AResults: TWebSearchResultArray; out ErrCode, ErrMsg: string): Boolean;
var
  Data: TJSONData;
  Root, Web, Item: TJSONObject;
  Arr: TJSONArray;
  I, N: Integer;
  R: TWebSearchResult;
begin
  Result := False;
  SetLength(AResults, 0);
  ErrCode := WEB_SEARCH_ERR_INVALID_RESPONSE;
  ErrMsg := 'Invalid JSON response';
  if Length(ABody) = 0 then Exit;
  try
    Data := GetJSON(ABody);
  except
    Exit;
  end;
  try
    if not (Data is TJSONObject) then Exit;
    Root := TJSONObject(Data);
    Web := Root.Find('web') as TJSONObject;
    if Web = nil then begin
      ErrMsg := 'Missing web results in response';
      Exit;
    end;
    Arr := Web.Find('results') as TJSONArray;
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
      R.Snippet := JsonStringField(Item, 'description');
      R.PublishedAt := JsonStringField(Item, 'age');
      if R.PublishedAt = '' then
        R.PublishedAt := JsonStringField(Item, 'published');
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

function TBraveWebSearchProvider.GetProviderType: string;
begin
  Result := 'brave';
end;

function TBraveWebSearchProvider.Search(const AConn: TWebSearchConnection;
  const ARequest: TWebSearchRequest; const AApiKey: string; AAllowPrivate: Boolean;
  ATransport: IWebSearchTransport; CancelCheck: TWebSearchCancelCheck;
  out AResponse: TWebSearchResponse): Boolean;
var
  Url: string;
  Hdr: array of string;
  HttpResp: TWebSearchHttpResponse;
  ErrCode, ErrMsg: string;
  TimeoutMs: Integer;
  Parsed: Boolean;
begin
  InitWebSearchResponse(AResponse);
  Result := False;
  if Trim(AApiKey) = '' then begin
    AResponse.ErrorCode := WEB_SEARCH_ERR_AUTH;
    AResponse.ErrorMessage := 'API key not configured';
    Exit;
  end;
  TimeoutMs := AConn.TimeoutMs;
  Url := BraveBuildSearchUrl(ARequest, ARequest.MaxResults);
  Hdr := ['X-Subscription-Token: ' + AApiKey];
  if not ATransport.Request('GET', Url, Hdr, '', TimeoutMs, CancelCheck, HttpResp,
    ErrCode, ErrMsg) then begin
    AResponse.ErrorCode := ErrCode;
    AResponse.ErrorMessage := ErrMsg;
    Exit;
  end;
  if HttpResp.StatusCode = 200 then begin
    Parsed := BraveParseSearchResponse(HttpResp.Body, ARequest.MaxResults, AResponse.Results,
      AResponse.ErrorCode, AResponse.ErrorMessage);
    if Parsed then begin
      AResponse.Success := True;
      Result := True;
    end;
    Exit;
  end;
  if MapHttpStatusToError(HttpResp.StatusCode, AResponse.ErrorCode) then begin
    AResponse.ErrorMessage := 'Brave API returned HTTP ' + IntToStr(HttpResp.StatusCode);
    Exit;
  end;
  AResponse.ErrorCode := WEB_SEARCH_ERR_INVALID_RESPONSE;
  AResponse.ErrorMessage := 'Unexpected HTTP status ' + IntToStr(HttpResp.StatusCode);
end;

function TBraveWebSearchProvider.TestConnection(const AConn: TWebSearchConnection;
  const AApiKey: string; AAllowPrivate: Boolean; ATransport: IWebSearchTransport;
  CancelCheck: TWebSearchCancelCheck): TConnectionTestResult;
var
  Req: TWebSearchRequest;
  Resp: TWebSearchResponse;
  StartMs: QWord;
begin
  FillChar(Result, SizeOf(Result), 0);
  Req.Query := 'LazyCodingAgent';
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
