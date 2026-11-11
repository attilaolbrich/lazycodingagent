unit uHostDnsResolve;

{$mode objfpc}{$H+}

interface

uses
  Sockets;

const
  MaxHostResolveAddr = 10;

type
  THostAddr = in_addr;
  THostAddr6 = Tin6_addr;

function ResolveHostAddresses4(const Host: string; var Addrs: array of THostAddr): Integer;
function ResolveHostAddresses6(const Host: string; var Addrs: array of THostAddr6): Integer;
function ResolveFirstHost4NetOrder(const Host: string; out AddrNet: LongWord): Boolean;
function HostResolveLastErrorText: string;

implementation

{$IFDEF UNIX}
uses
  netdb;

function ResolveHostAddresses4(const Host: string; var Addrs: array of THostAddr): Integer;
var
  H: THostEntry;
begin
  Result := ResolveName(Host, Addrs);
  if Result <= 0 then
  begin
    if ResolveHostByName(Host, H) then
    begin
      if Length(Addrs) > 0 then
      begin
        Addrs[0] := H.Addr;
        Result := 1;
      end;
    end;
  end;
end;

function ResolveHostAddresses6(const Host: string; var Addrs: array of THostAddr6): Integer;
var
  H6: THostEntry6;
begin
  Result := ResolveName6(Host, Addrs);
  if Result <= 0 then
  begin
    if ResolveHostByName6(Host, H6) then
    begin
      if Length(Addrs) > 0 then
      begin
        Addrs[0] := H6.Addr;
        Result := 1;
      end;
    end;
  end;
end;

function ResolveFirstHost4NetOrder(const Host: string; out AddrNet: LongWord): Boolean;
var
  H: THostEntry;
begin
  Result := ResolveHostByName(Host, H);
  if Result then
    AddrNet := LongWord(H.Addr);
end;

function HostResolveLastErrorText: string;
begin
  Result := '';
end;

{$ELSE}

uses
  SysUtils, Winsock2;

type
  PADDRINFOA = ^ADDRINFOA;
  PPADDRINFOA = ^PADDRINFOA;
  ADDRINFOA = record
    ai_flags: DWORD;
    ai_family: Integer;
    ai_socktype: Integer;
    ai_protocol: Integer;
    ai_addrlen: NativeUInt;
    ai_canonname: PAnsiChar;
    ai_addr: Pointer;
    ai_next: PADDRINFOA;
  end;

function getaddrinfo(NodeName, ServiceName: PAnsiChar; Hints: PADDRINFOA;
  Res: PPADDRINFOA): Integer; stdcall; external 'ws2_32.dll' name 'getaddrinfo';
procedure freeaddrinfo(AddrInfo: PADDRINFOA); stdcall; external 'ws2_32.dll' name 'freeaddrinfo';

const
  WSAHOST_NOT_FOUND = 11001;
  WSATRY_AGAIN = 11002;
  WSANO_RECOVERY = 11003;
  WSANO_DATA = 11004;
  WSAEINVAL = 10022;
  WSAEAFNOSUPPORT = 10047;
  WSAESOCKTNOSUPPORT = 10044;
  WSASERVICE_NOT_FOUND = 10109;
  EAI_AGAIN = 2;
  EAI_BADFLAGS = 3;
  EAI_FAIL = 4;
  EAI_FAMILY = 5;
  EAI_MEMORY = 6;
  EAI_NODATA = 7;
  EAI_NONAME = 8;
  EAI_SERVICE = 9;
  EAI_SOCKTYPE = 10;

function GaiErrorText(Rc: Integer): string;
begin
  case Rc of
    WSAHOST_NOT_FOUND, EAI_NONAME:
      Result := 'Host not found';
    WSATRY_AGAIN, EAI_AGAIN:
      Result := 'Temporary failure in name resolution';
    WSANO_RECOVERY, EAI_FAIL:
      Result := 'Non-recoverable failure in name resolution';
    WSANO_DATA, EAI_NODATA:
      Result := 'No address associated with hostname';
    WSAEINVAL, EAI_BADFLAGS:
      Result := 'Invalid argument';
    WSAEAFNOSUPPORT, EAI_FAMILY:
      Result := 'Address family not supported';
    WSAESOCKTNOSUPPORT, EAI_SOCKTYPE:
      Result := 'Socket type not supported';
    WSASERVICE_NOT_FOUND, EAI_SERVICE:
      Result := 'Service not found';
    EAI_MEMORY:
      Result := 'Memory allocation failure';
  else
    Result := 'getaddrinfo failed (' + IntToStr(Rc) + ')';
  end;
