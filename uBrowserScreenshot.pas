unit uBrowserScreenshot;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, uBrowserManager, uBrowserReadTypes, uBrowserElementLocator;

function BrowserCaptureScreenshot(S: TBrowserManagedSession; const WorkspaceRoot: string;
  FullPage: Boolean; const Selector: string; const Format: string; Quality: Integer;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out RelPath, AbsPath: string; out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;

implementation

uses
  uToolArtifactStore, Math, Base64;

function DecodeBase64ToBytes(const B64: string): TBytes;
var
  Raw: RawByteString;
  I: Integer;
begin
  Raw := DecodeStringBase64(AnsiString(B64));
  SetLength(Result, Length(Raw));
  for I := 1 to Length(Raw) do
    Result[I - 1] := Ord(Raw[I]);
end;

function BrowserCaptureScreenshot(S: TBrowserManagedSession; const WorkspaceRoot: string;
  FullPage: Boolean; const Selector: string; const Format: string; Quality: Integer;
  TimeoutMs: Integer; CancelCheck: TBrowserReadCancelCheck;
  out RelPath, AbsPath: string; out ErrKind: TBrowserReadErrorKind; out ErrMsg: string): Boolean;
var
  Params, ResultObj, Clip: TJSONObject;
  NodeId: Integer;
  X, Y: Double;
  B64, Ext, Fmt: string;
  Data: TBytes;
begin
  RelPath := '';
  AbsPath := '';
  S.Touch;
  Fmt := LowerCase(Format);
  if Fmt = '' then Fmt := 'png';
  if Fmt = 'jpeg' then Ext := '.jpg' else Ext := '.png';

  Params := TJSONObject.Create;
  try
    Params.Add('format', Fmt);
    if Fmt = 'jpeg' then
      Params.Add('quality', Quality);
    if FullPage then
      Params.Add('captureBeyondViewport', True);
    if Trim(Selector) <> '' then
    begin
      if not BrowserResolveElement(S, Selector, '', TimeoutMs, CancelCheck, NodeId, ErrKind, ErrMsg) then
        Exit(False);
      if not BrowserElementCenter(S.Connection, NodeId, TimeoutMs, CancelCheck, X, Y) then ;
      Clip := TJSONObject.Create;
      Clip.Add('x', 0);
      Clip.Add('y', 0);
      Clip.Add('width', 800);
      Clip.Add('height', 600);
      Clip.Add('scale', 1);
      Params.Add('clip', Clip);
    end;
    if not S.Connection.SendCommand('Page.captureScreenshot', Params, TimeoutMs, CancelCheck,
      ResultObj) then
    begin
      ErrKind := brekCdpConnectionFailed;
      ErrMsg := 'Page.captureScreenshot failed';
      Exit(False);
    end;
    try
      B64 := ResultObj.Get('data', '');
    finally
      ResultObj.Free;
    end;
  finally
    Params.Free;
  end;

  if B64 = '' then
  begin
    ErrKind := brekInternal;
    ErrMsg := 'Empty screenshot data';
    Exit(False);
  end;
  Data := DecodeBase64ToBytes(B64);
  AbsPath := CreateToolArtifactPath(WorkspaceRoot, S.Id, Ext);
  if not SaveToolArtifactBytes(AbsPath, Data) then
  begin
    ErrKind := brekInternal;
    ErrMsg := 'Could not save screenshot artifact';
    Exit(False);
  end;
  RelPath := TOOL_ARTIFACTS_REL_DIR + ExtractFileName(AbsPath);
  Result := True;
end;

end.
