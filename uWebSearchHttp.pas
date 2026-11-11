unit uWebSearchHttp;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, uWebSearchTypes;

type
  IWebSearchTransport = interface
    function Request(const AMethod, AUrl: string; const AHeaders: array of string;
      const ABody: RawByteString; ATimeoutMs: Integer;
      CancelCheck: TWebSearchCancelCheck; out AResp: TWebSearchHttpResponse;
      out ErrCode, ErrMsg: string): Boolean;
  end;

  TWebSearchProductionTransport = class(TInterfacedObject, IWebSearchTransport)
  public
    function Request(const AMethod, AUrl: string; const AHeaders: array of string;
      const ABody: RawByteString; ATimeoutMs: Integer;
      CancelCheck: TWebSearchCancelCheck; out AResp: TWebSearchHttpResponse;
      out ErrCode, ErrMsg: string): Boolean;
  end;

implementation

uses
  fphttpclient, uSslRuntime
  {$IFNDEF MSWINDOWS}
  , opensslsockets, sslsockets, ssockets
  {$ENDIF}
  ;

type
  TWebSearchCancelStream = class(TMemoryStream)
  private
    FCancelCheck: TWebSearchCancelCheck;
    FMaxBytes: Int64;
    FFailed: Boolean;
  public
    constructor Create(ACancelCheck: TWebSearchCancelCheck; AMaxBytes: Int64);
    function Write(const Buffer; Count: Longint): Longint; override;
    property Failed: Boolean read FFailed;
  end;

{$IFNDEF MSWINDOWS}
type
  TWebSearchSslBridge = class
  public
    SniHost: string;
    procedure OnGetSocket(Sender: TObject; const UseSSL: Boolean;
      out AHandler: TSocketHandler);
  end;

var
  GWebSearchSslBridge: TWebSearchSslBridge;

procedure TWebSearchSslBridge.OnGetSocket(Sender: TObject; const UseSSL: Boolean;
  out AHandler: TSocketHandler);
begin
  if not UseSSL then begin
    AHandler := nil;
    Exit;
  end;
  AHandler := TSSLSocketHandler.GetDefaultHandler;
  if SniHost <> '' then
    TSSLSocketHandler(AHandler).CertificateData.HostName := SniHost;
end;
{$ENDIF}

constructor TWebSearchCancelStream.Create(ACancelCheck: TWebSearchCancelCheck; AMaxBytes: Int64);
begin
  inherited Create;
  FCancelCheck := ACancelCheck;
  FMaxBytes := AMaxBytes;
  FFailed := False;
end;

function TWebSearchCancelStream.Write(const Buffer; Count: Longint): Longint;
begin
  if FFailed then Exit(0);
  if Assigned(FCancelCheck) and FCancelCheck() then begin
    FFailed := True;
    Exit(0);
  end;
  if (FMaxBytes > 0) and (Size + Count > FMaxBytes) then begin
    FFailed := True;
    Exit(0);
  end;
  Result := inherited Write(Buffer, Count);
end;

function ExtractHostFromUrl(const AUrl: string): string;
var
  S, Authority: string;
  P, SlashPos, ColonPos: SizeInt;
begin
  Result := '';
  S := Trim(AUrl);
  if SameText(Copy(S, 1, 8), 'https://') then
    Delete(S, 1, 8)
  else if SameText(Copy(S, 1, 7), 'http://') then
    Delete(S, 1, 7)
  else
    Exit;
  SlashPos := Pos('/', S);
  if SlashPos > 0 then
    Authority := Copy(S, 1, SlashPos - 1)
  else
    Authority := S;
  ColonPos := Pos(':', Authority);
  if ColonPos > 0 then
    Result := Copy(Authority, 1, ColonPos - 1)
  else
    Result := Authority;
end;

function TWebSearchProductionTransport.Request(const AMethod, AUrl: string;
  const AHeaders: array of string; const ABody: RawByteString; ATimeoutMs: Integer;
  CancelCheck: TWebSearchCancelCheck; out AResp: TWebSearchHttpResponse;
  out ErrCode, ErrMsg: string): Boolean;
