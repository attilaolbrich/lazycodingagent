unit uSqlite3Embed;

{$mode objfpc}{$H+}
{$packrecords C}

{ Minimal SQLite3 C API bindings for statically linked amalgamation.
  Windows default: MinGW-w64 sqlite3_embed.o + uSqliteWinEmbedBridge (Win32 forwarders) + MinGW import libs at link.
  LCA_SQLITE_USE_WINSQLITE3: OS winsqlite3.dll fallback.
  LCA_SQLITE_EMBED_WIN: MSVC sqlite3_embed.o + bridge (experimental; init still unreliable). }

interface

uses
  ctypes;

const
  SQLITE_OK = 0;
  SQLITE_ROW = 100;
  SQLITE_DONE = 101;
  SQLITE_ERROR = 1;

  SQLITE_OPEN_READWRITE = $00000002;
  SQLITE_OPEN_CREATE = $00000004;

  SQLITE_TRANSIENT = Pointer(-1);

type
  PSqlite3 = Pointer;
  PPSqlite3 = ^PSqlite3;
  PSqlite3Stmt = Pointer;
  PPSqlite3Stmt = ^PSqlite3Stmt;

function sqlite3_libversion: PAnsiChar; cdecl;
function sqlite3_open_v2(filename: PAnsiChar; ppDb: PPSqlite3; flags: cint; zVfs: PAnsiChar): cint; cdecl;
function sqlite3_close(db: PSqlite3): cint; cdecl;
function sqlite3_errmsg(db: PSqlite3): PAnsiChar; cdecl;
function sqlite3_exec(db: PSqlite3; sql: PAnsiChar; callback: Pointer; arg: Pointer; errmsg: PPAnsiChar): cint; cdecl;
procedure sqlite3_free(ptr: Pointer); cdecl;
function sqlite3_prepare_v2(db: PSqlite3; zSql: PAnsiChar; nByte: cint; ppStmt: PPSqlite3Stmt; pzTail: PPAnsiChar): cint; cdecl;
function sqlite3_finalize(pStmt: PSqlite3Stmt): cint; cdecl;
function sqlite3_step(pStmt: PSqlite3Stmt): cint; cdecl;
function sqlite3_bind_text(pStmt: PSqlite3Stmt; i: cint; z: PAnsiChar; n: cint; xDel: Pointer): cint; cdecl;
function sqlite3_bind_int(pStmt: PSqlite3Stmt; i: cint; iValue: cint): cint; cdecl;
function sqlite3_reset(pStmt: PSqlite3Stmt): cint; cdecl;
function sqlite3_column_text(pStmt: PSqlite3Stmt; iCol: cint): PAnsiChar; cdecl;
function sqlite3_column_int(pStmt: PSqlite3Stmt; iCol: cint): cint; cdecl;

implementation

{$ifdef MSWINDOWS}
  {$ifdef LCA_SQLITE_USE_WINSQLITE3}
  {$else}
    {$ifdef LCA_SQLITE_EMBED_WIN}
    {$else}
      {$define LCA_SQLITE_MINGW_EMBED}
    {$endif}
  {$endif}
{$endif}

{$ifdef LCA_SQLITE_USE_WINSQLITE3}
const
  SQLITE_DLL = 'winsqlite3.dll';
{$else}
  {$ifdef MSWINDOWS}
  uses
    uSqliteWinEmbedBridge;
  {$endif}
  {$ifdef UNIX}
    {$linklib c}
    {$linklib m}
    {$ifdef CPUAARCH64}
    {$ifdef LINUX}
    {$linklib gcc_s}
    {$endif}
    {$endif}
  {$endif}
  { MinGW CRT/kernel imports: resolved at final link via -Fl/-k to MinGW lib dir (see build docs). }
{$endif}

{$ifdef LCA_SQLITE_USE_WINSQLITE3}
function sqlite3_libversion: PAnsiChar; cdecl; external SQLITE_DLL name 'sqlite3_libversion';
function sqlite3_open_v2(filename: PAnsiChar; ppDb: PPSqlite3; flags: cint; zVfs: PAnsiChar): cint; cdecl;
  external SQLITE_DLL name 'sqlite3_open_v2';
