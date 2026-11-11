unit uAgentToolBase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, uAppTypes, uAgentTypes;

type
  TWorkspaceModeSet = set of TWorkspaceMode;

  TAgentToolSession = class
  public
    Tasks: TJSONArray;
    Diagnostics: TJSONObject;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
  end;

  TToolExecutionResult = record
    Success: Boolean;
    Output: string;
    Summary: string;
    WasException: Boolean;
    ExceptionClass: string;
    Attachments: TChatAttachmentArray;
  end;

  TAgentToolContext = class
  private
    FWorkspaceRoot: string;
    FMode: TWorkspaceMode;
    FSession: TAgentToolSession;
    FCancelFlag: PBoolean;
    FCancelDeadline: QWord;
    FAllowModifyOutsideWorkspace: Boolean;
    FChatSessionId: string;
    FAllowBrowserLocalhost: Boolean;
    FAllowBrowserInteractive: Boolean;
    FAllowBrowserSensitive: Boolean;
  public
    constructor Create(const AWorkspaceRoot: string);
    destructor Destroy; override;

    function ResolvePath(const APath: string; AForWrite: Boolean = True): string;
    function IsCancelled: Boolean;
    procedure SetCancelFlag(AFlag: PBoolean);
    procedure SetCancelDeadline(ADeadline: QWord);
    procedure ClearSession;

    property WorkspaceRoot: string read FWorkspaceRoot write FWorkspaceRoot;
    property Mode: TWorkspaceMode read FMode write FMode;
    property Session: TAgentToolSession read FSession;
    property AllowModifyOutsideWorkspace: Boolean read FAllowModifyOutsideWorkspace
      write FAllowModifyOutsideWorkspace;
    property ChatSessionId: string read FChatSessionId write FChatSessionId;
    property AllowBrowserLocalhost: Boolean read FAllowBrowserLocalhost
      write FAllowBrowserLocalhost;
    property AllowBrowserInteractive: Boolean read FAllowBrowserInteractive
      write FAllowBrowserInteractive;
    property AllowBrowserSensitive: Boolean read FAllowBrowserSensitive
      write FAllowBrowserSensitive;
  end;

  TAgentTool = class
  protected
    FContext: TAgentToolContext;
    FAliases: string;
    FAllowedModes: TWorkspaceModeSet;
    FAdvertised: Boolean;
    FMutatesFiles: Boolean;
  public
    constructor Create(AContext: TAgentToolContext); virtual;
    function MatchesName(const AName: string): Boolean; virtual;
    function GetDefinition: TToolDef; virtual; abstract;
    function Execute(const Args: TJSONObject): TToolExecutionResult; virtual; abstract;
    function ToolAllowedInMode(AMode: TWorkspaceMode): Boolean; virtual;
    function IsAdvertised(AMode: TWorkspaceMode): Boolean; virtual;

    property Context: TAgentToolContext read FContext;
    property Aliases: string read FAliases write FAliases;
    property AllowedModes: TWorkspaceModeSet read FAllowedModes write FAllowedModes;
    property Advertised: Boolean read FAdvertised write FAdvertised;
    property MutatesFiles: Boolean read FMutatesFiles write FMutatesFiles;
  end;

  TAgentToolClass = class of TAgentTool;

function CurrentToolContext: TAgentToolContext;
procedure SetCurrentToolContext(AContext: TAgentToolContext);

function SafeToolText(const S: RawByteString; MaxBytes: Integer = MaxInt): UTF8String;
function ToolError(const AMessage: string): string;
function JsonToolArgumentsWellFormed(const S: string): Boolean;
function TryGetJSONObject(const S: string; out Obj: TJSONObject): Boolean;
function ToolArgumentsJsonIsValid(const AArgumentsJson: string): Boolean;
function TryParseToolArguments(const AName, AArgumentsJson: string;
  out Args: TJSONObject; out ErrMsg: string): Boolean;
function ToolResultFromJson(const AJson: string): TToolExecutionResult;
function ToolDefToParametersJson(const Def: TToolDef): string;
function WorkspaceModeToCaption(AMode: TWorkspaceMode): string;
function ToolCancelled: Boolean;
function NotifyToolFileChanged(const APath: string): string;

