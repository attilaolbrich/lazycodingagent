unit uMcpHttp;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, uMcpTypes;

type
  TMcpCancelCheck = function: Boolean of object;

  IMcpTransport = interface
    ['{7E8F9A0B-1C2D-3E4F-5A6B-7C8D9E0F1A2B}']
    function EnsureReady(out ErrMsg: string): Boolean;
    function ListTools(out Tools: TMcpToolInfoArray; out ErrMsg: string): Boolean;
    function CallTool(const AServerToolName, AArgumentsJson: string; out AResultText, ErrMsg: string): Boolean;
    procedure Close;
  end;

  TMcpHttpTransport = class(TInterfacedObject, IMcpTransport)
  private
    FUrl: string;
    FBearer: string;
    FTimeoutMs: Integer;
    FSessionId: string;
    FRequestId: Integer;
    FInitialized: Boolean;
    FCancelCheck: TMcpCancelCheck;
    function PostJsonRpc(const AMethod: string; AParams: TJSONObject; AIsNotification: Boolean;
      out AResponseBody: string; out ErrMsg: string): Boolean;
  public
    constructor Create(const AUrl, ABearer: string; ATimeoutMs: Integer;
      ACancelCheck: TMcpCancelCheck);
    function EnsureReady(out ErrMsg: string): Boolean;
    function ListTools(out Tools: TMcpToolInfoArray; out ErrMsg: string): Boolean;
    function CallTool(const AServerToolName, AArgumentsJson: string; out AResultText, ErrMsg: string): Boolean;
    procedure Close;
  end;

implementation

uses
  jsonparser, fphttpclient, uSslRuntime, uMcpJson
  {$IFNDEF MSWINDOWS}
  , opensslsockets, sslsockets, ssockets
  {$ENDIF}
  ;

type
  TMcpSslBridge = class
  public
    SniHost: string;
    procedure OnGetSocket(Sender: TObject; const UseSSL: Boolean; out AHandler: TSocketHandler);
  end;

var
  GMcpSslBridge: TMcpSslBridge;

{$IFNDEF MSWINDOWS}
procedure TMcpSslBridge.OnGetSocket(Sender: TObject; const UseSSL: Boolean; out AHandler: TSocketHandler);
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

function ExtractHostFromUrl(const AUrl: string): string;
var
  S, Authority: string;
  SlashPos, ColonPos: SizeInt;
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

constructor TMcpHttpTransport.Create(const AUrl, ABearer: string; ATimeoutMs: Integer;
  ACancelCheck: TMcpCancelCheck);
begin
  inherited Create;
  FUrl := Trim(AUrl);
  FBearer := ABearer;
  if ATimeoutMs < 1000 then ATimeoutMs := MCP_DEFAULT_TIMEOUT_MS;
  FTimeoutMs := ATimeoutMs;
  FRequestId := 0;
  FInitialized := False;
  FCancelCheck := ACancelCheck;
end;

procedure TMcpHttpTransport.Close;
begin
  FInitialized := False;
  FSessionId := '';
end;

function TMcpHttpTransport.PostJsonRpc(const AMethod: string; AParams: TJSONObject;
  AIsNotification: Boolean; out AResponseBody: string; out ErrMsg: string): Boolean;
var
  Client: TFPHTTPClient;
  BodyStream, OutStream: TStringStream;
  Req: TJSONObject;
  Body: string;
