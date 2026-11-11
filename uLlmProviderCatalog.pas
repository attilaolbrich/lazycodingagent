unit uLlmProviderCatalog;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uAgentTypes;

const
  LLM_PROVIDER_CATALOG_VERSION = 5;

function LlmProviderCatalogName(AProv: TLlmProvider): string;
function LlmProviderRegistrationUrl(AProv: TLlmProvider): string;
function LlmProviderDefaultApiBaseUrl(AProv: TLlmProvider): string;
function LlmProviderIsCustom(AProv: TLlmProvider): Boolean;
function LlmProviderComboCaption(AProv: TLlmProvider; const ACustomDisplayName: string): string;
procedure PopulateLlmProviderCombo(AItems: TStrings; const ACustomDisplayName: string);

implementation

type
  TCatalogEntry = record
    Name: string;
    RegistrationUrl: string;
    DefaultApiBaseUrl: string;
  end;

const
  CATALOG: array[TLlmProvider] of TCatalogEntry = (
    (Name: 'OpenAI'; RegistrationUrl: 'https://platform.openai.com';
      DefaultApiBaseUrl: 'https://api.openai.com/v1'),
    (Name: 'Nous Research'; RegistrationUrl: 'https://portal.nousresearch.com';
      DefaultApiBaseUrl: 'https://inference-api.nousresearch.com/v1'),
    (Name: 'OpenRouter'; RegistrationUrl: 'https://openrouter.ai';
      DefaultApiBaseUrl: 'https://openrouter.ai/api/v1'),
    (Name: 'Groq'; RegistrationUrl: 'https://console.groq.com';
      DefaultApiBaseUrl: 'https://api.groq.com/openai/v1'),
    (Name: 'Together AI'; RegistrationUrl: 'https://api.together.xyz';
      DefaultApiBaseUrl: 'https://api.together.xyz/v1'),
    (Name: 'Fireworks AI'; RegistrationUrl: 'https://fireworks.ai';
      DefaultApiBaseUrl: 'https://api.fireworks.ai/inference/v1'),
    (Name: 'DeepSeek'; RegistrationUrl: 'https://platform.deepseek.com';
      DefaultApiBaseUrl: 'https://api.deepseek.com/v1'),
    (Name: 'Google Gemini'; RegistrationUrl: 'https://aistudio.google.com';
      DefaultApiBaseUrl: 'https://generativelanguage.googleapis.com/v1beta'),
    (Name: 'xAI'; RegistrationUrl: 'https://console.x.ai';
      DefaultApiBaseUrl: 'https://api.x.ai/v1'),
    (Name: 'Mistral AI'; RegistrationUrl: 'https://console.mistral.ai';
      DefaultApiBaseUrl: 'https://api.mistral.ai/v1'),
    (Name: 'Cerebras'; RegistrationUrl: 'https://cloud.cerebras.ai';
      DefaultApiBaseUrl: 'https://api.cerebras.ai/v1'),
    (Name: 'Nebius AI'; RegistrationUrl: 'https://studio.nebius.ai';
      DefaultApiBaseUrl: 'https://api.studio.nebius.ai/v1'),
    (Name: 'Novita AI'; RegistrationUrl: 'https://novita.ai';
      DefaultApiBaseUrl: 'https://api.novita.ai/v3/openai'),
    (Name: 'Hyperbolic'; RegistrationUrl: 'https://hyperbolic.xyz';
      DefaultApiBaseUrl: 'https://api.hyperbolic.xyz/v1'),
    (Name: 'DeepInfra'; RegistrationUrl: 'https://deepinfra.com';
      DefaultApiBaseUrl: 'https://api.deepinfra.com/v1/openai'),
    (Name: 'SambaNova'; RegistrationUrl: 'https://cloud.sambanova.ai';
      DefaultApiBaseUrl: 'https://api.sambanova.ai/v1'),
    (Name: 'Moonshot AI'; RegistrationUrl: 'https://platform.moonshot.cn';
      DefaultApiBaseUrl: 'https://api.moonshot.cn/v1'),
    (Name: 'Hugging Face'; RegistrationUrl: 'https://huggingface.co/settings/tokens';
      DefaultApiBaseUrl: 'https://router.huggingface.co/v1'),
    (Name: 'Venice AI'; RegistrationUrl: 'https://venice.ai';
      DefaultApiBaseUrl: 'https://api.venice.ai/api/v1'),
    (Name: 'Lepton AI'; RegistrationUrl: 'https://dashboard.lepton.ai';
      DefaultApiBaseUrl: 'https://api.lepton.ai/v1'),
    (Name: 'Perplexity'; RegistrationUrl: 'https://www.perplexity.ai/settings/api';
      DefaultApiBaseUrl: 'https://api.perplexity.ai'),
    (Name: 'Anyscale'; RegistrationUrl: 'https://console.anyscale.com';
      DefaultApiBaseUrl: 'https://api.endpoints.anyscale.com/v1'),
    (Name: 'Custom'; RegistrationUrl: ''; DefaultApiBaseUrl: '')
  );

function LlmProviderCatalogName(AProv: TLlmProvider): string;
begin
  Result := CATALOG[AProv].Name;
end;

function LlmProviderRegistrationUrl(AProv: TLlmProvider): string;
begin
  Result := CATALOG[AProv].RegistrationUrl;
end;

function LlmProviderDefaultApiBaseUrl(AProv: TLlmProvider): string;
begin
  Result := CATALOG[AProv].DefaultApiBaseUrl;
end;

function LlmProviderIsCustom(AProv: TLlmProvider): Boolean;
begin
  Result := AProv = lpCustom;
end;

function LlmProviderComboCaption(AProv: TLlmProvider; const ACustomDisplayName: string): string;
begin
  if LlmProviderIsCustom(AProv) and (Trim(ACustomDisplayName) <> '') then
    Result := 'Custom — ' + Trim(ACustomDisplayName)
  else
    Result := LlmProviderCatalogName(AProv);
end;

procedure PopulateLlmProviderCombo(AItems: TStrings; const ACustomDisplayName: string);
var
  P: TLlmProvider;
begin
  AItems.Clear;
  for P := Low(TLlmProvider) to High(TLlmProvider) do
    AItems.Add(LlmProviderComboCaption(P, ACustomDisplayName));
end;

end.
