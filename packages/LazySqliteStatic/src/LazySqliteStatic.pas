unit LazySqliteStatic;

{$mode objfpc}{$H+}

{ Links the vendored SQLite amalgamation object into the executable (no system libsqlite3). }

interface

function LazySqliteEmbeddedVersion: PAnsiChar;

implementation

uses
  uSqlite3Embed;

function LazySqliteEmbeddedVersion: PAnsiChar;
begin
  Result := sqlite3_libversion;
end;

end.
