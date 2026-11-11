unit uWorkspaceState;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uAppTypes, uAgentTypes, uLlmPromptCacheTypes;

type
  TPanelState = record
    Visible: Boolean;
    Floating: Boolean;
    Left: Integer;
    Top: Integer;
    Width: Integer;
    Height: Integer;
    { Docked strip height (terminal bottom panel); 0 = use default at runtime. }
    DockedHeight: Integer;
  end;

  TSavedModel = record
    ModelId: string;
    DisplayName: string;
  end;

  TProviderCredentials = record
    ApiKey: string;
    BaseUrl: string;
    CustomDisplayName: string;
  end;

  TWorkspaceState = class
  private
    FWorkspaceName: string;
    FWorkspaceRoot: string;
    FActiveWorkspaceId: string;
    FNavigation: TNavigationItem;
    FMode: TWorkspaceMode;
    FModel: string;
    FTheme: TThemeKind;

    FProvider: TLlmProvider;
    FApiKey: string;
    FBaseUrl: string;
    FTemperature: Double;
    FMaxTokens: Integer;
    FMaxSteps: Integer;
    FDebuggingMode: Boolean;
    FLearnMode: Boolean;
    FAutoSummarizeContext: Boolean;
    FContextWindowTokens: Integer;
    FSummarizeThreshold: Double;
    FPromptCacheSettings: TPromptCacheSettings;
    FLlmConnectTimeoutMs: Integer;
    FLlmReadTimeoutMs: Integer;
    FLlmHttpRetryCount: Integer;
    FLlmNativeToolCalling: Boolean;
    FLlmTextToolCompat: Boolean;
    FLlmStreamingEnabled: Boolean;

    FProviderCreds: array[TLlmProvider] of TProviderCredentials;
    FProviderModels: array[TLlmProvider] of array of TSavedModel;

    FPanels: array[TPanelId] of TPanelState;
    FOnChange: TNotifyEvent;
    procedure Changed;
    procedure InitProviderDefaults;
    procedure ResetProviderStorage;
    procedure SyncActiveFromProviderSlot;
    procedure SyncActiveToProviderSlot;
    function ModelListHasId(AProv: TLlmProvider; const AModelId: string; ASkipIndex: Integer): Boolean;
  public
    constructor Create;
    procedure ResetLayout;
    procedure SetNavigation(AValue: TNavigationItem);
    procedure SetMode(AValue: TWorkspaceMode);
    procedure SetModel(const AValue: string);
    procedure SetTheme(AValue: TThemeKind);
    procedure SetPanelVisible(AId: TPanelId; AValue: Boolean);
    function IsPanelVisible(AId: TPanelId): Boolean;
    procedure SetPanelFloating(AId: TPanelId; AValue: Boolean);
    function IsPanelFloating(AId: TPanelId): Boolean;
    procedure SetPanelBounds(AId: TPanelId; ALeft, ATop, AWidth, AHeight: Integer);
    function GetPanelBounds(AId: TPanelId; out ALeft, ATop, AWidth, AHeight: Integer): Boolean;
    procedure SetPanelDockedHeight(AId: TPanelId; AHeight: Integer);
    function GetPanelDockedHeight(AId: TPanelId): Integer;
    procedure Load;
    procedure Save;
    procedure LoadFromGlobalDb;
    procedure SaveToGlobalDb;

    procedure GetProviderCredentials(AProv: TLlmProvider; out AApiKey, ABaseUrl: string);
    procedure SetProviderCredentials(AProv: TLlmProvider; const AApiKey, ABaseUrl: string);
    function GetProviderCustomDisplayName(AProv: TLlmProvider): string;
    procedure SetProviderCustomDisplayName(AProv: TLlmProvider; const AName: string);
    function SavedModelCount(AProv: TLlmProvider): Integer;
    function GetSavedModel(AProv: TLlmProvider; AIndex: Integer): TSavedModel;
    procedure SetSavedModels(AProv: TLlmProvider; const AModels: array of TSavedModel);
    function AddSavedModel(AProv: TLlmProvider; const AModelId, ADisplayName: string): Integer;
    function UpdateSavedModel(AProv: TLlmProvider; AIndex: Integer; const AModelId, ADisplayName: string): Boolean;
    procedure DeleteSavedModel(AProv: TLlmProvider; AIndex: Integer);
    function FindSavedModelIndexById(AProv: TLlmProvider; const AModelId: string): Integer;
    procedure CommitActiveProviderCredentials(const AApiKey, ABaseUrl: string);
    procedure ActivateProvider(AProv: TLlmProvider);

    property WorkspaceName: string read FWorkspaceName write FWorkspaceName;
    property WorkspaceRoot: string read FWorkspaceRoot write FWorkspaceRoot;
    property ActiveWorkspaceId: string read FActiveWorkspaceId write FActiveWorkspaceId;
    function HasActiveWorkspace: Boolean;
    property Navigation: TNavigationItem read FNavigation;
    property Mode: TWorkspaceMode read FMode;
    property Model: string read FModel;
    property Theme: TThemeKind read FTheme;

    property Provider: TLlmProvider read FProvider write FProvider;
    property ApiKey: string read FApiKey write FApiKey;
    property BaseUrl: string read FBaseUrl write FBaseUrl;
    property Temperature: Double read FTemperature write FTemperature;
    property MaxTokens: Integer read FMaxTokens write FMaxTokens;
    property MaxSteps: Integer read FMaxSteps write FMaxSteps;
    property DebuggingMode: Boolean read FDebuggingMode write FDebuggingMode;
    property LearnMode: Boolean read FLearnMode write FLearnMode;
    property AutoSummarizeContext: Boolean read FAutoSummarizeContext write FAutoSummarizeContext;
    property ContextWindowTokens: Integer read FContextWindowTokens write FContextWindowTokens;
    property SummarizeThreshold: Double read FSummarizeThreshold write FSummarizeThreshold;
    property PromptCacheSettings: TPromptCacheSettings read FPromptCacheSettings
      write FPromptCacheSettings;
    property LlmConnectTimeoutMs: Integer read FLlmConnectTimeoutMs write FLlmConnectTimeoutMs;
    property LlmReadTimeoutMs: Integer read FLlmReadTimeoutMs write FLlmReadTimeoutMs;
    property LlmHttpRetryCount: Integer read FLlmHttpRetryCount write FLlmHttpRetryCount;
    property LlmNativeToolCalling: Boolean read FLlmNativeToolCalling write FLlmNativeToolCalling;
    property LlmTextToolCompat: Boolean read FLlmTextToolCompat write FLlmTextToolCompat;
    property LlmStreamingEnabled: Boolean read FLlmStreamingEnabled write FLlmStreamingEnabled;

    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

