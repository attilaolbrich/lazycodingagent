unit uChatSessionHub;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uAppTypes, uAgentTypes, uAgentTools, uAgentEngine, uChatSessionStore,
  uAgentExecutionLog, uAgentToolErrorLog, uLlmPromptCacheTypes, uLlmToolCalling;

type
  THubStateChangeEvent = procedure(Sender: TObject; const ASessionId: string;
    AOldState, ANewState: TAgentState; AStep, AMaxSteps: Integer) of object;
  THubMessageEvent = procedure(Sender: TObject; const ASessionId: string;
    const AMessage: TChatMessage) of object;
  THubToolCallEvent = procedure(Sender: TObject; const ASessionId: string;
    const AToolName, AArgs: string) of object;
  THubToolResultEvent = procedure(Sender: TObject; const ASessionId: string;
    const AToolName, AArgsJson: string; const AResult: TToolExecutionResult) of object;
  THubExecutionLogEvent = procedure(Sender: TObject; const ASessionId: string;
    AEntryIndex: Integer) of object;
  THubToolErrorLogEvent = procedure(Sender: TObject; const ASessionId: string;
    AEntryIndex: Integer) of object;

  TSessionRuntime = class
  public
    SessionId: string;
    Engine: TAgentEngine;
    ExecutionLog: TAgentExecutionLog;
    ToolErrorLog: TAgentToolErrorLog;
    constructor Create(const ASessionId, AWorkspaceId, AWorkspaceRoot: string);
    destructor Destroy; override;
  end;

  TChatSessionHub = class
  private
    FWorkspaceId: string;
    FWorkspaceRoot: string;
    FStore: TChatSessionStore;
    FRuntimes: array of TSessionRuntime;
    FOnStateChange: THubStateChangeEvent;
    FOnMessageAdded: THubMessageEvent;
    FOnToolCall: THubToolCallEvent;
    FOnToolResult: THubToolResultEvent;
    FOnExecutionLogAdded: THubExecutionLogEvent;
    FOnToolErrorAdded: THubToolErrorLogEvent;
    function IndexOfRuntime(const ASessionId: string): Integer;
    function IndexOfEngine(AEngine: TAgentEngine): Integer;
    procedure WireEngine(ARuntime: TSessionRuntime);
    procedure UnwireEngine(AEngine: TAgentEngine);
    procedure EngineStateChange(Sender: TObject; AOldState, ANewState: TAgentState;
      AStep, AMaxSteps: Integer);
    procedure EngineMessageAdded(Sender: TObject; const AMessage: TChatMessage);
    procedure EngineToolCall(Sender: TObject; const AToolName, AArgs: string);
    procedure EngineToolResult(Sender: TObject; const AToolName, AArgsJson: string;
      const AResult: TToolExecutionResult);
    procedure EngineExecutionLogAdded(Sender: TObject; AEntryIndex: Integer);
    procedure EngineToolErrorAdded(Sender: TObject; AEntryIndex: Integer);
  public
    constructor Create(const AWorkspaceId, AWorkspaceRoot: string);
    destructor Destroy; override;

    procedure SetWorkspaceRoot(const ARoot: string);
    procedure ApplyClientSettings(AProvider: TLlmProvider; const AApiKey, ABaseUrl, AModel: string;
      ATemperature: Double; AMaxTokens, AMaxSteps: Integer; AAutoSummarizeContext: Boolean;
      AContextWindowTokens: Integer; ASummarizeThreshold: Double;
      AConnectTimeoutMs, AReadTimeoutMs, AHttpRetryCount: Integer;
      const APromptCacheSettings: TPromptCacheSettings;
      const AToolCallingCaps: TLlmToolCallingCapabilities; ALearnWireLogging: Boolean);

    function EngineFor(const ASessionId: string): TAgentEngine;
    function ExecutionLogFor(const ASessionId: string): TAgentExecutionLog;
    function ToolErrorLogFor(const ASessionId: string): TAgentToolErrorLog;
    function GetOrCreateEngine(const ASessionId: string): TAgentEngine;
    function HasEngine(const ASessionId: string): Boolean;
    function IsSessionRunning(const ASessionId: string): Boolean;
    function AnyRunActive: Boolean;

    procedure SaveSessionToStore(const ASessionId: string);
    procedure SaveAll;
    procedure RemoveSession(const ASessionId: string);
    procedure Shutdown(ACancelRuns: Boolean);

    property WorkspaceId: string read FWorkspaceId;
    property WorkspaceRoot: string read FWorkspaceRoot;
    property Store: TChatSessionStore read FStore;

    property OnStateChange: THubStateChangeEvent read FOnStateChange write FOnStateChange;
    property OnMessageAdded: THubMessageEvent read FOnMessageAdded write FOnMessageAdded;
    property OnToolCall: THubToolCallEvent read FOnToolCall write FOnToolCall;
    property OnToolResult: THubToolResultEvent read FOnToolResult write FOnToolResult;
    property OnExecutionLogAdded: THubExecutionLogEvent read FOnExecutionLogAdded
      write FOnExecutionLogAdded;
    property OnToolErrorAdded: THubToolErrorLogEvent read FOnToolErrorAdded
      write FOnToolErrorAdded;
  end;

  TChatSessionHubManager = class
  private
    FHubs: TStringList;
    function FindHubIndex(const AWorkspaceId: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function GetOrCreate(const AWorkspaceId, AWorkspaceRoot: string): TChatSessionHub;
    function FindHub(const AWorkspaceId: string): TChatSessionHub;
    procedure RemoveHub(const AWorkspaceId: string; ACancelRuns: Boolean;
      ADeleteSessionStore: Boolean = True);
    procedure ShutdownAll(ACancelRuns: Boolean);
    function AnyRunActive: Boolean;
    function Count: Integer;
    function HubAt(AIndex: Integer): TChatSessionHub;
  end;

implementation

uses
  uChatContextManager;

{ TSessionRuntime }

constructor TSessionRuntime.Create(const ASessionId, AWorkspaceId, AWorkspaceRoot: string);
begin
  inherited Create;
  SessionId := ASessionId;
  ExecutionLog := TAgentExecutionLog.Create;
  ToolErrorLog := TAgentToolErrorLog.Create(ASessionId, AWorkspaceId, AWorkspaceRoot);
  Engine := TAgentEngine.Create(AWorkspaceRoot);
  Engine.ExecutionLog := ExecutionLog;
  Engine.ToolErrorLog := ToolErrorLog;
end;

destructor TSessionRuntime.Destroy;
begin
  if Assigned(Engine) then begin
    Engine.OnStateChange := nil;
    Engine.OnMessageAdded := nil;
    Engine.OnToolCall := nil;
    Engine.OnToolResult := nil;
    Engine.OnExecutionLogAdded := nil;
    Engine.OnToolErrorAdded := nil;
    Engine.ExecutionLog := nil;
    Engine.ToolErrorLog := nil;
    Engine.Free;
  end;
  ExecutionLog.Free;
  ToolErrorLog.Free;
  inherited Destroy;
end;

{ TChatSessionHub }

constructor TChatSessionHub.Create(const AWorkspaceId, AWorkspaceRoot: string);
begin
  inherited Create;
  FWorkspaceId := AWorkspaceId;
  FWorkspaceRoot := AWorkspaceRoot;
  FStore := TChatSessionStore.Create;
  FStore.BindWorkspace(AWorkspaceId);
end;

destructor TChatSessionHub.Destroy;
begin
  Shutdown(True);
  FStore.Free;
  inherited Destroy;
end;

function TChatSessionHub.IndexOfRuntime(const ASessionId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FRuntimes) do
    if SameText(FRuntimes[I].SessionId, ASessionId) then
      Exit(I);
  Result := -1;
end;

function TChatSessionHub.IndexOfEngine(AEngine: TAgentEngine): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FRuntimes) do
    if FRuntimes[I].Engine = AEngine then
      Exit(I);
  Result := -1;
