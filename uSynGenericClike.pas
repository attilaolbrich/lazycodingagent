unit uSynGenericClike;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SynHighlighterAny;

function CreateGenericClikeHighlighter(AOwner: TComponent): TSynAnySyn;
procedure LoadGenericClikeKeywords(AHighlighter: TSynAnySyn);

implementation

const
  GENERIC_CLIKE_KEYWORDS =
    'if else elif elsif elseif for while do switch case default break continue return ' +
    'goto function func procedure proc class struct enum union namespace using import ' +
    'public private protected internal static virtual override abstract final extern ' +
    'const constexpr var let volatile register inline export typedef typename template ' +
    'try catch throw finally raise new delete sizeof typeof alignas alignof ' +
    'true false nil null nullptr and or not xor mod in out ref async await yield ' +
    'interface implementation begin end unit program library package uses ' +
    'integer int long short float double void bool boolean char string object';

function CreateGenericClikeHighlighter(AOwner: TComponent): TSynAnySyn;
var
  HL: TSynAnySyn;
begin
  HL := TSynAnySyn.Create(AOwner);
  HL.Comments := [csCStyle];
  HL.DetectPreprocessor := True;
  LoadGenericClikeKeywords(HL);
  Result := HL;
end;

procedure LoadGenericClikeKeywords(AHighlighter: TSynAnySyn);
begin
  if AHighlighter = nil then Exit;
  AHighlighter.KeyWords.Text := StringReplace(GENERIC_CLIKE_KEYWORDS, ' ', LineEnding, [rfReplaceAll]);
end;

end.
