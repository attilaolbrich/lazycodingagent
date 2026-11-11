unit uWebSearchManager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uWebSearchTypes, uWebSearchHttp, uWebSearchConfig;

function ExecuteWebSearch(const AConfig: TWebSearchGlobalConfig; const ARequest: TWebSearchRequest;
  ATransport: IWebSearchTransport; CancelCheck: TWebSearchCancelCheck;
  out AResponse: TWebSearchResponse): Boolean;

function TestWebSearchConnection(const AConfig: TWebSearchGlobalConfig;
  const AConnectionId: string; ATransport: IWebSearchTransport;
  CancelCheck: TWebSearchCancelCheck): TConnectionTestResult;

function FindWebSearchConnection(const AConfig: TWebSearchGlobalConfig;
  const AConnectionId: string; out AConn: TWebSearchConnection): Boolean;

implementation

uses
  uWebSearchProvider, uWebSearchSecrets, uWebSearchNormalize;

function IsRetryableError(const ACode: string): Boolean;
begin
  Result := (ACode = WEB_SEARCH_ERR_AUTH) or (ACode = WEB_SEARCH_ERR_RATE_LIMIT) or
    (ACode = WEB_SEARCH_ERR_TIMEOUT) or (ACode = WEB_SEARCH_ERR_CONNECTION) or
    (ACode = WEB_SEARCH_ERR_INVALID_RESPONSE);
end;

function ConnectionApiKey(const AConn: TWebSearchConnection): string;
begin
  case AConn.Kind of
    wspkBrave, wspkTavily:
      Result := GetWebSearchApiKey(AConn.Id);
    else
      Result := '';
  end;
end;

function FindWebSearchConnection(const AConfig: TWebSearchGlobalConfig;
  const AConnectionId: string; out AConn: TWebSearchConnection): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AConfig.Connections) do
    if SameText(AConfig.Connections[I].Id, AConnectionId) then begin
      AConn := AConfig.Connections[I];
      Exit(True);
    end;
  Result := False;
end;

function TestWebSearchConnection(const AConfig: TWebSearchGlobalConfig;
  const AConnectionId: string; ATransport: IWebSearchTransport;
  CancelCheck: TWebSearchCancelCheck): TConnectionTestResult;
var
  Conn: TWebSearchConnection;
  Prov: IWebSearchProvider;
begin
  FillChar(Result, SizeOf(Result), 0);
  if not FindWebSearchConnection(AConfig, AConnectionId, Conn) then begin
    Result.ErrorCode := WEB_SEARCH_ERR_NO_PROVIDER;
    Result.ErrorMessage := 'Connection not found';
    Exit;
  end;
  Prov := CreateWebSearchProvider(Conn.Kind);
  if Prov = nil then begin
    Result.ErrorCode := WEB_SEARCH_ERR_NO_PROVIDER;
    Result.ErrorMessage := 'Unknown provider type';
    Exit;
  end;
  Result := Prov.TestConnection(Conn, ConnectionApiKey(Conn), AConfig.AllowPrivateInstances,
    ATransport, CancelCheck);
end;

function ExecuteWebSearch(const AConfig: TWebSearchGlobalConfig; const ARequest: TWebSearchRequest;
  ATransport: IWebSearchTransport; CancelCheck: TWebSearchCancelCheck;
  out AResponse: TWebSearchResponse): Boolean;
var
  Conns: array of TWebSearchConnection;
  I: Integer;
  Conn: TWebSearchConnection;
  Prov: IWebSearchProvider;
  Attempt: TWebSearchResponse;
  StartMs, DeadlineMs: QWord;
  RemainingMs: Integer;
  AttemptNames: string;
  ApiKey: string;
  ShouldFallback: Boolean;
begin
  InitWebSearchResponse(AResponse);
  Result := False;
  if not AConfig.Enabled then begin
    AResponse.ErrorCode := WEB_SEARCH_ERR_DISABLED;
    AResponse.ErrorMessage := 'Web Search is disabled';
    Exit;
  end;
  if not WebSearchHasUsableConnection(AConfig) then begin
    AResponse.ErrorCode := WEB_SEARCH_ERR_NO_PROVIDER;
    AResponse.ErrorMessage := 'No configured search provider is available';
    Exit;
  end;
  if Trim(ARequest.Query) = '' then begin
    AResponse.ErrorCode := WEB_SEARCH_ERR_INVALID_QUERY;
    AResponse.ErrorMessage := 'Search query is required';
    Exit;
  end;

  Conns := AConfig.Connections;
  SortConnectionsByPriority(Conns);
  StartMs := GetTickCount64;
  DeadlineMs := StartMs + QWord(AConfig.TotalTimeoutMs);
  AttemptNames := '';

  for I := 0 to High(Conns) do begin
    if Assigned(CancelCheck) and CancelCheck() then begin
      AResponse.ErrorCode := WEB_SEARCH_ERR_CANCELLED;
      AResponse.ErrorMessage := 'Search cancelled';
      Exit;
    end;
    Conn := Conns[I];
    if not Conn.Enabled then Continue;
    if not ConnectionIsConfigured(Conn, AConfig.AllowPrivateInstances) then Continue;

    if AttemptNames <> '' then AttemptNames := AttemptNames + ', ';
    AttemptNames := AttemptNames + Conn.Name;

    RemainingMs := Integer(DeadlineMs - GetTickCount64);
    if RemainingMs <= 0 then begin
      AResponse.ErrorCode := WEB_SEARCH_ERR_TIMEOUT;
      AResponse.ErrorMessage := 'Total search timeout exceeded';
      if not AConfig.AutomaticFallback then Exit;
      Continue;
    end;
    if Conn.TimeoutMs > RemainingMs then
      Conn.TimeoutMs := RemainingMs;

    Prov := CreateWebSearchProvider(Conn.Kind);
    if Prov = nil then Continue;
    ApiKey := ConnectionApiKey(Conn);
    InitWebSearchResponse(Attempt);
    Attempt.ProviderAttempted := Conn.Name;
    if Prov.Search(Conn, ARequest, ApiKey, AConfig.AllowPrivateInstances, ATransport,
      CancelCheck, Attempt) then begin
      if (Length(Attempt.Results) = 0) and not AConfig.FallbackOnEmptyResults then begin
        AResponse := Attempt;
        AResponse.Success := True;
        Result := True;
        Exit;
      end;
      if Length(Attempt.Results) > 0 then begin
        Attempt.Results := FilterValidResultUrls(Attempt.Results);
        AResponse := Attempt;
        AResponse.Success := True;
        Result := True;
        Exit;
      end;
      if not AConfig.FallbackOnEmptyResults then begin
        AResponse := Attempt;
        AResponse.Success := True;
        Result := True;
        Exit;
      end;
      if not AConfig.AutomaticFallback then begin
        AResponse := Attempt;
        AResponse.Success := True;
        Result := True;
        Exit;
      end;
      Continue;
    end;

    if Attempt.ErrorCode = WEB_SEARCH_ERR_CANCELLED then begin
      AResponse := Attempt;
      Exit;
    end;

    ShouldFallback := AConfig.AutomaticFallback and IsRetryableError(Attempt.ErrorCode);
    if not ShouldFallback then begin
      AResponse := Attempt;
      Exit;
    end;
  end;

  AResponse.ErrorCode := WEB_SEARCH_ERR_ALL_FAILED;
  AResponse.ErrorMessage := 'All search providers failed';
  if AttemptNames <> '' then
    AResponse.ErrorMessage := AResponse.ErrorMessage + ' (attempted: ' + AttemptNames + ')';
end;

end.
