unit uSqlitePanelLayoutRepository;

{$mode ObjFPC}{$H+}

interface

uses
  uRepositoryInterfaces, uSqlite3Embed;

type
  TSqlitePanelLayoutRepository = class(TInterfacedObject, IPanelLayoutRepository)
  private
    FDb: PSqlite3;
  public
    constructor Create(ADb: PSqlite3);
    procedure LoadAll(out ARows: TPanelLayoutRows);
    procedure SaveAll(const ARows: TPanelLayoutRows);
  end;

implementation

uses
  SysUtils, uSqliteCheck;

constructor TSqlitePanelLayoutRepository.Create(ADb: PSqlite3);
begin
  inherited Create;
  if ADb = nil then
    raise Exception.Create('TSqlitePanelLayoutRepository requires an open database');
  FDb := ADb;
end;

procedure TSqlitePanelLayoutRepository.LoadAll(out ARows: TPanelLayoutRows);
var
  Stmt: PSqlite3Stmt;
  N: Integer;
begin
  SetLength(ARows, 0);
  SqliteCheck(sqlite3_prepare_v2(FDb,
    'SELECT panel_ord, visible, floating, left_pos, top_pos, width, height, docked_height FROM panel_layout ORDER BY panel_ord',
    -1, @Stmt, nil), FDb, 'prepare panel_layout load');
  try
    N := 0;
    while sqlite3_step(Stmt) = SQLITE_ROW do
    begin
      SetLength(ARows, N + 1);
      ARows[N].PanelOrd := sqlite3_column_int(Stmt, 0);
      ARows[N].Visible := sqlite3_column_int(Stmt, 1) <> 0;
      ARows[N].Floating := sqlite3_column_int(Stmt, 2) <> 0;
      ARows[N].LeftPos := sqlite3_column_int(Stmt, 3);
      ARows[N].TopPos := sqlite3_column_int(Stmt, 4);
      ARows[N].Width := sqlite3_column_int(Stmt, 5);
      ARows[N].Height := sqlite3_column_int(Stmt, 6);
      ARows[N].DockedHeight := sqlite3_column_int(Stmt, 7);
      Inc(N);
    end;
  finally
    sqlite3_finalize(Stmt);
  end;
end;

procedure TSqlitePanelLayoutRepository.SaveAll(const ARows: TPanelLayoutRows);
var
  Stmt: PSqlite3Stmt;
  I: Integer;
  Err: PAnsiChar;
begin
  Err := nil;
  SqliteCheck(sqlite3_exec(FDb, 'DELETE FROM panel_layout;', nil, nil, @Err), FDb, 'clear panel_layout');
  if Err <> nil then sqlite3_free(Err);
  SqliteCheck(sqlite3_prepare_v2(FDb,
    'INSERT INTO panel_layout(panel_ord, visible, floating, left_pos, top_pos, width, height, docked_height) ' +
    'VALUES(?1,?2,?3,?4,?5,?6,?7,?8)', -1, @Stmt, nil), FDb, 'prepare panel_layout save');
  try
    for I := 0 to High(ARows) do
    begin
      SqliteCheck(sqlite3_bind_int(Stmt, 1, ARows[I].PanelOrd), FDb, 'bind ord');
      SqliteCheck(sqlite3_bind_int(Stmt, 2, Ord(ARows[I].Visible)), FDb, 'bind vis');
      SqliteCheck(sqlite3_bind_int(Stmt, 3, Ord(ARows[I].Floating)), FDb, 'bind float');
      SqliteCheck(sqlite3_bind_int(Stmt, 4, ARows[I].LeftPos), FDb, 'bind left');
      SqliteCheck(sqlite3_bind_int(Stmt, 5, ARows[I].TopPos), FDb, 'bind top');
      SqliteCheck(sqlite3_bind_int(Stmt, 6, ARows[I].Width), FDb, 'bind width');
      SqliteCheck(sqlite3_bind_int(Stmt, 7, ARows[I].Height), FDb, 'bind height');
      SqliteCheck(sqlite3_bind_int(Stmt, 8, ARows[I].DockedHeight), FDb, 'bind docked');
      SqliteStepDone(sqlite3_step(Stmt), FDb, 'step panel_layout save');
      SqliteCheck(sqlite3_reset(Stmt), FDb, 'reset panel_layout save');
    end;
  finally
    sqlite3_finalize(Stmt);
  end;
end;

end.
