unit uWebSearchSecrets;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function GetWebSearchApiKey(const AConnectionId: string): string;
procedure SetWebSearchApiKey(const AConnectionId, AApiKey: string);
procedure ClearWebSearchApiKey(const AConnectionId: string);
function WebSearchApiKeyIsSet(const AConnectionId: string): Boolean;

implementation

uses
  uAppDatabase, uRepositoryInterfaces;

function GetWebSearchApiKeyFromDb(const AConnectionId: string): string;
var
  Repo: IWebSearchRepository;
  Rows: TWebSearchConnectionRows;
  I: Integer;
begin
  Result := '';
  if Trim(AConnectionId) = '' then Exit;
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  Repo := TAppDatabase.GlobalWebSearch;
  Repo.LoadConnections(Rows);
  for I := 0 to High(Rows) do
    if SameText(Rows[I].Id, AConnectionId) then
      Exit(Rows[I].ApiKey);
end;

procedure SetWebSearchApiKeyInDb(const AConnectionId, AApiKey: string);
var
  Repo: IWebSearchRepository;
  Rows: TWebSearchConnectionRows;
  I: Integer;
  Found: Boolean;
begin
  if Trim(AConnectionId) = '' then Exit;
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  Repo := TAppDatabase.GlobalWebSearch;
  Repo.LoadConnections(Rows);
  Found := False;
  for I := 0 to High(Rows) do
    if SameText(Rows[I].Id, AConnectionId) then
    begin
      Rows[I].ApiKey := AApiKey;
      Found := True;
      Break;
    end;
  if not Found then
  begin
    I := Length(Rows);
    SetLength(Rows, I + 1);
    Rows[I].Id := AConnectionId;
    Rows[I].Name := 'Connection';
    Rows[I].Provider := 'brave';
    Rows[I].Enabled := True;
    Rows[I].Priority := I + 1;
    Rows[I].TimeoutMs := 10000;
    Rows[I].ApiKey := AApiKey;
  end;
  Repo.SaveConnections(Rows);
end;

function GetWebSearchApiKey(const AConnectionId: string): string;
begin
  Result := GetWebSearchApiKeyFromDb(AConnectionId);
end;

procedure SetWebSearchApiKey(const AConnectionId, AApiKey: string);
begin
  if Trim(AConnectionId) = '' then Exit;
  SetWebSearchApiKeyInDb(AConnectionId, AApiKey);
end;

procedure ClearWebSearchApiKey(const AConnectionId: string);
begin
  SetWebSearchApiKey(AConnectionId, '');
end;

function WebSearchApiKeyIsSet(const AConnectionId: string): Boolean;
begin
  Result := Trim(GetWebSearchApiKey(AConnectionId)) <> '';
end;

end.
