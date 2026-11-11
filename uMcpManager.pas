unit uMcpManager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, SyncObjs, uAgentTypes, uAgentToolBase, uMcpTypes, uMcpHttp;

type
  TMcpCancelCheck = function: Boolean of object;

  TMcpTransportRef = class
  public
    Transport: IMcpTransport;
  end;

  TMcpSessionManager = class
  private
    FActiveAliases: TStringList;
    FBoundTools: TMcpBoundToolArray;
    FStatusNotes: TStringList;
    FTransports: TStringList;
    FLock: TCriticalSection;
    FCancelCheck: TMcpCancelCheck;
    function FindBoundTool(const APrefixedName: string): Integer;
    function TransportForConnection(const AConn: TMcpConnection): IMcpTransport;
    procedure CloseTransports;
    procedure RefreshBoundTools;
  public
    constructor Create(ACancelCheck: TMcpCancelCheck);
    destructor Destroy; override;

    procedure ClearSession;
    procedure RegisterMentionsFromPrompt(const APrompt: string);
    procedure RescanMessages(const AMessages: array of TChatMessage);

    function ActiveAliasCount: Integer;
    function ActiveAliasesText: string;

    function BuildStatusNotes: string;
    function BuildGuidance(AIncludeSchemas: Boolean): string;
    procedure AppendToolDefs(var ADefs: TToolDefArray);

    function IsMcpTool(const AName: string): Boolean;
    function ExecuteTool(const AName, AArgumentsJson: string): TToolExecutionResult;

    class function TestConnection(const AConn: TMcpConnection; const ABearer: string;
      out AToolCount: Integer; out ErrMsg: string): Boolean;
  end;

implementation

uses
  uMcpConfig, uMcpMentions, uMcpJson, uMcpStdio, uMcpSecrets, uAppTypes;

constructor TMcpSessionManager.Create(ACancelCheck: TMcpCancelCheck);
begin
  inherited Create;
  FActiveAliases := TStringList.Create;
  FActiveAliases.Sorted := True;
  FActiveAliases.Duplicates := dupIgnore;
  FActiveAliases.CaseSensitive := False;
  FStatusNotes := TStringList.Create;
  FTransports := TStringList.Create;
  FTransports.OwnsObjects := True;
  FTransports.Sorted := False;
  FLock := TCriticalSection.Create;
  FCancelCheck := ACancelCheck;
  SetLength(FBoundTools, 0);
end;

destructor TMcpSessionManager.Destroy;
begin
  ClearSession;
  FTransports.Free;
  FStatusNotes.Free;
  FActiveAliases.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TMcpSessionManager.ClearSession;
begin
  FLock.Enter;
  try
    FActiveAliases.Clear;
    SetLength(FBoundTools, 0);
    FStatusNotes.Clear;
    CloseTransports;
  finally
    FLock.Leave;
  end;
end;

procedure TMcpSessionManager.CloseTransports;
var
  I: Integer;
  Ref: TMcpTransportRef;
begin
  for I := 0 to FTransports.Count - 1 do
  begin
    Ref := TMcpTransportRef(FTransports.Objects[I]);
    if Ref <> nil then
      Ref.Transport.Close;
  end;
  FTransports.Clear;
end;

procedure TMcpSessionManager.RegisterMentionsFromPrompt(const APrompt: string);
begin
  FLock.Enter;
  try
    RegisterAliasesFromText(FActiveAliases, APrompt);
    CloseTransports;
    RefreshBoundTools;
  finally
    FLock.Leave;
  end;
end;

procedure TMcpSessionManager.RescanMessages(const AMessages: array of TChatMessage);
begin
  FLock.Enter;
  try
    FActiveAliases.Clear;
    RescanUserMessagesForMcpMentions(FActiveAliases, AMessages);
    CloseTransports;
    RefreshBoundTools;
  finally
    FLock.Leave;
  end;
end;

function TMcpSessionManager.TransportForConnection(const AConn: TMcpConnection): IMcpTransport;
var
  Idx: Integer;
  Bearer: string;
  Tr: IMcpTransport;
  Ref: TMcpTransportRef;
begin
  Idx := FTransports.IndexOf(AConn.Id);
  if Idx >= 0 then
    Exit(TMcpTransportRef(FTransports.Objects[Idx]).Transport);
  case AConn.Transport of
    mtkStdio:
      Tr := TMcpStdioTransport.Create(AConn.Command, AConn.ArgsJson, AConn.WorkingDir,
        AConn.TimeoutMs, FCancelCheck);
    else begin
      Bearer := GetMcpBearerToken(AConn.Id);
      Tr := TMcpHttpTransport.Create(AConn.Url, Bearer, AConn.TimeoutMs, FCancelCheck);
    end;
  end;
  Ref := TMcpTransportRef.Create;
  Ref.Transport := Tr;
  FTransports.AddObject(AConn.Id, Ref);
  Result := Tr;
end;

procedure TMcpSessionManager.RefreshBoundTools;
var
  Connections: TMcpConnectionArray;
  I, A: Integer;
  Conn: TMcpConnection;
  Tr: IMcpTransport;
  Tools: TMcpToolInfoArray;
  Bound: TMcpBoundToolArray;
  ErrMsg: string;
  Alias: string;
