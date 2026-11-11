program test_browser_read;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, fpjson, jsonparser,
  uBrowserReadTypes, uBrowserReadUrl,
  uCdpConnection;

procedure Fail(const Msg: string);
begin
  WriteLn('FAIL: ', Msg);
  Halt(1);
end;

type
  TMockTransport = class(TInterfacedObject, ICdpTransport)
  private
    FQueue: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    function Connected: Boolean;
    function SendText(const Text: UTF8String): Boolean;
    function TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean;
    procedure Disconnect;
    procedure Enqueue(const Msg: string);
  end;

  TMockConn = class
  public
    class function RunCommandRoundTrip: Boolean;
  end;

constructor TMockTransport.Create;
begin
  inherited Create;
  FQueue := TStringList.Create;
end;

destructor TMockTransport.Destroy;
begin
  FQueue.Free;
  inherited Destroy;
end;

function TMockTransport.Connected: Boolean;
begin
  Result := True;
end;

function TMockTransport.SendText(const Text: UTF8String): Boolean;
var
  O: TJSONObject;
  Id: Integer;
begin
  O := TJSONObject(GetJSON(Text));
  try
    Id := O.Get('id', 0);
    Enqueue('{"id":' + IntToStr(Id) + ',"result":{}}');
  finally
    O.Free;
  end;
  Result := True;
end;

function TMockTransport.TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean;
begin
  if FQueue.Count = 0 then Exit(False);
  Text := UTF8String(FQueue[0]);
  FQueue.Delete(0);
  Result := True;
end;

procedure TMockTransport.Disconnect;
begin
end;

procedure TMockTransport.Enqueue(const Msg: string);
begin
  FQueue.Add(Msg);
end;

class function TMockConn.RunCommandRoundTrip: Boolean;
var
  Transport: ICdpTransport;
  Conn: TCdpConnection;
  Params, Res: TJSONObject;
begin
  Transport := TMockTransport.Create;
  Conn := TCdpConnection.Create(Transport);
  try
    Params := TJSONObject.Create;
    try
      Params.Add('url', 'about:blank');
      Result := Conn.SendCommand('Page.navigate', Params, 5000, nil, Res);
      if not Result then Exit(False);
      if Res = nil then Exit(False);
    finally
      Params.Free;
      if Assigned(Res) then Res.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TestUrlGuards;
var
  K: TBrowserReadErrorKind;
  Msg: string;
  WsRoot, NestedDir, NestedFile, OutsideDir, OutsideFile, FileUrl, OutsideUrl: string;
  Sl: TStringList;
begin
  if ValidateBrowserReadUrl('http://127.0.0.1/', False, '', K, Msg) then
    Fail('expected block for loopback');
  if K <> brekAccessDenied then
    Fail('wrong error kind for loopback');
  if ValidateBrowserReadUrl('ftp://example.com/', False, '', K, Msg) then
    Fail('expected block for ftp');
  if not ValidateBrowserReadUrl('http://127.0.0.1/', True, '', K, Msg) then
    Fail('expected localhost allowed in test mode');

  WsRoot := ExpandFileName(IncludeTrailingPathDelimiter(GetCurrentDir) +
    '.lca_test_browser_url_' + IntToStr(GetProcessID));
  NestedDir := IncludeTrailingPathDelimiter(WsRoot) + 'subdir';
  NestedFile := IncludeTrailingPathDelimiter(NestedDir) + 'page.html';
  OutsideDir := ExpandFileName(IncludeTrailingPathDelimiter(GetTempDir) +
    'lca_browser_url_out_' + IntToStr(GetProcessID));
  OutsideFile := IncludeTrailingPathDelimiter(OutsideDir) + 'outside.html';
  ForceDirectories(NestedDir);
  ForceDirectories(OutsideDir);
  Sl := TStringList.Create;
  try
    Sl.Text := '<html></html>';
    Sl.SaveToFile(NestedFile);
    Sl.SaveToFile(OutsideFile);
  finally
    Sl.Free;
  end;
  try
    FileUrl := 'file://' + StringReplace(NestedFile, '\', '/', [rfReplaceAll]);
    if not ValidateBrowserReadUrl(FileUrl, False, WsRoot, K, Msg) then
      Fail('expected nested workspace file allowed: ' + Msg);
    OutsideUrl := 'file://' + StringReplace(OutsideFile, '\', '/', [rfReplaceAll]);
    if ValidateBrowserReadUrl(OutsideUrl, False, WsRoot, K, Msg) then
      Fail('expected file outside workspace blocked');
  finally
    DeleteFile(NestedFile);
    DeleteFile(OutsideFile);
    RemoveDir(NestedDir);
    RemoveDir(WsRoot);
    RemoveDir(OutsideDir);
  end;
end;

procedure TestTypes;
var
  S: TBrowserReadWaitStrategy;
  Fmt: string;
begin
  if not ParseBrowserReadWaitStrategy('domcontentloaded', S) then Fail('parse dcl');
  if not ParseBrowserReadWaitStrategy('', S) or (S <> brwsLoad) then Fail('default wait');
  if ParseBrowserReadWaitStrategy('bad', S) then Fail('bad wait');
  if not ParseBrowserReadFormat('markdown', Fmt) then Fail('fmt');
end;

begin
  TestTypes;
  TestUrlGuards;
  if not TMockConn.RunCommandRoundTrip then
    Fail('cdp mock round trip');
  WriteLn('OK: browser_read unit tests passed');
end.
