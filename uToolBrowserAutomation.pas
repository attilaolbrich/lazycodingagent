unit uToolBrowserAutomation;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAppTypes, uAgentTypes, uAgentToolBase, uBrowserReadTypes,
  uBrowserManager;

type
  TBrowserToolBase = class(TAgentTool)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
  protected
    function Config: TBrowserReadConfig;
    function GetSession(const SessionId: string; out S: TBrowserManagedSession;
      out Err: string): Boolean;
    function DenyInteractive: TToolExecutionResult;
    function DenySensitive(const Action: string): TToolExecutionResult;
    function DenyAutomationPaused(S: TBrowserManagedSession): TToolExecutionResult;
    function JsonOk(O: TJSONObject): TToolExecutionResult;
    function JsonErr(const Code, Msg: string): TToolExecutionResult;
  end;

  TToolBrowserNavigate = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserInspect = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserClick = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserFill = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserWait = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserClose = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserScreenshot = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserConsole = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserNetwork = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserSelect = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserSetViewport = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserResumeAutomation = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

  TToolBrowserPauseAutomation = class(TBrowserToolBase)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

implementation

uses
  Math, uBrowserReadConfig, uBrowserAutomation,
  uBrowserPageInspector, uBrowserInputController, uBrowserWait, uBrowserScreenshot,
  uBrowserPermissions, uBrowserReadUrl, uChatImageStore, uToolArtifactStore;

type
  TBrowserCancelAdapter = class
  private
    FContext: TAgentToolContext;
  public
    constructor Create(AContext: TAgentToolContext);
    function Check: Boolean;
  end;

constructor TBrowserCancelAdapter.Create(AContext: TAgentToolContext);
begin
  inherited Create;
  FContext := AContext;
end;

function TBrowserCancelAdapter.Check: Boolean;
begin
  Result := Assigned(FContext) and FContext.IsCancelled;
end;

constructor TBrowserToolBase.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  AllowedModes := [wmAsk, wmPlan, wmAgent];
  MutatesFiles := False;
end;

function TBrowserToolBase.Config: TBrowserReadConfig;
begin
  Result := LoadBrowserReadConfig;
  if FContext.AllowBrowserLocalhost then
    Result.AllowLocalhost := True;
end;

function TBrowserToolBase.GetSession(const SessionId: string;
  out S: TBrowserManagedSession; out Err: string): Boolean;
begin
  S := BrowserSessionFind(SessionId);
  if S = nil then
  begin
    Err := 'Unknown browser session: ' + SessionId;
    Exit(False);
  end;
  if (FContext.ChatSessionId <> '') and (S.ChatSessionId <> '') and
     not SameText(FContext.ChatSessionId, S.ChatSessionId) then
  begin
    Err := 'Session belongs to another chat';
    Exit(False);
  end;
  Result := True;
end;

function TBrowserToolBase.DenyInteractive: TToolExecutionResult;
begin
  Result := JsonErr('ACCESS_DENIED',
    'Enable interactive browser actions for this chat session');
end;

function TBrowserToolBase.DenySensitive(const Action: string): TToolExecutionResult;
begin
  Result := JsonErr('USER_DENIED', 'User denied sensitive browser action: ' + Action);
end;

function TBrowserToolBase.DenyAutomationPaused(S: TBrowserManagedSession): TToolExecutionResult;
begin
  Result := JsonErr('AUTOMATION_PAUSED',
    'Automation is paused for this visible session; call browser_resume_automation when the user is ready');
end;

function TBrowserToolBase.JsonOk(O: TJSONObject): TToolExecutionResult;
begin
  O.Add('success', True);
  Result := ToolResultFromJson(O.AsJSON);
  O.Free;
end;

function TBrowserToolBase.JsonErr(const Code, Msg: string): TToolExecutionResult;
var
  O: TJSONObject;
begin
  O := TJSONObject.Create;
  O.Add('success', False);
  O.Add('error', Msg);
  O.Add('error_code', Code);
  Result := ToolResultFromJson(O.AsJSON);
  O.Free;
end;

