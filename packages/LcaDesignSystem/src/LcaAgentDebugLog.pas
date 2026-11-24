unit LcaAgentDebugLog;

{$mode objfpc}{$H+}

{ Temporary NDJSON probe for chat markdown blank-view investigation. }

interface

procedure LcaAgentDbgLog(const ALocation, AMessage, AHypothesisId: string;
  const ADataJson: string = '{}');

implementation

uses
  SysUtils, Classes;

const
  LCA_AGENT_DBG_LOG = '/home/lazy/Projects/lazycodingagent/.cursor/debug-7a7a88.log';
  LCA_AGENT_DBG_SESSION = '7a7a88';

function JsonEscape(const S: string): string;
begin
  Result := StringReplace(S, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
end;

procedure LcaAgentDbgLog(const ALocation, AMessage, AHypothesisId: string;
  const ADataJson: string);
var
  FS: TFileStream;
  Line: RawByteString;
  Dir, Data: string;
begin
  Dir := ExtractFilePath(LCA_AGENT_DBG_LOG);
  if not DirectoryExists(Dir) then Exit;
  if ADataJson = '' then
    Data := '{}'
  else
    Data := ADataJson;
  Line := RawByteString(
    Format('{"sessionId":"%s","timestamp":%d,"location":"%s","message":"%s",' +
      '"hypothesisId":"%s","data":%s}' + LineEnding,
      [LCA_AGENT_DBG_SESSION, GetTickCount64, JsonEscape(ALocation), JsonEscape(AMessage),
       JsonEscape(AHypothesisId), Data]));
  try
    if FileExists(LCA_AGENT_DBG_LOG) then
      FS := TFileStream.Create(LCA_AGENT_DBG_LOG, fmOpenWrite or fmShareDenyNone)
    else
      FS := TFileStream.Create(LCA_AGENT_DBG_LOG, fmCreate or fmShareDenyNone);
    try
      FS.Seek(0, soEnd);
      if Length(Line) > 0 then
        FS.WriteBuffer(Line[1], Length(Line));
    finally
      FS.Free;
    end;
  except
  end;
end;

end.