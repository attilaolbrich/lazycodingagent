unit uCdpWebSocket;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

function CdpWebSocketAcceptKey(const ClientKey: AnsiString): AnsiString;

type
  TCdpWebSocket = class
  private
    FSocket: LongInt;
    FConnected: Boolean;
    FReadBuf: RawByteString;
    function ReadMore(TimeoutMs: Integer): Boolean;
    function BuildClientKey: AnsiString;
    function ParseOneFrame(out Opcode: Byte; out Payload: RawByteString): Boolean;
    procedure SetSocketTimeout(Ms: Integer);
  public
    destructor Destroy; override;
    function Connect(const Host: string; Port: Word; const Path: string;
      TimeoutMs: Integer; out ErrMsg: string): Boolean;
    procedure Disconnect;
    function Connected: Boolean;
    function SendText(const Text: UTF8String): Boolean;
    function TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean;
  end;

implementation

uses
  sha1, base64, Math, Sockets, uHostDnsResolve, ctypes
  {$IFDEF UNIX}, BaseUnix, Unix{$ENDIF};

const
  LCA_INVALID_SOCKET = TSocket(-1);
  WS_MAGIC: AnsiString = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

function CdpWebSocketAcceptKey(const ClientKey: AnsiString): AnsiString;
var
  D: TSHA1Digest;
  Combined: AnsiString;
  Bin: AnsiString;
begin
  Combined := ClientKey + WS_MAGIC;
  D := SHA1Buffer(Combined[1], Length(Combined));
  SetLength(Bin, SizeOf(D));
  Move(D[0], Bin[1], SizeOf(D));
  Result := EncodeStringBase64(Bin);
end;

function SameBase64(const A, B: AnsiString): Boolean;
begin
  Result := SameText(Trim(A), Trim(B));
end;

function ParseIPv4Literal(const Host: string; out NetAddr: Cardinal): Boolean;
var
  Parts: TStringArray;
  I, V: Integer;
  B: Cardinal;
begin
  NetAddr := 0;
  Parts := Host.Split(['.']);
  if Length(Parts) <> 4 then
    Exit(False);
  for I := 0 to 3 do
  begin
    if Parts[I] = '' then
      Exit(False);
    V := StrToIntDef(Parts[I], -1);
    if (V < 0) or (V > 255) then
      Exit(False);
    B := Cardinal(V);
    NetAddr := NetAddr or (B shl ((3 - I) * 8));
  end;
  Result := True;
end;

function HttpStatusIs101(const StatusLine: AnsiString): Boolean;
var
  Parts: TStringArray;
  Code: Integer;
begin
  Parts := string(StatusLine).Split([' '], 3);
  if Length(Parts) < 2 then
    Exit(False);
  if not SameText(Parts[0], 'HTTP/1.1') and not SameText(Parts[0], 'HTTP/1.0') then
    Exit(False);
  Code := StrToIntDef(Trim(Parts[1]), 0);
  Result := Code = 101;
end;

function TCdpWebSocket.BuildClientKey: AnsiString;
const
  Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
var
  I: Integer;
  Raw: AnsiString;
begin
  SetLength(Raw, 16);
  Randomize;
  for I := 1 to 16 do
    Raw[I] := Chars[1 + Random(Length(Chars))];
  Result := EncodeStringBase64(Raw);
end;

procedure TCdpWebSocket.SetSocketTimeout(Ms: Integer);
{$IFDEF UNIX}
var
  Tv: timeval;
begin
  if FSocket = LCA_INVALID_SOCKET then Exit;
  Tv.tv_sec := Ms div 1000;
  Tv.tv_usec := (Ms mod 1000) * 1000;
  fpsetsockopt(FSocket, SOL_SOCKET, SO_RCVTIMEO, @Tv, SizeOf(Tv));
  fpsetsockopt(FSocket, SOL_SOCKET, SO_SNDTIMEO, @Tv, SizeOf(Tv));
end;
{$ELSE}
var
  Opt: LongInt;
  Len: LongInt;
begin
  if FSocket = LCA_INVALID_SOCKET then Exit;
  Opt := Ms;
  if Opt < 1 then
    Opt := 1;
  Len := SizeOf(Opt);
  fpsetsockopt(FSocket, SOL_SOCKET, SO_RCVTIMEO, @Opt, Len);
  fpsetsockopt(FSocket, SOL_SOCKET, SO_SNDTIMEO, @Opt, Len);
end;
{$ENDIF}

destructor TCdpWebSocket.Destroy;
begin
  Disconnect;
  inherited Destroy;
end;

procedure TCdpWebSocket.Disconnect;
begin
  FConnected := False;
  if (FSocket <> 0) and (FSocket <> LCA_INVALID_SOCKET) then
  begin
    {$IFDEF UNIX}
    fpClose(FSocket);
    {$ELSE}
    closesocket(FSocket);
    {$ENDIF}
    FSocket := LCA_INVALID_SOCKET;
  end;
  FReadBuf := '';
