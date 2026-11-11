program test_settings_import;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, uAppDatabase, uGlobalConfigKeys, uAppSettingsCodec,
  uRepositoryInterfaces;

procedure Fail(const Msg: string);
begin
  WriteLn('FAIL: ', Msg);
  Halt(1);
end;

function TempRoot: string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir) + 'lca-import-' + IntToStr(GetProcessID);
end;

var
  Root: string;
  ProvRows: TLlmProviderRows;
  WebRows: TWebSearchConnectionRows;
begin
  Root := TempRoot;
  TAppDatabase.SetConfigRootOverride(Root);
  TAppDatabase.OpenGlobal;
  SetLength(ProvRows, 1);
  ProvRows[0].ProviderOrd := 0;
  ProvRows[0].ApiKey := 'test-api-key-import';
  ProvRows[0].BaseUrl := 'https://example.com/v1';
  TAppDatabase.GlobalLlmSettings.SaveProviders(ProvRows);

  SetLength(WebRows, 1);
  WebRows[0].Id := 'conn1';
  WebRows[0].Name := 'Brave';
  WebRows[0].Provider := 'brave';
  WebRows[0].Enabled := True;
  WebRows[0].Priority := 1;
  WebRows[0].TimeoutMs := 10000;
  WebRows[0].ApiKey := 'web-search-key';
  TAppDatabase.GlobalWebSearch.SaveConnections(WebRows);

  TAppDatabase.GlobalLlmSettings.LoadProviders(ProvRows);
  if (Length(ProvRows) <> 1) or (ProvRows[0].ApiKey <> 'test-api-key-import') then
    Fail('LLM provider round-trip failed');

  TAppDatabase.GlobalWebSearch.LoadConnections(WebRows);
  if (Length(WebRows) <> 1) or (WebRows[0].ApiKey <> 'web-search-key') then
    Fail('Web search secret round-trip failed');

  SettingsSetString(TAppDatabase.GlobalSettings, KEY_MIGRATION_IMPORTED, 'test');
  TAppDatabase.CloseGlobal;
  TAppDatabase.ClearConfigRootOverride;
  WriteLn('Settings import tests passed.');
end.
