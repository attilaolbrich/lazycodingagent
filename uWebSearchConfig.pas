unit uWebSearchConfig;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uWebSearchTypes;

function LoadWebSearchConfig: TWebSearchGlobalConfig;
procedure SaveWebSearchConfig(const AConfig: TWebSearchGlobalConfig);
function WebSearchHasUsableConnection(const AConfig: TWebSearchGlobalConfig): Boolean;
function WebSearchIsToolAvailable: Boolean;
function ConnectionIsConfigured(const AConn: TWebSearchConnection): Boolean; overload;
function ConnectionIsConfigured(const AConn: TWebSearchConnection;
  AAllowPrivateInstances: Boolean): Boolean; overload;
function NewWebSearchConnectionId: string;
procedure SortConnectionsByPriority(var AConnections: array of TWebSearchConnection);
procedure SetWebSearchConfigOverrideForTests(const AConfig: TWebSearchGlobalConfig);
procedure ClearWebSearchConfigOverrideForTests;
procedure SaveWebSearchConfigToGlobalDb(const AConfig: TWebSearchGlobalConfig);

implementation

uses
  Classes, uWebSearchSecrets, uWebSearchUrl, uAppDatabase, uRepositoryInterfaces,
  uGlobalConfigKeys, uAppSettingsCodec;

var
  GTestConfigOverride: TWebSearchGlobalConfig;
  GTestConfigOverrideActive: Boolean = False;

procedure LoadWebSearchConfigFromGlobalDb(out Result: TWebSearchGlobalConfig); forward;

procedure SetWebSearchConfigOverrideForTests(const AConfig: TWebSearchGlobalConfig);
begin
  GTestConfigOverride := AConfig;
  GTestConfigOverrideActive := True;
end;

procedure ClearWebSearchConfigOverrideForTests;
begin
  GTestConfigOverrideActive := False;
end;

function NewWebSearchConnectionId: string;
var
  G: TGUID;
begin
  CreateGUID(G);
  Result := GUIDToString(G);
  Result := StringReplace(Result, '{', '', [rfReplaceAll]);
  Result := StringReplace(Result, '}', '', [rfReplaceAll]);
end;

function LoadWebSearchConfig: TWebSearchGlobalConfig;
begin
  if GTestConfigOverrideActive then
    Exit(GTestConfigOverride);
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  LoadWebSearchConfigFromGlobalDb(Result);
end;

procedure SaveWebSearchConfig(const AConfig: TWebSearchGlobalConfig);
begin
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  SaveWebSearchConfigToGlobalDb(AConfig);
end;

procedure LoadWebSearchConfigFromGlobalDb(out Result: TWebSearchGlobalConfig);
var
  Settings: IAppSettingsRepository;
  Repo: IWebSearchRepository;
  Rows: TWebSearchConnectionRows;
  I: Integer;
  Conn: TWebSearchConnection;
  KindStr: string;
begin
  Result := DefaultWebSearchGlobalConfig;
  Settings := TAppDatabase.GlobalSettings;
  Result.ConfigVersion := SettingsTryGetInt(Settings, KEY_WEBSEARCH_CONFIG_VERSION, WEB_SEARCH_CONFIG_VERSION);
  Result.Enabled := SettingsTryGetBool(Settings, KEY_WEBSEARCH_ENABLED, False);
  Result.MaxResults := SettingsTryGetInt(Settings, KEY_WEBSEARCH_MAX_RESULTS, WEB_SEARCH_DEFAULT_MAX_RESULTS);
  if Result.MaxResults < 1 then Result.MaxResults := 1;
  if Result.MaxResults > 50 then Result.MaxResults := 50;
  Result.TotalTimeoutMs := SettingsTryGetInt(Settings, KEY_WEBSEARCH_TOTAL_TIMEOUT, WEB_SEARCH_DEFAULT_TOTAL_TIMEOUT_MS);
  if Result.TotalTimeoutMs < 1000 then Result.TotalTimeoutMs := 1000;
  Result.AutomaticFallback := SettingsTryGetBool(Settings, KEY_WEBSEARCH_AUTO_FALLBACK, True);
  Result.FallbackOnEmptyResults := SettingsTryGetBool(Settings, KEY_WEBSEARCH_FALLBACK_EMPTY, False);
  Result.AllowPrivateInstances := SettingsTryGetBool(Settings, KEY_WEBSEARCH_ALLOW_PRIVATE, False);
  Repo := TAppDatabase.GlobalWebSearch;
  Repo.LoadConnections(Rows);
  SetLength(Result.Connections, Length(Rows));
  for I := 0 to High(Rows) do
  begin
    Conn.Id := Rows[I].Id;
    Conn.Name := Rows[I].Name;
    KindStr := Rows[I].Provider;
    if not ParseWebSearchProviderKind(KindStr, Conn.Kind) then
      Conn.Kind := wspkBrave;
    Conn.Enabled := Rows[I].Enabled;
    Conn.Priority := Rows[I].Priority;
    Conn.TimeoutMs := Rows[I].TimeoutMs;
    if Conn.TimeoutMs < 1000 then Conn.TimeoutMs := 1000;
    Conn.InstanceUrl := Rows[I].InstanceUrl;
    Conn.TavilySearchDepth := Rows[I].TavilySearchDepth;
    Conn.CustomHeaderName := Rows[I].CustomHeaderName;
    Conn.CustomHeaderValue := Rows[I].CustomHeaderValue;
    Result.Connections[I] := Conn;
  end;
  SortConnectionsByPriority(Result.Connections);
