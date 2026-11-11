unit uWebContentExtract;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uWebFetchTypes;

function ExtractWebContent(const Body: RawByteString; const ContentType: string;
  const OutputFormat: string; MaxLength: Integer; out Title: string;
  out Content: string; out Truncated: Boolean;
  out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;

implementation

uses
  Classes, StrUtils, DOM, DOM_HTML, SAX_HTML, htmldefs;

function MimeTypeOnly(const ContentType: string): string;
var
  P: SizeInt;
  S: string;
begin
  S := LowerCase(Trim(ContentType));
  P := Pos(';', S);
  if P > 0 then
    S := Trim(Copy(S, 1, P - 1));
  Result := S;
end;

function CharsetFromContentType(const ContentType: string): string;
var
  L, Key, Val: string;
  Parts: TStringArray;
  I, Eq: SizeInt;
begin
  Result := '';
  Parts := ContentType.Split([';']);
  for I := 0 to High(Parts) do
  begin
    L := Trim(Parts[I]);
    Eq := Pos('=', L);
    if Eq > 0 then
    begin
      Key := LowerCase(Trim(Copy(L, 1, Eq - 1)));
      Val := Trim(Copy(L, Eq + 1, MaxInt));
      if (Length(Val) >= 2) and ((Val[1] = '"') and (Val[Length(Val)] = '"')) then
        Val := Copy(Val, 2, Length(Val) - 2);
      if Key = 'charset' then
        Exit(Val);
    end;
  end;
end;

function DecodeBodyToUtf8(const Body: RawByteString; const Charset: string): string;
var
  Enc: string;
begin
  if Length(Body) = 0 then Exit('');
  Enc := LowerCase(Trim(Charset));
  if (Enc <> '') and (Enc <> 'utf-8') and (Enc <> 'utf8') then
  begin
    { Non-UTF-8 charsets are rare for modern web; best-effort UTF-8 decode. }
  end;
  Result := UTF8ToString(Body);
end;

function TryReadHtmlIntoDocument(Doc: THTMLDocument; Stream: TStream): Boolean;
begin
  Result := False;
  try
    ReadHTMLFile(Doc, Stream);
    Result := True;
  except
    on E: EDOMError do ;
    on E: Exception do ;
  end;
end;

function StripHtmlTagsRough(const HtmlUtf8: string): string;
var
  I: Integer;
  InTag: Boolean;
  C: Char;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    InTag := False;
    for I := 1 to Length(HtmlUtf8) do begin
      C := HtmlUtf8[I];
      if C = '<' then
        InTag := True
      else if C = '>' then
        InTag := False
      else if not InTag then
        SB.Append(C);
    end;
    Result := Trim(SB.ToString);
  finally
    SB.Free;
  end;
end;

function ExtractTitleFromHtmlRough(const HtmlUtf8: string): string;
var
  L, R, P: SizeInt;
  Tag: string;
begin
  Result := '';
  L := Pos('<title', LowerCase(HtmlUtf8));
  if L = 0 then Exit;
  P := PosEx('>', HtmlUtf8, L);
  if P = 0 then Exit;
  R := PosEx('</title>', LowerCase(HtmlUtf8), P + 1);
  if R = 0 then Exit;
  Tag := Copy(HtmlUtf8, P + 1, R - P - 1);
  Result := Trim(StripHtmlTagsRough(Tag));
end;

function NodeNameLower(N: TDOMNode): string;
begin
  if N is TDOMElement then
    Result := LowerCase(TDOMElement(N).TagName)
  else
    Result := '';
end;

function ShouldSkipTag(const Tag: string): Boolean;
begin
  Result := (Tag = 'script') or (Tag = 'style') or (Tag = 'nav') or (Tag = 'footer') or
    (Tag = 'aside') or (Tag = 'noscript') or (Tag = 'iframe') or (Tag = 'svg') or
    (Tag = 'form') or (Tag = 'header');
end;

function NodeHasVisibleText(N: TDOMNode): Boolean;
begin
  Result := (N <> nil) and (Trim(N.TextContent) <> '');
end;

function FindContentRoot(Doc: THTMLDocument): TDOMNode;
var
  List: TDOMNodeList;
  I: Integer;
  N: TDOMElement;
  Role: string;
begin
  Result := Doc;
  List := Doc.GetElementsByTagName('main');
  if (List <> nil) and (List.Length > 0) and NodeHasVisibleText(List.Item[0]) then
    Exit(List.Item[0]);
  List := Doc.GetElementsByTagName('article');
  if (List <> nil) and (List.Length > 0) and NodeHasVisibleText(List.Item[0]) then
    Exit(List.Item[0]);
  List := Doc.GetElementsByTagName('*');
  if List <> nil then
    for I := 0 to List.Length - 1 do
      if List.Item[I] is TDOMElement then
      begin
        N := TDOMElement(List.Item[I]);
        Role := LowerCase(N.GetAttribute('role'));
        if (Role = 'main') and NodeHasVisibleText(N) then
          Exit(N);
      end;
  List := Doc.GetElementsByTagName('body');
  if (List <> nil) and (List.Length > 0) and NodeHasVisibleText(List.Item[0]) then
    Exit(List.Item[0]);
  if Doc.DocumentElement <> nil then
    Exit(Doc.DocumentElement);
  Result := Doc;
end;

procedure AppendText(var OutText: string; const S: string);
begin
  if S = '' then Exit;
  if (OutText <> '') and (not (OutText[Length(OutText)] in [#10, #13, ' '])) and
     (not (S[1] in [#10, #13, ' '])) then
    OutText := OutText + ' ';
  OutText := OutText + S;
end;

procedure RenderNode(N: TDOMNode; var OutMd: string; InPre: Boolean; Depth: Integer);
var
  I: Integer;
  Child: TDOMNode;
  Tag, Href, Text: string;
  Level: Integer;
begin
  if N = nil then Exit;
  if N.NodeType = TEXT_NODE then
  begin
    Text := Trim(N.TextContent);
    if Text <> '' then
    begin
      if InPre then
        OutMd := OutMd + Text
      else
        AppendText(OutMd, Text);
    end;
    Exit;
  end;
  if not (N is TDOMElement) then
  begin
    for I := 0 to N.ChildNodes.Length - 1 do
      RenderNode(N.ChildNodes.Item[I], OutMd, InPre, Depth);
    Exit;
  end;

  Tag := NodeNameLower(N);
  if ShouldSkipTag(Tag) then
    Exit;

  if Tag = 'title' then
    Exit;

  if Tag = 'br' then
  begin
    OutMd := OutMd + LineEnding;
    Exit;
  end;

  if Tag = 'pre' then
  begin
    OutMd := OutMd + LineEnding + '```' + LineEnding + Trim(N.TextContent) +
      LineEnding + '```' + LineEnding;
    Exit;
  end;

  if Tag = 'code' then
  begin
    Text := Trim(N.TextContent);
    if Text <> '' then
      OutMd := OutMd + '`' + Text + '`';
    Exit;
  end;

  if (Tag = 'h1') or (Tag = 'h2') or (Tag = 'h3') or (Tag = 'h4') or
     (Tag = 'h5') or (Tag = 'h6') then
  begin
    Level := StrToIntDef(Copy(Tag, 2, 1), 1);
    OutMd := OutMd + LineEnding + StringOfChar('#', Level) + ' ' +
      Trim(N.TextContent) + LineEnding + LineEnding;
    Exit;
  end;

  if Tag = 'p' then
  begin
    OutMd := OutMd + LineEnding;
    for I := 0 to N.ChildNodes.Length - 1 do
      RenderNode(N.ChildNodes.Item[I], OutMd, False, Depth);
    OutMd := OutMd + LineEnding;
    Exit;
  end;

  if (Tag = 'ul') or (Tag = 'ol') then
  begin
    for I := 0 to N.ChildNodes.Length - 1 do
    begin
      Child := N.ChildNodes.Item[I];
      if NodeNameLower(Child) = 'li' then
      begin
        OutMd := OutMd + LineEnding + '- ' + Trim(Child.TextContent);
        RenderNode(Child, OutMd, False, Depth + 1);
      end;
    end;
    OutMd := OutMd + LineEnding;
    Exit;
  end;

  if Tag = 'a' then
  begin
    Href := TDOMElement(N).GetAttribute('href');
    Text := Trim(N.TextContent);
    if Text = '' then Text := Href;
    if Href <> '' then
      OutMd := OutMd + '[' + Text + '](' + Href + ')'
    else
      AppendText(OutMd, Text);
    Exit;
  end;

  for I := 0 to N.ChildNodes.Length - 1 do
    RenderNode(N.ChildNodes.Item[I], OutMd, InPre, Depth);
end;

function RoughExtractFromBody(const HtmlUtf8: string): string;
var
  L, R, OpenEnd: SizeInt;
  LowerHtml: string;
begin
  Result := '';
  LowerHtml := LowerCase(HtmlUtf8);
  L := Pos('<body', LowerHtml);
  if L = 0 then
    Exit;
  OpenEnd := PosEx('>', HtmlUtf8, L);
  if OpenEnd = 0 then
    Exit;
  R := PosEx('</body>', LowerHtml, OpenEnd + 1);
  if R = 0 then
    Exit;
  Result := StripHtmlTagsRough(Copy(HtmlUtf8, OpenEnd + 1, R - OpenEnd - 1));
end;

function HtmlToMarkdown(const HtmlUtf8: string): string;
var
  Doc: THTMLDocument;
  Stream: TStringStream;
  Root: TDOMNode;
begin
  Result := '';
  Doc := THTMLDocument.Create;
  Stream := TStringStream.Create(HtmlUtf8, TEncoding.UTF8);
  try
    if TryReadHtmlIntoDocument(Doc, Stream) then begin
      Root := FindContentRoot(Doc);
      RenderNode(Root, Result, False, 0);
      if Trim(Result) = '' then
        Result := StripHtmlTagsRough(HtmlUtf8);
    end else
      Result := StripHtmlTagsRough(HtmlUtf8);
  finally
    Stream.Free;
    Doc.Free;
  end;
  Result := Trim(Result);
  if (Result = '') and (Trim(HtmlUtf8) <> '') then
  begin
    Result := Trim(RoughExtractFromBody(HtmlUtf8));
    if Result = '' then
      Result := Trim(StripHtmlTagsRough(HtmlUtf8));
  end;
end;

function ExtractTitleFromHtml(const HtmlUtf8: string): string;
var
  Doc: THTMLDocument;
  Stream: TStringStream;
  TitleNode: TDOMNodeList;
begin
  Result := '';
  Doc := THTMLDocument.Create;
  Stream := TStringStream.Create(HtmlUtf8, TEncoding.UTF8);
  try
    if TryReadHtmlIntoDocument(Doc, Stream) then begin
      TitleNode := Doc.GetElementsByTagName('title');
      if (TitleNode <> nil) and (TitleNode.Length > 0) then
        Result := Trim(TitleNode.Item[0].TextContent);
      if Result = '' then begin
        TitleNode := Doc.GetElementsByTagName('h1');
        if (TitleNode <> nil) and (TitleNode.Length > 0) then
          Result := Trim(TitleNode.Item[0].TextContent);
      end;
    end else
      Result := ExtractTitleFromHtmlRough(HtmlUtf8);
  finally
    Stream.Free;
    Doc.Free;
  end;
  if Result = '' then
    Result := ExtractTitleFromHtmlRough(HtmlUtf8);
end;

function ApplyMaxLength(const S: string; MaxLength: Integer; out Truncated: Boolean): string;
begin
  Truncated := False;
  if MaxLength <= 0 then
    Exit(S);
  if Length(S) <= MaxLength then
    Exit(S);
  Truncated := True;
  Result := Copy(S, 1, MaxLength);
end;

function ExtractWebContent(const Body: RawByteString; const ContentType: string;
  const OutputFormat: string; MaxLength: Integer; out Title: string;
  out Content: string; out Truncated: Boolean;
  out ErrKind: TWebFetchErrorKind; out ErrMsg: string): Boolean;
var
  Mime, Fmt, Utf8Text, Charset: string;
begin
  Result := False;
  Title := '';
  Content := '';
  Truncated := False;
  ErrKind := wfekNone;
  ErrMsg := '';
  Mime := MimeTypeOnly(ContentType);
  Fmt := LowerCase(Trim(OutputFormat));
  if Fmt = '' then Fmt := WEB_FETCH_DEFAULT_FORMAT;
  Charset := CharsetFromContentType(ContentType);
  Utf8Text := DecodeBodyToUtf8(Body, Charset);

  if (Mime = 'application/pdf') or (Mime = 'application/octet-stream') then
  begin
    ErrKind := wfekUnsupportedContentType;
    ErrMsg := 'Unsupported content type: ' + Mime;
    Exit;
  end;

  if Fmt = 'html' then
  begin
    if Pos('html', Mime) > 0 then
      Content := Utf8Text
    else
      Content := Utf8Text;
    Content := ApplyMaxLength(Content, MaxLength, Truncated);
    if Pos('html', Mime) > 0 then
      Title := ExtractTitleFromHtml(Utf8Text);
    Result := True;
    Exit;
  end;

  if (Mime = 'text/plain') or (Mime = 'text/markdown') or (Mime = 'application/json') then
  begin
    if Fmt = 'markdown' then
    begin
      if Mime = 'application/json' then
        Content := '```json' + LineEnding + Utf8Text + LineEnding + '```'
      else
        Content := Utf8Text;
    end
    else
      Content := Utf8Text;
    Content := ApplyMaxLength(Content, MaxLength, Truncated);
    Result := True;
    Exit;
  end;

  if (Mime = '') or (Pos('html', Mime) > 0) or (Mime = 'application/xhtml+xml') then
  begin
    Title := ExtractTitleFromHtml(Utf8Text);
    Content := HtmlToMarkdown(Utf8Text);
    if Fmt = 'text' then
      Content := StringReplace(Content, '#', '', [rfReplaceAll]);
    Content := ApplyMaxLength(Content, MaxLength, Truncated);
    Result := True;
    Exit;
  end;

  ErrKind := wfekUnsupportedContentType;
  ErrMsg := 'Unsupported content type: ' + Mime;
end;

end.
