unit uSyntaxSchemeRegistry;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uSyntaxScheme;

type
  TSyntaxSchemeEntry = record
    Id: string;
    Name: string;
    FileName: string;
    BuiltIn: Boolean;
  end;

  TSyntaxSchemeRegistry = class
  private
    FEntries: array of TSyntaxSchemeEntry;
    FActiveId: string;
    FActiveScheme: TSyntaxScheme;
    function IndexOfId(const AId: string): Integer;
    function SchemeFilePath(const AFileName: string): string;
    procedure EnsureBuiltinSchemeFile;
    procedure ReloadActiveScheme;
  public
    constructor Create;
    function Count: Integer;
    function GetEntry(AIndex: Integer): TSyntaxSchemeEntry;
    function FindById(const AId: string; out AEntry: TSyntaxSchemeEntry): Boolean;
    property ActiveId: string read FActiveId;
    property ActiveScheme: TSyntaxScheme read FActiveScheme;
    procedure Load;
    procedure Save;
    procedure SetActive(const AId: string);
    function ImportFromFile(const ASourcePath: string; out AError: string): string;
    function Remove(const AId: string; out AError: string): Boolean;
    procedure EnsureLoaded;
  end;

function SyntaxSchemesDir: string;
function SyntaxSchemesIndexFile: string;

implementation

uses
  Forms, fpjson, jsonparser, FileUtil;

function SyntaxSchemesDir: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'lazycodingagent' +
    PathDelim + 'syntax-schemes';
end;

function SyntaxSchemesIndexFile: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'lazycodingagent' +
    PathDelim + 'syntax-schemes.json';
end;

function BuiltinSchemeJson: string;
begin
  Result :=
    '{' + LineEnding +
    '  "name": "Generic C-like",' + LineEnding +
    '  "tokenColors": [' + LineEnding +
    '    { "scope": "comment", "settings": { "foreground": "#6A9955" } },' + LineEnding +
    '    { "scope": "keyword", "settings": { "foreground": "#569CD6", "fontStyle": "bold" } },' + LineEnding +
    '    { "scope": "string", "settings": { "foreground": "#CE9178" } },' + LineEnding +
    '    { "scope": "constant.numeric", "settings": { "foreground": "#B5CEA8" } },' + LineEnding +
    '    { "scope": "operator", "settings": { "foreground": "#D4D4D4" } },' + LineEnding +
    '    { "scope": "source", "settings": { "foreground": "#D4D4D4" } }' + LineEnding +
    '  ]' + LineEnding +
    '}';
end;

{ TSyntaxSchemeRegistry }

constructor TSyntaxSchemeRegistry.Create;
begin
  inherited Create;
  FActiveScheme := DefaultGenericClikeScheme;
end;

