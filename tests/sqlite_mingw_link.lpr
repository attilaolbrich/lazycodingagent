program sqlite_mingw_link;

{$mode objfpc}{$H+}

uses
  SysUtils, ctypes, uSqlite3Embed;

var
  Db: PSqlite3;
  RC: cint;
begin
  WriteLn('libversion=', string(sqlite3_libversion()));
  RC := sqlite3_open_v2(':memory:', @Db, SQLITE_OPEN_READWRITE, nil);
  WriteLn('open rc=', RC);
  if Db <> nil then
    sqlite3_close(Db);
  WriteLn('ok');
end.
