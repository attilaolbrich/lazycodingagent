unit uToolWebSearch;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAppTypes, uAgentTypes, uAgentToolBase;

type
  TToolWebSearch = class(TAgentTool)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
    function IsAdvertised(AMode: TWorkspaceMode): Boolean; override;
  end;

implementation

uses
  uWebSearchConfig, uWebSearchManager, uWebSearchHttp, uWebSearchJson, uWebSearchTypes;

type
  TWebSearchCancelAdapter = class
  private
    FContext: TAgentToolContext;
  public
    constructor Create(AContext: TAgentToolContext);
    function Check: Boolean;
  end;

constructor TWebSearchCancelAdapter.Create(AContext: TAgentToolContext);
begin
  inherited Create;
  FContext := AContext;
end;

function TWebSearchCancelAdapter.Check: Boolean;
begin
  Result := FContext.IsCancelled;
end;

constructor TToolWebSearch.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  AllowedModes := [wmAsk, wmPlan, wmAgent];
  MutatesFiles := False;
end;

function TToolWebSearch.IsAdvertised(AMode: TWorkspaceMode): Boolean;
begin
  Result := inherited IsAdvertised(AMode) and ToolAllowedInMode(AMode) and
    WebSearchIsToolAvailable;
end;

function TToolWebSearch.GetDefinition: TToolDef;
begin
  Result.Name := 'web_search';
  Result.Description :=
    'Search the internet for current public information, documentation, libraries, ' +
    'technical solutions and relevant websites. Returns search results containing titles, ' +
    'URLs and summaries. Prefer web_fetch to read a specific URL after you find it.';
  SetLength(Result.Params, 3);
  Result.Params[0].Name := 'query';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Search query.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'max_results';
  Result.Params[1].ParamType := 'integer';
  Result.Params[1].Description := 'Maximum number of results (default 10).';
  Result.Params[1].Required := False;
  Result.Params[2].Name := 'recency';
  Result.Params[2].ParamType := 'string';
  Result.Params[2].Description := 'Filter by recency (default any).';
  Result.Params[2].Required := False;
  SetLength(Result.Params[2].EnumValues, 5);
  Result.Params[2].EnumValues[0] := 'any';
  Result.Params[2].EnumValues[1] := 'day';
  Result.Params[2].EnumValues[2] := 'week';
  Result.Params[2].EnumValues[3] := 'month';
  Result.Params[2].EnumValues[4] := 'year';
end;

function TToolWebSearch.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Cfg: TWebSearchGlobalConfig;
  Req: TWebSearchRequest;
  Resp: TWebSearchResponse;
  CancelAdapter: TWebSearchCancelAdapter;
  Transport: IWebSearchTransport;
  MaxGlobal: Integer;
begin
  Cfg := LoadWebSearchConfig;
  if not Cfg.Enabled then begin
    Result := ToolResultFromJson(WebSearchErrorJson('', WEB_SEARCH_ERR_DISABLED,
      'Web Search is disabled'));
    Exit;
  end;
  if not WebSearchHasUsableConnection(Cfg) then begin
    Result := ToolResultFromJson(WebSearchErrorJson('', WEB_SEARCH_ERR_NO_PROVIDER,
      'No search provider is configured'));
    Exit;
  end;

  Req.Query := Trim(Args.Get('query', ''));
  if Req.Query = '' then begin
    Result := ToolResultFromJson(WebSearchErrorJson('', WEB_SEARCH_ERR_INVALID_QUERY,
      'Missing required parameter: query'));
    Exit;
  end;

  MaxGlobal := Cfg.MaxResults;
  Req.MaxResults := Args.Get('max_results', MaxGlobal);
  if Req.MaxResults <= 0 then Req.MaxResults := MaxGlobal;
  if Req.MaxResults > MaxGlobal then Req.MaxResults := MaxGlobal;
  Req.Recency := NormalizeRecency(Args.Get('recency', 'any'));

  CancelAdapter := TWebSearchCancelAdapter.Create(FContext);
  Transport := TWebSearchProductionTransport.Create;
  try
    if ExecuteWebSearch(Cfg, Req, Transport,
      @CancelAdapter.Check, Resp) then
      Result := ToolResultFromJson(WebSearchToolResultToJson(Req.Query, Resp))
    else
      Result := ToolResultFromJson(WebSearchToolResultToJson(Req.Query, Resp));
  finally
    CancelAdapter.Free;
  end;
end;

end.
