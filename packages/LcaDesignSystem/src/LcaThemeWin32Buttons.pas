unit LcaThemeWin32Buttons;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, StdCtrls, LcaTheme;

procedure ApplyWin32ThemedButtonPaint(ABtn: TButton; ATheme: TThemeKind;
  ARole: TThemedButtonRole);

implementation

{$IFDEF WINDOWS}

uses
  SysUtils, Graphics, LCLIntf, LMessages, Windows;

type
  TWin32ThemedButtonPaint = class(TComponent)
  private
    FButton: TButton;
    FTheme: TThemeKind;
    FRole: TThemedButtonRole;
    FHover: Boolean;
    FSubclassInstalled: Boolean;
    FInstalling: Boolean;
    FChainedWindowProc: Boolean;
    FPrevWindowProc: TWndMethod;
    FClientCanvas: TCanvas;
    procedure ButtonWindowProc(var Message: TMessage);
    procedure InstallSubclass;
    procedure RemoveSubclass;
    procedure InvalidateButton;
    procedure PaintClient(HDC: HDC);
    function ParentBackgroundColor: TColor;
    function DisplayCaption: string;
  public
    constructor Create(AOwner: TButton); reintroduce;
    destructor Destroy; override;
    procedure Apply(ATheme: TThemeKind; ARole: TThemedButtonRole);
    class function FindOnButton(ABtn: TButton): TWin32ThemedButtonPaint;
  end;

const
  WM_PRINTCLIENT = $0318;
  WM_MOUSELEAVE = $02A3;
  BM_GETSTATE = $00F0;
  BST_PUSHED = $0004;
  TME_LEAVE = $00000002;

type
  TTrackMouseEvent = record
    cbSize: DWORD;
    dwFlags: DWORD;
    hwndTrack: HWND;
    dwHoverTime: DWORD;
  end;

  SUBCLASSPROC = function(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM;
    uIdSubclass: UINT_PTR; dwRefData: DWORD_PTR): LRESULT; stdcall;

function TrackMouseEvent(var EventTrack: TTrackMouseEvent): BOOL; stdcall;
  external 'user32.dll' name 'TrackMouseEvent';

function SetWindowSubclass(hWnd: HWND; pfnSubclass: SUBCLASSPROC; uIdSubclass: UINT_PTR;
  dwRefData: DWORD_PTR): BOOL; stdcall; external 'comctl32.dll' name 'SetWindowSubclass';

function RemoveWindowSubclass(hWnd: HWND; pfnSubclass: SUBCLASSPROC;
  uIdSubclass: UINT_PTR): BOOL; stdcall; external 'comctl32.dll' name 'RemoveWindowSubclass';

function DefSubclassProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
  stdcall; external 'comctl32.dll' name 'DefSubclassProc';

procedure SetWindowTheme(hwnd: HWND; pszSubAppName, pszSubIdList: PWideChar); stdcall;
  external 'uxtheme.dll' name 'SetWindowTheme';

function Win32ButtonDisplayCaption(const ACaption: string): string;
var
  P: Integer;
begin
  Result := ACaption;
  P := Pos('&', Result);
  while P > 0 do begin
    if (P < Length(Result)) and (Result[P + 1] = '&') then
      Delete(Result, P, 1)
    else
      Delete(Result, P, 1);
    P := Pos('&', Result);
  end;
end;

function ThemedButtonSubclassProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM;
  uIdSubclass: UINT_PTR; dwRefData: DWORD_PTR): LRESULT; stdcall;
var
  Helper: TWin32ThemedButtonPaint;
  PS: TPaintStruct;
  DC: HDC;
  R: TRect;
  TME: TTrackMouseEvent;
begin
  Helper := TWin32ThemedButtonPaint(Pointer(dwRefData));
  if Helper = nil then
    Exit(DefSubclassProc(hWnd, uMsg, wParam, lParam));
  if uMsg = WM_NCDESTROY then begin
    Helper.FSubclassInstalled := False;
    Helper.FHover := False;
    Exit(DefSubclassProc(hWnd, uMsg, wParam, lParam));
  end;
  if not Assigned(Helper.FButton) or (Helper.FButton.Handle <> hWnd) then
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
        if GetClientRect(hWnd, R) then
          Helper.PaintClient(HDC(wParam));
        Exit(0);
      end;
    WM_MOUSEMOVE:
      begin
        if not Helper.FHover then begin
          Helper.FHover := True;
          Helper.InvalidateButton;
          FillChar(TME, SizeOf(TME), 0);
          TME.cbSize := SizeOf(TME);
          TME.dwFlags := TME_LEAVE;
          TME.hwndTrack := hWnd;
          TrackMouseEvent(TME);
        end;
      end;
    WM_MOUSELEAVE:
      begin
        Helper.FHover := False;
        Helper.InvalidateButton;
      end;
    WM_LBUTTONDOWN, WM_LBUTTONUP, WM_SETFOCUS, WM_KILLFOCUS, WM_ENABLE:
      Helper.InvalidateButton;
  end;
  Result := DefSubclassProc(hWnd, uMsg, wParam, lParam);
end;

class function TWin32ThemedButtonPaint.FindOnButton(ABtn: TButton): TWin32ThemedButtonPaint;
var
  I: Integer;
begin
  Result := nil;
  if not Assigned(ABtn) then Exit;
  for I := 0 to ABtn.ComponentCount - 1 do
    if ABtn.Components[I] is TWin32ThemedButtonPaint then
      Exit(TWin32ThemedButtonPaint(ABtn.Components[I]));
