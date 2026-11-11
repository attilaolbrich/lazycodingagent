unit uAppIcon;

{$mode objfpc}{$H+}

{ Taskbar / form icon from OWL PNG (LcaDesignSystem). EXE file icon uses windres ICON group. }

interface

procedure ApplyOwlApplicationIcon;

implementation

uses
  Classes, SysUtils, Graphics, Forms, LcaOwlIconRes;

procedure ApplyOwlApplicationIcon;
var
  Pic: TPicture;
begin
  if not Assigned(Application) then Exit;
  Pic := TPicture.Create;
  try
    try
      if TryLoadOwlIconInto(Pic) then
        Application.Icon.Assign(Pic.Bitmap);
    except
      on E: Exception do
        { OWL_ICON resource may be unavailable until the LCL module handle is ready (Qt5/Linux). }
    end;
  finally
    Pic.Free;
  end;
end;

end.