end;

procedure TChatSessionHub.WireEngine(ARuntime: TSessionRuntime);
begin
  ARuntime.Engine.OnStateChange := @EngineStateChange;
  ARuntime.Engine.OnMessageAdded := @EngineMessageAdded;
  ARuntime.Engine.OnToolCall := @EngineToolCall;
  ARuntime.Engine.OnToolResult := @EngineToolResult;
  ARuntime.Engine.OnExecutionLogAdded := @EngineExecutionLogAdded;
  ARuntime.Engine.OnToolErrorAdded := @EngineToolErrorAdded;
end;

procedure TChatSessionHub.UnwireEngine(AEngine: TAgentEngine);
begin
  if not Assigned(AEngine) then Exit;
  AEngine.OnStateChange := nil;
  AEngine.OnMessageAdded := nil;
  AEngine.OnToolCall := nil;
  AEngine.OnToolResult := nil;
  AEngine.OnExecutionLogAdded := nil;
  AEngine.OnToolErrorAdded := nil;
end;

procedure TChatSessionHub.EngineStateChange(Sender: TObject; AOldState, ANewState: TAgentState;
  AStep, AMaxSteps: Integer);
var
  Idx: Integer;
  Sid: string;
begin
  Idx := IndexOfEngine(TAgentEngine(Sender));
  if Idx < 0 then Exit;
  Sid := FRuntimes[Idx].SessionId;
  if Assigned(FOnStateChange) then
    FOnStateChange(Self, Sid, AOldState, ANewState, AStep, AMaxSteps);
  if ANewState in [asIdle, asFinished, asError] then
    SaveSessionToStore(Sid);
