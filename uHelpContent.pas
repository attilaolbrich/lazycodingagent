unit uHelpContent;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  THelpTopicIndexArray = array of Integer;

  THelpTopic = record
    Id: string;
    Title: string;
    FileName: string;
    Keywords: string;
    Body: string;
  end;

  THelpCatalog = class
  private
    FTopics: array of THelpTopic;
    FHelpDirectory: string;
    FLoaded: Boolean;
    function IndexJsonPath(const ADir: string): string;
    procedure LoadFallbackMissing(const AReason: string);
    procedure ParseKeywords(AObj: TObject; out AKeywords: string);
  public
    function LoadFromDirectory(const ADir: string): Boolean;
    function LoadResolved: Boolean;
    function TopicCount: Integer;
    function GetTopic(AIndex: Integer): THelpTopic;
    function SearchIndices(const AQuery: string): THelpTopicIndexArray;
    property HelpDirectory: string read FHelpDirectory;
    property Loaded: Boolean read FLoaded;
  end;

function ResolveHelpDirectory: string;

implementation

uses
  fpjson, jsonparser, LazFileUtils;

function ResolveHelpDirectory: string;
const
  Candidates: array[0..2] of string = (
    'help',
    '../help',
    ''
  );
var
  Base, Dir, IdxPath: string;
  I: Integer;
begin
  Base := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  for I := 0 to High(Candidates) do
  begin
    if Candidates[I] = '' then
      Dir := IncludeTrailingPathDelimiter(GetCurrentDir) + 'help'
    else
      Dir := ExpandFileName(Base + Candidates[I]);
    IdxPath := IncludeTrailingPathDelimiter(Dir) + 'index.json';
    if FileExists(IdxPath) then
      Exit(ExcludeTrailingPathDelimiter(Dir));
  end;
  Result := '';
end;

function THelpCatalog.IndexJsonPath(const ADir: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ADir) + 'index.json';
end;

procedure THelpCatalog.ParseKeywords(AObj: TObject; out AKeywords: string);
var
  Arr: TJSONArray;
  J: Integer;
  S: string;
begin
  AKeywords := '';
  if not (AObj is TJSONArray) then Exit;
  Arr := TJSONArray(AObj);
  for J := 0 to Arr.Count - 1 do
  begin
    S := Trim(Arr.Items[J].AsString);
    if S <> '' then
    begin
      if AKeywords <> '' then
        AKeywords := AKeywords + ' ';
      AKeywords := AKeywords + S;
    end;
  end;
end;

procedure THelpCatalog.LoadFallbackMissing(const AReason: string);
begin
  SetLength(FTopics, 1);
  FTopics[0].Id := 'missing';
  FTopics[0].Title := 'Help not found';
  FTopics[0].FileName := '';
  FTopics[0].Keywords := 'help';
  FTopics[0].Body :=
    '# Help not found' + LineEnding + LineEnding +
    'Could not load the user guide.' + LineEnding + LineEnding +
    AReason + LineEnding + LineEnding +
    'Expected a `help` folder next to the executable containing `index.json` and topic `.md` files. ' +
    'After building, copy the project `help/` directory into the output folder.';
  FLoaded := True;
end;

function THelpCatalog.LoadFromDirectory(const ADir: string): Boolean;
var
  JsonSL: TStringList;
  Root: TJSONData;
  Arr: TJSONArray;
  I, N: Integer;
  Item: TJSONObject;
  FileName, FullPath: string;
  SL: TStringList;
begin
  SetLength(FTopics, 0);
  FHelpDirectory := '';
  FLoaded := False;
  if Trim(ADir) = '' then
  begin
    LoadFallbackMissing('No help directory was resolved.');
    Exit(True);
  end;
  if not FileExists(IndexJsonPath(ADir)) then
  begin
    LoadFallbackMissing('Missing index.json in: ' + ADir);
    Exit(True);
  end;

  JsonSL := TStringList.Create;
  try
    JsonSL.LoadFromFile(IndexJsonPath(ADir));
    Root := GetJSON(JsonSL.Text);
    try
      if Root is TJSONArray then
        Arr := TJSONArray(Root)
      else if (Root is TJSONObject) and (TJSONObject(Root).Find('topics') <> nil) then
        Arr := TJSONObject(Root).Arrays['topics']
      else
      begin
        LoadFallbackMissing('index.json must be a JSON array or an object with a "topics" array.');
        Exit(True);
      end;

      N := 0;
      SetLength(FTopics, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        if not (Arr.Items[I] is TJSONObject) then Continue;
        Item := TJSONObject(Arr.Items[I]);
        FTopics[N].Id := Item.Get('id', '');
        FTopics[N].Title := Item.Get('title', '');
        FTopics[N].FileName := Item.Get('file', '');
        if Item.Find('keywords') <> nil then
          ParseKeywords(Item.Find('keywords'), FTopics[N].Keywords)
        else
          FTopics[N].Keywords := '';
        FTopics[N].Body := '';
        FileName := FTopics[N].FileName;
        if FileName <> '' then
        begin
          FullPath := IncludeTrailingPathDelimiter(ADir) + FileName;
          if FileExists(FullPath) then
          begin
            SL := TStringList.Create;
            try
              SL.LoadFromFile(FullPath);
              FTopics[N].Body := SL.Text;
            finally
              SL.Free;
            end;
          end
          else
            FTopics[N].Body := '# Missing topic file' + LineEnding + LineEnding +
              'Expected: ' + FullPath;
        end;
        Inc(N);
      end;
      SetLength(FTopics, N);
      FHelpDirectory := ADir;
      FLoaded := N > 0;
      if not FLoaded then
        LoadFallbackMissing('index.json contained no valid topics.');
    finally
      Root.Free;
    end;
  finally
    JsonSL.Free;
  end;
  Result := True;
end;

function THelpCatalog.LoadResolved: Boolean;
begin
  Result := LoadFromDirectory(ResolveHelpDirectory);
end;

function THelpCatalog.TopicCount: Integer;
begin
  Result := Length(FTopics);
end;

function THelpCatalog.GetTopic(AIndex: Integer): THelpTopic;
begin
  if (AIndex < 0) or (AIndex >= Length(FTopics)) then
    raise ERangeError.Create('THelpCatalog.GetTopic');
  Result := FTopics[AIndex];
end;

function THelpCatalog.SearchIndices(const AQuery: string): THelpTopicIndexArray;
var
  I: Integer;
  Filter, Hay: string;
  N: Integer;
begin
  Filter := LowerCase(Trim(AQuery));
  SetLength(Result, 0);
  N := 0;
  for I := 0 to High(FTopics) do
  begin
    if Filter = '' then
    begin
      SetLength(Result, N + 1);
      Result[N] := I;
      Inc(N);
      Continue;
    end;
    Hay := LowerCase(FTopics[I].Title + ' ' + FTopics[I].Keywords + ' ' +
      FTopics[I].Body);
    if Pos(Filter, Hay) > 0 then
    begin
      SetLength(Result, N + 1);
      Result[N] := I;
      Inc(N);
    end;
  end;
end;

end.
