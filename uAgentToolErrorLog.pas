unit uAgentToolErrorLog;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, Contnrs, Forms, uAppTypes, uAgentExecutionLog;

type
  TToolErrorLogEntry = class
  public
    Timestamp: TDateTime;
    Caption: string;
    ToolName: string;
    ToolArgsJson: string;
    ToolOutputJson: string;
    Summary: string;
    WasException: Boolean;
    ExceptionClass: string;
    function BuildInspectorMarkdown: string;
  end;

  TAgentToolErrorLog = class
  private
    FEntries: TObjectList;
    FLock: TCriticalSection;
    FSessionId: string;
    FWorkspaceId: string;
    FWorkspaceRoot: string;
    function NewEntry: TToolErrorLogEntry;
    procedure AppendFileLine(AEntry: TToolErrorLogEntry);
  public
    constructor Create(const ASessionId, AWorkspaceId, AWorkspaceRoot: string);
    destructor Destroy; override;
    procedure Clear;
    function Count: Integer;
    function Entry(AIndex: Integer): TToolErrorLogEntry;
    function Add(const AToolName, AArgsJson, AOutputJson, ASummary, AExceptionClass: string;
      AWasException: Boolean): Integer;
    property SessionId: string read FSessionId;
  end;

function ToolErrorLogDir: string;
function ToolErrorLogFilePath: string;
procedure AppendToolErrorLogFile(const AWorkspaceId, AWorkspaceRoot, ASessionId, AToolName,
  AArgsJson, AOutputJson, ASummary, AExceptionClass: string; AWasException: Boolean;
  ATimestamp: TDateTime);

implementation

uses
  fpjson, DateUtils, uExecutionDetailText;

function ToolErrorLogDir: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'lazycodingagent';
end;

function ToolErrorLogFilePath: string;
begin
  Result := IncludeTrailingPathDelimiter(ToolErrorLogDir) + 'tool-errors.log';
end;

procedure EnsureToolErrorLogDir;
begin
  ForceDirectories(ToolErrorLogDir);
end;

procedure AppendToolErrorLogFile(const AWorkspaceId, AWorkspaceRoot, ASessionId, AToolName,
  AArgsJson, AOutputJson, ASummary, AExceptionClass: string; AWasException: Boolean;
  ATimestamp: TDateTime);
var
  O: TJSONObject;
  Line: RawByteString;
  FS: TFileStream;
begin
  try
    EnsureToolErrorLogDir;
    O := TJSONObject.Create;
    try
      O.Add('timestamp', FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss', ATimestamp));
      O.Add('workspace_id', AWorkspaceId);
      O.Add('workspace_root', AWorkspaceRoot);
      O.Add('session_id', ASessionId);
      O.Add('tool', AToolName);
      O.Add('was_exception', AWasException);
      if AExceptionClass <> '' then
        O.Add('exception_class', AExceptionClass);
      O.Add('summary', ASummary);
      O.Add('args', AArgsJson);
      O.Add('output', AOutputJson);
      Line := UTF8Encode(O.AsJSON + LineEnding);
    finally
      O.Free;
    end;
    if FileExists(ToolErrorLogFilePath) then
      FS := TFileStream.Create(ToolErrorLogFilePath, fmOpenWrite or fmShareDenyWrite)
    else
      FS := TFileStream.Create(ToolErrorLogFilePath, fmCreate or fmShareDenyWrite);
    try
      FS.Seek(0, soEnd);
      if Length(Line) > 0 then
        FS.WriteBuffer(Line[1], Length(Line));
    finally
      FS.Free;
    end;
  except
    // Never raise from logging
  end;
end;

function TToolErrorLogEntry.BuildInspectorMarkdown: string;
var
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    AppendDetailSectionHeader(SB, 'Tool error');
    SB.AppendLine(FormatDateTime('yyyy-mm-dd hh:nn:ss', Timestamp));
    SB.AppendLine;
    AppendDetailToolLine(SB, ToolName, WasException);
    if WasException and (ExceptionClass <> '') then
      SB.AppendLine('_Class: ' + ExceptionClass + '_');
    AppendDetailSectionHeader(SB, 'Summary');
    AppendDetailProseBlock(SB, Summary);
    AppendDetailSectionHeader(SB, 'Input (arguments)');
    AppendDetailJsonBlock(SB, ToolArgsJson);
    AppendDetailSectionHeader(SB, 'Output');
    AppendDetailJsonBlock(SB, ToolOutputJson);
    AppendDetailSectionHeader(SB, 'On-disk log');
    AppendDetailProseBlock(SB, ToolErrorLogFilePath);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

{ TAgentToolErrorLog }

constructor TAgentToolErrorLog.Create(const ASessionId, AWorkspaceId, AWorkspaceRoot: string);
begin
  inherited Create;
  FSessionId := ASessionId;
  FWorkspaceId := AWorkspaceId;
  FWorkspaceRoot := AWorkspaceRoot;
  FEntries := TObjectList.Create(True);
  FLock := TCriticalSection.Create;
end;

destructor TAgentToolErrorLog.Destroy;
begin
  FLock.Free;
  FEntries.Free;
  inherited Destroy;
end;

procedure TAgentToolErrorLog.Clear;
begin
  FLock.Enter;
  try
    FEntries.Clear;
  finally
    FLock.Leave;
  end;
end;

function TAgentToolErrorLog.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FEntries.Count;
  finally
    FLock.Leave;
  end;
end;

function TAgentToolErrorLog.Entry(AIndex: Integer): TToolErrorLogEntry;
begin
  FLock.Enter;
  try
    Result := TToolErrorLogEntry(FEntries[AIndex]);
  finally
    FLock.Leave;
  end;
end;

function TAgentToolErrorLog.NewEntry: TToolErrorLogEntry;
begin
  Result := TToolErrorLogEntry.Create;
  Result.Timestamp := Now;
  FEntries.Add(Result);
end;

procedure TAgentToolErrorLog.AppendFileLine(AEntry: TToolErrorLogEntry);
begin
  AppendToolErrorLogFile(FWorkspaceId, FWorkspaceRoot, FSessionId, AEntry.ToolName,
    AEntry.ToolArgsJson, AEntry.ToolOutputJson, AEntry.Summary, AEntry.ExceptionClass,
    AEntry.WasException, AEntry.Timestamp);
end;

function TAgentToolErrorLog.Add(const AToolName, AArgsJson, AOutputJson, ASummary,
  AExceptionClass: string; AWasException: Boolean): Integer;
var
  E: TToolErrorLogEntry;
  Cap: string;
begin
  FLock.Enter;
  try
    E := NewEntry;
    E.ToolName := AToolName;
    E.ToolArgsJson := AArgsJson;
    E.ToolOutputJson := AOutputJson;
    E.Summary := ASummary;
    E.WasException := AWasException;
    E.ExceptionClass := AExceptionClass;
    if ASummary <> '' then
      Cap := ASummary
    else
      Cap := TruncateLogCaption(AOutputJson);
    if AWasException then
      E.Caption := '⚠ ' + AToolName + ': ' + TruncateLogCaption(Cap)
    else
      E.Caption := '✕ ' + AToolName + ': ' + TruncateLogCaption(Cap);
    AppendFileLine(E);
    Result := FEntries.Count - 1;
  finally
    FLock.Leave;
  end;
end;

end.
