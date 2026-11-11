unit uToolApplyPatch;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAppTypes, uAgentTypes, uAgentToolBase;

function ExecuteApplyPatchJson(A: TJSONObject): string;
function ExecuteEditFileJson(A: TJSONObject): string;

type
  TToolApplyPatch = class(TAgentTool)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

implementation

uses
  uAgentToolPaths, RegExpr, {$IFDEF UNIX}BaseUnix{$ELSE}Windows{$ENDIF};

function CopyPathToFile(const Src, Dst: string): Boolean;
var
  InS, OutS: TFileStream;
begin
  Result := False;
  try
    InS := TFileStream.Create(Src, fmOpenRead or fmShareDenyWrite);
    try
      OutS := TFileStream.Create(Dst, fmCreate);
      try
        OutS.CopyFrom(InS, InS.Size);
      finally
        OutS.Free;
      end;
    finally
      InS.Free;
    end;
    Result := True;
  except
    Result := False;
  end;
end;

function PatchRestoreBackup(const Backup, Target: string): Boolean;
begin
  {$IFDEF WINDOWS}
  Result := MoveFileEx(PChar(Backup), PChar(Target), MOVEFILE_REPLACE_EXISTING);
  {$ELSE}
  Result := RenameFile(Backup, Target);
  {$ENDIF}
end;

procedure RollbackPatchChanges(Changed: TJSONArray; Backups: TStringList; out RollbackFailed: Boolean);
var
  K: Integer;
  Target, Backup: string;
begin
  RollbackFailed := False;
  for K := Changed.Count - 1 downto 0 do
  begin
    Target := Changed.Strings[K];
    Backup := Backups.Values[Target];
    if Backup = '' then
    begin
      if FileExists(Target) and not SysUtils.DeleteFile(Target) then
        RollbackFailed := True;
      Continue;
    end;
    if not PatchRestoreBackup(Backup, Target) then
      RollbackFailed := True
    else
      Backups.Values[Target] := '';
  end;
  for K := 0 to Backups.Count - 1 do
    if Backups.ValueFromIndex[K] <> '' then
      SysUtils.DeleteFile(Backups.ValueFromIndex[K]);
end;

type
  EPatchError = class(Exception)
  public
    ErrorKind, ErrorPath, Hint: string;
    ErrorLine: Integer;
    constructor Create(const AKind, AMessage, APath: string; ALine: Integer = 0;
      const AHint: string = '');
  end;
  TStagedEdit = class
    FilePath, TempPath: string;
    Original, Content: RawByteString;
    Remove, CreateFile: Boolean;
    destructor Destroy; override;
  end;
destructor TStagedEdit.Destroy;
begin if TempPath <> '' then SysUtils.DeleteFile(TempPath); inherited Destroy; end;

