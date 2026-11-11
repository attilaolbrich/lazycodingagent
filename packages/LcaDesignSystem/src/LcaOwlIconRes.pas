unit LcaOwlIconRes;

{$mode objfpc}{$H+}

{ OWL_ICON is embedded in lazycodingagent.exe (owl_icon.bmp via lazres in lazycodingagent.lpr). }

interface

uses
  Classes, SysUtils, Graphics, LResources;

function LcaOwlIconResourceInstance: PtrUInt;
{ True in the Lazarus IDE or when AComponent (or an owner) is csDesigning.
  JIT .lfm loading calls Loaded before csDesigning is set on the control. }
function LcaShouldSkipOwlIconLoad(const AComponent: TComponent = nil): Boolean;
function TryLoadOwlIconInto(APicture: TPicture): Boolean;
procedure LoadOwlIconInto(APicture: TPicture);

implementation

uses
  Forms, LCLType,
  {$IFDEF WINDOWS}Windows{$ENDIF}
  {$IFDEF UNIX}dl{$ENDIF};

const
  OwlIconResourceName = 'OWL_ICON';

var
  LcaOwlIconResAnchor: Byte;

function ModuleFromAddress(const AAddr: Pointer): PtrUInt;
{$IFDEF WINDOWS}
var
  MemInfo: TMemoryBasicInformation;
{$ENDIF}
{$IFDEF UNIX}
var
  Info: dl_info;
{$ENDIF}
begin
{$IFDEF WINDOWS}
  FillChar(MemInfo, SizeOf(MemInfo), 0);
  if VirtualQuery(AAddr, MemInfo, SizeOf(MemInfo)) = SizeOf(MemInfo) then
    Result := PtrUInt(MemInfo.AllocationBase)
  else
    Result := 0;
{$ELSE}
  FillChar(Info, SizeOf(Info), 0);
  if dladdr(AAddr, @Info) <> 0 then
    Result := PtrUInt(Info.dli_fbase)
  else
    Result := 0;
{$ENDIF}
end;

function LcaOwlIconResourceInstance: PtrUInt;
begin
  Result := ModuleFromAddress(@LcaOwlIconResAnchor);
  if Result = 0 then
    Result := PtrUInt(HInstance);
end;

procedure AppendUniqueInstance(var AInstances: array of PtrUInt; var ACount: Integer;
  const AValue: PtrUInt);
var
  J: Integer;
begin
  if AValue = 0 then Exit;
  for J := 0 to ACount - 1 do
    if AInstances[J] = AValue then Exit;
  AInstances[ACount] := AValue;
  Inc(ACount);
end;

function LazarusIdeHostExecutable: Boolean;
var
  N: string;
begin
  N := LowerCase(ExtractFileName(ParamStr(0)));
  Result := (N = 'lazarus') or (N = 'startlazarus');
end;

function ComponentOrOwnerDesigning(AComponent: TComponent): Boolean;
begin
  while AComponent <> nil do begin
    if csDesigning in AComponent.ComponentState then
      Exit(True);
    AComponent := AComponent.Owner;
  end;
  Result := False;
end;

function LcaShouldSkipOwlIconLoad(const AComponent: TComponent = nil): Boolean;
begin
  if LazarusIdeHostExecutable then
    Exit(True);
  if Assigned(Application) and (csDesigning in Application.ComponentState) then
    Exit(True);
  if Assigned(AComponent) and ComponentOrOwnerDesigning(AComponent) then
    Exit(True);
  Result := False;
end;

function OwlIconAssetsDirectory: string;
var
  Dir: string;
begin
  Dir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'assets';
  if DirectoryExists(Dir) then
    Exit(Dir);
  Dir := IncludeTrailingPathDelimiter(GetCurrentDir) + 'assets';
  if DirectoryExists(Dir) then
    Exit(Dir);
  if Assigned(Application) then begin
    Dir := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + 'assets';
    if DirectoryExists(Dir) then
      Exit(Dir);
  end;
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'assets';
end;

function TryLoadOwlIconFromAssets(APicture: TPicture): Boolean;
const
  Names: array[0..2] of string = ('owl_icon.bmp', 'owl_icon.png', 'owl_icon.jpg');
