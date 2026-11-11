unit uWebFetchUrl;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uWebFetchTypes;

type
  TWebFetchUrl = record
    Scheme: string;
    Host: string;
    Port: Word;
    Path: string;
    Secure: Boolean;
    OriginalUrl: string;
  end;

function ParseWebFetchUrl(const AUrl: string; out Parsed: TWebFetchUrl;
  out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;

function ValidateWebFetchTarget(const Parsed: TWebFetchUrl;
  out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;

function ResolveRedirectUrl(const BaseUrl, Location: string;
  out Resolved: string; out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;

function IsBlockedIPv4(Addr: Cardinal): Boolean;
function IsBlockedIPv6(const Addr: array of Byte): Boolean;

function HostIsBlockedName(const Host: string): Boolean;

function BuildPinnedRequestUrl(const Parsed: TWebFetchUrl; const ConnectIP: string): string;
function SelectConnectAddress(const Parsed: TWebFetchUrl; out ConnectIP: string;
  out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;

implementation

uses
  Sockets, uHostDnsResolve;

function StripFragment(const S: string): string;
var
  P: SizeInt;
begin
  P := Pos('#', S);
  if P > 0 then
    Result := Copy(S, 1, P - 1)
  else
    Result := S;
end;

function IsDigit(C: Char): Boolean; inline;
begin
  Result := C in ['0'..'9'];
end;

function HostLooksLikeIPv4(const Host: string): Boolean;
var
  I, Dots, PartLen: Integer;
begin
  if Host = '' then Exit(False);
  Dots := 0;
  PartLen := 0;
  for I := 1 to Length(Host) do
  begin
    if Host[I] = '.' then
    begin
      if PartLen = 0 then Exit(False);
      Inc(Dots);
      PartLen := 0;
    end
    else if IsDigit(Host[I]) then
    begin
      Inc(PartLen);
      if PartLen > 3 then Exit(False);
    end
    else
      Exit(False);
  end;
  Result := (Dots = 3) and (PartLen > 0);
end;

function ParseIPv4Host(const Host: string; out Addr: Cardinal): Boolean;
var
  Parts: TStringArray;
  I, V: Integer;
begin
  Result := False;
  Addr := 0;
  Parts := Host.Split(['.']);
  if Length(Parts) <> 4 then Exit;
  for I := 0 to 3 do
  begin
    if Parts[I] = '' then Exit;
    V := StrToIntDef(Parts[I], -1);
    if (V < 0) or (V > 255) then Exit;
    Addr := Addr or (Cardinal(V) shl ((3 - I) * 8));
  end;
  Result := True;
end;

function ParseIPv6Literal(const Host: string; out Bytes: array of Byte): Boolean;
var
  H6: in6_addr;
begin
  FillChar(Bytes, SizeOf(Bytes), 0);
  if not TryStrToHostAddr6(AnsiString(Host), H6) then
    Exit(False);
  Move(H6.s6_addr, Bytes, 16);
  Result := True;
end;

function IsBlockedIPv4(Addr: Cardinal): Boolean;
var
  B0, B1, B2, B3: Byte;
begin
  B0 := (Addr shr 24) and $FF;
  B1 := (Addr shr 16) and $FF;
  B2 := (Addr shr 8) and $FF;
  B3 := Addr and $FF;
  if B0 = 0 then Exit(True);
  if B0 = 10 then Exit(True);
  if (B0 = 100) and (B1 >= 64) and (B1 <= 127) then Exit(True);
  if (B0 = 127) then Exit(True);
  if (B0 = 169) and (B1 = 254) then Exit(True);
  if (B0 = 172) and (B1 >= 16) and (B1 <= 31) then Exit(True);
  if (B0 = 192) and (B1 = 168) then Exit(True);
  if (B0 = 192) and (B1 = 0) and (B2 = 0) then Exit(True);
  if (B0 = 198) and ((B1 = 18) or (B1 = 19)) then Exit(True);
  if B0 >= 224 then Exit(True);
  if (B0 = 0) and (B1 = 0) and (B2 = 0) and (B3 = 0) then Exit(True);
  Result := False;
end;

function IsBlockedIPv6(const Addr: array of Byte): Boolean;
begin
  if Length(Addr) < 16 then Exit(True);
  if (Addr[0] = 0) and (Addr[1] = 0) and (Addr[2] = 0) and (Addr[3] = 0) and
     (Addr[4] = 0) and (Addr[5] = 0) and (Addr[6] = 0) and (Addr[7] = 0) and
     (Addr[8] = 0) and (Addr[9] = 0) and (Addr[10] = $FF) and (Addr[11] = $FF) then
  begin
    if IsBlockedIPv4((Cardinal(Addr[12]) shl 24) or (Cardinal(Addr[13]) shl 16) or
      (Cardinal(Addr[14]) shl 8) or Cardinal(Addr[15])) then
      Exit(True);
  end;
  if Addr[0] = $FF then Exit(True);
  if (Addr[0] = $FE) and ((Addr[1] and $C0) = $80) then Exit(True);
  if (Addr[0] and $FE) = $FC then Exit(True);
  if (Addr[0] = 0) and (Addr[1] = 0) and (Addr[2] = 0) and (Addr[3] = 0) and
     (Addr[4] = 0) and (Addr[5] = 0) and (Addr[6] = 0) and (Addr[7] = 0) and
     (Addr[8] = 0) and (Addr[9] = 0) and (Addr[10] = 0) and (Addr[11] = 0) and
     (Addr[12] = 0) and (Addr[13] = 0) and (Addr[14] = 0) and (Addr[15] = 1) then
    Exit(True);
  if (Addr[0] = 0) and (Addr[1] = 0) and (Addr[2] = 0) and (Addr[3] = 0) and
     (Addr[4] = 0) and (Addr[5] = 0) and (Addr[6] = 0) and (Addr[7] = 0) and
     (Addr[8] = 0) and (Addr[9] = 0) and (Addr[10] = 0) and (Addr[11] = 0) and
     (Addr[12] = 0) and (Addr[13] = 0) and (Addr[14] = 0) and (Addr[15] = 0) then
    Exit(True);
  Result := False;
end;

function HostIsBlockedName(const Host: string): Boolean;
var
  L: string;
begin
  L := LowerCase(Trim(Host));
  if L = '' then Exit(True);
  if (L = 'localhost') or (L = 'localhost.localdomain') then Exit(True);
  if L = '0.0.0.0' then Exit(True);
  if L = '::1' then Exit(True);
  if L = '::' then Exit(True);
  if SameText(L, 'metadata.google.internal') then Exit(True);
  if SameText(L, 'metadata') then Exit(True);
  if Copy(L, Length(L) - 5, 6) = '.local' then Exit(True);
  if Copy(L, Length(L) - 13, 14) = '.localhost' then Exit(True);
  Result := False;
end;

function ValidateResolvedAddresses(const Host: string;
  out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;
var
  Addrs4: array[0..MaxHostResolveAddr - 1] of THostAddr;
  Addrs6: array[0..MaxHostResolveAddr - 1] of THostAddr6;
  N4, N6, I: Integer;
  V4: Cardinal;
  B6: array[0..15] of Byte;
begin
  Result := False;
  ErrKind := wfekDnsFailure;
  ErrMsg := 'Could not resolve host: ' + Host;

  if HostLooksLikeIPv4(Host) then
  begin
    if not ParseIPv4Host(Host, V4) then
    begin
      ErrKind := wfekInvalidUrl;
      ErrMsg := 'Invalid IPv4 address';
      Exit;
    end;
    if IsBlockedIPv4(V4) then
    begin
      ErrKind := wfekBlockedDestination;
      ErrMsg := 'Destination is not allowed';
      Exit;
    end;
    Exit(True);
  end;

  if (Length(Host) > 2) and (Host[1] = '[') and (Host[Length(Host)] = ']') then
  begin
    if not ParseIPv6Literal(Copy(Host, 2, Length(Host) - 2), B6) then
    begin
      ErrKind := wfekInvalidUrl;
      ErrMsg := 'Invalid IPv6 address';
      Exit;
    end;
    if IsBlockedIPv6(B6) then
    begin
      ErrKind := wfekBlockedDestination;
      ErrMsg := 'Destination is not allowed';
      Exit;
    end;
    Exit(True);
  end;

  if HostIsBlockedName(Host) then
  begin
    ErrKind := wfekBlockedDestination;
    ErrMsg := 'Destination is not allowed';
    Exit;
  end;

  N4 := ResolveHostAddresses4(Host, Addrs4);
  N6 := ResolveHostAddresses6(Host, Addrs6);

  if (N4 <= 0) and (N6 <= 0) then
    Exit;

  for I := 0 to N4 - 1 do
    if IsBlockedIPv4(ntohl(LongWord(Addrs4[I]))) then
    begin
      ErrKind := wfekBlockedDestination;
      ErrMsg := 'Destination is not allowed';
      Exit;
    end;

  for I := 0 to N6 - 1 do
  begin
    Move(Addrs6[I].s6_addr, B6, 16);
    if IsBlockedIPv6(B6) then
    begin
      ErrKind := wfekBlockedDestination;
      ErrMsg := 'Destination is not allowed';
      Exit;
    end;
  end;

  Result := True;
end;

function ParseWebFetchUrl(const AUrl: string; out Parsed: TWebFetchUrl;
  out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;
var
  S, Authority, PortText, Rest: string;
  P, SlashPos, QueryPos, ColonPos: SizeInt;
  PortNum: Integer;
begin
  Result := False;
  ErrKind := wfekInvalidUrl;
  ErrMsg := 'Invalid URL';
  FillChar(Parsed, SizeOf(Parsed), 0);
  Parsed.OriginalUrl := Trim(AUrl);
  S := StripFragment(Trim(AUrl));
  if S = '' then Exit;

  if SameText(Copy(S, 1, 8), 'https://') then
  begin
    Parsed.Scheme := 'https';
    Parsed.Secure := True;
    Parsed.Port := 443;
    Delete(S, 1, 8);
  end
  else if SameText(Copy(S, 1, 7), 'http://') then
  begin
    Parsed.Scheme := 'http';
    Parsed.Secure := False;
    Parsed.Port := 80;
    Delete(S, 1, 7);
  end
  else
  begin
    ErrMsg := 'Only http and https URLs are allowed';
    Exit;
  end;

  SlashPos := Pos('/', S);
  QueryPos := Pos('?', S);
  if (SlashPos = 0) or ((QueryPos > 0) and (QueryPos < SlashPos)) then
  begin
    if QueryPos > 0 then
      P := QueryPos
    else
      P := Length(S) + 1;
  end
  else
    P := SlashPos;
  Authority := Copy(S, 1, P - 1);
  Rest := Copy(S, P, MaxInt);
  if Rest = '' then
    Parsed.Path := '/'
  else if Rest[1] = '?' then
    Parsed.Path := '/' + Rest
  else
    Parsed.Path := Rest;

  if Pos('@', Authority) > 0 then
  begin
    ErrMsg := 'URLs with embedded credentials are not allowed';
    Exit;
  end;

  Parsed.Host := Authority;
  PortText := '';
  if (Authority <> '') and (Authority[1] = '[') then
  begin
    P := Pos(']', Authority);
    if P = 0 then
    begin
      ErrMsg := 'Invalid IPv6 URL host';
      Exit;
    end;
    Parsed.Host := Copy(Authority, 2, P - 2);
    if (P < Length(Authority)) and (Authority[P + 1] = ':') then
      PortText := Copy(Authority, P + 2, MaxInt);
  end
  else
  begin
    ColonPos := LastDelimiter(':', Authority);
    if ColonPos > 0 then
    begin
      Parsed.Host := Copy(Authority, 1, ColonPos - 1);
      PortText := Copy(Authority, ColonPos + 1, MaxInt);
    end;
  end;

  if Trim(Parsed.Host) = '' then
  begin
    ErrMsg := 'URL has no host';
    Exit;
  end;

  if PortText <> '' then
  begin
    PortNum := StrToIntDef(PortText, -1);
    if (PortNum < 1) or (PortNum > 65535) then
    begin
      ErrMsg := 'Invalid port';
      Exit;
    end;
    Parsed.Port := PortNum;
  end;

  Result := True;
  ErrKind := wfekNone;
  ErrMsg := '';
end;

function ValidateWebFetchTarget(const Parsed: TWebFetchUrl;
  out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;
begin
  Result := ValidateResolvedAddresses(Parsed.Host, ErrKind, ErrMsg);
end;

function BuildPinnedRequestUrl(const Parsed: TWebFetchUrl; const ConnectIP: string): string;
var
  PortPart: string;
  HostPart: string;
begin
  if (Parsed.Port = 80) and (not Parsed.Secure) then
    PortPart := ''
  else if (Parsed.Port = 443) and Parsed.Secure then
    PortPart := ''
  else
    PortPart := ':' + IntToStr(Parsed.Port);

  if Pos(':', ConnectIP) > 0 then
    HostPart := '[' + ConnectIP + ']'
  else
    HostPart := ConnectIP;

  Result := Parsed.Scheme + '://' + HostPart + PortPart + Parsed.Path;
end;

function SelectConnectAddress(const Parsed: TWebFetchUrl; out ConnectIP: string;
  out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;
var
  Addrs4: array[0..MaxHostResolveAddr - 1] of THostAddr;
  Addrs6: array[0..MaxHostResolveAddr - 1] of THostAddr6;
  N4, N6, I: Integer;
  V4: Cardinal;
  B6: array[0..15] of Byte;
begin
  Result := False;
  ConnectIP := '';
  if not ValidateWebFetchTarget(Parsed, ErrKind, ErrMsg) then Exit;

  if HostLooksLikeIPv4(Parsed.Host) then
  begin
    ConnectIP := Parsed.Host;
    Exit(True);
  end;

  if Pos(':', Parsed.Host) > 0 then
  begin
    ConnectIP := Parsed.Host;
    Exit(True);
  end;

  N4 := ResolveHostAddresses4(Parsed.Host, Addrs4);
  if N4 > 0 then
  begin
    for I := 0 to N4 - 1 do
    begin
      V4 := ntohl(LongWord(Addrs4[I]));
      if not IsBlockedIPv4(V4) then
      begin
        ConnectIP := IntToStr((V4 shr 24) and $FF) + '.' +
          IntToStr((V4 shr 16) and $FF) + '.' +
          IntToStr((V4 shr 8) and $FF) + '.' +
          IntToStr(V4 and $FF);
        Exit(True);
      end;
    end;
  end;

  N6 := ResolveHostAddresses6(Parsed.Host, Addrs6);
  if N6 > 0 then
  begin
    for I := 0 to N6 - 1 do
    begin
      Move(Addrs6[I].s6_addr, B6, 16);
      if not IsBlockedIPv6(B6) then
      begin
        ConnectIP := string(HostAddrToStr6(Addrs6[I]));
        Exit(True);
      end;
    end;
  end;

  ErrKind := wfekBlockedDestination;
  ErrMsg := 'Destination is not allowed';
end;

function ResolveRedirectUrl(const BaseUrl, Location: string;
  out Resolved: string; out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;
var
  Loc, BaseParsed: TWebFetchUrl;
  BaseTrim, L: string;
  Slash: SizeInt;
begin
  Result := False;
  ErrKind := wfekInvalidUrl;
  ErrMsg := 'Invalid redirect location';
  Resolved := '';
  L := Trim(Location);
  if L = '' then Exit;

  if (Pos('http://', LowerCase(L)) = 1) or (Pos('https://', LowerCase(L)) = 1) then
  begin
    if not ParseWebFetchUrl(L, Loc, ErrKind, ErrMsg) then Exit;
    Resolved := Loc.OriginalUrl;
    if not ValidateWebFetchTarget(Loc, ErrKind, ErrMsg) then Exit;
    Result := True;
    Exit;
  end;

  if not ParseWebFetchUrl(BaseUrl, BaseParsed, ErrKind, ErrMsg) then Exit;

  if L[1] = '/' then
  begin
    Resolved := BaseParsed.Scheme + '://' + BaseParsed.Host;
    if (BaseParsed.Port <> 80) and (not BaseParsed.Secure) or
       (BaseParsed.Secure and (BaseParsed.Port <> 443)) then
      Resolved := Resolved + ':' + IntToStr(BaseParsed.Port);
    Resolved := Resolved + L;
  end
  else
  begin
    BaseTrim := StripFragment(BaseUrl);
    Slash := Length(BaseTrim);
    while (Slash > 0) and (BaseTrim[Slash] <> '/') do
      Dec(Slash);
    if Slash = 0 then
      Resolved := BaseParsed.Scheme + '://' + BaseParsed.Host + '/' + L
    else
      Resolved := Copy(BaseTrim, 1, Slash) + L;
  end;

  if not ParseWebFetchUrl(Resolved, Loc, ErrKind, ErrMsg) then Exit;
  if not ValidateWebFetchTarget(Loc, ErrKind, ErrMsg) then Exit;
  Result := True;
end;

end.
