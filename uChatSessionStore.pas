unit uChatSessionStore;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAgentTypes;

type
  TChatSessionInfo = record
    Id: string;
    Title: string;
    Created: TDateTime;
    Modified: TDateTime;
    Archived: Boolean;
    ArchivedAt: TDateTime;
    AllowModifyOutside: Boolean;
    AllowBrowserLocalhost: Boolean;
    AllowBrowserInteractive: Boolean;
    AllowBrowserSensitive: Boolean;
  end;

  TChatSessionStore = class
  private
    FWorkspaceId: string;
    FSessions: array of TChatSessionInfo;
    FLastSessionId: string;
    function SessionFilePath(const AWorkspaceId: string): string;
    function IndexOfSession(const ASessionId: string): Integer;
    procedure EnsureLoaded;
    function ReadRootFromFile(out ARoot: TJSONObject): Boolean;
    procedure WriteRootToFile(ARoot: TJSONObject);
  public
    destructor Destroy; override;
    procedure BindWorkspace(const AWorkspaceId: string);
    function SessionCount: Integer;
    function GetSessionInfo(AIndex: Integer): TChatSessionInfo;
    function GetLastSessionId: string;
    procedure SetLastSessionId(const ASessionId: string);

    function CreateSession(const ATitle: string): string;
    function LoadSessionMessages(const ASessionId: string; out AMessages: TChatMessageArray): Boolean;
    procedure SaveSessionMessages(const ASessionId: string; const AMessages: TChatMessageArray);
    procedure DeleteSession(const ASessionId: string);
    procedure DeleteAllForWorkspace(const AWorkspaceId: string);
    function FindSessionInfo(const ASessionId: string; out AInfo: TChatSessionInfo): Boolean;
    procedure SetSessionArchived(const ASessionId: string; AArchived: Boolean);
    procedure SetAllowModifyOutside(const ASessionId: string; AValue: Boolean);
    procedure SetAllowBrowserLocalhost(const ASessionId: string; AValue: Boolean);
    procedure SetAllowBrowserInteractive(const ASessionId: string; AValue: Boolean);
    procedure SetAllowBrowserSensitive(const ASessionId: string; AValue: Boolean);
    procedure UpdateSessionTitle(const ASessionId, ATitle: string);
  end;

function NewSessionId: string;

implementation

uses
  Forms, jsonparser, DateUtils;

function DateTimeToJsonIso(ADt: TDateTime): string;
begin
  Result := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss', ADt);
end;

function JsonIsoToDateTime(const S: string): TDateTime;
var
  T: string;
  Y, Mo, D, H, Mi, Se: Integer;
  DotPos, ZPos: Integer;
begin
  T := Trim(S);
  if T = '' then
    Exit(Now);

  ZPos := Pos('Z', T);
  if ZPos > 0 then
    T := Copy(T, 1, ZPos - 1);
  DotPos := Pos('.', T);
  if DotPos > 0 then
    T := Copy(T, 1, DotPos - 1);

  if Length(T) < 19 then
    Exit(Now);
  if (T[5] <> '-') or (T[8] <> '-') or (T[11] <> 'T') or (T[14] <> ':') or (T[17] <> ':') then
    Exit(Now);

  Y := StrToIntDef(Copy(T, 1, 4), 0);
  Mo := StrToIntDef(Copy(T, 6, 2), 0);
  D := StrToIntDef(Copy(T, 9, 2), 0);
  H := StrToIntDef(Copy(T, 12, 2), 0);
  Mi := StrToIntDef(Copy(T, 15, 2), 0);
  Se := StrToIntDef(Copy(T, 18, 2), 0);

  if not TryEncodeDateTime(Y, Mo, D, H, Mi, Se, 0, Result) then
    Result := Now;
end;

function SafeJsonIsoToDateTime(const S: string): TDateTime;
begin
  try
    Result := JsonIsoToDateTime(S);
  except
    Result := Now;
  end;
end;

function SessionsDir: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'lazycodingagent' +
    PathDelim + 'sessions';
end;

