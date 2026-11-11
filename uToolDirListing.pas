unit uToolDirListing;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAgentToolBase;

function DirectoryListingJson(A: TJSONObject; Recursive: Boolean): string;

implementation

uses
  uAgentToolPaths;

function DirectoryListingJson(A: TJSONObject; Recursive: Boolean): string;
var
  Root, Pattern, Full, Rel: string;
  Hidden, Truncated: Boolean;
  Files: TStringList;
  Entries: TJSONArray;
  O, Entry: TJSONObject;
  R: TSearchRec;
  I: Integer;
begin
  Root := ResolveProjectPath(A.Get('path', '.'), paRead);
  if not DirectoryExists(Root) then raise Exception.Create('Directory does not exist: ' + Root);
  Hidden := A.Get('include_hidden', False);
  Pattern := A.Get('pattern', '**/*');
  if Recursive and (Pattern = '') then raise Exception.Create('pattern must not be empty');
  Files := TStringList.Create;
  Entries := TJSONArray.Create;
  O := TJSONObject.Create;
  O.Add('entries', Entries);
  Truncated := False;
  try
    if Recursive then
      CollectFiles(Root, '', Hidden, Files)
    else if FindFirst(IncludeTrailingPathDelimiter(Root) + '*', faAnyFile, R) = 0 then
    try
      repeat
        if (R.Name = '.') or (R.Name = '..') then Continue;
        if not Hidden and (R.Name[1] = '.') then Continue;
        Files.Add(R.Name);
      until FindNext(R) <> 0;
    finally
      FindClose(R);
    end;
    Files.Sort;
    for I := 0 to Files.Count - 1 do
    begin
      if ToolCancelled then raise Exception.Create('Tool cancelled');
      Rel := Files[I];
      Full := IncludeTrailingPathDelimiter(Root) + Rel;
      if Recursive then
        Rel := StringReplace(ExtractRelativePath(IncludeTrailingPathDelimiter(CanonicalWorkspaceRoot), Full),
          DirectorySeparator, '/', [rfReplaceAll]);
      if Recursive and not GlobMatches(Pattern, Rel) then Continue;
      if Entries.Count = 500 then begin Truncated := True; Break; end;
      Entry := TJSONObject.Create(['path', Rel]);
      if IsPathLink(Full) then
      begin
        Entry.Add('type', 'symlink');
        Entry.Add('size', 0);
      end
      else if DirectoryExists(ResolveProjectPath(Full, paRead)) then
      begin
        Entry.Add('type', 'directory');
        Entry.Add('size', 0);
      end
      else
      begin
        Entry.Add('type', 'file');
        if FindFirst(Full, faAnyFile, R) = 0 then
        try
          Entry.Add('size', R.Size);
        finally
          FindClose(R);
        end;
      end;
      Entries.Add(Entry);
    end;
    O.Add('directory', Root);
    O.Add('total_entries', Entries.Count);
    O.Add('truncated', Truncated);
    Result := O.AsJSON;
  finally
    Files.Free;
    O.Free;
  end;
end;

end.
