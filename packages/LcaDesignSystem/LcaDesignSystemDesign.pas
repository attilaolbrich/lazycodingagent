{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit LcaDesignSystemDesign;

{$warn 5023 off : no warning about unused units}
interface

uses
  LcaDesignReg, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('LcaDesignReg', @LcaDesignReg.Register);
end;

initialization
  RegisterPackage('LcaDesignSystemDesign', @Register);
end.