end;

constructor TWin32ThemedButtonPaint.Create(AOwner: TButton);
begin
  inherited Create(AOwner);
  FButton := AOwner;
  FHover := False;
  FSubclassInstalled := False;
  FInstalling := False;
  FChainedWindowProc := False;
  FClientCanvas := TCanvas.Create;
end;

destructor TWin32ThemedButtonPaint.Destroy;
begin
  RemoveSubclass;
  if FChainedWindowProc and Assigned(FButton) then
    FButton.WindowProc := FPrevWindowProc;
  if Assigned(FClientCanvas) then begin
    FClientCanvas.Handle := 0;
    FreeAndNil(FClientCanvas);
  end;
  inherited Destroy;
end;

procedure TWin32ThemedButtonPaint.InvalidateButton;
begin
  if Assigned(FButton) and FButton.HandleAllocated then
    InvalidateRect(FButton.Handle, nil, False);
end;

function TWin32ThemedButtonPaint.ParentBackgroundColor: TColor;
begin
  if Assigned(FButton.Parent) then
    Result := FButton.Parent.Color
  else
    Result := clBtnFace;
end;

function TWin32ThemedButtonPaint.DisplayCaption: string;
begin
  Result := Win32ButtonDisplayCaption(FButton.Caption);
end;

procedure TWin32ThemedButtonPaint.PaintClient(HDC: HDC);
var
  R: TRect;
  Enabled, Pressed, Focused: Boolean;
begin
  if not Assigned(FClientCanvas) then Exit;
  if not GetClientRect(FButton.Handle, R) then Exit;
  FClientCanvas.Handle := HDC;
  try
    FClientCanvas.Brush.Color := ParentBackgroundColor;
    FClientCanvas.FillRect(R);
    Enabled := FButton.Enabled;
    Focused := GetFocus = FButton.Handle;
    Pressed := (SendMessage(FButton.Handle, BM_GETSTATE, 0, 0) and BST_PUSHED) <> 0;
    FClientCanvas.Font.Assign(FButton.Font);
    PaintThemedButton(FClientCanvas, R, FTheme, FRole, DisplayCaption, Enabled, FHover and Enabled,
      Pressed, Focused, ThemedButtonCornerRadius(FButton), FButton.Font.Size, 0, FButton);
  finally
    FClientCanvas.Handle := 0;
  end;
end;

procedure TWin32ThemedButtonPaint.InstallSubclass;
begin
  if FSubclassInstalled or FInstalling then Exit;
  if not Assigned(FButton) or not FButton.HandleAllocated then Exit;
  FInstalling := True;
  try
    SetWindowTheme(FButton.Handle, '', '');
    if SetWindowSubclass(FButton.Handle, @ThemedButtonSubclassProc, 1, PtrUInt(Self)) then
      FSubclassInstalled := True;
  finally
    FInstalling := False;
  end;
end;

procedure TWin32ThemedButtonPaint.RemoveSubclass;
begin
  if not FSubclassInstalled then Exit;
  if Assigned(FButton) and FButton.HandleAllocated then
    RemoveWindowSubclass(FButton.Handle, @ThemedButtonSubclassProc, 1);
  FSubclassInstalled := False;
end;

procedure TWin32ThemedButtonPaint.ButtonWindowProc(var Message: TMessage);
var
  WasInstalled: Boolean;
begin
  WasInstalled := FSubclassInstalled;
  // Win32 does not deliver WM_CREATE to the LCL WindowProc. Dialogs style
  // buttons before the HWND exists, so install on the first later message.
  if Message.Msg <> LM_DESTROY then
    InstallSubclass;
  if FSubclassInstalled and not WasInstalled then begin
    if Message.Msg = LM_PAINT then begin
      if Message.WParam <> 0 then
        PaintClient(HDC(Message.WParam));
      Message.Result := 0;
      Exit;
    end;
    InvalidateButton;
  end;
  if Assigned(FPrevWindowProc) then
    FPrevWindowProc(Message);
end;

procedure TWin32ThemedButtonPaint.Apply(ATheme: TThemeKind; ARole: TThemedButtonRole);
begin
  FTheme := ATheme;
  FRole := ARole;
  if not FChainedWindowProc and Assigned(FButton) then begin
    FPrevWindowProc := FButton.WindowProc;
    FButton.WindowProc := @ButtonWindowProc;
    FChainedWindowProc := True;
  end;
  if FButton.HandleAllocated then
    InstallSubclass;
  FButton.Invalidate;
end;

procedure ApplyWin32ThemedButtonPaint(ABtn: TButton; ATheme: TThemeKind;
  ARole: TThemedButtonRole);
var
  Helper: TWin32ThemedButtonPaint;
begin
  if not Assigned(ABtn) then Exit;
  if csDesigning in ABtn.ComponentState then Exit;
  if csLoading in ABtn.ComponentState then Exit;
  if csReading in ABtn.ComponentState then Exit;
  if not ABtn.HandleAllocated then Exit;
  Helper := TWin32ThemedButtonPaint.FindOnButton(ABtn);
  if Helper = nil then
    Helper := TWin32ThemedButtonPaint.Create(ABtn);
  Helper.Apply(ATheme, ARole);
end;

{$ELSE}

procedure ApplyWin32ThemedButtonPaint(ABtn: TButton; ATheme: TThemeKind;
  ARole: TThemedButtonRole);
begin
end;

{$ENDIF}

end.