begin
  SetLength(FBoundTools, 0);
  FStatusNotes.Clear;
  if FActiveAliases.Count = 0 then Exit;
  Connections := LoadMcpConnections;
  for A := 0 to FActiveAliases.Count - 1 do
  begin
    Alias := FActiveAliases[A];
  if not McpConnectionByAlias(Connections, Alias, Conn) then
    begin
      FStatusNotes.Add('Unknown MCP plugin @' + Alias + ' (not configured).');
      Continue;
    end;
    if not ConnectionIsConfigured(Conn) then
    begin
      FStatusNotes.Add('MCP plugin ' + Conn.Name + ' is disabled or incomplete.');
      Continue;
    end;
    Tr := TransportForConnection(Conn);
    if not Tr.ListTools(Tools, ErrMsg) then
    begin
      FStatusNotes.Add('MCP plugin ' + Conn.Name + ' unavailable: ' + ErrMsg);
      Continue;
    end;
    McpToolsToBoundTools(Conn.Name, Conn.Id, Tools, Bound);
    for I := 0 to High(Bound) do
    begin
      SetLength(FBoundTools, Length(FBoundTools) + 1);
      FBoundTools[High(FBoundTools)] := Bound[I];
    end;
  end;
end;

function TMcpSessionManager.ActiveAliasCount: Integer;
begin
  Result := FActiveAliases.Count;
end;

function TMcpSessionManager.ActiveAliasesText: string;
begin
  Result := FActiveAliases.CommaText;
end;

function TMcpSessionManager.BuildStatusNotes: string;
begin
  if FStatusNotes.Count = 0 then
    Exit('');
  Result := StringReplace(FStatusNotes.Text, LineEnding, LineEnding + '- ', [rfReplaceAll]);
  Result := '- ' + Trim(Result);
end;

function TMcpSessionManager.BuildGuidance(AIncludeSchemas: Boolean): string;
var
  Notes, Tools: string;
begin
  if Length(FBoundTools) = 0 then
  begin
    Notes := BuildStatusNotes;
    if Notes <> '' then
      Exit('MCP plugins:' + LineEnding + Notes + LineEnding);
    Exit('');
  end;
  Tools := BuildMcpToolsGuidance(FBoundTools, AIncludeSchemas);
  Notes := BuildStatusNotes;
  if Notes <> '' then
    Result := Notes + LineEnding + Tools
  else
    Result := Tools;
end;

procedure TMcpSessionManager.AppendToolDefs(var ADefs: TToolDefArray);
var
  I, Base: Integer;
begin
  if Length(FBoundTools) = 0 then Exit;
  Base := Length(ADefs);
  SetLength(ADefs, Base + Length(FBoundTools));
  for I := 0 to High(FBoundTools) do
    ADefs[Base + I] := FBoundTools[I].Def;
end;

function TMcpSessionManager.FindBoundTool(const APrefixedName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FBoundTools) do
    if SameText(FBoundTools[I].PrefixedName, APrefixedName) then
      Exit(I);
end;

function TMcpSessionManager.IsMcpTool(const AName: string): Boolean;
begin
  Result := FindBoundTool(AName) >= 0;
end;

function TMcpSessionManager.ExecuteTool(const AName, AArgumentsJson: string): TToolExecutionResult;
var
  Idx: Integer;
  Bound: TMcpBoundTool;
  Connections: TMcpConnectionArray;
  Conn: TMcpConnection;
  Tr: IMcpTransport;
  OutText, ErrMsg: string;
begin
  Result := ToolResultFromJson(ToolError('Unknown MCP tool: ' + AName));
  Idx := FindBoundTool(AName);
  if Idx < 0 then Exit;
  Bound := FBoundTools[Idx];
  Connections := LoadMcpConnections;
  if not McpConnectionByAlias(Connections, Bound.Alias, Conn) then
  begin
    Result := ToolResultFromJson(ToolError('MCP plugin not found: ' + Bound.Alias));
    Exit;
  end;
  Tr := TransportForConnection(Conn);
  if not Tr.CallTool(Bound.ServerName, AArgumentsJson, OutText, ErrMsg) then
  begin
    Result.Success := False;
    Result.Output := '{"error":' + QuotedStr(ErrMsg) + '}';
    Result.Summary := 'mcp error';
    Exit;
  end;
  Result.Success := True;
  Result.Output := OutText;
  Result.Summary := Bound.ServerName;
end;

class function TMcpSessionManager.TestConnection(const AConn: TMcpConnection; const ABearer: string;
  out AToolCount: Integer; out ErrMsg: string): Boolean;
var
  Tr: IMcpTransport;
  Tools: TMcpToolInfoArray;
begin
  AToolCount := 0;
  case AConn.Transport of
    mtkStdio:
      Tr := TMcpStdioTransport.Create(AConn.Command, AConn.ArgsJson, AConn.WorkingDir,
        AConn.TimeoutMs, nil);
    else
      Tr := TMcpHttpTransport.Create(AConn.Url, ABearer, AConn.TimeoutMs, nil);
  end;
  try
    Result := Tr.ListTools(Tools, ErrMsg);
    if Result then
      AToolCount := Length(Tools);
  finally
    Tr.Close;
  end;
end;

end.