procedure SplitLines(const S: RawByteString; Lines, Endings: TStrings);
var I, Start: Integer; E: string;
begin
  I := 1; Start := 1;
  while I <= Length(S) do
  begin
    if S[I] in [#10, #13] then
    begin
      Lines.Add(Copy(S, Start, I-Start)); E := S[I];
      if (S[I] = #13) and (I < Length(S)) and (S[I+1] = #10) then begin E := #13#10; Inc(I); end;
      Endings.Add(E); Start := I+1;
    end;
    Inc(I);
  end;
  if Start <= Length(S) then begin Lines.Add(Copy(S, Start, MaxInt)); Endings.Add(''); end;
end;

function PatchPath(const Header: string): string;
var P: Integer;
begin
  Result := Copy(Header, 5, MaxInt); P := Pos(#9, Result);
  if P > 0 then Result := Copy(Result, 1, P-1);
  if Result = '/dev/null' then Exit;
  if (Copy(Result, 1, 2) = 'a/') or (Copy(Result, 1, 2) = 'b/') then Delete(Result, 1, 2);
  if (Result = '') or (Result[1] = '"') then
    raise EPatchError.Create('format', 'Patch requires unquoted file paths', '', 0);
  Result := ResolveProjectPath(Result, paWrite);
end;

function NextLineStart(const S: string; StartAt: Integer): Integer;
begin
  Result := StartAt;
  while (Result <= Length(S)) and (S[Result] <> #10) do Inc(Result);
  if Result <= Length(S) then Inc(Result);
end;

function FindUnifiedHeader(const S: string): Integer;
var I, Next: Integer;
begin
  Result := 0; I := 1;
  while I <= Length(S) do
  begin
    Next := NextLineStart(S, I);
    if (Copy(S, I, 4) = '--- ') and (Copy(S, Next, 4) = '+++ ') then Exit(I);
    I := Next;
  end;
end;

function FindClosingFence(const S: string; StartAt: Integer): Integer;
var I: Integer;
begin
  Result := 0; I := StartAt;
  while I <= Length(S) do
  begin
    if Copy(S, I, 3) = StringOfChar('`', 3) then Exit(I);
    I := NextLineStart(S, I);
  end;
end;

function NormalizePatch(const Value: string): string;
var S: string; HeaderStart, FenceStart: Integer;
begin
  S := Value;
  if Copy(S, 1, 3) = #239#187#191 then Delete(S, 1, 3);
  S := StringReplace(S, #13#10, #10, [rfReplaceAll]);
  S := StringReplace(S, #13, #10, [rfReplaceAll]);
  { Ignore a short response wrapper around one complete unified diff. }
  HeaderStart := FindUnifiedHeader(S);
  if HeaderStart > 0 then
  begin
    FenceStart := FindClosingFence(S, NextLineStart(S, HeaderStart));
    if FenceStart > 0 then
      S := Copy(S, HeaderStart, FenceStart - HeaderStart)
    else
      S := Copy(S, HeaderStart, MaxInt);
  end;

  Result := S;
end;

constructor EPatchError.Create(const AKind, AMessage, APath: string; ALine: Integer;
  const AHint: string);
begin
  inherited Create(AMessage);
  ErrorKind := AKind;
  ErrorPath := APath;
  ErrorLine := ALine;
  Hint := AHint;
end;

function PatchErrorJSON(const E: EPatchError): string;
var O: TJSONObject;
begin
  O := TJSONObject.Create;
  try
    O.Add('error', E.Message);
    O.Add('error_kind', E.ErrorKind);
    if E.ErrorPath <> '' then O.Add('path', E.ErrorPath);
    if E.ErrorLine > 0 then O.Add('line', E.ErrorLine);
    if E.Hint <> '' then O.Add('hint', E.Hint);
    Result := O.AsJSON;
  finally O.Free; end;
end;

function IsHunkBodyBoundary(const ALine: string): Boolean;
begin
  Result := (Copy(ALine, 1, 2) = '@@') or (Copy(ALine, 1, 4) = '--- ');
end;

function PatchErrorKindForMessage(const AMessage: string): string;
begin
  if Pos('Hunk count mismatch', AMessage) > 0 then Exit('hunk_count_mismatch');
  if Pos('Incomplete hunk', AMessage) > 0 then Exit('incomplete_hunk');
  if (Pos('Invalid hunk', AMessage) > 0) or (Pos('hunk header', LowerCase(AMessage)) > 0) or
     (Pos('Hunk position', AMessage) > 0) or (Pos('Hunk lines require', AMessage) > 0) or
     (Pos('Overlapping or invalid hunk', AMessage) > 0) or (Pos('Invalid new hunk position', AMessage) > 0) or
     (Pos('Old newline marker mismatch', AMessage) > 0) or (Pos('No-newline marker', AMessage) > 0) then
    Exit('invalid_hunk');
  if (Pos('Patch is empty', AMessage) > 0) or (Pos('Patch file has no hunks', AMessage) > 0) then Exit('empty_patch');
  if (Pos('Patch requires unquoted', AMessage) > 0) or (Pos('Invalid patch paths', AMessage) > 0) or
     (Pos('Renaming is unsupported', AMessage) > 0) then Exit('format');
  Result := 'patch_apply';
end;

procedure Stage(Edit: TStagedEdit);
{$IFDEF UNIX}var Info: Stat;{$ENDIF}
begin
  if Edit.Remove then Exit;
  ResolveProjectPath(Edit.FilePath, paWrite);
  if not ForceDirectories(ExtractFileDir(Edit.FilePath)) then raise Exception.Create('Cannot create patch parent directory');
  ResolveProjectPath(Edit.FilePath, paWrite);
  Edit.TempPath := SysUtils.GetTempFileName(ExtractFileDir(Edit.FilePath), '.agent-patch-');
  WriteBytes(Edit.TempPath, Edit.Content);
  {$IFDEF UNIX}
  if not Edit.CreateFile and (fpStat(Edit.FilePath, Info) = 0) then
    if fpChmod(Edit.TempPath, Info.st_mode and &777) <> 0 then raise Exception.Create('Cannot preserve file permissions');
  {$ENDIF}
end;

function Commit(Edits: TList; APatchWarnings: TStrings = nil): string;
var I, J: Integer; Stg: TStagedEdit; O: TJSONObject; Changed, WarnArr: TJSONArray;
  Warning, W, BackupPath: string;
  Backups: TStringList;
  RollbackFailed: Boolean;
begin
  Warning := '';
  Backups := TStringList.Create;
  Backups.NameValueSeparator := '=';
  O := TJSONObject.Create; Changed := TJSONArray.Create; O.Add('changed_paths', Changed);
  try
    try
      for I := 0 to Edits.Count - 1 do
      begin
        Stg := TStagedEdit(Edits[I]);
        ResolveProjectPath(Stg.FilePath, paWrite);
        if Stg.CreateFile then
        begin if FileExists(Stg.FilePath) or DirectoryExists(Stg.FilePath) then raise Exception.Create('Creation target already exists'); end
        else if ReadTextBytes(Stg.FilePath) <> Stg.Original then raise Exception.Create('File changed since patch validation: ' + Stg.FilePath);
      end;
      if ToolCancelled then raise Exception.Create('Tool cancelled');
      for I := 0 to Edits.Count - 1 do
      begin
        if ToolCancelled then raise Exception.Create('Tool cancelled');
        Stage(TStagedEdit(Edits[I]));
      end;
      if ToolCancelled then raise Exception.Create('Tool cancelled');
      for I := 0 to Edits.Count - 1 do
      begin
        if ToolCancelled then raise Exception.Create('Tool cancelled');
        Stg := TStagedEdit(Edits[I]); ResolveProjectPath(Stg.FilePath, paWrite);
        if (not Stg.CreateFile) and FileExists(Stg.FilePath) then
        begin
          BackupPath := SysUtils.GetTempFileName(ExtractFileDir(Stg.FilePath), '.agent-patch-bak-');
          if not CopyPathToFile(Stg.FilePath, BackupPath) then
            raise Exception.Create('Cannot back up ' + Stg.FilePath);
          Backups.Values[Stg.FilePath] := BackupPath;
        end;
      end;
      for I := 0 to Edits.Count - 1 do
      begin
        if ToolCancelled then raise Exception.Create('Tool cancelled');
        Stg := TStagedEdit(Edits[I]); ResolveProjectPath(Stg.FilePath, paWrite);
        if Stg.Remove then
        begin if not SysUtils.DeleteFile(Stg.FilePath) then raise Exception.Create('Cannot delete ' + Stg.FilePath); end
        else
        begin
          {$IFDEF WINDOWS}
          if not MoveFileEx(PChar(Stg.TempPath), PChar(Stg.FilePath), MOVEFILE_REPLACE_EXISTING) then
          {$ELSE}
          if not RenameFile(Stg.TempPath, Stg.FilePath) then
          {$ENDIF}
            raise Exception.Create('Cannot replace ' + Stg.FilePath);
          Stg.TempPath := '';
        end;
        Changed.Add(Stg.FilePath);
        W := NotifyToolFileChanged(Stg.FilePath);
        if W <> '' then Warning := Warning + W + LineEnding;
      end;
      for I := 0 to Backups.Count - 1 do
        if Backups.ValueFromIndex[I] <> '' then
          SysUtils.DeleteFile(Backups.ValueFromIndex[I]);
      O.Add('status', 'success');
      if (APatchWarnings <> nil) and (APatchWarnings.Count > 0) then
      begin
        WarnArr := TJSONArray.Create;
        for J := 0 to APatchWarnings.Count - 1 do
          WarnArr.Add(APatchWarnings[J]);
        O.Add('warnings', WarnArr);
      end;
    except on Ex: Exception do
      begin
        if Changed.Count > 0 then
          RollbackPatchChanges(Changed, Backups, RollbackFailed);
        O.Add('error', Ex.Message);
        O.Add('error_kind', PatchErrorKindForMessage(Ex.Message));
        O.Add('partial', RollbackFailed);
      end;
    end;
    if Warning <> '' then O.Add('tracking_warning', Trim(Warning));
    Result := O.AsJSON;
  finally
    Backups.Free;
    O.Free;
  end;
end;

function ExecuteApplyPatchJson(A: TJSONObject): string;
var
  DiffLines: TStringList; Edits: TList;
  Lines, Endings, Output, OutEndings, PatchWarnings: TStringList;
  R: TRegExpr; Stg: TStagedEdit;
  I, J, Cursor, OldStart, OldCount, NewStart, NewCount, HeaderOldCount, HeaderNewCount: Integer;
  SeenOld, SeenNew, MarkerIndex, HunkCount: Integer;
  OldPath, NewPath, Text, EOL, BOM, RelPath: string; MarkerOld, BrokeAtBoundary: Boolean;
  ContentStream: TStringStream;
  PatchEx: EPatchError;
  procedure AppendOriginal(UntilIndex: Integer);
  begin
    while Cursor < UntilIndex do
    begin
      if Cursor >= Lines.Count then
        raise EPatchError.Create('invalid_hunk', 'Hunk position outside file', Stg.FilePath, Cursor + 1);
      Output.Add(Lines[Cursor]); OutEndings.Add(Endings[Cursor]); Inc(Cursor);
    end;
  end;
  procedure CheckOld(const Value: string);
  begin
    if (Cursor >= Lines.Count) or (Lines[Cursor] <> Value) then
      raise EPatchError.Create('context_mismatch', 'Patch context mismatch in ' +
        Stg.FilePath + ' near line ' + IntToStr(Cursor + 1) +
        '; reread the current file and retry with exact context', Stg.FilePath, Cursor + 1,
        'Copy every - and space line exactly from read_file (entities, quotes, trailing spaces).');
  end;
  procedure ApplyHunkLine(const AText: string);
  var LineText: string;
  begin
    LineText := AText;
    if LineText = '' then LineText := ' ';
    if LineText[1] <> ' ' then
      raise EPatchError.Create('invalid_hunk', 'Invalid hunk line', Stg.FilePath, 0,
        'Each hunk line must start with space, -, or +; blank lines count as context.');
    CheckOld(Copy(LineText, 2, MaxInt));
    Output.Add(Lines[Cursor]); OutEndings.Add(Endings[Cursor]);
    Inc(Cursor); Inc(SeenOld); Inc(SeenNew);
    MarkerIndex := Output.Count - 1; MarkerOld := True;
  end;
begin
  DiffLines := TStringList.Create; Edits := TList.Create;
  Lines := TStringList.Create; Endings := TStringList.Create;
  Output := TStringList.Create; OutEndings := TStringList.Create;
  PatchWarnings := TStringList.Create;
  R := TRegExpr.Create;
  try
    try
      DiffLines.Text := NormalizePatch(A.Get('patch', ''));
    R.Expression := '^@@ -([0-9]+)(,([0-9]+))? \+([0-9]+)(,([0-9]+))? @@';
    I := 0;
    while I < DiffLines.Count do
    begin
      if (Copy(DiffLines[I], 1, 11) = 'diff --git ') or (Copy(DiffLines[I], 1, 6) = 'index ') or (DiffLines[I] = '') then begin Inc(I); Continue; end;
      if Copy(DiffLines[I], 1, 4) <> '--- ' then
      begin
        { A complete diff may be followed by a short explanatory response. }
        if Edits.Count > 0 then Break;
        if (Pos('*** Begin Patch', DiffLines.Text) > 0) or
           (Pos('*** Update File:', DiffLines.Text) > 0) then
          raise EPatchError.Create('format', 'Unsupported patch format; send a unified diff with --- and +++ file headers', '', 0)
        else if Copy(DiffLines[I], 1, 3) = '```' then
          raise EPatchError.Create('format', 'Remove surrounding Markdown fences and send a unified diff with --- and +++ file headers', '', 0)
        else
          raise EPatchError.Create('format', 'Expected unified diff file header (--- path / +++ path); check the patch format and remove any surrounding text', '', 0);
      end;
      OldPath := PatchPath(DiffLines[I]); Inc(I);
      if (I >= DiffLines.Count) or (Copy(DiffLines[I], 1, 4) <> '+++ ') then
        raise EPatchError.Create('format', 'Missing +++ header after unified diff file header', '', 0);
      NewPath := PatchPath(DiffLines[I]); Inc(I);
      if (OldPath = '/dev/null') and (NewPath = '/dev/null') then
        raise EPatchError.Create('format', 'Invalid patch paths', '', 0);
      if (OldPath <> '/dev/null') and (NewPath <> '/dev/null') and (OldPath <> NewPath) then
        raise EPatchError.Create('format', 'Renaming is unsupported; use delete and create', '', 0);
      Stg := TStagedEdit.Create; Edits.Add(Stg);
      Stg.CreateFile := OldPath = '/dev/null'; Stg.Remove := NewPath = '/dev/null';
      if Stg.Remove then Stg.FilePath := OldPath else Stg.FilePath := NewPath;
      for J := 0 to Edits.Count-2 do
        if TStagedEdit(Edits[J]).FilePath = Stg.FilePath then
          raise EPatchError.Create('patch_apply', 'Duplicate patch target', Stg.FilePath, 0);
      if Stg.CreateFile then
      begin
        if FileExists(Stg.FilePath) or DirectoryExists(Stg.FilePath) then
          raise EPatchError.Create('patch_apply', 'Creation target already exists', Stg.FilePath, 0);
      end
      else Stg.Original := ReadTextBytes(Stg.FilePath);
      Lines.Clear; Endings.Clear; Output.Clear; OutEndings.Clear;
      Text := Stg.Original; BOM := '';
      if Copy(Text, 1, 3) = #239#187#191 then begin BOM := Copy(Text, 1, 3); Delete(Text, 1, 3); end;
      SplitLines(Text, Lines, Endings); Cursor := 0; HunkCount := 0;
      { Unified diffs use LF for new files; existing files below retain their
        first observed line ending. }
      EOL := #10;
      for J := 0 to Endings.Count-1 do if Endings[J] <> '' then begin EOL := Endings[J]; Break; end;
      RelPath := ExtractFileName(Stg.FilePath);
      while (I < DiffLines.Count) and (Copy(DiffLines[I], 1, 2) = '@@') do
      begin
        if ToolCancelled then raise Exception.Create('Tool cancelled');
        if not R.Exec(DiffLines[I]) then raise EPatchError.Create('invalid_hunk', 'Invalid hunk header', Stg.FilePath, 0);
        OldStart := StrToInt(R.Match[1]); NewStart := StrToInt(R.Match[4]);
        HeaderOldCount := 1; HeaderNewCount := 1;
        if R.Match[3] <> '' then HeaderOldCount := StrToInt(R.Match[3]);
        if R.Match[6] <> '' then HeaderNewCount := StrToInt(R.Match[6]);
        if HeaderOldCount > 0 then Dec(OldStart);
        if HeaderNewCount > 0 then Dec(NewStart);
        if (OldStart < Cursor) or (OldStart > Lines.Count) then
          raise EPatchError.Create('invalid_hunk', 'Overlapping or invalid hunk', Stg.FilePath, OldStart + 1);
        AppendOriginal(OldStart);
        if NewStart <> Output.Count then
          PatchWarnings.Add('hunk at ' + RelPath + ': ignored +start ' + IntToStr(NewStart + 1) +
            ' (expected ' + IntToStr(Output.Count + 1) + ')');
        Inc(I); Inc(HunkCount); SeenOld := 0; SeenNew := 0; MarkerIndex := -1;
        MarkerOld := False; BrokeAtBoundary := False;
        while I < DiffLines.Count do
        begin
          Text := DiffLines[I];
          if IsHunkBodyBoundary(Text) then
          begin
            BrokeAtBoundary := True;
            Break;
          end;
          if Text = '\ No newline at end of file' then
          begin
            if MarkerOld and ((Cursor = 0) or (Endings[Cursor-1] <> '')) then
              raise EPatchError.Create('invalid_hunk', 'Old newline marker mismatch', Stg.FilePath, Cursor);
            if MarkerIndex >= 0 then OutEndings[MarkerIndex] := '';
            MarkerIndex := -1; MarkerOld := False; Inc(I); Continue;
          end;
          if (SeenOld = HeaderOldCount) and (SeenNew = HeaderNewCount) then Break;
          if Text = '' then
          begin
            ApplyHunkLine('');
            if (SeenOld > HeaderOldCount) or (SeenNew > HeaderNewCount) then
              raise EPatchError.Create('hunk_count_mismatch',
                'Hunk count mismatch; @@ old/new counts must match space, -, and + lines', Stg.FilePath, 0);
            Inc(I);
            Continue;
          end;
          case Text[1] of
            ' ': begin ApplyHunkLine(Text); end;
            '-': begin
              if SeenOld >= HeaderOldCount then
                raise EPatchError.Create('hunk_count_mismatch',
                  'Hunk count mismatch; @@ old/new counts must match space, -, and + lines', Stg.FilePath, 0);
              CheckOld(Copy(Text, 2, MaxInt)); Inc(Cursor); Inc(SeenOld);
              MarkerIndex := -1; MarkerOld := True;
            end;
            '+': begin
              if SeenNew >= HeaderNewCount then
                raise EPatchError.Create('hunk_count_mismatch',
                  'Hunk count mismatch; @@ old/new counts must match space, -, and + lines', Stg.FilePath, 0);
              Output.Add(Copy(Text, 2, MaxInt)); OutEndings.Add(EOL); Inc(SeenNew);
              MarkerIndex := Output.Count - 1; MarkerOld := False;
            end;
            else
              raise EPatchError.Create('invalid_hunk', 'Invalid hunk line', Stg.FilePath, 0,
                'Each hunk line must start with space, -, or +.');
          end;
          if (SeenOld > HeaderOldCount) or (SeenNew > HeaderNewCount) then
            raise EPatchError.Create('hunk_count_mismatch',
              'Hunk count mismatch; @@ old/new counts must match space, -, and + lines', Stg.FilePath, 0);
          Inc(I);
        end;
        if (SeenOld <> HeaderOldCount) or (SeenNew <> HeaderNewCount) then
        begin
          if BrokeAtBoundary then
          begin
            if (SeenOld = 0) and (SeenNew = 0) then
              raise EPatchError.Create('incomplete_hunk',
                'Incomplete hunk; expected ' + IntToStr(HeaderOldCount) + ' old and ' +
                IntToStr(HeaderNewCount) + ' new lines, got none', Stg.FilePath, 0,
                'Add - and + lines or use @@ -N,1 +N,1 @@ for one-line changes.');
            PatchWarnings.Add('hunk at ' + RelPath + ': adjusted @@ counts from ' +
              IntToStr(HeaderOldCount) + '/' + IntToStr(HeaderNewCount) + ' to ' +
              IntToStr(SeenOld) + '/' + IntToStr(SeenNew));
          end
          else
            raise EPatchError.Create('incomplete_hunk',
              'Incomplete hunk; expected ' + IntToStr(HeaderOldCount) + '/' +
              IntToStr(HeaderNewCount) + ' old/new lines, got ' + IntToStr(SeenOld) + '/' +
              IntToStr(SeenNew), Stg.FilePath, 0,
              'Recount space, -, and + lines in the hunk or start the next hunk with @@.');
        end;
      end;
      if HunkCount = 0 then raise EPatchError.Create('empty_patch', 'Patch file has no hunks', Stg.FilePath, 0);
      AppendOriginal(Lines.Count);
      ContentStream := TStringStream.Create(BOM);
      try
        for J := 0 to Output.Count - 1 do
        begin
          if (J < Output.Count - 1) and (OutEndings[J] = '') then
            raise EPatchError.Create('invalid_hunk', 'No-newline marker before final line', Stg.FilePath, 0);
          ContentStream.WriteString(Output[J] + OutEndings[J]);
        end;
        Stg.Content := ContentStream.DataString;
      finally
        ContentStream.Free;
      end;
      if Stg.Remove and (Output.Count <> 0) then
        raise EPatchError.Create('patch_apply', 'Deletion patch must remove all lines', Stg.FilePath, 0);
    end;
    if Edits.Count = 0 then raise EPatchError.Create('empty_patch', 'Patch is empty', '', 0);
      Result := Commit(Edits, PatchWarnings);
    except
      on Ex: EPatchError do Result := PatchErrorJSON(Ex);
      on Ex: Exception do
      begin
        PatchEx := EPatchError.Create(PatchErrorKindForMessage(Ex.Message), Ex.Message, '', 0);
        try Result := PatchErrorJSON(PatchEx); finally PatchEx.Free; end;
      end;
    end;
  finally
    for J := 0 to Edits.Count-1 do TObject(Edits[J]).Free;
    DiffLines.Free; Edits.Free; Lines.Free; Endings.Free; Output.Free; OutEndings.Free;
    PatchWarnings.Free; R.Free;
  end;
end;

function ExecuteEditFileJson(A: TJSONObject): string;
var
  Stg: TStagedEdit;
  Edits: TList;
  Old, NewText: string;
  P: Integer;
begin
  Stg := TStagedEdit.Create;
  Edits := TList.Create;
  Edits.Add(Stg);
  try
    Stg.FilePath := ResolveProjectPath(A.Get('path', ''), paWrite);
    Stg.Original := ReadTextBytes(Stg.FilePath);
    Old := A.Get('old_text', '');
    NewText := A.Get('new_text', '');
    if Old = '' then raise Exception.Create('old_text must not be empty');
    P := Pos(Old, Stg.Original);
    if (P = 0) or (Pos(Old, Copy(Stg.Original, P + 1, MaxInt)) > 0) then
      raise Exception.Create('old_text must match exactly once');
    Stg.Content := Copy(Stg.Original, 1, P - 1) + NewText + Copy(Stg.Original, P + Length(Old), MaxInt);
    Result := Commit(Edits);
  finally
    Stg.Free;
    Edits.Free;
  end;
end;

constructor TToolApplyPatch.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  AllowedModes := [wmAgent];
  MutatesFiles := True;
  Advertised := True;
end;

function TToolApplyPatch.GetDefinition: TToolDef;
begin
  Result.Name := 'apply_patch';
  Result.Description := 'Apply a unified diff after validating all hunks. Supports file creation, modification and deletion.';
  SetLength(Result.Params, 1);
  Result.Params[0].Name := 'patch';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Raw unified diff: --- a/path, +++ b/path, @@ -N,1 +N,1 @@, then one -old and +new line per change.';
  Result.Params[0].Required := True;
end;

function TToolApplyPatch.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Json: string;
begin
  try
    Json := ExecuteApplyPatchJson(Args);
  except
    on E: Exception do
      Json := ToolError(E.Message);
  end;
  Result := ToolResultFromJson(Json);
end;

end.
