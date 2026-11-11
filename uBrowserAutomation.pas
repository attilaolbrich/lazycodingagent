unit uBrowserAutomation;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math, fpjson, uBrowserReadTypes, uBrowserManager, uBrowserReadUrl, uBrowserNavigate;

function BrowserAutomationNavigate(S: TBrowserManagedSession; const Url: string;
  Strategy: TBrowserReadWaitStrategy; const WaitSelector: string; TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck; out FinalUrl, Title: string;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;

function BrowserAutomationSetViewport(S: TBrowserManagedSession; Width, Height: Integer;
  DeviceScaleFactor: Double; TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;

implementation

function BrowserAutomationNavigate(S: TBrowserManagedSession; const Url: string;
  Strategy: TBrowserReadWaitStrategy; const WaitSelector: string; TimeoutMs: Integer;
  CancelCheck: TBrowserReadCancelCheck; out FinalUrl, Title: string;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  Deadline: QWord;
begin
  S.Touch;
  Deadline := GetTickCount64 + QWord(TimeoutMs);
  if not ValidateBrowserReadUrl(Url, S.AllowLocalhost, S.WorkspaceRoot, ErrKind, ErrMsg) then
    Exit(False);
  if not S.Navigator.Navigate(Url, Strategy, WaitSelector, Deadline, CancelCheck,
    FinalUrl, ErrKind, ErrMsg) then
    Exit(False);
  if not ValidateBrowserReadUrl(FinalUrl, S.AllowLocalhost, S.WorkspaceRoot, ErrKind, ErrMsg) then
  begin
    ErrKind := brekAccessDenied;
    ErrMsg := 'Final URL not allowed: ' + ErrMsg;
    Exit(False);
  end;
  Title := S.Navigator.EvaluateString('document.title',
    Min(5000, BrowserReadRemainingMs(Deadline)), CancelCheck);
  Result := True;
end;

function BrowserAutomationSetViewport(S: TBrowserManagedSession; Width, Height: Integer;
  DeviceScaleFactor: Double; TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  Params, ResultObj: TJSONObject;
begin
  S.Touch;
  Params := TJSONObject.Create;
  try
    Params.Add('width', Width);
    Params.Add('height', Height);
    Params.Add('deviceScaleFactor', DeviceScaleFactor);
    Params.Add('mobile', False);
    if not S.Connection.SendCommand('Emulation.setDeviceMetricsOverride', Params, TimeoutMs,
      CancelCheck, ResultObj) then
    begin
      ErrKind := brekCdpConnectionFailed;
      ErrMsg := 'Emulation.setDeviceMetricsOverride failed';
      Exit(False);
    end;
    if Assigned(ResultObj) then
      ResultObj.Free;
    Result := True;
  finally
    Params.Free;
  end;
end;

end.
