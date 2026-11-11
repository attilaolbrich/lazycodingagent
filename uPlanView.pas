unit uPlanView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, Graphics, LcaTheme, LcaPaintButton,
  LcaPaintComboBox, LcaMarkdownView, uWorkspaceState;

type
  TPlanBuildEvent = procedure(Sender: TObject; const APlanPath, APlanContent, AModelId: string) of object;

  TPlanView = class(TComponent)
  private
    FTheme: TThemeKind;
    FLblPath: TLabel;
    FModelCombo: TLcaPaintComboBox;
    FModelIds: TStringList;
    FModel: string;
    FBuildBtn: TLcaPaintButton;
    FBodyMarkdown: TLcaMarkdownView;
    FPlanPath: string;
    FPlanContent: string;
    FOnBuild: TPlanBuildEvent;
    procedure BuildClick(Sender: TObject);
    procedure ModelComboChange(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Bind(ALblPath: TLabel; AModelCombo: TLcaPaintComboBox; ABuildBtn: TLcaPaintButton;
      ABody: TLcaMarkdownView);
    procedure LoadPlan(const APath, AContent: string);
    procedure ApplyTheme(ATheme: TThemeKind);
    procedure SetAvailableModels(const AModels: array of TSavedModel);
    procedure SetModel(const AModel: string);
    procedure ClearPlan;
    function SelectedModelId: string;
    property PlanPath: string read FPlanPath;
    property PlanContent: string read FPlanContent;
    property OnBuild: TPlanBuildEvent read FOnBuild write FOnBuild;
  end;

implementation

function ModelComboCaption(const M: TSavedModel): string;
begin
  if (Trim(M.DisplayName) <> '') and not SameText(M.DisplayName, M.ModelId) then
    Result := M.DisplayName
  else
    Result := M.ModelId;
end;

constructor TPlanView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTheme := tkDark;
  FModelIds := TStringList.Create;
end;

destructor TPlanView.Destroy;
begin
  FModelIds.Free;
  inherited Destroy;
end;

procedure TPlanView.Bind(ALblPath: TLabel; AModelCombo: TLcaPaintComboBox; ABuildBtn: TLcaPaintButton;
  ABody: TLcaMarkdownView);
begin
  FLblPath := ALblPath;
  FModelCombo := AModelCombo;
  FBuildBtn := ABuildBtn;
  FBodyMarkdown := ABody;
  if Assigned(FModelCombo) then
    FModelCombo.OnChange := @ModelComboChange;
  if Assigned(FBuildBtn) then
    FBuildBtn.OnClick := @BuildClick;
end;

procedure TPlanView.ClearPlan;
begin
  FPlanPath := '';
  FPlanContent := '';
  if Assigned(FLblPath) then begin
    FLblPath.Caption := 'Plan file: (none)';
    FLblPath.Hint := '';
    FLblPath.ShowHint := False;
  end;
  if Assigned(FBodyMarkdown) then
    FBodyMarkdown.SetMarkdown('');
end;

procedure TPlanView.LoadPlan(const APath, AContent: string);
begin
  FPlanPath := APath;
  FPlanContent := AContent;
  if Assigned(FLblPath) then begin
    FLblPath.Caption := 'Plan file: ' + APath;
    FLblPath.Hint := APath;
    FLblPath.ShowHint := True;
  end;
  if Assigned(FBodyMarkdown) then
    FBodyMarkdown.SetMarkdown(AContent);
end;

procedure TPlanView.SetAvailableModels(const AModels: array of TSavedModel);
var
  I, SelIdx: Integer;
  Cap: string;
begin
  if not Assigned(FModelCombo) then Exit;
  FModelCombo.Items.BeginUpdate;
  FModelIds.BeginUpdate;
  try
    FModelCombo.Items.Clear;
    FModelIds.Clear;
    SelIdx := -1;
    for I := 0 to High(AModels) do begin
      Cap := ModelComboCaption(AModels[I]);
      FModelCombo.Items.Add(Cap);
      FModelIds.Add(AModels[I].ModelId);
      if SameText(AModels[I].ModelId, FModel) then
        SelIdx := I;
    end;
    if SelIdx >= 0 then
      FModelCombo.SetItemIndexSilent(SelIdx)
    else if FModelCombo.Items.Count > 0 then begin
      FModelCombo.SetItemIndexSilent(0);
      FModel := FModelIds[0];
    end else
      FModel := '';
  finally
    FModelIds.EndUpdate;
    FModelCombo.Items.EndUpdate;
  end;
end;

procedure TPlanView.SetModel(const AModel: string);
var
  Idx: Integer;
begin
  FModel := AModel;
  Idx := FModelIds.IndexOf(AModel);
  if Assigned(FModelCombo) and (Idx >= 0) then
    FModelCombo.SetItemIndexSilent(Idx);
end;

function TPlanView.SelectedModelId: string;
var
  Idx: Integer;
begin
  Idx := FModelCombo.ItemIndex;
  if (Idx >= 0) and (Idx < FModelIds.Count) then
    Result := FModelIds[Idx]
  else
    Result := FModel;
end;

procedure TPlanView.ModelComboChange(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := FModelCombo.ItemIndex;
  if (Idx >= 0) and (Idx < FModelIds.Count) then
    FModel := FModelIds[Idx]
  else
    FModel := '';
end;

procedure TPlanView.ApplyTheme(ATheme: TThemeKind);
var
  P: TThemePalette;
begin
  FTheme := ATheme;
  P := ThemePalette(ATheme);
  if Assigned(FLblPath) then
    FLblPath.Font.Color := P.TextMuted;
  if Assigned(FModelCombo) then
    FModelCombo.ApplyTheme(ATheme);
  if Assigned(FBuildBtn) then
    FBuildBtn.ApplyTheme(ATheme);
  if Assigned(FBodyMarkdown) then
    FBodyMarkdown.ApplyTheme(ATheme);
end;

procedure TPlanView.BuildClick(Sender: TObject);
var
  ModelId: string;
begin
  if not Assigned(FOnBuild) then Exit;
  if Trim(FPlanPath) = '' then Exit;
  ModelId := SelectedModelId;
  if ModelId = '' then Exit;
  FOnBuild(Self, FPlanPath, FPlanContent, ModelId);
end;

end.