function DefaultBaseUrlForProvider(AProv: TLlmProvider): string;
function LoadPersistedThemeKind: TThemeKind;

implementation

uses
  Forms, uAppDatabase, uRepositoryInterfaces, uGlobalConfigKeys, uAppSettingsCodec,
  uLlmProviderCatalog;

const
  LLM_CONFIG_VERSION = 4;

function LoadPersistedThemeKind: TThemeKind;
var
  OrdVal: Integer;
  Settings: IAppSettingsRepository;
begin
  Result := tkDark;
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  Settings := TAppDatabase.GlobalSettings;
  OrdVal := SettingsTryGetInt(Settings, KEY_APPEARANCE_THEME, Ord(tkDark));
  if (OrdVal >= Ord(Low(TThemeKind))) and (OrdVal <= Ord(High(TThemeKind))) then
    Result := TThemeKind(OrdVal)
  else
    Result := tkDark;
end;

function DefaultBaseUrlForProvider(AProv: TLlmProvider): string;
begin
  Result := LlmProviderDefaultApiBaseUrl(AProv);
end;

function TWorkspaceState.HasActiveWorkspace: Boolean;
begin
  Result := (Trim(FActiveWorkspaceId) <> '') and
    (Trim(FWorkspaceRoot) <> '') and DirectoryExists(FWorkspaceRoot);
end;

