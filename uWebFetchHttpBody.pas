unit uWebFetchHttpBody;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uWebFetchTypes;

function HttpHeaderValue(const Headers: TStrings; const Name: string): string;

function HttpContentEncodingFromHeaders(const Headers: TStrings): string;

function MaybeDecompressHttpBody(const Body: RawByteString; const ContentEncoding: string;
  out Decompressed: RawByteString; out ErrMsg: string): Boolean;

implementation

uses
  zbase, zinflate;

function HttpHeaderValue(const Headers: TStrings; const Name: string): string;
var
  I, SepPos: SizeInt;
  HeaderLine, HeaderKey, HeaderVal: string;
begin
  Result := '';
  if Headers = nil then
    Exit;
  for I := 0 to Headers.Count - 1 do
  begin
    if (Headers.Names[I] <> '') and SameText(Trim(Headers.Names[I]), Name) then
      Exit(Trim(Headers.ValueFromIndex[I]));
    HeaderLine := Headers[I];
    SepPos := Pos(':', HeaderLine);
    if SepPos > 0 then
    begin
      HeaderKey := Trim(System.Copy(HeaderLine, 1, SepPos - 1));
      HeaderVal := Trim(System.Copy(HeaderLine, SepPos + 1, Length(HeaderLine) - SepPos));
      if SameText(HeaderKey, Name) then
        Exit(HeaderVal);
    end;
  end;
end;

function FirstContentEncodingToken(const ContentEncoding: string): string;
var
  S, Part: string;
  Comma: SizeInt;
begin
  S := LowerCase(Trim(ContentEncoding));
  if S = '' then
    Exit('');
  Comma := Pos(',', S);
  if Comma > 0 then
    Part := Trim(System.Copy(S, 1, Comma - 1))
  else
    Part := S;
  if Pos(';', Part) > 0 then
    Part := Trim(System.Copy(Part, 1, Pos(';', Part) - 1));
  Result := Part;
end;

function HttpContentEncodingFromHeaders(const Headers: TStrings): string;
begin
  Result := FirstContentEncodingToken(HttpHeaderValue(Headers, 'Content-Encoding'));
end;

function GzipDeflateOffset(const Body: RawByteString): SizeInt;
var
  Cursor: SizeInt;
  Flg: Byte;
  XLen: Word;