end;

function TCdpWebSocket.ReadMore(TimeoutMs: Integer): Boolean;
var
  Chunk: array[0..8191] of Byte;
  Tmp: RawByteString;
  N: Integer;
begin
  if FSocket = LCA_INVALID_SOCKET then Exit(False);
  SetSocketTimeout(TimeoutMs);
  N := fpRecv(FSocket, @Chunk[0], SizeOf(Chunk), 0);
  if N <= 0 then Exit(False);
  SetLength(Tmp, N);
  Move(Chunk[0], Tmp[1], N);
  FReadBuf := FReadBuf + Tmp;
  Result := True;
end;

function TCdpWebSocket.Connect(const Host: string; Port: Word; const Path: string;
  TimeoutMs: Integer; out ErrMsg: string): Boolean;
var
  Req, Resp, Line, Key, AcceptExpected, AcceptGot, P, StatusLine: AnsiString;
  I, PPos, N, HeaderEnd: Integer;
  Addr: sockaddr_in;
  AcceptFound: Boolean;
  V4: Cardinal;
begin
  Result := False;
  ErrMsg := '';
  Disconnect;
  FSocket := fpsocket(AF_INET, SOCK_STREAM, 0);
  if FSocket = LCA_INVALID_SOCKET then
  begin
    ErrMsg := 'Could not create TCP socket';
    Exit;
  end;
  SetSocketTimeout(TimeoutMs);

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(Port);
  if ParseIPv4Literal(Host, V4) then
    Addr.sin_addr.s_addr := htonl(V4)
  else if not ResolveFirstHost4NetOrder(Host, Addr.sin_addr.s_addr) then
  begin
    ErrMsg := 'Could not resolve host: ' + Host;
    Disconnect;
    Exit;
  end;

  if fpConnect(FSocket, @Addr, SizeOf(Addr)) <> 0 then
  begin
    ErrMsg := 'TCP connect failed to ' + Host + ':' + IntToStr(Port);
    Disconnect;
    Exit;
  end;

  Key := BuildClientKey;
  AcceptExpected := CdpWebSocketAcceptKey(Key);
  P := AnsiString(Path);
  if (P = '') or (P[1] <> '/') then
    P := '/' + P;
  Req :=
    'GET ' + P + ' HTTP/1.1' + #13#10 +
    'Host: ' + AnsiString(Host) + ':' + AnsiString(IntToStr(Port)) + #13#10 +
    'Upgrade: websocket' + #13#10 +
    'Connection: Upgrade' + #13#10 +
    'Sec-WebSocket-Key: ' + Key + #13#10 +
    'Sec-WebSocket-Version: 13' + #13#10#13#10;
  N := fpSend(FSocket, Pointer(Req), Length(Req), 0);
  if N <> Length(Req) then
  begin
    ErrMsg := 'Failed to send WebSocket upgrade request';
    Disconnect;
    Exit;
  end;

  Resp := '';
  while Pos(#13#10#13#10, Resp) = 0 do
  begin
    if not ReadMore(TimeoutMs) then
    begin
      ErrMsg := 'Timed out waiting for WebSocket handshake response';
      Disconnect;
      Exit;
    end;
    Resp := Resp + FReadBuf;
    FReadBuf := '';
    if Length(Resp) > 16384 then
    begin
      ErrMsg := 'WebSocket handshake response too large';
      Disconnect;
      Exit;
    end;
  end;

  HeaderEnd := Pos(#13#10#13#10, Resp);
  StatusLine := Copy(Resp, 1, HeaderEnd - 1);
  if Pos(#13#10, StatusLine) > 0 then
    StatusLine := Copy(StatusLine, 1, Pos(#13#10, StatusLine) - 1);
  if (Length(StatusLine) > 0) and (StatusLine[Length(StatusLine)] = #13) then
    SetLength(StatusLine, Length(StatusLine) - 1);

  if not HttpStatusIs101(StatusLine) then
  begin
    ErrMsg := 'Expected HTTP 101 Switching Protocols, got: ' + string(StatusLine);
    Disconnect;
    Exit;
  end;

  AcceptFound := False;
  AcceptGot := '';
  I := 1;
  while I <= Length(Resp) do
  begin
    PPos := Pos(#10, Copy(Resp, I, MaxInt));
    if PPos = 0 then
      Line := Copy(Resp, I, MaxInt)
    else
      Line := Copy(Resp, I, PPos - 1);
    if (Length(Line) > 0) and (Line[Length(Line)] = #13) then
      SetLength(Line, Length(Line) - 1);
    if Pos('Sec-WebSocket-Accept:', string(Line)) > 0 then
    begin
      AcceptGot := Trim(Copy(Line, Pos(':', Line) + 1, MaxInt));
      AcceptFound := True;
      if not SameBase64(AcceptGot, AcceptExpected) then
      begin
        ErrMsg := 'Sec-WebSocket-Accept mismatch';
        Disconnect;
        Exit;
      end;
    end;
    if PPos = 0 then Break;
    I := I + PPos;
  end;

  if not AcceptFound then
  begin
    ErrMsg := 'WebSocket handshake missing Sec-WebSocket-Accept header';
    Disconnect;
    Exit;
  end;

  FConnected := True;
  Result := True;
end;

function TCdpWebSocket.Connected: Boolean;
begin
  Result := FConnected and (FSocket <> LCA_INVALID_SOCKET);
end;

function TCdpWebSocket.SendText(const Text: UTF8String): Boolean;
var
  Payload, Frame: RawByteString;
  Len: QWord;
  I: Integer;
  Mask: array[0..3] of Byte;
  N: Integer;
begin
  if not Connected then Exit(False);
  Payload := Text;
  Len := Length(Payload);
  Frame := '';
  Frame := Frame + AnsiChar($81);
  if Len < 126 then
    Frame := Frame + AnsiChar(Ord(Len) or $80)
  else if Len < 65536 then
  begin
    Frame := Frame + AnsiChar($FE);
    Frame := Frame + AnsiChar((Len shr 8) and $FF);
    Frame := Frame + AnsiChar(Len and $FF);
  end
  else
  begin
    Frame := Frame + AnsiChar($FF);
    for I := 7 downto 0 do
      Frame := Frame + AnsiChar((Len shr (I * 8)) and $FF);
  end;
  Randomize;
  Mask[0] := Random(256);
  Mask[1] := Random(256);
  Mask[2] := Random(256);
  Mask[3] := Random(256);
  Frame := Frame + AnsiChar(Mask[0]) + AnsiChar(Mask[1]) + AnsiChar(Mask[2]) + AnsiChar(Mask[3]);
  Frame := Frame + Payload;
  for I := 1 to Length(Payload) do
    Frame[Length(Frame) - Length(Payload) + I] :=
      AnsiChar(Ord(Frame[Length(Frame) - Length(Payload) + I]) xor Mask[(I - 1) mod 4]);
  N := fpSend(FSocket, Pointer(Frame), Length(Frame), 0);
  Result := N = Length(Frame);
end;

function TCdpWebSocket.ParseOneFrame(out Opcode: Byte; out Payload: RawByteString): Boolean;
var
  B0, B1: Byte;
  Masked: Boolean;
  PayloadLen: QWord;
  Mask: array[0..3] of Byte;
  HeaderLen: Integer;
  I: Integer;
begin
  Result := False;
  Opcode := 0;
  Payload := '';
  if Length(FReadBuf) < 2 then Exit;
  B0 := Ord(FReadBuf[1]);
  B1 := Ord(FReadBuf[2]);
  Opcode := B0 and $0F;
  Masked := (B1 and $80) <> 0;
  PayloadLen := B1 and $7F;
  HeaderLen := 2;
  if PayloadLen = 126 then
  begin
    if Length(FReadBuf) < 4 then Exit;
    PayloadLen := (Ord(FReadBuf[3]) shl 8) or Ord(FReadBuf[4]);
    HeaderLen := 4;
  end
  else if PayloadLen = 127 then
  begin
    if Length(FReadBuf) < 10 then Exit;
    PayloadLen := 0;
    for I := 0 to 7 do
      PayloadLen := (PayloadLen shl 8) or Ord(FReadBuf[3 + I]);
    HeaderLen := 10;
  end;
  if Masked then
    HeaderLen := HeaderLen + 4;
  if Int64(Length(FReadBuf)) < HeaderLen + Int64(PayloadLen) then Exit;
  if Masked then
  begin
    Mask[0] := Ord(FReadBuf[HeaderLen - 3]);
    Mask[1] := Ord(FReadBuf[HeaderLen - 2]);
    Mask[2] := Ord(FReadBuf[HeaderLen - 1]);
    Mask[3] := Ord(FReadBuf[HeaderLen]);
  end;
  Payload := Copy(FReadBuf, HeaderLen + 1, PayloadLen);
  FReadBuf := Copy(FReadBuf, HeaderLen + PayloadLen + 1, MaxInt);
  if Masked then
    for I := 1 to Length(Payload) do
      Payload[I] := AnsiChar(Ord(Payload[I]) xor Mask[(I - 1) mod 4]);
  Result := True;
end;

function TCdpWebSocket.TryReceiveText(out Text: UTF8String; TimeoutMs: Integer): Boolean;
var
  Opcode: Byte;
  Payload: RawByteString;
begin
  Text := '';
  Result := False;
  if not Connected then Exit;
  while True do
  begin
    if not ParseOneFrame(Opcode, Payload) then
    begin
      if not ReadMore(TimeoutMs) then Exit;
      if not ParseOneFrame(Opcode, Payload) then Exit;
    end;
    if Opcode = 8 then
    begin
      FConnected := False;
      Exit;
    end;
    if Opcode = 9 then
      Continue;
    if Opcode = 1 then
    begin
      Text := UTF8String(Payload);
      Exit(True);
    end;
  end;
end;

end.