constructor TWorkspaceState.Create;
begin
  inherited Create;
  FWorkspaceName := '';
  FWorkspaceRoot := '';
  FActiveWorkspaceId := '';
  FNavigation := niHome;
  FMode := wmAgent;
  FModel := 'anthropic/claude-3.7-sonnet';
  FTheme := tkDark;

  FProvider := lpOpenRouter;
  FApiKey := '';
  FBaseUrl := '';
  FTemperature := 0.2;
  FMaxTokens := DEFAULT_MAX_OUTPUT_TOKENS;
  FMaxSteps := DEFAULT_MAX_AGENT_STEPS;
  FDebuggingMode := False;
  FLearnMode := False;
  FAutoSummarizeContext := True;
  FContextWindowTokens := DEFAULT_CONTEXT_WINDOW_TOKENS;
  FSummarizeThreshold := DEFAULT_SUMMARIZE_THRESHOLD;
  FPromptCacheSettings := DefaultPromptCacheSettings;
  FLlmConnectTimeoutMs := DEFAULT_LLM_CONNECT_TIMEOUT_MS;
  FLlmReadTimeoutMs := DEFAULT_LLM_READ_TIMEOUT_MS;
  FLlmHttpRetryCount := DEFAULT_LLM_HTTP_RETRY_COUNT;
  FLlmNativeToolCalling := True;
  FLlmTextToolCompat := False;
  FLlmStreamingEnabled := False;

  InitProviderDefaults;
  ResetLayout;
end;

procedure TWorkspaceState.InitProviderDefaults;
var
  P: TLlmProvider;
begin
  ResetProviderStorage;
  FProviderCreds[FProvider].ApiKey := FApiKey;
  FProviderCreds[FProvider].BaseUrl := FBaseUrl;
  AddSavedModel(FProvider, FModel, FModel);
end;

procedure TWorkspaceState.ResetProviderStorage;
var
  P: TLlmProvider;
begin
  for P := Low(TLlmProvider) to High(TLlmProvider) do begin
    FProviderCreds[P].ApiKey := '';
    FProviderCreds[P].BaseUrl := DefaultBaseUrlForProvider(P);
    SetLength(FProviderModels[P], 0);
  end;
end;

procedure TWorkspaceState.Changed;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TWorkspaceState.SyncActiveFromProviderSlot;
begin
  FApiKey := FProviderCreds[FProvider].ApiKey;
  FBaseUrl := FProviderCreds[FProvider].BaseUrl;
end;

procedure TWorkspaceState.SyncActiveToProviderSlot;
begin
  FProviderCreds[FProvider].ApiKey := FApiKey;
  FProviderCreds[FProvider].BaseUrl := FBaseUrl;
end;

procedure TWorkspaceState.CommitActiveProviderCredentials(const AApiKey, ABaseUrl: string);
begin
  FApiKey := AApiKey;
  FBaseUrl := ABaseUrl;
  SyncActiveToProviderSlot;
end;

procedure TWorkspaceState.ActivateProvider(AProv: TLlmProvider);
begin
  if FProvider <> AProv then begin
    SyncActiveToProviderSlot;
    FProvider := AProv;
    SyncActiveFromProviderSlot;
  end;
end;

function TWorkspaceState.ModelListHasId(AProv: TLlmProvider; const AModelId: string; ASkipIndex: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FProviderModels[AProv]) do begin
    if I = ASkipIndex then Continue;
    if SameText(FProviderModels[AProv][I].ModelId, AModelId) then begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TWorkspaceState.GetProviderCredentials(AProv: TLlmProvider; out AApiKey, ABaseUrl: string);
begin
  AApiKey := FProviderCreds[AProv].ApiKey;
  ABaseUrl := FProviderCreds[AProv].BaseUrl;
end;

procedure TWorkspaceState.SetProviderCredentials(AProv: TLlmProvider; const AApiKey, ABaseUrl: string);
begin
  FProviderCreds[AProv].ApiKey := AApiKey;
  FProviderCreds[AProv].BaseUrl := Trim(ABaseUrl);
  if AProv = FProvider then
    SyncActiveFromProviderSlot;
end;

function TWorkspaceState.GetProviderCustomDisplayName(AProv: TLlmProvider): string;
begin
  Result := FProviderCreds[AProv].CustomDisplayName;
