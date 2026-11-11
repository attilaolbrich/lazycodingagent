program test_mcp_mentions;

{$mode objfpc}{$H+}

uses
  SysUtils, uMcpMentions, uMcpTypes, uMcpConfig;

type
  TStringArray = array of string;

procedure Fail(const Msg: string);
begin
  WriteLn('FAIL: ', Msg);
  Halt(1);
end;

procedure TestParseMentions;
var
  Aliases: TStringArray;
begin
  ParseMcpMentions('Hello @myplugin and @other_tool', Aliases);
  if Length(Aliases) <> 2 then
    Fail('Expected 2 aliases');
  if not SameText(Aliases[0], 'myplugin') then
    Fail('First alias');
  if not SameText(Aliases[1], 'other_tool') then
    Fail('Second alias');
  ParseMcpMentions('email@test.com', Aliases);
  if Length(Aliases) <> 0 then
    Fail('Should not parse email as mention');
end;

procedure TestPrefixedNames;
begin
  if McpPrefixedToolName('MyPlugin', 'search') <> 'mcp_myplugin_search' then
    Fail('Prefixed tool name');
  if not McpAliasIsValid('myplugin') then
    Fail('Valid alias rejected');
  if McpAliasIsValid('9bad') then
    Fail('Invalid alias accepted');
end;

begin
  TestParseMentions;
  TestPrefixedNames;
  WriteLn('OK test_mcp_mentions');
end.