function NewSessionId: string;
begin
  Result := 'sess_' + IntToHex(GetTickCount64, 16) + '_' + IntToHex(Random($7FFFFFFF), 8);
end;

function MessageToJson(const AMsg: TChatMessage): TJSONObject;
var
  O, TC, AttObj: TJSONObject;
  TCs, Atts: TJSONArray;
  I: Integer;
begin
  O := TJSONObject.Create;
  O.Add('role', ChatRoleToString(AMsg.Role));
  O.Add('content', AMsg.Content);
  O.Add('toolCallId', AMsg.ToolCallId);
  O.Add('timestamp', DateTimeToJsonIso(AMsg.Timestamp));
  O.Add('tokensUsed', AMsg.TokensUsed);
  O.Add('visualSummary', AMsg.VisualSummary);
  TCs := TJSONArray.Create;
  for I := 0 to High(AMsg.ToolCalls) do begin
    TC := TJSONObject.Create;
    TC.Add('id', AMsg.ToolCalls[I].Id);
    TC.Add('name', AMsg.ToolCalls[I].Name);
    TC.Add('argumentsJson', AMsg.ToolCalls[I].ArgumentsJson);
    TCs.Add(TC);
  end;
  O.Add('toolCalls', TCs);
  Atts := TJSONArray.Create;
  for I := 0 to High(AMsg.Attachments) do begin
    AttObj := TJSONObject.Create;
    AttObj.Add('kind', ChatAttachmentKindToString(AMsg.Attachments[I].Kind));
    AttObj.Add('path', AMsg.Attachments[I].RelativePath);
    AttObj.Add('mime', AMsg.Attachments[I].MimeType);
    AttObj.Add('name', AMsg.Attachments[I].OriginalName);
    AttObj.Add('width', AMsg.Attachments[I].Width);
    AttObj.Add('height', AMsg.Attachments[I].Height);
    Atts.Add(AttObj);
  end;
  O.Add('attachments', Atts);
  Result := O;
end;

procedure MessageFromJson(AObj: TJSONObject; out AMsg: TChatMessage);
var
  Arr: TJSONArray;
  I: Integer;
  TCObj, AttObj: TJSONObject;
begin
  AMsg := StringToChatRole(AObj.Get('role', 'user'));
  AMsg.Content := AObj.Get('content', '');
  AMsg.ToolCallId := AObj.Get('toolCallId', '');
  AMsg.TokensUsed := AObj.Get('tokensUsed', 0);
  AMsg.VisualSummary := AObj.Get('visualSummary', '');
  if AObj.Find('timestamp') <> nil then
    AMsg.Timestamp := SafeJsonIsoToDateTime(AObj.Get('timestamp', ''))
  else
    AMsg.Timestamp := Now;
  SetLength(AMsg.ToolCalls, 0);
  if AObj.Find('toolCalls') is TJSONArray then begin
    Arr := TJSONArray(AObj.Find('toolCalls'));
    SetLength(AMsg.ToolCalls, Arr.Count);
    for I := 0 to Arr.Count - 1 do begin
      if not (Arr.Items[I] is TJSONObject) then Continue;
      TCObj := TJSONObject(Arr.Items[I]);
      AMsg.ToolCalls[I].Id := TCObj.Get('id', '');
      AMsg.ToolCalls[I].Name := TCObj.Get('name', '');
      AMsg.ToolCalls[I].ArgumentsJson := TCObj.Get('argumentsJson', '');
    end;
  end;
  SetLength(AMsg.Attachments, 0);
  if AObj.Find('attachments') is TJSONArray then begin
    Arr := TJSONArray(AObj.Find('attachments'));
    SetLength(AMsg.Attachments, Arr.Count);
    for I := 0 to Arr.Count - 1 do begin
      if not (Arr.Items[I] is TJSONObject) then Continue;
      AttObj := TJSONObject(Arr.Items[I]);
      AMsg.Attachments[I].Kind := StringToChatAttachmentKind(AttObj.Get('kind', 'image'));
      AMsg.Attachments[I].RelativePath := AttObj.Get('path', '');
      AMsg.Attachments[I].MimeType := AttObj.Get('mime', '');
      AMsg.Attachments[I].OriginalName := AttObj.Get('name', '');
      AMsg.Attachments[I].Width := AttObj.Get('width', 0);
      AMsg.Attachments[I].Height := AttObj.Get('height', 0);
    end;
  end;
