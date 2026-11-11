unit uBrowserReadConfig;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uBrowserReadTypes;

function LoadBrowserReadConfig: TBrowserReadConfig;
procedure SaveBrowserReadExecutablePath(const APath: string);
procedure SaveBrowserReadConfigToGlobalDb(const AConfig: TBrowserReadConfig);

function BrowserReadTestLocalAllowed: Boolean;

implementation

uses
  uAppDatabase, uRepositoryInterfaces;

function LoadBrowserReadConfigFromDb: TBrowserReadConfig;
var
  Repo: IBrowserReadRepository;
begin
  Result := DefaultBrowserReadConfig;
  Result.AllowLocalhost := BrowserReadTestLocalAllowed;
  Repo := TAppDatabase.GlobalBrowserRead;
  Result.ExecutablePath := Repo.LoadExecutablePath;
  Result.MaxConcurrent := Repo.LoadMaxConcurrent;
  if Result.MaxConcurrent < 1 then
    Result.MaxConcurrent := 1;
  if Result.MaxConcurrent > 4 then
    Result.MaxConcurrent := 4;
  Result.MaxSessions := Repo.LoadMaxSessions;
  if Result.MaxSessions < 1 then
    Result.MaxSessions := 1;
  if Result.MaxSessions > 8 then
    Result.MaxSessions := 8;
  Result.IdleTimeoutMs := Repo.LoadIdleTimeoutMs;
  if Result.IdleTimeoutMs < 60000 then
    Result.IdleTimeoutMs := 60000;
end;

function LoadBrowserReadConfig: TBrowserReadConfig;
begin
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  Result := LoadBrowserReadConfigFromDb;
end;

procedure SaveBrowserReadConfigToGlobalDb(const AConfig: TBrowserReadConfig);
var
  Repo: IBrowserReadRepository;
  MaxC, MaxS, Idle: Integer;
begin
  Repo := TAppDatabase.GlobalBrowserRead;
  Repo.SaveExecutablePath(AConfig.ExecutablePath);
  MaxC := AConfig.MaxConcurrent;
  if MaxC < 1 then MaxC := 1;
  if MaxC > 4 then MaxC := 4;
  Repo.SaveMaxConcurrent(MaxC);
  MaxS := AConfig.MaxSessions;
  if MaxS < 1 then MaxS := 1;
  if MaxS > 8 then MaxS := 8;
  Repo.SaveMaxSessions(MaxS);
  Idle := AConfig.IdleTimeoutMs;
  if Idle < 60000 then Idle := 60000;
  Repo.SaveIdleTimeoutMs(Idle);
end;

procedure SaveBrowserReadExecutablePath(const APath: string);
var
  Cfg: TBrowserReadConfig;
begin
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  Cfg := LoadBrowserReadConfigFromDb;
  Cfg.ExecutablePath := Trim(APath);
  SaveBrowserReadConfigToGlobalDb(Cfg);
end;

function BrowserReadTestLocalAllowed: Boolean;
begin
  Result := SameText(GetEnvironmentVariable('LCA_BROWSER_READ_TEST_LOCAL'), '1');
end;

end.
