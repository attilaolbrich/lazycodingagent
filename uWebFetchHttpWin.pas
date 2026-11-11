unit uWebFetchHttpWin;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, uWebFetchTypes, uWebFetchHttpBody;

function WebFetchHttpWinGet(const RequestUrl, VHost: string;
  const Config: TWebFetchConfig; CancelCheck: TWebFetchCancelCheck;
  out Resp: THttpFetchResponse; out ErrKind: TWebFetchErrorKind;
  out ErrMsg: string): Boolean;

implementation

{$IFDEF MSWINDOWS}
uses
  Windows;

const
  WINHTTP_OPTION_REDIRECT_POLICY = 88;
  WINHTTP_OPTION_REDIRECT_POLICY_NEVER = 0;
  WINHTTP_QUERY_LOCATION = 35;
  WINHTTP_QUERY_CONTENT_TYPE = 1;
  WINHTTP_QUERY_CONTENT_ENCODING = 29;
  WINHTTP_QUERY_RAW_HEADERS_CRLF = 22;
  WINHTTP_QUERY_FLAG_NUMBER = $20000000;
  WINHTTP_QUERY_STATUS_CODE = 19;
  WINHTTP_FLAG_SECURE = $00800000;
  ERROR_WINHTTP_SECURE_FAILURE = 12175;
  ERROR_WINHTTP_SECURE_INVALID_CERT = 12157;
  ERROR_WINHTTP_NAME_NOT_RESOLVED = 12007;
  ERROR_INTERNET_SEC_CERT_DATE_INVALID = 12037;
  ERROR_INTERNET_SEC_CERT_CN_INVALID = 12038;

type
  HInternet = Pointer;

function WinHttpOpen(pwszUserAgent: PWideChar; dwAccessType: DWORD;
  pwszProxyName, pwszProxyBypass: PWideChar; dwFlags: DWORD): HInternet; stdcall;
  external 'winhttp.dll' name 'WinHttpOpen';
function WinHttpConnect(hSession: HInternet; pswzServerName: PWideChar;
  nServerPort: Word; dwReserved: DWORD): HInternet; stdcall;
  external 'winhttp.dll' name 'WinHttpConnect';
function WinHttpOpenRequest(hConnect: HInternet; pwszVerb, pwszObjectName,
  pwszVersion, pwszReferrer: PWideChar; ppwszAcceptTypes: Pointer;
  dwFlags: DWORD): HInternet; stdcall; external 'winhttp.dll' name 'WinHttpOpenRequest';
function WinHttpSendRequest(hRequest: HInternet; pwszHeaders: PWideChar;
  dwHeadersLength: DWORD; lpOptional: Pointer; dwOptionalLength,
  dwTotalLength: DWORD_PTR; dwContext: DWORD_PTR): BOOL; stdcall;
  external 'winhttp.dll' name 'WinHttpSendRequest';
function WinHttpReceiveResponse(hRequest: HInternet; lpReserved: Pointer): BOOL; stdcall;
  external 'winhttp.dll' name 'WinHttpReceiveResponse';
function WinHttpQueryHeaders(hRequest: HInternet; dwInfoLevel: DWORD;
  pwszName: PWideChar; lpBuffer: Pointer; var lpdwBufferLength: DWORD;
  var lpdwIndex: DWORD): BOOL; stdcall; external 'winhttp.dll' name 'WinHttpQueryHeaders';
function WinHttpReadData(hRequest: HInternet; lpBuffer: Pointer;
  dwNumberOfBytesToRead: DWORD; var lpdwNumberOfBytesRead: DWORD): BOOL; stdcall;
  external 'winhttp.dll' name 'WinHttpReadData';
function WinHttpSetTimeouts(hInternet: HInternet; nResolveTimeout,
  nConnectTimeout, nSendTimeout, nReceiveTimeout: Integer): BOOL; stdcall;
  external 'winhttp.dll' name 'WinHttpSetTimeouts';
