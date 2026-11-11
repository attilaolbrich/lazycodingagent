unit uAppDatabase;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, uRepositoryInterfaces;

type
  TAppDatabaseScope = (adsGlobal, adsWorkspace);

  TAppDatabase = class
  private
    class function LazarusConfigDir: string;
    class function OpenDatabaseFile(const AFileName: string): Pointer;
    class procedure CloseDatabaseHandle(var AHandle: Pointer);
    class procedure ApplyPragmas(ADb: Pointer);
    class procedure RunMigrations(ADb: Pointer);
    class function QuerySchemaVersion(ADb: Pointer): Integer;
    class function WorkspaceDbPath(const AWsId: string): string;
    class function SanitizeWorkspaceId(const AWsId: string): string;
  public
    class procedure SetConfigRootOverride(const AParentDir: string);
    class procedure ClearConfigRootOverride;
    class function ConfigRoot: string;
    class procedure OpenGlobal;
    class procedure CloseGlobal;
    class procedure OpenWorkspace(const AWsId: string);
    class procedure CloseWorkspace(const AWsId: string);
    class procedure CloseAll;
    class function GlobalSettings: IAppSettingsRepository;
    class function WorkspaceSettings(const AWsId: string): IAppSettingsRepository;
    class function GlobalWorkspaceRegistry: IWorkspaceRegistryRepository;
    class function GlobalLlmSettings: ILlmSettingsRepository;
    class function GlobalPanelLayout: IPanelLayoutRepository;
    class function GlobalWebSearch: IWebSearchRepository;
    class function GlobalBrowserRead: IBrowserReadRepository;
    class function IsGlobalOpen: Boolean;
    class function SchemaVersion(AScope: TAppDatabaseScope; const AWsId: string = ''): Integer;
  end;

implementation

uses
  uSqlite3Embed, uSqliteAppSettingsRepository, uSqliteWorkspaceRegistryRepository,
  uSqliteLlmSettingsRepository, uSqlitePanelLayoutRepository, uSqliteWebSearchRepository,
  uSqliteBrowserReadRepository;

const
  ENV_DATA_ROOT = 'LAZYCODINGAGENT_DATA_ROOT';

var
  GGlobalDb: Pointer = nil;
  GGlobalSettings: IAppSettingsRepository = nil;
  GWorkspaceDbs: TStringList = nil;
  GConfigRootOverride: string = '';

class procedure TAppDatabase.SetConfigRootOverride(const AParentDir: string);
begin
  GConfigRootOverride := IncludeTrailingPathDelimiter(ExpandFileName(AParentDir));
end;

class procedure TAppDatabase.ClearConfigRootOverride;
begin
  GConfigRootOverride := '';
end;

class function TAppDatabase.ConfigRoot: string;
var
  Root: string;
begin
  if GConfigRootOverride <> '' then
    Root := GConfigRootOverride
  else
  begin
    Root := SysUtils.GetEnvironmentVariable(ENV_DATA_ROOT);
    if Root <> '' then
      Root := IncludeTrailingPathDelimiter(ExpandFileName(Root))
    else
      Root := LazarusConfigDir;
  end;
  Result := Root + 'lazycodingagent' + PathDelim;
end;

class function TAppDatabase.LazarusConfigDir: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False));
end;

class function TAppDatabase.SanitizeWorkspaceId(const AWsId: string): string;
var
  I: Integer;
  C: Char;