end;

procedure TWorkspaceState.SetProviderCustomDisplayName(AProv: TLlmProvider; const AName: string);
begin
  FProviderCreds[AProv].CustomDisplayName := Trim(AName);
  if AProv = FProvider then
    SyncActiveFromProviderSlot;
end;

function TWorkspaceState.SavedModelCount(AProv: TLlmProvider): Integer;
begin
  Result := Length(FProviderModels[AProv]);
end;

function TWorkspaceState.GetSavedModel(AProv: TLlmProvider; AIndex: Integer): TSavedModel;
begin
  if (AIndex < 0) or (AIndex > High(FProviderModels[AProv])) then
    raise ERangeError.Create('Saved model index out of range');
  Result := FProviderModels[AProv][AIndex];
end;

procedure TWorkspaceState.SetSavedModels(AProv: TLlmProvider; const AModels: array of TSavedModel);
var
  I: Integer;
begin
  SetLength(FProviderModels[AProv], Length(AModels));
  for I := 0 to High(AModels) do
    FProviderModels[AProv][I] := AModels[I];
end;

function TWorkspaceState.AddSavedModel(AProv: TLlmProvider; const AModelId, ADisplayName: string): Integer;
var
  M: TSavedModel;
  N: Integer;
begin
  Result := -1;
  if Trim(AModelId) = '' then Exit;
  if ModelListHasId(AProv, Trim(AModelId), -1) then Exit;
  M.ModelId := Trim(AModelId);
  if Trim(ADisplayName) <> '' then
    M.DisplayName := Trim(ADisplayName)
  else
    M.DisplayName := M.ModelId;
  N := Length(FProviderModels[AProv]);
  SetLength(FProviderModels[AProv], N + 1);
  FProviderModels[AProv][N] := M;
  Result := N;
end;

function TWorkspaceState.UpdateSavedModel(AProv: TLlmProvider; AIndex: Integer;
  const AModelId, ADisplayName: string): Boolean;
var
  Id: string;
begin
  Result := False;
  if (AIndex < 0) or (AIndex > High(FProviderModels[AProv])) then Exit;
  Id := Trim(AModelId);
  if Id = '' then Exit;
  if ModelListHasId(AProv, Id, AIndex) then Exit;
  if SameText(FModel, FProviderModels[AProv][AIndex].ModelId) then
    FModel := Id;
  FProviderModels[AProv][AIndex].ModelId := Id;
  if Trim(ADisplayName) <> '' then
    FProviderModels[AProv][AIndex].DisplayName := Trim(ADisplayName)
  else
    FProviderModels[AProv][AIndex].DisplayName := Id;
  Result := True;
end;

procedure TWorkspaceState.DeleteSavedModel(AProv: TLlmProvider; AIndex: Integer);
var
  I, N: Integer;
  DeletedId: string;
begin
  if (AIndex < 0) or (AIndex > High(FProviderModels[AProv])) then Exit;
  DeletedId := FProviderModels[AProv][AIndex].ModelId;
  N := Length(FProviderModels[AProv]);
  for I := AIndex to N - 2 do
    FProviderModels[AProv][I] := FProviderModels[AProv][I + 1];
  SetLength(FProviderModels[AProv], N - 1);
  if SameText(FModel, DeletedId) then begin
    if SavedModelCount(AProv) > 0 then
      FModel := FProviderModels[AProv][0].ModelId
    else
      FModel := '';
  end;
end;

function TWorkspaceState.FindSavedModelIndexById(AProv: TLlmProvider; const AModelId: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FProviderModels[AProv]) do begin
    if SameText(FProviderModels[AProv][I].ModelId, AModelId) then begin
      Result := I;
      Exit;
    end;
  end;
end;

procedure TWorkspaceState.ResetLayout;
var
  P: TPanelId;
begin
  for P := Low(TPanelId) to High(TPanelId) do begin
    FPanels[P].Visible := (P in [piNavigation, piChat]);
    FPanels[P].Floating := False;
    FPanels[P].Left := 100 + Ord(P) * 50;
    FPanels[P].Top := 100 + Ord(P) * 50;
    FPanels[P].Width := 500;
    if P = piTerminal then begin
      FPanels[P].Height := 0;
      FPanels[P].DockedHeight := 0;
    end else
      FPanels[P].Height := 600;
    if P <> piTerminal then
      FPanels[P].DockedHeight := 0;
  end;
  Changed;
