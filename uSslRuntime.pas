unit uSslRuntime;

{$mode objfpc}{$H+}

interface

function EnsureOpenSslAvailable: Boolean;
function OpenSslUnavailableUserMessage: string;

implementation

{$IFDEF MSWINDOWS}
function EnsureOpenSslAvailable: Boolean;
begin
  Result := True;
end;

function OpenSslUnavailableUserMessage: string;
begin
  Result := '';
end;
{$ELSE}
uses
  openssl;

function EnsureOpenSslAvailable: Boolean;
begin
  Result := InitSSLInterface;
end;

function OpenSslUnavailableUserMessage: string;
begin
  Result := 'HTTPS requires OpenSSL 3. On Debian, Ubuntu, or Raspberry Pi OS run: ' +
    'sudo apt install libssl3' +
    ' (package may be libssl3t64 on newer releases). Then restart LazyCodingAgent.';
end;
{$ENDIF}

end.
