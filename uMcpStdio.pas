unit uMcpStdio;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process, fpjson, uMcpTypes, uMcpHttp;

type
  TMcpStdioTransport = class(TInterfacedObject, IMcpTransport)
  private
    FCommand: string;
    FArgsJson: string;
    FWorkingDir: string;
    FTimeoutMs: Integer;
    FProc: TProcess;
    FRequestId: Integer;
    FInitialized: Boolean;
    FCancelCheck: TMcpCancelCheck;
    FReadBuffer: string;
    procedure EnsureProcess;
    function ReadJsonRpcResponse(out ABody: string; out ErrMsg: string): Boolean;
    function WriteJsonRpc(const AMethod: string; AParams: TJSONObject; AIsNotification: Boolean;
      out ErrMsg: string): Boolean;
    function RequestJsonRpc(const AMethod: string; AParams: TJSONObject; AIsNotification: Boolean;
      out AResponseBody: string; out ErrMsg: string): Boolean;
    function BuildArgv: TStringArray;
  public
    constructor Create(const ACommand, AArgsJson, AWorkingDir: string; ATimeoutMs: Integer;
      ACancelCheck: TMcpCancelCheck);
    destructor Destroy; override;
    function EnsureReady(out ErrMsg: string): Boolean;
    function ListTools(out Tools: TMcpToolInfoArray; out ErrMsg: string): Boolean;
    function CallTool(const AServerToolName, AArgumentsJson: string; out AResultText, ErrMsg: string): Boolean;
    procedure Close;
  end;

implementation

uses
  jsonparser, uMcpJson;

function TMcpStdioTransport.BuildArgv: TStringArray;
var
  Data: TJSONData;
  Arr: TJSONArray;
  I: Integer;
begin
  SetLength(Result, 0);
  if Trim(FArgsJson) = '' then Exit;
  try
    Data := GetJSON(FArgsJson);
    try
      if Data is TJSONArray then
      begin
        Arr := TJSONArray(Data);
        SetLength(Result, Arr.Count);
        for I := 0 to Arr.Count - 1 do
          Result[I] := Arr.Strings[I];
      end;
    finally
      Data.Free;
    end;
  except
  end;
end;

constructor TMcpStdioTransport.Create(const ACommand, AArgsJson, AWorkingDir: string;
  ATimeoutMs: Integer; ACancelCheck: TMcpCancelCheck);
begin
  inherited Create;
  FCommand := Trim(ACommand);
  FArgsJson := AArgsJson;
  if Trim(FArgsJson) = '' then
    FArgsJson := '[]';
  FWorkingDir := AWorkingDir;
  if ATimeoutMs < 1000 then ATimeoutMs := MCP_DEFAULT_TIMEOUT_MS;
  FTimeoutMs := ATimeoutMs;
  FProc := nil;
  FRequestId := 0;
  FInitialized := False;
  FCancelCheck := ACancelCheck;
  FReadBuffer := '';
end;

destructor TMcpStdioTransport.Destroy;
begin
  Close;
  inherited Destroy;
end;

procedure TMcpStdioTransport.Close;
begin
  FInitialized := False;
  if FProc <> nil then
  begin
    try
      if FProc.Running then
        FProc.Terminate(0);
    except
    end;
    FreeAndNil(FProc);
  end;
  FReadBuffer := '';
end;

procedure TMcpStdioTransport.EnsureProcess;
var
  Args: TStringArray;
  I: Integer;
begin
  if FProc <> nil then Exit;
  if FCommand = '' then
    raise Exception.Create('MCP stdio command is empty');
  FProc := TProcess.Create(nil);
  FProc.Executable := FCommand;
  Args := BuildArgv;
  FProc.Parameters.Clear;
  for I := 0 to High(Args) do
    FProc.Parameters.Add(Args[I]);
  if FWorkingDir <> '' then
    FProc.CurrentDirectory := FWorkingDir;
  FProc.Options := [poUsePipes, poStderrToOutPut];
  FProc.ShowWindow := swoHide;
  FProc.Execute;