begin
  Result := 0;
  if Length(Body) < 10 then
    Exit;
  if (Ord(Body[1]) <> $1F) or (Ord(Body[2]) <> $8B) then
    Exit;
  if Ord(Body[3]) <> 8 then
    Exit;
  Flg := Ord(Body[4]);
  Cursor := 11;
  if (Flg and $04) <> 0 then
  begin
    if Cursor + 1 > Length(Body) then
      Exit;
    XLen := Ord(Body[Cursor]) or (Ord(Body[Cursor + 1]) shl 8);
    Cursor := Cursor + 2 + XLen;
  end;
  if (Flg and $08) <> 0 then
  begin
    while (Cursor <= Length(Body)) and (Body[Cursor] <> #0) do
      Inc(Cursor);
    if Cursor > Length(Body) then
      Exit;
    Inc(Cursor);
  end;
  if (Flg and $10) <> 0 then
  begin
    while (Cursor <= Length(Body)) and (Body[Cursor] <> #0) do
      Inc(Cursor);
    if Cursor > Length(Body) then
      Exit;
    Inc(Cursor);
  end;
  if (Flg and $02) <> 0 then
    Cursor := Cursor + 2;
  if Cursor > Length(Body) then
    Exit;
  Result := Cursor;
end;

function InflateZlibStream(const Body: RawByteString; InOffset: SizeInt; RawDeflate: Boolean;
  MaxBytes: Int64; out Decompressed: RawByteString; out ErrMsg: string): Boolean;
const
  CHUNK = 16384;
var
  strm: z_stream;
  OutStream: TMemoryStream;
  OutChunk: array[0..CHUNK - 1] of Byte;
  Err: Integer;
  Produced: Integer;
  AvailIn: Integer;
begin
  Result := False;
  Decompressed := '';
  ErrMsg := '';
  if (InOffset < 1) or (InOffset > Length(Body)) then
  begin
    ErrMsg := 'Failed to decode compressed response';
    Exit;
  end;

  FillChar(strm, SizeOf(strm), 0);
  if RawDeflate then
    Err := inflateInit2(strm, -MAX_WBITS)
  else
    Err := inflateInit(strm);
  if Err <> Z_OK then
  begin
    ErrMsg := 'Failed to decode compressed response';
    Exit;
  end;

  OutStream := TMemoryStream.Create;
  try
    AvailIn := Length(Body) - InOffset + 1;
    strm.next_in := PByte(@Body[InOffset]);
    strm.avail_in := AvailIn;
    repeat
      strm.next_out := @OutChunk[0];
      strm.avail_out := CHUNK;
      Err := inflate(strm, Z_NO_FLUSH);
      if (Err <> Z_OK) and (Err <> Z_STREAM_END) and (Err <> Z_BUF_ERROR) then
      begin
        ErrMsg := 'Failed to decode compressed response';
        Exit;
      end;
      Produced := CHUNK - strm.avail_out;
      if Produced > 0 then
      begin
        if OutStream.Size + Produced > MaxBytes then
        begin
          ErrMsg := 'Response exceeds size limit';
          Exit;
        end;
        OutStream.Write(OutChunk[0], Produced);
      end;
      if (Err = Z_BUF_ERROR) and (Produced = 0) then
      begin
        ErrMsg := 'Failed to decode compressed response';
        Exit;
      end;
    until Err = Z_STREAM_END;

    SetLength(Decompressed, OutStream.Size);
    if OutStream.Size > 0 then
    begin
      OutStream.Position := 0;
      OutStream.ReadBuffer(Decompressed[1], OutStream.Size);
    end;
    Result := True;
  finally
    inflateEnd(strm);
    OutStream.Free;
  end;
end;

function InflateHttpEncodedBody(const Body: RawByteString; const ContentEncoding: string;
  MaxBytes: Int64; out Decompressed: RawByteString; out ErrMsg: string): Boolean;
var
  Enc: string;
  GzOff: SizeInt;
begin
  Enc := FirstContentEncodingToken(ContentEncoding);
  if (Enc = 'gzip') or (Enc = 'x-gzip') then
  begin
    GzOff := GzipDeflateOffset(Body);
    if GzOff = 0 then
    begin
      ErrMsg := 'Failed to decode compressed response';
      Exit(False);
    end;
    Result := InflateZlibStream(Body, GzOff, True, MaxBytes, Decompressed, ErrMsg);
    Exit;
  end;
  if Enc = 'deflate' then
  begin
    Result := InflateZlibStream(Body, 1, False, MaxBytes, Decompressed, ErrMsg);
    if Result then
      Exit;
    Result := InflateZlibStream(Body, 1, True, MaxBytes, Decompressed, ErrMsg);
    Exit;
  end;
  Decompressed := Body;
  Result := True;
end;

function MaybeDecompressHttpBody(const Body: RawByteString; const ContentEncoding: string;
  out Decompressed: RawByteString; out ErrMsg: string): Boolean;
var
  Enc: string;
begin
  Decompressed := Body;
  ErrMsg := '';
  Enc := FirstContentEncodingToken(ContentEncoding);
  if (Enc = '') or (Enc = 'identity') then
    Exit(True);
  if (Enc = 'gzip') or (Enc = 'x-gzip') or (Enc = 'deflate') then
  begin
    Result := InflateHttpEncodedBody(Body, Enc, WEB_FETCH_MAX_BODY_BYTES, Decompressed, ErrMsg);
    if Result and (Length(Body) > 0) and (Length(Decompressed) = 0) then
    begin
      Result := False;
      ErrMsg := 'Failed to decode compressed response';
    end;
  end
  else
    Result := True;
end;

end.