function WinHttpSetOption(hInternet: HInternet; dwOption: DWORD;
  lpBuffer: Pointer; dwBufferLength: DWORD): BOOL; stdcall;
  external 'winhttp.dll' name 'WinHttpSetOption';
function WinHttpCloseHandle(hInternet: HInternet): BOOL; stdcall;
  external 'winhttp.dll' name 'WinHttpCloseHandle';

procedure ParseRequestUrl(const AURL: string; out AHost, APath: string;
  out APort: Word; out ASecure: Boolean);
var
  S, Authority, PortText: string;
  P, SlashPos, QueryPos, ColonPos: SizeInt;
  PortNum: Integer;
begin
  S := Trim(AURL);
  if SameText(Copy(S, 1, 8), 'https://') then begin
    ASecure := True;
    APort := 443;
    Delete(S, 1, 8);
  end else if SameText(Copy(S, 1, 7), 'http://') then begin
    ASecure := False;
    APort := 80;
    Delete(S, 1, 7);
  end else
    raise Exception.Create('bad url');

  SlashPos := Pos('/', S);
  QueryPos := Pos('?', S);
  if (SlashPos = 0) or ((QueryPos > 0) and (QueryPos < SlashPos)) then begin
    if QueryPos > 0 then P := QueryPos else P := Length(S) + 1;
  end else
    P := SlashPos;
  Authority := Copy(S, 1, P - 1);
  APath := Copy(S, P, MaxInt);
  if APath = '' then APath := '/';

  AHost := Authority;
  PortText := '';
  if (Authority <> '') and (Authority[1] = '[') then begin
    P := Pos(']', Authority);
    if P = 0 then raise Exception.Create('bad ipv6');
    AHost := Copy(Authority, 2, P - 2);
    if (P < Length(Authority)) and (Authority[P + 1] = ':') then
      PortText := Copy(Authority, P + 2, MaxInt);
  end else begin
    ColonPos := LastDelimiter(':', Authority);
    if ColonPos > 0 then begin
      AHost := Copy(Authority, 1, ColonPos - 1);
      PortText := Copy(Authority, ColonPos + 1, MaxInt);
    end;
  end;
  if PortText <> '' then begin
    PortNum := StrToIntDef(PortText, 0);
    if (PortNum >= 1) and (PortNum <= 65535) then
      APort := PortNum;
  end;
end;

function QueryHeaderString(Request: HInternet; InfoLevel: DWORD): string;
var
  Buf: array[0..8191] of WideChar;
  Len, Idx: DWORD;
begin
  Len := SizeOf(Buf);
  Idx := 0;
  if WinHttpQueryHeaders(Request, InfoLevel, nil, @Buf[0], Len, Idx) then
    Result := UTF8Encode(string(WideString(Buf)))
  else
    Result := '';
end;

function QueryHeaderDword(Request: HInternet; InfoLevel: DWORD): DWORD;
var
  Status: DWORD;
  Len, Idx: DWORD;
begin
  Status := 0;
  Len := SizeOf(Status);
  Idx := 0;
  if WinHttpQueryHeaders(Request, InfoLevel, nil, @Status, Len, Idx) then
    Result := Status
  else
    Result := 0;
end;

function Win32ErrorText(AError: DWORD): string;
var
  Flags: DWORD;
  Buf: array[0..1023] of Char;
begin
  Result := '';
  if AError = 0 then Exit;
  Flags := FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS;
  if FormatMessage(Flags, nil, AError, 0, Buf, Length(Buf), nil) > 0 then
    Result := Trim(string(Buf));
end;