var
  Client: TFPHTTPClient;
  OutStream: TWebSearchCancelStream;
  I: Integer;
  HeaderName, HeaderValue: string;
  P: SizeInt;
  StartMs: QWord;
  Host: string;
  BodyStream: TStringStream;
begin
  Result := False;
  FillChar(AResp, SizeOf(AResp), 0);
  ErrCode := WEB_SEARCH_ERR_CONNECTION;
  ErrMsg := 'HTTP request failed';

  if Assigned(CancelCheck) and CancelCheck() then begin
    ErrCode := WEB_SEARCH_ERR_CANCELLED;
    ErrMsg := 'Search cancelled';
    Exit;
  end;

  {$IFNDEF MSWINDOWS}
  if (Pos('https://', LowerCase(AUrl)) > 0) and not EnsureOpenSslAvailable then begin
    ErrMsg := OpenSslUnavailableUserMessage;
    Exit;
  end;
  {$ENDIF}

  OutStream := TWebSearchCancelStream.Create(CancelCheck, WEB_SEARCH_MAX_BODY_BYTES);
  Client := TFPHTTPClient.Create(nil);
  try
    Client.AllowRedirect := False;
    if ATimeoutMs < 1000 then ATimeoutMs := 1000;
    Client.IOTimeout := ATimeoutMs;
    Client.ConnectTimeout := ATimeoutMs;
    Client.AddHeader('User-Agent', WEB_SEARCH_USER_AGENT);
    Client.AddHeader('Accept', 'application/json');
    for I := Low(AHeaders) to High(AHeaders) do begin
      P := Pos(':', AHeaders[I]);
      if P <= 0 then Continue;
      HeaderName := Trim(Copy(AHeaders[I], 1, P - 1));
      HeaderValue := Trim(Copy(AHeaders[I], P + 1, MaxInt));
      if HeaderName <> '' then
        Client.AddHeader(HeaderName, HeaderValue);
    end;
    Host := ExtractHostFromUrl(AUrl);
    {$IFNDEF MSWINDOWS}
    if Host <> '' then begin
      GWebSearchSslBridge.SniHost := Host;
      Client.OnGetSocketHandler := @GWebSearchSslBridge.OnGetSocket;
    end;
    {$ENDIF}
    StartMs := GetTickCount64;
    try
      if SameText(AMethod, 'POST') then begin
        BodyStream := TStringStream.Create(string(ABody));
        try
          Client.RequestBody := BodyStream;
          Client.Post(AUrl, OutStream);
        finally
          Client.RequestBody := nil;
          BodyStream.Free;
        end;
      end else
        Client.Get(AUrl, OutStream);
    except
      on E: Exception do begin
        if GetTickCount64 - StartMs >= QWord(ATimeoutMs) then begin
          ErrCode := WEB_SEARCH_ERR_TIMEOUT;
          ErrMsg := 'Request timed out';
        end else
          ErrMsg := 'HTTP request failed';
        Exit;
      end;
    end;
    if OutStream.Failed and Assigned(CancelCheck) and CancelCheck() then begin
      ErrCode := WEB_SEARCH_ERR_CANCELLED;
      ErrMsg := 'Search cancelled';
      Exit;
    end;
    if OutStream.Failed then begin
      ErrMsg := 'Response exceeds size limit';
      Exit;
    end;
    AResp.StatusCode := Client.ResponseStatusCode;
    AResp.ContentType := Client.ResponseHeaders.Values['Content-Type'];
    if AResp.ContentType = '' then
      AResp.ContentType := Client.ResponseHeaders.Values['content-type'];
    SetLength(AResp.Body, OutStream.Size);
    if OutStream.Size > 0 then begin
      OutStream.Position := 0;
      OutStream.ReadBuffer(AResp.Body[1], OutStream.Size);
    end;
    Result := True;
    ErrCode := '';
    ErrMsg := '';
  finally
    {$IFNDEF MSWINDOWS}
    GWebSearchSslBridge.SniHost := '';
    {$ENDIF}
    Client.Free;
    OutStream.Free;
  end;
end;

{$IFNDEF MSWINDOWS}
initialization
  GWebSearchSslBridge := TWebSearchSslBridge.Create;

finalization
  GWebSearchSslBridge.Free;
{$ENDIF}

end.
