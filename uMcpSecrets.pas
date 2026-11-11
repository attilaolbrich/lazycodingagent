unit uMcpSecrets;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function GetMcpBearerToken(const AConnectionId: string): string;
procedure SetMcpBearerToken(const AConnectionId, AToken: string);
procedure ClearMcpBearerToken(const AConnectionId: string);
function McpBearerTokenIsSet(const AConnectionId: string): Boolean;

implementation

uses
  uAppDatabase, uRepositoryInterfaces, uMcpTypes;

function GetMcpBearerTokenFromDb(const AConnectionId: string): string;
var
  Repo: IMcpRepository;
  Rows: TMcpConnectionRows;
  I: Integer;
begin
  Result := '';
  if Trim(AConnectionId) = '' then Exit;
  Repo := TAppDatabase.GlobalMcp;
  Repo.LoadConnections(Rows);
  for I := 0 to High(Rows) do
    if Rows[I].Id = AConnectionId then
      Exit(Rows[I].BearerToken);
end;

procedure SetMcpBearerTokenInDb(const AConnectionId, AToken: string);
var
  Repo: IMcpRepository;
  Rows: TMcpConnectionRows;
  I: Integer;
  Found: Boolean;
  Row: TMcpConnectionRow;
begin
  if Trim(AConnectionId) = '' then Exit;
  Repo := TAppDatabase.GlobalMcp;
  Repo.LoadConnections(Rows);
  Found := False;
  for I := 0 to High(Rows) do
    if Rows[I].Id = AConnectionId then
    begin
      Rows[I].BearerToken := AToken;
      Found := True;
      Break;
    end;
  if not Found then
  begin
    Row.Id := AConnectionId;
    Row.Name := 'pending';
    Row.Enabled := False;
    Row.Transport := McpTransportKindToString(mtkHttp);
    Row.Url := '';
    Row.BearerToken := AToken;
    Row.Command := '';
    Row.ArgsJson := '[]';
    Row.WorkingDir := '';
    Row.TimeoutMs := MCP_DEFAULT_TIMEOUT_MS;
    SetLength(Rows, Length(Rows) + 1);
    Rows[High(Rows)] := Row;
  end;
  Repo.SaveConnections(Rows);
end;

function GetMcpBearerToken(const AConnectionId: string): string;
begin
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  Result := GetMcpBearerTokenFromDb(AConnectionId);
end;

procedure SetMcpBearerToken(const AConnectionId, AToken: string);
begin
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  SetMcpBearerTokenInDb(AConnectionId, AToken);
end;

procedure ClearMcpBearerToken(const AConnectionId: string);
begin
  SetMcpBearerToken(AConnectionId, '');
end;

function McpBearerTokenIsSet(const AConnectionId: string): Boolean;
begin
  Result := Trim(GetMcpBearerToken(AConnectionId)) <> '';
end;

end.
