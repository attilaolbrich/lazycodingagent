unit uToolSearchCode;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, RegExpr, uAppTypes, uAgentTypes, uAgentToolBase;

type
  TToolSearchCode = class(TAgentTool)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

implementation

uses
  uAgentToolPaths, StrUtils;

const
  SearchFileMaxBytes = 16 * 1024 * 1024;
  SearchLineMaxBytes = 1024 * 1024;

constructor TToolSearchCode.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  FAliases := 'grep';
  AllowedModes := [wmAsk, wmPlan, wmAgent];
  MutatesFiles := False;
end;

function TToolSearchCode.GetDefinition: TToolDef;
begin
  Result.Name := 'search_code';
  Result.Description := 'Search project text natively; supports literal or regular-expression searches; capped at 500 matches.';
  SetLength(Result.Params, 6);
  Result.Params[0].Name := 'query';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'Search query.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'path';
  Result.Params[1].ParamType := 'string';
  Result.Params[1].Description := 'File or directory to search.';
  Result.Params[1].Required := False;
  Result.Params[2].Name := 'glob';
  Result.Params[2].ParamType := 'string';
  Result.Params[2].Description := 'Optional glob filter on relative paths.';
  Result.Params[2].Required := False;
  Result.Params[3].Name := 'regex';
  Result.Params[3].ParamType := 'boolean';
  Result.Params[3].Description := 'Treat query as RegExpr.';
  Result.Params[3].Required := False;
  Result.Params[4].Name := 'case_sensitive';
  Result.Params[4].ParamType := 'boolean';
  Result.Params[4].Description := 'Case sensitive literal search.';
  Result.Params[4].Required := False;
  Result.Params[5].Name := 'include_hidden';
  Result.Params[5].ParamType := 'boolean';
  Result.Params[5].Description := 'Include hidden files when searching directories.';
  Result.Params[5].Required := False;
end;

function TToolSearchCode.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Files: TStringList;
  O, Match: TJSONObject;
  Matches: TJSONArray;
  I, LineNo, StartAt, MatchPos, K, LineLength, LineCapacity, N, B: Integer;
  Root, SearchRoot, Query, Path, FullPath, LowerQuery, LineText, LowerLine: string;
  Stream: TFileStream;
  RawLine: RawByteString;
  Buffer: array[0..65535] of Byte;
  Regex: TRegExpr;
  Truncated, IsDirectory, BinaryFile: Boolean;
  Json: string;

  procedure AddMatch(const APath, AText: string; ALine, AColumn: Integer);
  begin
    if Matches.Count >= 500 then begin Truncated := True; Exit; end;
    Match := TJSONObject.Create(['path', APath, 'line', ALine,
      'column', AColumn, 'text', TrimRight(AText)]);
    Matches.Add(Match);
  end;

  procedure ScanLine(const ALine: RawByteString);
  begin
    Inc(LineNo);
    LineText := SafeToolText(ALine);
    if not Args.Get('regex', False) and not Args.Get('case_sensitive', True) then
      LowerLine := AnsiLowerCase(LineText);
    if Args.Get('regex', False) then
    begin
      if Regex.Exec(LineText) then
      begin
        repeat
          if ToolCancelled then raise Exception.Create('Tool cancelled');
          MatchPos := Regex.MatchPos[0];
          AddMatch(Path, LineText, LineNo, MatchPos);
          if Truncated then Exit;
        until not Regex.ExecNext;
      end;
    end
    else
    begin
      StartAt := 1;
      while StartAt <= Length(LineText) do
      begin
        if ToolCancelled then raise Exception.Create('Tool cancelled');
        if Args.Get('case_sensitive', True) then
          K := PosEx(Query, LineText, StartAt)
        else
          K := PosEx(LowerQuery, LowerLine, StartAt);
        if K = 0 then Break;
        MatchPos := K;
        AddMatch(Path, LineText, LineNo, MatchPos);
        if Truncated then Exit;
        StartAt := MatchPos + Length(Query);
      end;
    end;
  end;

