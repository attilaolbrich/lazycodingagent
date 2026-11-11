unit uBrowserInputController;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson, uBrowserReadTypes, uBrowserManager, uBrowserElementLocator;

function BrowserClickElement(S: TBrowserManagedSession; const Selector, Ref: string;
  TimeoutMs, ClickCount: Integer; CancelCheck: TBrowserReadCancelCheck;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;

function BrowserFillElement(S: TBrowserManagedSession; const Selector, Ref, Value: string;
  ClearFirst: Boolean; TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;

function BrowserSelectOption(S: TBrowserManagedSession; const Selector, Ref, Value: string;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;

function BrowserActionLooksSensitive(const Selector, Ref: string): Boolean;

implementation

uses
  Classes, Math, uCdpConnection;

function BrowserActionLooksSensitive(const Selector, Ref: string): Boolean;
var
  L: string;
begin
  L := LowerCase(Trim(Selector) + ' ' + Trim(Ref));
  if Pos('submit', L) > 0 then Exit(True);
  if Pos('delete', L) > 0 then Exit(True);
  if Pos('checkout', L) > 0 then Exit(True);
  if Pos('purchase', L) > 0 then Exit(True);
  if Pos('[type=submit]', L) > 0 then Exit(True);
  Result := False;
end;

procedure DispatchMouse(AConn: TCdpConnection; AX, AY: Double; const Typ: string;
  ClickCount: Integer; TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck);
var
  Params, ResultObj: TJSONObject;
begin
  Params := TJSONObject.Create;
  try
    Params.Add('type', Typ);
    Params.Add('x', AX);
    Params.Add('y', AY);
    Params.Add('button', 'left');
    Params.Add('clickCount', ClickCount);
    if not AConn.SendCommand('Input.dispatchMouseEvent', Params, TimeoutMs, CancelCheck, ResultObj) then
      Exit;
    if Assigned(ResultObj) then
      ResultObj.Free;
  finally
    Params.Free;
  end;
end;

function BrowserClickElement(S: TBrowserManagedSession; const Selector, Ref: string;
  TimeoutMs, ClickCount: Integer; CancelCheck: TBrowserReadCancelCheck;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  NodeId: Integer;
  Visible, Enabled: Boolean;
  X, Y: Double;
  Clicks: Integer;
begin
  S.Touch;
  if ClickCount < 1 then
    ClickCount := 1;
  if not BrowserResolveElement(S, Selector, Ref, TimeoutMs, CancelCheck, NodeId, ErrKind, ErrMsg) then
    Exit(False);
  if not BrowserElementVisibleEnabled(S.Connection, NodeId, TimeoutMs, CancelCheck,
    Visible, Enabled) then
  begin
    ErrKind := brekCdpConnectionFailed;
    ErrMsg := 'Could not inspect element';
    Exit(False);
  end;
  if not Visible or not Enabled then
  begin
    ErrKind := brekElementNotInteractable;
    ErrMsg := 'Element is not visible or not enabled';
    Exit(False);
  end;
  if not BrowserScrollIntoView(S.Connection, NodeId, TimeoutMs, CancelCheck) then ;
  if not BrowserElementCenter(S.Connection, NodeId, TimeoutMs, CancelCheck, X, Y) then
  begin
    ErrKind := brekElementNotFound;
    ErrMsg := 'Could not determine element position';
    Exit(False);
  end;
  for Clicks := 1 to ClickCount do
  begin
    DispatchMouse(S.Connection, X, Y, 'mousePressed', 1, TimeoutMs, CancelCheck);
    DispatchMouse(S.Connection, X, Y, 'mouseReleased', 1, TimeoutMs, CancelCheck);
  end;
  Result := True;
end;

procedure SendKey(AConn: TCdpConnection; const Typ: string; Key: Word;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck);
var
  Params, ResultObj: TJSONObject;
begin
  Params := TJSONObject.Create;
  try
    Params.Add('type', Typ);
    Params.Add('key', 'a');
    Params.Add('code', 'KeyA');
    Params.Add('windowsVirtualKeyCode', Key);
    Params.Add('nativeVirtualKeyCode', Key);
    Params.Add('modifiers', 2); // ctrl for select-all path handled separately
    if not AConn.SendCommand('Input.dispatchKeyEvent', Params, TimeoutMs, CancelCheck, ResultObj) then
      Exit;
    if Assigned(ResultObj) then
      ResultObj.Free;
  finally
    Params.Free;
  end;
end;

function BrowserFillElement(S: TBrowserManagedSession; const Selector, Ref, Value: string;
  ClearFirst: Boolean; TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  NodeId: Integer;
  Visible, Enabled: Boolean;
  Params, ResultObj: TJSONObject;
begin
  S.Touch;
  if not BrowserResolveElement(S, Selector, Ref, TimeoutMs, CancelCheck, NodeId, ErrKind, ErrMsg) then
    Exit(False);
  if not BrowserElementVisibleEnabled(S.Connection, NodeId, TimeoutMs, CancelCheck,
    Visible, Enabled) then
  begin
    ErrKind := brekCdpConnectionFailed;
    ErrMsg := 'Could not inspect element';
    Exit(False);
  end;
  if not Visible or not Enabled then
  begin
    ErrKind := brekElementNotInteractable;
    ErrMsg := 'Element is not visible or not enabled';
    Exit(False);
  end;
  BrowserScrollIntoView(S.Connection, NodeId, TimeoutMs, CancelCheck);
  Params := TJSONObject.Create;
  try
    Params.Add('nodeId', NodeId);
    if not S.Connection.SendCommand('DOM.focus', Params, TimeoutMs, CancelCheck, ResultObj) then
    begin
      ErrKind := brekCdpConnectionFailed;
      ErrMsg := 'DOM.focus failed';
      Exit(False);
    end;
    ResultObj.Free;
  finally
    Params.Free;
  end;
  if ClearFirst then
  begin
    Params := TJSONObject.Create;
    try
      Params.Add('text', '');
      if not S.Connection.SendCommand('Input.insertText', Params, TimeoutMs, CancelCheck, ResultObj) then
      begin
        ErrKind := brekCdpConnectionFailed;
        ErrMsg := 'Could not clear field';
        Exit(False);
      end;
      ResultObj.Free;
    finally
      Params.Free;
    end;
  end;
  Params := TJSONObject.Create;
  try
    Params.Add('text', Value);
    if not S.Connection.SendCommand('Input.insertText', Params, TimeoutMs, CancelCheck, ResultObj) then
    begin
      ErrKind := brekCdpConnectionFailed;
      ErrMsg := 'Input.insertText failed';
      Exit(False);
    end;
    ResultObj.Free;
  finally
    Params.Free;
  end;
  Result := True;
end;

function BrowserSelectOption(S: TBrowserManagedSession; const Selector, Ref, Value: string;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  NodeId: Integer;
  Params, ResultObj, Remote, ArgObj, ArgArr: TJSONObject;
  ObjectId: string;
  Args: TJSONArray;
  Ok: Boolean;
begin
  S.Touch;
  if not BrowserResolveElement(S, Selector, Ref, TimeoutMs, CancelCheck, NodeId, ErrKind, ErrMsg) then
    Exit(False);
  Params := TJSONObject.Create;
  try
    Params.Add('nodeId', NodeId);
    if not S.Connection.SendCommand('DOM.resolveNode', Params, TimeoutMs, CancelCheck, ResultObj) then
    begin
      ErrKind := brekCdpConnectionFailed;
      ErrMsg := 'DOM.resolveNode failed';
      Exit(False);
    end;
    try
      Remote := TJSONObject(ResultObj.Find('object'));
      if Remote = nil then
      begin
        ErrKind := brekElementNotFound;
        ErrMsg := 'Could not resolve node';
        Exit(False);
      end;
      ObjectId := Remote.Get('objectId', '');
    finally
      ResultObj.Free;
    end;
  finally
    Params.Free;
  end;
  Params := TJSONObject.Create;
  try
    Params.Add('objectId', ObjectId);
    Params.Add('functionDeclaration',
      'function(v){if(!this||this.tagName!=="SELECT")return false;this.value=v;' +
      'this.dispatchEvent(new Event("change",{bubbles:true}));return true;}');
    Args := TJSONArray.Create;
    ArgObj := TJSONObject.Create;
    ArgObj.Add('value', Value);
    Args.Add(ArgObj);
    Params.Add('arguments', Args);
    Params.Add('returnByValue', True);
    if not S.Connection.SendCommand('Runtime.callFunctionOn', Params, TimeoutMs, CancelCheck,
      ResultObj) then
    begin
      ErrKind := brekCdpConnectionFailed;
      ErrMsg := 'Runtime.callFunctionOn failed';
      Exit(False);
    end;
    try
      Ok := False;
      if ResultObj.Find('result') <> nil then
        Ok := TJSONObject(ResultObj.Find('result')).Get('value', False);
      if not Ok then
      begin
        ErrKind := brekElementNotInteractable;
        ErrMsg := 'Could not select option (not a SELECT or value missing)';
        Exit(False);
      end;
      Result := True;
    finally
      ResultObj.Free;
    end;
  finally
    Params.Free;
  end;
end;

end.
