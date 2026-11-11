unit LcaThemeWin32Combo;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, StdCtrls, LcaTheme;

procedure ApplyWin32ThemedComboPaint(ACombo: TComboBox; ATheme: TThemeKind);

implementation

{$IFDEF WINDOWS}

uses
  Graphics, LCLIntf, LMessages, Windows, LcaThemedComboBox;

type
  TWin32ThemedComboPaint = class(TComponent)
  private
    FCombo: TComboBox;
    FTheme: TThemeKind;
    FFocused: Boolean;
    FSubclassInstalled: Boolean;
    FInstalling: Boolean;
    FChainedWindowProc: Boolean;
    FPrevWindowProc: TWndMethod;
    procedure ComboWindowProc(var Message: TMessage);
    procedure InstallSubclass;
    procedure RemoveSubclass;
    procedure InvalidateCombo;
    procedure PaintClient(HDC: HDC);
    function ParentBackgroundColor: TColor;
    function DisplayText: string;
    function DroppedDown: Boolean;
    function ShowFocusRing: Boolean;
  public
    constructor Create(AOwner: TComboBox); reintroduce;
    destructor Destroy; override;
    procedure Apply(ATheme: TThemeKind);
    class function FindOnCombo(ACombo: TComboBox): TWin32ThemedComboPaint;
  end;

const
  WM_PRINTCLIENT = $0318;
  CB_GETDROPPEDSTATE = $0147;

type
  SUBCLASSPROC = function(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM;
    uIdSubclass: UINT_PTR; dwRefData: DWORD_PTR): LRESULT; stdcall;

function SetWindowSubclass(hWnd: HWND; pfnSubclass: SUBCLASSPROC; uIdSubclass: UINT_PTR;
  dwRefData: DWORD_PTR): BOOL; stdcall; external 'comctl32.dll' name 'SetWindowSubclass';

function RemoveWindowSubclass(hWnd: HWND; pfnSubclass: SUBCLASSPROC;
  uIdSubclass: UINT_PTR): BOOL; stdcall; external 'comctl32.dll' name 'RemoveWindowSubclass';

function DefSubclassProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
  stdcall; external 'comctl32.dll' name 'DefSubclassProc';

procedure SetWindowTheme(hwnd: HWND; pszSubAppName, pszSubIdList: PWideChar); stdcall;
  external 'uxtheme.dll' name 'SetWindowTheme';

function ThemedComboSubclassProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM;
  uIdSubclass: UINT_PTR; dwRefData: DWORD_PTR): LRESULT; stdcall;
var
  Helper: TWin32ThemedComboPaint;
  PS: TPaintStruct;
  DC: HDC;
begin
  Helper := TWin32ThemedComboPaint(Pointer(dwRefData));
  if Helper = nil then
    Exit(DefSubclassProc(hWnd, uMsg, wParam, lParam));
  if uMsg = WM_NCDESTROY then begin
    Helper.FSubclassInstalled := False;
    Exit(DefSubclassProc(hWnd, uMsg, wParam, lParam));
  end;
  if not Assigned(Helper.FCombo) or (Helper.FCombo.Handle <> hWnd) then
    Exit(DefSubclassProc(hWnd, uMsg, wParam, lParam));

  case uMsg of
    WM_ERASEBKGND:
      Exit(1);
    WM_PAINT:
      begin
        DC := BeginPaint(hWnd, PS);
        try
          Helper.PaintClient(DC);
        finally
          EndPaint(hWnd, PS);
        end;
        Exit(0);
      end;
    WM_PRINTCLIENT:
      begin
        Helper.PaintClient(HDC(wParam));
        Exit(0);
      end;
    WM_SETFOCUS, WM_KILLFOCUS, WM_ENABLE, WM_LBUTTONDOWN, WM_LBUTTONUP:
      Helper.InvalidateCombo;
  end;
  Result := DefSubclassProc(hWnd, uMsg, wParam, lParam);
end;

class function TWin32ThemedComboPaint.FindOnCombo(ACombo: TComboBox): TWin32ThemedComboPaint;
var
  I: Integer;
begin
  Result := nil;
  if not Assigned(ACombo) then Exit;
  for I := 0 to ACombo.ComponentCount - 1 do
    if ACombo.Components[I] is TWin32ThemedComboPaint then
      Exit(TWin32ThemedComboPaint(ACombo.Components[I]));
end;

constructor TWin32ThemedComboPaint.Create(AOwner: TComboBox);
begin
  inherited Create(AOwner);
  FCombo := AOwner;
  FSubclassInstalled := False;
  FInstalling := False;
  FChainedWindowProc := False;
  FFocused := False;
end;

destructor TWin32ThemedComboPaint.Destroy;
begin
  RemoveSubclass;
  if FChainedWindowProc and Assigned(FCombo) then
    FCombo.WindowProc := FPrevWindowProc;
  inherited Destroy;
end;

