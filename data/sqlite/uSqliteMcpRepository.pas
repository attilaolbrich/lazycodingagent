unit uSqliteMcpRepository;

{$mode ObjFPC}{$H+}

interface

uses
  uRepositoryInterfaces, uSqlite3Embed;

type
  TSqliteMcpRepository = class(TInterfacedObject, IMcpRepository)
  private
    FDb: PSqlite3;
  public
    constructor Create(ADb: PSqlite3);
    procedure LoadConnections(out ARows: TMcpConnectionRows);
    procedure SaveConnections(const ARows: TMcpConnectionRows);
  end;

implementation

uses
  SysUtils, uSqliteCheck, uSecurityManager;

constructor TSqliteMcpRepository.Create(ADb: PSqlite3);
begin
  inherited Create;
  if ADb = nil then
    raise Exception.Create('TSqliteMcpRepository requires an open database');
  FDb := ADb;
end;

procedure TSqliteMcpRepository.LoadConnections(out ARows: TMcpConnectionRows);
var
  Stmt: PSqlite3Stmt;
  N: Integer;
  P: PAnsiChar;
  StoredToken: string;
begin
  SetLength(ARows, 0);
  SqliteCheck(sqlite3_prepare_v2(FDb,
    'SELECT id, name, enabled, transport, url, bearer_token, command, args_json, cwd, timeout_ms ' +
    'FROM mcp_connections ORDER BY name COLLATE NOCASE, id',
    -1, @Stmt, nil), FDb, 'prepare mcp_connections load');
  try
    N := 0;
    while sqlite3_step(Stmt) = SQLITE_ROW do
    begin
      SetLength(ARows, N + 1);
      P := sqlite3_column_text(Stmt, 0);
      if P <> nil then ARows[N].Id := string(P) else ARows[N].Id := '';
      P := sqlite3_column_text(Stmt, 1);
      if P <> nil then ARows[N].Name := string(P) else ARows[N].Name := '';
      ARows[N].Enabled := sqlite3_column_int(Stmt, 2) <> 0;
      P := sqlite3_column_text(Stmt, 3);
      if P <> nil then ARows[N].Transport := string(P) else ARows[N].Transport := 'http';
      P := sqlite3_column_text(Stmt, 4);
      if P <> nil then ARows[N].Url := string(P) else ARows[N].Url := '';
      P := sqlite3_column_text(Stmt, 5);
      if P <> nil then StoredToken := string(P) else StoredToken := '';
      if StoredToken = '' then
        ARows[N].BearerToken := ''
      else if IsEncryptedSecretBlob(StoredToken) then
        ARows[N].BearerToken := DecryptSecret(StoredToken)
      else
        ARows[N].BearerToken := StoredToken;
      P := sqlite3_column_text(Stmt, 6);
      if P <> nil then ARows[N].Command := string(P) else ARows[N].Command := '';
      P := sqlite3_column_text(Stmt, 7);
      if P <> nil then ARows[N].ArgsJson := string(P) else ARows[N].ArgsJson := '[]';
      P := sqlite3_column_text(Stmt, 8);
      if P <> nil then ARows[N].WorkingDir := string(P) else ARows[N].WorkingDir := '';
      ARows[N].TimeoutMs := sqlite3_column_int(Stmt, 9);
      Inc(N);
    end;
  finally
    sqlite3_finalize(Stmt);
  end;
end;

procedure TSqliteMcpRepository.SaveConnections(const ARows: TMcpConnectionRows);
var
  Stmt: PSqlite3Stmt;
  I: Integer;
  Err: PAnsiChar;
  EncToken: string;
begin
  Err := nil;
  SqliteCheck(sqlite3_exec(FDb, 'DELETE FROM mcp_connections;', nil, nil, @Err), FDb, 'clear mcp');
  if Err <> nil then sqlite3_free(Err);
  SqliteCheck(sqlite3_prepare_v2(FDb,
    'INSERT INTO mcp_connections(id, name, enabled, transport, url, bearer_token, command, args_json, cwd, timeout_ms) ' +
    'VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10)',
    -1, @Stmt, nil), FDb, 'prepare mcp save');
  try
    for I := 0 to High(ARows) do
    begin
      if Trim(ARows[I].BearerToken) = '' then
        EncToken := ''
      else
        EncToken := EncryptSecret(ARows[I].BearerToken);
      SqliteCheck(sqlite3_bind_text(Stmt, 1, PAnsiChar(AnsiString(ARows[I].Id)), -1, SQLITE_TRANSIENT), FDb, 'bind id');
      SqliteCheck(sqlite3_bind_text(Stmt, 2, PAnsiChar(AnsiString(ARows[I].Name)), -1, SQLITE_TRANSIENT), FDb, 'bind name');
      SqliteCheck(sqlite3_bind_int(Stmt, 3, Ord(ARows[I].Enabled)), FDb, 'bind enabled');
      SqliteCheck(sqlite3_bind_text(Stmt, 4, PAnsiChar(AnsiString(ARows[I].Transport)), -1, SQLITE_TRANSIENT), FDb, 'bind transport');
      SqliteCheck(sqlite3_bind_text(Stmt, 5, PAnsiChar(AnsiString(ARows[I].Url)), -1, SQLITE_TRANSIENT), FDb, 'bind url');
      SqliteCheck(sqlite3_bind_text(Stmt, 6, PAnsiChar(AnsiString(EncToken)), -1, SQLITE_TRANSIENT), FDb, 'bind bearer');
      SqliteCheck(sqlite3_bind_text(Stmt, 7, PAnsiChar(AnsiString(ARows[I].Command)), -1, SQLITE_TRANSIENT), FDb, 'bind command');
      SqliteCheck(sqlite3_bind_text(Stmt, 8, PAnsiChar(AnsiString(ARows[I].ArgsJson)), -1, SQLITE_TRANSIENT), FDb, 'bind args');
      SqliteCheck(sqlite3_bind_text(Stmt, 9, PAnsiChar(AnsiString(ARows[I].WorkingDir)), -1, SQLITE_TRANSIENT), FDb, 'bind cwd');
      SqliteCheck(sqlite3_bind_int(Stmt, 10, ARows[I].TimeoutMs), FDb, 'bind timeout');
      SqliteStepDone(sqlite3_step(Stmt), FDb, 'step mcp save');
      SqliteCheck(sqlite3_reset(Stmt), FDb, 'reset mcp save');
    end;
  finally
    sqlite3_finalize(Stmt);
  end;
end;

end.