constructor TToolBrowserNavigate.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserNavigate.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_navigate';
  Result.Description :=
    'Navigate a browser session to a URL. Creates a session when session_id is omitted. ' +
    'Set visible true on a new session to open a window the user can see and interact with ' +
    '(manual login, paired UX review); reuse session_id for later browser_* steps. ' +
    'Prefer default headless for routine automated checks.';
  SetLength(Result.Params, 6);
  Result.Params[0].Name := 'url';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description :=
    'HTTP or HTTPS URL, or file:/// path to a file or folder inside the active workspace.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'session_id';
  Result.Params[1].ParamType := 'string';
  Result.Params[1].Description := 'Existing browser session id; omit to create a new session.';
  Result.Params[2].Name := 'wait_strategy';
  Result.Params[2].ParamType := 'string';
  Result.Params[2].Description := 'domcontentloaded, load (default), or selector.';
  Result.Params[3].Name := 'wait_selector';
  Result.Params[3].ParamType := 'string';
  Result.Params[3].Description := 'CSS selector when wait_strategy is selector.';
  Result.Params[4].Name := 'timeout_ms';
  Result.Params[4].ParamType := 'integer';
  Result.Params[4].Description := 'Navigation timeout in milliseconds (default 30000).';
  Result.Params[5].Name := 'visible';
  Result.Params[5].ParamType := 'boolean';
  Result.Params[5].Description :=
    'When creating a new session, open a visible browser window (default false). ' +
    'Ignored when session_id is set.';
end;

function TToolBrowserNavigate.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Url, Sid, WaitSel, FinalUrl, Title: string;
  Strategy: TBrowserReadWaitStrategy;
  TimeoutMs: Integer;
  Visible: Boolean;
  HadExistingSession: Boolean;
  CreatedNewSession: Boolean;
  Succeeded: Boolean;
  S: TBrowserManagedSession;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg, Err: string;
  O: TJSONObject;
  Adapter: TBrowserCancelAdapter;
  Cfg: TBrowserReadConfig;