function ClassifyWinHttpError(AError: DWORD): TWebFetchErrorKind;
begin
  case AError of
    ERROR_WINHTTP_NAME_NOT_RESOLVED:
      Result := wfekDnsFailure;
    ERROR_WINHTTP_SECURE_FAILURE,
    ERROR_WINHTTP_SECURE_INVALID_CERT,
    ERROR_INTERNET_SEC_CERT_DATE_INVALID,
    ERROR_INTERNET_SEC_CERT_CN_INVALID:
      Result := wfekTlsFailure;
  else
    if (AError >= 12000) and (AError <= 12199) then
    begin
      if (AError >= 12150) and (AError <= 12180) then
        Result := wfekTlsFailure
      else
        Result := wfekInternal;
    end
    else
      Result := wfekInternal;
  end;
end;

procedure SetWinHttpFailure(const Stage: string; AError: DWORD;
  out ErrKind: TWebFetchErrorKind; out ErrMsg: string);
var
  Detail: string;
begin
  ErrKind := ClassifyWinHttpError(AError);
  Detail := Win32ErrorText(AError);
  if ErrKind = wfekTlsFailure then
    ErrMsg := 'TLS/HTTPS handshake failed'
  else
    ErrMsg := Stage;
  if Detail <> '' then
    ErrMsg := ErrMsg + ': ' + Detail;
  if AError <> 0 then
    ErrMsg := ErrMsg + ' (' + IntToStr(AError) + ')';
end;

function WebFetchHttpWinGet(const RequestUrl, VHost: string;
  const Config: TWebFetchConfig; CancelCheck: TWebFetchCancelCheck;
  out Resp: THttpFetchResponse; out ErrKind: TWebFetchErrorKind;
  out ErrMsg: string): Boolean;
var
  Host, Path, HeaderText: string;
  HostW, PathW, HeaderW, AgentW: UnicodeString;
  Port: Word;
  Secure: Boolean;
  Session, Connection, Request: HInternet;
  Policy: DWORD;
  BytesRead: DWORD;
  Buffer: array[0..16383] of Byte;
  Total: Int64;
  Body: TMemoryStream;
  StartTick: QWord;
  RawBody: RawByteString;
  ContentEncoding: string;
  LastErr: DWORD;
