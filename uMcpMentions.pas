unit uMcpMentions;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, uAgentTypes, uMcpTypes;

type
  TStringArray = array of string;

procedure ParseMcpMentions(const AText: string; out AAliases: TStringArray);
procedure RegisterAliasesFromText(AList: TStrings; const AText: string);
procedure RescanUserMessagesForMcpMentions(AList: TStrings; const AMessages: array of TChatMessage);
function KnownAliasesFromMentions(const AText: string; const AConnections: TMcpConnectionArray): TStringArray;
function UnknownMentionHint(const AText: string; const AConnections: TMcpConnectionArray): string;

implementation

uses
  uMcpConfig;

function IsAliasChar(C: Char): Boolean;
begin
  Result := C in ['A'..'Z', 'a'..'z', '0'..'9', '_'];
end;

function IsMentionStart(const AText: string; AAtPos: Integer): Boolean;
begin
  Result := True;
  if AAtPos > 1 then
    Result := not IsAliasChar(AText[AAtPos - 1]);
end;

procedure ParseMcpMentions(const AText: string; out AAliases: TStringArray);
var
  I, Start, N: Integer;
  Alias: string;

  procedure AddAlias(const S: string);
  var
    J: Integer;
  begin
    if (S = '') or not McpAliasIsValid(S) then Exit;
    for J := 0 to High(AAliases) do
      if SameText(AAliases[J], S) then Exit;
    SetLength(AAliases, N + 1);
    AAliases[N] := S;
    Inc(N);
  end;

begin
  SetLength(AAliases, 0);
  N := 0;
  I := 1;
  while I <= Length(AText) do
  begin
    if (AText[I] = '@') and IsMentionStart(AText, I) then
    begin
      Start := I + 1;
      Alias := '';
      while (Start <= Length(AText)) and IsAliasChar(AText[Start]) do
      begin
        Alias := Alias + AText[Start];
        Inc(Start);
      end;
      AddAlias(Alias);
      I := Start;
      Continue;
    end;
    Inc(I);
  end;
end;

procedure RegisterAliasesFromText(AList: TStrings; const AText: string);
var
  Aliases: TStringArray;
  I: Integer;
begin
  ParseMcpMentions(AText, Aliases);
  for I := 0 to High(Aliases) do
  begin
    if AList.IndexOf(Aliases[I]) < 0 then
      AList.Add(Aliases[I]);
  end;
end;

procedure RescanUserMessagesForMcpMentions(AList: TStrings; const AMessages: array of TChatMessage);
var
  I: Integer;
begin
  AList.Clear;
  for I := 0 to High(AMessages) do
    if AMessages[I].Role = crUser then
      RegisterAliasesFromText(AList, AMessages[I].Content);
end;

function KnownAliasesFromMentions(const AText: string; const AConnections: TMcpConnectionArray): TStringArray;
var
  All, OutArr: TStringArray;
  I, N: Integer;
  Conn: TMcpConnection;
begin
  ParseMcpMentions(AText, All);
  SetLength(OutArr, 0);
  N := 0;
  for I := 0 to High(All) do
    if McpConnectionByAlias(AConnections, All[I], Conn) and Conn.Enabled then
    begin
      SetLength(OutArr, N + 1);
      OutArr[N] := Conn.Name;
      Inc(N);
    end;
  Result := OutArr;
end;

function UnknownMentionHint(const AText: string; const AConnections: TMcpConnectionArray): string;
var
  All: TStringArray;
  I: Integer;
  Conn: TMcpConnection;
  Names: TStringList;
begin
  Result := '';
  ParseMcpMentions(AText, All);
  Names := TStringList.Create;
  try
    for I := 0 to High(All) do
      if not McpConnectionByAlias(AConnections, All[I], Conn) then
        Names.Add('@' + All[I]);
    if Names.Count > 0 then
      Result := 'Unknown MCP plugin mention(s): ' + Names.CommaText +
        ' (configure in Plugins → MCP Connections).';
  finally
    Names.Free;
  end;
end;

end.
