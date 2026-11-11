unit uSqliteLlmSettingsRepository;

{$mode ObjFPC}{$H+}

interface

uses
  uRepositoryInterfaces, uSqlite3Embed;

type
  TSqliteLlmSettingsRepository = class(TInterfacedObject, ILlmSettingsRepository)
  private
    FDb: PSqlite3;
  public
    constructor Create(ADb: PSqlite3);
    procedure LoadProviders(out ARows: TLlmProviderRows);
    procedure SaveProviders(const ARows: TLlmProviderRows);
    procedure LoadModels(out ARows: TSavedModelRows);
    procedure SaveModels(const ARows: TSavedModelRows);
  end;

implementation

uses
  SysUtils, uSqliteCheck, uSecurityManager;

constructor TSqliteLlmSettingsRepository.Create(ADb: PSqlite3);
begin
  inherited Create;
  if ADb = nil then
    raise Exception.Create('TSqliteLlmSettingsRepository requires an open database');
  FDb := ADb;
end;

procedure TSqliteLlmSettingsRepository.LoadProviders(out ARows: TLlmProviderRows);
var
  Stmt: PSqlite3Stmt;
  N: Integer;
  P: PAnsiChar;
  StoredKey: string;
begin
  SetLength(ARows, 0);
  SqliteCheck(sqlite3_prepare_v2(FDb,
    'SELECT provider_ord, api_key, base_url FROM llm_providers ORDER BY provider_ord', -1, @Stmt, nil),
    FDb, 'prepare llm_providers load');
  try
    N := 0;
    while sqlite3_step(Stmt) = SQLITE_ROW do
    begin
      SetLength(ARows, N + 1);
      ARows[N].ProviderOrd := sqlite3_column_int(Stmt, 0);
      P := sqlite3_column_text(Stmt, 1);
      if P <> nil then StoredKey := string(P) else StoredKey := '';
      if StoredKey = '' then
        ARows[N].ApiKey := ''
      else if IsEncryptedSecretBlob(StoredKey) then
        ARows[N].ApiKey := DecryptSecret(StoredKey)
      else
        ARows[N].ApiKey := StoredKey;
      P := sqlite3_column_text(Stmt, 2);
      if P <> nil then ARows[N].BaseUrl := string(P) else ARows[N].BaseUrl := '';
      Inc(N);
    end;
  finally
    sqlite3_finalize(Stmt);
  end;
end;

procedure TSqliteLlmSettingsRepository.SaveProviders(const ARows: TLlmProviderRows);
var
  Stmt: PSqlite3Stmt;
  I: Integer;
  Err: PAnsiChar;
  EncKey: string;
begin
  Err := nil;
  SqliteCheck(sqlite3_exec(FDb, 'DELETE FROM llm_providers;', nil, nil, @Err), FDb, 'clear llm_providers');
  if Err <> nil then sqlite3_free(Err);
  SqliteCheck(sqlite3_prepare_v2(FDb,
    'INSERT INTO llm_providers(provider_ord, api_key, base_url) VALUES(?1,?2,?3)', -1, @Stmt, nil),
    FDb, 'prepare llm_providers save');
  try
    for I := 0 to High(ARows) do
    begin
      if Trim(ARows[I].ApiKey) = '' then
        EncKey := ''
      else
        EncKey := EncryptSecret(ARows[I].ApiKey);
      SqliteCheck(sqlite3_bind_int(Stmt, 1, ARows[I].ProviderOrd), FDb, 'bind ord');
      SqliteCheck(sqlite3_bind_text(Stmt, 2, PAnsiChar(AnsiString(EncKey)), -1, SQLITE_TRANSIENT), FDb, 'bind key');
      SqliteCheck(sqlite3_bind_text(Stmt, 3, PAnsiChar(AnsiString(ARows[I].BaseUrl)), -1, SQLITE_TRANSIENT), FDb, 'bind url');
      SqliteStepDone(sqlite3_step(Stmt), FDb, 'step llm_providers save');
      SqliteCheck(sqlite3_reset(Stmt), FDb, 'reset llm_providers save');
    end;
  finally
    sqlite3_finalize(Stmt);
  end;
end;

procedure TSqliteLlmSettingsRepository.LoadModels(out ARows: TSavedModelRows);
var
  Stmt: PSqlite3Stmt;
  N: Integer;
  P: PAnsiChar;
begin
  SetLength(ARows, 0);
  SqliteCheck(sqlite3_prepare_v2(FDb,
    'SELECT provider_ord, seq, model_id, display_name FROM saved_models ORDER BY provider_ord, seq',
    -1, @Stmt, nil), FDb, 'prepare saved_models load');
  try
    N := 0;
    while sqlite3_step(Stmt) = SQLITE_ROW do
    begin
      SetLength(ARows, N + 1);
      ARows[N].ProviderOrd := sqlite3_column_int(Stmt, 0);
      ARows[N].Seq := sqlite3_column_int(Stmt, 1);
      P := sqlite3_column_text(Stmt, 2);
      if P <> nil then ARows[N].ModelId := string(P) else ARows[N].ModelId := '';
      P := sqlite3_column_text(Stmt, 3);
      if P <> nil then ARows[N].DisplayName := string(P) else ARows[N].DisplayName := '';
      Inc(N);
    end;
  finally
    sqlite3_finalize(Stmt);
  end;
end;

procedure TSqliteLlmSettingsRepository.SaveModels(const ARows: TSavedModelRows);
var
  Stmt: PSqlite3Stmt;
  I: Integer;
  Err: PAnsiChar;
begin
  Err := nil;
  SqliteCheck(sqlite3_exec(FDb, 'DELETE FROM saved_models;', nil, nil, @Err), FDb, 'clear saved_models');
  if Err <> nil then sqlite3_free(Err);
  SqliteCheck(sqlite3_prepare_v2(FDb,
    'INSERT INTO saved_models(provider_ord, seq, model_id, display_name) VALUES(?1,?2,?3,?4)',
    -1, @Stmt, nil), FDb, 'prepare saved_models save');
  try
    for I := 0 to High(ARows) do
    begin
      SqliteCheck(sqlite3_bind_int(Stmt, 1, ARows[I].ProviderOrd), FDb, 'bind ord');
      SqliteCheck(sqlite3_bind_int(Stmt, 2, ARows[I].Seq), FDb, 'bind seq');
      SqliteCheck(sqlite3_bind_text(Stmt, 3, PAnsiChar(AnsiString(ARows[I].ModelId)), -1, SQLITE_TRANSIENT), FDb, 'bind id');
      SqliteCheck(sqlite3_bind_text(Stmt, 4, PAnsiChar(AnsiString(ARows[I].DisplayName)), -1, SQLITE_TRANSIENT), FDb, 'bind name');
      SqliteStepDone(sqlite3_step(Stmt), FDb, 'step saved_models save');
      SqliteCheck(sqlite3_reset(Stmt), FDb, 'reset saved_models save');
    end;
  finally
    sqlite3_finalize(Stmt);
  end;
end;

end.
