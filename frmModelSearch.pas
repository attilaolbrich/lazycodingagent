unit frmModelSearch;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, LCLType, LcaPaintButton, LcaPaintComboBox,
  uAppTypes, uLlmClient, LcaTheme;

type
  TModelAddEvent = procedure(Sender: TObject; const AModelId, ADisplayName: string) of object;

  { TModelSearchForm }
  TModelSearchForm = class(TForm)
    pnlTop: TPanel;
    lblSearch: TLabel;
    edtSearch: TEdit;
    lstModels: TListBox;
    pnlBottom: TPanel;
    btnAdd: TLcaPaintButton;
    btnClose: TLcaPaintButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edtSearchChange(Sender: TObject);
    procedure lstModelsDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure lstModelsDblClick(Sender: TObject);
    procedure btnAddClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    FTheme: TThemeKind;
    FAllModels: array of TLlmModelInfo;
    FOnAdd: TModelAddEvent;
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure RebuildFilteredList;
    function DoAddSelected: Boolean;
    procedure DoCancel;
  public
    class procedure ShowModalSearch(AOwner: TComponent; ATheme: TThemeKind;
      const AModels: array of TLlmModelInfo; AOnAdd: TModelAddEvent);
  end;

implementation

{$R *.lfm}

function ModelLine(const M: TLlmModelInfo): string;
begin
  if (Trim(M.DisplayName) <> '') and not SameText(M.DisplayName, M.Id) then
    Result := M.DisplayName + ' — ' + M.Id
  else
    Result := M.Id;
end;

class procedure TModelSearchForm.ShowModalSearch(AOwner: TComponent; ATheme: TThemeKind;
  const AModels: array of TLlmModelInfo; AOnAdd: TModelAddEvent);
var
  Dlg: TModelSearchForm;
  I: Integer;
begin
  Dlg := TModelSearchForm.Create(AOwner);
  try
    Dlg.FTheme := ATheme;
    SetLength(Dlg.FAllModels, Length(AModels));
    for I := 0 to High(AModels) do
      Dlg.FAllModels[I] := AModels[I];
    Dlg.FOnAdd := AOnAdd;
    Dlg.ApplyTheme(ATheme);
    Dlg.RebuildFilteredList;
    Dlg.ShowModal;
  finally
    Dlg.Free;
  end;
end;

procedure TModelSearchForm.FormCreate(Sender: TObject);
begin
  KeyPreview := True;
  OnKeyDown := @FormKeyDown;
end;

procedure TModelSearchForm.FormShow(Sender: TObject);
begin
  ApplyTheme(FTheme);
  ApplyFormPlatformThemes(Self, FTheme);
  pnlBottom.BringToFront;
end;

procedure TModelSearchForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then begin
    Key := 0;
    DoCancel;
  end else if (Key = VK_RETURN) and not (ssCtrl in Shift) and not (ssAlt in Shift) then begin
    if ActiveControl = edtSearch then
      Exit;
    Key := 0;
    btnAddClick(Self);
  end;
end;

procedure TModelSearchForm.lstModelsDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
begin
  ThemedListBoxDrawItem(Control, Index, ARect, State, FTheme);
end;

procedure TModelSearchForm.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  Color := P.Background;
  Font.Color := P.Text;
  pnlTop.Color := P.Surface;
  pnlBottom.Color := P.Surface;
  ApplyThemedForm(Self, ATheme);
  edtSearch.Color := P.SurfaceAlt;
  edtSearch.Font.Color := P.Text;
  ApplyPlatformChrome(Self, ATheme);
  ApplyPlatformScrollableThemeRecursive(Self, ATheme);
  ConfigureThemedListBox(lstModels, ATheme);
  lstModels.OnDrawItem := @lstModelsDrawItem;
  lstModels.Invalidate;
end;

procedure TModelSearchForm.RebuildFilteredList;
var
  I: Integer;
  Filter, Line: string;
begin
  Filter := LowerCase(Trim(edtSearch.Text));
  lstModels.Items.BeginUpdate;
  try
    lstModels.Items.Clear;
    for I := 0 to High(FAllModels) do begin
      Line := ModelLine(FAllModels[I]);
      if (Filter = '') or (Pos(Filter, LowerCase(Line)) > 0) or
         (Pos(Filter, LowerCase(FAllModels[I].Id)) > 0) then
        lstModels.Items.AddObject(Line, TObject(PtrUInt(I)));
    end;
    if lstModels.Items.Count > 0 then
      lstModels.ItemIndex := 0;
  finally
    lstModels.Items.EndUpdate;
  end;
end;

procedure TModelSearchForm.edtSearchChange(Sender: TObject);
begin
  RebuildFilteredList;
end;

function TModelSearchForm.DoAddSelected: Boolean;
var
  Idx, Src: Integer;
begin
  Result := False;
  Idx := lstModels.ItemIndex;
  if Idx < 0 then Exit;
  Src := Integer(PtrUInt(lstModels.Items.Objects[Idx]));
  if (Src < 0) or (Src > High(FAllModels)) then Exit;
  if Assigned(FOnAdd) then
    FOnAdd(Self, FAllModels[Src].Id, FAllModels[Src].DisplayName);
  Result := True;
end;

procedure TModelSearchForm.DoCancel;
begin
  ModalResult := mrCancel;
  Close;
end;

procedure TModelSearchForm.lstModelsDblClick(Sender: TObject);
begin
  btnAddClick(Self);
end;

procedure TModelSearchForm.btnAddClick(Sender: TObject);
begin
  if not DoAddSelected then Exit;
  ModalResult := mrOk;
  Close;
end;

procedure TModelSearchForm.btnCloseClick(Sender: TObject);
begin
  DoCancel;
end;

end.