end;

procedure ParseSessionMeta(AObj: TJSONObject; out AInfo: TChatSessionInfo);
begin
  AInfo.Id := AObj.Get('id', '');
  AInfo.Title := AObj.Get('title', 'Chat');
  if AObj.Find('created') <> nil then
    AInfo.Created := SafeJsonIsoToDateTime(AObj.Get('created', ''))
  else
    AInfo.Created := Now;
  if AObj.Find('modified') <> nil then
    AInfo.Modified := SafeJsonIsoToDateTime(AObj.Get('modified', ''))
  else
    AInfo.Modified := AInfo.Created;
  AInfo.Archived := AObj.Get('archived', False);
  if AObj.Find('archivedAt') <> nil then
    AInfo.ArchivedAt := SafeJsonIsoToDateTime(AObj.Get('archivedAt', ''))
  else
    AInfo.ArchivedAt := 0;
  AInfo.AllowModifyOutside := AObj.Get('allowModifyOutside', False);
  AInfo.AllowBrowserLocalhost := AObj.Get('allowBrowserLocalhost', False);
  AInfo.AllowBrowserInteractive := AObj.Get('allowBrowserInteractive', False);
  AInfo.AllowBrowserSensitive := AObj.Get('allowBrowserSensitive', False);
end;

{ TChatSessionStore }

destructor TChatSessionStore.Destroy;
begin
  inherited Destroy;
end;

function TChatSessionStore.SessionFilePath(const AWorkspaceId: string): string;
begin
  Result := IncludeTrailingPathDelimiter(SessionsDir) + AWorkspaceId + '.json';
end;

function TChatSessionStore.IndexOfSession(const ASessionId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FSessions) do
    if SameText(FSessions[I].Id, ASessionId) then
      Exit(I);
  Result := -1;
end;

procedure TChatSessionStore.BindWorkspace(const AWorkspaceId: string);
begin
  if FWorkspaceId <> AWorkspaceId then begin
    FWorkspaceId := AWorkspaceId;
    SetLength(FSessions, 0);
    FLastSessionId := '';
    EnsureLoaded;
  end;
end;

function TChatSessionStore.ReadRootFromFile(out ARoot: TJSONObject): Boolean;
var
  Path: string;
  SL: TStringList;
  Data: TJSONData;
begin
  ARoot := nil;
  Result := False;
  if FWorkspaceId = '' then Exit;
  Path := SessionFilePath(FWorkspaceId);
  if not FileExists(Path) then Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(Path);
    if Trim(SL.Text) = '' then Exit;
    Data := GetJSON(SL.Text);
    if Data is TJSONObject then begin
      ARoot := TJSONObject(Data);
      Result := True;
    end else
      Data.Free;
  finally
    SL.Free;
  end;
end;

procedure TChatSessionStore.WriteRootToFile(ARoot: TJSONObject);
var
  Path, Dir: string;
  SL: TStringList;
begin
  if (FWorkspaceId = '') or (ARoot = nil) then Exit;
  Path := SessionFilePath(FWorkspaceId);
  Dir := ExtractFilePath(Path);
  if not DirectoryExists(Dir) then
    ForceDirectories(Dir);
  SL := TStringList.Create;
  try
    SL.Text := ARoot.AsJSON;
    SL.SaveToFile(Path);
  finally
    SL.Free;
  end;
end;

procedure TChatSessionStore.EnsureLoaded;
var
  Root, Sess: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  OwnedRoot: Boolean;
