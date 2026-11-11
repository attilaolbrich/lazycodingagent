unit frmMcpConnection;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, LcaPaintButton, LcaPaintComboBox,
  uAppTypes, LcaTheme, LcaThemedMessageBox, uMcpTypes;

type
  TMcpConnectionForm = class(TForm)
    pnlBottom: TPanel;
    btnOK: TLcaPaintButton;
    btnCancel: TLcaPaintButton;
    lblName: TLabel;
    edtName: TEdit;
    lblTransport: TLabel;
    cboTransport: TLcaPaintComboBox;
    lblUrl: TLabel;
    edtUrl: TEdit;
    lblBearer: TLabel;
    edtBearer: TEdit;
    lblCommand: TLabel;
    edtCommand: TEdit;
    lblArgs: TLabel;
    edtArgs: TEdit;
    lblWorkingDir: TLabel;
    edtWorkingDir: TEdit;
    lblTimeout: TLabel;
    edtTimeout: TEdit;
    chkEnabled: TCheckBox;
    procedure FormShow(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure cboTransportChange(Sender: TObject);
    procedure edtBearerChange(Sender: TObject);
  private
    FTheme: TThemeKind;
    FBearerChanged: Boolean;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure UpdateTransportFields;
    function ValidateInput: Boolean;
  public
    class function Execute(AOwner: TComponent; ATheme: TThemeKind;
      const AConn: TMcpConnection; AIsNew: Boolean;
      out AConnOut: TMcpConnection; out ANewBearer: string;
      out ABearerChanged: Boolean): Boolean;
  end;

implementation

{$R *.lfm}

uses
  uMcpSecrets;

class function TMcpConnectionForm.Execute(AOwner: TComponent; ATheme: TThemeKind;
  const AConn: TMcpConnection; AIsNew: Boolean;
  out AConnOut: TMcpConnection; out ANewBearer: string;
  out ABearerChanged: Boolean): Boolean;
var
  Dlg: TMcpConnectionForm;
begin
  Dlg := TMcpConnectionForm.Create(AOwner);
  try
    Dlg.FTheme := ATheme;
    Dlg.FBearerChanged := False;
    Dlg.edtName.Text := AConn.Name;
    Dlg.chkEnabled.Checked := AConn.Enabled;
    Dlg.cboTransport.Items.Clear;
    Dlg.cboTransport.Items.Add('HTTP');
    Dlg.cboTransport.Items.Add('Stdio');
    if AConn.Transport = mtkStdio then
      Dlg.cboTransport.ItemIndex := 1
    else
      Dlg.cboTransport.ItemIndex := 0;
    Dlg.edtUrl.Text := AConn.Url;
    Dlg.edtCommand.Text := AConn.Command;
    Dlg.edtArgs.Text := AConn.ArgsJson;
    if Trim(Dlg.edtArgs.Text) = '' then
      Dlg.edtArgs.Text := '[]';
    Dlg.edtWorkingDir.Text := AConn.WorkingDir;
    Dlg.edtTimeout.Text := IntToStr(AConn.TimeoutMs);
    Dlg.edtBearer.Text := '';
    if not AIsNew and McpBearerTokenIsSet(AConn.Id) then
      Dlg.edtBearer.Text := '********';
    Dlg.ApplyTheme(ATheme);
    Dlg.UpdateTransportFields;
    Result := Dlg.ShowModal = mrOk;
    if Result then
    begin
      AConnOut := AConn;
      AConnOut.Name := Trim(Dlg.edtName.Text);
      if Dlg.cboTransport.ItemIndex = 1 then
        AConnOut.Transport := mtkStdio
      else
        AConnOut.Transport := mtkHttp;
      AConnOut.Enabled := Dlg.chkEnabled.Checked;
      AConnOut.Url := Trim(Dlg.edtUrl.Text);
      AConnOut.Command := Trim(Dlg.edtCommand.Text);
      AConnOut.ArgsJson := Trim(Dlg.edtArgs.Text);
      if AConnOut.ArgsJson = '' then
        AConnOut.ArgsJson := '[]';
      AConnOut.WorkingDir := Trim(Dlg.edtWorkingDir.Text);
      AConnOut.TimeoutMs := StrToIntDef(Trim(Dlg.edtTimeout.Text), MCP_DEFAULT_TIMEOUT_MS);
      ANewBearer := Trim(Dlg.edtBearer.Text);
      ABearerChanged := Dlg.FBearerChanged and (ANewBearer <> '') and (ANewBearer <> '********');
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TMcpConnectionForm.FormShow(Sender: TObject);
begin
  ApplyTheme(FTheme);
  ApplyFormPlatformThemes(Self, FTheme);
end;

procedure TMcpConnectionForm.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.Background;
  Font.Color := P.Text;
  pnlBottom.Color := P.Surface;
  ApplyThemedForm(Self, ATheme);
  edtName.Color := P.SurfaceAlt;
  edtUrl.Color := P.SurfaceAlt;
  edtBearer.Color := P.SurfaceAlt;
  edtCommand.Color := P.SurfaceAlt;
  edtArgs.Color := P.SurfaceAlt;
  edtWorkingDir.Color := P.SurfaceAlt;
  edtTimeout.Color := P.SurfaceAlt;
  btnOK.ApplyTheme(ATheme);
  btnCancel.ApplyTheme(ATheme);
  lblName.Font.Color := P.Text;
  lblTransport.Font.Color := P.Text;
  lblUrl.Font.Color := P.Text;
  lblBearer.Font.Color := P.Text;
  lblCommand.Font.Color := P.Text;
  lblArgs.Font.Color := P.Text;
  lblWorkingDir.Font.Color := P.Text;
  lblTimeout.Font.Color := P.Text;
  chkEnabled.Font.Color := P.Text;
  ApplyPlatformChrome(Self, ATheme);
end;

procedure TMcpConnectionForm.UpdateTransportFields;
var
  Stdio: Boolean;
begin
  Stdio := cboTransport.ItemIndex = 1;
  lblUrl.Visible := not Stdio;
  edtUrl.Visible := not Stdio;
  lblBearer.Visible := not Stdio;
  edtBearer.Visible := not Stdio;
  lblCommand.Visible := Stdio;
  edtCommand.Visible := Stdio;
  lblArgs.Visible := Stdio;
  edtArgs.Visible := Stdio;
  lblWorkingDir.Visible := Stdio;
  edtWorkingDir.Visible := Stdio;
end;

procedure TMcpConnectionForm.cboTransportChange(Sender: TObject);
begin
  UpdateTransportFields;
end;

procedure TMcpConnectionForm.edtBearerChange(Sender: TObject);
begin
  FBearerChanged := True;
end;

function TMcpConnectionForm.ValidateInput: Boolean;
var
  AliasName: string;
begin
  AliasName := Trim(edtName.Text);
  if not McpAliasIsValid(AliasName) then
  begin
    LcaShowMessage(
      'Name must start with a letter and contain only letters, digits, and underscores. ' +
      'It is used as the @alias in chat.', FTheme);
    Exit(False);
  end;
  if cboTransport.ItemIndex = 1 then
  begin
    if Trim(edtCommand.Text) = '' then
    begin
      LcaShowMessage('Command is required for stdio MCP plugins.', FTheme);
      Exit(False);
    end;
  end
  else if Trim(edtUrl.Text) = '' then
  begin
    LcaShowMessage('Connection URL is required for HTTP MCP plugins.', FTheme);
    Exit(False);
  end;
  Result := True;
end;

procedure TMcpConnectionForm.btnOKClick(Sender: TObject);
begin
  if not ValidateInput then
    ModalResult := mrNone
  else
    ModalResult := mrOk;
end;

end.
