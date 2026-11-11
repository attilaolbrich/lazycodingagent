unit uMcpConfig;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uMcpTypes;

function LoadMcpConnections: TMcpConnectionArray;
procedure SaveMcpConnections(const AConnections: TMcpConnectionArray);
function FindMcpConnectionByName(const AConnections: TMcpConnectionArray;
  const AName: string): Integer;
function FindMcpConnectionByNameCI(const AConnections: TMcpConnectionArray;
  const AName: string): Integer;
function McpConnectionByAlias(const AConnections: TMcpConnectionArray;
  const AAlias: string; out AConn: TMcpConnection): Boolean;
procedure SetMcpConfigOverrideForTests(const AConnections: TMcpConnectionArray);
procedure ClearMcpConfigOverrideForTests;

implementation

uses
  Classes, uAppDatabase, uRepositoryInterfaces, uMcpSecrets;

var
  GTestOverride: TMcpConnectionArray;
  GTestOverrideActive: Boolean = False;

function RowToConnection(const ARow: TMcpConnectionRow): TMcpConnection;
begin
  Result := DefaultMcpConnection;
  Result.Id := ARow.Id;
  Result.Name := ARow.Name;
  Result.Enabled := ARow.Enabled;
  Result.Transport := McpTransportKindFromString(ARow.Transport);
  Result.Url := ARow.Url;
  Result.Command := ARow.Command;
  Result.ArgsJson := ARow.ArgsJson;
  if Trim(Result.ArgsJson) = '' then
    Result.ArgsJson := '[]';
  Result.WorkingDir := ARow.WorkingDir;
  Result.TimeoutMs := ARow.TimeoutMs;
  if Result.TimeoutMs < 1000 then
    Result.TimeoutMs := MCP_DEFAULT_TIMEOUT_MS;
end;

function ConnectionToRow(const AConn: TMcpConnection): TMcpConnectionRow;
begin
  Result.Id := AConn.Id;
  Result.Name := AConn.Name;
  Result.Enabled := AConn.Enabled;
  Result.Transport := McpTransportKindToString(AConn.Transport);
  Result.Url := AConn.Url;
  Result.BearerToken := GetMcpBearerToken(AConn.Id);
  Result.Command := AConn.Command;
  Result.ArgsJson := AConn.ArgsJson;
  if Trim(Result.ArgsJson) = '' then
    Result.ArgsJson := '[]';
  Result.WorkingDir := AConn.WorkingDir;
  Result.TimeoutMs := AConn.TimeoutMs;
end;

procedure SetMcpConfigOverrideForTests(const AConnections: TMcpConnectionArray);
begin
  GTestOverride := AConnections;
  GTestOverrideActive := True;
end;

procedure ClearMcpConfigOverrideForTests;
begin
  GTestOverrideActive := False;
end;

function LoadMcpConnections: TMcpConnectionArray;
var
  Repo: IMcpRepository;
  Rows: TMcpConnectionRows;
  I: Integer;
begin
  if GTestOverrideActive then
    Exit(GTestOverride);
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  Repo := TAppDatabase.GlobalMcp;
  Repo.LoadConnections(Rows);
  SetLength(Result, Length(Rows));
  for I := 0 to High(Rows) do
    Result[I] := RowToConnection(Rows[I]);
end;

procedure SaveMcpConnections(const AConnections: TMcpConnectionArray);
var
  Repo: IMcpRepository;
  Rows: TMcpConnectionRows;
  I: Integer;
begin
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  SetLength(Rows, Length(AConnections));
  for I := 0 to High(AConnections) do
    Rows[I] := ConnectionToRow(AConnections[I]);
  Repo := TAppDatabase.GlobalMcp;
  Repo.SaveConnections(Rows);
end;

function FindMcpConnectionByName(const AConnections: TMcpConnectionArray;
  const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(AConnections) do
    if AConnections[I].Name = AName then
      Exit(I);
end;

function FindMcpConnectionByNameCI(const AConnections: TMcpConnectionArray;
  const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(AConnections) do
    if SameText(AConnections[I].Name, AName) then
      Exit(I);
end;

function McpConnectionByAlias(const AConnections: TMcpConnectionArray;
  const AAlias: string; out AConn: TMcpConnection): Boolean;
var
  Idx: Integer;
begin
  Idx := FindMcpConnectionByNameCI(AConnections, AAlias);
  Result := Idx >= 0;
  if Result then
    AConn := AConnections[Idx];
end;

end.