end;

procedure TWorkspaceState.SetNavigation(AValue: TNavigationItem);
begin
  if FNavigation <> AValue then begin
    FNavigation := AValue;
    Changed;
  end;
end;

procedure TWorkspaceState.SetMode(AValue: TWorkspaceMode);
begin
  if FMode <> AValue then begin
    FMode := AValue;
    Changed;
  end;
end;

procedure TWorkspaceState.SetModel(const AValue: string);
begin
  if FModel <> AValue then begin
    FModel := AValue;
    Changed;
  end;
end;

procedure TWorkspaceState.SetTheme(AValue: TThemeKind);
begin
  if FTheme <> AValue then begin
    FTheme := AValue;
    Changed;
  end;
end;

procedure TWorkspaceState.SetPanelVisible(AId: TPanelId; AValue: Boolean);
begin
  if FPanels[AId].Visible <> AValue then begin
    FPanels[AId].Visible := AValue;
    Changed;
  end;
end;

function TWorkspaceState.IsPanelVisible(AId: TPanelId): Boolean;
begin
  Result := FPanels[AId].Visible;
end;

procedure TWorkspaceState.SetPanelFloating(AId: TPanelId; AValue: Boolean);
begin
  if FPanels[AId].Floating <> AValue then begin
    FPanels[AId].Floating := AValue;
    Changed;
  end;
end;

function TWorkspaceState.IsPanelFloating(AId: TPanelId): Boolean;
begin
  Result := FPanels[AId].Floating;
end;

procedure TWorkspaceState.SetPanelBounds(AId: TPanelId; ALeft, ATop, AWidth, AHeight: Integer);
begin
  FPanels[AId].Left := ALeft;
  FPanels[AId].Top := ATop;
  FPanels[AId].Width := AWidth;
  FPanels[AId].Height := AHeight;
end;

function TWorkspaceState.GetPanelBounds(AId: TPanelId; out ALeft, ATop, AWidth, AHeight: Integer): Boolean;
begin
  ALeft := FPanels[AId].Left;
  ATop := FPanels[AId].Top;
  AWidth := FPanels[AId].Width;
  AHeight := FPanels[AId].Height;
  Result := True;
end;

procedure TWorkspaceState.SetPanelDockedHeight(AId: TPanelId; AHeight: Integer);
begin
  if FPanels[AId].DockedHeight <> AHeight then begin
    FPanels[AId].DockedHeight := AHeight;
    Changed;
  end;
end;

function TWorkspaceState.GetPanelDockedHeight(AId: TPanelId): Integer;
begin
  Result := FPanels[AId].DockedHeight;
end;

procedure TWorkspaceState.Load;
begin
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  LoadFromGlobalDb;
end;

procedure TWorkspaceState.Save;
begin
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  SaveToGlobalDb;
end;

procedure TWorkspaceState.LoadFromGlobalDb;
var
  Settings: IAppSettingsRepository;
  Llm: ILlmSettingsRepository;
  Panels: IPanelLayoutRepository;
  ProvRows: TLlmProviderRows;
  ModelRows: TSavedModelRows;
  PanelRows: TPanelLayoutRows;
  P: TPanelId;
  Prov: TLlmProvider;
  I, J, OrdVal, ActiveOrd: Integer;
  StoredCustomName: string;