end;

function TMcpStdioTransport.WriteJsonRpc(const AMethod: string; AParams: TJSONObject;
  AIsNotification: Boolean; out ErrMsg: string): Boolean;
var
  Req: TJSONObject;
  Line: string;
  Bytes: TBytes;
begin
  Result := False;
  ErrMsg := '';
  EnsureProcess;
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
    Line := Req.AsJSON + LineEnding;
  finally
    Req.Free;
  end;
  Bytes := TEncoding.UTF8.GetBytes(Line);
  if Length(Bytes) > 0 then
    FProc.Input.WriteBuffer(Bytes[0], Length(Bytes));
  Result := True;
end;

function TMcpStdioTransport.ReadJsonRpcResponse(out ABody: string; out ErrMsg: string): Boolean;
var
  C: AnsiChar;
  StartMs: QWord;
  Ch: Char;
  Line: string;
begin
  Result := False;
  ABody := '';
  ErrMsg := '';
  StartMs := GetTickCount64;
  while GetTickCount64 - StartMs < QWord(FTimeoutMs) do
  begin
    if Assigned(FCancelCheck) and FCancelCheck() then
    begin
      ErrMsg := 'Cancelled';
      Exit;
    end;
    if FProc.Output.NumBytesAvailable > 0 then
    begin
      FProc.Output.Read(C, 1);
      Ch := Char(C);
      if Ch = #10 then
      begin
        Line := Trim(FReadBuffer);
        FReadBuffer := '';
        if Line <> '' then
        begin
          ABody := Line;
          Exit(True);
        end;
      end
      else if Ch <> #13 then
        FReadBuffer := FReadBuffer + Ch;
    end
    else if not FProc.Running and (FProc.Output.NumBytesAvailable = 0) then
    begin
      ErrMsg := 'MCP process exited';
      Exit;
    end
    else
      Sleep(10);
  end;
  ErrMsg := 'MCP stdio read timeout';
end;

function TMcpStdioTransport.RequestJsonRpc(const AMethod: string; AParams: TJSONObject;
  AIsNotification: Boolean; out AResponseBody: string; out ErrMsg: string): Boolean;
begin
  Result := False;
  if not WriteJsonRpc(AMethod, AParams, AIsNotification, ErrMsg) then Exit;
  if AIsNotification then
    Exit(True);
  Result := ReadJsonRpcResponse(AResponseBody, ErrMsg);
end;

function TMcpStdioTransport.EnsureReady(out ErrMsg: string): Boolean;
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
    if not RequestJsonRpc('initialize', Params, False, Resp, ErrMsg) then Exit;
    if not JsonRpcValidateResponse(Resp, ErrMsg) then Exit;
    FInitialized := True;
    RequestJsonRpc('notifications/initialized', nil, True, Resp, ErrMsg);
    Result := True;
  finally
    Params.Free;
  end;
end;

function TMcpStdioTransport.ListTools(out Tools: TMcpToolInfoArray; out ErrMsg: string): Boolean;
var
  Resp: string;
  Params: TJSONObject;
begin
  SetLength(Tools, 0);
  if not EnsureReady(ErrMsg) then Exit(False);
  Params := TJSONObject.Create;
  try
    if not RequestJsonRpc('tools/list', Params, False, Resp, ErrMsg) then Exit(False);
    Result := ParseMcpToolsListResponse(Resp, Tools, ErrMsg);
  finally
    Params.Free;
  end;
end;

function TMcpStdioTransport.CallTool(const AServerToolName, AArgumentsJson: string;
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
      ArgData := GetJSON(AArgumentsJson);
      if ArgData is TJSONObject then
        Params.Add('arguments', ArgData)
      else
      begin
        ArgData.Free;
        Params.Add('arguments', TJSONObject.Create);
      end;
    end;
    if not RequestJsonRpc('tools/call', Params, False, Resp, ErrMsg) then Exit(False);
    AResultText := ExtractMcpCallResultText(Resp);
    Result := True;
  finally
    Params.Free;
  end;
end;

end.