begin
  Result := False;
  AResponseBody := '';
  ErrMsg := '';
  if FUrl = '' then
  begin
    ErrMsg := 'MCP URL is empty';
    Exit;
  end;
  if Assigned(FCancelCheck) and FCancelCheck() then
  begin
    ErrMsg := 'Cancelled';
    Exit;
  end;
  {$IFNDEF MSWINDOWS}
  if (Pos('https://', LowerCase(FUrl)) > 0) and not EnsureOpenSslAvailable then
  begin
    ErrMsg := OpenSslUnavailableUserMessage;
    Exit;
  end;
  {$ENDIF}
  Req := TJSONObject.Create;
  try
    Req.Add('jsonrpc', '2.0');
    if not AIsNotification then
    begin
      Inc(FRequestId);
      Req.Add('id', FRequestId);
    end;
    Req.Add('method', AMethod);
    if AParams <> nil then
      Req.Add('params', AParams.Clone)
    else
      Req.Add('params', TJSONObject.Create);
    Body := Req.AsJSON;
  finally
    Req.Free;
  end;

  Client := TFPHTTPClient.Create(nil);
  OutStream := TStringStream.Create('', fmCreate);
  try
    try
      Client.AllowRedirect := True;
      Client.IOTimeout := FTimeoutMs;
      Client.ConnectTimeout := FTimeoutMs;
      Client.AddHeader('Accept', 'application/json, text/event-stream');
      Client.AddHeader('Content-Type', 'application/json');
      if FBearer <> '' then
        Client.AddHeader('Authorization', 'Bearer ' + FBearer);
      if FSessionId <> '' then
        Client.AddHeader('Mcp-Session-Id', FSessionId);
      {$IFNDEF MSWINDOWS}
      GMcpSslBridge.SniHost := ExtractHostFromUrl(FUrl);
      Client.OnGetSocketHandler := @GMcpSslBridge.OnGetSocket;
      {$ENDIF}
      BodyStream := TStringStream.Create(Body);
      try
        Client.RequestBody := BodyStream;
        Client.Post(FUrl, OutStream);
      finally
        Client.RequestBody := nil;
        BodyStream.Free;
      end;
      AResponseBody := ExtractJsonRpcFromHttpBody(OutStream.DataString);
      if Client.ResponseHeaders <> nil then
      begin
        if Client.ResponseHeaders.Values['mcp-session-id'] <> '' then
          FSessionId := Client.ResponseHeaders.Values['mcp-session-id']
        else if Client.ResponseHeaders.Values['Mcp-Session-Id'] <> '' then
          FSessionId := Client.ResponseHeaders.Values['Mcp-Session-Id'];
      end;
      if Client.ResponseStatusCode >= 400 then
      begin
        ErrMsg := Format('HTTP %d: %s', [Client.ResponseStatusCode, Copy(AResponseBody, 1, 512)]);
        Exit;
      end;
      Result := True;
    except
      on E: Exception do
      begin
        ErrMsg := E.Message;
        if ErrMsg = '' then
          ErrMsg := 'HTTP request failed';
      end;
    end;
  finally
    Client.Free;
    OutStream.Free;
  end;
end;

function TMcpHttpTransport.EnsureReady(out ErrMsg: string): Boolean;
var
  Params, ClientInfo, Capabilities: TJSONObject;
  Resp: string;
begin
  Result := FInitialized;
  if Result then Exit;
  Params := TJSONObject.Create;
  ClientInfo := TJSONObject.Create;
  Capabilities := TJSONObject.Create;
  try
    ClientInfo.Add('name', MCP_CLIENT_NAME);
    ClientInfo.Add('version', MCP_CLIENT_VERSION);
    Params.Add('protocolVersion', MCP_PROTOCOL_VERSION);
    Params.Add('capabilities', Capabilities);
    Params.Add('clientInfo', ClientInfo);
    if not PostJsonRpc('initialize', Params, False, Resp, ErrMsg) then
      Exit;
    if not JsonRpcValidateResponse(Resp, ErrMsg) then
      Exit;
    FInitialized := True;
    PostJsonRpc('notifications/initialized', nil, True, Resp, ErrMsg);
    Result := True;
  finally
    Params.Free;
  end;
end;

function TMcpHttpTransport.ListTools(out Tools: TMcpToolInfoArray; out ErrMsg: string): Boolean;
var
  Resp: string;
  Params: TJSONObject;
begin
  SetLength(Tools, 0);
  if not EnsureReady(ErrMsg) then Exit(False);
  Params := TJSONObject.Create;
  try
    if not PostJsonRpc('tools/list', Params, False, Resp, ErrMsg) then
      Exit(False);
    Result := ParseMcpToolsListResponse(Resp, Tools, ErrMsg);
  finally
    Params.Free;
  end;
end;

function TMcpHttpTransport.CallTool(const AServerToolName, AArgumentsJson: string;
  out AResultText, ErrMsg: string): Boolean;
var
  Resp: string;
  Params: TJSONObject;
  ArgData: TJSONData;
begin
  AResultText := '';
  if not EnsureReady(ErrMsg) then Exit(False);
  Params := TJSONObject.Create;
  try
    Params.Add('name', AServerToolName);
    if Trim(AArgumentsJson) = '' then
      Params.Add('arguments', TJSONObject.Create)
    else begin
      try
        ArgData := GetJSON(AArgumentsJson);
      except
        on E: Exception do
        begin
          ErrMsg := 'Invalid tool arguments JSON: ' + E.Message;
          Exit(False);
        end;
      end;
      if ArgData is TJSONObject then
        Params.Add('arguments', ArgData)
      else
      begin
        ArgData.Free;
        Params.Add('arguments', TJSONObject.Create);
      end;
    end;
    if not PostJsonRpc('tools/call', Params, False, Resp, ErrMsg) then
      Exit(False);
    AResultText := ExtractMcpCallResultText(Resp);
    Result := True;
  finally
    Params.Free;
  end;
end;

initialization
  GMcpSslBridge := TMcpSslBridge.Create;

finalization
  FreeAndNil(GMcpSslBridge);

end.
