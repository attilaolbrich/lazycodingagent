unit LcaUiPaintProfile;

{$mode objfpc}{$H+}

{ Opt-in UI paint/layout counters. Enable with -dLCA_UI_PAINT_PROFILE (Lazarus: Project /
  Compiler Options / Custom defines). Lines go to Debug Output once per second. }

interface

uses
  SysUtils;

procedure LcaUiProfileEnsureStarted;
procedure LcaUiProfileRecordThemedPaint(ADurationMs: QWord);
procedure LcaUiProfileRecordGutterPaint(ADurationMs: QWord);
procedure LcaUiProfileRecordLayoutFromScroll(ADurationMs: QWord; AContentSetBounds: Boolean);
procedure LcaUiProfileRecordMarkdownRender;
procedure LcaUiProfileRecordMarkdownSyncContent;
procedure LcaUiProfileRecordMarkdownGetContentSize;

implementation

{$IFDEF LCA_UI_PAINT_PROFILE}

uses
  ExtCtrls, Forms;

type
  TLcaUiProfileState = record
    ThemedPaintCount: QWord;
    ThemedPaintTotalMs: QWord;
    ThemedPaintMaxMs: QWord;
    GutterPaintCount: QWord;
    GutterPaintTotalMs: QWord;
    GutterPaintMaxMs: QWord;
    LayoutFromScrollCount: QWord;
    LayoutFromScrollTotalMs: QWord;
    LayoutFromScrollMaxMs: QWord;
    ContentSetBoundsCount: QWord;
    MarkdownRenderCount: QWord;
    MarkdownSyncCount: QWord;
    MarkdownGetContentSizeCount: QWord;
  end;

var
  GProfile: TLcaUiProfileState;
  GProfileTimer: TTimer;
  GProfileStarted: Boolean;

procedure LcaUiProfileOnTimer(Sender: TObject);
var
  S: TLcaUiProfileState;
  ThemedAvg, GutterAvg, LayoutAvg: Double;
begin
  S := GProfile;
  FillChar(GProfile, SizeOf(GProfile), 0);
  if S.ThemedPaintCount > 0 then
    ThemedAvg := S.ThemedPaintTotalMs / S.ThemedPaintCount
  else
    ThemedAvg := 0;
  if S.GutterPaintCount > 0 then
    GutterAvg := S.GutterPaintTotalMs / S.GutterPaintCount
  else
    GutterAvg := 0;
  if S.LayoutFromScrollCount > 0 then
    LayoutAvg := S.LayoutFromScrollTotalMs / S.LayoutFromScrollCount
  else
    LayoutAvg := 0;
  DebugLn(Format(
    'LCA_UI_PAINT_PROFILE 1s: themedPaint=%d avg=%.2f max=%.0fms gutterPaint=%d avg=%.2f max=%.0fms ' +
    'layoutFromScroll=%d avg=%.2f max=%.0fms contentSetBounds=%d mdRender=%d mdSync=%d mdGetSize=%d',
    [S.ThemedPaintCount, ThemedAvg, S.ThemedPaintMaxMs,
     S.GutterPaintCount, GutterAvg, S.GutterPaintMaxMs,
     S.LayoutFromScrollCount, LayoutAvg, S.LayoutFromScrollMaxMs,
     S.ContentSetBoundsCount, S.MarkdownRenderCount, S.MarkdownSyncCount,
     S.MarkdownGetContentSizeCount]));
end;

procedure LcaUiProfileEnsureStarted;
begin
  if GProfileStarted then Exit;
  if not Assigned(Application) then Exit;
  GProfileStarted := True;
  GProfileTimer := TTimer.Create(Application);
  GProfileTimer.Interval := 1000;
  GProfileTimer.OnTimer := @LcaUiProfileOnTimer;
  GProfileTimer.Enabled := True;
end;

procedure LcaUiProfileRecordThemedPaint(ADurationMs: QWord);
begin
  LcaUiProfileEnsureStarted;
  Inc(GProfile.ThemedPaintCount);
  Inc(GProfile.ThemedPaintTotalMs, ADurationMs);
  if ADurationMs > GProfile.ThemedPaintMaxMs then
    GProfile.ThemedPaintMaxMs := ADurationMs;
end;

procedure LcaUiProfileRecordGutterPaint(ADurationMs: QWord);
begin
  LcaUiProfileEnsureStarted;
  Inc(GProfile.GutterPaintCount);
  Inc(GProfile.GutterPaintTotalMs, ADurationMs);
  if ADurationMs > GProfile.GutterPaintMaxMs then
    GProfile.GutterPaintMaxMs := ADurationMs;
end;

procedure LcaUiProfileRecordLayoutFromScroll(ADurationMs: QWord; AContentSetBounds: Boolean);
begin
  LcaUiProfileEnsureStarted;
  Inc(GProfile.LayoutFromScrollCount);
  Inc(GProfile.LayoutFromScrollTotalMs, ADurationMs);
  if ADurationMs > GProfile.LayoutFromScrollMaxMs then
    GProfile.LayoutFromScrollMaxMs := ADurationMs;
  if AContentSetBounds then
    Inc(GProfile.ContentSetBoundsCount);
end;

procedure LcaUiProfileRecordMarkdownRender;
begin
  LcaUiProfileEnsureStarted;
  Inc(GProfile.MarkdownRenderCount);
end;

procedure LcaUiProfileRecordMarkdownSyncContent;
begin
  LcaUiProfileEnsureStarted;
  Inc(GProfile.MarkdownSyncCount);
end;

procedure LcaUiProfileRecordMarkdownGetContentSize;
begin
  LcaUiProfileEnsureStarted;
  Inc(GProfile.MarkdownGetContentSizeCount);
end;

{$ELSE}

procedure LcaUiProfileEnsureStarted;
begin
end;

procedure LcaUiProfileRecordThemedPaint(ADurationMs: QWord);
begin
  if ADurationMs = 0 then ;
end;

procedure LcaUiProfileRecordGutterPaint(ADurationMs: QWord);
begin
  if ADurationMs = 0 then ;
end;

procedure LcaUiProfileRecordLayoutFromScroll(ADurationMs: QWord; AContentSetBounds: Boolean);
begin
  if ADurationMs = 0 then ;
  if not AContentSetBounds then ;
end;

procedure LcaUiProfileRecordMarkdownRender;
begin
end;

procedure LcaUiProfileRecordMarkdownSyncContent;
begin
end;

procedure LcaUiProfileRecordMarkdownGetContentSize;
begin
end;

{$ENDIF}

end.