end;

procedure SaveWebSearchConfigToGlobalDb(const AConfig: TWebSearchGlobalConfig);
var
  Settings: IAppSettingsRepository;
  Repo: IWebSearchRepository;
  Rows: TWebSearchConnectionRows;
  I: Integer;
  Key: string;
begin
  Settings := TAppDatabase.GlobalSettings;
  SettingsSetInt(Settings, KEY_WEBSEARCH_CONFIG_VERSION, WEB_SEARCH_CONFIG_VERSION);
  SettingsSetBool(Settings, KEY_WEBSEARCH_ENABLED, AConfig.Enabled);
  SettingsSetInt(Settings, KEY_WEBSEARCH_MAX_RESULTS, AConfig.MaxResults);
  SettingsSetInt(Settings, KEY_WEBSEARCH_TOTAL_TIMEOUT, AConfig.TotalTimeoutMs);
  SettingsSetBool(Settings, KEY_WEBSEARCH_AUTO_FALLBACK, AConfig.AutomaticFallback);
  SettingsSetBool(Settings, KEY_WEBSEARCH_FALLBACK_EMPTY, AConfig.FallbackOnEmptyResults);
  SettingsSetBool(Settings, KEY_WEBSEARCH_ALLOW_PRIVATE, AConfig.AllowPrivateInstances);
  SetLength(Rows, Length(AConfig.Connections));
  for I := 0 to High(AConfig.Connections) do
  begin
    Rows[I].Id := AConfig.Connections[I].Id;
    Rows[I].Name := AConfig.Connections[I].Name;
    Rows[I].Provider := WebSearchProviderKindToString(AConfig.Connections[I].Kind);
    Rows[I].Enabled := AConfig.Connections[I].Enabled;
    Rows[I].Priority := AConfig.Connections[I].Priority;
    Rows[I].TimeoutMs := AConfig.Connections[I].TimeoutMs;
    Rows[I].InstanceUrl := AConfig.Connections[I].InstanceUrl;
    Rows[I].TavilySearchDepth := AConfig.Connections[I].TavilySearchDepth;
    Rows[I].CustomHeaderName := AConfig.Connections[I].CustomHeaderName;
    Rows[I].CustomHeaderValue := AConfig.Connections[I].CustomHeaderValue;
    Key := GetWebSearchApiKey(AConfig.Connections[I].Id);
    Rows[I].ApiKey := Key;
  end;
  Repo := TAppDatabase.GlobalWebSearch;
  Repo.SaveConnections(Rows);
end;

function ConnectionIsConfigured(const AConn: TWebSearchConnection): Boolean;
begin
  Result := ConnectionIsConfigured(AConn, False);
end;

function ConnectionIsConfigured(const AConn: TWebSearchConnection;
  AAllowPrivateInstances: Boolean): Boolean;
var
  Base: string;
  Err: string;
begin
  case AConn.Kind of
    wspkBrave, wspkTavily:
      Result := WebSearchApiKeyIsSet(AConn.Id);
    wspkSearxng:
      Result := ValidateSearxngInstanceUrl(AConn.InstanceUrl,
        AAllowPrivateInstances or WebSearchTrustedLocalAllowed(), Base, Err);
  else
    Result := False;
  end;
end;

function WebSearchHasUsableConnection(const AConfig: TWebSearchGlobalConfig): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AConfig.Connections) do
    if AConfig.Connections[I].Enabled and
      ConnectionIsConfigured(AConfig.Connections[I], AConfig.AllowPrivateInstances) then
      Exit(True);
  Result := False;
end;

function WebSearchIsToolAvailable: Boolean;
var
  Cfg: TWebSearchGlobalConfig;
begin
  Cfg := LoadWebSearchConfig;
  Result := Cfg.Enabled and WebSearchHasUsableConnection(Cfg);
end;

procedure SortConnectionsByPriority(var AConnections: array of TWebSearchConnection);
var
  I, J, Best: Integer;
  Tmp: TWebSearchConnection;
begin
  for I := Low(AConnections) to High(AConnections) - 1 do
  begin
    Best := I;
    for J := I + 1 to High(AConnections) do
      if (AConnections[J].Priority < AConnections[Best].Priority) or
        ((AConnections[J].Priority = AConnections[Best].Priority) and
         (CompareText(AConnections[J].Id, AConnections[Best].Id) < 0)) then
        Best := J;
    if Best <> I then
    begin
      Tmp := AConnections[I];
      AConnections[I] := AConnections[Best];
      AConnections[Best] := Tmp;
    end;
  end;
end;

end.
