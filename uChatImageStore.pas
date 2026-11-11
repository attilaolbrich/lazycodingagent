unit uChatImageStore;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uAgentTypes;

const
  CHAT_IMAGE_MAX_BYTES = 5 * 1024 * 1024;
  CHAT_IMAGE_MAX_COUNT = 4;
  CHAT_IMAGE_MAX_EDGE = 2048;
  CHAT_ATTACHMENTS_REL_DIR = '.lca/attachments/';

function ChatAttachmentsRelativeDir: string;
function AttachmentAbsolutePath(const ARelativePath: string): string;
function MimeTypeFromImageFileName(const AFileName: string): string;
function IsAllowedImageFileName(const AFileName: string): Boolean;

function ImportImageToSidecar(const ASourcePath, ASessionId: string;
  out AAttachment: TChatAttachment): string;

function LoadAttachmentAsDataUrl(const ARelativePath: string; out ADataUrl: string): string;
function AttachmentFileSize(const ARelativePath: string): Int64;
function FormatAttachmentSummary(const AAtt: TChatAttachment): string;
function FormatAttachmentsSummary(const AAttachments: array of TChatAttachment): string;
function UserMessageTextForPayload(const AText: string; AHasImages: Boolean): string;

implementation

uses
  Math, Graphics, uAgentToolPaths, FileUtil;

const
  Base64Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function EncodeStreamBase64(AStream: TStream): string;
var
  Input: array[0..2] of Byte;
  InLen, I, B: Integer;
  C: Char;
begin
  Result := '';
  InLen := 0;
  AStream.Position := 0;
  while AStream.Read(Input[InLen], 1) = 1 do begin
    Inc(InLen);
    if InLen < 3 then Continue;
    B := (Input[0] shl 16) or (Input[1] shl 8) or Input[2];
    for I := 0 to 3 do begin
      C := Base64Alphabet[(B shr (18 - I * 6)) and $3F + 1];
      Result := Result + C;
    end;
    InLen := 0;
  end;
  if InLen > 0 then begin
    if InLen = 1 then
      Input[1] := 0;
    if InLen <= 2 then
      Input[2] := 0;
    B := (Input[0] shl 16) or (Input[1] shl 8) or Input[2];
    for I := 0 to 3 do begin
      if (InLen = 1) and (I >= 2) then
        C := '='
      else if (InLen = 2) and (I = 3) then
        C := '='
      else
        C := Base64Alphabet[(B shr (18 - I * 6)) and $3F + 1];
      Result := Result + C;
    end;
  end;
end;

function ChatAttachmentsRelativeDir: string;
begin
  Result := CHAT_ATTACHMENTS_REL_DIR;
end;

function AttachmentAbsolutePath(const ARelativePath: string): string;
begin
  Result := ResolveProjectPathInWorkspace(ARelativePath);
end;

function NormalizeExt(const AFileName: string): string;
var
  E: string;
begin
  E := LowerCase(ExtractFileExt(AFileName));
  if E = '.jpeg' then
    Result := '.jpg'
  else
    Result := E;
end;

function MimeTypeFromImageFileName(const AFileName: string): string;
begin
  case NormalizeExt(AFileName) of
    '.png': Result := 'image/png';
    '.jpg': Result := 'image/jpeg';
    '.webp': Result := 'image/webp';
    '.gif': Result := 'image/gif';
  else
    Result := '';
  end;
end;

function IsAllowedImageFileName(const AFileName: string): Boolean;
begin
  Result := MimeTypeFromImageFileName(AFileName) <> '';
end;

function EnsureAttachmentsDirectory: string;
begin
  Result := AttachmentAbsolutePath(CHAT_ATTACHMENTS_REL_DIR);
  if not DirectoryExists(Result) then
    ForceDirectories(Result);
end;

function NewSidecarFileName(const ASessionId, AExt: string): string;
begin
  Result := ASessionId + '-' + IntToHex(GetTickCount64, 16) + '-' +
    IntToHex(Random($7FFFFFFF), 8) + AExt;
end;

function LoadPictureSize(const APath: string; out AW, AH: Integer): Boolean;
var
  Pic: TPicture;
begin
  AW := 0;
  AH := 0;
  Result := False;
  if not FileExists(APath) then Exit;
  Pic := TPicture.Create;
  try
    Pic.LoadFromFile(APath);
    AW := Pic.Width;
    AH := Pic.Height;
    Result := (AW > 0) and (AH > 0);
  finally
    Pic.Free;
  end;
end;

function MaybeDownscaleImage(const ASourcePath, ADestPath: string;
  out AW, AH: Integer): string;
var
  Pic, Scaled: TPicture;
  Ratio: Double;
  NewW, NewH: Integer;
begin
  Result := '';
  AW := 0;
  AH := 0;
  if not LoadPictureSize(ASourcePath, AW, AH) then begin
    Result := 'Could not read image dimensions.';
    Exit;
  end;
  if (Max(AW, AH) <= CHAT_IMAGE_MAX_EDGE) then begin
    if not CopyFile(ASourcePath, ADestPath, False) then
      Result := 'Failed to copy image to attachments folder.'
    else
      Result := '';
    Exit;
  end;

  Pic := TPicture.Create;
  Scaled := TPicture.Create;
  try
    try
      Pic.LoadFromFile(ASourcePath);
      if AW >= AH then begin
        Ratio := CHAT_IMAGE_MAX_EDGE / AW;
        NewW := CHAT_IMAGE_MAX_EDGE;
        NewH := Max(1, Round(AH * Ratio));
      end else begin
        Ratio := CHAT_IMAGE_MAX_EDGE / AH;
        NewH := CHAT_IMAGE_MAX_EDGE;
        NewW := Max(1, Round(AW * Ratio));
      end;
      Scaled.Bitmap.SetSize(NewW, NewH);
      Scaled.Bitmap.Canvas.StretchDraw(Rect(0, 0, NewW, NewH), Pic.Graphic);
      AW := NewW;
      AH := NewH;
      Scaled.SaveToFile(ADestPath);
    except
      on E: Exception do
        Result := 'Failed to resize image: ' + E.Message;
    end;
  finally
    Scaled.Free;
    Pic.Free;
  end;