begin
  if AWsId = '' then
    raise Exception.Create('Workspace id is required');
  for I := 1 to Length(AWsId) do
  begin
    C := AWsId[I];
    if not (C in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_']) then
      raise Exception.Create('Invalid workspace id');
  end;
  Result := AWsId;
end;

class function TAppDatabase.WorkspaceDbPath(const AWsId: string): string;
begin
  Result := ConfigRoot + 'workspaces' + PathDelim + SanitizeWorkspaceId(AWsId) + PathDelim + 'workspace.db';
end;

function SqliteCheck(const ACode: Integer; ADb: PSqlite3; const AContext: string): Integer;
begin
  if ACode <> SQLITE_OK then
    raise Exception.CreateFmt('%s: %s', [AContext, string(sqlite3_errmsg(ADb))]);
  Result := ACode;
end;

class procedure TAppDatabase.ApplyPragmas(ADb: Pointer);
var
  Db: PSqlite3;
  Err: PAnsiChar;
begin
  Db := PSqlite3(ADb);
  Err := nil;
  SqliteCheck(sqlite3_exec(Db, 'PRAGMA journal_mode=WAL;', nil, nil, @Err), Db, 'journal_mode');
  if Err <> nil then sqlite3_free(Err);
  Err := nil;
  SqliteCheck(sqlite3_exec(Db, 'PRAGMA foreign_keys=ON;', nil, nil, @Err), Db, 'foreign_keys');
  if Err <> nil then sqlite3_free(Err);
  Err := nil;
  SqliteCheck(sqlite3_exec(Db, 'PRAGMA busy_timeout=5000;', nil, nil, @Err), Db, 'busy_timeout');
  if Err <> nil then sqlite3_free(Err);
end;

procedure RecordMigration(ADb: PSqlite3; AVersion: Integer);
var
  Err: PAnsiChar;
  AppliedAt: AnsiString;
  Sql: AnsiString;
begin
  AppliedAt := AnsiString(FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now));
  Sql := AnsiString(Format('INSERT INTO schema_migrations(version, applied_at) VALUES(%d, ''%s'');',
    [AVersion, AppliedAt]));
  Err := nil;
  SqliteCheck(sqlite3_exec(ADb, PAnsiChar(Sql), nil, nil, @Err), ADb, 'migration record');
  if Err <> nil then sqlite3_free(Err);
end;

class procedure TAppDatabase.RunMigrations(ADb: Pointer);
var
  Db: PSqlite3;
  Ver: Integer;
  Err: PAnsiChar;
