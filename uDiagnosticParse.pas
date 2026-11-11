unit uDiagnosticParse;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, RegExpr;

procedure ParseCompilerOutput(const Text: string; Messages: TJSONArray);

implementation

function NormalizeSeverity(const S: string): string;
var
  L: string;
begin
  L := LowerCase(Trim(S));
  if (L = 'fatal') or (L = 'error') then Result := 'error'
  else if L = 'warning' then Result := 'warning'
  else if (L = 'note') or (L = 'hint') or (L = 'info') then Result := 'info'
  else Result := L;
end;

procedure ParseCompilerOutput(const Text: string; Messages: TJSONArray);
var
  Lines: TStringList;
  I: Integer;
  Line, Severity: string;
  FpcRe, GccRe, MsvcRe, General: TRegExpr;
  D: TJSONObject;
begin
  Lines := TStringList.Create;
  FpcRe := TRegExpr.Create;
  GccRe := TRegExpr.Create;
  MsvcRe := TRegExpr.Create;
  General := TRegExpr.Create;
  try
    Lines.Text := Text;
    FpcRe.Expression := '^([^(]+)\(([0-9]+),([0-9]+)\)\s*:?\s*(Fatal|Error|Warning|Note|Hint):\s*(.*)$';
    GccRe.Expression := '^(.+?):([0-9]+):([0-9]+):\s*(fatal error|error|warning|note):\s*(.*)$';
    MsvcRe.Expression := '^([^(]+)\(([0-9]+),([0-9]+)\)\s*:\s*(fatal error|error|warning)\s+(.*)$';
    General.Expression := '^(Fatal|Error|Warning|Note|Hint):\s*(.*)$';
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if Line = '' then Continue;
      if FpcRe.Exec(Line) then
      begin
        Severity := NormalizeSeverity(FpcRe.Match[4]);
        D := TJSONObject.Create(['path', FpcRe.Match[1], 'line', StrToInt(FpcRe.Match[2]),
          'column', StrToInt(FpcRe.Match[3]), 'severity', Severity, 'message', FpcRe.Match[5]]);
        Messages.Add(D);
      end
      else if GccRe.Exec(Line) then
      begin
        Severity := NormalizeSeverity(GccRe.Match[4]);
        D := TJSONObject.Create(['path', GccRe.Match[1], 'line', StrToInt(GccRe.Match[2]),
          'column', StrToInt(GccRe.Match[3]), 'severity', Severity, 'message', GccRe.Match[5]]);
        Messages.Add(D);
      end
      else if MsvcRe.Exec(Line) then
      begin
        Severity := NormalizeSeverity(MsvcRe.Match[4]);
        D := TJSONObject.Create(['path', MsvcRe.Match[1], 'line', StrToInt(MsvcRe.Match[2]),
          'column', StrToInt(MsvcRe.Match[3]), 'severity', Severity, 'message', Trim(MsvcRe.Match[5])]);
        Messages.Add(D);
      end
      else if General.Exec(Line) then
      begin
        Severity := NormalizeSeverity(General.Match[1]);
        Messages.Add(TJSONObject.Create(['severity', Severity, 'message', General.Match[2]]));
      end;
    end;
  finally
    Lines.Free;
    FpcRe.Free;
    GccRe.Free;
    MsvcRe.Free;
    General.Free;
  end;
end;

end.
