program test_web_search;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils,
  uWebSearchTypes, uWebSearchUrl, uWebSearchProviderBrave, uWebSearchProviderSearxng,
  uWebSearchProviderTavily, uWebSearchManager, uWebSearchConfig, uWebSearchHttp,
  uWebSearchSecrets, uAppDatabase;

procedure Fail(const Msg: string);
begin
  WriteLn('FAIL: ', Msg);
  Halt(1);
end;

type
  TMockTransport = class(TInterfacedObject, IWebSearchTransport)
  private
    FResponses: array of record
      Method, Url: string;
      Status: Integer;
      Body: RawByteString;
      ContentType: string;
    end;
    FCallIndex: Integer;
  public
    procedure QueueResponse(const AMethod, AUrl: string; AStatus: Integer;
      const ABody: RawByteString; const AContentType: string = 'application/json');
    function Request(const AMethod, AUrl: string; const AHeaders: array of string;
      const ABody: RawByteString; ATimeoutMs: Integer;
      CancelCheck: TWebSearchCancelCheck; out AResp: TWebSearchHttpResponse;
      out ErrCode, ErrMsg: string): Boolean;
  end;

procedure TMockTransport.QueueResponse(const AMethod, AUrl: string; AStatus: Integer;
  const ABody: RawByteString; const AContentType: string);
var
  N: Integer;
begin
  N := Length(FResponses);
  SetLength(FResponses, N + 1);
  FResponses[N].Method := AMethod;
  FResponses[N].Url := AUrl;
  FResponses[N].Status := AStatus;
  FResponses[N].Body := ABody;
  FResponses[N].ContentType := AContentType;
end;

function TMockTransport.Request(const AMethod, AUrl: string; const AHeaders: array of string;
  const ABody: RawByteString; ATimeoutMs: Integer;
  CancelCheck: TWebSearchCancelCheck; out AResp: TWebSearchHttpResponse;
  out ErrCode, ErrMsg: string): Boolean;
begin
  Result := False;
  FillChar(AResp, SizeOf(AResp), 0);
  if FCallIndex >= Length(FResponses) then begin
    ErrCode := WEB_SEARCH_ERR_CONNECTION;
    ErrMsg := 'no mock response';
    Exit;
  end;
  AResp.StatusCode := FResponses[FCallIndex].Status;
  AResp.Body := FResponses[FCallIndex].Body;
  AResp.ContentType := FResponses[FCallIndex].ContentType;
  Inc(FCallIndex);
  Result := True;
  ErrCode := '';
  ErrMsg := '';
end;

var
  Req: TWebSearchRequest;
  Results: TWebSearchResultArray;
  ErrCode, ErrMsg: string;
  Cfg: TWebSearchGlobalConfig;
  Resp: TWebSearchResponse;
  Mock: TMockTransport;
  Url: string;
  Body: string;
  DbRoot: string;
begin
  DbRoot := IncludeTrailingPathDelimiter(GetTempDir) + 'lca-ws-test-' + IntToStr(GetProcessID);
  TAppDatabase.SetConfigRootOverride(DbRoot);
  TAppDatabase.OpenGlobal;

  Req.Query := 'hello world';
  Req.MaxResults := 5;
  Req.Recency := 'week';
  Url := BraveBuildSearchUrl(Req, 5);
  if Pos('freshness=pw', Url) = 0 then Fail('brave freshness');
  if Pos('hello%20world', Url) = 0 then Fail('brave url encode');

  Body := '{"web":{"results":[{"title":"T","url":"https://example.com/x","description":"S"}]}}';
  if not BraveParseSearchResponse(RawByteString(Body), 10, Results, ErrCode, ErrMsg) then
    Fail('brave parse: ' + ErrMsg);
  if Length(Results) <> 1 then Fail('brave result count');
  if Results[0].URL <> 'https://example.com/x' then Fail('brave url');

  Body := '{"results":[{"title":"S","url":"https://a.test","content":"c"}]}';
  if not SearxngParseSearchResponse(RawByteString(Body), 'application/json', 5, Results,
    ErrCode, ErrMsg) then
    Fail('searxng parse');
  if Length(Results) <> 1 then Fail('searxng count');

  Body := '{"results":[{"title":"T","url":"https://b.test","content":"x"}]}';
  if not TavilyParseSearchResponse(RawByteString(Body), 5, Results, ErrCode, ErrMsg) then
    Fail('tavily parse');

  Cfg := DefaultWebSearchGlobalConfig;
  Cfg.Enabled := True;
  Cfg.AutomaticFallback := True;
  SetLength(Cfg.Connections, 2);
  Cfg.Connections[0].Id := 'c1';
  Cfg.Connections[0].Name := 'First';
  Cfg.Connections[0].Kind := wspkBrave;
  Cfg.Connections[0].Enabled := True;
  Cfg.Connections[0].Priority := 1;
  Cfg.Connections[0].TimeoutMs := 5000;
  Cfg.Connections[1].Id := 'c2';
  Cfg.Connections[1].Name := 'Second';
  Cfg.Connections[1].Kind := wspkBrave;
  Cfg.Connections[1].Enabled := True;
  Cfg.Connections[1].Priority := 2;
  Cfg.Connections[1].TimeoutMs := 5000;
  SetWebSearchApiKey('c1', 'key1');
  SetWebSearchApiKey('c2', 'key2');
  SetWebSearchConfigOverrideForTests(Cfg);

  Mock := TMockTransport.Create;
  Mock.QueueResponse('GET', '', 429, '');
  Mock.QueueResponse('GET', '', 200,
    RawByteString('{"web":{"results":[{"title":"OK","url":"https://ok.test","description":""}]}}'));
  Req.Query := 'test';
  Req.MaxResults := 5;
  Req.Recency := 'any';
  if not ExecuteWebSearch(Cfg, Req, Mock, nil, Resp) then Fail('fallback search failed');
  if not Resp.Success then Fail('fallback not success');
  if Length(Resp.Results) <> 1 then Fail('fallback results');
  ClearWebSearchConfigOverrideForTests;
  ClearWebSearchApiKey('c1');
  ClearWebSearchApiKey('c2');
  TAppDatabase.CloseGlobal;
  TAppDatabase.ClearConfigRootOverride;

  if ValidateSearchResultUrl('http://user:pass@evil.com') then Fail('cred url');
  if not ValidateSearchResultUrl('https://example.com') then Fail('valid url');

  WriteLn('All web_search tests passed.');
end.
