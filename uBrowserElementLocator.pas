unit uBrowserElementLocator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson, uCdpConnection, uBrowserReadTypes, uBrowserManager;

function BrowserResolveElement(S: TBrowserManagedSession; const Selector, Ref: string;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck; out NodeId: Integer;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;

function BrowserElementVisibleEnabled(AConn: TCdpConnection; NodeId: Integer;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out Visible, Enabled: Boolean): Boolean;

function BrowserScrollIntoView(AConn: TCdpConnection; NodeId: Integer;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck): Boolean;

function BrowserElementCenter(AConn: TCdpConnection; NodeId: Integer;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out X, Y: Double): Boolean;

function BrowserRegisterRef(S: TBrowserManagedSession; NodeId: Integer): string;

implementation

uses
  DateUtils, Classes, Math;

function BrowserRegisterRef(S: TBrowserManagedSession; NodeId: Integer): string;
var
  Ref: string;
begin
  Inc(S.RefCounter);
  Ref := 'e' + IntToStr(S.RefCounter);
  S.RefMap.Add(Ref + '=' + IntToStr(NodeId));
  Result := Ref;
end;

function BrowserResolveElement(S: TBrowserManagedSession; const Selector, Ref: string;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck; out NodeId: Integer;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  Params, ResultObj, Root, QueryParams: TJSONObject;
  NodeIds: TJSONArray;
  I, N: Integer;
  Sel: string;
  Start: QWord;
  DocId: Integer;
begin
  NodeId := 0;
  ErrKind := brekNone;
  ErrMsg := '';
  if Trim(Ref) <> '' then
  begin
    I := S.RefMap.IndexOfName(Ref);
    if I < 0 then
    begin
      ErrKind := brekElementNotFound;
      ErrMsg := 'Unknown element ref: ' + Ref;
      Exit(False);
    end;
    NodeId := StrToIntDef(S.RefMap.ValueFromIndex[I], 0);
    if NodeId = 0 then
    begin
      ErrKind := brekElementNotFound;
      ErrMsg := 'Stale element ref';
      Exit(False);
    end;
    Exit(True);
  end;

  Sel := Trim(Selector);
  if Sel = '' then
  begin
    ErrKind := brekInvalidArgument;
    ErrMsg := 'selector or ref is required';
    Exit(False);
  end;

  Start := GetTickCount64;
  while GetTickCount64 - Start < QWord(TimeoutMs) do
  begin
    if Assigned(CancelCheck) and CancelCheck() then
    begin
      ErrKind := brekCancelled;
      ErrMsg := 'Cancelled';
      Exit(False);
    end;

    Params := TJSONObject.Create;
    try
      if not S.Connection.SendCommand('DOM.getDocument', Params, 5000, CancelCheck, ResultObj) then
      begin
        ErrKind := brekCdpConnectionFailed;
        ErrMsg := 'DOM.getDocument failed';
        Exit(False);
      end;
      try
        Root := TJSONObject(ResultObj.Find('root'));
        DocId := Root.Get('nodeId', 0);
      finally
        ResultObj.Free;
      end;
    finally
      Params.Free;
    end;

    QueryParams := TJSONObject.Create;
    try
      QueryParams.Add('nodeId', DocId);
      QueryParams.Add('selector', Sel);
      if not S.Connection.SendCommand('DOM.querySelectorAll', QueryParams, 5000,
        CancelCheck, ResultObj) then
      begin
        ErrKind := brekCdpConnectionFailed;
        ErrMsg := 'DOM.querySelectorAll failed';
        Exit(False);
      end;
      try
        NodeIds := TJSONArray(ResultObj.Find('nodeIds'));
        N := 0;
        if Assigned(NodeIds) then
          N := NodeIds.Count;
        if N = 0 then
        begin
          Sleep(100);
          S.Connection.PumpEvents(50, CancelCheck);
          Continue;
        end;
        if N > 1 then
        begin
          ErrKind := brekAmbiguousSelector;
          ErrMsg := Format('Selector matched %d elements', [N]);
          Exit(False);
        end;
        NodeId := NodeIds.Items[0].AsInteger;
        Exit(True);
      finally
        ResultObj.Free;
      end;
    finally
      QueryParams.Free;
    end;
  end;
  ErrKind := brekSelectorTimeout;
  ErrMsg := 'Element not found for selector';
  Result := False;
end;

function BrowserElementVisibleEnabled(AConn: TCdpConnection; NodeId: Integer;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out Visible, Enabled: Boolean): Boolean;
var
  Params, ResultObj: TJSONObject;
  Box, Style: TJSONArray;
  I: Integer;
  V: string;
begin
  Visible := False;
  Enabled := True;
  Params := TJSONObject.Create;
  try
    Params.Add('nodeId', NodeId);
    if not AConn.SendCommand('DOM.getBoxModel', Params, TimeoutMs, CancelCheck, ResultObj) then
      Exit(False);
    try
      Box := TJSONArray(ResultObj.Find('model'));
      Visible := Assigned(Box) and (Box.Count > 0);
    finally
      ResultObj.Free;
    end;
    if not AConn.SendCommand('CSS.enable', Params, 5000, CancelCheck, ResultObj) then
      Exit(Visible);
    ResultObj.Free;
    if not AConn.SendCommand('CSS.getComputedStyleForNode', Params, TimeoutMs, CancelCheck,
      ResultObj) then
      Exit(Visible);
    try
      Style := TJSONArray(ResultObj.Find('computedStyle'));
      if Assigned(Style) then
        for I := 0 to Style.Count - 1 do
          if Style.Items[I] is TJSONObject then
            with TJSONObject(Style.Items[I]) do
              if SameText(Get('name', ''), 'visibility') and
                 SameText(Get('value', ''), 'hidden') then
                Visible := False;
    finally
      ResultObj.Free;
    end;
    Params.Clear;
    Params.Add('nodeId', NodeId);
    Params.Add('depth', 0);
    if AConn.SendCommand('DOM.describeNode', Params, TimeoutMs, CancelCheck, ResultObj) then
    try
      if ResultObj.Find('node') <> nil then
        with TJSONObject(ResultObj.Find('node')) do
        begin
          V := Get('nodeName', '');
          if SameText(V, '#text') then ;
          Enabled := not Get('isDisabled', False);
        end;
    finally
      ResultObj.Free;
    end;
    Result := True;
  finally
    Params.Free;
  end;
end;

function BrowserScrollIntoView(AConn: TCdpConnection; NodeId: Integer;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck): Boolean;
var
  Params, ResultObj: TJSONObject;
begin
  Params := TJSONObject.Create;
  try
    Params.Add('nodeId', NodeId);
    Result := AConn.SendCommand('DOM.scrollIntoViewIfNeeded', Params, TimeoutMs,
      CancelCheck, ResultObj);
    if Assigned(ResultObj) then
      ResultObj.Free;
  finally
    Params.Free;
  end;
end;

function BrowserElementCenter(AConn: TCdpConnection; NodeId: Integer;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out X, Y: Double): Boolean;
var
  Params, ResultObj: TJSONObject;
  Content: TJSONArray;
begin
  X := 0;
  Y := 0;
  Params := TJSONObject.Create;
  try
    Params.Add('nodeId', NodeId);
    if not AConn.SendCommand('DOM.getBoxModel', Params, TimeoutMs, CancelCheck, ResultObj) then
      Exit(False);
    try
      if not (ResultObj.Find('model') is TJSONObject) then
        Exit(False);
      Content := TJSONArray(TJSONObject(ResultObj.Find('model')).Find('content'));
      if (Content = nil) or (Content.Count < 8) then
        Exit(False);
      X := (Content.Items[0].AsInteger + Content.Items[4].AsInteger) / 2;
      Y := (Content.Items[1].AsInteger + Content.Items[5].AsInteger) / 2;
      Result := True;
    finally
      ResultObj.Free;
    end;
  finally
    Params.Free;
  end;
end;

end.
