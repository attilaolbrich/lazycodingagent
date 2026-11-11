unit uGlobalConfigKeys;

{$mode ObjFPC}{$H+}

interface

const
  KEY_MIGRATION_IMPORTED = 'migration.global_config_imported_at';
  KEY_WORKSPACE_ACTIVE_ID = 'workspace.active_id';

  KEY_APPEARANCE_THEME = 'appearance.theme';
  KEY_AGENT_MODE = 'agent.mode';
  KEY_AGENT_MODEL = 'agent.model';

  KEY_LLM_CONFIG_VERSION = 'llm.config_version';
  KEY_LLM_PROVIDER = 'llm.provider';
  KEY_LLM_CUSTOM_DISPLAY_NAME = 'llm.custom_display_name';
  KEY_LLM_TEMPERATURE = 'llm.temperature';
  KEY_LLM_MAX_TOKENS = 'llm.max_tokens';
  KEY_LLM_MAX_STEPS = 'llm.max_steps';
  KEY_LLM_CONTEXT_WINDOW = 'llm.context_window_tokens';
  KEY_LLM_SUMMARIZE_THRESHOLD = 'llm.summarize_threshold';
  KEY_LLM_CONNECT_TIMEOUT_MS = 'llm.connect_timeout_ms';
  KEY_LLM_READ_TIMEOUT_MS = 'llm.read_timeout_ms';
  KEY_LLM_HTTP_RETRY_COUNT = 'llm.http_retry_count';
  KEY_LLM_NATIVE_TOOL_CALLING = 'llm.native_tool_calling';
  KEY_LLM_TEXT_TOOL_COMPAT = 'llm.text_tool_compat';
  KEY_LLM_STREAMING_ENABLED = 'llm.streaming_enabled';

  KEY_GENERAL_DEBUGGING = 'general.debugging_mode';
  KEY_GENERAL_LEARN = 'general.learn_mode';
  KEY_GENERAL_AUTO_SUMMARIZE = 'general.auto_summarize_context';

  KEY_PROMPT_CACHE_MODE = 'prompt_cache.mode';
  KEY_PROMPT_CACHE_RETENTION = 'prompt_cache.retention';
  KEY_PROMPT_CACHE_SYSTEM = 'prompt_cache.cache_system';
  KEY_PROMPT_CACHE_TOOLS = 'prompt_cache.cache_tools';
  KEY_PROMPT_CACHE_PROJECT = 'prompt_cache.cache_project';
  KEY_PROMPT_CACHE_HISTORY = 'prompt_cache.cache_history';

  KEY_WEBSEARCH_CONFIG_VERSION = 'websearch.config_version';
  KEY_WEBSEARCH_ENABLED = 'websearch.enabled';
  KEY_WEBSEARCH_MAX_RESULTS = 'websearch.max_results';
  KEY_WEBSEARCH_TOTAL_TIMEOUT = 'websearch.total_timeout_ms';
  KEY_WEBSEARCH_AUTO_FALLBACK = 'websearch.automatic_fallback';
  KEY_WEBSEARCH_FALLBACK_EMPTY = 'websearch.fallback_on_empty';
  KEY_WEBSEARCH_ALLOW_PRIVATE = 'websearch.allow_private_instances';

  KEY_BROWSER_EXECUTABLE = 'browserread.executable_path';
  KEY_BROWSER_MAX_CONCURRENT = 'browserread.max_concurrent';
  KEY_BROWSER_MAX_SESSIONS = 'browserread.max_sessions';
  KEY_BROWSER_IDLE_TIMEOUT = 'browserread.idle_timeout_ms';

implementation

end.
