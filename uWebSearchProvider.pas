unit uWebSearchProvider;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uWebSearchTypes, uWebSearchHttp;

type
  IWebSearchProvider = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetProviderType: string;
    function Search(const AConn: TWebSearchConnection; const ARequest: TWebSearchRequest;
      const AApiKey: string; AAllowPrivate: Boolean; ATransport: IWebSearchTransport;
      CancelCheck: TWebSearchCancelCheck; out AResponse: TWebSearchResponse): Boolean;
    function TestConnection(const AConn: TWebSearchConnection; const AApiKey: string;
      AAllowPrivate: Boolean; ATransport: IWebSearchTransport;
      CancelCheck: TWebSearchCancelCheck): TConnectionTestResult;
  end;

  TWebSearchProviderClass = class of TObject;

procedure RegisterWebSearchProviders;
function CreateWebSearchProvider(AKind: TWebSearchProviderKind): IWebSearchProvider;

implementation

uses
  uWebSearchProviderBrave, uWebSearchProviderSearxng, uWebSearchProviderTavily;

function CreateWebSearchProvider(AKind: TWebSearchProviderKind): IWebSearchProvider;
begin
  case AKind of
    wspkBrave: Result := TBraveWebSearchProvider.Create;
    wspkSearxng: Result := TSearxngWebSearchProvider.Create;
    wspkTavily: Result := TTavilyWebSearchProvider.Create;
  else
    Result := nil;
  end;
end;

procedure RegisterWebSearchProviders;
begin
  { Providers are created on demand via CreateWebSearchProvider. }
end;

end.