begin
  SetLength(FSessions, 0);
  FLastSessionId := '';
  if FWorkspaceId = '' then Exit;

  OwnedRoot := ReadRootFromFile(Root);
  if not OwnedRoot then Exit;

  try
    FLastSessionId := Root.Get('lastSessionId', '');
    if Root.Find('sessions') is TJSONArray then begin
      Arr := TJSONArray(Root.Find('sessions'));
      SetLength(FSessions, Arr.Count);
      for I := 0 to Arr.Count - 1 do begin
        if Arr.Items[I] is TJSONObject then begin
          Sess := TJSONObject(Arr.Items[I]);
          ParseSessionMeta(Sess, FSessions[I]);
        end;
      end;
    end;
  finally
    Root.Free;
  end;
end;

function TChatSessionStore.SessionCount: Integer;
begin
  Result := Length(FSessions);
end;

function TChatSessionStore.GetSessionInfo(AIndex: Integer): TChatSessionInfo;
begin
  Result := FSessions[AIndex];
end;

function TChatSessionStore.GetLastSessionId: string;
begin
  Result := FLastSessionId;
end;

procedure TChatSessionStore.SetLastSessionId(const ASessionId: string);
begin
  FLastSessionId := ASessionId;
end;

function TChatSessionStore.CreateSession(const ATitle: string): string;
var
  Root, Sess: TJSONObject;
  Arr: TJSONArray;
  Info: TChatSessionInfo;
  MsgArr: TJSONArray;
begin
  EnsureLoaded;
  Info.Id := NewSessionId;
  if Trim(ATitle) <> '' then
    Info.Title := Trim(ATitle)
  else
    Info.Title := 'Chat ' + IntToStr(Length(FSessions) + 1);
  Info.Created := Now;
  Info.Modified := Info.Created;
  Info.AllowModifyOutside := False;
  Info.AllowBrowserLocalhost := False;
  Info.AllowBrowserInteractive := False;
  Info.AllowBrowserSensitive := False;

  if ReadRootFromFile(Root) then begin
    if Root.Find('sessions') is TJSONArray then
      Arr := TJSONArray(Root.Find('sessions'))
    else begin
      Arr := TJSONArray.Create;
      Root.Add('sessions', Arr);
    end;
  end else begin
    Root := TJSONObject.Create;
    Arr := TJSONArray.Create;
    Root.Add('sessions', Arr);
  end;

  Sess := TJSONObject.Create;
  Sess.Add('id', Info.Id);
  Sess.Add('title', Info.Title);
  Sess.Add('created', DateTimeToJsonIso(Info.Created));
  Sess.Add('modified', DateTimeToJsonIso(Info.Modified));
  Sess.Add('archived', False);
  Sess.Add('allowModifyOutside', False);
  MsgArr := TJSONArray.Create;
  Sess.Add('messages', MsgArr);
  Arr.Add(Sess);

  FLastSessionId := Info.Id;
  if Root.Find('lastSessionId') <> nil then
    Root.Delete('lastSessionId');
  Root.Add('lastSessionId', FLastSessionId);
  WriteRootToFile(Root);
  Root.Free;

  SetLength(FSessions, Length(FSessions) + 1);
  FSessions[High(FSessions)] := Info;
  Result := Info.Id;
end;

function TChatSessionStore.LoadSessionMessages(const ASessionId: string;
  out AMessages: TChatMessageArray): Boolean;
var
  Root, Sess: TJSONObject;
  Arr, MsgArr: TJSONArray;
  I, J: Integer;
begin
  Result := False;
  SetLength(AMessages, 0);
  EnsureLoaded;
  if not ReadRootFromFile(Root) then Exit;
  try
    if not (Root.Find('sessions') is TJSONArray) then Exit;
    Arr := TJSONArray(Root.Find('sessions'));
    for I := 0 to Arr.Count - 1 do begin
      if not (Arr.Items[I] is TJSONObject) then Continue;
      Sess := TJSONObject(Arr.Items[I]);
      if not SameText(Sess.Get('id', ''), ASessionId) then Continue;
      if not (Sess.Find('messages') is TJSONArray) then begin
        Result := True;
        Exit;
      end;
      MsgArr := TJSONArray(Sess.Find('messages'));
      SetLength(AMessages, MsgArr.Count);
      for J := 0 to MsgArr.Count - 1 do begin
        if MsgArr.Items[J] is TJSONObject then
          MessageFromJson(TJSONObject(MsgArr.Items[J]), AMessages[J]);
      end;
      Result := True;
      Exit;
    end;
  finally
    Root.Free;
  end;
