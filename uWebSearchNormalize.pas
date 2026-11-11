unit uWebSearchNormalize;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uWebSearchTypes;

procedure DedupeWebSearchResults(var AResults: TWebSearchResultArray);
function FilterValidResultUrls(const AResults: TWebSearchResultArray): TWebSearchResultArray;

implementation

uses
  uWebSearchUrl;

procedure DedupeWebSearchResults(var AResults: TWebSearchResultArray);
var
  I, J, N: Integer;
  Seen: array of string;
  Key: string;
  Found: Boolean;
begin
  SetLength(Seen, 0);
  N := 0;
  for I := 0 to High(AResults) do begin
    if not ValidateSearchResultUrl(AResults[I].URL) then Continue;
    Key := CanonicalResultUrl(AResults[I].URL);
    Found := False;
    for J := 0 to High(Seen) do
      if Seen[J] = Key then begin Found := True; Break; end;
    if Found then Continue;
    SetLength(Seen, Length(Seen) + 1);
    Seen[High(Seen)] := Key;
    if N <> I then
      AResults[N] := AResults[I];
    Inc(N);
  end;
  SetLength(AResults, N);
end;

function FilterValidResultUrls(const AResults: TWebSearchResultArray): TWebSearchResultArray;
var
  I, N: Integer;
begin
  SetLength(Result, Length(AResults));
  N := 0;
  for I := 0 to High(AResults) do
    if ValidateSearchResultUrl(AResults[I].URL) then begin
      Result[N] := AResults[I];
      Inc(N);
    end;
  SetLength(Result, N);
end;

end.