begin
  Url := Args.Get('url', '');
  if Trim(Url) = '' then
    Exit(JsonErr('INVALID_ARGUMENT', 'url is required'));
  Sid := Args.Get('session_id', '');
  HadExistingSession := Sid <> '';
  Visible := Args.Get('visible', False);
  if (Sid <> '') and Visible then
    Exit(JsonErr('INVALID_ARGUMENT',
      'visible applies only when creating a session (omit session_id)'));
  if not ParseBrowserReadWaitStrategy(Args.Get('wait_strategy', 'load'), Strategy) then
    Exit(JsonErr('INVALID_ARGUMENT', 'invalid wait_strategy'));
  WaitSel := Args.Get('wait_selector', '');
  TimeoutMs := Args.Get('timeout_ms', BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS);
  Cfg := Config;
  Adapter := TBrowserCancelAdapter.Create(FContext);
  CreatedNewSession := False;
  Succeeded := False;
  try
    if Sid = '' then
    begin
      if not ValidateBrowserReadUrl(Url, Cfg.AllowLocalhost or FContext.AllowBrowserLocalhost,
        FContext.WorkspaceRoot, ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
      if (Pos('127.0.0.1', LowerCase(Url)) > 0) or (Pos('localhost', LowerCase(Url)) > 0) then
        if not FContext.AllowBrowserLocalhost and not Cfg.AllowLocalhost then
          Exit(JsonErr('ACCESS_DENIED', 'Localhost browsing requires permission'));
      if not BrowserSessionCreate(FContext.WorkspaceRoot, FContext.ChatSessionId,
        FContext.AllowBrowserLocalhost or Cfg.AllowLocalhost, Visible, Cfg,
        @Adapter.Check, S, ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
      CreatedNewSession := True;
      Sid := S.Id;
    end
    else if not GetSession(Sid, S, Err) then
      Exit(JsonErr('SESSION_NOT_FOUND', Err));

    if HadExistingSession and S.Visible and S.AutomationPaused then
      Exit(DenyAutomationPaused(S));

    S.Lock.Enter;
    try
      if not BrowserAutomationNavigate(S, Url, Strategy, WaitSel, TimeoutMs, @Adapter.Check,
        FinalUrl, Title, ErrKind, ErrMsg) then
      begin
        Result := JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg);
        Exit;
      end;
    finally
      S.Lock.Leave;
    end;

    O := TJSONObject.Create;
    O.Add('session_id', Sid);
    O.Add('url', FinalUrl);
    O.Add('title', Title);
    O.Add('visible', S.Visible);
    O.Add('automation_paused', S.AutomationPaused);
    O.Add('status', 'ok');
    Succeeded := True;
    Result := JsonOk(O);
  finally
    if CreatedNewSession and not Succeeded and (Sid <> '') then
      BrowserSessionClose(Sid, @Adapter.Check);
    Adapter.Free;
  end;
end;

constructor TToolBrowserInspect.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserInspect.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_inspect';
  Result.Description := 'Inspect the current browser page (title, URL, elements, links, forms).';
  SetLength(Result.Params, 7);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Browser session id.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'selector';
  Result.Params[1].ParamType := 'string';
  Result.Params[1].Description := 'Optional CSS selector to inspect one element.';
  Result.Params[2].Name := 'include_links';
  Result.Params[2].ParamType := 'boolean';
  Result.Params[2].Description := 'Include link list (default true).';
  Result.Params[3].Name := 'include_forms';
  Result.Params[3].ParamType := 'boolean';
  Result.Params[3].Description := 'Include forms and fields (default true).';
  Result.Params[4].Name := 'include_accessibility';
  Result.Params[4].ParamType := 'boolean';
  Result.Params[4].Description := 'Include accessibility notes when supported.';
  Result.Params[5].Name := 'max_length';
  Result.Params[5].ParamType := 'integer';
  Result.Params[5].Description := 'Max visible text characters (default 20000).';
  Result.Params[6].Name := 'timeout_ms';
  Result.Params[6].ParamType := 'integer';
  Result.Params[6].Description := 'Operation timeout in milliseconds (default 30000).';
end;

function TToolBrowserInspect.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  O: TJSONObject;
  Adapter: TBrowserCancelAdapter;
begin
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    S.Lock.Enter;
    try
      O := BrowserInspectPage(S, Args.Get('selector', ''),
        Args.Get('include_links', True), Args.Get('include_forms', True),
        Args.Get('include_accessibility', False),
        Args.Get('max_length', BROWSER_READ_DEFAULT_MAX_LENGTH),
        Args.Get('timeout_ms', BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS), @Adapter.Check);
    finally
      S.Lock.Leave;
    end;
    Result := JsonOk(O);
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserClick.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserClick.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_click';
  Result.Description := 'Click an element via CDP pointer events.';
  SetLength(Result.Params, 5);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Browser session id.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'selector';
  Result.Params[1].ParamType := 'string';
  Result.Params[1].Description := 'CSS selector for the element to click.';
  Result.Params[1].Required := True;
  Result.Params[2].Name := 'timeout_ms';
  Result.Params[2].ParamType := 'integer';
  Result.Params[2].Description := 'Wait timeout in milliseconds (default 30000).';
  Result.Params[3].Name := 'click_count';
  Result.Params[3].ParamType := 'integer';
  Result.Params[3].Description := 'Number of clicks (default 1).';
  Result.Params[4].Name := 'ref';
  Result.Params[4].ParamType := 'string';
  Result.Params[4].Description := 'Element ref from browser_inspect instead of selector.';
end;

function TToolBrowserClick.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
  Adapter: TBrowserCancelAdapter;
  AllowSession: Boolean;
  Sel, Ref: string;
  O: TJSONObject;
begin
  if not FContext.AllowBrowserInteractive then
    Exit(DenyInteractive);
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  if S.Visible and S.AutomationPaused then
    Exit(DenyAutomationPaused(S));
  Sel := Args.Get('selector', '');
  Ref := Args.Get('ref', '');
  if BrowserActionLooksSensitive(Sel, Ref) and not FContext.AllowBrowserSensitive then
  begin
    AllowSession := False;
    if not RequestBrowserSensitiveConfirm('Allow clicking: ' + Sel + '?', AllowSession) then
      Exit(DenySensitive('click'));
    if AllowSession then
      FContext.AllowBrowserSensitive := True;
  end;
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    S.Lock.Enter;
    try
      if not BrowserClickElement(S, Sel, Ref, Args.Get('timeout_ms',
        BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS), Args.Get('click_count', 1),
        @Adapter.Check, ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
    finally
      S.Lock.Leave;
    end;
    O := TJSONObject.Create;
    O.Add('session_id', S.Id);
    O.Add('status', 'clicked');
    Result := JsonOk(O);
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserFill.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserFill.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_fill';
  Result.Description := 'Fill an input or textarea (password values are not logged).';
  SetLength(Result.Params, 6);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Browser session id.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'selector';
  Result.Params[1].ParamType := 'string';
  Result.Params[1].Description := 'CSS selector for the input or textarea.';
  Result.Params[1].Required := True;
  Result.Params[2].Name := 'value';
  Result.Params[2].ParamType := 'string';
  Result.Params[2].Description := 'Text to enter.';
  Result.Params[2].Required := True;
  Result.Params[3].Name := 'clear_first';
  Result.Params[3].ParamType := 'boolean';
  Result.Params[3].Description := 'Clear existing field content first (default true).';
  Result.Params[4].Name := 'ref';
  Result.Params[4].ParamType := 'string';
  Result.Params[4].Description := 'Element ref from browser_inspect instead of selector.';
  Result.Params[5].Name := 'timeout_ms';
  Result.Params[5].ParamType := 'integer';
  Result.Params[5].Description := 'Wait timeout in milliseconds (default 30000).';
end;

function TToolBrowserFill.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
  Adapter: TBrowserCancelAdapter;
  O: TJSONObject;
  Val: string;
begin
  if not FContext.AllowBrowserInteractive then
    Exit(DenyInteractive);
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  if S.Visible and S.AutomationPaused then
    Exit(DenyAutomationPaused(S));
  Val := Args.Get('value', '');
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    S.Lock.Enter;
    try
      if not BrowserFillElement(S, Args.Get('selector', ''), Args.Get('ref', ''), Val,
        Args.Get('clear_first', True), Args.Get('timeout_ms',
        BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS), @Adapter.Check, ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
    finally
      S.Lock.Leave;
    end;
    O := TJSONObject.Create;
    O.Add('session_id', S.Id);
    O.Add('status', 'filled');
    if Pos('password', LowerCase(Args.Get('selector', ''))) > 0 then
      O.Add('value_logged', False);
    Result := JsonOk(O);
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserWait.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserWait.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_wait';
  Result.Description := 'Wait for selector, text, URL, or document ready.';
  SetLength(Result.Params, 6);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Browser session id.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'condition';
  Result.Params[1].ParamType := 'string';
  Result.Params[1].Description :=
    'selector_visible, selector_hidden, text_present, url_matches, or document_ready.';
  Result.Params[1].Required := True;
  Result.Params[2].Name := 'selector';
  Result.Params[2].ParamType := 'string';
  Result.Params[2].Description := 'CSS selector when condition uses a selector.';
  Result.Params[3].Name := 'text';
  Result.Params[3].ParamType := 'string';
  Result.Params[3].Description := 'Substring for text_present condition.';
  Result.Params[4].Name := 'url_pattern';
  Result.Params[4].ParamType := 'string';
  Result.Params[4].Description := 'URL substring or wildcard for url_matches.';
  Result.Params[5].Name := 'timeout_ms';
  Result.Params[5].ParamType := 'integer';
  Result.Params[5].Description := 'Max wait in milliseconds (default 30000).';
end;

function TToolBrowserWait.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
  Adapter: TBrowserCancelAdapter;
  O: TJSONObject;
begin
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    S.Lock.Enter;
    try
      if not BrowserWaitCondition(S, Args.Get('condition', ''), Args.Get('selector', ''),
        Args.Get('text', ''), Args.Get('url_pattern', ''),
        Args.Get('timeout_ms', BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS), @Adapter.Check,
        ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
    finally
      S.Lock.Leave;
    end;
    O := TJSONObject.Create;
    O.Add('status', 'ok');
    Result := JsonOk(O);
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserClose.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserClose.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_close';
  Result.Description := 'Close a browser session and release resources.';
  SetLength(Result.Params, 1);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Browser session id to close.';
  Result.Params[0].Required := True;
end;

function TToolBrowserClose.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Sid: string;
  Adapter: TBrowserCancelAdapter;
  O: TJSONObject;
begin
  Sid := Args.Get('session_id', '');
  if Sid = '' then
    Exit(JsonErr('INVALID_ARGUMENT', 'session_id required'));
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    if not BrowserSessionClose(Sid, @Adapter.Check) then
      Exit(JsonErr('SESSION_NOT_FOUND', 'Session not found'));
    O := TJSONObject.Create;
    O.Add('closed', Sid);
    Result := JsonOk(O);
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserScreenshot.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserScreenshot.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_screenshot';
  Result.Description := 'Capture a PNG/JPEG screenshot; returns artifact_path for text providers.';
  SetLength(Result.Params, 6);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Browser session id.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'full_page';
  Result.Params[1].ParamType := 'boolean';
  Result.Params[1].Description := 'Capture full scrollable page (default false).';
  Result.Params[2].Name := 'selector';
  Result.Params[2].ParamType := 'string';
  Result.Params[2].Description := 'Optional CSS selector to clip the screenshot.';
  Result.Params[3].Name := 'format';
  Result.Params[3].ParamType := 'string';
  Result.Params[3].Description := 'png (default) or jpeg.';
  Result.Params[4].Name := 'quality';
  Result.Params[4].ParamType := 'integer';
  Result.Params[4].Description := 'JPEG quality 0-100 (default 85).';
  Result.Params[5].Name := 'timeout_ms';
  Result.Params[5].ParamType := 'integer';
  Result.Params[5].Description := 'Capture timeout in milliseconds (default 30000).';
end;

function TToolBrowserScreenshot.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
  Adapter: TBrowserCancelAdapter;
  Rel, Abs: string;
  O: TJSONObject;
  Att: TChatAttachment;
begin
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    S.Lock.Enter;
    try
      if not BrowserCaptureScreenshot(S, FContext.WorkspaceRoot,
        Args.Get('full_page', False), Args.Get('selector', ''),
        Args.Get('format', 'png'), Args.Get('quality', 85),
        Args.Get('timeout_ms', BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS), @Adapter.Check,
        Rel, Abs, ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
    finally
      S.Lock.Leave;
    end;
    O := TJSONObject.Create;
    O.Add('artifact_path', Rel);
    O.Add('absolute_path', Abs);
    Result := JsonOk(O);
    SetLength(Result.Attachments, 1);
    Att.Kind := cakImage;
    Att.RelativePath := Rel;
    Att.OriginalName := ExtractFileName(Abs);
    Att.MimeType := MimeTypeFromImageFileName(Abs);
    Result.Attachments[0] := Att;
    Result.Summary := 'Screenshot saved';
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserConsole.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserConsole.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_console';
  Result.Description := 'Read browser console messages and JS errors.';
  SetLength(Result.Params, 4);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Browser session id.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'level';
  Result.Params[1].ParamType := 'string';
  Result.Params[1].Description := 'Optional filter: log, warning, error, etc.';
  Result.Params[2].Name := 'since_last_read';
  Result.Params[2].ParamType := 'boolean';
  Result.Params[2].Description := 'Only entries since last read (default true).';
  Result.Params[3].Name := 'max_entries';
  Result.Params[3].ParamType := 'integer';
  Result.Params[3].Description := 'Maximum entries returned (default 100).';
end;

function TToolBrowserConsole.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  O: TJSONObject;
  Entries: TJSONArray;
begin
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  Entries := S.ConsoleLog.ReadEntries(Args.Get('since_last_read', True),
    Args.Get('level', ''), Args.Get('max_entries', 100));
  O := TJSONObject.Create;
  O.Add('entries', Entries);
  Result := JsonOk(O);
end;

constructor TToolBrowserNetwork.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserNetwork.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_network';
  Result.Description := 'Inspect network request metadata (no bodies).';
  SetLength(Result.Params, 4);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Browser session id.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'failed_only';
  Result.Params[1].ParamType := 'boolean';
  Result.Params[1].Description := 'Return only failed requests (default false).';
  Result.Params[2].Name := 'status_min';
  Result.Params[2].ParamType := 'integer';
  Result.Params[2].Description := 'Minimum HTTP status code to include (0 = no filter).';
  Result.Params[3].Name := 'max_entries';
  Result.Params[3].ParamType := 'integer';
  Result.Params[3].Description := 'Maximum entries returned (default 100).';
end;

function TToolBrowserNetwork.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  O: TJSONObject;
  Entries: TJSONArray;
begin
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  Entries := S.NetworkLog.ReadEntries(Args.Get('failed_only', False),
    Args.Get('status_min', 0), Args.Get('max_entries', 100));
  O := TJSONObject.Create;
  O.Add('entries', Entries);
  Result := JsonOk(O);
end;

constructor TToolBrowserSelect.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserSelect.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_select';
  Result.Description := 'Select an option on a native HTML select element.';
  SetLength(Result.Params, 4);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Browser session id.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'selector';
  Result.Params[1].ParamType := 'string';
  Result.Params[1].Description := 'CSS selector for the select element.';
  Result.Params[1].Required := True;
  Result.Params[2].Name := 'value';
  Result.Params[2].ParamType := 'string';
  Result.Params[2].Description := 'Option value to select.';
  Result.Params[2].Required := True;
  Result.Params[3].Name := 'timeout_ms';
  Result.Params[3].ParamType := 'integer';
  Result.Params[3].Description := 'Wait timeout in milliseconds (default 30000).';
end;

function TToolBrowserSelect.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
  Adapter: TBrowserCancelAdapter;
  O: TJSONObject;
begin
  if not FContext.AllowBrowserInteractive then
    Exit(DenyInteractive);
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  if S.Visible and S.AutomationPaused then
    Exit(DenyAutomationPaused(S));
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    S.Lock.Enter;
    try
      if not BrowserSelectOption(S, Args.Get('selector', ''), Args.Get('ref', ''),
        Args.Get('value', ''), Args.Get('timeout_ms', BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS),
        @Adapter.Check, ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
    finally
      S.Lock.Leave;
    end;
    O := TJSONObject.Create;
    O.Add('status', 'selected');
    Result := JsonOk(O);
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserSetViewport.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserSetViewport.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_set_viewport';
  Result.Description := 'Set viewport size for responsive testing (not full device emulation).';
  SetLength(Result.Params, 4);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Browser session id.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'width';
  Result.Params[1].ParamType := 'integer';
  Result.Params[1].Description := 'Viewport width in CSS pixels.';
  Result.Params[1].Required := True;
  Result.Params[2].Name := 'height';
  Result.Params[2].ParamType := 'integer';
  Result.Params[2].Description := 'Viewport height in CSS pixels.';
  Result.Params[2].Required := True;
  Result.Params[3].Name := 'device_scale_factor';
  Result.Params[3].ParamType := 'number';
  Result.Params[3].Description := 'Device scale factor (default 1.0).';
end;

function TToolBrowserSetViewport.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  ErrKind: TBrowserReadErrorKind;
  ErrMsg: string;
  Adapter: TBrowserCancelAdapter;
  O: TJSONObject;
begin
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  if S.Visible and S.AutomationPaused then
    Exit(DenyAutomationPaused(S));
  Adapter := TBrowserCancelAdapter.Create(FContext);
  try
    S.Lock.Enter;
    try
      if not BrowserAutomationSetViewport(S, Args.Get('width', 1280), Args.Get('height', 720),
        Args.Get('device_scale_factor', 1.0), BROWSER_AUTOMATION_DEFAULT_TIMEOUT_MS,
        @Adapter.Check, ErrKind, ErrMsg) then
        Exit(JsonErr(BrowserReadErrorKindToCode(ErrKind), ErrMsg));
    finally
      S.Lock.Leave;
    end;
    O := TJSONObject.Create;
    O.Add('status', 'ok');
    Result := JsonOk(O);
  finally
    Adapter.Free;
  end;
end;

constructor TToolBrowserResumeAutomation.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserResumeAutomation.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_resume_automation';
  Result.Description :=
    'Resume agent interactive control on a visible browser session after the user finished manual steps.';
  SetLength(Result.Params, 1);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Browser session id.';
  Result.Params[0].Required := True;
end;

function TToolBrowserResumeAutomation.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  O: TJSONObject;
begin
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  if not S.Visible then
    Exit(JsonErr('INVALID_ARGUMENT',
      'browser_resume_automation applies only to visible browser sessions'));
  S.Lock.Enter;
  try
    S.AutomationPaused := False;
    S.Touch;
  finally
    S.Lock.Leave;
  end;
  O := TJSONObject.Create;
  O.Add('session_id', S.Id);
  O.Add('automation_paused', False);
  O.Add('status', 'ok');
  Result := JsonOk(O);
end;

constructor TToolBrowserPauseAutomation.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
end;

function TToolBrowserPauseAutomation.GetDefinition: TToolDef;
begin
  Result.Name := 'browser_pause_automation';
  Result.Description :=
    'Pause agent interactive control on a visible session so the user can use the browser without competing clicks or fills.';
  SetLength(Result.Params, 1);
  Result.Params[0].Name := 'session_id';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Browser session id.';
  Result.Params[0].Required := True;
end;

function TToolBrowserPauseAutomation.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  S: TBrowserManagedSession;
  Err: string;
  O: TJSONObject;
begin
  if not GetSession(Args.Get('session_id', ''), S, Err) then
    Exit(JsonErr('SESSION_NOT_FOUND', Err));
  if not S.Visible then
    Exit(JsonErr('INVALID_ARGUMENT',
      'browser_pause_automation applies only to visible browser sessions'));
  S.Lock.Enter;
  try
    S.AutomationPaused := True;
    S.Touch;
  finally
    S.Lock.Leave;
  end;
  O := TJSONObject.Create;
  O.Add('session_id', S.Id);
  O.Add('automation_paused', True);
  O.Add('status', 'ok');
  Result := JsonOk(O);
end;

end.