end;

procedure TChatSessionStore.SaveSessionMessages(const ASessionId: string;
  const AMessages: TChatMessageArray);
var
  Root, Sess: TJSONObject;
  Arr, MsgArr: TJSONArray;
  I, J, Idx: Integer;
  MsgObj: TJSONObject;
begin
  if FWorkspaceId = '' then Exit;
  EnsureLoaded;
  Idx := IndexOfSession(ASessionId);
  if Idx < 0 then Exit;

  FSessions[Idx].Modified := Now;
  FLastSessionId := ASessionId;

  if not ReadRootFromFile(Root) then begin
    Root := TJSONObject.Create;
    Arr := TJSONArray.Create;
    Root.Add('sessions', Arr);
  end else if not (Root.Find('sessions') is TJSONArray) then begin
    Arr := TJSONArray.Create;
    if Root.Find('sessions') <> nil then
      Root.Delete('sessions');
    Root.Add('sessions', Arr);
  end else
    Arr := TJSONArray(Root.Find('sessions'));

  for I := 0 to Arr.Count - 1 do begin
    if not (Arr.Items[I] is TJSONObject) then Continue;
    Sess := TJSONObject(Arr.Items[I]);
    if not SameText(Sess.Get('id', ''), ASessionId) then Continue;
    if Sess.Find('messages') <> nil then
      Sess.Delete('messages');
    MsgArr := TJSONArray.Create;
    for J := 0 to High(AMessages) do begin
      MsgObj := MessageToJson(AMessages[J]);
      MsgArr.Add(MsgObj);
    end;
    Sess.Add('messages', MsgArr);
    if Sess.Find('modified') <> nil then
      Sess.Delete('modified');
    Sess.Add('modified', DateTimeToJsonIso(FSessions[Idx].Modified));
    Break;
  end;

  if Root.Find('lastSessionId') <> nil then
    Root.Delete('lastSessionId');
  Root.Add('lastSessionId', FLastSessionId);
  WriteRootToFile(Root);
  Root.Free;
end;

procedure TChatSessionStore.DeleteSession(const ASessionId: string);
var
  Root, Sess: TJSONObject;
  Arr: TJSONArray;
  I, Idx: Integer;
  NewArr: TJSONArray;
begin
  EnsureLoaded;
  Idx := IndexOfSession(ASessionId);
  if Idx < 0 then Exit;

  if not ReadRootFromFile(Root) then Exit;
  try
    if Root.Find('sessions') is TJSONArray then begin
      Arr := TJSONArray(Root.Find('sessions'));
      NewArr := TJSONArray.Create;
      for I := 0 to Arr.Count - 1 do begin
        if not (Arr.Items[I] is TJSONObject) then Continue;
        Sess := TJSONObject(Arr.Items[I]);
        if SameText(Sess.Get('id', ''), ASessionId) then
          Continue;
        NewArr.Add(TJSONObject(Sess.Clone));
      end;
      Root.Delete('sessions');
      Root.Add('sessions', NewArr);
    end;
    if SameText(FLastSessionId, ASessionId) then begin
      if Root.Find('lastSessionId') <> nil then
        Root.Delete('lastSessionId');
      if Length(FSessions) > 1 then
        Root.Add('lastSessionId', FSessions[High(FSessions) - 1].Id)
      else
        Root.Add('lastSessionId', '');
    end;
    WriteRootToFile(Root);
  finally
    Root.Free;
  end;

  for I := Idx to High(FSessions) - 1 do
    FSessions[I] := FSessions[I + 1];
  SetLength(FSessions, Length(FSessions) - 1);
  if SameText(FLastSessionId, ASessionId) then
    if Length(FSessions) > 0 then
      FLastSessionId := FSessions[High(FSessions)].Id
    else
      FLastSessionId := '';
