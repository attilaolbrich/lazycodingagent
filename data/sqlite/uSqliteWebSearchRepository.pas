unit uSqliteWebSearchRepository;

{$mode ObjFPC}{$H+}

interface

uses
  uRepositoryInterfaces, uSqlite3Embed;

type
  TSqliteWebSearchRepository = class(TInterfacedObject, IWebSearchRepository)
  private
    FDb: PSqlite3;
  public
    constructor Create(ADb: PSqlite3);
    procedure LoadConnections(out ARows: TWebSearchConnectionRows);
    procedure SaveConnections(const ARows: TWebSearchConnectionRows);
  end;

implementation

uses
  SysUtils, uSqliteCheck, uSecurityManager;

constructor TSqliteWebSearchRepository.Create(ADb: PSqlite3);
begin
  inherited Create;
  if ADb = nil then
    raise Exception.Create('TSqliteWebSearchRepository requires an open database');
  FDb := ADb;
end;

procedure TSqliteWebSearchRepository.LoadConnections(out ARows: TWebSearchConnectionRows);
var
  Stmt: PSqlite3Stmt;
  N: Integer;
  P: PAnsiChar;
  StoredKey: string;
begin
  SetLength(ARows, 0);
  SqliteCheck(sqlite3_prepare_v2(FDb,
    'SELECT id, name, provider, enabled, priority, timeout_ms, instance_url, tavily_search_depth, ' +
    'custom_header_name, custom_header_value, api_key FROM web_search_connections ORDER BY priority, id',
    -1, @Stmt, nil), FDb, 'prepare web_search_connections load');
  try
    N := 0;
    while sqlite3_step(Stmt) = SQLITE_ROW do
    begin
      SetLength(ARows, N + 1);
      P := sqlite3_column_text(Stmt, 0);
      if P <> nil then ARows[N].Id := string(P) else ARows[N].Id := '';
      P := sqlite3_column_text(Stmt, 1);
      if P <> nil then ARows[N].Name := string(P) else ARows[N].Name := '';
      P := sqlite3_column_text(Stmt, 2);
      if P <> nil then ARows[N].Provider := string(P) else ARows[N].Provider := '';
      ARows[N].Enabled := sqlite3_column_int(Stmt, 3) <> 0;
      ARows[N].Priority := sqlite3_column_int(Stmt, 4);
      ARows[N].TimeoutMs := sqlite3_column_int(Stmt, 5);
      P := sqlite3_column_text(Stmt, 6);
      if P <> nil then ARows[N].InstanceUrl := string(P) else ARows[N].InstanceUrl := '';
      P := sqlite3_column_text(Stmt, 7);
      if P <> nil then ARows[N].TavilySearchDepth := string(P) else ARows[N].TavilySearchDepth := 'basic';
      P := sqlite3_column_text(Stmt, 8);
      if P <> nil then ARows[N].CustomHeaderName := string(P) else ARows[N].CustomHeaderName := '';
      P := sqlite3_column_text(Stmt, 9);
      if P <> nil then ARows[N].CustomHeaderValue := string(P) else ARows[N].CustomHeaderValue := '';
      P := sqlite3_column_text(Stmt, 10);
      if P <> nil then StoredKey := string(P) else StoredKey := '';
      if StoredKey = '' then
        ARows[N].ApiKey := ''
      else if IsEncryptedSecretBlob(StoredKey) then
        ARows[N].ApiKey := DecryptSecret(StoredKey)
      else
        ARows[N].ApiKey := StoredKey;
      Inc(N);
    end;
  finally
    sqlite3_finalize(Stmt);
  end;
end;

procedure TSqliteWebSearchRepository.SaveConnections(const ARows: TWebSearchConnectionRows);
var
  Stmt: PSqlite3Stmt;
  I: Integer;
  Err: PAnsiChar;
  EncKey: string;
begin
  Err := nil;
  SqliteCheck(sqlite3_exec(FDb, 'DELETE FROM web_search_connections;', nil, nil, @Err), FDb, 'clear web_search');
  if Err <> nil then sqlite3_free(Err);
  SqliteCheck(sqlite3_prepare_v2(FDb,
    'INSERT INTO web_search_connections(id, name, provider, enabled, priority, timeout_ms, instance_url, ' +
    'tavily_search_depth, custom_header_name, custom_header_value, api_key) VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11)',
    -1, @Stmt, nil), FDb, 'prepare web_search save');
  try
    for I := 0 to High(ARows) do
    begin
      if Trim(ARows[I].ApiKey) = '' then
        EncKey := ''
      else
        EncKey := EncryptSecret(ARows[I].ApiKey);
      SqliteCheck(sqlite3_bind_text(Stmt, 1, PAnsiChar(AnsiString(ARows[I].Id)), -1, SQLITE_TRANSIENT), FDb, 'bind id');
      SqliteCheck(sqlite3_bind_text(Stmt, 2, PAnsiChar(AnsiString(ARows[I].Name)), -1, SQLITE_TRANSIENT), FDb, 'bind name');
      SqliteCheck(sqlite3_bind_text(Stmt, 3, PAnsiChar(AnsiString(ARows[I].Provider)), -1, SQLITE_TRANSIENT), FDb, 'bind provider');
      SqliteCheck(sqlite3_bind_int(Stmt, 4, Ord(ARows[I].Enabled)), FDb, 'bind enabled');
      SqliteCheck(sqlite3_bind_int(Stmt, 5, ARows[I].Priority), FDb, 'bind priority');
      SqliteCheck(sqlite3_bind_int(Stmt, 6, ARows[I].TimeoutMs), FDb, 'bind timeout');
      SqliteCheck(sqlite3_bind_text(Stmt, 7, PAnsiChar(AnsiString(ARows[I].InstanceUrl)), -1, SQLITE_TRANSIENT), FDb, 'bind url');
      SqliteCheck(sqlite3_bind_text(Stmt, 8, PAnsiChar(AnsiString(ARows[I].TavilySearchDepth)), -1, SQLITE_TRANSIENT), FDb, 'bind depth');
      SqliteCheck(sqlite3_bind_text(Stmt, 9, PAnsiChar(AnsiString(ARows[I].CustomHeaderName)), -1, SQLITE_TRANSIENT), FDb, 'bind hdr name');
      SqliteCheck(sqlite3_bind_text(Stmt, 10, PAnsiChar(AnsiString(ARows[I].CustomHeaderValue)), -1, SQLITE_TRANSIENT), FDb, 'bind hdr val');
      SqliteCheck(sqlite3_bind_text(Stmt, 11, PAnsiChar(AnsiString(EncKey)), -1, SQLITE_TRANSIENT), FDb, 'bind api key');
      SqliteStepDone(sqlite3_step(Stmt), FDb, 'step web_search save');
      SqliteCheck(sqlite3_reset(Stmt), FDb, 'reset web_search save');
    end;
  finally
    sqlite3_finalize(Stmt);
  end;
end;

end.
