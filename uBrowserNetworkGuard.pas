unit uBrowserNetworkGuard;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uCdpConnection, uBrowserReadTypes;

type
  TBrowserNetworkGuard = class
  private
    FConnection: TCdpConnection;
    FAllowLocalhost: Boolean;
    FWorkspaceRoot: string;
    FRequestIds: TStringList;
    function FailRequest(const RequestId, ErrorReason: string): Boolean;
    function ContinueRequest(const RequestId: string): Boolean;
  public
    constructor Create(AConnection: TCdpConnection; AllowLocalhost: Boolean;
      const WorkspaceRoot: string);
    destructor Destroy; override;
    procedure HandleEvent(const Method, ParamsJson: AnsiString);
    function Enable(CancelCheck: TBrowserReadCancelCheck): Boolean;
  end;

implementation

uses
  uBrowserReadUrl;

constructor TBrowserNetworkGuard.Create(AConnection: TCdpConnection; AllowLocalhost: Boolean;
  const WorkspaceRoot: string);
begin
  inherited Create;
  FConnection := AConnection;
  FAllowLocalhost := AllowLocalhost;
  FWorkspaceRoot := WorkspaceRoot;
  FRequestIds := TStringList.Create;
end;

destructor TBrowserNetworkGuard.Destroy;
begin
  FRequestIds.Free;
  inherited Destroy;
end;

function TBrowserNetworkGuard.FailRequest(const RequestId, ErrorReason: string): Boolean;
var
  Params, ResultObj: TJSONObject;
begin
  Params := TJSONObject.Create;
  try
    Params.Add('requestId', RequestId);
    Params.Add('errorReason', ErrorReason);
    Result := FConnection.SendCommand('Fetch.failRequest', Params, 10000, nil, ResultObj);
  finally
    Params.Free;
    if Assigned(ResultObj) then ResultObj.Free;
  end;
end;

function TBrowserNetworkGuard.ContinueRequest(const RequestId: string): Boolean;
var
  Params, ResultObj: TJSONObject;
begin
  Params := TJSONObject.Create;
  try
    Params.Add('requestId', RequestId);
    Result := FConnection.SendCommand('Fetch.continueRequest', Params, 10000, nil, ResultObj);
  finally
    Params.Free;
    if Assigned(ResultObj) then ResultObj.Free;
  end;
end;

procedure TBrowserNetworkGuard.HandleEvent(const Method, ParamsJson: AnsiString);
var
  Params: TJSONObject;
  RequestId, Url: string;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
begin
  if Method <> 'Fetch.requestPaused' then Exit;
  Params := TJSONObject(GetJSON(ParamsJson));
  try
    RequestId := Params.Get('requestId', '');
    if Params.Find('request') <> nil then
      Url := TJSONObject(Params.Find('request')).Get('url', '')
    else
      Url := '';
    if RequestId = '' then Exit;
    if not ValidateBrowserReadRequestUrl(Url, FAllowLocalhost, FWorkspaceRoot, ErrKind,
      ErrMsg) then
      FailRequest(RequestId, 'BlockedByClient')
    else
      ContinueRequest(RequestId);
  finally
    Params.Free;
  end;
end;

function TBrowserNetworkGuard.Enable(CancelCheck: TBrowserReadCancelCheck): Boolean;
var
  Params, Patterns, Pat, ResultObj: TJSONObject;
  PatArr: TJSONArray;
begin
  Params := TJSONObject.Create;
  PatArr := TJSONArray.Create;
  try
    Params.Add('handleAuthRequests', False);
    Pat := TJSONObject.Create;
    Pat.Add('urlPattern', '*');
    PatArr.Add(Pat);
    Params.Add('patterns', PatArr);
    Result := FConnection.SendCommand('Fetch.enable', Params, 15000, CancelCheck, ResultObj);
  finally
    Params.Free;
    if Assigned(ResultObj) then ResultObj.Free;
  end;
end;

end.
