# m1-read-through-workspace-state — Workspace state (SQLite)

**Status:** Done

**Depends on:** [m1-global-schema-v2.md](m1-global-schema-v2.md)

## Goal

Persist workspace-global state (LLM providers/models, panel layout, app prefs) via repository ports. `uWorkspaceState.pas` uses `LoadFromGlobalDb` / `SaveToGlobalDb` with `ILlmSettingsRepository`, `IPanelLayoutRepository`, and `IAppSettingsRepository` (split by concern, not a single `IWorkspaceStateRepository`).

## Delivered

- Interfaces and adapters: `data/uRepositoryInterfaces.pas`, `data/sqlite/uSqliteLlmSettingsRepository.pas`, `uSqlitePanelLayoutRepository.pas`, `uSqliteAppSettingsRepository.pas`.
- `uWorkspaceState.pas` Load/Save → SQLite only; `LLM_CONFIG_VERSION` stored in `app_settings`.

## Acceptance criteria

- [x] Load/Save round-trip providers, models, panels, and typed app settings in `global.db`.
- [x] No SQL types leak above repository layer (persistence rule).
- [x] SQLite-only; no INI read/write paths.

## References

- `uWorkspaceState.pas`, `data/uGlobalConfigKeys.pas`
