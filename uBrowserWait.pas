unit uBrowserWait;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uBrowserReadTypes, uBrowserManager, uBrowserElementLocator, uBrowserNavigate;

function BrowserWaitCondition(S: TBrowserManagedSession; const Condition, Selector, Text,
  UrlPattern: string; TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;

implementation

uses
  DateUtils, Classes;

function UrlMatchesPattern(const Url, Pattern: string): Boolean;
var
  I: Integer;
  P, U: string;
begin
  if Pattern = '' then Exit(False);
  if Pos('*', Pattern) = 0 then
    Exit(Pos(LowerCase(Pattern), LowerCase(Url)) > 0);
  P := LowerCase(Pattern);
  U := LowerCase(Url);
  if SameText(Copy(P, 1, 1), '*') then
    Exit(Pos(Copy(P, 2, MaxInt), U) > 0);
  if SameText(Copy(P, Length(P), 1), '*') then
    Exit(Pos(Copy(P, 1, Length(P) - 1), U) = 1);
  Result := SameText(U, P);
end;

function BrowserWaitCondition(S: TBrowserManagedSession; const Condition, Selector, Text,
  UrlPattern: string; TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  Start: QWord;
  NodeId: Integer;
  Visible, Enabled: Boolean;
  Url, BodyText: string;
  Nav: TBrowserNavigator;
begin
  ErrKind := brekNone;
  ErrMsg := '';
  S.Touch;
  Start := GetTickCount64;
  Nav := S.Navigator;
  while GetTickCount64 - Start < QWord(TimeoutMs) do
  begin
    if Assigned(CancelCheck) and CancelCheck() then
    begin
      ErrKind := brekCancelled;
      ErrMsg := 'Cancelled';
      Exit(False);
    end;
    S.Connection.PumpEvents(50, CancelCheck);

    if SameText(Condition, 'document_ready') then
    begin
      Url := Nav.EvaluateString('document.readyState', 2000, CancelCheck);
      if SameText(Url, 'complete') or SameText(Url, 'interactive') then
        Exit(True);
    end
    else if SameText(Condition, 'url_matches') then
    begin
      Url := Nav.EvaluateString('location.href', 2000, CancelCheck);
      if UrlMatchesPattern(Url, UrlPattern) then
        Exit(True);
    end
    else if SameText(Condition, 'text_present') then
    begin
      BodyText := Nav.EvaluateString('document.body ? document.body.innerText : ""', 3000,
        CancelCheck);
      if Pos(Text, BodyText) > 0 then
        Exit(True);
    end
    else if SameText(Condition, 'selector_visible') then
    begin
      if BrowserResolveElement(S, Selector, '', 1000, CancelCheck, NodeId, ErrKind, ErrMsg) then
        if BrowserElementVisibleEnabled(S.Connection, NodeId, 1000, CancelCheck, Visible, Enabled) and
           Visible then
          Exit(True);
      ErrKind := brekNone;
      ErrMsg := '';
    end
    else if SameText(Condition, 'selector_hidden') then
    begin
      if not BrowserResolveElement(S, Selector, '', 500, CancelCheck, NodeId, ErrKind, ErrMsg) then
      begin
        ErrKind := brekNone;
        Exit(True);
      end;
      if BrowserElementVisibleEnabled(S.Connection, NodeId, 500, CancelCheck, Visible, Enabled) and
         not Visible then
        Exit(True);
      ErrKind := brekNone;
    end
    else
    begin
      ErrKind := brekInvalidArgument;
      ErrMsg := 'Unknown wait condition: ' + Condition;
      Exit(False);
    end;
    Sleep(100);
  end;
  ErrKind := brekNavigationTimeout;
  ErrMsg := 'Wait timed out';
  Result := False;
end;

end.