end;

procedure TChatSessionHub.EngineMessageAdded(Sender: TObject; const AMessage: TChatMessage);
var
  Idx: Integer;
  Sid: string;
begin
  Idx := IndexOfEngine(TAgentEngine(Sender));
  if Idx < 0 then Exit;
  Sid := FRuntimes[Idx].SessionId;
  if Assigned(FOnMessageAdded) then
    FOnMessageAdded(Self, Sid, AMessage);
end;

procedure TChatSessionHub.EngineToolCall(Sender: TObject; const AToolName, AArgs: string);
var
  Idx: Integer;
begin
  Idx := IndexOfEngine(TAgentEngine(Sender));
  if Idx < 0 then Exit;
  if Assigned(FOnToolCall) then
    FOnToolCall(Self, FRuntimes[Idx].SessionId, AToolName, AArgs);
end;

procedure TChatSessionHub.EngineToolResult(Sender: TObject; const AToolName, AArgsJson: string;
  const AResult: TToolExecutionResult);
var
  Idx: Integer;
begin
  Idx := IndexOfEngine(TAgentEngine(Sender));
  if Idx < 0 then Exit;
  if Assigned(FOnToolResult) then
    FOnToolResult(Self, FRuntimes[Idx].SessionId, AToolName, AArgsJson, AResult);
end;

procedure TChatSessionHub.EngineExecutionLogAdded(Sender: TObject; AEntryIndex: Integer);
var
  Idx: Integer;
begin
  Idx := IndexOfEngine(TAgentEngine(Sender));
  if Idx < 0 then Exit;
  if Assigned(FOnExecutionLogAdded) then
    FOnExecutionLogAdded(Self, FRuntimes[Idx].SessionId, AEntryIndex);
end;

procedure TChatSessionHub.EngineToolErrorAdded(Sender: TObject; AEntryIndex: Integer);
var
  Idx: Integer;
begin
  Idx := IndexOfEngine(TAgentEngine(Sender));
  if Idx < 0 then Exit;
  if Assigned(FOnToolErrorAdded) then
    FOnToolErrorAdded(Self, FRuntimes[Idx].SessionId, AEntryIndex);
end;

function TChatSessionHub.ExecutionLogFor(const ASessionId: string): TAgentExecutionLog;
var
  Idx: Integer;
begin
  Idx := IndexOfRuntime(ASessionId);
  if Idx < 0 then
    Result := nil
  else
    Result := FRuntimes[Idx].ExecutionLog;
end;

function TChatSessionHub.ToolErrorLogFor(const ASessionId: string): TAgentToolErrorLog;
var
  Idx: Integer;
begin
  Idx := IndexOfRuntime(ASessionId);
  if Idx < 0 then
    Result := nil
  else
    Result := FRuntimes[Idx].ToolErrorLog;
end;

procedure TChatSessionHub.SetWorkspaceRoot(const ARoot: string);
var
  I: Integer;
