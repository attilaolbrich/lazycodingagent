program test_web_fetch;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils,
  uWebFetchTypes, uWebFetchUrl, uWebFetch, uWebContentExtract, uWebFetchHttpBody;

procedure Fail(const Msg: string);
begin
  WriteLn('FAIL: ', Msg);
  Halt(1);
end;

const
  GZIP_HTML_FIXTURE: array[0..76] of Byte = (
    $1F, $8B, $08, $00, $00, $00, $00, $00, $02, $FF, $B3, $C9, $28, $C9, $CD, $B1,
    $B3, $C9, $48, $4D, $4C, $B1, $B3, $29, $C9, $2C, $C9, $49, $B5, $73, $AF, $CA,
    $2C, $F0, $C8, $B4, $D1, $87, $F0, $6C, $F4, $21, $72, $49, $F9, $29, $95, $76,
    $36, $05, $76, $EE, $51, $9E, $01, $F1, $FE, $DE, $36, $FA, $05, $40, $29, $88,
    $A0, $3E, $D8, $0C, $00, $D8, $E8, $70, $D8, $4A, $00, $00, $00
  );
  GZIP_OSOFT_LIKE_FIXTURE: array[0..153] of Byte = (
    $1F, $8B, $08, $00, $00, $00, $00, $00, $02, $FF, $25, $4E, $DB, $0D, $83, $30,
    $0C, $5C, $C5, $CD, $7F, $9B, $05, $4C, $A4, $4E, $D0, $8F, $4E, $E0, $36, $01,
    $22, $9C, $87, $C0, $20, $85, $6D, $BA, $47, $FF, $58, $AC, $A1, $F9, $F1, $E9,
    $7C, $E7, $3B, $E3, $C5, $A6, $B7, $94, $EC, $60, $94, $C0, $06, $CF, $09, $4C,
    $71, $E8, $D4, $B8, $AA, $CA, $1D, $59, $83, $E2, $85, $9D, $79, $5C, $9F, $A9,
    $17, $D4, $8D, $A1, $6E, $DA, $2B, $D9, $D2, $7C, $6E, $36, $CB, $E4, $33, $44,
    $DA, $9A, $58, $17, $18, $C8, $47, $F0, $B6, $53, $42, $B3, $10, $A7, $50, $43,
    $B3, $B9, $EF, $70, $7C, $87, $B2, $79, $71, $EC, $A1, $4F, $5C, $28, $90, $C0,
    $B4, $0A, $C9, $F1, $59, $6E, $A8, $73, $2D, $38, $6F, $2B, $B4, $06, $FD, $7F,
    $F0, $07, $69, $CD, $58, $19, $B0, $00, $00, $00
  );

function GzipBytesFromFixture(const Bytes: array of Byte): RawByteString;
var
  I: Integer;
begin
  SetLength(Result, Length(Bytes));
  for I := 0 to High(Bytes) do
    Result[I + 1] := AnsiChar(Bytes[I]);
end;

function GzipHtmlFixtureBytes: RawByteString;
begin
  Result := GzipBytesFromFixture(GZIP_HTML_FIXTURE);
end;

procedure AssertBlocked(const Url: string);
var
  P: TWebFetchUrl;
  K: TWebFetchErrorKind;
  Msg: string;
begin
  if not ParseWebFetchUrl(Url, P, K, Msg) then
  begin
    if K = wfekBlockedDestination then Exit;
    if K = wfekInvalidUrl then Exit;
    Fail('expected block for ' + Url + ' got parse ' + Msg);
  end;
  if ValidateWebFetchTarget(P, K, Msg) then
    Fail('expected blocked destination for ' + Url);
  if K <> wfekBlockedDestination then
    Fail('wrong error kind for ' + Url);
end;

