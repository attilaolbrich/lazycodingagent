unit uAppSettingsCodec;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, uRepositoryInterfaces;

function SettingsTryGetInt(ARepo: IAppSettingsRepository; const AKey: string;
  ADefault: Integer): Integer;
function SettingsTryGetFloat(ARepo: IAppSettingsRepository; const AKey: string;
  ADefault: Double): Double;
function SettingsTryGetBool(ARepo: IAppSettingsRepository; const AKey: string;
  ADefault: Boolean): Boolean;
function SettingsTryGetString(ARepo: IAppSettingsRepository; const AKey: string;
  const ADefault: string): string;

procedure SettingsSetInt(ARepo: IAppSettingsRepository; const AKey: string; AValue: Integer);
procedure SettingsSetFloat(ARepo: IAppSettingsRepository; const AKey: string; AValue: Double);
procedure SettingsSetBool(ARepo: IAppSettingsRepository; const AKey: string; AValue: Boolean);
procedure SettingsSetString(ARepo: IAppSettingsRepository; const AKey, AValue: string);

implementation

function SettingsTryGetString(ARepo: IAppSettingsRepository; const AKey: string;
  const ADefault: string): string;
var
  V: string;
begin
  if ARepo.TryGet(AKey, V) then
    Result := V
  else
    Result := ADefault;
end;

function SettingsTryGetInt(ARepo: IAppSettingsRepository; const AKey: string;
  ADefault: Integer): Integer;
var
  V: string;
begin
  if ARepo.TryGet(AKey, V) and TryStrToInt(Trim(V), Result) then
    Exit;
  Result := ADefault;
end;

function SettingsTryGetFloat(ARepo: IAppSettingsRepository; const AKey: string;
  ADefault: Double): Double;
var
  V: string;
begin
  if ARepo.TryGet(AKey, V) and TryStrToFloat(Trim(V), Result) then
    Exit;
  Result := ADefault;
end;

function SettingsTryGetBool(ARepo: IAppSettingsRepository; const AKey: string;
  ADefault: Boolean): Boolean;
var
  V: string;
begin
  if not ARepo.TryGet(AKey, V) then
    Exit(ADefault);
  V := LowerCase(Trim(V));
  if (V = '1') or (V = 'true') or (V = 'yes') then
    Exit(True);
  if (V = '0') or (V = 'false') or (V = 'no') then
    Exit(False);
  Result := ADefault;
end;

procedure SettingsSetString(ARepo: IAppSettingsRepository; const AKey, AValue: string);
begin
  ARepo.SetString(AKey, AValue);
end;

procedure SettingsSetInt(ARepo: IAppSettingsRepository; const AKey: string; AValue: Integer);
begin
  ARepo.SetString(AKey, IntToStr(AValue));
end;

procedure SettingsSetFloat(ARepo: IAppSettingsRepository; const AKey: string; AValue: Double);
begin
  ARepo.SetString(AKey, FloatToStr(AValue));
end;

procedure SettingsSetBool(ARepo: IAppSettingsRepository; const AKey: string; AValue: Boolean);
begin
  if AValue then
    ARepo.SetString(AKey, 'true')
  else
    ARepo.SetString(AKey, 'false');
end;

end.