function TSyntaxSchemeRegistry.SchemeFilePath(const AFileName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(SyntaxSchemesDir) + AFileName;
end;

function TSyntaxSchemeRegistry.IndexOfId(const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if SameText(FEntries[I].Id, AId) then
      Exit(I);
  Result := -1;
end;

function TSyntaxSchemeRegistry.Count: Integer;
begin
  Result := Length(FEntries);
end;

function TSyntaxSchemeRegistry.GetEntry(AIndex: Integer): TSyntaxSchemeEntry;
begin
  Result := FEntries[AIndex];
end;

function TSyntaxSchemeRegistry.FindById(const AId: string; out AEntry: TSyntaxSchemeEntry): Boolean;
var
  Idx: Integer;
begin
  Idx := IndexOfId(AId);
  if Idx < 0 then
    Exit(False);
  AEntry := FEntries[Idx];
  Result := True;
end;

procedure TSyntaxSchemeRegistry.EnsureBuiltinSchemeFile;
var
  Dir, Path: string;
  SL: TStringList;
begin
  Dir := SyntaxSchemesDir;
  if not DirectoryExists(Dir) then
    ForceDirectories(Dir);
  Path := SchemeFilePath('generic-clike.json');
  if FileExists(Path) then Exit;
  SL := TStringList.Create;
  try
    SL.Text := BuiltinSchemeJson;
    SL.SaveToFile(Path);
  finally
    SL.Free;
  end;
end;

procedure TSyntaxSchemeRegistry.ReloadActiveScheme;
var
  Entry: TSyntaxSchemeEntry;
  Err: string;
  Path: string;
begin
  if not FindById(FActiveId, Entry) then begin
    FActiveScheme := DefaultGenericClikeScheme;
    Exit;
  end;
  Path := SchemeFilePath(Entry.FileName);
  if not LoadSchemeFromJsonFile(Path, FActiveScheme, Err) then
    FActiveScheme := DefaultGenericClikeScheme
  else
    FActiveScheme.Id := Entry.Id;
end;

procedure TSyntaxSchemeRegistry.EnsureLoaded;
begin
  if Count = 0 then
    Load;
end;

procedure TSyntaxSchemeRegistry.Load;
var
  Path, Err: string;
  Data: TJSONData;
  Root: TJSONObject;
  Arr: TJSONArray;
  Item: TJSONObject;
  I: Integer;
  E: TSyntaxSchemeEntry;
  SL: TStringList;
begin
  EnsureBuiltinSchemeFile;
  SetLength(FEntries, 0);
  FActiveId := 'generic-clike';
  Path := SyntaxSchemesIndexFile;
  if FileExists(Path) then begin
    SL := TStringList.Create;
    try
      SL.LoadFromFile(Path);
      Data := GetJSON(SL.Text);
      try
        if Data is TJSONObject then begin
          Root := TJSONObject(Data);
          FActiveId := Root.Get('activeId', 'generic-clike');
          Arr := Root.Find('schemes') as TJSONArray;
          if Arr <> nil then begin
            for I := 0 to Arr.Count - 1 do begin
              if not (Arr.Items[I] is TJSONObject) then Continue;
              Item := TJSONObject(Arr.Items[I]);
              E.Id := Item.Get('id', '');
              E.Name := Item.Get('name', E.Id);
              E.FileName := Item.Get('fileName', '');
              E.BuiltIn := SameText(Item.Get('builtIn', 'false'), 'true');
              if (E.Id <> '') and (E.FileName <> '') then begin
                SetLength(FEntries, Length(FEntries) + 1);
                FEntries[High(FEntries)] := E;
              end;
            end;
          end;
        end;
      finally
        Data.Free;
      end;
    finally
      SL.Free;
    end;
  end;
  if Count = 0 then begin
    E.Id := 'generic-clike';
    E.Name := 'Generic C-like';
    E.FileName := 'generic-clike.json';
    E.BuiltIn := True;
    SetLength(FEntries, 1);
    FEntries[0] := E;
    Save;
  end;
  if IndexOfId(FActiveId) < 0 then
    FActiveId := FEntries[0].Id;
  ReloadActiveScheme;
end;

procedure TSyntaxSchemeRegistry.Save;
var
  Root, Item: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  Path, Dir: string;
  SL: TStringList;
begin
  EnsureBuiltinSchemeFile;
  Root := TJSONObject.Create;
  try
    Root.Add('activeId', FActiveId);
    Arr := TJSONArray.Create;
    for I := 0 to Count - 1 do begin
      Item := TJSONObject.Create;
      Item.Add('id', FEntries[I].Id);
      Item.Add('name', FEntries[I].Name);
      Item.Add('fileName', FEntries[I].FileName);
      if FEntries[I].BuiltIn then
        Item.Add('builtIn', 'true')
      else
        Item.Add('builtIn', 'false');
      Arr.Add(Item);
    end;
    Root.Add('schemes', Arr);
    Path := SyntaxSchemesIndexFile;
    Dir := ExtractFilePath(Path);
    if not DirectoryExists(Dir) then
      ForceDirectories(Dir);
    SL := TStringList.Create;
    try
      SL.Text := Root.AsJSON;
      SL.SaveToFile(Path);
    finally
      SL.Free;
    end;
  finally
    Root.Free;
  end;
end;

procedure TSyntaxSchemeRegistry.SetActive(const AId: string);
begin
  if IndexOfId(AId) < 0 then Exit;
  FActiveId := AId;
  ReloadActiveScheme;
  Save;
end;

function TSyntaxSchemeRegistry.ImportFromFile(const ASourcePath: string; out AError: string): string;
var
  Scheme: TSyntaxScheme;
  BaseName, DestName, DestPath, NewId: string;
  SL: TStringList;
  E: TSyntaxSchemeEntry;
  N: Integer;
begin
  AError := '';
  Result := '';
  if not LoadSchemeFromJsonFile(ASourcePath, Scheme, AError) then
    Exit('');
  BaseName := ChangeFileExt(ExtractFileName(ASourcePath), '');
  NewId := LowerCase(StringReplace(BaseName, ' ', '-', [rfReplaceAll]));
  if NewId = '' then
    NewId := 'imported-scheme';
  if IndexOfId(NewId) >= 0 then begin
    N := 2;
    while IndexOfId(NewId + '-' + IntToStr(N)) >= 0 do
      Inc(N);
    NewId := NewId + '-' + IntToStr(N);
  end;
  DestName := NewId + '.json';
  DestPath := SchemeFilePath(DestName);
  ForceDirectories(SyntaxSchemesDir);
  SL := TStringList.Create;
  try
    SL.LoadFromFile(ASourcePath);
    SL.SaveToFile(DestPath);
  finally
    SL.Free;
  end;
  E.Id := NewId;
  E.Name := Scheme.Name;
  if E.Name = '' then
    E.Name := BaseName;
  E.FileName := DestName;
  E.BuiltIn := False;
  SetLength(FEntries, Length(FEntries) + 1);
  FEntries[High(FEntries)] := E;
  Save;
  Result := NewId;
end;

function TSyntaxSchemeRegistry.Remove(const AId: string; out AError: string): Boolean;
var
  Idx: Integer;
  Path: string;
  I: Integer;
begin
  AError := '';
  Idx := IndexOfId(AId);
  if Idx < 0 then begin
    AError := 'Scheme not found.';
    Exit(False);
  end;
  if FEntries[Idx].BuiltIn then begin
    AError := 'Built-in schemes cannot be removed.';
    Exit(False);
  end;
  Path := SchemeFilePath(FEntries[Idx].FileName);
  if FileExists(Path) then
    DeleteFile(Path);
  for I := Idx to Count - 2 do
    FEntries[I] := FEntries[I + 1];
  SetLength(FEntries, Count - 1);
  if SameText(FActiveId, AId) then begin
    if Count > 0 then
      FActiveId := FEntries[0].Id
    else
      FActiveId := 'generic-clike';
    ReloadActiveScheme;
  end;
  Save;
  Result := True;
end;

end.
