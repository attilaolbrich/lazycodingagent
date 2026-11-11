unit uBrowserSession;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson, uCdpConnection, uBrowserReadTypes;

type
  TBrowserSession = class
  private
    FConnection: TCdpConnection;
    FTargetId: string;
  public
    constructor Create(AConnection: TCdpConnection);
    function OpenBlankPage(CancelCheck: TBrowserReadCancelCheck;
      out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
    function ClosePage(CancelCheck: TBrowserReadCancelCheck): Boolean;
    property TargetId: string read FTargetId;
  end;

implementation

function TBrowserSession.OpenBlankPage(CancelCheck: TBrowserReadCancelCheck;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  CreateParams, AttachParams, EnableParams, DownloadParams, ResultObj: TJSONObject;
  SessionId: string;
begin
  ErrKind := brekNone;
  ErrMsg := '';
  FTargetId := '';

  CreateParams := TJSONObject.Create;
  try
    CreateParams.Add('url', 'about:blank');
    if not FConnection.SendCommand('Target.createTarget', CreateParams, 20000,
      CancelCheck, ResultObj) then
    begin
      ErrKind := brekCdpConnectionFailed;
      ErrMsg := 'Target.createTarget failed';
      Exit(False);
    end;
    try
      if ResultObj.Find('targetId') = nil then
      begin
        ErrKind := brekCdpConnectionFailed;
        ErrMsg := 'Missing targetId';
        Exit(False);
      end;
      FTargetId := ResultObj.Get('targetId', '');
    finally
      ResultObj.Free;
    end;
  finally
    CreateParams.Free;
  end;

  AttachParams := TJSONObject.Create;
  try
    AttachParams.Add('targetId', FTargetId);
    AttachParams.Add('flatten', True);
    if not FConnection.SendCommand('Target.attachToTarget', AttachParams, 20000,
      CancelCheck, ResultObj) then
    begin
      ErrKind := brekCdpConnectionFailed;
      ErrMsg := 'Target.attachToTarget failed';
      Exit(False);
    end;
    try
      SessionId := ResultObj.Get('sessionId', '');
      if SessionId = '' then
      begin
        ErrKind := brekCdpConnectionFailed;
        ErrMsg := 'Missing sessionId';
        Exit(False);
      end;
      FConnection.SessionId := SessionId;
    finally
      ResultObj.Free;
    end;
  finally
    AttachParams.Free;
  end;

  EnableParams := TJSONObject.Create;
  try
    if not FConnection.SendCommand('Page.enable', EnableParams, 10000, CancelCheck, ResultObj) then
    begin
      ErrKind := brekCdpConnectionFailed;
      ErrMsg := 'Page.enable failed';
      Exit(False);
    end;
    ResultObj.Free;
    if not FConnection.SendCommand('Runtime.enable', EnableParams, 10000, CancelCheck, ResultObj) then
    begin
      ErrKind := brekCdpConnectionFailed;
      ErrMsg := 'Runtime.enable failed';
      Exit(False);
    end;
    ResultObj.Free;
    if not FConnection.SendCommand('DOM.enable', EnableParams, 10000, CancelCheck, ResultObj) then
    begin
      ErrKind := brekCdpConnectionFailed;
      ErrMsg := 'DOM.enable failed';
      Exit(False);
    end;
    ResultObj.Free;
    DownloadParams := TJSONObject.Create;
    try
      DownloadParams.Add('behavior', 'deny');
      if FConnection.SendCommand('Browser.setDownloadBehavior', DownloadParams,
        10000, CancelCheck, ResultObj) then
        ResultObj.Free
      else if Assigned(ResultObj) then
        ResultObj.Free;
    finally
      DownloadParams.Free;
    end;
  finally
    EnableParams.Free;
  end;
  Result := True;
end;

function TBrowserSession.ClosePage(CancelCheck: TBrowserReadCancelCheck): Boolean;
var
  Params, ResultObj: TJSONObject;
begin
  if FTargetId = '' then Exit(True);
  Params := TJSONObject.Create;
  try
    Params.Add('targetId', FTargetId);
    Result := FConnection.SendCommand('Target.closeTarget', Params, 10000, CancelCheck, ResultObj);
  finally
    Params.Free;
    if Assigned(ResultObj) then ResultObj.Free;
  end;
  FTargetId := '';
  FConnection.SessionId := '';
end;

constructor TBrowserSession.Create(AConnection: TCdpConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

end.