begin
  Json := '{}';
  Root := CanonicalWorkspaceRoot;
  SearchRoot := ResolveProjectPath(Args.Get('path', '.'), paRead);
  Query := Args.Get('query', '');
  if Query = '' then
  begin
    Result := ToolResultFromJson(ToolError('query must not be empty'));
    Exit;
  end;

  Files := TStringList.Create;
  Files.CaseSensitive := True;
  Matches := TJSONArray.Create;
  O := TJSONObject.Create;
  O.Add('matches', Matches);
  Regex := nil;
  Truncated := False;
  try
    try
      if Args.Get('regex', False) then
      begin
        Regex := TRegExpr.Create;
        Regex.Expression := Query;
        Regex.ModifierI := not Args.Get('case_sensitive', True);
      end
      else if not Args.Get('case_sensitive', True) then
        LowerQuery := AnsiLowerCase(Query);

      IsDirectory := DirectoryExists(SearchRoot);
      if IsDirectory then
        CollectFiles(SearchRoot, '', Args.Get('include_hidden', False), Files)
      else if FileExists(SearchRoot) then
        Files.Add(ExtractFileName(SearchRoot))
      else
        raise Exception.Create('Search path does not exist: ' + SearchRoot);
      Files.Sort;

      for I := 0 to Files.Count - 1 do
      begin
        if ToolCancelled then raise Exception.Create('Tool cancelled');
        if IsDirectory then
          FullPath := IncludeTrailingPathDelimiter(SearchRoot) + Files[I]
        else
          FullPath := SearchRoot;
        Path := StringReplace(ExtractRelativePath(IncludeTrailingPathDelimiter(Root), FullPath),
          DirectorySeparator, '/', [rfReplaceAll]);
        if (Args.Get('glob', '') <> '') and not GlobMatches(Args.Get('glob', ''), Path) then Continue;

        Stream := TFileStream.Create(FullPath, fmOpenRead or fmShareDenyWrite);
        try
          if Stream.Size > SearchFileMaxBytes then Continue;
          BinaryFile := False;
          LineNo := 0;
          RawLine := '';
          LineLength := 0;
          LineCapacity := 0;
          while Stream.Position < Stream.Size do
          begin
            if ToolCancelled then raise Exception.Create('Tool cancelled');
            N := Stream.Read(Buffer, SizeOf(Buffer));
            for B := 0 to N - 1 do
            begin
              if Buffer[B] = 0 then begin BinaryFile := True; Break; end;
              if Buffer[B] = 10 then
              begin
                if (LineLength > 0) and (RawLine[LineLength] = #13) then Dec(LineLength);
                SetLength(RawLine, LineLength);
                ScanLine(RawLine);
                SetLength(RawLine, LineCapacity);
                LineLength := 0;
                if Truncated then Break;
              end
              else
              begin
                if LineLength >= SearchLineMaxBytes then
                begin
                  BinaryFile := True;
                  Break;
                end;
                if LineLength >= LineCapacity then
                begin
                  if LineCapacity = 0 then LineCapacity := 256 else LineCapacity := LineCapacity * 2;
                  SetLength(RawLine, LineCapacity);
                end;
                Inc(LineLength);
                RawLine[LineLength] := AnsiChar(Buffer[B]);
              end;
            end;
            if BinaryFile or Truncated then Break;
          end;
          if BinaryFile then Continue;
          if not Truncated and (LineLength > 0) then
          begin
            SetLength(RawLine, LineLength);
            ScanLine(RawLine);
          end;
        finally
          Stream.Free;
        end;
        if Truncated then Break;
      end;
      O.Add('total_matches', Matches.Count);
      O.Add('truncated', Truncated);
      Json := O.AsJSON;
    except
      on E: Exception do
        Json := ToolError(E.Message);
    end;
  finally
    Files.Free;
    Regex.Free;
    O.Free;
  end;
  Result := ToolResultFromJson(Json);
end;

end.
