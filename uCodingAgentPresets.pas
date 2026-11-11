unit uCodingAgentPresets;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TCodingAgentPreset = record
    Vendor: string;
    Caption: string;
    ModelId: string;
  end;

function CodingAgentPresetCount: Integer;
function GetCodingAgentPreset(AIndex: Integer): TCodingAgentPreset;
function FindCodingAgentPresetByModelId(const AModelId: string): Integer;
procedure PopulatePredefinedCodingAgents(AItems: TStrings);

implementation

const
  CODING_AGENT_PRESETS: array[0..6] of TCodingAgentPreset = (
    (Vendor: 'Anthropic'; Caption: 'Claude 3.7 Sonnet'; ModelId: 'anthropic/claude-3.7-sonnet'),
    (Vendor: 'Nous Research'; Caption: 'Hermes 4 70B'; ModelId: 'Hermes-4-70B'),
    (Vendor: 'OpenAI'; Caption: 'GPT-4o'; ModelId: 'openai/gpt-4o'),
    (Vendor: 'DeepSeek'; Caption: 'DeepSeek R1'; ModelId: 'deepseek/deepseek-r1'),
    (Vendor: 'Google'; Caption: 'Gemini 2.0 Flash'; ModelId: 'google/gemini-2.0-flash'),
    (Vendor: 'Nous Research'; Caption: 'Hermes 4 405B'; ModelId: 'Hermes-4-405B'),
    (Vendor: 'Qwen'; Caption: 'Qwen 2.5 Coder 7B (Ollama)'; ModelId: 'qwen2.5-coder:7b')
  );

function CodingAgentPresetCount: Integer;
begin
  Result := Length(CODING_AGENT_PRESETS);
end;

function GetCodingAgentPreset(AIndex: Integer): TCodingAgentPreset;
begin
  if (AIndex < 0) or (AIndex >= CodingAgentPresetCount) then
    raise ERangeError.Create('Coding agent preset index out of range');
  Result := CODING_AGENT_PRESETS[AIndex];
end;

function FindCodingAgentPresetByModelId(const AModelId: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to CodingAgentPresetCount - 1 do begin
    if SameText(CODING_AGENT_PRESETS[I].ModelId, AModelId) then begin
      Result := I;
      Exit;
    end;
  end;
end;

procedure PopulatePredefinedCodingAgents(AItems: TStrings);
var
  I: Integer;
begin
  if not Assigned(AItems) then Exit;
  AItems.BeginUpdate;
  try
    AItems.Clear;
    for I := 0 to CodingAgentPresetCount - 1 do
      AItems.Add(CODING_AGENT_PRESETS[I].ModelId);
  finally
    AItems.EndUpdate;
  end;
end;

end.