begin
  Settings := TAppDatabase.GlobalSettings;
  Llm := TAppDatabase.GlobalLlmSettings;
  Panels := TAppDatabase.GlobalPanelLayout;

  OrdVal := SettingsTryGetInt(Settings, KEY_APPEARANCE_THEME, Ord(FTheme));
  if (OrdVal >= Ord(Low(TThemeKind))) and (OrdVal <= Ord(High(TThemeKind))) then
    FTheme := TThemeKind(OrdVal);
  FMode := TWorkspaceMode(SettingsTryGetInt(Settings, KEY_AGENT_MODE, Ord(FMode)));
  FModel := SettingsTryGetString(Settings, KEY_AGENT_MODEL, FModel);

  ActiveOrd := SettingsTryGetInt(Settings, KEY_LLM_PROVIDER, Ord(FProvider));
  StoredCustomName := SettingsTryGetString(Settings, KEY_LLM_CUSTOM_DISPLAY_NAME, '');

  FTemperature := SettingsTryGetFloat(Settings, KEY_LLM_TEMPERATURE, FTemperature);
  FMaxTokens := SettingsTryGetInt(Settings, KEY_LLM_MAX_TOKENS, FMaxTokens);
  FMaxSteps := SettingsTryGetInt(Settings, KEY_LLM_MAX_STEPS, FMaxSteps);
  FDebuggingMode := SettingsTryGetBool(Settings, KEY_GENERAL_DEBUGGING, FDebuggingMode);
  FLearnMode := SettingsTryGetBool(Settings, KEY_GENERAL_LEARN, FLearnMode);
  FAutoSummarizeContext := SettingsTryGetBool(Settings, KEY_GENERAL_AUTO_SUMMARIZE, FAutoSummarizeContext);
  FContextWindowTokens := SettingsTryGetInt(Settings, KEY_LLM_CONTEXT_WINDOW, FContextWindowTokens);
  FSummarizeThreshold := SettingsTryGetFloat(Settings, KEY_LLM_SUMMARIZE_THRESHOLD, FSummarizeThreshold);
  FLlmConnectTimeoutMs := ClampLlmConnectTimeoutMs(SettingsTryGetInt(Settings,
    KEY_LLM_CONNECT_TIMEOUT_MS, DEFAULT_LLM_CONNECT_TIMEOUT_MS));
  FLlmReadTimeoutMs := ClampLlmReadTimeoutMs(SettingsTryGetInt(Settings,
    KEY_LLM_READ_TIMEOUT_MS, DEFAULT_LLM_READ_TIMEOUT_MS));
  FLlmHttpRetryCount := ClampLlmHttpRetryCount(SettingsTryGetInt(Settings,
    KEY_LLM_HTTP_RETRY_COUNT, DEFAULT_LLM_HTTP_RETRY_COUNT));
  FLlmNativeToolCalling := SettingsTryGetBool(Settings, KEY_LLM_NATIVE_TOOL_CALLING, True);
  FLlmTextToolCompat := SettingsTryGetBool(Settings, KEY_LLM_TEXT_TOOL_COMPAT, False);
  FLlmStreamingEnabled := SettingsTryGetBool(Settings, KEY_LLM_STREAMING_ENABLED, False);

  FPromptCacheSettings.Mode := TPromptCacheMode(SettingsTryGetInt(Settings, KEY_PROMPT_CACHE_MODE,
    Ord(FPromptCacheSettings.Mode)));
  FPromptCacheSettings.Retention := TPromptCacheRetention(SettingsTryGetInt(Settings, KEY_PROMPT_CACHE_RETENTION,
    Ord(FPromptCacheSettings.Retention)));
  FPromptCacheSettings.CacheSystemInstructions := SettingsTryGetBool(Settings, KEY_PROMPT_CACHE_SYSTEM,
    FPromptCacheSettings.CacheSystemInstructions);
  FPromptCacheSettings.CacheToolDefinitions := SettingsTryGetBool(Settings, KEY_PROMPT_CACHE_TOOLS,
    FPromptCacheSettings.CacheToolDefinitions);
  FPromptCacheSettings.CacheProjectContext := SettingsTryGetBool(Settings, KEY_PROMPT_CACHE_PROJECT,
    FPromptCacheSettings.CacheProjectContext);
  FPromptCacheSettings.CacheConversationHistory := SettingsTryGetBool(Settings, KEY_PROMPT_CACHE_HISTORY,
    FPromptCacheSettings.CacheConversationHistory);

  ResetProviderStorage;
  Llm.LoadProviders(ProvRows);
  Llm.LoadModels(ModelRows);

  if (ActiveOrd >= Ord(Low(TLlmProvider))) and (ActiveOrd <= Ord(High(TLlmProvider))) then
    FProvider := TLlmProvider(ActiveOrd);
  for I := 0 to High(ProvRows) do
    if (ProvRows[I].ProviderOrd >= Ord(Low(TLlmProvider))) and
       (ProvRows[I].ProviderOrd <= Ord(High(TLlmProvider))) then
    begin
      Prov := TLlmProvider(ProvRows[I].ProviderOrd);
      FProviderCreds[Prov].ApiKey := ProvRows[I].ApiKey;
      FProviderCreds[Prov].BaseUrl := ProvRows[I].BaseUrl;
      if Trim(FProviderCreds[Prov].BaseUrl) = '' then
        FProviderCreds[Prov].BaseUrl := LlmProviderDefaultApiBaseUrl(Prov);
    end;
  for I := 0 to High(ModelRows) do
    if (ModelRows[I].ProviderOrd >= Ord(Low(TLlmProvider))) and
       (ModelRows[I].ProviderOrd <= Ord(High(TLlmProvider))) then
    begin
      Prov := TLlmProvider(ModelRows[I].ProviderOrd);
      J := Length(FProviderModels[Prov]);
      SetLength(FProviderModels[Prov], J + 1);
      FProviderModels[Prov][J].ModelId := ModelRows[I].ModelId;
      FProviderModels[Prov][J].DisplayName := ModelRows[I].DisplayName;
    end;
  if Trim(StoredCustomName) <> '' then
    FProviderCreds[lpCustom].CustomDisplayName := Trim(StoredCustomName);

  SyncActiveFromProviderSlot;

  Panels.LoadAll(PanelRows);
  if Length(PanelRows) = 0 then
    ResetLayout
  else
    for P := Low(TPanelId) to High(TPanelId) do
      for I := 0 to High(PanelRows) do
        if PanelRows[I].PanelOrd = Ord(P) then
        begin
          FPanels[P].Visible := PanelRows[I].Visible;
          FPanels[P].Floating := PanelRows[I].Floating;
          FPanels[P].Left := PanelRows[I].LeftPos;
          FPanels[P].Top := PanelRows[I].TopPos;
          FPanels[P].Width := PanelRows[I].Width;
          FPanels[P].Height := PanelRows[I].Height;
          FPanels[P].DockedHeight := PanelRows[I].DockedHeight;
          Break;
        end;
