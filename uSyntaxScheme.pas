unit uSyntaxScheme;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, fpjson;

type
  TSyntaxTokenKind = (
    stkComment,
    stkKeyword,
    stkString,
    stkNumber,
    stkOperator,
    stkText
  );

  TSyntaxScheme = record
    Id: string;
    Name: string;
    Colors: array[TSyntaxTokenKind] of TColor;
    BoldKeyword: Boolean;
  end;

function DefaultGenericClikeScheme: TSyntaxScheme;
function SyntaxTokenKindFromScope(const AScope: string): TSyntaxTokenKind;
function ParseColorFromJson(const AValue: string): TColor;
function LoadSchemeFromJsonFile(const APath: string; out AScheme: TSyntaxScheme;
  out AError: string): Boolean;
function LoadSchemeFromJsonText(const AJson: string; const AId, AFileName: string;
  out AScheme: TSyntaxScheme; out AError: string): Boolean;
procedure ApplySchemeToSynAnyHighlighter(AHighlighter: TObject; const AScheme: TSyntaxScheme);

implementation

uses
  SynHighlighterAny, SynEditHighlighter;

function ParseHexColor(const S: string): TColor;
var
  H: string;
  N: LongInt;
begin
  H := Trim(S);
  if H = '' then
    Exit(clNone);
  if (Length(H) > 0) and (H[1] = '#') then
    H := Copy(H, 2, MaxInt);
  if Length(H) = 3 then
    H := H[1] + H[1] + H[2] + H[2] + H[3] + H[3];
  if TryStrToInt('$' + H, N) then
    Exit(TColor(N and $FFFFFF));
  Result := clNone;
end;

function ParseColorFromJson(const AValue: string): TColor;
begin
  Result := ParseHexColor(AValue);
end;

function SyntaxTokenKindFromScope(const AScope: string): TSyntaxTokenKind;
var
  S: string;
begin
  S := LowerCase(Trim(AScope));
  if (Pos('comment', S) > 0) then
    Exit(stkComment);
  if (Pos('keyword', S) > 0) or (Pos('storage.type', S) > 0) then
    Exit(stkKeyword);
  if (Pos('string', S) > 0) or (Pos('regexp', S) > 0) or (Pos('character', S) > 0) then
    Exit(stkString);
  if (Pos('constant.numeric', S) > 0) or (Pos('number', S) > 0) then
    Exit(stkNumber);
  if (Pos('operator', S) > 0) or (Pos('punctuation', S) > 0) then
    Exit(stkOperator);
  Result := stkText;
end;

function DefaultGenericClikeScheme: TSyntaxScheme;
begin
  Result.Id := 'generic-clike';
  Result.Name := 'Generic C-like';
  Result.Colors[stkComment] := $006A9955;
  Result.Colors[stkKeyword] := $00D69D85;
  Result.Colors[stkString] := $00CE9178;
  Result.Colors[stkNumber] := $00B5CEA8;
  Result.Colors[stkOperator] := $00D4D4D4;
  Result.Colors[stkText] := $00D4D4D4;
  Result.BoldKeyword := True;
end;

procedure MergeTokenColor(var AScheme: TSyntaxScheme; AKind: TSyntaxTokenKind; AColor: TColor;
  const AFontStyle: string);
begin
  if AColor = clNone then Exit;
  AScheme.Colors[AKind] := AColor;
  if AKind = stkKeyword then
    AScheme.BoldKeyword := Pos('bold', LowerCase(AFontStyle)) > 0;
end;

function LoadSchemeFromJsonText(const AJson: string; const AId, AFileName: string;
  out AScheme: TSyntaxScheme; out AError: string): Boolean;
var
  Data: TJSONData;
  Root, Item, Settings: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  ScopeVal, Fg, Fs: string;
  Kind: TSyntaxTokenKind;
  NameVal: string;
begin
  AError := '';
  AScheme := DefaultGenericClikeScheme;
  AScheme.Id := AId;
  if AFileName <> '' then
    AScheme.Name := ChangeFileExt(ExtractFileName(AFileName), '');
  try
    Data := GetJSON(AJson);
  except
    on E: Exception do begin
      AError := E.Message;
      Exit(False);
    end;
  end;
  if Data = nil then begin
    AError := 'Invalid JSON.';
    Exit(False);
  end;
  try
    if not (Data is TJSONObject) then begin
      AError := 'Expected a JSON object.';
      Exit(False);
    end;
    Root := TJSONObject(Data);
    NameVal := Root.Get('name', '');
    if Trim(NameVal) <> '' then
      AScheme.Name := NameVal;
    Arr := Root.Find('tokenColors') as TJSONArray;
    if Arr = nil then begin
      AError := 'No tokenColors array found (VS Code theme fragment expected).';
      Exit(False);
    end;
    for I := 0 to Arr.Count - 1 do begin
      if not (Arr.Items[I] is TJSONObject) then Continue;
      Item := TJSONObject(Arr.Items[I]);
      ScopeVal := Item.Get('scope', '');
      Settings := Item.Find('settings') as TJSONObject;
      if Settings = nil then Continue;
      Fg := Settings.Get('foreground', '');
      Fs := Settings.Get('fontStyle', '');
      Kind := SyntaxTokenKindFromScope(ScopeVal);
      MergeTokenColor(AScheme, Kind, ParseColorFromJson(Fg), Fs);
    end;
    Result := True;
  finally
    Data.Free;
  end;
end;

function LoadSchemeFromJsonFile(const APath: string; out AScheme: TSyntaxScheme;
  out AError: string): Boolean;
var
  SL: TStringList;
  Id: string;
begin
  if not FileExists(APath) then begin
    AError := 'File not found: ' + APath;
    Exit(False);
  end;
  SL := TStringList.Create;
  try
    SL.LoadFromFile(APath);
    Id := ChangeFileExt(ExtractFileName(APath), '');
    Result := LoadSchemeFromJsonText(SL.Text, Id, APath, AScheme, AError);
  finally
    SL.Free;
  end;
end;

procedure SetAttrColor(AAttr: TSynHighlighterAttributes; AColor: TColor; ABold: Boolean);
begin
  if AAttr = nil then Exit;
  if AColor <> clNone then
    AAttr.Foreground := AColor;
  if ABold then
    AAttr.Style := AAttr.Style + [fsBold]
  else
    AAttr.Style := AAttr.Style - [fsBold];
end;

procedure ApplySchemeToSynAnyHighlighter(AHighlighter: TObject; const AScheme: TSyntaxScheme);
var
  HL: TSynAnySyn;
begin
  if not (AHighlighter is TSynAnySyn) then Exit;
  HL := TSynAnySyn(AHighlighter);
  SetAttrColor(HL.CommentAttri, AScheme.Colors[stkComment], False);
  SetAttrColor(HL.KeyAttri, AScheme.Colors[stkKeyword], AScheme.BoldKeyword);
  SetAttrColor(HL.StringAttri, AScheme.Colors[stkString], False);
  SetAttrColor(HL.NumberAttri, AScheme.Colors[stkNumber], False);
  SetAttrColor(HL.SymbolAttri, AScheme.Colors[stkOperator], False);
  SetAttrColor(HL.IdentifierAttri, AScheme.Colors[stkText], False);
end;

end.
