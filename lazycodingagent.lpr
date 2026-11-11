program lazycodingagent;

{$mode objfpc}{$H+}

{$R packages/LcaDesignSystem/res/owl_icon.res}

uses
  {$IFDEF UNIX}
  cthreads,
  uLinuxDisplayEnv,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset (keep cthreads/uLinuxDisplayEnv before Interfaces on Unix)
  SysUtils,
  Forms, mainunit, frmSplash, uWorkspaceState,
  uSqlite3Embed, uGlobalConfigBootstrap
  { you can add units after this };

{$IFDEF WINDOWS}
{$R lazycodingagent_appicon.res}
{$ENDIF}
{$R *.res}

var
  Splash: TSplashForm;

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
  Application.ShowMainForm := False;
  EnsureGlobalConfigReady;
  Splash := TSplashForm.Create(Application);
  try
    SetActiveSplashForm(Splash);
    Splash.ApplyTheme(LoadPersistedThemeKind);
    Splash.Show;
    Application.ProcessMessages;
    Splash.SetLoadProgress(0);
    Application.ProcessMessages;
    Application.CreateForm(TLazyCodingAgentForm, LazyCodingAgentForm);
    LazyCodingAgentForm.PrepareVisibleStartup;
    LazyCodingAgentForm.FinishThemingBehindSplash;
    Splash.HoldVisible(SplashPostLoadDelayMs);
  finally
    SetActiveSplashForm(nil);
    Splash.Hide;
    Splash.Free;
  end;
  Application.ShowMainForm := True;
  LazyCodingAgentForm.RevealAfterSplash;
  Application.Run;
end.