procedure TWin32ThemedComboPaint.InvalidateCombo;
begin
  if Assigned(FCombo) and FCombo.HandleAllocated then
    InvalidateRect(FCombo.Handle, nil, False);
end;

function TWin32ThemedComboPaint.ParentBackgroundColor: TColor;
begin
  if Assigned(FCombo.Parent) then
    Result := FCombo.Parent.Color
  else
    Result := clBtnFace;
end;

function TWin32ThemedComboPaint.ShowFocusRing: Boolean;
begin
  Result := True;
  if FCombo is TLcaThemedComboBox then
    Result := TLcaThemedComboBox(FCombo).ShowFocusRing;
end;

function TWin32ThemedComboPaint.DroppedDown: Boolean;
begin
  Result := False;
  if Assigned(FCombo) and FCombo.HandleAllocated then
    Result := SendMessage(FCombo.Handle, CB_GETDROPPEDSTATE, 0, 0) <> 0;
end;

function TWin32ThemedComboPaint.DisplayText: string;
begin
  Result := '';
  if not Assigned(FCombo) then Exit;
  if FCombo.Style in [csDropDownList, csOwnerDrawFixed, csOwnerDrawVariable] then begin
    if (FCombo.ItemIndex >= 0) and (FCombo.ItemIndex < FCombo.Items.Count) then
      Result := FCombo.Items[FCombo.ItemIndex]
    else
      Result := FCombo.Text;
  end else
    Result := FCombo.Text;
end;

procedure TWin32ThemedComboPaint.PaintClient(HDC: HDC);
var
  R: TRect;
  Canvas: TCanvas;
begin
  if not GetClientRect(FCombo.Handle, R) then Exit;
  Canvas := TCanvas.Create;
  try
    Canvas.Handle := HDC;
    Canvas.Brush.Color := ParentBackgroundColor;
    Canvas.FillRect(R);
    FFocused := GetFocus = FCombo.Handle;
    Canvas.Font.Assign(FCombo.Font);
    PaintThemedComboField(Canvas, R, FTheme, DisplayText, FCombo.Enabled,
      FFocused, DroppedDown, ShowFocusRing, ThemedComboCornerRadius(FCombo),
      ThemedComboChevronGutter(FCombo));
  finally
    Canvas.Handle := 0;
    Canvas.Free;
  end;
end;

procedure TWin32ThemedComboPaint.InstallSubclass;
begin
  if FSubclassInstalled or FInstalling then Exit;
  if not Assigned(FCombo) or not FCombo.HandleAllocated then Exit;
  FInstalling := True;
  try
    SetWindowTheme(FCombo.Handle, '', '');
    if SetWindowSubclass(FCombo.Handle, @ThemedComboSubclassProc, 2, PtrUInt(Self)) then
      FSubclassInstalled := True;
  finally
    FInstalling := False;
  end;
end;

procedure TWin32ThemedComboPaint.RemoveSubclass;
begin
  if not FSubclassInstalled then Exit;
  if Assigned(FCombo) and FCombo.HandleAllocated then
    RemoveWindowSubclass(FCombo.Handle, @ThemedComboSubclassProc, 2);
  FSubclassInstalled := False;
end;

procedure TWin32ThemedComboPaint.ComboWindowProc(var Message: TMessage);
var
  WasInstalled: Boolean;
begin
  WasInstalled := FSubclassInstalled;
  if Message.Msg <> LM_DESTROY then
    InstallSubclass;
  if FSubclassInstalled and not WasInstalled then begin
    if Message.Msg = LM_PAINT then begin
      if Message.WParam <> 0 then
        PaintClient(HDC(Message.WParam));
      Message.Result := 0;
      Exit;
    end;
    InvalidateCombo;
  end;
  if Assigned(FPrevWindowProc) then
    FPrevWindowProc(Message);
end;

procedure TWin32ThemedComboPaint.Apply(ATheme: TThemeKind);
begin
  FTheme := ATheme;
  if not FChainedWindowProc and Assigned(FCombo) then begin
    FPrevWindowProc := FCombo.WindowProc;
    FCombo.WindowProc := @ComboWindowProc;
    FChainedWindowProc := True;
  end;
  if FCombo.HandleAllocated then
    InstallSubclass;
  FCombo.Invalidate;
end;

procedure ApplyWin32ThemedComboPaint(ACombo: TComboBox; ATheme: TThemeKind);
begin
  if not Assigned(ACombo) then Exit;
  if csDesigning in ACombo.ComponentState then Exit;
  if csLoading in ACombo.ComponentState then Exit;
  if csReading in ACombo.ComponentState then Exit;
  if not ACombo.HandleAllocated then Exit;
  { Phase A: avoid WM_PAINT subclass on the composite Win32 combo; owner-draw + StyleComboBox only. }
  SetWindowTheme(ACombo.Handle, '', '');
  ACombo.Invalidate;
end;

{$ELSE}

procedure ApplyWin32ThemedComboPaint(ACombo: TComboBox; ATheme: TThemeKind);
begin
end;

{$ENDIF}

end.