begin
  Db := PSqlite3(ADb);
  Ver := QuerySchemaVersion(ADb);
  if Ver < 1 then
  begin
    Err := nil;
    SqliteCheck(sqlite3_exec(Db,
      'CREATE TABLE schema_migrations (' +
      '  version INTEGER PRIMARY KEY,' +
      '  applied_at TEXT NOT NULL' +
      ');', nil, nil, @Err), Db, 'migration v1 schema_migrations');
    if Err <> nil then sqlite3_free(Err);
    Err := nil;
    SqliteCheck(sqlite3_exec(Db,
      'CREATE TABLE app_settings (' +
      '  key TEXT PRIMARY KEY,' +
      '  value TEXT NOT NULL,' +
      '  type TEXT NOT NULL CHECK (type IN (''string'',''int'',''float'',''bool''))' +
      ');', nil, nil, @Err), Db, 'migration v1 app_settings');
    if Err <> nil then sqlite3_free(Err);
    RecordMigration(Db, 1);
    Ver := 1;
  end;
  if Ver < 2 then
  begin
    Err := nil;
    SqliteCheck(sqlite3_exec(Db,
      'CREATE TABLE workspaces (' +
      '  id TEXT PRIMARY KEY,' +
      '  display_name TEXT NOT NULL,' +
      '  folder_path TEXT NOT NULL UNIQUE,' +
      '  last_session_id TEXT NOT NULL DEFAULT '''',' +
      '  sort_order INTEGER NOT NULL DEFAULT 0' +
      ');', nil, nil, @Err), Db, 'migration v2 workspaces');
    if Err <> nil then sqlite3_free(Err);
    Err := nil;
    SqliteCheck(sqlite3_exec(Db,
      'CREATE TABLE llm_providers (' +
      '  provider_ord INTEGER PRIMARY KEY,' +
      '  api_key TEXT NOT NULL DEFAULT '''',' +
      '  base_url TEXT NOT NULL DEFAULT ''''' +
      ');', nil, nil, @Err), Db, 'migration v2 llm_providers');
    if Err <> nil then sqlite3_free(Err);
    Err := nil;
    SqliteCheck(sqlite3_exec(Db,
      'CREATE TABLE saved_models (' +
      '  provider_ord INTEGER NOT NULL,' +
      '  seq INTEGER NOT NULL,' +
      '  model_id TEXT NOT NULL,' +
      '  display_name TEXT NOT NULL,' +
      '  PRIMARY KEY (provider_ord, seq)' +
      ');', nil, nil, @Err), Db, 'migration v2 saved_models');
    if Err <> nil then sqlite3_free(Err);
    Err := nil;
    SqliteCheck(sqlite3_exec(Db,
      'CREATE TABLE panel_layout (' +
      '  panel_ord INTEGER PRIMARY KEY,' +
      '  visible INTEGER NOT NULL,' +
      '  floating INTEGER NOT NULL,' +
      '  left_pos INTEGER NOT NULL,' +
      '  top_pos INTEGER NOT NULL,' +
      '  width INTEGER NOT NULL,' +
      '  height INTEGER NOT NULL,' +
      '  docked_height INTEGER NOT NULL DEFAULT 0' +
      ');', nil, nil, @Err), Db, 'migration v2 panel_layout');
    if Err <> nil then sqlite3_free(Err);
    Err := nil;
    SqliteCheck(sqlite3_exec(Db,
      'CREATE TABLE web_search_connections (' +
      '  id TEXT PRIMARY KEY,' +
      '  name TEXT NOT NULL,' +
      '  provider TEXT NOT NULL,' +
      '  enabled INTEGER NOT NULL,' +
      '  priority INTEGER NOT NULL,' +
      '  timeout_ms INTEGER NOT NULL,' +
      '  instance_url TEXT NOT NULL DEFAULT '''',' +
      '  tavily_search_depth TEXT NOT NULL DEFAULT ''basic'',' +
      '  custom_header_name TEXT NOT NULL DEFAULT '''',' +
      '  custom_header_value TEXT NOT NULL DEFAULT '''',' +
      '  api_key TEXT NOT NULL DEFAULT ''''' +
      ');', nil, nil, @Err), Db, 'migration v2 web_search_connections');
    if Err <> nil then sqlite3_free(Err);
    RecordMigration(Db, 2);
  end;
end;

class function TAppDatabase.QuerySchemaVersion(ADb: Pointer): Integer;
var
  Db: PSqlite3;
  Stmt: PSqlite3Stmt;
  RC: Integer;
begin
  Result := 0;
  Db := PSqlite3(ADb);
  RC := sqlite3_prepare_v2(Db, 'SELECT MAX(version) FROM schema_migrations', -1, @Stmt, nil);
  if RC = SQLITE_ERROR then
    Exit(0);
  SqliteCheck(RC, Db, 'prepare schema version');
  try
    RC := sqlite3_step(Stmt);
    if RC = SQLITE_ROW then
      Result := sqlite3_column_int(Stmt, 0);
  finally
    sqlite3_finalize(Stmt);
  end;
end;

class function TAppDatabase.OpenDatabaseFile(const AFileName: string): Pointer;
var
  Db: PSqlite3;
  Dir: string;
  Path: AnsiString;
begin
  Dir := ExtractFilePath(AFileName);
  if (Dir <> '') and not DirectoryExists(Dir) then
    ForceDirectories(Dir);
  Path := AnsiString(AFileName);
  SqliteCheck(sqlite3_open_v2(PAnsiChar(Path), @Db, SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE, nil), Db, 'sqlite3_open');
  try
    ApplyPragmas(Db);
    RunMigrations(Db);
  except
    sqlite3_close(Db);
    raise;
  end;
  Result := Db;
end;

class procedure TAppDatabase.CloseDatabaseHandle(var AHandle: Pointer);
begin
  if AHandle = nil then
    Exit;
  sqlite3_close(PSqlite3(AHandle));
  AHandle := nil;
end;

class procedure TAppDatabase.OpenGlobal;
var
  Path: string;
begin
  if GGlobalDb <> nil then
    Exit;
  Path := ConfigRoot + 'global.db';
  GGlobalDb := OpenDatabaseFile(Path);
  GGlobalSettings := TSqliteAppSettingsRepository.Create(PSqlite3(GGlobalDb));
end;

class procedure TAppDatabase.CloseGlobal;
begin
  GGlobalSettings := nil;
  CloseDatabaseHandle(GGlobalDb);
end;

class procedure TAppDatabase.OpenWorkspace(const AWsId: string);
var
  Id: string;
  Idx: Integer;
  Path: string;
  Db: Pointer;
begin
  Id := SanitizeWorkspaceId(AWsId);
  if GWorkspaceDbs = nil then
  begin
    GWorkspaceDbs := TStringList.Create;
    GWorkspaceDbs.Sorted := True;
    GWorkspaceDbs.Duplicates := dupError;
  end;
  Idx := GWorkspaceDbs.IndexOf(Id);
  if Idx >= 0 then
    Exit;
  Path := WorkspaceDbPath(Id);
  Db := OpenDatabaseFile(Path);
  GWorkspaceDbs.AddObject(Id, TObject(Db));
end;

class procedure TAppDatabase.CloseWorkspace(const AWsId: string);
var
  Id: string;
  Idx: Integer;
  Db: Pointer;
begin
  if GWorkspaceDbs = nil then
    Exit;
  Id := SanitizeWorkspaceId(AWsId);
  Idx := GWorkspaceDbs.IndexOf(Id);
  if Idx < 0 then
    Exit;
  Db := Pointer(GWorkspaceDbs.Objects[Idx]);
  GWorkspaceDbs.Delete(Idx);
  CloseDatabaseHandle(Db);
end;

class procedure TAppDatabase.CloseAll;
var
  I: Integer;
  Db: Pointer;
begin
  CloseGlobal;
  if GWorkspaceDbs = nil then
    Exit;
  for I := GWorkspaceDbs.Count - 1 downto 0 do
  begin
    Db := Pointer(GWorkspaceDbs.Objects[I]);
    CloseDatabaseHandle(Db);
  end;
  FreeAndNil(GWorkspaceDbs);
end;

class function TAppDatabase.IsGlobalOpen: Boolean;
begin
  Result := GGlobalDb <> nil;
end;

class function TAppDatabase.GlobalSettings: IAppSettingsRepository;
begin
  if GGlobalSettings = nil then
    raise Exception.Create('Global database is not open');
  Result := GGlobalSettings;
end;

class function TAppDatabase.GlobalWorkspaceRegistry: IWorkspaceRegistryRepository;
begin
  if GGlobalDb = nil then
    raise Exception.Create('Global database is not open');
  Result := TSqliteWorkspaceRegistryRepository.Create(PSqlite3(GGlobalDb));
end;

class function TAppDatabase.GlobalLlmSettings: ILlmSettingsRepository;
begin
  if GGlobalDb = nil then
    raise Exception.Create('Global database is not open');
  Result := TSqliteLlmSettingsRepository.Create(PSqlite3(GGlobalDb));
end;

class function TAppDatabase.GlobalPanelLayout: IPanelLayoutRepository;
begin
  if GGlobalDb = nil then
    raise Exception.Create('Global database is not open');
  Result := TSqlitePanelLayoutRepository.Create(PSqlite3(GGlobalDb));
end;

class function TAppDatabase.GlobalWebSearch: IWebSearchRepository;
begin
  if GGlobalDb = nil then
    raise Exception.Create('Global database is not open');
  Result := TSqliteWebSearchRepository.Create(PSqlite3(GGlobalDb));
end;

class function TAppDatabase.GlobalBrowserRead: IBrowserReadRepository;
begin
  if GGlobalDb = nil then
    raise Exception.Create('Global database is not open');
  Result := TSqliteBrowserReadRepository.Create(PSqlite3(GGlobalDb));
end;

class function TAppDatabase.WorkspaceSettings(const AWsId: string): IAppSettingsRepository;
var
  Id: string;
  Idx: Integer;
begin
  if GWorkspaceDbs = nil then
    raise Exception.Create('Workspace database is not open');
  Id := SanitizeWorkspaceId(AWsId);
  Idx := GWorkspaceDbs.IndexOf(Id);
  if Idx < 0 then
    raise Exception.Create('Workspace database is not open: ' + Id);
  Result := TSqliteAppSettingsRepository.Create(PSqlite3(Pointer(GWorkspaceDbs.Objects[Idx])));
end;

class function TAppDatabase.SchemaVersion(AScope: TAppDatabaseScope; const AWsId: string): Integer;
var
  Idx: Integer;
begin
  case AScope of
    adsGlobal:
      begin
        if GGlobalDb = nil then
          raise Exception.Create('Global database is not open');
        Result := QuerySchemaVersion(GGlobalDb);
      end;
    adsWorkspace:
      begin
        if GWorkspaceDbs = nil then
          raise Exception.Create('Workspace database is not open');
        Idx := GWorkspaceDbs.IndexOf(SanitizeWorkspaceId(AWsId));
        if Idx < 0 then
          raise Exception.Create('Workspace database is not open');
        Result := QuerySchemaVersion(Pointer(GWorkspaceDbs.Objects[Idx]));
      end;
  end;
end;

finalization
  TAppDatabase.CloseAll;

end.