begin
  FWorkspaceRoot := ARoot;
  for I := 0 to High(FRuntimes) do
    FRuntimes[I].Engine.Context.WorkspaceRoot := ARoot;
end;

procedure TChatSessionHub.ApplyClientSettings(AProvider: TLlmProvider; const AApiKey, ABaseUrl, AModel: string;
  ATemperature: Double; AMaxTokens, AMaxSteps: Integer; AAutoSummarizeContext: Boolean;
  AContextWindowTokens: Integer; ASummarizeThreshold: Double;
  AConnectTimeoutMs, AReadTimeoutMs, AHttpRetryCount: Integer;
  const APromptCacheSettings: TPromptCacheSettings;
  const AToolCallingCaps: TLlmToolCallingCapabilities; ALearnWireLogging: Boolean);
var
  I: Integer;
  E: TAgentEngine;
begin
  for I := 0 to High(FRuntimes) do begin
    E := FRuntimes[I].Engine;
    E.Client.Provider := AProvider;
    E.Client.ApiKey := AApiKey;
    E.Client.BaseUrl := ABaseUrl;
    E.Client.Model := AModel;
    E.Client.Temperature := ATemperature;
    E.Client.MaxTokens := ClampMaxOutputTokens(AMaxTokens);
    E.Client.ConnectTimeoutMs := AConnectTimeoutMs;
    E.Client.ReadTimeoutMs := AReadTimeoutMs;
    E.Client.HttpRetryCount := AHttpRetryCount;
    E.Client.ToolCallingCapabilities := AToolCallingCaps;
    E.Client.LearnWireLogging := ALearnWireLogging;
    E.ToolCallingCapabilities := AToolCallingCaps;
    E.LearnWireLogging := ALearnWireLogging;
    E.MaxSteps := AMaxSteps;
    E.AutoSummarizeContext := AAutoSummarizeContext;
    E.ContextWindowTokens := AContextWindowTokens;
    E.SummarizeThreshold := ASummarizeThreshold;
    E.PromptCacheSettings := APromptCacheSettings;
    E.Client.PromptCacheSettings := APromptCacheSettings;
    E.Context.WorkspaceRoot := FWorkspaceRoot;
  end;
end;

function TChatSessionHub.EngineFor(const ASessionId: string): TAgentEngine;
var
  Idx: Integer;
begin
  Idx := IndexOfRuntime(ASessionId);
  if Idx < 0 then
    Result := nil
  else
    Result := FRuntimes[Idx].Engine;
end;

function TChatSessionHub.GetOrCreateEngine(const ASessionId: string): TAgentEngine;
var
  Idx: Integer;
  Rt: TSessionRuntime;
  Msgs: TChatMessageArray;
begin
  Idx := IndexOfRuntime(ASessionId);
  if Idx >= 0 then
    Exit(FRuntimes[Idx].Engine);

  Rt := TSessionRuntime.Create(ASessionId, FWorkspaceId, FWorkspaceRoot);
  WireEngine(Rt);
  SetLength(FRuntimes, Length(FRuntimes) + 1);
  FRuntimes[High(FRuntimes)] := Rt;

  if FStore.LoadSessionMessages(ASessionId, Msgs) then
    Rt.Engine.LoadConversation(Msgs);

  Result := Rt.Engine;
end;

function TChatSessionHub.HasEngine(const ASessionId: string): Boolean;
begin
  Result := IndexOfRuntime(ASessionId) >= 0;
end;

function TChatSessionHub.IsSessionRunning(const ASessionId: string): Boolean;
var
  E: TAgentEngine;
begin
  E := EngineFor(ASessionId);
  Result := Assigned(E) and E.IsRunActive;
end;

function TChatSessionHub.AnyRunActive: Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FRuntimes) do
    if FRuntimes[I].Engine.IsRunActive then
      Exit(True);
  Result := False;
end;

procedure TChatSessionHub.SaveSessionToStore(const ASessionId: string);
var
  E: TAgentEngine;
  Msgs: TChatMessageArray;
begin
  if ASessionId = '' then Exit;
  E := EngineFor(ASessionId);
  if not Assigned(E) then Exit;
  E.ExportMessages(Msgs);
  FStore.SaveSessionMessages(ASessionId, Msgs);
end;

procedure TChatSessionHub.SaveAll;
var
  I: Integer;
