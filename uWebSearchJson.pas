unit uWebSearchJson;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uWebSearchTypes;

function WebSearchToolResultToJson(const AQuery: string; const AResponse: TWebSearchResponse): string;
function WebSearchErrorJson(const AQuery, AErrorCode, AErrorMessage: string): string;

implementation

uses
  fpjson;

function WebSearchToolResultToJson(const AQuery: string; const AResponse: TWebSearchResponse): string;
var
  Root, Item: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  Pub: TJSONData;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('success', AResponse.Success);
    Root.Add('query', AQuery);
    if not AResponse.Success then begin
      if AResponse.ErrorCode <> '' then
        Root.Add('error_code', AResponse.ErrorCode);
      if AResponse.ErrorMessage <> '' then
        Root.Add('error', AResponse.ErrorMessage);
    end;
    Arr := TJSONArray.Create;
    for I := 0 to High(AResponse.Results) do begin
      Item := TJSONObject.Create;
      Item.Add('title', AResponse.Results[I].Title);
      Item.Add('url', AResponse.Results[I].URL);
      Item.Add('snippet', AResponse.Results[I].Snippet);
      if Trim(AResponse.Results[I].PublishedAt) = '' then
        Item.Add('published_at', TJSONNull.Create)
      else
        Item.Add('published_at', AResponse.Results[I].PublishedAt);
      Arr.Add(Item);
    end;
    Root.Add('results', Arr);
    Root.Add('result_count', Length(AResponse.Results));
    Result := Root.AsJSON;
  finally
    Root.Free;
  end;
end;

function WebSearchErrorJson(const AQuery, AErrorCode, AErrorMessage: string): string;
var
  R: TWebSearchResponse;
begin
  InitWebSearchResponse(R);
  R.Success := False;
  R.ErrorCode := AErrorCode;
  R.ErrorMessage := AErrorMessage;
  Result := WebSearchToolResultToJson(AQuery, R);
end;

end.
