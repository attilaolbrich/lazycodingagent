unit uWorkspaceRegistry;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TWorkspaceEntry = record
    Id: string;
    DisplayName: string;
    FolderPath: string;
    LastSessionId: string;
  end;

  TWorkspaceRegistry = class
  private
    FEntries: array of TWorkspaceEntry;
    FActiveWorkspaceId: string;
    function IndexOfId(const AId: string): Integer;
    function IndexOfPath(const AFolderPath: string): Integer;
  public
    function Count: Integer;
    function GetEntry(AIndex: Integer): TWorkspaceEntry;
    function FindById(const AId: string; out AEntry: TWorkspaceEntry): Boolean;
    function FindByPath(const AFolderPath: string; out AEntry: TWorkspaceEntry): Boolean;
    function WorkspaceIdFromPath(const AFolderPath: string): string;

    property ActiveWorkspaceId: string read FActiveWorkspaceId write FActiveWorkspaceId;

    function AddWorkspace(const ADisplayName, AFolderPath: string): string;
    function UpdateWorkspace(const AId: string; const ADisplayName, AFolderPath: string): Boolean;
    procedure SetLastSessionId(const AWorkspaceId, ASessionId: string);
    function RemoveWorkspace(const AId: string): Boolean;

    procedure Load;
    procedure Save;
    procedure LoadFromGlobalDb;
    procedure SaveToGlobalDb;
  end;

function WorkspaceRegistryFileName: string;
function NormalizeWorkspaceFolderPath(const APath: string): string;

implementation

uses
  uAppDatabase, uRepositoryInterfaces;

function WorkspaceRegistryFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'lazycodingagent' +
    PathDelim + 'workspaces.json';
end;

function NormalizeWorkspaceFolderPath(const APath: string): string;
begin
  Result := ExpandFileName(ExcludeTrailingPathDelimiter(Trim(APath)));
end;

function WorkspaceIdFromNormalizedPath(const ANormalizedPath: string): string;
var
  I: Integer;
  H: UInt64;
begin
  H := 5381;
  for I := 1 to Length(ANormalizedPath) do
    H := ((H shl 5) + H) + Ord(ANormalizedPath[I]);
  Result := 'ws_' + IntToHex(H, 16);
end;

{ TWorkspaceRegistry }

function TWorkspaceRegistry.Count: Integer;
begin
  Result := Length(FEntries);
end;

function TWorkspaceRegistry.GetEntry(AIndex: Integer): TWorkspaceEntry;
begin
  Result := FEntries[AIndex];
end;

function TWorkspaceRegistry.IndexOfId(const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FEntries) do
    if SameText(FEntries[I].Id, AId) then
      Exit(I);
  Result := -1;
end;

function TWorkspaceRegistry.IndexOfPath(const AFolderPath: string): Integer;
var
  I: Integer;
  Norm: string;
begin
  Norm := NormalizeWorkspaceFolderPath(AFolderPath);
  for I := 0 to High(FEntries) do
    if SameText(NormalizeWorkspaceFolderPath(FEntries[I].FolderPath), Norm) then
      Exit(I);
  Result := -1;
end;

function TWorkspaceRegistry.WorkspaceIdFromPath(const AFolderPath: string): string;
begin
  Result := WorkspaceIdFromNormalizedPath(NormalizeWorkspaceFolderPath(AFolderPath));
end;

function TWorkspaceRegistry.FindById(const AId: string; out AEntry: TWorkspaceEntry): Boolean;
var
  Idx: Integer;
begin
  Idx := IndexOfId(AId);
  Result := Idx >= 0;
  if Result then
    AEntry := FEntries[Idx];
end;

function TWorkspaceRegistry.FindByPath(const AFolderPath: string; out AEntry: TWorkspaceEntry): Boolean;
var
  Idx: Integer;
begin
  Idx := IndexOfPath(AFolderPath);
  Result := Idx >= 0;
  if Result then
    AEntry := FEntries[Idx];
end;

function TWorkspaceRegistry.AddWorkspace(const ADisplayName, AFolderPath: string): string;
var
  E: TWorkspaceEntry;
  Idx: Integer;
  Norm: string;