end;

procedure TChatSessionStore.DeleteAllForWorkspace(const AWorkspaceId: string);
var
  Path: string;
begin
  Path := SessionFilePath(AWorkspaceId);
  if FileExists(Path) then
    DeleteFile(Path);
  if FWorkspaceId = AWorkspaceId then begin
    SetLength(FSessions, 0);
    FLastSessionId := '';
  end;
end;

function TChatSessionStore.FindSessionInfo(const ASessionId: string; out AInfo: TChatSessionInfo): Boolean;
var
  Idx: Integer;
begin
  EnsureLoaded;
  Idx := IndexOfSession(ASessionId);
  if Idx < 0 then
    Exit(False);
  AInfo := FSessions[Idx];
  Result := True;
end;

procedure TChatSessionStore.SetSessionArchived(const ASessionId: string; AArchived: Boolean);
var
  Root, Sess: TJSONObject;
  Arr: TJSONArray;
  I, Idx: Integer;
begin
  EnsureLoaded;
  Idx := IndexOfSession(ASessionId);
  if Idx < 0 then Exit;

  FSessions[Idx].Archived := AArchived;
  if AArchived then
    FSessions[Idx].ArchivedAt := Now
  else
    FSessions[Idx].ArchivedAt := 0;

  if not ReadRootFromFile(Root) then Exit;
  try
    if not (Root.Find('sessions') is TJSONArray) then Exit;
    Arr := TJSONArray(Root.Find('sessions'));
    for I := 0 to Arr.Count - 1 do begin
      if not (Arr.Items[I] is TJSONObject) then Continue;
      Sess := TJSONObject(Arr.Items[I]);
      if not SameText(Sess.Get('id', ''), ASessionId) then Continue;
      if Sess.Find('archived') <> nil then
        Sess.Delete('archived');
      Sess.Add('archived', AArchived);
      if Sess.Find('archivedAt') <> nil then
        Sess.Delete('archivedAt');
      if AArchived then
        Sess.Add('archivedAt', DateTimeToJsonIso(FSessions[Idx].ArchivedAt));
      Break;
    end;
    WriteRootToFile(Root);
  finally
    Root.Free;
  end;
end;

procedure TChatSessionStore.SetAllowModifyOutside(const ASessionId: string; AValue: Boolean);
var
  Root, Sess: TJSONObject;
  Arr: TJSONArray;
  I, Idx: Integer;
begin
  EnsureLoaded;
  Idx := IndexOfSession(ASessionId);
  if Idx < 0 then Exit;

  FSessions[Idx].AllowModifyOutside := AValue;

  if not ReadRootFromFile(Root) then Exit;
  try
    if not (Root.Find('sessions') is TJSONArray) then Exit;
    Arr := TJSONArray(Root.Find('sessions'));
    for I := 0 to Arr.Count - 1 do begin
      if not (Arr.Items[I] is TJSONObject) then Continue;
      Sess := TJSONObject(Arr.Items[I]);
      if not SameText(Sess.Get('id', ''), ASessionId) then Continue;
      if Sess.Find('allowModifyOutside') <> nil then
        Sess.Delete('allowModifyOutside');
      Sess.Add('allowModifyOutside', AValue);
      Break;
    end;
    WriteRootToFile(Root);
  finally
    Root.Free;
  end;
end;

procedure TChatSessionStore.SetAllowBrowserLocalhost(const ASessionId: string; AValue: Boolean);
var
  Root, Sess: TJSONObject;
  Arr: TJSONArray;
  I, Idx: Integer;
begin
  EnsureLoaded;
  Idx := IndexOfSession(ASessionId);
  if Idx < 0 then Exit;
  FSessions[Idx].AllowBrowserLocalhost := AValue;
  if not ReadRootFromFile(Root) then Exit;
  try
    if not (Root.Find('sessions') is TJSONArray) then Exit;
    Arr := TJSONArray(Root.Find('sessions'));
    for I := 0 to Arr.Count - 1 do begin
      if not (Arr.Items[I] is TJSONObject) then Continue;
      Sess := TJSONObject(Arr.Items[I]);
      if not SameText(Sess.Get('id', ''), ASessionId) then Continue;
      if Sess.Find('allowBrowserLocalhost') <> nil then
        Sess.Delete('allowBrowserLocalhost');
      Sess.Add('allowBrowserLocalhost', AValue);
      Break;
    end;
    WriteRootToFile(Root);
  finally
    Root.Free;
  end;
