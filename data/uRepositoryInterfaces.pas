unit uRepositoryInterfaces;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils;

type
  IAppSettingsRepository = interface
    ['{A4B8C2E1-7F3D-4A91-9E2B-1C0D5E6F7081}']
    function TryGet(const AKey: string; out AValue: string): Boolean;
    procedure SetString(const AKey, AValue: string);
  end;

  TRegistryWorkspaceRow = record
    Id: string;
    DisplayName: string;
    FolderPath: string;
    LastSessionId: string;
    SortOrder: Integer;
  end;
  TRegistryWorkspaceRows = array of TRegistryWorkspaceRow;

  IWorkspaceRegistryRepository = interface
    ['{B1C2D3E4-F5A6-4789-ABCD-EF0123456789}']
    procedure LoadAll(out ARows: TRegistryWorkspaceRows; out AActiveWorkspaceId: string);
    procedure SaveAll(const ARows: TRegistryWorkspaceRows; const AActiveWorkspaceId: string);
  end;

  TLlmProviderRow = record
    ProviderOrd: Integer;
    ApiKey: string;
    BaseUrl: string;
  end;
  TLlmProviderRows = array of TLlmProviderRow;

  TSavedModelRow = record
    ProviderOrd: Integer;
    Seq: Integer;
    ModelId: string;
    DisplayName: string;
  end;
  TSavedModelRows = array of TSavedModelRow;

  ILlmSettingsRepository = interface
    ['{C2D3E4F5-A6B7-4890-BCDE-F12345678901}']
    procedure LoadProviders(out ARows: TLlmProviderRows);
    procedure SaveProviders(const ARows: TLlmProviderRows);
    procedure LoadModels(out ARows: TSavedModelRows);
    procedure SaveModels(const ARows: TSavedModelRows);
  end;

  TPanelLayoutRow = record
    PanelOrd: Integer;
    Visible: Boolean;
    Floating: Boolean;
    LeftPos: Integer;
    TopPos: Integer;
    Width: Integer;
    Height: Integer;
    DockedHeight: Integer;
  end;
  TPanelLayoutRows = array of TPanelLayoutRow;

  IPanelLayoutRepository = interface
    ['{D3E4F5A6-B7C8-4901-CDEF-123456789012}']
    procedure LoadAll(out ARows: TPanelLayoutRows);
    procedure SaveAll(const ARows: TPanelLayoutRows);
  end;

  TWebSearchConnectionRow = record
    Id: string;
    Name: string;
    Provider: string;
    Enabled: Boolean;
    Priority: Integer;
    TimeoutMs: Integer;
    InstanceUrl: string;
    TavilySearchDepth: string;
    CustomHeaderName: string;
    CustomHeaderValue: string;
    ApiKey: string;
  end;
  TWebSearchConnectionRows = array of TWebSearchConnectionRow;

  IWebSearchRepository = interface
    ['{E4F5A6B7-C8D9-4012-DEF0-234567890123}']
    procedure LoadConnections(out ARows: TWebSearchConnectionRows);
    procedure SaveConnections(const ARows: TWebSearchConnectionRows);
  end;

  IBrowserReadRepository = interface
    ['{F5A6B7C8-D9E0-4123-EF01-345678901234}']
    function LoadExecutablePath: string;
    procedure SaveExecutablePath(const APath: string);
    function LoadMaxConcurrent: Integer;
    procedure SaveMaxConcurrent(AValue: Integer);
    function LoadMaxSessions: Integer;
    procedure SaveMaxSessions(AValue: Integer);
    function LoadIdleTimeoutMs: Integer;
    procedure SaveIdleTimeoutMs(AValue: Integer);
  end;

implementation

end.
