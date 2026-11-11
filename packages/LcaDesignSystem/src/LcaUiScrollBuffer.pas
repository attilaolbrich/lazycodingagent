unit LcaUiScrollBuffer;

{$mode objfpc}{$H+}

{ Double-buffer policy for TLcaScrollHost. Qt5 disables buffering (existing behavior).
  On Windows, default off for large scroll surfaces; override with -dLCA_SCROLL_HOST_FORCE_DOUBLEBUFFER. }

interface

uses
  Controls, ExtCtrls;

procedure ApplyScrollHostDoubleBufferPolicy(AHost: TWinControl; AViewport: TPanel);

implementation

procedure ApplyScrollHostDoubleBufferPolicy(AHost: TWinControl; AViewport: TPanel);
var
  UseBuffer: Boolean;
begin
  {$IFDEF LCLQt5}
  UseBuffer := False;
  {$ELSE}
  {$IFDEF LCLcocoa}
  UseBuffer := False;
  {$ELSE}
  {$IFDEF LCA_SCROLL_HOST_FORCE_DOUBLEBUFFER}
  UseBuffer := True;
  {$ELSE}
  {$IFDEF LCLwin32}
  UseBuffer := False;
  {$ELSE}
  UseBuffer := True;
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  AHost.DoubleBuffered := UseBuffer;
  if Assigned(AViewport) then
    AViewport.DoubleBuffered := UseBuffer;
end;

end.
