unit uSqliteCheck;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, uSqlite3Embed;

function SqliteCheck(const ACode: Integer; ADb: PSqlite3; const AContext: string): Integer;
procedure SqliteStepDone(const ACode: Integer; ADb: PSqlite3; const AContext: string);

implementation

function SqliteCheck(const ACode: Integer; ADb: PSqlite3; const AContext: string): Integer;
begin
  if ACode <> SQLITE_OK then
    raise Exception.CreateFmt('%s: %s', [AContext, string(sqlite3_errmsg(ADb))]);
  Result := ACode;
end;

procedure SqliteStepDone(const ACode: Integer; ADb: PSqlite3; const AContext: string);
begin
  if ACode <> SQLITE_DONE then
    SqliteCheck(ACode, ADb, AContext);
end;

end.