begin
  Result := False;
  FillChar(Resp, SizeOf(Resp), 0);
  ErrKind := wfekInternal;
  ErrMsg := 'HTTP request failed';
  Session := nil;
  Connection := nil;
  Request := nil;
  Body := TMemoryStream.Create;
  try
    ParseRequestUrl(RequestUrl, Host, Path, Port, Secure);
    HostW := UTF8Decode(Host);
    PathW := UTF8Decode(Path);
    AgentW := UTF8Decode(WEB_FETCH_USER_AGENT);
    HeaderText := 'Accept: text/html,application/xhtml+xml,text/plain,text/markdown,application/json;q=0.9,*/*;q=0.8' + #13#10 +
      'Accept-Encoding: gzip, deflate' + #13#10;
    if VHost <> '' then
      HeaderText := HeaderText + 'Host: ' + VHost + #13#10;
    HeaderW := UTF8Decode(HeaderText);

    Session := WinHttpOpen(PWideChar(AgentW), 0, nil, nil, 0);
    if Session = nil then
    begin
      SetWinHttpFailure('WinHTTP open failed', GetLastError, ErrKind, ErrMsg);
      Exit;
    end;
    WinHttpSetTimeouts(Session, Config.ConnectTimeoutMs, Config.ConnectTimeoutMs,
      Config.RequestTimeoutMs, Config.RequestTimeoutMs);

    Connection := WinHttpConnect(Session, PWideChar(HostW), Port, 0);
    if Connection = nil then
    begin
      SetWinHttpFailure('WinHTTP connect failed', GetLastError, ErrKind, ErrMsg);
      Exit;
    end;
    if Secure then
      Request := WinHttpOpenRequest(Connection, 'GET', PWideChar(PathW), nil, nil, nil,
        WINHTTP_FLAG_SECURE)
    else
      Request := WinHttpOpenRequest(Connection, 'GET', PWideChar(PathW), nil, nil, nil, 0);
    if Request = nil then
    begin
      SetWinHttpFailure('WinHTTP open request failed', GetLastError, ErrKind, ErrMsg);
      Exit;
    end;

    Policy := WINHTTP_OPTION_REDIRECT_POLICY_NEVER;
    WinHttpSetOption(Request, WINHTTP_OPTION_REDIRECT_POLICY, @Policy, SizeOf(Policy));

    StartTick := GetTickCount64;
    if not WinHttpSendRequest(Request, PWideChar(HeaderW), DWORD(-1), nil, 0, 0, 0) then
    begin
      if GetTickCount64 - StartTick >= QWord(Config.RequestTimeoutMs) then
      begin
        ErrKind := wfekTimeout;
        ErrMsg := 'Request timed out';
      end
      else
        SetWinHttpFailure('WinHTTP send failed', GetLastError, ErrKind, ErrMsg);
      Exit;
    end;
    if not WinHttpReceiveResponse(Request, nil) then
    begin
      SetWinHttpFailure('WinHTTP receive failed', GetLastError, ErrKind, ErrMsg);
      Exit;
    end;

    Resp.StatusCode := Integer(QueryHeaderDword(Request,
      WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER));
    Resp.ContentType := QueryHeaderString(Request, WINHTTP_QUERY_CONTENT_TYPE);
    Resp.Location := QueryHeaderString(Request, WINHTTP_QUERY_LOCATION);
    ContentEncoding := QueryHeaderString(Request, WINHTTP_QUERY_CONTENT_ENCODING);

    Total := 0;
    repeat
      if Assigned(CancelCheck) and CancelCheck() then
      begin
        ErrKind := wfekCancelled;
        ErrMsg := 'Request cancelled';
        Exit;
      end;
      if GetTickCount64 - StartTick > QWord(Config.RequestTimeoutMs) then
      begin
        ErrKind := wfekTimeout;
        ErrMsg := 'Request timed out';
        Exit;
      end;
      BytesRead := 0;
      if not WinHttpReadData(Request, @Buffer[0], SizeOf(Buffer), BytesRead) then
      begin
        LastErr := GetLastError;
        if LastErr <> 0 then
        begin
          SetWinHttpFailure('WinHTTP read failed', LastErr, ErrKind, ErrMsg);
          Exit;
        end;
        Break;
      end;
      if BytesRead > 0 then
      begin
        if Total + BytesRead > Config.MaxBodyBytes then
        begin
          ErrKind := wfekContentTooLarge;
          ErrMsg := 'Response exceeds size limit';
          Exit;
        end;
        Body.WriteBuffer(Buffer[0], BytesRead);
        Total := Total + BytesRead;
      end;
    until BytesRead = 0;

    SetLength(RawBody, Body.Size);
    if Body.Size > 0 then
    begin
      Body.Position := 0;
      Body.ReadBuffer(RawBody[1], Body.Size);
    end;
    if not MaybeDecompressHttpBody(RawBody, ContentEncoding, Resp.Body, ErrMsg) then
    begin
      ErrKind := wfekInternal;
      if Trim(ErrMsg) = '' then
        ErrMsg := 'Failed to decode compressed response';
      Exit;
    end;
    Result := True;
    ErrKind := wfekNone;
    ErrMsg := '';
  finally
    Body.Free;
    if Request <> nil then WinHttpCloseHandle(Request);
    if Connection <> nil then WinHttpCloseHandle(Connection);
    if Session <> nil then WinHttpCloseHandle(Session);
  end;
end;

{$ELSE}

function WebFetchHttpWinGet(const RequestUrl, VHost: string;
  const Config: TWebFetchConfig; CancelCheck: TWebFetchCancelCheck;
  out Resp: THttpFetchResponse; out ErrKind: TWebFetchErrorKind;
  out ErrMsg: string): Boolean;
begin
  Result := False;
  FillChar(Resp, SizeOf(Resp), 0);
  ErrKind := wfekInternal;
  ErrMsg := 'WinHTTP is only available on Windows';
end;

{$ENDIF}

end.
