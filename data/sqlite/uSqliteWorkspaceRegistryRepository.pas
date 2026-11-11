unit uSqliteWorkspaceRegistryRepository;

{$mode ObjFPC}{$H+}

interface

uses
  uRepositoryInterfaces, uSqlite3Embed;

type
  TSqliteWorkspaceRegistryRepository = class(TInterfacedObject, IWorkspaceRegistryRepository)
  private
    FDb: PSqlite3;
  public
    constructor Create(ADb: PSqlite3);
    procedure LoadAll(out ARows: TRegistryWorkspaceRows; out AActiveWorkspaceId: string);
    procedure SaveAll(const ARows: TRegistryWorkspaceRows; const AActiveWorkspaceId: string);
  end;

implementation

uses
  SysUtils, uSqliteCheck, uGlobalConfigKeys, uAppSettingsCodec, uSqliteAppSettingsRepository;

constructor TSqliteWorkspaceRegistryRepository.Create(ADb: PSqlite3);
begin
  inherited Create;
  if ADb = nil then
    raise Exception.Create('TSqliteWorkspaceRegistryRepository requires an open database');
  FDb := ADb;
end;

procedure TSqliteWorkspaceRegistryRepository.LoadAll(out ARows: TRegistryWorkspaceRows;
  out AActiveWorkspaceId: string);
var
  Stmt: PSqlite3Stmt;
  RC: Integer;
  N: Integer;
  P: PAnsiChar;
  Settings: IAppSettingsRepository;
begin
  SetLength(ARows, 0);
  AActiveWorkspaceId := '';
  Settings := TSqliteAppSettingsRepository.Create(FDb);
  AActiveWorkspaceId := SettingsTryGetString(Settings, KEY_WORKSPACE_ACTIVE_ID, '');
  RC := sqlite3_prepare_v2(FDb,
    'SELECT id, display_name, folder_path, last_session_id, sort_order FROM workspaces ORDER BY sort_order',
    -1, @Stmt, nil);
  SqliteCheck(RC, FDb, 'prepare workspaces load');
  try
    N := 0;
    while sqlite3_step(Stmt) = SQLITE_ROW do
    begin
      SetLength(ARows, N + 1);
      P := sqlite3_column_text(Stmt, 0);
      if P <> nil then ARows[N].Id := string(P) else ARows[N].Id := '';
      P := sqlite3_column_text(Stmt, 1);
      if P <> nil then ARows[N].DisplayName := string(P) else ARows[N].DisplayName := '';
      P := sqlite3_column_text(Stmt, 2);
      if P <> nil then ARows[N].FolderPath := string(P) else ARows[N].FolderPath := '';
      P := sqlite3_column_text(Stmt, 3);
      if P <> nil then ARows[N].LastSessionId := string(P) else ARows[N].LastSessionId := '';
      ARows[N].SortOrder := sqlite3_column_int(Stmt, 4);
      Inc(N);
    end;
  finally
    sqlite3_finalize(Stmt);
  end;
end;

procedure TSqliteWorkspaceRegistryRepository.SaveAll(const ARows: TRegistryWorkspaceRows;
  const AActiveWorkspaceId: string);
var
  Stmt: PSqlite3Stmt;
  I: Integer;
  Err: PAnsiChar;
  Settings: IAppSettingsRepository;
begin
  Err := nil;
  SqliteCheck(sqlite3_exec(FDb, 'DELETE FROM workspaces;', nil, nil, @Err), FDb, 'clear workspaces');
  if Err <> nil then sqlite3_free(Err);
  SqliteCheck(sqlite3_prepare_v2(FDb,
    'INSERT INTO workspaces(id, display_name, folder_path, last_session_id, sort_order) VALUES(?1,?2,?3,?4,?5)',
    -1, @Stmt, nil), FDb, 'prepare workspaces save');
  try
    for I := 0 to High(ARows) do
    begin
      SqliteCheck(sqlite3_bind_text(Stmt, 1, PAnsiChar(AnsiString(ARows[I].Id)), -1, SQLITE_TRANSIENT), FDb, 'bind id');
      SqliteCheck(sqlite3_bind_text(Stmt, 2, PAnsiChar(AnsiString(ARows[I].DisplayName)), -1, SQLITE_TRANSIENT), FDb, 'bind name');
      SqliteCheck(sqlite3_bind_text(Stmt, 3, PAnsiChar(AnsiString(ARows[I].FolderPath)), -1, SQLITE_TRANSIENT), FDb, 'bind path');
      SqliteCheck(sqlite3_bind_text(Stmt, 4, PAnsiChar(AnsiString(ARows[I].LastSessionId)), -1, SQLITE_TRANSIENT), FDb, 'bind session');
      SqliteCheck(sqlite3_bind_int(Stmt, 5, ARows[I].SortOrder), FDb, 'bind sort');
      SqliteStepDone(sqlite3_step(Stmt), FDb, 'step workspaces save');
      SqliteCheck(sqlite3_reset(Stmt), FDb, 'reset workspaces save');
    end;
  finally
    sqlite3_finalize(Stmt);
  end;
  Settings := TSqliteAppSettingsRepository.Create(FDb);
  SettingsSetString(Settings, KEY_WORKSPACE_ACTIVE_ID, AActiveWorkspaceId);
end;

end.
