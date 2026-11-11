unit uAgentTools;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, uAppTypes, uAgentTypes,
  uAgentToolBase,
  uToolReadFile,
  uToolWriteFile,
  uToolListDirectory,
  uToolGlob,
  uToolSearchCode,
  uToolRunProcess,
  uToolDiagnostics,
  uToolTodo,
  uToolApplyPatch,
  uToolEditFile,
  uToolGit,
  uToolCreatePlanFile,
  uToolWebFetch,
  uToolWebSearch,
  uToolBrowserRead,
  uToolBrowserAutomation;

type
  TToolExecutionResult = uAgentToolBase.TToolExecutionResult;
  TAgentToolContext = uAgentToolBase.TAgentToolContext;
  TAgentTool = uAgentToolBase.TAgentTool;

  TAgentToolRegistry = class
  private
    FContext: TAgentToolContext;
    FTools: array of TAgentTool;
    FActiveMode: TWorkspaceMode;
    procedure RegisterTool(ATool: TAgentTool);
    function FindTool(const AName: string): TAgentTool;
  public
    constructor Create(AContext: TAgentToolContext);
    destructor Destroy; override;

    function GetToolDefinitions: TToolDefArray; overload;
    function GetToolDefinitions(AMode: TWorkspaceMode): TToolDefArray; overload;
    function ExecuteTool(const AName, AArgumentsJson: string): TToolExecutionResult; overload;
    function ExecuteTool(const AName, AArgumentsJson: string; AMode: TWorkspaceMode): TToolExecutionResult; overload;
    function ToolCount: Integer;
    function GetTool(AIndex: Integer): TAgentTool;
    function ToolGuidance(AMode: TWorkspaceMode; AIncludeFullSchemas: Boolean = True): string;

    property Context: TAgentToolContext read FContext;
  end;

implementation

uses
  uWebSearchConfig, uWebSearchJson, uWebSearchTypes;

constructor TAgentToolRegistry.Create(AContext: TAgentToolContext);
begin
  inherited Create;
  FContext := AContext;
  FActiveMode := wmAgent;
  SetLength(FTools, 0);

  RegisterTool(TToolReadFile.Create(FContext));
  RegisterTool(TToolWriteFile.Create(FContext));
  RegisterTool(TToolListDirectory.Create(FContext));
  RegisterTool(TToolGlob.Create(FContext));
  RegisterTool(TToolSearchCode.Create(FContext));
  RegisterTool(TToolApplyPatch.Create(FContext));
  RegisterTool(TToolEditFile.Create(FContext));
  RegisterTool(TToolRunProcess.Create(FContext));
  RegisterTool(TToolDiagnostics.Create(FContext));
  RegisterTool(TToolGit.Create(FContext));
  RegisterTool(TToolTodo.Create(FContext));
  RegisterTool(TToolCreatePlanFile.Create(FContext));
  RegisterTool(TToolWebFetch.Create(FContext));
  RegisterTool(TToolWebSearch.Create(FContext));
  RegisterTool(TToolBrowserRead.Create(FContext));
  RegisterTool(TToolBrowserNavigate.Create(FContext));
  RegisterTool(TToolBrowserInspect.Create(FContext));
  RegisterTool(TToolBrowserClick.Create(FContext));
  RegisterTool(TToolBrowserFill.Create(FContext));
  RegisterTool(TToolBrowserWait.Create(FContext));
  RegisterTool(TToolBrowserClose.Create(FContext));
  RegisterTool(TToolBrowserScreenshot.Create(FContext));
  RegisterTool(TToolBrowserConsole.Create(FContext));
  RegisterTool(TToolBrowserNetwork.Create(FContext));
  RegisterTool(TToolBrowserSelect.Create(FContext));
  RegisterTool(TToolBrowserSetViewport.Create(FContext));
  RegisterTool(TToolBrowserResumeAutomation.Create(FContext));
  RegisterTool(TToolBrowserPauseAutomation.Create(FContext));
end;

destructor TAgentToolRegistry.Destroy;
var
  I: Integer;
begin
  for I := Low(FTools) to High(FTools) do
    FTools[I].Free;
  SetLength(FTools, 0);
  inherited Destroy;
end;

procedure TAgentToolRegistry.RegisterTool(ATool: TAgentTool);
var
  Idx: Integer;
begin
  if ATool = nil then Exit;
  Idx := Length(FTools);
  SetLength(FTools, Idx + 1);
  FTools[Idx] := ATool;
end;

function TAgentToolRegistry.FindTool(const AName: string): TAgentTool;
var
  I: Integer;
begin
  Result := nil;
  for I := Low(FTools) to High(FTools) do
    if FTools[I].MatchesName(AName) then
      Exit(FTools[I]);
end;

function TAgentToolRegistry.ToolCount: Integer;
begin
  Result := Length(FTools);
end;

function TAgentToolRegistry.GetTool(AIndex: Integer): TAgentTool;
begin
  if (AIndex >= Low(FTools)) and (AIndex <= High(FTools)) then
    Result := FTools[AIndex]
  else
    Result := nil;
