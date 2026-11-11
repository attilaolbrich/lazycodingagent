program test_security_manager;

{$mode objfpc}{$H+}

uses
  SysUtils, uSecurityManager;

procedure Fail(const Msg: string);
begin
  WriteLn('FAIL: ', Msg);
  Halt(1);
end;

procedure TestRoundTrip;
var
  Plain, Enc, Back: string;
begin
  Plain := 'sk-test-key-12345';
  Enc := EncryptSecret(Plain);
  if not IsEncryptedSecretBlob(Enc) then
    Fail('Encrypted blob missing prefix');
  Back := DecryptSecret(Enc);
  if Back <> Plain then
    Fail('Round-trip mismatch');
end;

procedure TestEmpty;
begin
  if EncryptSecret('') <> '' then
    Fail('Empty encrypt should be empty');
  if DecryptSecret('') <> '' then
    Fail('Empty decrypt should be empty');
end;

begin
  TestEmpty;
  TestRoundTrip;
  WriteLn('Security manager tests passed.');
end.
