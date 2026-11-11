unit uSqliteAppSettingsRepository;

{$mode ObjFPC}{$H+}

interface

uses
  uRepositoryInterfaces, uSqlite3Embed;

type
  TSqliteAppSettingsRepository = class(TInterfacedObject, IAppSettingsRepository)
  private
    FDb: PSqlite3;
  public
    constructor Create(ADb: PSqlite3);
    function TryGet(const AKey: string; out AValue: string): Boolean;
    procedure SetString(const AKey, AValue: string);
  end;

implementation

uses
  SysUtils, Classes, uSqliteCheck;

constructor TSqliteAppSettingsRepository.Create(ADb: PSqlite3);
begin
  inherited Create;
  if ADb = nil then
    raise Exception.Create('TSqliteAppSettingsRepository requires an open database');
  FDb := ADb;
end;

function TSqliteAppSettingsRepository.TryGet(const AKey: string; out AValue: string): Boolean;
var
  Stmt: PSqlite3Stmt;
  RC: Integer;
  P: PAnsiChar;
begin
  AValue := '';
  Result := False;
  RC := sqlite3_prepare_v2(FDb, 'SELECT value FROM app_settings WHERE key = ?1', -1, @Stmt, nil);
  SqliteCheck(RC, FDb, 'prepare app_settings get');
  try
    SqliteCheck(sqlite3_bind_text(Stmt, 1, PAnsiChar(AnsiString(AKey)), -1, SQLITE_TRANSIENT), FDb, 'bind key');
    RC := sqlite3_step(Stmt);
    if RC = SQLITE_ROW then
    begin
      P := sqlite3_column_text(Stmt, 0);
      if P <> nil then
        AValue := string(P);
      Result := True;
    end
    else if RC <> SQLITE_DONE then
      SqliteCheck(RC, FDb, 'step app_settings get');
  finally
    sqlite3_finalize(Stmt);
  end;
end;

procedure TSqliteAppSettingsRepository.SetString(const AKey, AValue: string);
var
  Stmt: PSqlite3Stmt;
  RC: Integer;
begin
  SqliteCheck(sqlite3_prepare_v2(FDb,
    'INSERT INTO app_settings(key, value, type) VALUES(?1, ?2, ''string'') ' +
    'ON CONFLICT(key) DO UPDATE SET value = excluded.value, type = ''string''', -1, @Stmt, nil), FDb, 'prepare app_settings set');
  try
    SqliteCheck(sqlite3_bind_text(Stmt, 1, PAnsiChar(AnsiString(AKey)), -1, SQLITE_TRANSIENT), FDb, 'bind key');
    SqliteCheck(sqlite3_bind_text(Stmt, 2, PAnsiChar(AnsiString(AValue)), -1, SQLITE_TRANSIENT), FDb, 'bind value');
    RC := sqlite3_step(Stmt);
    if RC <> SQLITE_DONE then
      SqliteCheck(RC, FDb, 'step app_settings set');
  finally
    sqlite3_finalize(Stmt);
  end;
end;

end.