begin
  Norm := NormalizeWorkspaceFolderPath(AFolderPath);
  Idx := IndexOfPath(Norm);
  if Idx >= 0 then begin
    Result := FEntries[Idx].Id;
    if Trim(ADisplayName) <> '' then
      FEntries[Idx].DisplayName := Trim(ADisplayName);
    Exit;
  end;

  E.Id := WorkspaceIdFromNormalizedPath(Norm);
  E.FolderPath := Norm;
  if Trim(ADisplayName) <> '' then
    E.DisplayName := Trim(ADisplayName)
  else
    E.DisplayName := ExtractFileName(Norm);
  E.LastSessionId := '';

  SetLength(FEntries, Length(FEntries) + 1);
  FEntries[High(FEntries)] := E;
  Result := E.Id;
end;

function TWorkspaceRegistry.UpdateWorkspace(const AId: string; const ADisplayName, AFolderPath: string): Boolean;
var
  Idx, OtherIdx: Integer;
  Norm: string;
begin
  Idx := IndexOfId(AId);
  if Idx < 0 then
    Exit(False);

  Norm := NormalizeWorkspaceFolderPath(AFolderPath);
  OtherIdx := IndexOfPath(Norm);
  if (OtherIdx >= 0) and (OtherIdx <> Idx) then
    Exit(False);

  FEntries[Idx].FolderPath := Norm;
  if Trim(ADisplayName) <> '' then
    FEntries[Idx].DisplayName := Trim(ADisplayName);
  Result := True;
end;

procedure TWorkspaceRegistry.SetLastSessionId(const AWorkspaceId, ASessionId: string);
var
  Idx: Integer;
begin
  Idx := IndexOfId(AWorkspaceId);
  if Idx < 0 then Exit;
  FEntries[Idx].LastSessionId := ASessionId;
end;

function TWorkspaceRegistry.RemoveWorkspace(const AId: string): Boolean;
var
  Idx, I: Integer;
begin
  Idx := IndexOfId(AId);
  if Idx < 0 then
    Exit(False);
  if SameText(FActiveWorkspaceId, AId) then
    FActiveWorkspaceId := '';
  for I := Idx to High(FEntries) - 1 do
    FEntries[I] := FEntries[I + 1];
  SetLength(FEntries, Length(FEntries) - 1);
  Result := True;
end;

procedure TWorkspaceRegistry.Load;
begin
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  LoadFromGlobalDb;
end;

procedure TWorkspaceRegistry.Save;
begin
  if not TAppDatabase.IsGlobalOpen then
    TAppDatabase.OpenGlobal;
  SaveToGlobalDb;
end;

procedure TWorkspaceRegistry.LoadFromGlobalDb;
var
  Repo: IWorkspaceRegistryRepository;
  Rows: TRegistryWorkspaceRows;
  I: Integer;
  SanitizeActive: Boolean;
begin
  SetLength(FEntries, 0);
  FActiveWorkspaceId := '';
  Repo := TAppDatabase.GlobalWorkspaceRegistry;
  Repo.LoadAll(Rows, FActiveWorkspaceId);
  SetLength(FEntries, Length(Rows));
  for I := 0 to High(Rows) do
  begin
    FEntries[I].Id := Rows[I].Id;
    FEntries[I].DisplayName := Rows[I].DisplayName;
    FEntries[I].FolderPath := Rows[I].FolderPath;
    FEntries[I].LastSessionId := Rows[I].LastSessionId;
  end;
  SanitizeActive := False;
  if Count = 0 then begin
    if FActiveWorkspaceId <> '' then begin
      FActiveWorkspaceId := '';
      SanitizeActive := True;
    end;
  end else if (Trim(FActiveWorkspaceId) <> '') and (IndexOfId(FActiveWorkspaceId) < 0) then begin
    FActiveWorkspaceId := '';
    SanitizeActive := True;
  end;
  if SanitizeActive then
    SaveToGlobalDb;
end;

procedure TWorkspaceRegistry.SaveToGlobalDb;
var
  Repo: IWorkspaceRegistryRepository;
  Rows: TRegistryWorkspaceRows;
  I: Integer;
begin
  SetLength(Rows, Length(FEntries));
  for I := 0 to High(FEntries) do
  begin
    Rows[I].Id := FEntries[I].Id;
    Rows[I].DisplayName := FEntries[I].DisplayName;
    Rows[I].FolderPath := FEntries[I].FolderPath;
    Rows[I].LastSessionId := FEntries[I].LastSessionId;
    Rows[I].SortOrder := I;
  end;
  Repo := TAppDatabase.GlobalWorkspaceRegistry;
  Repo.SaveAll(Rows, FActiveWorkspaceId);
end;

end.
