unit uSecurityManager;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils;

const
  LCA_SECRET_BLOB_PREFIX = 'lca-sec:v2:';
  LCA_SECRET_SALT_LEN = 16;

function IsEncryptedSecretBlob(const AValue: string): Boolean;
function EncryptSecret(const APlaintext: string): string;
function DecryptSecret(const AStored: string): string;

implementation

uses
  Classes, base64, sha1;

const
  LCA_DATA_KEY_SALT = 'LazyCodingAgent-data-v1';

{$I uAppBuiltInKey.inc}

function BuiltInKeyMaterial: TBytes;
var
  I: Integer;
begin
  SetLength(Result, 32);
  for I := 0 to 15 do
    Result[I] := LCA_KEY_PART_A[I] xor LCA_KEY_XOR_MASK;
  for I := 0 to 15 do
    Result[I + 16] := LCA_KEY_PART_B[I] xor LCA_KEY_XOR_MASK;
end;

function DerivedSecretKey: TBytes;
var
  Mat: TBytes;
  S, Raw: AnsiString;
  D1, D2: TSHA1Digest;
begin
  Mat := BuiltInKeyMaterial;
  SetLength(Raw, Length(Mat));
  if Length(Mat) > 0 then
    Move(Mat[0], Raw[1], Length(Mat));
  S := Raw + AnsiString(LCA_DATA_KEY_SALT);
  D1 := SHA1Buffer(S[1], Length(S));
  SetLength(S, Length(S) + SizeOf(D1));
  Move(D1[0], S[Length(S) - SizeOf(D1) + 1], SizeOf(D1));
  D2 := SHA1Buffer(S[1], Length(S));
  SetLength(Result, 32);
  Move(D1[0], Result[0], SizeOf(D1));
  Move(D2[0], Result[SizeOf(D1)], 12);
end;

function BytesToBase64(const B: TBytes): string;
var
  S: AnsiString;
begin
  if Length(B) = 0 then
    Exit('');
  SetLength(S, Length(B));
  Move(B[0], S[1], Length(B));
  Result := EncodeStringBase64(S);
end;

function Base64ToBytes(const S: string): TBytes;
var
  Dec: AnsiString;
  I: Integer;
begin
  Dec := DecodeStringBase64(AnsiString(S));
  SetLength(Result, Length(Dec));
  for I := 1 to Length(Dec) do
    Result[I - 1] := Ord(Dec[I]);
end;

procedure AppendLe32(var Buf: AnsiString; Value: Cardinal);
var
  Base: Integer;
begin
  Base := Length(Buf);
  SetLength(Buf, Base + 4);
  Buf[Base + 1] := Chr(Byte(Value and $FF));
  Buf[Base + 2] := Chr(Byte((Value shr 8) and $FF));
  Buf[Base + 3] := Chr(Byte((Value shr 16) and $FF));
  Buf[Base + 4] := Chr(Byte((Value shr 24) and $FF));
end;

function ExpandKeystream(const MasterKey, Salt: TBytes; Len: Integer): TBytes;
var
  Block: Cardinal;
  Input: AnsiString;
  Digest: TSHA1Digest;
  I, Offset, Take: Integer;
begin
  if Len <= 0 then
    Exit(nil);
  SetLength(Result, Len);
  Offset := 0;
  Block := 0;
  while Offset < Len do
  begin
    Input := '';
    if Length(MasterKey) > 0 then
    begin
      SetLength(Input, Length(MasterKey));
      Move(MasterKey[0], Input[1], Length(MasterKey));
    end;
    if Length(Salt) > 0 then
    begin
      SetLength(Input, Length(Input) + Length(Salt));
      Move(Salt[0], Input[Length(Input) - Length(Salt) + 1], Length(Salt));
    end;
    AppendLe32(Input, Block);
    Digest := SHA1Buffer(Input[1], Length(Input));
    Take := SizeOf(Digest);
    if Offset + Take > Len then
      Take := Len - Offset;
    for I := 0 to Take - 1 do
      Result[Offset + I] := Digest[I];
    Inc(Offset, Take);
    Inc(Block);
  end;
end;

procedure XorWithKeystream(var Data: TBytes; const Stream: TBytes);
var
  I: Integer;
begin
  if Length(Stream) = 0 then
    Exit;
  for I := 0 to High(Data) do
    Data[I] := Data[I] xor Stream[I mod Length(Stream)];
end;

procedure FillRandomSalt(var Salt: TBytes);
var
  I: Integer;
begin
  Randomize;
  SetLength(Salt, LCA_SECRET_SALT_LEN);
  for I := 0 to LCA_SECRET_SALT_LEN - 1 do
    Salt[I] := Random(256);
end;

function IsEncryptedSecretBlob(const AValue: string): Boolean;
begin
  Result := Copy(AValue, 1, Length(LCA_SECRET_BLOB_PREFIX)) = LCA_SECRET_BLOB_PREFIX;
end;

function EncryptSecret(const APlaintext: string): string;
var
  Master, Salt, Plain, Cipher, Stream, Blob: TBytes;
  PlainUtf8: UTF8String;
begin
  if Trim(APlaintext) = '' then
    Exit('');
  Master := DerivedSecretKey;
  FillRandomSalt(Salt);
  PlainUtf8 := UTF8Encode(APlaintext);
  SetLength(Plain, Length(PlainUtf8));
  if Length(PlainUtf8) > 0 then
    Move(PAnsiChar(PlainUtf8)^, Plain[0], Length(PlainUtf8));
  Cipher := Plain;
  Stream := ExpandKeystream(Master, Salt, Length(Cipher));
  XorWithKeystream(Cipher, Stream);
  SetLength(Blob, LCA_SECRET_SALT_LEN + Length(Cipher));
  Move(Salt[0], Blob[0], LCA_SECRET_SALT_LEN);
  if Length(Cipher) > 0 then
    Move(Cipher[0], Blob[LCA_SECRET_SALT_LEN], Length(Cipher));
  Result := LCA_SECRET_BLOB_PREFIX + BytesToBase64(Blob);
end;

function DecryptSecret(const AStored: string): string;
var
  Master, Salt, Blob, Cipher, Stream, Plain: TBytes;
  Payload: string;
  CipherLen: Integer;
  RS: RawByteString;
begin
  if Trim(AStored) = '' then
    Exit('');
  if not IsEncryptedSecretBlob(AStored) then
    Exit(AStored);
  Payload := Copy(AStored, Length(LCA_SECRET_BLOB_PREFIX) + 1, MaxInt);
  Blob := Base64ToBytes(Payload);
  if Length(Blob) < LCA_SECRET_SALT_LEN then
    raise Exception.Create('Invalid encrypted secret blob.');
  CipherLen := Length(Blob) - LCA_SECRET_SALT_LEN;
  SetLength(Salt, LCA_SECRET_SALT_LEN);
  Move(Blob[0], Salt[0], LCA_SECRET_SALT_LEN);
  SetLength(Cipher, CipherLen);
  if CipherLen > 0 then
    Move(Blob[LCA_SECRET_SALT_LEN], Cipher[0], CipherLen);
  Master := DerivedSecretKey;
  Stream := ExpandKeystream(Master, Salt, Length(Cipher));
  Plain := Cipher;
  XorWithKeystream(Plain, Stream);
  if Length(Plain) = 0 then
    Exit('');
  SetLength(RS, Length(Plain));
  Move(Plain[0], RS[1], Length(Plain));
  Result := UTF8ToString(RS);
end;

end.