end;

function TAgentToolRegistry.GetToolDefinitions: TToolDefArray;
begin
  Result := GetToolDefinitions(FActiveMode);
end;

procedure SortToolDefsByName(var ADefs: TToolDefArray);
var
  I, J: Integer;
  Tmp: TToolDef;
begin
  for I := Low(ADefs) to High(ADefs) - 1 do
    for J := I + 1 to High(ADefs) do
      if CompareText(ADefs[J].Name, ADefs[I].Name) < 0 then begin
        Tmp := ADefs[I];
        ADefs[I] := ADefs[J];
        ADefs[J] := Tmp;
      end;
end;

function TAgentToolRegistry.ToolGuidance(AMode: TWorkspaceMode;
  AIncludeFullSchemas: Boolean): string;
var
  I: Integer;
  Def: TToolDef;
  Schema: string;
  Defs: TToolDefArray;
begin
  Defs := GetToolDefinitions(AMode);
  Result := 'Available tools (JSON arguments):' + LineEnding;
  for I := Low(Defs) to High(Defs) do begin
    Def := Defs[I];
    if AIncludeFullSchemas then begin
      Schema := ToolDefToParametersJson(Def);
      Result := Result + '- ' + Def.Name + ': ' + Def.Description +
        ' Parameters: ' + Schema + LineEnding;
    end else
      Result := Result + '- ' + Def.Name + ': ' + Def.Description + LineEnding;
  end;
end;

function TAgentToolRegistry.GetToolDefinitions(AMode: TWorkspaceMode): TToolDefArray;
var
  I, N: Integer;
begin
  SetLength(Result, 0);
  FActiveMode := AMode;
  N := 0;
  for I := Low(FTools) to High(FTools) do
    if FTools[I].IsAdvertised(AMode) and FTools[I].ToolAllowedInMode(AMode) then
      Inc(N);
  SetLength(Result, N);
  N := 0;
  for I := Low(FTools) to High(FTools) do
    if FTools[I].IsAdvertised(AMode) and FTools[I].ToolAllowedInMode(AMode) then
    begin
      Result[N] := FTools[I].GetDefinition;
      Inc(N);
    end;
  SortToolDefsByName(Result);
end;

function TAgentToolRegistry.ExecuteTool(const AName, AArgumentsJson: string): TToolExecutionResult;
begin
  Result := ExecuteTool(AName, AArgumentsJson, FActiveMode);
end;

function TAgentToolRegistry.ExecuteTool(const AName, AArgumentsJson: string;
  AMode: TWorkspaceMode): TToolExecutionResult;
var
  Args: TJSONObject;
  Tool: TAgentTool;
  PrevContext: TAgentToolContext;
  ParseErr: string;
begin
  Result.Success := False;
  Result.Output := '';
  Result.Summary := '';
  Result.WasException := False;
  Result.ExceptionClass := '';
  SetLength(Result.Attachments, 0);

  FContext.Mode := AMode;
  PrevContext := CurrentToolContext;
  SetCurrentToolContext(FContext);
  try
    if not TryParseToolArguments(AName, AArgumentsJson, Args, ParseErr) then
    begin
      Result := ToolResultFromJson(ToolError(ParseErr));
      Exit;
    end;

    try
      Tool := FindTool(AName);
      if not Assigned(Tool) then
      begin
        Result := ToolResultFromJson(ToolError('Tool not found: ' + AName));
        Exit;
      end;
      if not Tool.ToolAllowedInMode(AMode) then
      begin
        Result := ToolResultFromJson(ToolError('Tool unavailable in ' +
          WorkspaceModeToCaption(AMode) + ' mode: ' + Tool.GetDefinition.Name));
        Exit;
      end;
      if not Tool.IsAdvertised(AMode) then
      begin
        if SameText(Tool.GetDefinition.Name, 'web_search') then begin
          if not LoadWebSearchConfig.Enabled then
            Result := ToolResultFromJson(WebSearchErrorJson('', WEB_SEARCH_ERR_DISABLED,
              'Web Search is disabled'))
          else
            Result := ToolResultFromJson(WebSearchErrorJson('', WEB_SEARCH_ERR_NO_PROVIDER,
              'Web Search is not configured'));
        end else
          Result := ToolResultFromJson(ToolError('Tool is not available: ' +
            Tool.GetDefinition.Name));
        Exit;
      end;
      if ToolCancelled then
      begin
        Result := ToolResultFromJson(ToolError('Tool cancelled'));
        Exit;
      end;

      try
        Result := Tool.Execute(Args);
      except
        on E: Exception do
        begin
          Result := ToolResultFromJson(ToolError('Tool execution failed: ' + E.Message));
          Result.WasException := True;
          Result.ExceptionClass := E.ClassName;
        end;
      end;
    finally
      Args.Free;
    end;
  finally
    SetCurrentToolContext(PrevContext);
  end;
end;

end.
