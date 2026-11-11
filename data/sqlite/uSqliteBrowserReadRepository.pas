unit uSqliteBrowserReadRepository;

{$mode ObjFPC}{$H+}

interface

uses
  uRepositoryInterfaces, uSqlite3Embed;

type
  TSqliteBrowserReadRepository = class(TInterfacedObject, IBrowserReadRepository)
  private
    FDb: PSqlite3;
    FSettings: IAppSettingsRepository;
  public
    constructor Create(ADb: PSqlite3);
    function LoadExecutablePath: string;
    procedure SaveExecutablePath(const APath: string);
    function LoadMaxConcurrent: Integer;
    procedure SaveMaxConcurrent(AValue: Integer);
    function LoadMaxSessions: Integer;
    procedure SaveMaxSessions(AValue: Integer);
    function LoadIdleTimeoutMs: Integer;
    procedure SaveIdleTimeoutMs(AValue: Integer);
  end;

implementation

uses
  SysUtils, uSqliteAppSettingsRepository, uGlobalConfigKeys, uAppSettingsCodec,
  uBrowserReadTypes;

constructor TSqliteBrowserReadRepository.Create(ADb: PSqlite3);
begin
  inherited Create;
  if ADb = nil then
    raise Exception.Create('TSqliteBrowserReadRepository requires an open database');
  FDb := ADb;
  FSettings := TSqliteAppSettingsRepository.Create(FDb);
end;

function TSqliteBrowserReadRepository.LoadExecutablePath: string;
begin
  Result := Trim(SettingsTryGetString(FSettings, KEY_BROWSER_EXECUTABLE, ''));
end;

procedure TSqliteBrowserReadRepository.SaveExecutablePath(const APath: string);
begin
  SettingsSetString(FSettings, KEY_BROWSER_EXECUTABLE, Trim(APath));
end;

function TSqliteBrowserReadRepository.LoadMaxConcurrent: Integer;
begin
  Result := SettingsTryGetInt(FSettings, KEY_BROWSER_MAX_CONCURRENT, BROWSER_READ_DEFAULT_MAX_CONCURRENT);
end;

procedure TSqliteBrowserReadRepository.SaveMaxConcurrent(AValue: Integer);
begin
  SettingsSetInt(FSettings, KEY_BROWSER_MAX_CONCURRENT, AValue);
end;

function TSqliteBrowserReadRepository.LoadMaxSessions: Integer;
begin
  Result := SettingsTryGetInt(FSettings, KEY_BROWSER_MAX_SESSIONS, BROWSER_DEFAULT_MAX_SESSIONS);
end;

procedure TSqliteBrowserReadRepository.SaveMaxSessions(AValue: Integer);
begin
  SettingsSetInt(FSettings, KEY_BROWSER_MAX_SESSIONS, AValue);
end;

function TSqliteBrowserReadRepository.LoadIdleTimeoutMs: Integer;
begin
  Result := SettingsTryGetInt(FSettings, KEY_BROWSER_IDLE_TIMEOUT, BROWSER_DEFAULT_IDLE_TIMEOUT_MS);
end;

procedure TSqliteBrowserReadRepository.SaveIdleTimeoutMs(AValue: Integer);
begin
  SettingsSetInt(FSettings, KEY_BROWSER_IDLE_TIMEOUT, AValue);
end;

end.
