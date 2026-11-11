program test_mcp_json_tools;

{$mode objfpc}{$H+}

uses
  SysUtils, uMcpJson, uMcpTypes;

procedure Fail(const Msg: string);
begin
  WriteLn('FAIL: ', Msg);
  Halt(1);
end;

procedure TestToolsListParse;
const
  SAMPLE =
    '{"jsonrpc":"2.0","id":1,"result":{"tools":[' +
    '{"name":"search","description":"Search docs","inputSchema":' +
    '{"type":"object","properties":{"q":{"type":"string","description":"query"}},' +
    '"required":["q"]}}]}}';
var
  Tools: TMcpToolInfoArray;
  Err: string;
  Def: TToolDef;
begin
  if not ParseMcpToolsListResponse(SAMPLE, Tools, Err) then
    Fail('Parse failed: ' + Err);
  if Length(Tools) <> 1 then
    Fail('Tool count');
  if Tools[0].Name <> 'search' then
    Fail('Tool name');
  Def := McpToolInfoToToolDef(Tools[0]);
  if Length(Def.Params) <> 1 then
    Fail('Param count');
  if Def.Params[0].Name <> 'q' then
    Fail('Param name');
  if not Def.Params[0].Required then
    Fail('Param required');
end;

procedure TestJsonRpcBodyExtract;
var
  Plain, Sse, Inner: string;
begin
  Plain := '{"jsonrpc":"2.0","id":1,"result":{}}';
  if ExtractJsonRpcFromHttpBody(Plain) <> Plain then
    Fail('Plain JSON body extract');
  Sse := 'event: message' + LineEnding +
    'data: {"jsonrpc":"2.0","id":2,"result":{"tools":[]}}' + LineEnding + LineEnding;
  Inner := ExtractJsonRpcFromHttpBody(Sse);
  if Pos('"tools"', Inner) = 0 then
    Fail('SSE body extract');
end;

procedure TestJsonRpcErrorMessage;
begin
  if JsonRpcErrorMessage('{"jsonrpc":"2.0","id":1,"error":{"message":"auth failed"}}') <>
    'auth failed' then
    Fail('JsonRpcErrorMessage text');
  if JsonRpcErrorMessage('{"jsonrpc":"2.0","id":1,"result":{}}') <> '' then
    Fail('JsonRpcErrorMessage on success');
end;

procedure TestJsonRpcValidate;
var
  Err: string;
begin
  if not JsonRpcValidateResponse('{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05"}}', Err) then
    Fail('Validate initialize-shaped response: ' + Err);
  if JsonRpcValidateResponse('{"jsonrpc":"2.0","id":1,"error":{"message":"nope"}}', Err) then
    Fail('Validate should fail on error');
end;

begin
  TestToolsListParse;
  TestJsonRpcBodyExtract;
  TestJsonRpcErrorMessage;
  TestJsonRpcValidate;
  WriteLn('OK test_mcp_json_tools');
end.
