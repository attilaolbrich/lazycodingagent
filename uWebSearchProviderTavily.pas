unit uWebSearchProviderTavily;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uWebSearchTypes, uWebSearchHttp, uWebSearchProvider;

type
  TTavilyWebSearchProvider = class(TInterfacedObject, IWebSearchProvider)
  public
    function GetProviderType: string;
    function Search(const AConn: TWebSearchConnection; const ARequest: TWebSearchRequest;
      const AApiKey: string; AAllowPrivate: Boolean; ATransport: IWebSearchTransport;
      CancelCheck: TWebSearchCancelCheck; out AResponse: TWebSearchResponse): Boolean;
    function TestConnection(const AConn: TWebSearchConnection; const AApiKey: string;
      AAllowPrivate: Boolean; ATransport: IWebSearchTransport;
      CancelCheck: TWebSearchCancelCheck): TConnectionTestResult;
  end;

function TavilyBuildRequestBody(const AApiKey: string; const AConn: TWebSearchConnection;
  const ARequest: TWebSearchRequest): string;
function TavilyParseSearchResponse(const ABody: RawByteString; AMaxResults: Integer;
  out AResults: TWebSearchResultArray; out ErrCode, ErrMsg: string): Boolean;

implementation

uses
  fpjson, jsonparser, uWebSearchNormalize;

const
  TAVILY_API_URL = 'https://api.tavily.com/search';

function TavilyMapDays(const ARecency: string): Integer;
begin
  case LowerCase(Trim(ARecency)) of
    'day': Exit(1);
    'week': Exit(7);
    'month': Exit(30);
    'year': Exit(365);
  else
    Exit(0);
  end;
end;

function TavilyBuildRequestBody(const AApiKey: string; const AConn: TWebSearchConnection;
  const ARequest: TWebSearchRequest): string;
var
  Root: TJSONObject;
  Days: Integer;
  Depth: string;
  MaxR: Integer;
begin
  MaxR := ARequest.MaxResults;
  if MaxR < 1 then MaxR := 1;
  if MaxR > 20 then MaxR := 20;
  Root := TJSONObject.Create;
  try
    Root.Add('api_key', AApiKey);
    Root.Add('query', ARequest.Query);
    Root.Add('max_results', MaxR);
    Depth := Trim(AConn.TavilySearchDepth);
    if Depth = '' then Depth := 'basic';
    Root.Add('search_depth', Depth);
    Days := TavilyMapDays(ARequest.Recency);
    if Days > 0 then
      Root.Add('days', Days);
    Result := Root.AsJSON;
  finally
    Root.Free;
  end;
end;

function JsonStringField(AObj: TJSONObject; const AName: string): string;
var
  D: TJSONData;
begin
  D := AObj.Find(AName);
  if not Assigned(D) or (D is TJSONNull) then Exit('');
  Result := D.AsString;
end;

function TavilyParseSearchResponse(const ABody: RawByteString; AMaxResults: Integer;
  out AResults: TWebSearchResultArray; out ErrCode, ErrMsg: string): Boolean;
var
  Data: TJSONData;
  Root, Item: TJSONObject;
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
      R.PublishedAt := JsonStringField(Item, 'published_date');
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

function TTavilyWebSearchProvider.GetProviderType: string;
begin
  Result := 'tavily';
end;

function TTavilyWebSearchProvider.Search(const AConn: TWebSearchConnection;
  const ARequest: TWebSearchRequest; const AApiKey: string; AAllowPrivate: Boolean;
  ATransport: IWebSearchTransport; CancelCheck: TWebSearchCancelCheck;
  out AResponse: TWebSearchResponse): Boolean;
var
  Body: RawByteString;
  Hdr: array of string;
  HttpResp: TWebSearchHttpResponse;
  ErrCode, ErrMsg: string;
  Parsed: Boolean;
begin
  InitWebSearchResponse(AResponse);
  Result := False;
  if Trim(AApiKey) = '' then begin
    AResponse.ErrorCode := WEB_SEARCH_ERR_AUTH;
    AResponse.ErrorMessage := 'API key not configured';
    Exit;
  end;
  Body := TavilyBuildRequestBody(AApiKey, AConn, ARequest);
  Hdr := ['Content-Type: application/json'];
  if not ATransport.Request('POST', TAVILY_API_URL, Hdr, Body, AConn.TimeoutMs,
    CancelCheck, HttpResp, ErrCode, ErrMsg) then begin
    AResponse.ErrorCode := ErrCode;
    AResponse.ErrorMessage := ErrMsg;
    Exit;
  end;
  if HttpResp.StatusCode = 200 then begin
    Parsed := TavilyParseSearchResponse(HttpResp.Body, ARequest.MaxResults,
      AResponse.Results, AResponse.ErrorCode, AResponse.ErrorMessage);
    if Parsed then begin
      AResponse.Success := True;
      Result := True;
    end;
    Exit;
  end;
  if MapHttpStatusToError(HttpResp.StatusCode, AResponse.ErrorCode) then begin
    AResponse.ErrorMessage := 'Tavily API returned HTTP ' + IntToStr(HttpResp.StatusCode);
    Exit;
  end;
  AResponse.ErrorCode := WEB_SEARCH_ERR_INVALID_RESPONSE;
  AResponse.ErrorMessage := 'Unexpected HTTP status ' + IntToStr(HttpResp.StatusCode);
end;

function TTavilyWebSearchProvider.TestConnection(const AConn: TWebSearchConnection;
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