implementation

uses
  uAgentToolPaths;

var
  GActiveToolContext: TAgentToolContext = nil;

function CurrentToolContext: TAgentToolContext;
begin
  Result := GActiveToolContext;
end;

procedure SetCurrentToolContext(AContext: TAgentToolContext);
begin
  GActiveToolContext := AContext;
end;

function WorkspaceModeToCaption(AMode: TWorkspaceMode): string;
begin
  Result := WorkspaceModeCaption(AMode);
end;

function SafeToolText(const S: RawByteString; MaxBytes: Integer): UTF8String;
var
  I, J, N, W, B, SecondMin, SecondMax: Integer;
begin
  if Int64(Length(S)) * 3 < Int64(MaxBytes) then
    SetLength(Result, Length(S) * 3)
  else
    SetLength(Result, MaxBytes);
  I := 1;
  W := 0;
  while I <= Length(S) do
  begin
    B := Ord(S[I]);
    N := 0;
    SecondMin := $80;
    SecondMax := $BF;
    if B < $80 then
      N := 1
    else if (B >= $C2) and (B <= $DF) then
      N := 2
    else if (B >= $E0) and (B <= $EF) then
    begin
      N := 3;
      if B = $E0 then SecondMin := $A0;
      if B = $ED then SecondMax := $9F;
    end
    else if (B >= $F0) and (B <= $F4) then
    begin
      N := 4;
      if B = $F0 then SecondMin := $90;
      if B = $F4 then SecondMax := $8F;
    end;
    if I + N - 1 > Length(S) then N := 0;
    if N > 1 then
    begin
      if (Ord(S[I + 1]) < SecondMin) or (Ord(S[I + 1]) > SecondMax) then N := 0;
      for J := 2 to N - 1 do
        if (Ord(S[I + J]) < $80) or (Ord(S[I + J]) > $BF) then begin N := 0; Break; end;
    end;
    if N = 0 then
    begin
      if W + 3 > MaxBytes then Break;
      Result[W + 1] := #239;
      Result[W + 2] := #191;
      Result[W + 3] := #189;
      Inc(W, 3);
      Inc(I);
    end
    else
    begin
      if W + N > MaxBytes then Break;
      Move(S[I], Result[W + 1], N);
      Inc(W, N);
      Inc(I, N);
    end;
  end;
  SetLength(Result, W);
end;

function ToolError(const AMessage: string): string;
var
  O: TJSONObject;
begin
  O := TJSONObject.Create(['error', SafeToolText(AMessage)]);
  try
    Result := O.AsJSON;
  finally
    O.Free;
  end;
end;

