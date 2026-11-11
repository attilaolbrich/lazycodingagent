unit uBrowserPageInspector;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson, uBrowserManager, uBrowserReadTypes;

function BrowserInspectPage(S: TBrowserManagedSession; const Selector: string;
  IncludeLinks, IncludeForms, IncludeA11y: Boolean; MaxLength: Integer;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck): TJSONObject;

implementation

uses
  uBrowserElementLocator, uBrowserNavigate, Classes;

function TruncStr(const S: string; MaxLen: Integer): string;
begin
  if (MaxLen > 0) and (Length(S) > MaxLen) then
    Result := Copy(S, 1, MaxLen) + '…'
  else
    Result := S;
end;

function BrowserInspectPage(S: TBrowserManagedSession; const Selector: string;
  IncludeLinks, IncludeForms, IncludeA11y: Boolean; MaxLength: Integer;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck): TJSONObject;
var
  O: TJSONObject;
  Links, Forms, Fields: TJSONArray;
  Url, Title, Text, Summary: string;
  NodeId: Integer;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
  Ref: string;
  Visible, Enabled: Boolean;
  El: TJSONObject;
begin
  S.Touch;
  O := TJSONObject.Create;
  Url := S.Navigator.EvaluateString('location.href', TimeoutMs, CancelCheck);
  Title := S.Navigator.EvaluateString('document.title', TimeoutMs, CancelCheck);
  Text := S.Navigator.EvaluateString(
    'document.body ? document.body.innerText.substring(0,5000) : ""', TimeoutMs, CancelCheck);
  O.Add('url', Url);
  O.Add('title', Title);
  O.Add('visible_text', TruncStr(Text, MaxLength));

  if Trim(Selector) <> '' then
  begin
    if BrowserResolveElement(S, Selector, '', TimeoutMs, CancelCheck, NodeId, ErrKind, ErrMsg) then
    begin
      Ref := BrowserRegisterRef(S, NodeId);
      BrowserElementVisibleEnabled(S.Connection, NodeId, TimeoutMs, CancelCheck, Visible, Enabled);
      El := TJSONObject.Create;
      El.Add('ref', Ref);
      El.Add('selector', Selector);
      El.Add('visible', Visible);
      El.Add('enabled', Enabled);
      O.Add('element', El);
    end
    else
      O.Add('element_error', ErrMsg);
  end;

  if IncludeLinks then
  begin
    Links := TJSONArray.Create;
    Summary := S.Navigator.EvaluateString(
      'JSON.stringify(Array.from(document.querySelectorAll("a[href]")).slice(0,40).map(a=>({text:a.innerText.trim().slice(0,80),href:a.href})))',
      TimeoutMs, CancelCheck);
    if Summary <> '' then
    begin
      try
        Links := TJSONArray(GetJSON(Summary));
      except
        Links := TJSONArray.Create;
      end;
    end;
    O.Add('links', Links);
  end;

  if IncludeForms then
  begin
    Forms := TJSONArray.Create;
    Summary := S.Navigator.EvaluateString(
      'JSON.stringify(Array.from(document.querySelectorAll("form")).slice(0,20).map((f,i)=>({index:i,action:f.action,method:f.method})))',
      TimeoutMs, CancelCheck);
    if Summary <> '' then
    begin
      try
        Forms := TJSONArray(GetJSON(Summary));
      except
        Forms := TJSONArray.Create;
      end;
    end;
    O.Add('forms', Forms);
    Fields := TJSONArray.Create;
    Summary := S.Navigator.EvaluateString(
      'JSON.stringify(Array.from(document.querySelectorAll("input,textarea,select")).slice(0,50).map(el=>({tag:el.tagName,name:el.name||"",type:el.type||"",id:el.id||""})))',
      TimeoutMs, CancelCheck);
    if Summary <> '' then
    begin
      try
        Fields := TJSONArray(GetJSON(Summary));
      except
        Fields := TJSONArray.Create;
      end;
    end;
    O.Add('fields', Fields);
  end;

  if IncludeA11y then
    O.Add('accessibility_note', 'Partial; use element refs for interaction');

  Result := O;
end;

end.