function sqlite3_close(db: PSqlite3): cint; cdecl; external SQLITE_DLL name 'sqlite3_close';
function sqlite3_errmsg(db: PSqlite3): PAnsiChar; cdecl; external SQLITE_DLL name 'sqlite3_errmsg';
function sqlite3_exec(db: PSqlite3; sql: PAnsiChar; callback: Pointer; arg: Pointer; errmsg: PPAnsiChar): cint; cdecl;
  external SQLITE_DLL name 'sqlite3_exec';
procedure sqlite3_free(ptr: Pointer); cdecl; external SQLITE_DLL name 'sqlite3_free';
function sqlite3_prepare_v2(db: PSqlite3; zSql: PAnsiChar; nByte: cint; ppStmt: PPSqlite3Stmt; pzTail: PPAnsiChar): cint; cdecl;
  external SQLITE_DLL name 'sqlite3_prepare_v2';
function sqlite3_finalize(pStmt: PSqlite3Stmt): cint; cdecl; external SQLITE_DLL name 'sqlite3_finalize';
function sqlite3_step(pStmt: PSqlite3Stmt): cint; cdecl; external SQLITE_DLL name 'sqlite3_step';
function sqlite3_bind_text(pStmt: PSqlite3Stmt; i: cint; z: PAnsiChar; n: cint; xDel: Pointer): cint; cdecl;
  external SQLITE_DLL name 'sqlite3_bind_text';
function sqlite3_bind_int(pStmt: PSqlite3Stmt; i: cint; iValue: cint): cint; cdecl;
  external SQLITE_DLL name 'sqlite3_bind_int';
function sqlite3_reset(pStmt: PSqlite3Stmt): cint; cdecl; external SQLITE_DLL name 'sqlite3_reset';
function sqlite3_column_text(pStmt: PSqlite3Stmt; iCol: cint): PAnsiChar; cdecl;
  external SQLITE_DLL name 'sqlite3_column_text';
function sqlite3_column_int(pStmt: PSqlite3Stmt; iCol: cint): cint; cdecl;
  external SQLITE_DLL name 'sqlite3_column_int';
{$else}
function sqlite3_libversion: PAnsiChar; cdecl; external;
function sqlite3_open_v2(filename: PAnsiChar; ppDb: PPSqlite3; flags: cint; zVfs: PAnsiChar): cint; cdecl; external;
function sqlite3_close(db: PSqlite3): cint; cdecl; external;
function sqlite3_errmsg(db: PSqlite3): PAnsiChar; cdecl; external;
function sqlite3_exec(db: PSqlite3; sql: PAnsiChar; callback: Pointer; arg: Pointer; errmsg: PPAnsiChar): cint; cdecl; external;
procedure sqlite3_free(ptr: Pointer); cdecl; external;
function sqlite3_prepare_v2(db: PSqlite3; zSql: PAnsiChar; nByte: cint; ppStmt: PPSqlite3Stmt; pzTail: PPAnsiChar): cint; cdecl; external;
function sqlite3_finalize(pStmt: PSqlite3Stmt): cint; cdecl; external;
function sqlite3_step(pStmt: PSqlite3Stmt): cint; cdecl; external;
function sqlite3_bind_text(pStmt: PSqlite3Stmt; i: cint; z: PAnsiChar; n: cint; xDel: Pointer): cint; cdecl; external;
function sqlite3_bind_int(pStmt: PSqlite3Stmt; i: cint; iValue: cint): cint; cdecl; external;
function sqlite3_reset(pStmt: PSqlite3Stmt): cint; cdecl; external;
function sqlite3_column_text(pStmt: PSqlite3Stmt; iCol: cint): PAnsiChar; cdecl; external;
function sqlite3_column_int(pStmt: PSqlite3Stmt; iCol: cint): cint; cdecl; external;

{$L sqlite3_embed.o}
{$endif}

end.
