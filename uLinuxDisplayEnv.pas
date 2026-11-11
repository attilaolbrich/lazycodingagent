unit uLinuxDisplayEnv;

{$mode objfpc}{$H+}

{ Must load before Interfaces so Qt/GDK read QT_QPA_PLATFORM / GDK_BACKEND at init. }

interface

implementation

uses
  SysUtils;

function libc_setenv(name, value: PChar; overwrite: Integer): Integer; cdecl;
  external 'c' name 'setenv';

procedure ApplyLinuxWaylandWorkarounds;
begin
  if GetEnvironmentVariable('WAYLAND_DISPLAY') = '' then
    Exit;
  {$IFDEF LCLGtk2}
  if GetEnvironmentVariable('GDK_BACKEND') = '' then
    libc_setenv('GDK_BACKEND', 'x11', 1);
  {$ENDIF}
  {$IFDEF LCLQt5}
  if GetEnvironmentVariable('QT_QPA_PLATFORM') = '' then
    libc_setenv('QT_QPA_PLATFORM', 'xcb', 1);
  {$ENDIF}
end;

initialization
  ApplyLinuxWaylandWorkarounds;

end.
