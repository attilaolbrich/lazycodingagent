unit uWebSearchUrl;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uWebSearchTypes;

function UrlEncodeQueryComponent(const S: string): string;
function ValidateSearchResultUrl(const AUrl: string): Boolean;
function ValidateSearxngInstanceUrl(const AUrl: string; AAllowPrivate: Boolean;
  out ANormalizedBase: string; out ErrMsg: string): Boolean;
function WebSearchTrustedLocalAllowed: Boolean;
function CanonicalResultUrl(const AUrl: string): string;

implementation

uses
  uWebFetchUrl, uWebFetchTypes;

function UrlEncodeQueryComponent(const S: string): string;
const
  Unreserved = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
var
  I: Integer;
  C: Char;
  B: Byte;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if Pos(C, Unreserved) > 0 then
      Result := Result + C
    else
    begin
      B := Ord(C);
      Result := Result + '%' + IntToHex(B, 2);
    end;
  end;
end;

function HasEmbeddedCredentials(const AUrl: string): Boolean;
var
  P, AtPos: SizeInt;
  SchemeEnd: SizeInt;
begin
  SchemeEnd := Pos('://', LowerCase(AUrl));
  if SchemeEnd = 0 then Exit(False);
  P := SchemeEnd + 3;
  AtPos := Pos('@', Copy(AUrl, P, MaxInt));
  Result := AtPos > 0;
end;

function ValidateSearchResultUrl(const AUrl: string): Boolean;
var
  L: string;
begin
  L := Trim(AUrl);
  if L = '' then Exit(False);
  if HasEmbeddedCredentials(L) then Exit(False);
  if not (SameText(Copy(L, 1, 7), 'http://') or SameText(Copy(L, 1, 8), 'https://')) then
    Exit(False);
  Result := True;
end;

function CanonicalResultUrl(const AUrl: string): string;
begin
  Result := LowerCase(Trim(AUrl));
end;

function WebSearchTrustedLocalAllowed: Boolean;
begin
  Result := SameText(GetEnvironmentVariable('LCA_WEB_SEARCH_TRUSTED_LOCAL'), '1');
end;

function ParseBaseUrl(const AUrl: string; out Scheme, Host, Path: string;
  out Port: Word; out ErrMsg: string): Boolean;
var
  S, Authority, PortText: string;
  P, SlashPos, ColonPos: SizeInt;
  PortNum: Integer;
begin
  Result := False;
  Scheme := '';
  Host := '';
  Path := '/';
  Port := 0;
  ErrMsg := 'Invalid URL';
  S := Trim(AUrl);
  if SameText(Copy(S, 1, 8), 'https://') then begin
    Scheme := 'https';
    Port := 443;
    Delete(S, 1, 8);
  end else if SameText(Copy(S, 1, 7), 'http://') then begin
    Scheme := 'http';
    Port := 80;
    Delete(S, 1, 7);
  end else begin
    ErrMsg := 'URL must use http or https';
    Exit;
  end;
  if S = '' then Exit;
  SlashPos := Pos('/', S);
  if SlashPos > 0 then begin
    Authority := Copy(S, 1, SlashPos - 1);
    Path := Copy(S, SlashPos, MaxInt);
  end else
    Authority := S;
  if Authority = '' then Exit;
  ColonPos := Pos(':', Authority);
  if ColonPos > 0 then begin
    Host := Copy(Authority, 1, ColonPos - 1);
    PortText := Copy(Authority, ColonPos + 1, MaxInt);
    PortNum := StrToIntDef(PortText, -1);
    if (PortNum < 1) or (PortNum > 65535) then Exit;
    Port := Word(PortNum);
  end else
    Host := Authority;
  if Host = '' then Exit;
  if Path = '' then Path := '/';
  Result := True;
end;

function ValidateSearxngInstanceUrl(const AUrl: string; AAllowPrivate: Boolean;
  out ANormalizedBase: string; out ErrMsg: string): Boolean;
var
  Scheme, Host, Path: string;
  Port: Word;
  Parsed: TWebFetchUrl;
  Kind: TWebFetchErrorKind;
begin
  ANormalizedBase := '';
  ErrMsg := '';
  if not ParseBaseUrl(Trim(AUrl), Scheme, Host, Path, Port, ErrMsg) then
    Exit(False);
  if HasEmbeddedCredentials(AUrl) then begin
    ErrMsg := 'URLs with embedded credentials are not allowed';
    Exit(False);
  end;
  if not AAllowPrivate and not WebSearchTrustedLocalAllowed then begin
    if HostIsBlockedName(Host) then begin
      ErrMsg := 'Local/private SearXNG URLs are blocked. Enable "Allow local/private SearXNG" in Web Search settings.';
      Exit(False);
    end;
    Parsed.Scheme := Scheme;
    Parsed.Host := Host;
    Parsed.Port := Port;
    Parsed.Path := Path;
    Parsed.Secure := SameText(Scheme, 'https');
    Parsed.OriginalUrl := AUrl;
    if not ValidateWebFetchTarget(Parsed, Kind, ErrMsg) then begin
      if (ErrMsg = 'Destination is not allowed') or (Kind = wfekBlockedDestination) then
        ErrMsg := 'Local/private SearXNG URLs are blocked. Enable "Allow local/private SearXNG" in Web Search settings.';
      Exit(False);
    end;
  end;
  ANormalizedBase := Scheme + '://' + Host;
  if (Port <> 80) and (Port <> 443) then
    ANormalizedBase := ANormalizedBase + ':' + IntToStr(Port);
  if Path <> '' then
    ANormalizedBase := ANormalizedBase + Path;
  if ANormalizedBase[Length(ANormalizedBase)] = '/' then
    SetLength(ANormalizedBase, Length(ANormalizedBase) - 1);
  Result := True;
end;

end.