function JsonIsWhitespace(C: Char): Boolean; inline;
begin
  Result := C in [#9, #10, #13, ' '];
end;

procedure JsonSkipWhitespace(const S: string; var I: Integer);
begin
  while (I <= Length(S)) and JsonIsWhitespace(S[I]) do
    Inc(I);
end;

function JsonParseString(const S: string; var I: Integer): Boolean;
var
  C: Char;
begin
  if (I > Length(S)) or (S[I] <> '"') then Exit(False);
  Inc(I);
  while I <= Length(S) do
  begin
    C := S[I];
    if C = '"' then
    begin
      Inc(I);
      Exit(True);
    end;
    if C = '\' then
    begin
      Inc(I);
      if I > Length(S) then Exit(False);
      if S[I] = 'u' then
      begin
        if I + 4 > Length(S) then Exit(False);
        Inc(I, 5);
        Continue;
      end;
      Inc(I);
      Continue;
    end;
    if C in [#10, #13] then Exit(False);
    Inc(I);
  end;
  Result := False;
end;

function JsonParseLiteral(const S: string; var I: Integer; const Lit: string): Boolean;
var
  J: Integer;
begin
  for J := 1 to Length(Lit) do
  begin
    if (I > Length(S)) or (S[I] <> Lit[J]) then Exit(False);
    Inc(I);
  end;
  Result := True;
end;

function JsonParseNumber(const S: string; var I: Integer): Boolean;
var
  C: Char;
  SawDigit: Boolean;
begin
  SawDigit := False;
  if (I <= Length(S)) and (S[I] = '-') then Inc(I);
  while I <= Length(S) do
  begin
    C := S[I];
    if C in ['0'..'9'] then
    begin
      SawDigit := True;
      Inc(I);
      Continue;
    end;
    Break;
  end;
  if (I <= Length(S)) and (S[I] = '.') then
  begin
    Inc(I);
    while (I <= Length(S)) and (S[I] in ['0'..'9']) do
    begin
      SawDigit := True;
      Inc(I);
    end;
  end;
  if (I <= Length(S)) and (S[I] in ['e', 'E']) then
  begin
    Inc(I);
    if (I <= Length(S)) and (S[I] in ['+', '-']) then Inc(I);
    while (I <= Length(S)) and (S[I] in ['0'..'9']) do
    begin
      SawDigit := True;
      Inc(I);
    end;
  end;
  Result := SawDigit;
end;

function JsonParseValue(const S: string; var I: Integer): Boolean; forward;

function JsonParseArray(const S: string; var I: Integer): Boolean;
begin
  if (I > Length(S)) or (S[I] <> '[') then Exit(False);
  Inc(I);
  JsonSkipWhitespace(S, I);
  if (I <= Length(S)) and (S[I] = ']') then
  begin
    Inc(I);
    Exit(True);
  end;
  while I <= Length(S) do
  begin
    if not JsonParseValue(S, I) then Exit(False);
    JsonSkipWhitespace(S, I);
    if I > Length(S) then Exit(False);
    if S[I] = ']' then
    begin
      Inc(I);
      Exit(True);
    end;
    if S[I] <> ',' then Exit(False);
    Inc(I);
    JsonSkipWhitespace(S, I);
  end;
  Result := False;
end;

function JsonParseObject(const S: string; var I: Integer): Boolean;
begin
  if (I > Length(S)) or (S[I] <> '{') then Exit(False);
  Inc(I);
  JsonSkipWhitespace(S, I);
  if (I <= Length(S)) and (S[I] = '}') then
  begin
    Inc(I);
    Exit(True);
  end;
  while I <= Length(S) do
  begin
    if not JsonParseString(S, I) then Exit(False);
    JsonSkipWhitespace(S, I);
    if (I > Length(S)) or (S[I] <> ':') then Exit(False);
    Inc(I);
    JsonSkipWhitespace(S, I);
    if not JsonParseValue(S, I) then Exit(False);
    JsonSkipWhitespace(S, I);
    if I > Length(S) then Exit(False);
    if S[I] = '}' then
    begin
      Inc(I);
      Exit(True);
    end;
    if S[I] <> ',' then Exit(False);
    Inc(I);
    JsonSkipWhitespace(S, I);
  end;
  Result := False;
end;

function JsonParseValue(const S: string; var I: Integer): Boolean;
begin
  JsonSkipWhitespace(S, I);
  if I > Length(S) then Exit(False);
  case S[I] of
    '"': Exit(JsonParseString(S, I));
    '{': Exit(JsonParseObject(S, I));
    '[': Exit(JsonParseArray(S, I));
    't': Exit(JsonParseLiteral(S, I, 'true'));
    'f': Exit(JsonParseLiteral(S, I, 'false'));
    'n': Exit(JsonParseLiteral(S, I, 'null'));
    '-', '0'..'9': Exit(JsonParseNumber(S, I));
  else
    Exit(False);
  end;
end;

function JsonToolArgumentsWellFormed(const S: string): Boolean;
var
  T: string;
  I: Integer;
begin
  T := Trim(S);
  if T = '' then Exit(True);
  I := 1;
  if not JsonParseObject(T, I) then Exit(False);
  JsonSkipWhitespace(T, I);
  Result := I > Length(T);
end;

function TryGetJSONObject(const S: string; out Obj: TJSONObject): Boolean;
var
  Parser: TJSONParser;
  Data: TJSONData;
  T: string;
begin
  Result := False;
  Obj := nil;
  T := Trim(S);
  if T = '' then
  begin
    Obj := TJSONObject.Create;
    Exit(True);
  end;
  if not JsonToolArgumentsWellFormed(T) then
    Exit;
  Parser := TJSONParser.Create(T);
  try
    try
      Data := Parser.Parse;
      if Data is TJSONObject then
      begin
        Obj := TJSONObject(Data);
        Result := True;
      end
      else
        Data.Free;
    except
      Result := False;
    end;
  finally
    Parser.Free;
  end;
end;

function ToolArgumentsJsonIsValid(const AArgumentsJson: string): Boolean;
begin
  Result := JsonToolArgumentsWellFormed(AArgumentsJson);
end;

function TryParseToolArguments(const AName, AArgumentsJson: string;
  out Args: TJSONObject; out ErrMsg: string): Boolean;
var
  Prefix: string;
begin
  Args := nil;
  ErrMsg := '';
  if not JsonToolArgumentsWellFormed(AArgumentsJson) then
  begin
    Prefix := string(SafeToolText(AArgumentsJson, 120));
    if Length(Trim(AArgumentsJson)) > Length(Prefix) then
      Prefix := Prefix + '…';
    ErrMsg := Format('JSON argument parsing error for tool %s (%d bytes): %s',
      [AName, Length(AArgumentsJson), Prefix]);
    if Trim(Prefix) = '' then
      ErrMsg := Format('JSON argument parsing error for tool %s (empty or invalid JSON)',
        [AName]);
    Exit(False);
  end;
  if not TryGetJSONObject(AArgumentsJson, Args) then
  begin
    Prefix := string(SafeToolText(AArgumentsJson, 120));
    if Length(Trim(AArgumentsJson)) > Length(Prefix) then
      Prefix := Prefix + '…';
    ErrMsg := Format('JSON argument parsing error for tool %s (%d bytes): %s',
      [AName, Length(AArgumentsJson), Prefix]);
    if Trim(Prefix) = '' then
      ErrMsg := Format('JSON argument parsing error for tool %s (empty or invalid JSON)',
        [AName]);
    Exit(False);
  end;
  Result := True;
end;

function StringArrayToJsonEnum(const AValues: array of string): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  for I := Low(AValues) to High(AValues) do
    Result.Add(AValues[I]);
end;

function ToolDefToParametersJson(const Def: TToolDef): string;
var
  ParamObj, PropsObj: TJSONObject;
  ReqArray: TJSONArray;
  I: Integer;
  PropDetail: TJSONObject;
  ParamType: string;
  EnumArr: TJSONArray;
begin
  ParamObj := TJSONObject.Create;
  try
    ParamObj.Add('type', 'object');
    PropsObj := TJSONObject.Create;
    ReqArray := TJSONArray.Create;
    for I := Low(Def.Params) to High(Def.Params) do begin
      PropDetail := TJSONObject.Create;
      if Length(Def.Params[I].EnumValues) > 0 then begin
        PropDetail.Add('type', 'string');
        EnumArr := StringArrayToJsonEnum(Def.Params[I].EnumValues);
        PropDetail.Add('enum', EnumArr);
      end else begin
        ParamType := Trim(Def.Params[I].ParamType);
        if ParamType = '' then
          PropDetail.Add('type', 'string')
        else
          PropDetail.Add('type', ParamType);
      end;
      PropDetail.Add('description', Def.Params[I].Description);
      PropsObj.Add(Def.Params[I].Name, PropDetail);
      if Def.Params[I].Required then
        ReqArray.Add(Def.Params[I].Name);
    end;
    ParamObj.Add('properties', PropsObj);
    ParamObj.Add('required', ReqArray);
    Result := ParamObj.AsJSON;
  finally
    ParamObj.Free;
  end;
end;

function ToolResultFromJson(const AJson: string): TToolExecutionResult;
var
  O: TJSONObject;
begin
  Result.Output := AJson;
  Result.Success := True;
  Result.Summary := 'OK';
  Result.WasException := False;
  Result.ExceptionClass := '';
  if Trim(AJson) = '' then Exit;
  if AJson[1] <> '{' then Exit;
  if not TryGetJSONObject(AJson, O) then Exit;
  try
    if O.Find('success') <> nil then
      Result.Success := O.Get('success', True);
    if O.Find('error') <> nil then
    begin
      Result.Success := False;
      Result.Summary := O.Get('error', 'Error');
      if O.Find('error_code') <> nil then
        Result.Summary := O.Get('error_code', '') + ': ' + Result.Summary
      else if O.Find('error_kind') <> nil then
        Result.Summary := O.Get('error_kind', '') + ': ' + Result.Summary;
    end
    else if O.Find('status') <> nil then
      Result.Summary := O.Get('status', 'success')
    else
      Result.Summary := 'OK';
  finally
    O.Free;
  end;
end;

function ToolCancelled: Boolean;
begin
  Result := Assigned(GActiveToolContext) and GActiveToolContext.IsCancelled;
end;

function NotifyToolFileChanged(const APath: string): string;
begin
  Result := '';
  { Standalone app: no IDE refresh hook yet. }
  if APath <> '' then ;
end;

{ TAgentToolSession }

constructor TAgentToolSession.Create;
begin
  inherited Create;
  Tasks := TJSONArray.Create;
  Diagnostics := TJSONObject.Create;
end;

destructor TAgentToolSession.Destroy;
begin
  Tasks.Free;
  Diagnostics.Free;
  inherited Destroy;
end;

procedure TAgentToolSession.Clear;
begin
  Tasks.Clear;
  Diagnostics.Clear;
end;

{ TAgentToolContext }

constructor TAgentToolContext.Create(const AWorkspaceRoot: string);
begin
  inherited Create;
  if Trim(AWorkspaceRoot) <> '' then
    FWorkspaceRoot := ExpandFileName(AWorkspaceRoot)
  else
    FWorkspaceRoot := GetCurrentDir;
  FMode := wmAgent;
  FSession := TAgentToolSession.Create;
  FCancelFlag := nil;
  FCancelDeadline := 0;
  FAllowModifyOutsideWorkspace := False;
end;

destructor TAgentToolContext.Destroy;
begin
  FSession.Free;
  inherited Destroy;
end;

function TAgentToolContext.ResolvePath(const APath: string; AForWrite: Boolean): string;
begin
  if AForWrite then
    Result := uAgentToolPaths.ResolveProjectPath(APath, paWrite)
  else
    Result := uAgentToolPaths.ResolveProjectPath(APath, paRead);
end;

function TAgentToolContext.IsCancelled: Boolean;
begin
  Result := Assigned(FCancelFlag) and FCancelFlag^;
  if not Result and (FCancelDeadline > 0) then
    Result := GetTickCount64 >= FCancelDeadline;
end;

procedure TAgentToolContext.SetCancelFlag(AFlag: PBoolean);
begin
  FCancelFlag := AFlag;
end;

procedure TAgentToolContext.SetCancelDeadline(ADeadline: QWord);
begin
  FCancelDeadline := ADeadline;
end;

procedure TAgentToolContext.ClearSession;
begin
  FSession.Clear;
end;

{ TAgentTool }

constructor TAgentTool.Create(AContext: TAgentToolContext);
begin
  inherited Create;
  FContext := AContext;
  FAliases := '';
  FAllowedModes := [wmAgent];
  FAdvertised := True;
  FMutatesFiles := True;
end;

function TAgentTool.MatchesName(const AName: string): Boolean;
var
  Def: TToolDef;
begin
  Def := GetDefinition;
  if SameText(Def.Name, AName) then Exit(True);
  Result := Pos(';' + LowerCase(AName) + ';', ';' + LowerCase(FAliases) + ';') > 0;
end;

function TAgentTool.ToolAllowedInMode(AMode: TWorkspaceMode): Boolean;
begin
  Result := AMode in FAllowedModes;
end;

function TAgentTool.IsAdvertised(AMode: TWorkspaceMode): Boolean;
begin
  Result := FAdvertised;
end;

end.
