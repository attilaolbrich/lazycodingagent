unit uBrowserNetworkCollector;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uCdpConnection;

type
  TBrowserNetworkCollector = class
  private
    FEntries: TStringList;
    FMaxEntries: Integer;
    function RedactUrl(const Url: string): string;
    procedure AddMeta(const RequestId, Url, Method, ResType: string;
      Status: Integer; Failed: Boolean; FailText: string);
  public
    constructor Create(AMaxEntries: Integer = 500);
    destructor Destroy; override;
    procedure HandleEvent(const Method, ParamsJson: AnsiString);
    function ReadEntries(FailedOnly: Boolean; StatusMin: Integer;
      MaxCount: Integer): TJSONArray;
    procedure Clear;
  end;

implementation

constructor TBrowserNetworkCollector.Create(AMaxEntries: Integer);
begin
  inherited Create;
  FEntries := TStringList.Create;
  FMaxEntries := AMaxEntries;
  if FMaxEntries < 50 then
    FMaxEntries := 50;
end;

destructor TBrowserNetworkCollector.Destroy;
begin
  FEntries.Free;
  inherited Destroy;
end;

procedure TBrowserNetworkCollector.Clear;
begin
  FEntries.Clear;
end;

function TBrowserNetworkCollector.RedactUrl(const Url: string): string;
var
  P: SizeInt;
  L: string;
begin
  L := Url;
  P := Pos('token=', LowerCase(L));
  if P > 0 then
    L := Copy(L, 1, P + 5) + '[redacted]';
  P := Pos('password=', LowerCase(L));
  if P > 0 then
    L := Copy(L, 1, P + 8) + '[redacted]';
  Result := L;
end;

procedure TBrowserNetworkCollector.AddMeta(const RequestId, Url, Method,
  ResType: string; Status: Integer; Failed: Boolean; FailText: string);
var
  O: TJSONObject;
begin
  O := TJSONObject.Create;
  O.Add('request_id', RequestId);
  O.Add('url', RedactUrl(Url));
  O.Add('method', Method);
  O.Add('resource_type', ResType);
  O.Add('status', Status);
  O.Add('failed', Failed);
  if FailText <> '' then
    O.Add('failure', FailText);
  FEntries.Add(O.AsJSON);
  O.Free;
  while FEntries.Count > FMaxEntries do
    FEntries.Delete(0);
end;

procedure TBrowserNetworkCollector.HandleEvent(const Method, ParamsJson: AnsiString);
var
  Params: TJSONObject;
  ReqId, Url, HttpMethod, ResType, FailText: string;
  Status: Integer;
begin
  Params := TJSONObject(GetJSON(ParamsJson));
  try
    if Method = 'Network.requestWillBeSent' then
    begin
      ReqId := Params.Get('requestId', '');
      if Params.Find('request') <> nil then
        with TJSONObject(Params.Find('request')) do
        begin
          Url := Get('url', '');
          HttpMethod := Get('method', 'GET');
        end;
      ResType := Params.Get('type', '');
      AddMeta(ReqId, Url, HttpMethod, ResType, 0, False, '');
    end
    else if Method = 'Network.responseReceived' then
    begin
      ReqId := Params.Get('requestId', '');
      Status := 0;
      Url := '';
      if Params.Find('response') <> nil then
        with TJSONObject(Params.Find('response')) do
        begin
          Status := Get('status', 0);
          Url := Get('url', '');
        end;
      AddMeta(ReqId, Url, '', '', Status, False, '');
    end
    else if Method = 'Network.loadingFailed' then
    begin
      ReqId := Params.Get('requestId', '');
      FailText := Params.Get('errorText', 'failed');
      AddMeta(ReqId, '', '', '', 0, True, FailText);
    end;
  finally
    Params.Free;
  end;
end;

function TBrowserNetworkCollector.ReadEntries(FailedOnly: Boolean;
  StatusMin: Integer; MaxCount: Integer): TJSONArray;
var
  Arr: TJSONArray;
  I, N: Integer;
  O: TJSONObject;
  St: Integer;
  Failed: Boolean;
begin
  Arr := TJSONArray.Create;
  if MaxCount <= 0 then
    MaxCount := 100;
  N := 0;
  for I := FEntries.Count - 1 downto 0 do
  begin
    O := TJSONObject(GetJSON(FEntries[I]));
    try
      Failed := O.Get('failed', False);
      St := O.Get('status', 0);
      if FailedOnly and not Failed then
        Continue;
      if (StatusMin > 0) and (St < StatusMin) and not Failed then
        Continue;
      Arr.Add(O.Clone);
      Inc(N);
      if N >= MaxCount then Break;
    finally
      O.Free;
    end;
  end;
  Result := Arr;
end;

end.
