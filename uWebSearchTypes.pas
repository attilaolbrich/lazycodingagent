unit uWebSearchTypes;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  WEB_SEARCH_USER_AGENT =
    'LazyCodingAgent/1.0 (+https://github.com/lazarus/lazycodingagent)';
  WEB_SEARCH_DEFAULT_MAX_RESULTS = 10;
  WEB_SEARCH_DEFAULT_TOTAL_TIMEOUT_MS = 30000;
  WEB_SEARCH_DEFAULT_CONNECTION_TIMEOUT_MS = 10000;
  WEB_SEARCH_MAX_BODY_BYTES = 2 * 1024 * 1024;
  WEB_SEARCH_CONFIG_VERSION = 1;

  WEB_SEARCH_ERR_DISABLED = 'WEB_SEARCH_DISABLED';
  WEB_SEARCH_ERR_NO_PROVIDER = 'NO_PROVIDER_CONFIGURED';
  WEB_SEARCH_ERR_INVALID_QUERY = 'INVALID_SEARCH_QUERY';
  WEB_SEARCH_ERR_AUTH = 'PROVIDER_AUTH_FAILED';
  WEB_SEARCH_ERR_RATE_LIMIT = 'PROVIDER_RATE_LIMITED';
  WEB_SEARCH_ERR_TIMEOUT = 'PROVIDER_TIMEOUT';
  WEB_SEARCH_ERR_CONNECTION = 'PROVIDER_CONNECTION_FAILED';
  WEB_SEARCH_ERR_INVALID_RESPONSE = 'PROVIDER_INVALID_RESPONSE';
  WEB_SEARCH_ERR_ALL_FAILED = 'ALL_PROVIDERS_FAILED';
  WEB_SEARCH_ERR_CANCELLED = 'SEARCH_CANCELLED';

type
  TWebSearchProviderKind = (
    wspkBrave,
    wspkSearxng,
    wspkTavily
  );

  TWebSearchConnection = record
    Id: string;
    Name: string;
    Kind: TWebSearchProviderKind;
    Enabled: Boolean;
    Priority: Integer;
    TimeoutMs: Integer;
    InstanceUrl: string;
    TavilySearchDepth: string;
    CustomHeaderName: string;
    CustomHeaderValue: string;
  end;

  TWebSearchGlobalConfig = record
    ConfigVersion: Integer;
    Enabled: Boolean;
    MaxResults: Integer;
    TotalTimeoutMs: Integer;
    AutomaticFallback: Boolean;
    FallbackOnEmptyResults: Boolean;
    AllowPrivateInstances: Boolean;
    Connections: array of TWebSearchConnection;
  end;

  TWebSearchRequest = record
    Query: string;
    MaxResults: Integer;
    Recency: string;
  end;

  TWebSearchResult = record
    Title: string;
    URL: string;
    Snippet: string;
    PublishedAt: string;
  end;
  TWebSearchResultArray = array of TWebSearchResult;

  TWebSearchResponse = record
    Success: Boolean;
    Results: TWebSearchResultArray;
    ErrorCode: string;
    ErrorMessage: string;
    ProviderAttempted: string;
  end;

  TConnectionTestResult = record
    Success: Boolean;
    ResponseTimeMs: Integer;
    ResultCount: Integer;
    ErrorCode: string;
    ErrorMessage: string;
  end;

  TWebSearchCancelCheck = function: Boolean of object;

  TWebSearchHttpResponse = record
    StatusCode: Integer;
    ContentType: string;
    Body: RawByteString;
  end;

function DefaultWebSearchGlobalConfig: TWebSearchGlobalConfig;
function WebSearchProviderKindToString(AKind: TWebSearchProviderKind): string;
function ParseWebSearchProviderKind(const S: string; out AKind: TWebSearchProviderKind): Boolean;
function WebSearchProviderDisplayName(AKind: TWebSearchProviderKind): string;
procedure InitWebSearchResponse(out R: TWebSearchResponse);
function NormalizeRecency(const S: string): string;
function RecencyIsValid(const S: string): Boolean;

implementation

function DefaultWebSearchGlobalConfig: TWebSearchGlobalConfig;
begin
  Result.ConfigVersion := WEB_SEARCH_CONFIG_VERSION;
  Result.Enabled := False;
  Result.MaxResults := WEB_SEARCH_DEFAULT_MAX_RESULTS;
  Result.TotalTimeoutMs := WEB_SEARCH_DEFAULT_TOTAL_TIMEOUT_MS;
  Result.AutomaticFallback := True;
  Result.FallbackOnEmptyResults := False;
  Result.AllowPrivateInstances := False;
  SetLength(Result.Connections, 0);
end;

function WebSearchProviderKindToString(AKind: TWebSearchProviderKind): string;
begin
  case AKind of
    wspkBrave: Result := 'brave';
    wspkSearxng: Result := 'searxng';
    wspkTavily: Result := 'tavily';
  else
    Result := '';
  end;
end;

function ParseWebSearchProviderKind(const S: string; out AKind: TWebSearchProviderKind): Boolean;
begin
  if SameText(S, 'brave') then begin AKind := wspkBrave; Exit(True); end;
  if SameText(S, 'searxng') then begin AKind := wspkSearxng; Exit(True); end;
  if SameText(S, 'tavily') then begin AKind := wspkTavily; Exit(True); end;
  Result := False;
end;

function WebSearchProviderDisplayName(AKind: TWebSearchProviderKind): string;
begin
  case AKind of
    wspkBrave: Result := 'Brave';
    wspkSearxng: Result := 'SearXNG';
    wspkTavily: Result := 'Tavily';
  else
    Result := 'Unknown';
  end;
end;

procedure InitWebSearchResponse(out R: TWebSearchResponse);
begin
  R.Success := False;
  SetLength(R.Results, 0);
  R.ErrorCode := '';
  R.ErrorMessage := '';
  R.ProviderAttempted := '';
end;

function NormalizeRecency(const S: string): string;
var
  L: string;
begin
  L := LowerCase(Trim(S));
  if L = '' then Exit('any');
  if RecencyIsValid(L) then Exit(L);
  Result := 'any';
end;

function RecencyIsValid(const S: string): Boolean;
begin
  Result := SameText(S, 'any') or SameText(S, 'day') or SameText(S, 'week') or
    SameText(S, 'month') or SameText(S, 'year');
end;

end.