type
  TRedirectThenOkTransport = class(TInterfacedObject, IWebFetchTransport)
  public
    function Fetch(const RequestUrl: string; const Parsed: TWebFetchUrl;
      const ConnectIP, VHost: string; const Config: TWebFetchConfig;
      CancelCheck: TWebFetchCancelCheck; out Resp: THttpFetchResponse;
      out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;
  end;

  TMockTransport = class(TInterfacedObject, IWebFetchTransport)
  private
    FStatus: Integer;
    FContentType: string;
    FBody: RawByteString;
    FLocation: string;
    FCalls: Integer;
  public
    constructor Create(AStatus: Integer; const AContentType: string;
      const ABody: RawByteString; const ALocation: string = '');
    function Fetch(const RequestUrl: string; const Parsed: TWebFetchUrl;
      const ConnectIP, VHost: string; const Config: TWebFetchConfig;
      CancelCheck: TWebFetchCancelCheck; out Resp: THttpFetchResponse;
      out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;
    property Calls: Integer read FCalls;
  end;

function TRedirectThenOkTransport.Fetch(const RequestUrl: string;
  const Parsed: TWebFetchUrl; const ConnectIP, VHost: string;
  const Config: TWebFetchConfig; CancelCheck: TWebFetchCancelCheck;
  out Resp: THttpFetchResponse; out ErrKind: TWebFetchErrorKind;
  out ErrMsg: string): Boolean;
begin
  FillChar(Resp, SizeOf(Resp), 0);
  if Pos('/next', RequestUrl) > 0 then
  begin
    Resp.StatusCode := 200;
    Resp.ContentType := 'text/plain';
    Resp.Body := 'done';
  end
  else
  begin
    Resp.StatusCode := 302;
    Resp.Location := 'http://93.184.216.34/next';
  end;
  Result := True;
  ErrKind := wfekNone;
  ErrMsg := '';
end;

constructor TMockTransport.Create(AStatus: Integer; const AContentType: string;
  const ABody: RawByteString; const ALocation: string);
begin
  inherited Create;
  FStatus := AStatus;
  FContentType := AContentType;
  FBody := ABody;
  FLocation := ALocation;
  FCalls := 0;
end;

function TMockTransport.Fetch(const RequestUrl: string; const Parsed: TWebFetchUrl;
  const ConnectIP, VHost: string; const Config: TWebFetchConfig;
  CancelCheck: TWebFetchCancelCheck; out Resp: THttpFetchResponse;
  out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;
begin
  Inc(FCalls);
  FillChar(Resp, SizeOf(Resp), 0);
  Resp.StatusCode := FStatus;
  Resp.ContentType := FContentType;
  Resp.Body := FBody;
  Resp.Location := FLocation;
  Result := True;
  ErrKind := wfekNone;
  ErrMsg := '';
end;

var
  FixturePath, FixtureHtml, Title, Content, Resolved: string;
  RawBody, GzBody, PlainBody: RawByteString;
  Truncated: Boolean;
  K: TWebFetchErrorKind;
  Msg: string;
  R: TWebFetchResult;
  Mock: IWebFetchTransport;
  Config: TWebFetchConfig;
  CancelFlag: Boolean;
  P: TWebFetchUrl;
  HeaderList: TStringList;

function CancelSoon: Boolean;
begin
  Result := CancelFlag;
end;

begin
  if ParamCount >= 1 then
    FixturePath := ParamStr(1)
  else
    FixturePath := 'tests/fixtures/web_fetch/sample.html';
  if not FileExists(FixturePath) then
    Fail('fixture not found: ' + FixturePath);

  AssertBlocked('http://127.0.0.1/');
  AssertBlocked('http://[::1]/');
  AssertBlocked('http://10.0.0.1/');
  AssertBlocked('http://localhost/');
  AssertBlocked('http://user:pass@example.com/');
  if ParseWebFetchUrl('file:///etc/passwd', P, K, Msg) then
    Fail('file url should not parse');

  if not IsBlockedIPv4((127 shl 24) or 1) then
    Fail('127.0.0.1 should be blocked');

  HeaderList := TStringList.Create;
  try
    HeaderList.Add('content-type: text/html; charset=utf-8');
    if HttpHeaderValue(HeaderList, 'Content-Type') <> 'text/html; charset=utf-8' then
      Fail('HttpHeaderValue case mismatch');
    HeaderList.Add('CONTENT-ENCODING: gzip');
    if HttpContentEncodingFromHeaders(HeaderList) <> 'gzip' then
      Fail('HttpContentEncodingFromHeaders mismatch');
  finally
    HeaderList.Free;
  end;

  if not MaybeDecompressHttpBody(GzipHtmlFixtureBytes, 'gzip', RawBody, Msg) then
    Fail('gzip decompress: ' + Msg);
  if Pos('GZIP_OK', RawBody) = 0 then
    Fail('gzip decompress missing body text');
  if Pos('GzipHi', RawBody) = 0 then
    Fail('gzip decompress missing title');

  if not MaybeDecompressHttpBody(GzipBytesFromFixture(GZIP_OSOFT_LIKE_FIXTURE), 'gzip',
    RawBody, Msg) then
    Fail('osoft-like gzip decompress: ' + Msg);
  if not ExtractWebContent(RawBody, 'text/html; charset=utf-8', 'markdown', 20000,
    Title, Content, Truncated, K, Msg) then
    Fail('osoft-like extract: ' + Msg);
  if Pos('ügyviteli', RawBody) = 0 then
    Fail('osoft-like decompress missing main text');
  if (Pos('folyamat', LowerCase(Content)) = 0) and (Pos('kutat', LowerCase(Content)) = 0) then
    Fail('osoft-like markdown missing main text: ' + Copy(Content, 1, 120));

  if FileExists('tests/fixtures/web_fetch/osoft-home.html.gz') then
  begin
    with TFileStream.Create('tests/fixtures/web_fetch/osoft-home.html.gz', fmOpenRead or fmShareDenyWrite) do
    try
      SetLength(GzBody, Size);
      if Size > 0 then
        ReadBuffer(GzBody[1], Size);
    finally
      Free;
    end;
    if not MaybeDecompressHttpBody(GzBody, 'gzip', PlainBody, Msg) then
      Fail('osoft fixture gzip: ' + Msg);
    if not ExtractWebContent(PlainBody, 'text/html; charset=utf-8', 'markdown', 20000,
      Title, Content, Truncated, K, Msg) then
      Fail('osoft fixture extract: ' + Msg);
    if Length(Content) < 500 then
      Fail('osoft fixture markdown too short: ' + IntToStr(Length(Content)));
    if (Pos('ügyvitel', LowerCase(Content)) = 0) and (Pos('O-Soft', Content) = 0) then
      Fail('osoft fixture missing expected page text');
  end;

  if not ExtractWebContent(
    RawByteString('<!doctype html><html><body><main></main><div>VisibleInBody</div></body></html>'),
    'text/html', 'markdown', 20000, Title, Content, Truncated, K, Msg) then
    Fail('empty main extract: ' + Msg);
  if Pos('VisibleInBody', Content) = 0 then
    Fail('empty main should fall back to body text');

  with TStringList.Create do
  try
    LoadFromFile(FixturePath);
    FixtureHtml := Text;
  finally
    Free;
  end;
  if not ExtractWebContent(RawByteString(FixtureHtml), 'text/html', 'markdown', 20000,
    Title, Content, Truncated, K, Msg) then
    Fail('extract html: ' + Msg);
  if Pos('Authentication', Content) = 0 then
    Fail('missing heading');
  if Pos('token guide', Content) = 0 then
    Fail('missing link text');
  if (Pos('skip me', Content) > 0) and (Pos('Authentication', Content) > 0) and
     (Pos('#', Content) > 0) then
    Fail('nav should be stripped');

  if not ExtractWebContent(
    RawByteString('<html><head><title>Bad Tags</title></head><body><p>Hello</p><123>x</123></body></html>'),
    'text/html', 'markdown', 20000, Title, Content, Truncated, K, Msg) then
    Fail('extract malformed html should fallback: ' + Msg);
  if Pos('Hello', Content) = 0 then
    Fail('malformed html fallback missing body text');

  if not ExtractWebContent(RawByteString('hello'), 'text/plain', 'text', 3,
    Title, Content, Truncated, K, Msg) then
    Fail('plain extract');
  if not Truncated then
    Fail('expected truncation');
  if Length(Content) <> 3 then
    Fail('truncation length');

  Config := DefaultWebFetchConfig;
  Mock := TMockTransport.Create(200, 'text/html',
    RawByteString('<html><head><title>T</title></head><body><p>OK</p></body></html>'));
  R := FetchWebContent('http://93.184.216.34/page', 'markdown', 20000, Config, nil, Mock);
  if not R.Success then
    Fail('mock fetch failed: ' + R.ErrorMessage);

  Mock := TRedirectThenOkTransport.Create;
  R := FetchWebContent('http://93.184.216.34/start', 'text', 20000, Config, nil, Mock);
  if not R.Success then
    Fail('redirect chain failed: ' + R.ErrorMessage);
  if R.Content <> 'done' then
    Fail('redirect body mismatch');

  if ResolveRedirectUrl('http://93.184.216.34/a', 'http://127.0.0.1/evil', Resolved, K, Msg) then
    Fail('redirect to private should not resolve');
  if K <> wfekBlockedDestination then
    Fail('redirect to private should be blocked');

  Mock := TMockTransport.Create(404, 'text/html', 'missing');
  R := FetchWebContent('http://93.184.216.34/missing', 'markdown', 20000, Config, nil, Mock);
  if R.Success or (R.ErrorKind <> wfekHttpError) then
    Fail('expected http 404 error');

  CancelFlag := True;
  Mock := TMockTransport.Create(200, 'text/plain', 'x');
  R := FetchWebContent('http://93.184.216.34/', 'text', 20000, Config, @CancelSoon, Mock);
  if R.ErrorKind <> wfekCancelled then
    Fail('expected cancel');

  if SameText(GetEnvironmentVariable('LCA_LIVE_WEB_FETCH'), '1') then
  begin
    R := FetchWebContent('https://commspliant.com/', 'markdown', 20000, Config, nil, nil);
    if not R.Success then
      Fail('live commspliant fetch: ' + R.ErrorMessage + ' (kind=' +
        WebFetchErrorKindToCode(R.ErrorKind) + ')');
    if Pos('CommsPliant', R.Content) = 0 then
      Fail('live commspliant fetch: expected site content in body');
    R := FetchWebContent('https://osoft.hu/', 'markdown', 20000, Config, nil, nil);
    if not R.Success then
      Fail('live osoft fetch: ' + R.ErrorMessage + ' (kind=' +
        WebFetchErrorKindToCode(R.ErrorKind) + ')');
    if Length(R.Content) < 500 then
      Fail('live osoft fetch: expected substantial page text');
    if (Pos('ügyvitel', LowerCase(R.Content)) = 0) and (Pos('O-Soft', R.Content) = 0) then
      Fail('live osoft fetch: expected site content in body');
  end;

  WriteLn('Web fetch tests passed.');
end.
