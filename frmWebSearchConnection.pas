unit frmWebSearchConnection;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, LcaPaintButton, LcaPaintComboBox,
  uAppTypes, LcaTheme, LcaThemedMessageBox, uWebSearchTypes;

type
  TWebSearchConnectionForm = class(TForm)
    pnlBottom: TPanel;
    btnOK: TLcaPaintButton;
    btnCancel: TLcaPaintButton;
    lblName: TLabel;
    edtName: TEdit;
    lblProvider: TLabel;
    cboProvider: TLcaPaintComboBox;
    lblApiKey: TLabel;
    edtApiKey: TEdit;
    lblInstanceUrl: TLabel;
    edtInstanceUrl: TEdit;
    lblTimeout: TLabel;
    edtTimeout: TEdit;
    chkEnabled: TCheckBox;
    lblTavilyDepth: TLabel;
    cboTavilyDepth: TLcaPaintComboBox;
    procedure FormShow(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure cboProviderChange(Sender: TObject);
  private
    FTheme: TThemeKind;
    FApiKeyChanged: Boolean;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure UpdateProviderFields;
  public
    class function Execute(AOwner: TComponent; ATheme: TThemeKind;
      const AConn: TWebSearchConnection; AIsNew: Boolean;
      out AConnOut: TWebSearchConnection; out ANewApiKey: string;
      out AApiKeyChanged: Boolean): Boolean;
  end;

implementation

{$R *.lfm}

uses
  uWebSearchSecrets;

class function TWebSearchConnectionForm.Execute(AOwner: TComponent; ATheme: TThemeKind;
  const AConn: TWebSearchConnection; AIsNew: Boolean;
  out AConnOut: TWebSearchConnection; out ANewApiKey: string;
  out AApiKeyChanged: Boolean): Boolean;
var
  Dlg: TWebSearchConnectionForm;
  Idx: Integer;
begin
  Dlg := TWebSearchConnectionForm.Create(AOwner);
  try
    Dlg.FTheme := ATheme;
    Dlg.FApiKeyChanged := False;
    Dlg.cboProvider.Items.Clear;
    Dlg.cboProvider.Items.Add('Brave Search');
    Dlg.cboProvider.Items.Add('SearXNG');
    Dlg.cboProvider.Items.Add('Tavily');
    case AConn.Kind of
      wspkBrave: Dlg.cboProvider.ItemIndex := 0;
      wspkSearxng: Dlg.cboProvider.ItemIndex := 1;
      wspkTavily: Dlg.cboProvider.ItemIndex := 2;
    else Dlg.cboProvider.ItemIndex := 0;
    end;
    Dlg.edtName.Text := AConn.Name;
    Dlg.edtInstanceUrl.Text := AConn.InstanceUrl;
    Dlg.edtTimeout.Text := IntToStr(AConn.TimeoutMs);
    Dlg.chkEnabled.Checked := AConn.Enabled;
    Dlg.cboTavilyDepth.Items.Clear;
    Dlg.cboTavilyDepth.Items.Add('basic');
    Dlg.cboTavilyDepth.Items.Add('advanced');
    if SameText(AConn.TavilySearchDepth, 'advanced') then
      Dlg.cboTavilyDepth.ItemIndex := 1
    else
      Dlg.cboTavilyDepth.ItemIndex := 0;
    Dlg.edtApiKey.Text := '';
    if not AIsNew and WebSearchApiKeyIsSet(AConn.Id) then
      Dlg.edtApiKey.Text := '********';
    Dlg.ApplyTheme(ATheme);
    Dlg.UpdateProviderFields;
    Result := Dlg.ShowModal = mrOk;
    if Result then begin
      AConnOut := AConn;
      AConnOut.Name := Trim(Dlg.edtName.Text);
      Idx := Dlg.cboProvider.ItemIndex;
      if Idx = 1 then AConnOut.Kind := wspkSearxng
      else if Idx = 2 then AConnOut.Kind := wspkTavily
      else AConnOut.Kind := wspkBrave;
      AConnOut.InstanceUrl := Trim(Dlg.edtInstanceUrl.Text);
      AConnOut.TimeoutMs := StrToIntDef(Trim(Dlg.edtTimeout.Text),
        WEB_SEARCH_DEFAULT_CONNECTION_TIMEOUT_MS);
      AConnOut.Enabled := Dlg.chkEnabled.Checked;
      if Dlg.cboTavilyDepth.ItemIndex = 1 then
        AConnOut.TavilySearchDepth := 'advanced'
      else
        AConnOut.TavilySearchDepth := 'basic';
      ANewApiKey := Trim(Dlg.edtApiKey.Text);
      AApiKeyChanged := Dlg.FApiKeyChanged and (ANewApiKey <> '') and (ANewApiKey <> '********');
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TWebSearchConnectionForm.FormShow(Sender: TObject);
begin
  ApplyTheme(FTheme);
  ApplyFormPlatformThemes(Self, FTheme);
end;

procedure TWebSearchConnectionForm.ApplyTheme(ATheme: TThemeKind);
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
  edtApiKey.Color := P.SurfaceAlt;
  edtInstanceUrl.Color := P.SurfaceAlt;
  edtTimeout.Color := P.SurfaceAlt;
  ApplyPlatformChrome(Self, ATheme);
end;

procedure TWebSearchConnectionForm.UpdateProviderFields;
var
  Idx: Integer;
begin
  Idx := cboProvider.ItemIndex;
  lblApiKey.Visible := (Idx = 0) or (Idx = 2);
  edtApiKey.Visible := lblApiKey.Visible;
  lblInstanceUrl.Visible := Idx = 1;
  edtInstanceUrl.Visible := Idx = 1;
  lblTavilyDepth.Visible := Idx = 2;
  cboTavilyDepth.Visible := Idx = 2;
end;

procedure TWebSearchConnectionForm.cboProviderChange(Sender: TObject);
begin
  UpdateProviderFields;
end;

procedure TWebSearchConnectionForm.btnOKClick(Sender: TObject);
begin
  if Trim(edtName.Text) = '' then begin
    LcaMessageDlg('Web Search', 'Enter a connection name.', mtWarning, [mbOK], FTheme);
    Exit;
  end;
  if (cboProvider.ItemIndex = 1) and (Trim(edtInstanceUrl.Text) = '') then begin
    LcaMessageDlg('Web Search', 'Enter the SearXNG instance URL.', mtWarning, [mbOK], FTheme);
    Exit;
  end;
  if (edtApiKey.Visible) and (Trim(edtApiKey.Text) = '') and
     (Trim(edtApiKey.Text) <> '********') then begin
    { allow empty if masked placeholder means unchanged }
  end;
  ModalResult := mrOk;
end;

end.
