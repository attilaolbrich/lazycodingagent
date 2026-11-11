unit uExecutionDetailText;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

procedure AppendDetailSectionHeader(SB: TStringBuilder; const ATitle: string);
procedure AppendDetailJsonBlock(SB: TStringBuilder; const AJson: string);
procedure AppendDetailProseBlock(SB: TStringBuilder; const AText: string);
procedure AppendDetailToolLine(SB: TStringBuilder; const AToolName: string; AFailed: Boolean);

implementation

uses
  uAgentExecutionLog;

procedure AppendDetailSectionHeader(SB: TStringBuilder; const ATitle: string);
begin
  SB.AppendLine('### ' + ATitle);
  SB.AppendLine;
end;

procedure AppendDetailJsonBlock(SB: TStringBuilder; const AJson: string);
var
  Pretty: string;
begin
  Pretty := Trim(PrettyJsonString(AJson));
  if Pretty = '' then
    SB.AppendLine('*(empty)*')
  else begin
    SB.AppendLine('```json');
    SB.AppendLine(Pretty);
    SB.AppendLine('```');
  end;
  SB.AppendLine;
end;

procedure AppendDetailProseBlock(SB: TStringBuilder; const AText: string);
var
  T: string;
begin
  T := Trim(AText);
  if T = '' then
    SB.AppendLine('*(empty)*')
  else begin
    SB.AppendLine('```');
    SB.AppendLine(T);
    SB.AppendLine('```');
  end;
  SB.AppendLine;
end;

procedure AppendDetailToolLine(SB: TStringBuilder; const AToolName: string; AFailed: Boolean);
begin
  SB.Append('**');
  SB.Append(AToolName);
  SB.Append('**');
  if AFailed then
    SB.Append(' *(failed)*');
  SB.AppendLine;
  SB.AppendLine;
end;

end.
