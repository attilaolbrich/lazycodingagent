unit uToolTodo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAppTypes, uAgentTypes, uAgentToolBase;

type
  TToolTodo = class(TAgentTool)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function MatchesName(const AName: string): Boolean; override;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

implementation

constructor TToolTodo.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  FAliases := 'plan';
  AllowedModes := [wmAsk, wmPlan, wmAgent];
  MutatesFiles := False;
end;

function TToolTodo.MatchesName(const AName: string): Boolean;
begin
  Result := inherited MatchesName(AName);
end;

function TToolTodo.GetDefinition: TToolDef;
begin
  Result.Name := 'todo';
  Result.Description := 'Read or replace chat-local tasks. replace: pass items array of objects with id, text, and status (pending, in_progress, completed). Example: {"action":"replace","items":[{"id":"1","text":"Inspect files","status":"pending"}]}';
  SetLength(Result.Params, 2);
  Result.Params[0].Name := 'action';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'read or replace.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'items';
  Result.Params[1].ParamType := 'array';
  Result.Params[1].Description := 'Full task list for replace; each object needs id, text, status.';
  Result.Params[1].Required := False;
end;

function JsonFieldString(AObj: TJSONObject; const ANames: array of string): string;
var
  I: Integer;
  D: TJSONData;
begin
  Result := '';
  if AObj = nil then Exit;
  for I := Low(ANames) to High(ANames) do begin
    D := AObj.Find(ANames[I]);
    if D = nil then Continue;
    if D is TJSONString then
      Exit(TJSONString(D).AsString)
    else
      Exit(D.AsJSON);
  end;
end;

function NormalizeTaskStatus(const S: string): string;
var
  L: string;
begin
  L := LowerCase(Trim(S));
  if L = '' then Exit('');
  if (L = 'pending') or (L = 'todo') or (L = 'open') then Exit('pending');
  if (L = 'in_progress') or (L = 'in progress') or (L = 'in-progress') or (L = 'doing') or (L = 'active') then
    Exit('in_progress');
  if (L = 'completed') or (L = 'complete') or (L = 'done') or (L = 'closed') then Exit('completed');
  Result := Trim(S);
end;

function ResolveItemsArray(Args: TJSONObject): TJSONArray;
begin
  Result := Args.Find('items') as TJSONArray;
  if Result = nil then
    Result := Args.Find('tasks') as TJSONArray;
end;

function NormalizeReplaceItems(const Items: TJSONArray; out AError: string): TJSONArray;
var
  I: Integer;
  Src, Norm: TJSONObject;
  ID, Text, Status: string;
  IDs: TStringList;
  OutArr: TJSONArray;
begin
  AError := '';
  OutArr := TJSONArray.Create;
  IDs := TStringList.Create;
  try
    for I := 0 to Items.Count - 1 do begin
      if not (Items[I] is TJSONObject) then begin
        AError := 'Task must be an object';
        Exit(nil);
      end;
      Src := TJSONObject(Items[I]);
      ID := Trim(JsonFieldString(Src, ['id', 'task_id']));
      Text := Trim(JsonFieldString(Src, ['text', 'content', 'description', 'title']));
      Status := NormalizeTaskStatus(JsonFieldString(Src, ['status', 'state']));
      if (ID = '') and (Text <> '') then
        ID := IntToStr(I + 1);
      if (ID = '') or (Text = '') then begin
        AError := 'Task requires id, text, and status';
        Exit(nil);
      end;
      if Status = '' then begin
        AError := 'Task requires id, text, and status';
        Exit(nil);
      end;
      if IDs.IndexOf(ID) >= 0 then begin
        AError := 'Task IDs must be nonempty and unique; text is required';
        Exit(nil);
      end;
      if not ((Status = 'pending') or (Status = 'in_progress') or (Status = 'completed')) then begin
        AError := 'Invalid task status';
        Exit(nil);
      end;
      IDs.Add(ID);
      Norm := TJSONObject.Create;
      Norm.Add('id', ID);
      Norm.Add('text', Text);
      Norm.Add('status', Status);
      OutArr.Add(Norm);
    end;
    Result := OutArr;
    OutArr := nil;
  finally
    IDs.Free;
    if OutArr <> nil then
      OutArr.Free;
  end;
end;

function TToolTodo.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Action, Json: string;
  Items, Normalized: TJSONArray;
  O: TJSONObject;
  Session: TAgentToolSession;
  Err: string;
begin
  Session := FContext.Session;
  Action := Args.Get('action', 'read');

  if Action = 'replace' then begin
    Items := ResolveItemsArray(Args);
    if Items = nil then
      Exit(ToolResultFromJson(ToolError('replace requires items')));
    if Items.Count > 100 then
      Exit(ToolResultFromJson(ToolError('At most 100 tasks are supported')));
    Normalized := NormalizeReplaceItems(Items, Err);
    if Normalized = nil then
      Exit(ToolResultFromJson(ToolError(Err)));
    try
      Session.Tasks.Free;
      Session.Tasks := Normalized;
      Normalized := nil;
    finally
      if Normalized <> nil then
        Normalized.Free;
    end;
  end else if Action <> 'read' then
    Exit(ToolResultFromJson(ToolError('action must be read or replace')));

  O := TJSONObject.Create;
  try
    O.Add('items', Session.Tasks.Clone);
    Json := O.AsJSON;
  finally
    O.Free;
  end;
  Result := ToolResultFromJson(Json);
end;

end.