end;

var
  GWsaStarted: Boolean = False;
  GHostResolveLastError: string = '';
  GResolveCacheHost: string = '';
  GResolveCacheFilled: Boolean = False;
  GResolveCacheN4: Integer = 0;
  GResolveCacheN6: Integer = 0;
  GResolveCacheAddrs4: array[0..MaxHostResolveAddr - 1] of THostAddr;
  GResolveCacheAddrs6: array[0..MaxHostResolveAddr - 1] of THostAddr6;

function HostResolveLastErrorText: string;
begin
  Result := GHostResolveLastError;
end;

procedure EnsureWsaStarted;
var
  Wsa: TWsaData;
begin
  if GWsaStarted then
    Exit;
  if WSAStartup($0202, Wsa) = 0 then
    GWsaStarted := True
  else
    GHostResolveLastError := 'WSAStartup failed';
end;

procedure FillHostResolveCache(const Host: string);
var
  Head, Cur: PADDRINFOA;
  Sock4: PSockAddrIn;
  Sock6: PSockAddrIn6;
  Rc: Integer;
begin
  if GResolveCacheFilled and SameText(GResolveCacheHost, Host) then
    Exit;

  GResolveCacheHost := Host;
  GResolveCacheFilled := True;
  GResolveCacheN4 := 0;
  GResolveCacheN6 := 0;
  GHostResolveLastError := '';

  if Length(Host) = 0 then
  begin
    GHostResolveLastError := 'Empty hostname';
    Exit;
  end;

  EnsureWsaStarted;
  if not GWsaStarted then
    Exit;

  Head := nil;
  Rc := getaddrinfo(PAnsiChar(AnsiString(Host)), nil, nil, @Head);
  if Rc <> 0 then
  begin
    GHostResolveLastError := GaiErrorText(Rc);
    Exit;
  end;

  if Head = nil then
  begin
    GHostResolveLastError := 'No addresses returned';
    Exit;
  end;

  Cur := Head;
  while Cur <> nil do
  begin
    if (Cur^.ai_family = AF_INET) and (GResolveCacheN4 < MaxHostResolveAddr) then
    begin
      Sock4 := PSockAddrIn(Cur^.ai_addr);
      Move(Sock4^.sin_addr, GResolveCacheAddrs4[GResolveCacheN4], SizeOf(THostAddr));
      Inc(GResolveCacheN4);
    end
    else if (Cur^.ai_family = AF_INET6) and (GResolveCacheN6 < MaxHostResolveAddr) then
    begin
      Sock6 := PSockAddrIn6(Cur^.ai_addr);
      Move(Sock6^.sin6_addr, GResolveCacheAddrs6[GResolveCacheN6], SizeOf(THostAddr6));
      Inc(GResolveCacheN6);
    end;
    Cur := Cur^.ai_next;
  end;
  freeaddrinfo(Head);

  if (GResolveCacheN4 = 0) and (GResolveCacheN6 = 0) then
    GHostResolveLastError := 'No addresses returned';
end;

function ResolveHostAddresses4(const Host: string; var Addrs: array of THostAddr): Integer;
var
  I: Integer;
begin
  Result := 0;
  if Length(Addrs) = 0 then
    Exit;
  FillHostResolveCache(Host);
  for I := 0 to GResolveCacheN4 - 1 do
  begin
    if I >= Length(Addrs) then
      Break;
    Addrs[I] := GResolveCacheAddrs4[I];
    Inc(Result);
  end;
end;

function ResolveHostAddresses6(const Host: string; var Addrs: array of THostAddr6): Integer;
var
  I: Integer;
begin
  Result := 0;
  if Length(Addrs) = 0 then
    Exit;
  FillHostResolveCache(Host);
  for I := 0 to GResolveCacheN6 - 1 do
  begin
    if I >= Length(Addrs) then
      Break;
    Addrs[I] := GResolveCacheAddrs6[I];
    Inc(Result);
  end;
end;

function ResolveFirstHost4NetOrder(const Host: string; out AddrNet: LongWord): Boolean;
var
  Addrs: array[0..0] of THostAddr;
begin
  Result := ResolveHostAddresses4(Host, Addrs) > 0;
  if Result then
    AddrNet := LongWord(Addrs[0].S_addr);
end;

{$ENDIF}

end.