end;

procedure TChatSessionStore.SetAllowBrowserInteractive(const ASessionId: string; AValue: Boolean);
var
  Root, Sess: TJSONObject;
  Arr: TJSONArray;
  I, Idx: Integer;
begin
  EnsureLoaded;
  Idx := IndexOfSession(ASessionId);
  if Idx < 0 then Exit;
  FSessions[Idx].AllowBrowserInteractive := AValue;
  if not ReadRootFromFile(Root) then Exit;
  try
    if not (Root.Find('sessions') is TJSONArray) then Exit;
    Arr := TJSONArray(Root.Find('sessions'));
    for I := 0 to Arr.Count - 1 do begin
      if not (Arr.Items[I] is TJSONObject) then Continue;
      Sess := TJSONObject(Arr.Items[I]);
      if not SameText(Sess.Get('id', ''), ASessionId) then Continue;
      if Sess.Find('allowBrowserInteractive') <> nil then
        Sess.Delete('allowBrowserInteractive');
      Sess.Add('allowBrowserInteractive', AValue);
      Break;
    end;
    WriteRootToFile(Root);
  finally
    Root.Free;
  end;
end;

procedure TChatSessionStore.SetAllowBrowserSensitive(const ASessionId: string; AValue: Boolean);
var
  Root, Sess: TJSONObject;
  Arr: TJSONArray;
  I, Idx: Integer;
begin
  EnsureLoaded;
  Idx := IndexOfSession(ASessionId);
  if Idx < 0 then Exit;
  FSessions[Idx].AllowBrowserSensitive := AValue;
  if not ReadRootFromFile(Root) then Exit;
  try
    if not (Root.Find('sessions') is TJSONArray) then Exit;
    Arr := TJSONArray(Root.Find('sessions'));
    for I := 0 to Arr.Count - 1 do begin
      if not (Arr.Items[I] is TJSONObject) then Continue;
      Sess := TJSONObject(Arr.Items[I]);
      if not SameText(Sess.Get('id', ''), ASessionId) then Continue;
      if Sess.Find('allowBrowserSensitive') <> nil then
        Sess.Delete('allowBrowserSensitive');
      Sess.Add('allowBrowserSensitive', AValue);
      Break;
    end;
    WriteRootToFile(Root);
  finally
    Root.Free;
  end;
end;

procedure TChatSessionStore.UpdateSessionTitle(const ASessionId, ATitle: string);
var
  Root, Sess: TJSONObject;
  Arr: TJSONArray;
  I, Idx: Integer;
  T: string;
begin
  T := Trim(ATitle);
  if T = '' then Exit;
  EnsureLoaded;
  Idx := IndexOfSession(ASessionId);
  if Idx < 0 then Exit;

  FSessions[Idx].Title := T;
  FSessions[Idx].Modified := Now;

  if not ReadRootFromFile(Root) then Exit;
  try
    if not (Root.Find('sessions') is TJSONArray) then Exit;
    Arr := TJSONArray(Root.Find('sessions'));
    for I := 0 to Arr.Count - 1 do begin
      if not (Arr.Items[I] is TJSONObject) then Continue;
      Sess := TJSONObject(Arr.Items[I]);
      if not SameText(Sess.Get('id', ''), ASessionId) then Continue;
      if Sess.Find('title') <> nil then
        Sess.Delete('title');
      Sess.Add('title', T);
      if Sess.Find('modified') <> nil then
        Sess.Delete('modified');
      Sess.Add('modified', DateTimeToJsonIso(FSessions[Idx].Modified));
      Break;
    end;
    WriteRootToFile(Root);
  finally
    Root.Free;
  end;
end;

end.
