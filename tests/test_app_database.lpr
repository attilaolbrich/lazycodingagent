program test_app_database;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, uAppDatabase;

function TempDataRoot: string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir) + 'lca-dbtest-' + IntToStr(GetProcessID);
end;

procedure Fail(const Msg: string);
begin
  WriteLn('FAIL: ', Msg);
  Halt(1);
end;

procedure TestGlobalRoundTrip(const Probe: string);
var
  ReadBack: string;
  DbPath: string;
begin
  TAppDatabase.SetConfigRootOverride(TempDataRoot);
  TAppDatabase.OpenGlobal;
  try
    if TAppDatabase.SchemaVersion(adsGlobal) <> 2 then
      Fail('Expected schema version 2 on global database');
    TAppDatabase.GlobalSettings.SetString('m0.probe', Probe);
  finally
    TAppDatabase.CloseGlobal;
  end;
  DbPath := TAppDatabase.ConfigRoot + 'global.db';
  if not FileExists(DbPath) then
    Fail('global.db was not created at ' + DbPath);
  TAppDatabase.OpenGlobal;
  try
    if not TAppDatabase.GlobalSettings.TryGet('m0.probe', ReadBack) then
      Fail('m0.probe missing after reopen');
    if ReadBack <> Probe then
      Fail('m0.probe value mismatch after reopen');
    if TAppDatabase.SchemaVersion(adsGlobal) <> 2 then
      Fail('Schema version mismatch after reopen');
  finally
    TAppDatabase.CloseGlobal;
  end;
end;

procedure TestWorkspaceRoundTrip(const Probe: string);
var
  ReadBack: string;
  WsId: string;
  DbPath: string;
begin
  WsId := 'test-ws-1';
  TAppDatabase.SetConfigRootOverride(TempDataRoot);
  TAppDatabase.OpenWorkspace(WsId);
  try
    TAppDatabase.WorkspaceSettings(WsId).SetString('ws.smoke', Probe);
  finally
    TAppDatabase.CloseWorkspace(WsId);
  end;
  DbPath := TAppDatabase.ConfigRoot + 'workspaces' + PathDelim + WsId + PathDelim + 'workspace.db';
  if not FileExists(DbPath) then
    Fail('workspace.db was not created at ' + DbPath);
  TAppDatabase.OpenWorkspace(WsId);
  try
    if not TAppDatabase.WorkspaceSettings(WsId).TryGet('ws.smoke', ReadBack) then
      Fail('ws.smoke missing after reopen');
    if ReadBack <> Probe then
      Fail('ws.smoke value mismatch after reopen');
    if TAppDatabase.SchemaVersion(adsWorkspace, WsId) <> 2 then
      Fail('Workspace schema version mismatch');
  finally
    TAppDatabase.CloseWorkspace(WsId);
  end;
end;

var
  Probe: string;
begin
  Probe := 'probe-' + IntToStr(Random(MaxInt));
  TestGlobalRoundTrip(Probe);
  TestWorkspaceRoundTrip(Probe + '-ws');
  TAppDatabase.ClearConfigRootOverride;
  WriteLn('SQLite app database tests passed.');
end.
