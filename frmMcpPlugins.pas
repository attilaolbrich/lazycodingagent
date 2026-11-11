unit frmMcpPlugins;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, ComCtrls, LcaPaintButton,
  uAppTypes, LcaTheme, LcaThemedMessageBox, uMcpTypes;

type
  TMcpPluginsForm = class(TForm)
    lblTitle: TLabel;
    lblHint: TLabel;
    lvConnections: TListView;
    pnlActions: TPanel;
    btnAdd: TLcaPaintButton;
    btnEdit: TLcaPaintButton;
    btnRemove: TLcaPaintButton;
    btnTest: TLcaPaintButton;
    pnlBottom: TPanel;
    btnClose: TLcaPaintButton;
    procedure FormShow(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure btnAddClick(Sender: TObject);
    procedure btnEditClick(Sender: TObject);
    procedure btnRemoveClick(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
    procedure lvConnectionsResize(Sender: TObject);
  private
    FTheme: TThemeKind;
    FConnections: TMcpConnectionArray;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure LoadData;
    procedure SaveData;
    procedure RefreshList;
    procedure AdjustListColumns;
    function SelectedIndex: Integer;
  public
    class procedure Execute(AOwner: TComponent; ATheme: TThemeKind);
  end;

implementation

{$R *.lfm}

uses
  StrUtils, frmMcpConnection, uMcpConfig, uMcpSecrets, uMcpManager;

class procedure TMcpPluginsForm.Execute(AOwner: TComponent; ATheme: TThemeKind);
var
  Dlg: TMcpPluginsForm;
begin
  Dlg := TMcpPluginsForm.Create(AOwner);
  try
    Dlg.FTheme := ATheme;
    Dlg.ApplyTheme(ATheme);
    Dlg.LoadData;
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

procedure TMcpPluginsForm.FormShow(Sender: TObject);
begin
  ApplyTheme(FTheme);
  ApplyFormPlatformThemes(Self, FTheme);
end;

procedure TMcpPluginsForm.ApplyTheme(ATheme: TThemeKind);
var
  Palette: TThemePalette;
begin
  FTheme := ATheme;
  Palette := ThemePalette(ATheme);
  Color := Palette.Background;
  Font.Color := Palette.Text;
  lblTitle.Font.Color := Palette.Text;
  lblHint.Font.Color := Palette.TextMuted;
  pnlActions.Color := Palette.Surface;
  pnlBottom.Color := Palette.Surface;
  lvConnections.Color := Palette.SurfaceAlt;
  lvConnections.Font.Color := Palette.Text;
  ApplyThemedForm(Self, ATheme);
  ApplyPlatformChrome(Self, ATheme);
  btnAdd.ApplyTheme(ATheme);
  btnEdit.ApplyTheme(ATheme);
  btnRemove.ApplyTheme(ATheme);
  btnTest.ApplyTheme(ATheme);
  btnClose.ApplyTheme(ATheme);
end;

procedure TMcpPluginsForm.LoadData;
begin
  FConnections := LoadMcpConnections;
  RefreshList;
end;

procedure TMcpPluginsForm.SaveData;
begin
  SaveMcpConnections(FConnections);
end;

procedure TMcpPluginsForm.AdjustListColumns;
var
  I, Fixed, LastW: Integer;
begin
  if lvConnections.Columns.Count < 2 then Exit;
  Fixed := 0;
  for I := 0 to lvConnections.Columns.Count - 2 do
    Fixed := Fixed + lvConnections.Columns[I].Width;
  LastW := lvConnections.ClientWidth - Fixed - 6;
  if LastW < 80 then LastW := 80;
  lvConnections.Columns[lvConnections.Columns.Count - 1].Width := LastW;
end;

procedure TMcpPluginsForm.RefreshList;
var
  I: Integer;
  Item: TListItem;
  Conn: TMcpConnection;
begin
  lvConnections.Items.Clear;
  lvConnections.Columns.Clear;
  with lvConnections.Columns.Add do begin
    Caption := 'Enabled';
    Width := 64;
  end;
  with lvConnections.Columns.Add do begin
    Caption := 'Name';
    Width := 140;
  end;
  with lvConnections.Columns.Add do begin
    Caption := 'Type';
    Width := 72;
  end;
  with lvConnections.Columns.Add do begin
    Caption := 'Target';
    Width := 300;
  end;
  for I := 0 to High(FConnections) do
  begin
    Conn := FConnections[I];
    Item := lvConnections.Items.Add;
    Item.Caption := IfThen(Conn.Enabled, 'Yes', 'No');
    Item.SubItems.Add(Conn.Name);
    Item.SubItems.Add(McpTransportDisplayName(Conn.Transport));
    Item.SubItems.Add(ConnectionSummaryLine(Conn));
    Item.Data := Pointer(I);
  end;
  AdjustListColumns;
end;

function TMcpPluginsForm.SelectedIndex: Integer;
begin
  if lvConnections.Selected = nil then
    Result := -1
  else
    Result := Integer(lvConnections.Selected.Data);
end;

procedure TMcpPluginsForm.lvConnectionsResize(Sender: TObject);
begin
  AdjustListColumns;
end;

procedure TMcpPluginsForm.btnAddClick(Sender: TObject);
var
  Conn, OutConn: TMcpConnection;
  Key: string;
  KeyChanged: Boolean;
begin
  Conn := DefaultMcpConnection;
  Conn.Id := NewMcpConnectionId;
  Conn.Name := 'myplugin';
  if TMcpConnectionForm.Execute(Self, FTheme, Conn, True, OutConn, Key, KeyChanged) then
  begin
    SetLength(FConnections, Length(FConnections) + 1);
    FConnections[High(FConnections)] := OutConn;
    if KeyChanged then
      SetMcpBearerToken(OutConn.Id, Key);
    SaveData;
    RefreshList;
  end;
end;

procedure TMcpPluginsForm.btnEditClick(Sender: TObject);
var
  Idx: Integer;
  OutConn: TMcpConnection;
  Key: string;
  KeyChanged: Boolean;
begin
  Idx := SelectedIndex;
  if Idx < 0 then Exit;
  if TMcpConnectionForm.Execute(Self, FTheme, FConnections[Idx], False, OutConn, Key, KeyChanged) then
  begin
    FConnections[Idx] := OutConn;
    if KeyChanged then
      SetMcpBearerToken(OutConn.Id, Key);
    SaveData;
    RefreshList;
  end;
end;

procedure TMcpPluginsForm.btnRemoveClick(Sender: TObject);
var
  Idx, I: Integer;
begin
  Idx := SelectedIndex;
  if Idx < 0 then Exit;
  if LcaMessageDlg('MCP Plugins', 'Remove MCP connection "' + FConnections[Idx].Name + '"?',
    mtConfirmation, [mbYes, mbNo], FTheme) <> mrYes then
    Exit;
  ClearMcpBearerToken(FConnections[Idx].Id);
  for I := Idx to High(FConnections) - 1 do
    FConnections[I] := FConnections[I + 1];
  SetLength(FConnections, Length(FConnections) - 1);
  SaveData;
  RefreshList;
end;

procedure TMcpPluginsForm.btnTestClick(Sender: TObject);
var
  Idx, ToolCount: Integer;
  ErrMsg: string;
  Bearer: string;
begin
  Idx := SelectedIndex;
  if Idx < 0 then Exit;
  Bearer := GetMcpBearerToken(FConnections[Idx].Id);
  if TMcpSessionManager.TestConnection(FConnections[Idx], Bearer, ToolCount, ErrMsg) then
    LcaShowMessage(Format('Connection OK. %d tool(s) reported.', [ToolCount]), FTheme)
  else
    LcaShowMessage('Connection failed: ' + ErrMsg, FTheme);
end;

procedure TMcpPluginsForm.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
