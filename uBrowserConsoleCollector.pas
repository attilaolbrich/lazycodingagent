unit uBrowserConsoleCollector;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uCdpConnection, uBrowserReadTypes;

type
  TBrowserConsoleEntry = record
    Level: string;
    Text: string;
    Url: string;
    Line: Integer;
  end;

  TBrowserConsoleCollector = class
  private
    FEntries: TStringList;
    FLastReadIndex: Integer;
    FMaxEntries: Integer;
    procedure AddEntry(const Level, Text, Url: string; ALine: Integer);
    function Redact(const S: string): string;
  public
    constructor Create(AMaxEntries: Integer = 500);
    destructor Destroy; override;
    procedure HandleEvent(const Method, ParamsJson: AnsiString);
    function ReadEntries(SinceLastRead: Boolean; const LevelFilter: string;
      MaxCount: Integer): TJSONArray;
    procedure Clear;
  end;

implementation

constructor TBrowserConsoleCollector.Create(AMaxEntries: Integer);
begin
  inherited Create;
  FEntries := TStringList.Create;
  FLastReadIndex := 0;
  FMaxEntries := AMaxEntries;
  if FMaxEntries < 50 then
    FMaxEntries := 50;
end;

destructor TBrowserConsoleCollector.Destroy;
begin
  FEntries.Free;
  inherited Destroy;
end;

procedure TBrowserConsoleCollector.Clear;
begin
  FEntries.Clear;
  FLastReadIndex := 0;
end;

function TBrowserConsoleCollector.Redact(const S: string): string;
var
  L: string;
begin
  L := S;
  if Pos('bearer ', LowerCase(L)) > 0 then
    L := StringReplace(L, 'Bearer ', '[redacted] ', [rfIgnoreCase]);
  if Pos('password=', LowerCase(L)) > 0 then
    L := '[redacted password in console]';
  Result := L;
end;

procedure TBrowserConsoleCollector.AddEntry(const Level, Text, Url: string;
  ALine: Integer);
var
  O: TJSONObject;
begin
  O := TJSONObject.Create;
  O.Add('level', Level);
  O.Add('text', Redact(Text));
  O.Add('url', Url);
  O.Add('line', ALine);
  FEntries.Add(O.AsJSON);
  O.Free;
  while FEntries.Count > FMaxEntries do
    FEntries.Delete(0);
  if FLastReadIndex > FEntries.Count then
    FLastReadIndex := FEntries.Count;
end;

procedure TBrowserConsoleCollector.HandleEvent(const Method, ParamsJson: AnsiString);
var
  Root: TJSONObject;
  Args: TJSONArray;
  Arg: TJSONData;
  I: Integer;
  Level, Text, Url: string;
  Line: Integer;
  Stack: TJSONArray;
  Entry: TJSONObject;
begin
  if Method = 'Runtime.consoleAPICalled' then
  begin
    Root := TJSONObject(GetJSON(ParamsJson));
    try
      Level := Root.Get('type', 'log');
      Args := TJSONArray(Root.Find('args'));
      Text := '';
      if Assigned(Args) then
        for I := 0 to Args.Count - 1 do
        begin
          Arg := Args.Items[I];
          if Arg is TJSONObject then
            Text := Text + TJSONObject(Arg).Get('value', TJSONObject(Arg).Get('description', ''))
          else
            Text := Text + Arg.AsString;
        end;
      Stack := TJSONArray(Root.Find('stackTrace'));
      Url := '';
      Line := 0;
      if Assigned(Stack) and (Stack.Count > 0) and (Stack.Items[0] is TJSONObject) then
      begin
        Url := TJSONObject(Stack.Items[0]).Get('url', '');
        Line := TJSONObject(Stack.Items[0]).Get('lineNumber', 0);
      end;
      AddEntry(Level, Text, Url, Line);
    finally
      Root.Free;
    end;
  end
  else if Method = 'Log.entryAdded' then
  begin
    Root := TJSONObject(GetJSON(ParamsJson));
    try
      if not (Root.Find('entry') is TJSONObject) then Exit;
      Entry := TJSONObject(Root.Find('entry'));
      AddEntry(Entry.Get('level', 'info'), Entry.Get('text', ''), Entry.Get('url', ''),
        Entry.Get('lineNumber', 0));
    finally
      Root.Free;
    end;
  end;
end;

function TBrowserConsoleCollector.ReadEntries(SinceLastRead: Boolean;
  const LevelFilter: string; MaxCount: Integer): TJSONArray;
var
  Arr: TJSONArray;
  I, Start, N: Integer;
  O: TJSONObject;
  L: string;
begin
  Arr := TJSONArray.Create;
  if MaxCount <= 0 then
    MaxCount := 100;
  Start := 0;
  if SinceLastRead then
    Start := FLastReadIndex;
  N := 0;
  for I := Start to FEntries.Count - 1 do
  begin
    O := TJSONObject(GetJSON(FEntries[I]));
    try
      L := LowerCase(O.Get('level', ''));
      if (LevelFilter <> '') and not SameText(L, LevelFilter) then
        Continue;
      Arr.Add(O.Clone);
      Inc(N);
      if N >= MaxCount then Break;
    finally
      O.Free;
    end;
  end;
  FLastReadIndex := FEntries.Count;
  Result := Arr;
end;

end.