end;

procedure TWorkspaceState.SaveToGlobalDb;
var
  Settings: IAppSettingsRepository;
  Llm: ILlmSettingsRepository;
  Panels: IPanelLayoutRepository;
  ProvRows: TLlmProviderRows;
  ModelRows: TSavedModelRows;
  PanelRows: TPanelLayoutRows;
  P: TPanelId;
  Prov: TLlmProvider;
  I, J, N: Integer;
begin
  SyncActiveToProviderSlot;
  Settings := TAppDatabase.GlobalSettings;
  SettingsSetInt(Settings, KEY_APPEARANCE_THEME, Ord(FTheme));
  SettingsSetInt(Settings, KEY_AGENT_MODE, Ord(FMode));
  SettingsSetString(Settings, KEY_AGENT_MODEL, FModel);
  SettingsSetInt(Settings, KEY_LLM_CONFIG_VERSION, LLM_CONFIG_VERSION);
  SettingsSetInt(Settings, KEY_LLM_PROVIDER, Ord(FProvider));
  SettingsSetString(Settings, KEY_LLM_CUSTOM_DISPLAY_NAME, FProviderCreds[lpCustom].CustomDisplayName);
  SettingsSetFloat(Settings, KEY_LLM_TEMPERATURE, FTemperature);
  SettingsSetInt(Settings, KEY_LLM_MAX_TOKENS, FMaxTokens);
  SettingsSetInt(Settings, KEY_LLM_MAX_STEPS, FMaxSteps);
  SettingsSetBool(Settings, KEY_GENERAL_DEBUGGING, FDebuggingMode);
  SettingsSetBool(Settings, KEY_GENERAL_LEARN, FLearnMode);
  SettingsSetBool(Settings, KEY_GENERAL_AUTO_SUMMARIZE, FAutoSummarizeContext);
  SettingsSetInt(Settings, KEY_LLM_CONTEXT_WINDOW, FContextWindowTokens);
  SettingsSetFloat(Settings, KEY_LLM_SUMMARIZE_THRESHOLD, FSummarizeThreshold);
  SettingsSetInt(Settings, KEY_LLM_CONNECT_TIMEOUT_MS, ClampLlmConnectTimeoutMs(FLlmConnectTimeoutMs));
  SettingsSetInt(Settings, KEY_LLM_READ_TIMEOUT_MS, ClampLlmReadTimeoutMs(FLlmReadTimeoutMs));
  SettingsSetInt(Settings, KEY_LLM_HTTP_RETRY_COUNT, ClampLlmHttpRetryCount(FLlmHttpRetryCount));
  SettingsSetBool(Settings, KEY_LLM_NATIVE_TOOL_CALLING, FLlmNativeToolCalling);
  SettingsSetBool(Settings, KEY_LLM_TEXT_TOOL_COMPAT, FLlmTextToolCompat);
  SettingsSetBool(Settings, KEY_LLM_STREAMING_ENABLED, FLlmStreamingEnabled);

  SettingsSetInt(Settings, KEY_PROMPT_CACHE_MODE, Ord(FPromptCacheSettings.Mode));
  SettingsSetInt(Settings, KEY_PROMPT_CACHE_RETENTION, Ord(FPromptCacheSettings.Retention));
  SettingsSetBool(Settings, KEY_PROMPT_CACHE_SYSTEM, FPromptCacheSettings.CacheSystemInstructions);
  SettingsSetBool(Settings, KEY_PROMPT_CACHE_TOOLS, FPromptCacheSettings.CacheToolDefinitions);
  SettingsSetBool(Settings, KEY_PROMPT_CACHE_PROJECT, FPromptCacheSettings.CacheProjectContext);
  SettingsSetBool(Settings, KEY_PROMPT_CACHE_HISTORY, FPromptCacheSettings.CacheConversationHistory);

  N := Ord(High(TLlmProvider)) - Ord(Low(TLlmProvider)) + 1;
  SetLength(ProvRows, N);
  I := 0;
  for Prov := Low(TLlmProvider) to High(TLlmProvider) do
  begin
    ProvRows[I].ProviderOrd := Ord(Prov);
    ProvRows[I].ApiKey := FProviderCreds[Prov].ApiKey;
    ProvRows[I].BaseUrl := FProviderCreds[Prov].BaseUrl;
    Inc(I);
  end;
  Llm := TAppDatabase.GlobalLlmSettings;
  Llm.SaveProviders(ProvRows);

  SetLength(ModelRows, 0);
  for Prov := Low(TLlmProvider) to High(TLlmProvider) do
    for J := 0 to High(FProviderModels[Prov]) do
    begin
      N := Length(ModelRows);
      SetLength(ModelRows, N + 1);
      ModelRows[N].ProviderOrd := Ord(Prov);
      ModelRows[N].Seq := J;
      ModelRows[N].ModelId := FProviderModels[Prov][J].ModelId;
      ModelRows[N].DisplayName := FProviderModels[Prov][J].DisplayName;
    end;
  Llm.SaveModels(ModelRows);

  SetLength(PanelRows, Ord(High(TPanelId)) - Ord(Low(TPanelId)) + 1);
  for P := Low(TPanelId) to High(TPanelId) do
  begin
    I := Ord(P) - Ord(Low(TPanelId));
    PanelRows[I].PanelOrd := Ord(P);
    PanelRows[I].Visible := FPanels[P].Visible;
    PanelRows[I].Floating := FPanels[P].Floating;
    PanelRows[I].LeftPos := FPanels[P].Left;
    PanelRows[I].TopPos := FPanels[P].Top;
    PanelRows[I].Width := FPanels[P].Width;
    PanelRows[I].Height := FPanels[P].Height;
    PanelRows[I].DockedHeight := FPanels[P].DockedHeight;
  end;
  Panels := TAppDatabase.GlobalPanelLayout;
  Panels.SaveAll(PanelRows);
end;

end.
