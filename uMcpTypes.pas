unit uMcpTypes;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uAgentTypes;

const
  MCP_CONFIG_VERSION = 1;
  MCP_DEFAULT_TIMEOUT_MS = 30000;
  MCP_CLIENT_NAME = 'LazyCodingAgent';
  MCP_CLIENT_VERSION = '1.0';
  MCP_PROTOCOL_VERSION = '2024-11-05';
  MCP_TOOL_PREFIX = 'mcp_';

type
  TMcpTransportKind = (mtkHttp, mtkStdio);

  TMcpConnection = record
    Id: string;
    Name: string;
    Enabled: Boolean;
    Transport: TMcpTransportKind;
    Url: string;
    Command: string;
    ArgsJson: string;
    WorkingDir: string;
    TimeoutMs: Integer;
  end;
  TMcpConnectionArray = array of TMcpConnection;

  TMcpToolInfo = record
    Name: string;
    Description: string;
    InputSchemaJson: string;
  end;
  TMcpToolInfoArray = array of TMcpToolInfo;

  TMcpBoundTool = record
    PrefixedName: string;
    ServerName: string;
    ConnectionId: string;
    Alias: string;
    Def: TToolDef;
  end;
  TMcpBoundToolArray = array of TMcpBoundTool;

function McpTransportKindToString(AKind: TMcpTransportKind): string;
function McpTransportKindFromString(const S: string): TMcpTransportKind;
function McpTransportDisplayName(AKind: TMcpTransportKind): string;
function DefaultMcpConnection: TMcpConnection;
function NewMcpConnectionId: string;
function McpAliasIsValid(const AName: string): Boolean;
function SanitizeMcpToolSegment(const S: string): string;
function McpPrefixedToolName(const AAlias, AServerToolName: string): string;
function ConnectionSummaryLine(const AConn: TMcpConnection): string;
function ConnectionIsConfigured(const AConn: TMcpConnection): Boolean;

implementation

uses
  Classes;

function McpTransportKindToString(AKind: TMcpTransportKind): string;
begin
  case AKind of
    mtkStdio: Result := 'stdio';
  else
    Result := 'http';
  end;
end;

function McpTransportKindFromString(const S: string): TMcpTransportKind;
begin
  if SameText(S, 'stdio') then
    Result := mtkStdio
  else
    Result := mtkHttp;
end;

function McpTransportDisplayName(AKind: TMcpTransportKind): string;
begin
  case AKind of
    mtkStdio: Result := 'Stdio';
  else
    Result := 'HTTP';
  end;
end;

function DefaultMcpConnection: TMcpConnection;
begin
  Result.Id := '';
  Result.Name := '';
  Result.Enabled := True;
  Result.Transport := mtkHttp;
  Result.Url := '';
  Result.Command := '';
  Result.ArgsJson := '[]';
  Result.WorkingDir := '';
  Result.TimeoutMs := MCP_DEFAULT_TIMEOUT_MS;
end;

function NewMcpConnectionId: string;
var
  G: TGUID;
begin
  CreateGUID(G);
  Result := GUIDToString(G);
  Result := StringReplace(Result, '{', '', [rfReplaceAll]);
  Result := StringReplace(Result, '}', '', [rfReplaceAll]);
end;

function McpAliasIsValid(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(AName) < 1 then Exit;
  if not (AName[1] in ['A'..'Z', 'a'..'z', '_']) then Exit;
  for I := 1 to Length(AName) do
    if not (AName[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit;
  Result := True;
end;

function SanitizeMcpToolSegment(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if C in ['A'..'Z', 'a'..'z', '0'..'9', '_'] then
      Result := Result + C
    else if (Result <> '') and (Result[Length(Result)] <> '_') then
      Result := Result + '_';
  end;
  if Result = '' then
    Result := 'tool';
end;

function McpPrefixedToolName(const AAlias, AServerToolName: string): string;
begin
  Result := MCP_TOOL_PREFIX + SanitizeMcpToolSegment(LowerCase(AAlias)) + '_' +
    SanitizeMcpToolSegment(AServerToolName);
end;

function ConnectionSummaryLine(const AConn: TMcpConnection): string;
begin
  case AConn.Transport of
    mtkStdio:
      Result := Trim(AConn.Command);
    else
      Result := Trim(AConn.Url);
  end;
end;

function ConnectionIsConfigured(const AConn: TMcpConnection): Boolean;
begin
  if not AConn.Enabled then
    Exit(False);
  if not McpAliasIsValid(Trim(AConn.Name)) then
    Exit(False);
  case AConn.Transport of
    mtkStdio:
      Result := Trim(AConn.Command) <> '';
    else
      Result := Trim(AConn.Url) <> '';
  end;
end;

end.