var
  Base, Path: string;
  I: Integer;
begin
  Result := False;
  if not Assigned(APicture) then Exit;
  Base := IncludeTrailingPathDelimiter(OwlIconAssetsDirectory);
  for I := Low(Names) to High(Names) do begin
    Path := Base + Names[I];
    if not FileExists(Path) then Continue;
    try
      APicture.LoadFromFile(Path);
      Result := (APicture.Width > 0) and (APicture.Height > 0);
      if Result then Exit;
    except
      on E: Exception do
        Result := False;
    end;
  end;
end;

{$IFDEF WINDOWS}
function TryLoadOwlIconFromInstance(const AInstance: PtrUInt; APicture: TPicture): Boolean;
begin
  Result := False;
  if (AInstance = 0) or not Assigned(APicture) then Exit;
  try
    APicture.Bitmap.LoadFromResourceName(TLCLHandle(AInstance), OwlIconResourceName);
    Result := (APicture.Bitmap.Width > 0) and (APicture.Bitmap.Height > 0);
  except
    on E: Exception do
      Result := False;
  end;
end;

function TryLoadOwlIconFromStream(const AInstance: PtrUInt; const AResType: PChar;
  APicture: TPicture): Boolean;
var
  RS: TResourceStream;
begin
  Result := False;
  if (AInstance = 0) or not Assigned(APicture) then Exit;
  try
    RS := TResourceStream.Create(AInstance, OwlIconResourceName, AResType);
  except
    on E: EResNotFound do
      Exit;
  end;
  try
    if AResType = RT_BITMAP then
      APicture.Bitmap.LoadFromStream(RS, RS.Size)
    else
      APicture.LoadFromStream(RS);
    Result := (APicture.Width > 0) and (APicture.Height > 0);
  finally
    RS.Free;
  end;
end;
{$ENDIF}

function TryLoadOwlIconInto(APicture: TPicture): Boolean;
var
  Instances: array[0..7] of PtrUInt;
  ResTypes: array[0..2] of PChar;
  InstanceCount, I{$IFDEF WINDOWS}, T{$ENDIF}: Integer;
  {$IFDEF WINDOWS}
  ModHandle: HMODULE;
  {$ENDIF}
begin
  Result := False;
  if not Assigned(APicture) then Exit;
  if LcaShouldSkipOwlIconLoad then
    Exit;

  APicture.Graphic := nil;

  {$IFDEF UNIX}
  if TryLoadOwlIconFromAssets(APicture) then
    Exit(True);
  {$ENDIF}

  InstanceCount := 0;
  {$IFDEF WINDOWS}
  ModHandle := GetModuleHandle(nil);
  if ModHandle <> 0 then
    AppendUniqueInstance(Instances, InstanceCount, PtrUInt(ModHandle));
  {$ENDIF}
  AppendUniqueInstance(Instances, InstanceCount, PtrUInt(HInstance));
  AppendUniqueInstance(Instances, InstanceCount, LcaOwlIconResourceInstance);
  {$IFDEF WINDOWS}
  ModHandle := GetModuleHandle('LcaDesignSystem.bpl');
  if ModHandle <> 0 then
    AppendUniqueInstance(Instances, InstanceCount, PtrUInt(ModHandle));
  ModHandle := GetModuleHandle('lcadesignsystem.bpl');
  if ModHandle <> 0 then
    AppendUniqueInstance(Instances, InstanceCount, PtrUInt(ModHandle));
  {$ENDIF}

  {$IFDEF WINDOWS}
  for I := 0 to InstanceCount - 1 do
    if TryLoadOwlIconFromInstance(Instances[I], APicture) then
      Exit(True);

  ResTypes[0] := RT_BITMAP;
  ResTypes[1] := PChar('PNG');
  ResTypes[2] := RT_RCDATA;

  for I := 0 to InstanceCount - 1 do
    for T := Low(ResTypes) to High(ResTypes) do
      if TryLoadOwlIconFromStream(Instances[I], ResTypes[T], APicture) then
        Exit(True);
  {$ENDIF}
end;

procedure LoadOwlIconInto(APicture: TPicture);
begin
  if not TryLoadOwlIconInto(APicture) then
    raise EResNotFound.Create(OwlIconResourceName);
end;

end.