end;

function ImportImageToSidecar(const ASourcePath, ASessionId: string;
  out AAttachment: TChatAttachment): string;
var
  Src, DestAbs, RelPath, Ext, SidecarDir, BaseName: string;
  Size: Int64;
  W, H: Integer;
  F: TFileStream;
begin
  Result := '';
  FillChar(AAttachment, SizeOf(AAttachment), 0);
  AAttachment.Kind := cakImage;

  Src := ExpandFileName(Trim(ASourcePath));
  if not FileExists(Src) then begin
    Result := 'Image file not found: ' + Src;
    Exit;
  end;

  BaseName := ExtractFileName(Src);
  if not IsAllowedImageFileName(BaseName) then begin
    Result := 'Unsupported image type (use PNG, JPEG, WebP, or GIF).';
    Exit;
  end;

  F := TFileStream.Create(Src, fmOpenRead or fmShareDenyWrite);
  try
    Size := F.Size;
  finally
    F.Free;
  end;
  if Size > CHAT_IMAGE_MAX_BYTES then begin
    Result := Format('Image exceeds %d MiB limit.', [CHAT_IMAGE_MAX_BYTES div (1024 * 1024)]);
    Exit;
  end;

  if Trim(ASessionId) = '' then begin
    Result := 'No active chat session for image attachment.';
    Exit;
  end;

  SidecarDir := EnsureAttachmentsDirectory;
  Ext := NormalizeExt(BaseName);
  if Ext = '' then Ext := '.png';
  BaseName := NewSidecarFileName(ASessionId, Ext);
  DestAbs := IncludeTrailingPathDelimiter(SidecarDir) + BaseName;
  RelPath := CHAT_ATTACHMENTS_REL_DIR + BaseName;

  Result := MaybeDownscaleImage(Src, DestAbs, W, H);
  if Result <> '' then Exit;

  if not LoadPictureSize(DestAbs, W, H) then begin
    W := 0;
    H := 0;
  end;

  AAttachment.RelativePath := RelPath;
  AAttachment.MimeType := MimeTypeFromImageFileName(BaseName);
  AAttachment.OriginalName := ExtractFileName(ASourcePath);
  AAttachment.Width := W;
  AAttachment.Height := H;
end;

function LoadAttachmentAsDataUrl(const ARelativePath: string; out ADataUrl: string): string;
var
  AbsPath: string;
  Bytes: TMemoryStream;
  Enc: string;
  Mime: string;
begin
  Result := '';
  ADataUrl := '';
  AbsPath := AttachmentAbsolutePath(ARelativePath);
  if not FileExists(AbsPath) then begin
    Result := 'Attachment file missing: ' + ARelativePath;
    Exit;
  end;
  Mime := MimeTypeFromImageFileName(AbsPath);
  if Mime = '' then
    Mime := 'application/octet-stream';
  Bytes := TMemoryStream.Create;
  try
    Bytes.LoadFromFile(AbsPath);
    if Bytes.Size > CHAT_IMAGE_MAX_BYTES then begin
      Result := 'Attachment too large for API: ' + ARelativePath;
      Exit;
    end;
    Enc := EncodeStreamBase64(Bytes);
    ADataUrl := 'data:' + Mime + ';base64,' + Enc;
  finally
    Bytes.Free;
  end;
end;

function AttachmentFileSize(const ARelativePath: string): Int64;
var
  F: TFileStream;
  Abs: string;
begin
  Result := 0;
  Abs := AttachmentAbsolutePath(ARelativePath);
  if not FileExists(Abs) then Exit;
  F := TFileStream.Create(Abs, fmOpenRead or fmShareDenyWrite);
  try
    Result := F.Size;
  finally
    F.Free;
  end;
end;

function FormatAttachmentSummary(const AAtt: TChatAttachment): string;
var
  DisplayName: string;
begin
  if AAtt.OriginalName <> '' then
    DisplayName := AAtt.OriginalName
  else
    DisplayName := ExtractFileName(AAtt.RelativePath);
  Result := Format('[image: %s (%s)]', [DisplayName, AAtt.RelativePath]);
end;

function FormatAttachmentsSummary(const AAttachments: array of TChatAttachment): string;
var
  I: Integer;
  Parts: TStringList;
begin
  Parts := TStringList.Create;
  try
    for I := Low(AAttachments) to High(AAttachments) do
      Parts.Add(FormatAttachmentSummary(AAttachments[I]));
    Result := Parts.Text;
    Result := Trim(Result);
  finally
    Parts.Free;
  end;
end;

function UserMessageTextForPayload(const AText: string; AHasImages: Boolean): string;
begin
  Result := Trim(AText);
  if (Result = '') and AHasImages then
    Result := '(see attached image(s))';
end;

end.
