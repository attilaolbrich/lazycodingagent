unit uToolArtifactStore;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  TOOL_ARTIFACTS_REL_DIR = '.lca/artifacts/';
  TOOL_ARTIFACT_MAX_BYTES = 8 * 1024 * 1024;

function ToolArtifactsRelativeDir: string;
function CreateToolArtifactPath(const WorkspaceRoot, SessionId, Ext: string): string;
function SaveToolArtifactBytes(const AbsPath: string; const Data: TBytes): Boolean;
procedure CleanupOldArtifacts(const WorkspaceRoot: string; MaxAgeHours: Integer = 24);

implementation

uses
  Classes, DateUtils, uAgentToolPaths;

function ToolArtifactsRelativeDir: string;
begin
  Result := TOOL_ARTIFACTS_REL_DIR;
end;

function CreateToolArtifactPath(const WorkspaceRoot, SessionId, Ext: string): string;
var
  Dir, Name: string;
begin
  Dir := IncludeTrailingPathDelimiter(WorkspaceRoot) + TOOL_ARTIFACTS_REL_DIR;
  if not DirectoryExists(Dir) then
    ForceDirectories(Dir);
  Name := 'shot_' + SessionId + '_' + IntToHex(GetTickCount64, 12) + Ext;
  Result := Dir + Name;
end;

function SaveToolArtifactBytes(const AbsPath: string; const Data: TBytes): Boolean;
var
  FS: TFileStream;
begin
  if Length(Data) > TOOL_ARTIFACT_MAX_BYTES then
    Exit(False);
  FS := TFileStream.Create(AbsPath, fmCreate);
  try
    if Length(Data) > 0 then
      FS.WriteBuffer(Data[0], Length(Data));
    Result := True;
  finally
    FS.Free;
  end;
end;

procedure CleanupOldArtifacts(const WorkspaceRoot: string; MaxAgeHours: Integer);
var
  Dir: string;
  SR: TSearchRec;
  Cutoff: TDateTime;
begin
  Dir := IncludeTrailingPathDelimiter(WorkspaceRoot) + TOOL_ARTIFACTS_REL_DIR;
  if not DirectoryExists(Dir) then Exit;
  Cutoff := IncHour(Now, -MaxAgeHours);
  if FindFirst(Dir + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Attr and faDirectory) <> 0 then Continue;
      if FileDateToDateTime(SR.Time) < Cutoff then
        DeleteFile(PAnsiChar(Dir + SR.Name));
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

end.
