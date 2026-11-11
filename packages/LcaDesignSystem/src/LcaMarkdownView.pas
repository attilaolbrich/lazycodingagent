unit LcaMarkdownView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, Controls, Graphics, Types, LCLType, LMessages, LcaThemedControl, LcaTheme;

type
  TSelectFragRec = record
    StartIdx: Integer;
    Text: string;
    DocRect: TRect;
  end;

  TLcaMarkdownView = class(TLcaThemedControl)
  private
    FSource: string;
    FBlocks: TObjectList;
    FContentHeight: Integer;
    FLayoutTextWidth: Integer;
    FScrollY: Integer;
    FAutoScrollToEnd: Boolean;
    FStickToBottom: Boolean;
    FShowVBar: Boolean;
    FDragScrollActive: Boolean;
    FDragThumbOffset: Integer;
    FWheelAccumY: Integer;
    FWheelFlushQueued: Boolean;
    FLayoutGuard: Boolean;
    FPainting: Boolean;
    FNeedsLayout: Boolean;
    FRelayoutQueued: Boolean;
    FPendingRebuild: Boolean;
    FPendingScrollToEnd: Boolean;
    FSelectLayoutValid: Boolean;
    FPlainText: string;
    FSelectFrags: array of TSelectFragRec;
    FSelAnchor: Integer;
    FSelCaret: Integer;
    FSelActive: Boolean;
    FTextSelDrag: Boolean;
    FParseInFence: Boolean;
    FParseInList: Boolean;
    FEphemeralThinkingVisible: Boolean;
    FEphemeralThinkingBlock: TObject;
    procedure SetAutoScrollToEnd(AValue: Boolean);
    procedure RebuildBlocksFromSource;
    procedure ParseAppendToBlocks(const ALines: TStrings; AStartLineIndex: Integer);
    procedure RelayoutDocumentFrom(AStartBlockIndex: Integer);
    procedure RelayoutEphemeralTail;
    procedure RelayoutDocument;
    function ContentBusy: Boolean;
    procedure ScheduleDeferredRelayout;
    procedure DeferredRelayout(Data: PtrInt);
    procedure ApplyDeferredContent;
    function ContentPad: Integer;
    function ScrollbarThickness: Integer;
    function TextAreaWidth: Integer;
    function MaxScrollY: Integer;
    procedure ClampScroll;
    procedure UpdateStickToBottomFromScroll;
    procedure ApplyScrollPolicy(AForceStick: Boolean);
    procedure ScrollToEnd;
    function VerticalTrackRect: TRect;
    function VerticalThumbRect: TRect;
    function HitOnVerticalThumb(X, Y: Integer): Boolean;
    function HitInVerticalTrack(X, Y: Integer): Boolean;
    procedure ScrollByDelta(ADeltaY: Integer);
    procedure ScheduleWheelFlush;
    procedure WheelFlush(Data: PtrInt);
    function FirstVisibleBlockIndex(AViewTop: Integer): Integer;
    procedure PaintDocument(ACanvas: TCanvas; const P: TThemePalette);
    procedure PaintScrollbar(const P: TThemePalette);
    procedure PaintScrollbarTrack(ACanvas: TCanvas; const ARect: TRect; const P: TThemePalette);
    procedure PaintScrollbarThumb(ACanvas: TCanvas; const ARect: TRect; const P: TThemePalette);
    procedure ClearTextSelection;
    procedure InvalidateSelectionLayout;
    procedure EnsureSelectionLayout;
    procedure BuildSelectionLayout;
    function SelectionBounds(out ALo, AHi: Integer): Boolean;
    function SelectedPlainText: string;
    function ClientPointToPlainIndex(AX, AY: Integer): Integer;
    procedure PaintTextSelection(ACanvas: TCanvas; const P: TThemePalette);
    procedure CopySelectionToClipboard;
    procedure SelectAllText;
    procedure SelectWordAt(AIndex: Integer);
    procedure WMCopy(var Msg: TLMessage); message LM_COPY;
  protected
    procedure DoApplyThemeColors(const P: TThemePalette); override;
    procedure PaintThemedClient(const ARect: TRect; const P: TThemePalette); override;
    procedure Paint; override;
    procedure Loaded; override;
    procedure CreateWnd; override;
    procedure Resize; override;
    procedure ChangeScale(M, D: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AppendChunk(const AText: string);
    procedure AppendMarkdownTail(const ADelta: string; AScrollToEndAfter: Boolean = False);
    procedure SetEphemeralThinkingVisible(AVisible: Boolean);
    function EphemeralThinkingVisible: Boolean;
    procedure SetMarkdownText(const AText: string);
    procedure Clear;
    procedure SetMarkdown(const AMarkdown: string; AScrollToEndAfterRender: Boolean = False);
    procedure ScrollToEndIfAutoScroll;
    procedure RequestRender;
  published
    property AutoScrollToEnd: Boolean read FAutoScrollToEnd write SetAutoScrollToEnd default True;
    property Align;
    property Anchors;
    property Left;
    property Top;
    property Width;
    property Height;
    property TabOrder;
    property TabStop;
  end;

implementation

uses
  Math, LCLIntf, Forms, Clipbrd, LcaUiPaintProfile, LcaPaintPrimitives;

type
  TSelectLayoutState = record
    Plain: string;
    Frags: array of TSelectFragRec;
  end;

const
  LCA_MD_PAD_BASE = 8;
  LCA_MD_CODE_PAD_BASE = 8;
  LCA_MD_BULLET_INDENT_BASE = 18;
  LCA_MD_LINE_LEADING_BASE = 4;
  LCA_MD_LINE_EXTRA_BASE = 6;
  LCA_MD_EMPTY_BLOCK_BASE = 6;
  LCA_MD_HRULE_BLOCK_BASE = 16;
  LCA_MD_SCROLL_BOTTOM_EPS = 4;
  LCA_EPHEMERAL_THINKING_TEXT = 'Thinking...';
  LCA_MD_BULLET = #$E2#$80#$A2;

type
  TMarkdownBlockKind = (
    mbkEmpty, mbkHeading, mbkParagraph, mbkCode, mbkBullet, mbkHRule,
    mbkThinking, mbkTool);

  TChatLabelRole = (clrNone, clrUser, clrAgent, clrTool, clrThinking);

  TInlineStyle = (isNormal, isBold, isItalic, isCode);

  TInlineRun = record
    Text: string;
    Style: TInlineStyle;
  end;

  TInlineRunArray = array of TInlineRun;

  TLayoutFrag = record
    X: Integer;
    Width: Integer;
    Text: string;
    Style: TInlineStyle;
  end;

  TLayoutLine = record
    Y: Integer;
    Height: Integer;
    Frags: array of TLayoutFrag;
  end;

  TLayoutLineArray = array of TLayoutLine;

  TMarkdownBlockObj = class
  public
    Kind: TMarkdownBlockKind;
    HeadingLevel: Byte;
    ChatLabelRole: TChatLabelRole;
    Runs: array of TInlineRun;
    CodeText: string;
    CalculatedHeight: Integer;
    LayoutTop: Integer;
    LineHeight: Integer;
    Lines: TLayoutLineArray;
    PrefixText: string;
    PrefixWidth: Integer;
    PrefixX: Integer;
  end;

procedure AppendInlineRun(var ARuns: TInlineRunArray; const AText: string;
  AStyle: TInlineStyle);
var
  N: Integer;
begin
  if AText = '' then Exit;
  N := Length(ARuns);
  SetLength(ARuns, N + 1);
  ARuns[N].Text := AText;
  ARuns[N].Style := AStyle;
end;

procedure ParseInlineMarkdown(const S: string; out ARuns: TInlineRunArray);
var
  I, N: Integer;
  InBold, InCode, InItalic: Boolean;
  Token: string;
  Style: TInlineStyle;
begin
  SetLength(ARuns, 0);
  I := 1;
  InBold := False;
  InCode := False;
  InItalic := False;
  while I <= Length(S) do begin
    if (I + 1 <= Length(S)) and (S[I] = '*') and (S[I + 1] = '*') then begin
      if InCode then
        AppendInlineRun(ARuns, Copy(S, I, 2), isNormal)
      else
        InBold := not InBold;
      Inc(I, 2);
      Continue;
    end;
    if (not InBold) and (not InCode) and (S[I] = '*') then begin
      InItalic := not InItalic;
      Inc(I);
      Continue;
    end;
    if S[I] = '`' then begin
      if InBold or InItalic then
        AppendInlineRun(ARuns, '`', isNormal)
      else
        InCode := not InCode;
      Inc(I);
      Continue;
    end;
    N := I;
    while (N <= Length(S)) and not (
      ((N + 1 <= Length(S)) and (S[N] = '*') and (S[N + 1] = '*')) or
      (S[N] = '`') or
      ((not InBold) and (not InCode) and (S[N] = '*'))) do
      Inc(N);
    Token := Copy(S, I, N - I);
    if InCode then
      Style := isCode
    else if InBold then
      Style := isBold
    else if InItalic then
      Style := isItalic
    else
      Style := isNormal;
    AppendInlineRun(ARuns, Token, Style);
    I := N;
  end;
end;

function ClassifyChatHeadingRole(const ABody: string): TChatLabelRole;
var
  T: string;
begin
  T := Trim(ABody);
  if SameText(T, 'You') then
    Exit(clrUser);
  if SameText(T, 'Agent') then
    Exit(clrAgent);
  if (Length(T) >= 4) and SameText(Copy(T, 1, 4), 'Tool') then
    Exit(clrTool);
  Result := clrNone;
end;

function ChatLabelTextColor(const P: TThemePalette; ARole: TChatLabelRole): TColor;
begin
  case ARole of
    clrUser: Result := P.ChatLabelUser;
    clrAgent: Result := P.ChatLabelAgent;
    clrTool: Result := P.ChatLabelTool;
    clrThinking: Result := P.ChatLabelThinking;
  else
    Result := P.Text;
  end;
end;

function IsHorizontalRuleLine(const ATrimmed: string): Boolean;
var
  I: Integer;
begin
  if Length(ATrimmed) < 3 then Exit(False);
  for I := 1 to Length(ATrimmed) do
    if ATrimmed[I] <> '-' then
      Exit(False);
  Result := True;
end;

procedure AddBlockParagraph(ABlocks: TObjectList;
  AKind: TMarkdownBlockKind; const ALine: string; AHeadingLevel: Byte = 0);
var
  B: TMarkdownBlockObj;
begin
  B := TMarkdownBlockObj.Create;
  B.Kind := AKind;
  B.HeadingLevel := AHeadingLevel;
  B.ChatLabelRole := clrNone;
  case AKind of
    mbkHeading: B.ChatLabelRole := ClassifyChatHeadingRole(ALine);
    mbkThinking: B.ChatLabelRole := clrThinking;
    mbkTool: B.ChatLabelRole := clrTool;
  end;
  ParseInlineMarkdown(ALine, B.Runs);
  ABlocks.Add(B);
end;

procedure ParseMarkdownLines(const ALines: TStrings; AStartLineIndex: Integer;
  var AInFence, AInList: Boolean; ABlocks: TObjectList);
var
  I, Level: Integer;
  Line, Trimmed, Body: string;
  B: TMarkdownBlockObj;
begin
  for I := AStartLineIndex to ALines.Count - 1 do begin
    Line := ALines[I];
    Trimmed := Trim(Line);
    if AInFence then begin
      if Trimmed = '```' then begin
        AInFence := False;
      end else if ABlocks.Count > 0 then begin
        B := TMarkdownBlockObj(ABlocks[ABlocks.Count - 1]);
        if B.CodeText <> '' then
          B.CodeText := B.CodeText + LineEnding;
        B.CodeText := B.CodeText + Line;
      end else begin
        B := TMarkdownBlockObj.Create;
        B.Kind := mbkCode;
        B.CodeText := Line;
        ABlocks.Add(B);
      end;
      Continue;
    end;
    if (Length(Trimmed) >= 3) and (Copy(Trimmed, 1, 3) = '```') then begin
      if AInList then
        AInList := False;
      B := TMarkdownBlockObj.Create;
      B.Kind := mbkCode;
      B.CodeText := '';
      ABlocks.Add(B);
      AInFence := True;
      Continue;
    end;
    if Trimmed = '' then begin
      if AInList then
        AInList := False;
      B := TMarkdownBlockObj.Create;
      B.Kind := mbkEmpty;
      ABlocks.Add(B);
      Continue;
    end;
    if IsHorizontalRuleLine(Trimmed) then begin
      if AInList then
        AInList := False;
      B := TMarkdownBlockObj.Create;
      B.Kind := mbkHRule;
      ABlocks.Add(B);
      Continue;
    end;
    if (Length(Trimmed) > 0) and (Trimmed[1] = '#') then begin
      if AInList then
        AInList := False;
      Level := 0;
      while (Level < Length(Trimmed)) and (Trimmed[Level + 1] = '#') do
        Inc(Level);
      if (Level >= 1) and (Level <= 6) and
         ((Level = Length(Trimmed)) or (Trimmed[Level + 1] = ' ')) then begin
        Body := Trim(Copy(Trimmed, Level + 1, MaxInt));
        AddBlockParagraph(ABlocks, mbkHeading, Body, Level);
        Continue;
      end;
    end;
    if (Length(Trimmed) >= 2) and ((Copy(Trimmed, 1, 2) = '- ') or (Copy(Trimmed, 1, 2) = '* ')) then begin
      Body := Trim(Copy(Trimmed, 3, MaxInt));
      AddBlockParagraph(ABlocks, mbkBullet, Body);
      AInList := True;
      Continue;
    end;
    if AInList then
      AInList := False;
    if (Length(Trimmed) > Length('@think ')) and
       (Copy(Trimmed, 1, Length('@think ')) = '@think ') then begin
      Body := Trim(Copy(Trimmed, Length('@think ') + 1, MaxInt));
      AddBlockParagraph(ABlocks, mbkThinking, Body);
      Continue;
    end;
    if (Length(Trimmed) > Length('@tool ')) and
       (Copy(Trimmed, 1, Length('@tool ')) = '@tool ') then begin
      Body := Trim(Copy(Trimmed, Length('@tool ') + 1, MaxInt));
      AddBlockParagraph(ABlocks, mbkTool, '- ' + Body);
      Continue;
    end;
    AddBlockParagraph(ABlocks, mbkParagraph, Trimmed);
  end;
end;

procedure ParseMarkdownSource(const AMarkdown: string; ABlocks: TObjectList);
var
  Lines: TStringList;
  InFence, InList: Boolean;
begin
  ABlocks.Clear;
  Lines := TStringList.Create;
  try
    Lines.Text := AMarkdown;
    InFence := False;
    InList := False;
    ParseMarkdownLines(Lines, 0, InFence, InList, ABlocks);
  finally
    Lines.Free;
  end;
end;

function RunFontStyle(AStyle: TInlineStyle; ABase: TFontStyles): TFontStyles;
begin
  Result := ABase;
  case AStyle of
    isBold: Include(Result, fsBold);
    isItalic: Include(Result, fsItalic);
    isCode: ;
  end;
end;

procedure ConfigureBodyFont(ACanvas: TCanvas; AControl: TControl; ASize: Integer);
begin
  ACanvas.Font.Name := ThemedUiFontName;
  ACanvas.Font.Size := ASize;
  ACanvas.Font.Style := [];
end;

procedure ConfigureMonoFont(ACanvas: TCanvas; AControl: TControl; ASize: Integer);
begin
  ACanvas.Font.Name := ThemedMonospaceFontName;
  ACanvas.Font.Pitch := fpFixed;
  ACanvas.Font.Size := ASize;
end;

function LineHeightForCanvas(ACanvas: TCanvas; AControl: TControl): Integer;
begin
  Result := ACanvas.TextHeight('Ag') +
    ScaledLayoutMetric(AControl, LCA_MD_LINE_LEADING_BASE);
end;

procedure ApplyInlineRunFont(ACanvas: TCanvas; AStyle: TInlineStyle;
  const ABaseStyle: TFontStyles);
begin
  if AStyle = isCode then begin
    ConfigureMonoFont(ACanvas, nil, ACanvas.Font.Size);
    ACanvas.Font.Style := [];
  end else begin
    ACanvas.Font.Name := ThemedUiFontName;
    ACanvas.Font.Pitch := fpDefault;
    ACanvas.Font.Style := RunFontStyle(AStyle, ABaseStyle);
  end;
end;

procedure AppendLayoutFrag(var ALine: TLayoutLine; AX, AWidth: Integer;
  const AText: string; AStyle: TInlineStyle);
var
  N: Integer;
begin
  if AText = '' then Exit;
  N := Length(ALine.Frags);
  SetLength(ALine.Frags, N + 1);
  ALine.Frags[N].X := AX;
  ALine.Frags[N].Width := AWidth;
  ALine.Frags[N].Text := AText;
  ALine.Frags[N].Style := AStyle;
end;

procedure PushLayoutLine(var ALines: TLayoutLineArray; var ALine: TLayoutLine;
  var ACurX, ALineW, AY: Integer; AOriginX, ALineHeight: Integer);
var
  N: Integer;
begin
  ALine.Y := AY;
  ALine.Height := ALineHeight;
  N := Length(ALines);
  SetLength(ALines, N + 1);
  ALines[N] := ALine;
  AY := AY + ALineHeight;
  ACurX := AOriginX;
  ALineW := 0;
  SetLength(ALine.Frags, 0);
end;

procedure LayoutWrapRuns(ACanvas: TCanvas; var ALines: TLayoutLineArray;
  const ARuns: TInlineRunArray; AOriginX, AMaxWidth, ALineHeight: Integer;
  const ABaseStyle: TFontStyles; out AHeight: Integer);
var
  R, I, CurX, LineW, AY, WordStart: Integer;
  Style: TInlineStyle;
  SpaceW: Integer;
  CurLine: TLayoutLine;
  Ch: Char;

  procedure EmitWord(const AW: string);
  var
    WW, J, CW: Integer;
  begin
    if AW = '' then Exit;
    WW := ACanvas.TextWidth(AW);
    if (LineW > 0) and (LineW + WW > AMaxWidth) then
      PushLayoutLine(ALines, CurLine, CurX, LineW, AY, AOriginX, ALineHeight);
    if WW > AMaxWidth then begin
      for J := 1 to Length(AW) do begin
        CW := ACanvas.TextWidth(AW[J]);
        if (LineW > 0) and (LineW + CW > AMaxWidth) then
          PushLayoutLine(ALines, CurLine, CurX, LineW, AY, AOriginX, ALineHeight);
        AppendLayoutFrag(CurLine, CurX, CW, AW[J], Style);
        CurX := CurX + CW;
        LineW := LineW + CW;
      end;
    end else begin
      AppendLayoutFrag(CurLine, CurX, WW, AW, Style);
      CurX := CurX + WW;
      LineW := LineW + WW;
    end;
  end;

begin
  SetLength(ALines, 0);
  if AMaxWidth <= 0 then begin
    AHeight := ALineHeight;
    Exit;
  end;
  SetLength(CurLine.Frags, 0);
  CurX := AOriginX;
  LineW := 0;
  AY := 0;
  for R := 0 to High(ARuns) do begin
    Style := ARuns[R].Style;
    ApplyInlineRunFont(ACanvas, Style, ABaseStyle);
    SpaceW := ACanvas.TextWidth(' ');
    WordStart := 0;
    for I := 1 to Length(ARuns[R].Text) do begin
      Ch := ARuns[R].Text[I];
      if Ch <= ' ' then begin
        if WordStart > 0 then begin
          EmitWord(Copy(ARuns[R].Text, WordStart, I - WordStart));
          WordStart := 0;
        end;
        if (Ch = ' ') and (LineW > 0) then begin
          if LineW + SpaceW > AMaxWidth then
            PushLayoutLine(ALines, CurLine, CurX, LineW, AY, AOriginX, ALineHeight)
          else begin
            AppendLayoutFrag(CurLine, CurX, SpaceW, ' ', Style);
            CurX := CurX + SpaceW;
            LineW := LineW + SpaceW;
          end;
        end;
      end else if WordStart = 0 then
        WordStart := I;
    end;
    if WordStart > 0 then
      EmitWord(Copy(ARuns[R].Text, WordStart, MaxInt));
  end;
  if (LineW > 0) or (Length(ALines) = 0) then
    PushLayoutLine(ALines, CurLine, CurX, LineW, AY, AOriginX, ALineHeight);
  AHeight := AY;
end;

procedure LayoutCodeBlockLines(const ACode: string; ALeft, APad, ALineHeight: Integer;
  out ALines: TLayoutLineArray; out AHeight: Integer);
var
  Lines: TStringList;
  I, N: Integer;
begin
  ALines := nil;
  SetLength(ALines, 0);
  Lines := TStringList.Create;
  try
    if ACode = '' then
      Lines.Add('')
    else
      Lines.Text := ACode;
    N := Max(1, Lines.Count);
    SetLength(ALines, Lines.Count);
    for I := 0 to Lines.Count - 1 do begin
      ALines[I].Y := APad + I * ALineHeight;
      ALines[I].Height := ALineHeight;
      SetLength(ALines[I].Frags, 1);
      ALines[I].Frags[0].X := ALeft + APad;
      ALines[I].Frags[0].Width := 0;
      ALines[I].Frags[0].Text := Lines[I];
      ALines[I].Frags[0].Style := isCode;
    end;
    AHeight := 2 * APad + N * ALineHeight;
  finally
    Lines.Free;
  end;
end;

procedure LayoutAppendFragment(var L: TSelectLayoutState; const ARect: TRect;
  const AText: string);
var
  N: Integer;
begin
  if AText = '' then Exit;
  N := Length(L.Frags);
  SetLength(L.Frags, N + 1);
  L.Frags[N].StartIdx := Length(L.Plain);
  L.Frags[N].Text := AText;
  L.Frags[N].DocRect := ARect;
  L.Plain := L.Plain + AText;
end;

procedure LayoutAppendNewline(var L: TSelectLayoutState);
begin
  if (L.Plain <> '') and (L.Plain[Length(L.Plain)] <> #10) then
    L.Plain := L.Plain + LineEnding;
end;

procedure AppendBlockToSelection(ACanvas: TCanvas; var L: TSelectLayoutState;
  ABlk: TMarkdownBlockObj);
var
  Li, Fi, W, DocY: Integer;
  Line: TLayoutLine;
  Frag: TLayoutFrag;
  R: TRect;
begin
  if ABlk = nil then Exit;
  if ABlk.Kind in [mbkEmpty, mbkHRule] then Exit;
  if (ABlk.Kind = mbkBullet) and (ABlk.PrefixText <> '') then begin
    R := Rect(ABlk.PrefixX, ABlk.LayoutTop,
      ABlk.PrefixX + Max(1, ABlk.PrefixWidth),
      ABlk.LayoutTop + Max(1, ABlk.LineHeight));
    LayoutAppendFragment(L, R, ABlk.PrefixText);
  end;
  for Li := 0 to High(ABlk.Lines) do begin
    Line := ABlk.Lines[Li];
    DocY := ABlk.LayoutTop + Line.Y;
    for Fi := 0 to High(Line.Frags) do begin
      Frag := Line.Frags[Fi];
      W := Frag.Width;
      if W <= 0 then begin
        ApplyInlineRunFont(ACanvas, Frag.Style, []);
        W := ACanvas.TextWidth(Frag.Text);
        if W = 0 then
          W := ACanvas.TextWidth(' ');
      end;
      R := Rect(Frag.X, DocY, Frag.X + W, DocY + Line.Height);
      LayoutAppendFragment(L, R, Frag.Text);
    end;
  end;
  LayoutAppendNewline(L);
end;

procedure PaintLayoutLines(ACanvas: TCanvas; const ALines: TLayoutLineArray;
  ABlockTop, AScrollY, AViewTop, AViewBottom: Integer;
  ATextColor, ACodeBg: TColor; AFillInlineCode: Boolean;
  const ABaseStyle: TFontStyles);
var
  Li, Fi, ScreenY, DocY: Integer;
  Held: TLayoutLineArray;
  Line: TLayoutLine;
  Frag: TLayoutFrag;
  LastStyle: TInlineStyle;
  FontSet: Boolean;
  TR: TRect;
begin
  Held := ALines;
  FontSet := False;
  LastStyle := isNormal;
  ACanvas.Font.Color := ATextColor;
  for Li := 0 to High(Held) do begin
    Line := Held[Li];
    DocY := ABlockTop + Line.Y;
    if DocY + Line.Height < AViewTop then Continue;
    if DocY > AViewBottom then Break;
    ScreenY := DocY - AScrollY;
    for Fi := 0 to High(Line.Frags) do begin
      Frag := Line.Frags[Fi];
      if Frag.Text = '' then Continue;
      if (not FontSet) or (Frag.Style <> LastStyle) then begin
        ApplyInlineRunFont(ACanvas, Frag.Style, ABaseStyle);
        ACanvas.Font.Color := ATextColor;
        FontSet := True;
        LastStyle := Frag.Style;
      end;
      if AFillInlineCode and (Frag.Style = isCode) then begin
        TR := Rect(Frag.X, ScreenY, Frag.X + Frag.Width, ScreenY + Line.Height);
        ACanvas.Brush.Style := bsSolid;
        ACanvas.Brush.Color := ACodeBg;
        ACanvas.FillRect(TR);
      end;
      ACanvas.Brush.Style := bsClear;
      ACanvas.TextOut(Frag.X, ScreenY, Frag.Text);
    end;
  end;
end;

{ TLcaMarkdownView }

procedure TLcaMarkdownView.SetAutoScrollToEnd(AValue: Boolean);
begin
  if FAutoScrollToEnd = AValue then Exit;
  FAutoScrollToEnd := AValue;
  if FAutoScrollToEnd and FStickToBottom then
    ScrollToEnd;
end;

constructor TLcaMarkdownView.Create(AOwner: TComponent);
begin
  { Before inherited: theme/apply may Invalidate and Paint — FBlocks must exist. }
  FBlocks := TObjectList.Create(True);
  FSource := '';
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csCaptureMouse, csClickEvents, csDoubleClicks];
  TabStop := True;
  FAutoScrollToEnd := True;
  FStickToBottom := True;
  FScrollY := 0;
  FPlainText := '';
  FSelAnchor := 0;
  FSelCaret := 0;
  FSelActive := False;
  FTextSelDrag := False;
  FSelectLayoutValid := False;
  FParseInFence := False;
  FParseInList := False;
  FEphemeralThinkingVisible := False;
  FEphemeralThinkingBlock := nil;
  FPainting := False;
  FRelayoutQueued := False;
  FPendingRebuild := False;
  FPendingScrollToEnd := False;
end;

destructor TLcaMarkdownView.Destroy;
begin
  FRelayoutQueued := False;
  Application.RemoveAsyncCalls(Self);
  FreeAndNil(FEphemeralThinkingBlock);
  FreeAndNil(FBlocks);
  inherited Destroy;
end;

procedure TLcaMarkdownView.DoApplyThemeColors(const P: TThemePalette);
begin
  Color := P.Background;
  Font.Color := P.Text;
end;

procedure TLcaMarkdownView.PaintThemedClient(const ARect: TRect; const P: TThemePalette);
begin
  Canvas.Brush.Color := P.Background;
  Canvas.FillRect(ARect);
end;

function TLcaMarkdownView.ContentPad: Integer;
begin
  Result := ScaledLayoutMetric(Self, LCA_MD_PAD_BASE);
end;

function TLcaMarkdownView.ScrollbarThickness: Integer;
begin
  Result := ScaledThemedScrollbarThickness(Self);
end;

function TLcaMarkdownView.TextAreaWidth: Integer;
var
  W: Integer;
begin
  W := ClientWidth - 2 * ContentPad;
  if FShowVBar then
    Dec(W, ScrollbarThickness);
  if W < 1 then
    W := 1;
  Result := W;
end;

function TLcaMarkdownView.MaxScrollY: Integer;
begin
  Result := Max(0, FContentHeight - ClientHeight);
end;

procedure TLcaMarkdownView.ClampScroll;
begin
  if FScrollY < 0 then FScrollY := 0;
  if FScrollY > MaxScrollY then FScrollY := MaxScrollY;
end;

procedure TLcaMarkdownView.UpdateStickToBottomFromScroll;
begin
  if MaxScrollY <= 0 then begin
    FStickToBottom := True;
    Exit;
  end;
  if FScrollY >= MaxScrollY - LCA_MD_SCROLL_BOTTOM_EPS then
    FStickToBottom := True
  else
    FStickToBottom := False;
end;

procedure TLcaMarkdownView.ScrollToEnd;
begin
  FScrollY := MaxScrollY;
  ClampScroll;
end;

procedure TLcaMarkdownView.ApplyScrollPolicy(AForceStick: Boolean);
begin
  if AForceStick then
    FStickToBottom := True;
  if FAutoScrollToEnd and FStickToBottom then
    ScrollToEnd;
end;

function TLcaMarkdownView.ContentBusy: Boolean;
begin
  Result := FPainting or FLayoutGuard or (csDestroying in ComponentState);
end;

procedure TLcaMarkdownView.ScheduleDeferredRelayout;
begin
  if FRelayoutQueued then Exit;
  if csDestroying in ComponentState then Exit;
  FRelayoutQueued := True;
  Application.QueueAsyncCall(@DeferredRelayout, PtrInt(Self));
end;

procedure TLcaMarkdownView.ApplyDeferredContent;
begin
  if not FPendingRebuild then Exit;
  FPendingRebuild := False;
  RebuildBlocksFromSource;
end;

procedure TLcaMarkdownView.DeferredRelayout(Data: PtrInt);
begin
  FRelayoutQueued := False;
  if PtrInt(Self) <> Data then Exit;
  if csDestroying in ComponentState then Exit;
  if FPainting or FLayoutGuard then begin
    ScheduleDeferredRelayout;
    Exit;
  end;
  ApplyDeferredContent;
  RelayoutDocument;
  if FPendingScrollToEnd then begin
    FPendingScrollToEnd := False;
    ApplyScrollPolicy(True);
  end;
  Invalidate;
end;

procedure TLcaMarkdownView.RebuildBlocksFromSource;
var
  NewBlocks, OldBlocks: TObjectList;
begin
  NewBlocks := TObjectList.Create(True);
  ParseMarkdownSource(FSource, NewBlocks);
  OldBlocks := FBlocks;
  FBlocks := NewBlocks;
  OldBlocks.Free;
  FParseInFence := False;
  FParseInList := False;
  InvalidateSelectionLayout;
end;

procedure TLcaMarkdownView.ParseAppendToBlocks(const ALines: TStrings; AStartLineIndex: Integer);
begin
  ParseMarkdownLines(ALines, AStartLineIndex, FParseInFence, FParseInList, FBlocks);
end;

function TLcaMarkdownView.EphemeralThinkingVisible: Boolean;
begin
  Result := FEphemeralThinkingVisible;
end;

procedure TLcaMarkdownView.SetEphemeralThinkingVisible(AVisible: Boolean);
var
  Blk: TMarkdownBlockObj;
begin
  if FEphemeralThinkingVisible = AVisible then Exit;
  FEphemeralThinkingVisible := AVisible;
  if AVisible then begin
    if FEphemeralThinkingBlock = nil then begin
      Blk := TMarkdownBlockObj.Create;
      Blk.Kind := mbkThinking;
      Blk.ChatLabelRole := clrThinking;
      ParseInlineMarkdown(LCA_EPHEMERAL_THINKING_TEXT, Blk.Runs);
      FEphemeralThinkingBlock := Blk;
    end;
  end;
  ClearTextSelection;
  if ContentBusy then begin
    FNeedsLayout := True;
    ScheduleDeferredRelayout;
    Exit;
  end;
  RelayoutEphemeralTail;
  if FAutoScrollToEnd and FStickToBottom then
    ScrollToEnd;
  Invalidate;
end;

procedure TLcaMarkdownView.AppendMarkdownTail(const ADelta: string; AScrollToEndAfter: Boolean);
var
  Lines: TStringList;
  StartIdx: Integer;
begin
  if ADelta = '' then Exit;
  ClearTextSelection;
  FSource := FSource + ADelta;
  if AScrollToEndAfter then
    FPendingScrollToEnd := True;
  if ContentBusy then begin
    FPendingRebuild := True;
    FNeedsLayout := True;
    ScheduleDeferredRelayout;
    LcaUiProfileRecordMarkdownRender;
    Exit;
  end;
  StartIdx := FBlocks.Count;
  if StartIdx > 0 then
    Dec(StartIdx);
  Lines := TStringList.Create;
  try
    Lines.Text := ADelta;
    ParseAppendToBlocks(Lines, 0);
  finally
    Lines.Free;
  end;
  RelayoutDocumentFrom(StartIdx);
  ApplyScrollPolicy(AScrollToEndAfter);
  if AScrollToEndAfter then
    FPendingScrollToEnd := False;
  Invalidate;
  LcaUiProfileRecordMarkdownRender;
end;

procedure TLcaMarkdownView.RelayoutDocument;
begin
  RelayoutDocumentFrom(0);
end;

procedure TLcaMarkdownView.RelayoutDocumentFrom(AStartBlockIndex: Integer);
var
  Pass, Y, BodySize, LineH, CodePad, W, BulletInd, Pad, FromIdx: Integer;
  OldScroll: Integer;
  Blk: TMarkdownBlockObj;
  BlockLineH: Integer;

  procedure MeasureOneBlock(ABlk: TMarkdownBlockObj);
  var
    H: Integer;
    NewLines: TLayoutLineArray;
  begin
    if ABlk = nil then Exit;
    NewLines := nil;
    SetLength(NewLines, 0);
    ABlk.PrefixText := '';
    ABlk.PrefixWidth := 0;
    ABlk.PrefixX := Pad;
    ABlk.LineHeight := LineH;
    case ABlk.Kind of
      mbkEmpty:
        ABlk.CalculatedHeight := ScaledLayoutMetric(Self, LCA_MD_EMPTY_BLOCK_BASE);
      mbkHRule:
        ABlk.CalculatedHeight := ScaledLayoutMetric(Self, LCA_MD_HRULE_BLOCK_BASE);
      mbkCode:
        begin
          ConfigureMonoFont(Canvas, Self, BodySize);
          ABlk.LineHeight := LineHeightForCanvas(Canvas, Self);
          LayoutCodeBlockLines(ABlk.CodeText, Pad, CodePad, ABlk.LineHeight, NewLines, H);
          ABlk.CalculatedHeight := H;
          ConfigureBodyFont(Canvas, Self, BodySize);
        end;
      mbkHeading:
        begin
          Canvas.Font.Style := [fsBold];
          Canvas.Font.Size := BodySize + Max(0, 4 - ABlk.HeadingLevel);
          ABlk.LineHeight := LineHeightForCanvas(Canvas, Self);
          LayoutWrapRuns(Canvas, NewLines, ABlk.Runs, Pad, W,
            ABlk.LineHeight, [fsBold], H);
          ABlk.CalculatedHeight := H;
          ConfigureBodyFont(Canvas, Self, BodySize);
        end;
      mbkBullet:
        begin
          ABlk.PrefixText := LCA_MD_BULLET;
          ABlk.PrefixWidth := Canvas.TextWidth(LCA_MD_BULLET);
          LayoutWrapRuns(Canvas, NewLines, ABlk.Runs, Pad + BulletInd,
            W - BulletInd, LineH, [], H);
          ABlk.CalculatedHeight := H;
        end;
      mbkThinking:
        begin
          Canvas.Font.Style := [fsItalic];
          LayoutWrapRuns(Canvas, NewLines, ABlk.Runs, Pad, W, LineH, [fsItalic], H);
          ABlk.CalculatedHeight := H;
          ConfigureBodyFont(Canvas, Self, BodySize);
        end;
      mbkTool:
        begin
          Canvas.Font.Size := Max(8, BodySize - 1);
          BlockLineH := LineHeightForCanvas(Canvas, Self);
          ABlk.LineHeight := BlockLineH;
          LayoutWrapRuns(Canvas, NewLines, ABlk.Runs, Pad, W, BlockLineH, [], H);
          ABlk.CalculatedHeight := H;
          ConfigureBodyFont(Canvas, Self, BodySize);
        end;
      mbkParagraph:
        begin
          LayoutWrapRuns(Canvas, NewLines, ABlk.Runs, Pad, W, LineH, [], H);
          ABlk.CalculatedHeight := H;
        end;
    end;
    ABlk.Lines := NewLines;
  end;

  procedure MeasureBlocksFrom(AFromIndex: Integer);
  var
    BlockIdx: Integer;
    EphBlk: TMarkdownBlockObj;
  begin
    ConfigureBodyFont(Canvas, Self, BodySize);
    LineH := LineHeightForCanvas(Canvas, Self);
    if (AFromIndex > 0) and (AFromIndex <= FBlocks.Count) then begin
      Blk := TMarkdownBlockObj(FBlocks[AFromIndex - 1]);
      Y := Blk.LayoutTop + Blk.CalculatedHeight +
        ScaledLayoutMetric(Self, LCA_MD_LINE_EXTRA_BASE);
    end else
      Y := Pad;
    for BlockIdx := AFromIndex to FBlocks.Count - 1 do begin
      Blk := TMarkdownBlockObj(FBlocks[BlockIdx]);
      MeasureOneBlock(Blk);
      Blk.LayoutTop := Y;
      Y := Y + Blk.CalculatedHeight + ScaledLayoutMetric(Self, LCA_MD_LINE_EXTRA_BASE);
    end;
    if FEphemeralThinkingVisible and Assigned(FEphemeralThinkingBlock) then begin
      EphBlk := TMarkdownBlockObj(FEphemeralThinkingBlock);
      MeasureOneBlock(EphBlk);
      EphBlk.LayoutTop := Y;
      Y := Y + EphBlk.CalculatedHeight +
        ScaledLayoutMetric(Self, LCA_MD_LINE_EXTRA_BASE);
    end;
    FContentHeight := Y + Pad;
  end;

begin
  if not Assigned(FBlocks) or FLayoutGuard then Exit;
  if FPainting then begin
    FNeedsLayout := True;
    ScheduleDeferredRelayout;
    Exit;
  end;
  if AStartBlockIndex < 0 then
    AStartBlockIndex := 0;
  if AStartBlockIndex > FBlocks.Count then
    AStartBlockIndex := FBlocks.Count;
  if not HandleAllocated then begin
    FNeedsLayout := True;
    Exit;
  end;
  FLayoutGuard := True;
  FNeedsLayout := False;
  LcaUiProfileRecordMarkdownGetContentSize;
  OldScroll := FScrollY;
  BodySize := ThemedMarkdownBodyFontSize(Self);
  CodePad := ScaledLayoutMetric(Self, LCA_MD_CODE_PAD_BASE);
  BulletInd := ScaledLayoutMetric(Self, LCA_MD_BULLET_INDENT_BASE);
  Pad := ContentPad;
  FromIdx := AStartBlockIndex;
  if FromIdx = 0 then
    FShowVBar := False;
  for Pass := 0 to 1 do begin
    W := TextAreaWidth;
    FLayoutTextWidth := W;
    MeasureBlocksFrom(FromIdx);
    if FContentHeight <= ClientHeight then begin
      FShowVBar := False;
      Break;
    end;
    if FShowVBar then
      Break;
    FShowVBar := True;
    FromIdx := 0;
  end;
  ClampScroll;
  if (OldScroll <> FScrollY) and not (FAutoScrollToEnd and FStickToBottom) then
    ; // keep user scroll
  UpdateStickToBottomFromScroll;
  InvalidateSelectionLayout;
  FLayoutGuard := False;
end;

procedure TLcaMarkdownView.RelayoutEphemeralTail;
var
  FromIdx: Integer;
begin
  if not Assigned(FBlocks) then Exit;
  if (FBlocks.Count > 0) and FEphemeralThinkingVisible then
    FromIdx := FBlocks.Count - 1
  else
    FromIdx := FBlocks.Count;
  RelayoutDocumentFrom(FromIdx);
end;

procedure TLcaMarkdownView.ClearTextSelection;
begin
  FSelAnchor := 0;
  FSelCaret := 0;
  FSelActive := False;
  FTextSelDrag := False;
end;

procedure TLcaMarkdownView.InvalidateSelectionLayout;
begin
  FSelectLayoutValid := False;
end;

procedure TLcaMarkdownView.EnsureSelectionLayout;
begin
  if FSelectLayoutValid then Exit;
  BuildSelectionLayout;
  FSelectLayoutValid := True;
end;

procedure TLcaMarkdownView.BuildSelectionLayout;
var
  L: TSelectLayoutState;
  I: Integer;
  B: TMarkdownBlockObj;
  BodySize: Integer;
begin
  L.Plain := '';
  SetLength(L.Frags, 0);
  if not Assigned(FBlocks) or not HandleAllocated then begin
    FPlainText := '';
    SetLength(FSelectFrags, 0);
    Exit;
  end;
  BodySize := ThemedMarkdownBodyFontSize(Self);
  ConfigureBodyFont(Canvas, Self, BodySize);
  for I := 0 to FBlocks.Count - 1 do begin
    B := TMarkdownBlockObj(FBlocks[I]);
    if B = nil then Continue;
    if B.Kind = mbkCode then
      ConfigureMonoFont(Canvas, Self, BodySize)
    else if B.Kind = mbkHeading then begin
      Canvas.Font.Style := [fsBold];
      Canvas.Font.Size := BodySize + Max(0, 4 - B.HeadingLevel);
    end else if B.Kind = mbkThinking then
      Canvas.Font.Style := [fsItalic]
    else if B.Kind = mbkTool then
      Canvas.Font.Size := Max(8, BodySize - 1)
    else
      ConfigureBodyFont(Canvas, Self, BodySize);
    AppendBlockToSelection(Canvas, L, B);
    ConfigureBodyFont(Canvas, Self, BodySize);
  end;
  if FEphemeralThinkingVisible and Assigned(FEphemeralThinkingBlock) then begin
    B := TMarkdownBlockObj(FEphemeralThinkingBlock);
    Canvas.Font.Style := [fsItalic];
    AppendBlockToSelection(Canvas, L, B);
    ConfigureBodyFont(Canvas, Self, BodySize);
  end;
  FPlainText := L.Plain;
  FSelectFrags := L.Frags;
  if FSelActive then begin
    if FSelAnchor > Length(FPlainText) then
      ClearTextSelection
    else if FSelCaret > Length(FPlainText) then
      FSelCaret := Length(FPlainText);
  end;
end;

function TLcaMarkdownView.SelectionBounds(out ALo, AHi: Integer): Boolean;
begin
  if not FSelActive then
    Exit(False);
  ALo := FSelAnchor;
  AHi := FSelCaret;
  if ALo > AHi then begin
    ALo := FSelCaret;
    AHi := FSelAnchor;
  end;
  Result := True;
end;

function TLcaMarkdownView.SelectedPlainText: string;
var
  Lo, Hi: Integer;
begin
  EnsureSelectionLayout;
  if not SelectionBounds(Lo, Hi) or (Lo >= Hi) then
    Exit('');
  Result := Copy(FPlainText, Lo + 1, Hi - Lo);
end;

function TLcaMarkdownView.ClientPointToPlainIndex(AX, AY: Integer): Integer;
var
  DocX, DocY, I, J, Lo, Hi, Mid, W: Integer;
  F: TSelectFragRec;
  BestDist, Dist, DY: Integer;
  BestIdx: Integer;
begin
  EnsureSelectionLayout;
  if Length(FSelectFrags) = 0 then
    Exit(0);
  DocX := AX;
  DocY := AY + FScrollY;
  BestIdx := 0;
  BestDist := MaxInt;
  for I := 0 to High(FSelectFrags) do begin
    F := FSelectFrags[I];
    if PtInRect(F.DocRect, Point(DocX, DocY)) then begin
      if Length(F.Text) = 1 then
        Exit(F.StartIdx);
      Lo := 1;
      Hi := Length(F.Text);
      while Lo < Hi do begin
        Mid := (Lo + Hi) div 2;
        W := Canvas.TextWidth(Copy(F.Text, 1, Mid));
        if DocX < F.DocRect.Left + W then
          Hi := Mid
        else
          Lo := Mid + 1;
      end;
      J := Lo;
      if J > Length(F.Text) then
        J := Length(F.Text);
      Exit(F.StartIdx + J - 1);
    end;
    DY := DocY - ((F.DocRect.Top + F.DocRect.Bottom) div 2);
    Dist := Abs(DY) * 1000 + Abs(DocX - ((F.DocRect.Left + F.DocRect.Right) div 2));
    if Dist < BestDist then begin
      BestDist := Dist;
      if DocX <= F.DocRect.Left then
        BestIdx := F.StartIdx
      else if DocX >= F.DocRect.Right then
        BestIdx := F.StartIdx + Length(F.Text)
      else
        BestIdx := F.StartIdx + Length(F.Text) div 2;
    end;
  end;
  if BestIdx < 0 then
    BestIdx := 0;
  if BestIdx > Length(FPlainText) then
    BestIdx := Length(FPlainText);
  Result := BestIdx;
end;

procedure TLcaMarkdownView.PaintTextSelection(ACanvas: TCanvas; const P: TThemePalette);
var
  Lo, Hi, I, SelStartInFrag, SelEndInFrag, LeftW, RightW: Integer;
  F: TSelectFragRec;
  R: TRect;
  ViewTop, ViewBottom: Integer;
begin
  if not SelectionBounds(Lo, Hi) or (Lo >= Hi) then Exit;
  EnsureSelectionLayout;
  ViewTop := FScrollY;
  ViewBottom := FScrollY + ClientHeight;
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := P.AccentActive;
  ACanvas.Pen.Style := psClear;
  for I := 0 to High(FSelectFrags) do begin
    F := FSelectFrags[I];
    if (F.DocRect.Bottom < ViewTop) or (F.DocRect.Top > ViewBottom) then Continue;
    if (F.StartIdx + Length(F.Text) <= Lo) or (F.StartIdx >= Hi) then Continue;
    SelStartInFrag := Max(0, Lo - F.StartIdx);
    SelEndInFrag := Min(Length(F.Text), Hi - F.StartIdx);
    if SelStartInFrag >= SelEndInFrag then Continue;
    LeftW := 0;
    if SelStartInFrag > 0 then
      LeftW := ACanvas.TextWidth(Copy(F.Text, 1, SelStartInFrag));
    RightW := ACanvas.TextWidth(Copy(F.Text, 1, SelEndInFrag));
    R := F.DocRect;
    R.Left := R.Left + LeftW;
    R.Right := F.DocRect.Left + RightW;
    Dec(R.Top, FScrollY);
    Dec(R.Bottom, FScrollY);
    ACanvas.FillRect(R);
  end;
  ACanvas.Pen.Style := psSolid;
  ACanvas.Brush.Style := bsClear;
end;

procedure TLcaMarkdownView.CopySelectionToClipboard;
var
  S: string;
begin
  S := SelectedPlainText;
  if S = '' then Exit;
  Clipboard.AsText := S;
end;

procedure TLcaMarkdownView.SelectAllText;
begin
  EnsureSelectionLayout;
  FSelAnchor := 0;
  FSelCaret := Length(FPlainText);
  FSelActive := FSelCaret > 0;
  Invalidate;
end;

procedure TLcaMarkdownView.SelectWordAt(AIndex: Integer);
var
  Lo, Hi: Integer;
begin
  EnsureSelectionLayout;
  if FPlainText = '' then Exit;
  if AIndex < 0 then AIndex := 0;
  if AIndex > Length(FPlainText) then AIndex := Length(FPlainText);
  Lo := AIndex + 1;
  Hi := AIndex + 1;
  while (Lo > 1) and (FPlainText[Lo - 1] > ' ') and (FPlainText[Lo - 1] <> #10) do
    Dec(Lo);
  while (Hi <= Length(FPlainText)) and (FPlainText[Hi] > ' ') and (FPlainText[Hi] <> #10) do
    Inc(Hi);
  FSelAnchor := Lo - 1;
  FSelCaret := Hi - 1;
  FSelActive := FSelCaret > FSelAnchor;
  Invalidate;
end;

procedure TLcaMarkdownView.WMCopy(var Msg: TLMessage);
begin
  CopySelectionToClipboard;
  Msg.Result := 1;
end;

procedure TLcaMarkdownView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if (Key = Ord('C')) and (ssCtrl in Shift) then begin
    CopySelectionToClipboard;
    Key := 0;
  end else if (Key = Ord('A')) and (ssCtrl in Shift) then begin
    SelectAllText;
    Key := 0;
  end;
end;

procedure TLcaMarkdownView.Clear;
var
  Empty, OldBlocks: TObjectList;
begin
  FSource := '';
  FParseInFence := False;
  FParseInList := False;
  FEphemeralThinkingVisible := False;
  FPendingRebuild := True;
  ClearTextSelection;
  if ContentBusy then begin
    FNeedsLayout := True;
    ScheduleDeferredRelayout;
    Exit;
  end;
  FPendingRebuild := False;
  Empty := TObjectList.Create(True);
  OldBlocks := FBlocks;
  FBlocks := Empty;
  OldBlocks.Free;
  FContentHeight := ContentPad * 2;
  FScrollY := 0;
  FStickToBottom := True;
  FNeedsLayout := False;
  InvalidateSelectionLayout;
  Invalidate;
end;

procedure TLcaMarkdownView.SetMarkdownText(const AText: string);
begin
  ClearTextSelection;
  FEphemeralThinkingVisible := False;
  FSource := AText;
  FPendingRebuild := True;
  if ContentBusy then begin
    FNeedsLayout := True;
    ScheduleDeferredRelayout;
    LcaUiProfileRecordMarkdownRender;
    Exit;
  end;
  FPendingRebuild := False;
  RebuildBlocksFromSource;
  RelayoutDocument;
  ApplyScrollPolicy(False);
  Invalidate;
  LcaUiProfileRecordMarkdownRender;
end;

procedure TLcaMarkdownView.AppendChunk(const AText: string);
begin
  AppendMarkdownTail(AText, False);
end;

procedure TLcaMarkdownView.SetMarkdown(const AMarkdown: string; AScrollToEndAfterRender: Boolean);
begin
  if AScrollToEndAfterRender then
    FPendingScrollToEnd := True;
  SetMarkdownText(AMarkdown);
  if AScrollToEndAfterRender then begin
    if ContentBusy then
      Exit;
    FPendingScrollToEnd := False;
    ApplyScrollPolicy(True);
  end;
end;

procedure TLcaMarkdownView.ScrollToEndIfAutoScroll;
begin
  ApplyScrollPolicy(True);
  Invalidate;
end;

procedure TLcaMarkdownView.RequestRender;
begin
  if ContentBusy then begin
    FNeedsLayout := True;
    ScheduleDeferredRelayout;
    Exit;
  end;
  RelayoutDocument;
  Invalidate;
end;

function TLcaMarkdownView.VerticalTrackRect: TRect;
var
  BarW: Integer;
begin
  BarW := ScrollbarThickness;
  Result := Rect(ClientWidth - BarW, 0, ClientWidth, ClientHeight);
end;

function TLcaMarkdownView.VerticalThumbRect: TRect;
var
  TrackR: TRect;
  ThumbH, ThumbY, MinThumb, MaxS, ViewH: Integer;
begin
  TrackR := VerticalTrackRect;
  Result := TrackR;
  if not FShowVBar then Exit;
  MaxS := MaxScrollY;
  if MaxS <= 0 then Exit;
  ViewH := ClientHeight;
  MinThumb := Max(ScrollbarThickness, ScaledLayoutMetric(Self, 20));
  ThumbH := Max(MinThumb, MulDiv(TrackR.Height, ViewH, FContentHeight));
  if ThumbH > TrackR.Height then
    ThumbH := TrackR.Height;
  ThumbY := TrackR.Top;
  if TrackR.Height > ThumbH then
    ThumbY := TrackR.Top + MulDiv(TrackR.Height - ThumbH, FScrollY, MaxS);
  Result := Rect(TrackR.Left + 2, ThumbY, TrackR.Right - 1, ThumbY + ThumbH);
end;

function TLcaMarkdownView.HitOnVerticalThumb(X, Y: Integer): Boolean;
begin
  if not FShowVBar then Exit(False);
  Result := PtInRect(VerticalThumbRect, Point(X, Y));
end;

function TLcaMarkdownView.HitInVerticalTrack(X, Y: Integer): Boolean;
begin
  if not FShowVBar then Exit(False);
  Result := PtInRect(VerticalTrackRect, Point(X, Y));
end;

procedure TLcaMarkdownView.ScrollByDelta(ADeltaY: Integer);
begin
  if ADeltaY = 0 then Exit;
  FScrollY := FScrollY + ADeltaY;
  ClampScroll;
  UpdateStickToBottomFromScroll;
  Invalidate;
end;

procedure TLcaMarkdownView.ScheduleWheelFlush;
begin
  if FWheelFlushQueued then Exit;
  FWheelFlushQueued := True;
  Application.QueueAsyncCall(@WheelFlush, PtrInt(Self));
end;

procedure TLcaMarkdownView.WheelFlush(Data: PtrInt);
var
  Delta: Integer;
begin
  FWheelFlushQueued := False;
  if PtrInt(Self) <> Data then Exit;
  Delta := FWheelAccumY;
  FWheelAccumY := 0;
  if Delta <> 0 then
    ScrollByDelta(-Delta);
end;

procedure TLcaMarkdownView.PaintScrollbarTrack(ACanvas: TCanvas; const ARect: TRect;
  const P: TThemePalette);
begin
  PaintThemedScrollbarTrack(ACanvas, ARect, P.SurfaceAlt);
end;

procedure TLcaMarkdownView.PaintScrollbarThumb(ACanvas: TCanvas; const ARect: TRect;
  const P: TThemePalette);
var
  ThumbColor: TColor;
begin
  ThumbColor := BlendRgb(P.Border, P.TextMuted, 0.35);
  PaintThemedScrollbarThumb(ACanvas, ARect, ThumbColor, False);
end;

procedure TLcaMarkdownView.PaintScrollbar(const P: TThemePalette);
var
  TrackR, ThumbR: TRect;
begin
  if not FShowVBar then Exit;
  TrackR := VerticalTrackRect;
  PaintScrollbarTrack(Canvas, TrackR, P);
  ThumbR := VerticalThumbRect;
  if (ThumbR.Right > ThumbR.Left) and (ThumbR.Bottom > ThumbR.Top) then
    PaintScrollbarThumb(Canvas, ThumbR, P);
end;

function TLcaMarkdownView.FirstVisibleBlockIndex(AViewTop: Integer): Integer;
var
  Lo, Hi, Mid: Integer;
  B: TMarkdownBlockObj;
begin
  Result := 0;
  if not Assigned(FBlocks) then Exit;
  Result := FBlocks.Count;
  if FBlocks.Count = 0 then Exit;
  Lo := 0;
  Hi := FBlocks.Count - 1;
  while Lo <= Hi do begin
    Mid := (Lo + Hi) div 2;
    B := TMarkdownBlockObj(FBlocks[Mid]);
    if (B <> nil) and (B.LayoutTop + B.CalculatedHeight < AViewTop) then
      Lo := Mid + 1
    else begin
      Result := Mid;
      Hi := Mid - 1;
    end;
  end;
end;

procedure TLcaMarkdownView.PaintDocument(ACanvas: TCanvas; const P: TThemePalette);
var
  I, X, Y, W, BodySize, LineH: Integer;
  B: TMarkdownBlockObj;
  ViewTop, ViewBottom: Integer;
  BlockRect, VisRect: TRect;
  TextColor: TColor;
  SavedClip: TRect;
  SavedBrush: TBrushStyle;
begin
  if not Assigned(FBlocks) then Exit;
  BodySize := ThemedMarkdownBodyFontSize(Self);
  ConfigureBodyFont(ACanvas, Self, BodySize);
  LineH := LineHeightForCanvas(ACanvas, Self);
  W := TextAreaWidth;
  X := ContentPad;
  ViewTop := FScrollY - LineH;
  ViewBottom := FScrollY + ClientHeight;
  SavedClip := ACanvas.ClipRect;
  SavedBrush := ACanvas.Brush.Style;
  ACanvas.ClipRect := ClientRect;
  PaintTextSelection(ACanvas, P);
  I := FirstVisibleBlockIndex(FScrollY);
  while I < FBlocks.Count do begin
    B := TMarkdownBlockObj(FBlocks[I]);
    Inc(I);
    if B = nil then Continue;
    if B.LayoutTop > ViewBottom then Break;
    if B.LayoutTop + B.CalculatedHeight < ViewTop then Continue;
    Y := B.LayoutTop - FScrollY;
    case B.Kind of
      mbkEmpty:
        Continue;
      mbkHRule:
        begin
          ACanvas.Pen.Color := P.Border;
          BlockRect := Rect(X, Y + B.CalculatedHeight div 2,
            X + W, Y + B.CalculatedHeight div 2 + 1);
          ACanvas.MoveTo(BlockRect.Left, BlockRect.Top);
          ACanvas.LineTo(BlockRect.Right, BlockRect.Top);
        end;
      mbkCode:
        begin
          BlockRect := Rect(X, Y, X + W, Y + B.CalculatedHeight);
          VisRect := Rect(0, 0, 0, 0);
          if IntersectRect(VisRect, BlockRect, ClientRect) then begin
            ACanvas.Brush.Style := bsSolid;
            ACanvas.Brush.Color := P.SurfaceAlt;
            ACanvas.FillRect(VisRect);
            ACanvas.Pen.Color := P.Border;
            ACanvas.Rectangle(BlockRect);
          end;
          ConfigureMonoFont(ACanvas, Self, BodySize);
          PaintLayoutLines(ACanvas, B.Lines, B.LayoutTop, FScrollY, ViewTop, ViewBottom,
            P.Text, P.SurfaceAlt, False, []);
          ConfigureBodyFont(ACanvas, Self, BodySize);
        end;
      mbkHeading:
        begin
          TextColor := ChatLabelTextColor(P, B.ChatLabelRole);
          ACanvas.Font.Style := [fsBold];
          ACanvas.Font.Size := BodySize + Max(0, 4 - B.HeadingLevel);
          ACanvas.Font.Color := TextColor;
          PaintLayoutLines(ACanvas, B.Lines, B.LayoutTop, FScrollY, ViewTop, ViewBottom,
            TextColor, P.SurfaceAlt, True, [fsBold]);
          ConfigureBodyFont(ACanvas, Self, BodySize);
        end;
      mbkBullet:
        begin
          TextColor := P.Text;
          ACanvas.Font.Color := TextColor;
          ACanvas.Brush.Style := bsClear;
          ACanvas.TextOut(B.PrefixX, Y, B.PrefixText);
          PaintLayoutLines(ACanvas, B.Lines, B.LayoutTop, FScrollY, ViewTop, ViewBottom,
            TextColor, P.SurfaceAlt, True, []);
        end;
      mbkThinking:
        begin
          TextColor := ChatLabelTextColor(P, B.ChatLabelRole);
          ACanvas.Font.Style := [fsItalic];
          ACanvas.Font.Color := TextColor;
          PaintLayoutLines(ACanvas, B.Lines, B.LayoutTop, FScrollY, ViewTop, ViewBottom,
            TextColor, P.SurfaceAlt, True, [fsItalic]);
          ConfigureBodyFont(ACanvas, Self, BodySize);
        end;
      mbkTool:
        begin
          TextColor := ChatLabelTextColor(P, B.ChatLabelRole);
          ACanvas.Font.Size := Max(8, BodySize - 1);
          ACanvas.Font.Color := TextColor;
          PaintLayoutLines(ACanvas, B.Lines, B.LayoutTop, FScrollY, ViewTop, ViewBottom,
            TextColor, P.SurfaceAlt, True, []);
          ConfigureBodyFont(ACanvas, Self, BodySize);
        end;
      mbkParagraph:
        begin
          TextColor := P.Text;
          ACanvas.Font.Color := TextColor;
          PaintLayoutLines(ACanvas, B.Lines, B.LayoutTop, FScrollY, ViewTop, ViewBottom,
            TextColor, P.SurfaceAlt, True, []);
        end;
    end;
  end;
  if FEphemeralThinkingVisible and Assigned(FEphemeralThinkingBlock) then begin
    B := TMarkdownBlockObj(FEphemeralThinkingBlock);
    if not ((B.LayoutTop + B.CalculatedHeight < ViewTop) or (B.LayoutTop > ViewBottom)) then begin
      TextColor := ChatLabelTextColor(P, B.ChatLabelRole);
      ACanvas.Font.Style := [fsItalic];
      ACanvas.Font.Color := TextColor;
      PaintLayoutLines(ACanvas, B.Lines, B.LayoutTop, FScrollY, ViewTop, ViewBottom,
        TextColor, P.SurfaceAlt, True, [fsItalic]);
      ConfigureBodyFont(ACanvas, Self, BodySize);
    end;
  end;
  ACanvas.Brush.Style := SavedBrush;
  ACanvas.ClipRect := SavedClip;
end;

procedure TLcaMarkdownView.CreateWnd;
begin
  inherited CreateWnd;
  if FNeedsLayout or (FSource <> '') then
    RelayoutDocument;
end;

procedure TLcaMarkdownView.Loaded;
begin
  inherited Loaded;
  if FNeedsLayout or (FSource <> '') then begin
    RelayoutDocument;
    Invalidate;
  end;
end;

procedure TLcaMarkdownView.Paint;
var
  P: TThemePalette;
  T0, Elapsed: QWord;
begin
  T0 := GetTickCount64;
  P := EffectivePalette;
  FPainting := True;
  try
    PaintThemedClient(ClientRect, P);
    if LcaInDesignContext(Self) and (csDesigning in ComponentState) then begin
      Canvas.Font.Color := P.TextMuted;
      Canvas.Brush.Style := bsClear;
      Canvas.TextOut(4, 4, ClassName);
    end else if not FLayoutGuard then begin
      PaintDocument(Canvas, P);
      PaintScrollbar(P);
    end;
  finally
    FPainting := False;
  end;
  if FNeedsLayout then
    ScheduleDeferredRelayout;
  Elapsed := GetTickCount64 - T0;
  LcaUiProfileRecordThemedPaint(Elapsed);
end;

procedure TLcaMarkdownView.Resize;
begin
  inherited Resize;
  if ContentBusy then begin
    FNeedsLayout := True;
    ScheduleDeferredRelayout;
    Exit;
  end;
  RelayoutDocument;
  Invalidate;
end;

procedure TLcaMarkdownView.ChangeScale(M, D: Integer);
begin
  inherited ChangeScale(M, D);
  if ContentBusy then begin
    FNeedsLayout := True;
    ScheduleDeferredRelayout;
    Exit;
  end;
  RelayoutDocument;
end;

procedure TLcaMarkdownView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  TrackR: TRect;
  MaxS, ThumbH, RelY: Integer;
  ThumbR: TRect;
  Idx: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  if HitOnVerticalThumb(X, Y) then begin
    FDragScrollActive := True;
    ThumbR := VerticalThumbRect;
    FDragThumbOffset := Y - ThumbR.Top;
    SetCapture(Self.Handle);
    Exit;
  end;
  if HitInVerticalTrack(X, Y) then begin
    TrackR := VerticalTrackRect;
    MaxS := MaxScrollY;
    ThumbH := VerticalThumbRect.Bottom - VerticalThumbRect.Top;
    RelY := Y - TrackR.Top - ThumbH div 2;
    if TrackR.Height > ThumbH then
      FScrollY := MulDiv(RelY, MaxS, TrackR.Height - ThumbH)
    else
      FScrollY := 0;
    ClampScroll;
    UpdateStickToBottomFromScroll;
    Invalidate;
    Exit;
  end;
  if not (FShowVBar and HitInVerticalTrack(X, Y)) then begin
    SetFocus;
    Idx := ClientPointToPlainIndex(X, Y);
    if ssDouble in Shift then
      SelectWordAt(Idx)
    else begin
      FSelAnchor := Idx;
      FSelCaret := Idx;
      FSelActive := True;
      FTextSelDrag := True;
      SetCapture(Handle);
      Invalidate;
    end;
  end;
end;

procedure TLcaMarkdownView.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  TrackR: TRect;
  MaxS, ThumbH, NewTop: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if FTextSelDrag then begin
    FSelCaret := ClientPointToPlainIndex(X, Y);
    Invalidate;
    Exit;
  end;
  if not FDragScrollActive then Exit;
  TrackR := VerticalTrackRect;
  MaxS := MaxScrollY;
  ThumbH := VerticalThumbRect.Bottom - VerticalThumbRect.Top;
  NewTop := Y - FDragThumbOffset;
  if TrackR.Height > ThumbH then begin
    if NewTop < TrackR.Top then NewTop := TrackR.Top;
    if NewTop > TrackR.Bottom - ThumbH then NewTop := TrackR.Bottom - ThumbH;
    FScrollY := MulDiv(NewTop - TrackR.Top, MaxS, TrackR.Height - ThumbH);
  end;
  ClampScroll;
  UpdateStickToBottomFromScroll;
  Invalidate;
end;

procedure TLcaMarkdownView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if FTextSelDrag then begin
    FTextSelDrag := False;
    FSelCaret := ClientPointToPlainIndex(X, Y);
    if GetCapture = Handle then
      SetCapture(0);
    Invalidate;
  end;
  if FDragScrollActive then begin
    FDragScrollActive := False;
    if GetCapture = Handle then
      SetCapture(0);
  end;
end;

function TLcaMarkdownView.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
var
  Step: Integer;
begin
  Step := ScaledLayoutMetric(Self, 40);
  FWheelAccumY := FWheelAccumY + MulDiv(WheelDelta, Step, 120);
  ScheduleWheelFlush;
  Result := True;
end;

end.