begin
  for I := 0 to High(FRuntimes) do
    SaveSessionToStore(FRuntimes[I].SessionId);
end;

procedure TChatSessionHub.RemoveSession(const ASessionId: string);
var
  Idx: Integer;
begin
  Idx := IndexOfRuntime(ASessionId);
  if Idx < 0 then Exit;
  FRuntimes[Idx].Engine.RequestCancel;
  FRuntimes[Idx].Free;
  if Idx < High(FRuntimes) then
    Move(FRuntimes[Idx + 1], FRuntimes[Idx], (High(FRuntimes) - Idx) * SizeOf(Pointer));
  SetLength(FRuntimes, Length(FRuntimes) - 1);
end;

procedure TChatSessionHub.Shutdown(ACancelRuns: Boolean);
var
  I: Integer;
begin
  for I := High(FRuntimes) downto 0 do begin
    if ACancelRuns then
      FRuntimes[I].Engine.RequestCancel;
    UnwireEngine(FRuntimes[I].Engine);
    FRuntimes[I].Free;
  end;
  SetLength(FRuntimes, 0);
end;

{ TChatSessionHubManager }

constructor TChatSessionHubManager.Create;
begin
  inherited Create;
  FHubs := TStringList.Create;
  FHubs.OwnsObjects := True;
  FHubs.Sorted := True;
  FHubs.Duplicates := dupError;
end;

destructor TChatSessionHubManager.Destroy;
begin
  ShutdownAll(True);
  FHubs.Free;
  inherited Destroy;
end;

function TChatSessionHubManager.FindHubIndex(const AWorkspaceId: string): Integer;
begin
  Result := FHubs.IndexOf(AWorkspaceId);
end;

function TChatSessionHubManager.GetOrCreate(const AWorkspaceId, AWorkspaceRoot: string): TChatSessionHub;
var
  Hub: TChatSessionHub;
  Idx: Integer;
begin
  Idx := FindHubIndex(AWorkspaceId);
  if Idx >= 0 then begin
    Hub := TChatSessionHub(FHubs.Objects[Idx]);
    Hub.SetWorkspaceRoot(AWorkspaceRoot);
    Exit(Hub);
  end;
  Hub := TChatSessionHub.Create(AWorkspaceId, AWorkspaceRoot);
  FHubs.AddObject(AWorkspaceId, Hub);
  Result := Hub;
end;

function TChatSessionHubManager.FindHub(const AWorkspaceId: string): TChatSessionHub;
var
  Idx: Integer;
begin
  Idx := FindHubIndex(AWorkspaceId);
  if Idx < 0 then
    Result := nil
  else
    Result := TChatSessionHub(FHubs.Objects[Idx]);
end;

procedure TChatSessionHubManager.RemoveHub(const AWorkspaceId: string; ACancelRuns: Boolean;
  ADeleteSessionStore: Boolean);
var
  Idx: Integer;
  Hub: TChatSessionHub;
begin
  Idx := FindHubIndex(AWorkspaceId);
  if Idx < 0 then Exit;
  Hub := TChatSessionHub(FHubs.Objects[Idx]);
  Hub.Shutdown(ACancelRuns);
  if ADeleteSessionStore then
    Hub.Store.DeleteAllForWorkspace(AWorkspaceId);
  FHubs.Delete(Idx);
end;

procedure TChatSessionHubManager.ShutdownAll(ACancelRuns: Boolean);
var
  I: Integer;
begin
  for I := FHubs.Count - 1 downto 0 do begin
    TChatSessionHub(FHubs.Objects[I]).Shutdown(ACancelRuns);
    FHubs.Delete(I);
  end;
end;

function TChatSessionHubManager.AnyRunActive: Boolean;
var
  I: Integer;
begin
  for I := 0 to FHubs.Count - 1 do
    if TChatSessionHub(FHubs.Objects[I]).AnyRunActive then
      Exit(True);
  Result := False;
end;

function TChatSessionHubManager.Count: Integer;
begin
  Result := FHubs.Count;
end;

function TChatSessionHubManager.HubAt(AIndex: Integer): TChatSessionHub;
begin
  Result := TChatSessionHub(FHubs.Objects[AIndex]);
end;

end.
