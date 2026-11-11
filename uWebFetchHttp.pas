unit uWebFetchHttp;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uWebFetchTypes, uWebFetchUrl;

function HttpFetchUrl(const RequestUrl: string; const Parsed: TWebFetchUrl;
  const ConnectIP, VHost: string; const Config: TWebFetchConfig;
  CancelCheck: TWebFetchCancelCheck; out Resp: THttpFetchResponse;
  out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;

implementation

uses
  uSslRuntime, uWebFetchHttpBody
  {$IFDEF MSWINDOWS}
  , uWebFetchHttpWin
  {$ELSE}
  , fphttpclient, opensslsockets, sslsockets, ssockets
  {$ENDIF};

type
  TCancelAwareStream = class(TMemoryStream)
  private
    FCancelCheck: TWebFetchCancelCheck;
    FMaxBytes: Int64;
    FErrKind: TWebFetchErrorKind;
    FErrMsg: string;
    FFailed: Boolean;
  public
    constructor Create(ACancelCheck: TWebFetchCancelCheck; AMaxBytes: Int64);
    function Write(const Buffer; Count: Longint): Longint; override;
    property Failed: Boolean read FFailed;
    property ErrKind: TWebFetchErrorKind read FErrKind;
    property ErrMsg: string read FErrMsg;
  end;

constructor TCancelAwareStream.Create(ACancelCheck: TWebFetchCancelCheck; AMaxBytes: Int64);
begin
  inherited Create;
  FCancelCheck := ACancelCheck;
  FMaxBytes := AMaxBytes;
  FFailed := False;
  FErrKind := wfekNone;
  FErrMsg := '';
end;

function TCancelAwareStream.Write(const Buffer; Count: Longint): Longint;
begin
  if FFailed then Exit(0);
  if Assigned(FCancelCheck) and FCancelCheck() then
  begin
    FFailed := True;
    FErrKind := wfekCancelled;
    FErrMsg := 'Request cancelled';
    Exit(0);
  end;
  if (FMaxBytes > 0) and (Size + Count > FMaxBytes) then
  begin
    FFailed := True;
    FErrKind := wfekContentTooLarge;
    FErrMsg := 'Response exceeds size limit';
    Exit(0);
  end;
  Result := inherited Write(Buffer, Count);
end;

{$IFNDEF MSWINDOWS}
type
  TWebFetchSslBridge = class
  public
    SniHost: string;
    procedure OnGetSocket(Sender: TObject; const UseSSL: Boolean;
      out AHandler: TSocketHandler);
  end;

var
  GWebFetchSslBridge: TWebFetchSslBridge;

procedure TWebFetchSslBridge.OnGetSocket(Sender: TObject; const UseSSL: Boolean;
  out AHandler: TSocketHandler);
begin
  if not UseSSL then
  begin
    AHandler := nil;
    Exit;
  end;
  AHandler := TSSLSocketHandler.GetDefaultHandler;
  if SniHost <> '' then
    TSSLSocketHandler(AHandler).CertificateData.HostName := SniHost;
end;

function HttpFetchUrlUnix(const RequestUrl, VHost: string; AAddHostHeader: Boolean;
  const Config: TWebFetchConfig; CancelCheck: TWebFetchCancelCheck;
  out Resp: THttpFetchResponse; out ErrKind: TWebFetchErrorKind;
  out ErrMsg: string): Boolean;
var
  Client: TFPHTTPClient;
  OutStream: TCancelAwareStream;
  StartMs: QWord;
  RawBody: RawByteString;
  ContentEncoding: string;
begin
  Result := False;
  FillChar(Resp, SizeOf(Resp), 0);
  ErrKind := wfekInternal;
  ErrMsg := 'HTTP request failed';

  if not EnsureOpenSslAvailable then
  begin
    ErrKind := wfekTlsFailure;
    ErrMsg := OpenSslUnavailableUserMessage;
    Exit;
  end;

  OutStream := TCancelAwareStream.Create(CancelCheck, Config.MaxBodyBytes);
  Client := TFPHTTPClient.Create(nil);
  try
    Client.AllowRedirect := False;
    Client.IOTimeout := Config.RequestTimeoutMs;
    if Config.ConnectTimeoutMs < Config.RequestTimeoutMs then
      Client.ConnectTimeout := Config.ConnectTimeoutMs
    else
      Client.ConnectTimeout := Config.RequestTimeoutMs;
    Client.AddHeader('User-Agent', WEB_FETCH_USER_AGENT);
    Client.AddHeader('Accept-Encoding', 'gzip, deflate');
    Client.AddHeader('Accept', 'text/html,application/xhtml+xml,text/plain,text/markdown,application/json;q=0.9,*/*;q=0.8');
    if AAddHostHeader and (VHost <> '') then
      Client.AddHeader('Host', VHost);
    if VHost <> '' then
      GWebFetchSslBridge.SniHost := VHost;
    Client.OnGetSocketHandler := @GWebFetchSslBridge.OnGetSocket;
    StartMs := GetTickCount64;
    try
      Client.Get(RequestUrl, OutStream);
    except
      on E: EInOutError do
      begin
        if GetTickCount64 - StartMs >= QWord(Config.RequestTimeoutMs) then
        begin
          ErrKind := wfekTimeout;
          ErrMsg := 'Request timed out';
        end
        else
        begin
          ErrKind := wfekTlsFailure;
          if Trim(E.Message) <> '' then
            ErrMsg := 'Secure connection failed: ' + E.Message
          else
            ErrMsg := 'Secure connection failed';
        end;
        Exit;
      end;
      on E: EHTTPClient do
      begin
        if GetTickCount64 - StartMs >= QWord(Config.RequestTimeoutMs) then
        begin
          ErrKind := wfekTimeout;
          ErrMsg := 'Request timed out';
        end
        else
        begin
          ErrKind := wfekInternal;
          if Trim(E.Message) <> '' then
            ErrMsg := 'HTTP request failed: ' + E.Message
          else
            ErrMsg := 'HTTP request failed';
        end;
        Exit;
      end;
      on E: Exception do
      begin
        if GetTickCount64 - StartMs >= QWord(Config.RequestTimeoutMs) then
        begin
          ErrKind := wfekTimeout;
          ErrMsg := 'Request timed out';
        end
        else
        begin
          ErrKind := wfekInternal;
          if Trim(E.Message) <> '' then
            ErrMsg := 'HTTP request failed: ' + E.Message
          else
            ErrMsg := 'HTTP request failed';
        end;
        Exit;
      end;
    end;

    if OutStream.Failed then
    begin
      ErrKind := OutStream.ErrKind;
      ErrMsg := OutStream.ErrMsg;
      Exit;
    end;

    Resp.StatusCode := Client.ResponseStatusCode;
    Resp.ContentType := HttpHeaderValue(Client.ResponseHeaders, 'Content-Type');
    Resp.Location := HttpHeaderValue(Client.ResponseHeaders, 'Location');
    ContentEncoding := HttpHeaderValue(Client.ResponseHeaders, 'Content-Encoding');
    SetLength(RawBody, OutStream.Size);
    if OutStream.Size > 0 then
    begin
      OutStream.Position := 0;
      OutStream.ReadBuffer(RawBody[1], OutStream.Size);
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
    GWebFetchSslBridge.SniHost := '';
    Client.Free;
    OutStream.Free;
  end;
end;

{$ENDIF}

function HttpFetchUrl(const RequestUrl: string; const Parsed: TWebFetchUrl;
  const ConnectIP, VHost: string; const Config: TWebFetchConfig;
  CancelCheck: TWebFetchCancelCheck; out Resp: THttpFetchResponse;
  out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;
var
  Pinned, FetchUrl: string;
  UseHostnameUrl: Boolean;
begin
  Pinned := BuildPinnedRequestUrl(Parsed, ConnectIP);
  UseHostnameUrl := (VHost <> '') and SameText(VHost, Parsed.Host) and (ConnectIP <> '') and
    not SameText(ConnectIP, Parsed.Host);
  if UseHostnameUrl then
    FetchUrl := RequestUrl
  else
    FetchUrl := Pinned;
  {$IFDEF MSWINDOWS}
  Result := WebFetchHttpWinGet(FetchUrl, VHost, Config, CancelCheck, Resp, ErrKind, ErrMsg);
  {$ELSE}
  Result := HttpFetchUrlUnix(FetchUrl, VHost, not UseHostnameUrl, Config, CancelCheck, Resp,
    ErrKind, ErrMsg);
  {$ENDIF}
end;

{$IFNDEF MSWINDOWS}
initialization
  GWebFetchSslBridge := TWebFetchSslBridge.Create;

finalization
  GWebFetchSslBridge.Free;
{$ENDIF}

end.
