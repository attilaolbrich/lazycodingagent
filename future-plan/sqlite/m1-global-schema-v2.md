# m1-global-schema-v2 — Global DB migration v2

**Status:** Mostly done (gaps: `syntax_schemes` table, FK on `saved_models`)

**Depends on:** [m0-foundation.md](m0-foundation.md)

## Out of scope

- Wiring chat/syntax stores (separate M1 items).
- Workspace DB chat tables ([m1-workspace-schema-v2.md](m1-workspace-schema-v2.md)).

## Goal

Add migration **version 2** on `global.db` creating normalized tables from parent plan §5.1. Existing v1 (`app_settings`, `schema_migrations`) remains; v2 adds tables only.

## Delivered

- `uAppDatabase.pas`: v2 SQL for `workspaces`, `llm_providers`, `saved_models`, `panel_layout`, `web_search_connections` (web search table extends parent sketch).
- `test_app_database` asserts global schema version **2** after open.

## Acceptance criteria

- [x] Fresh `global.db` reaches schema version 2 after open/migrate.
- [x] Upgrading from v1-only DB applies v2 without data loss on `app_settings`.
- [ ] SQL matches §5.1 for `syntax_schemes`; `saved_models` FK on `provider_ord` if required.
- [x] Production paths use SQLite only for global config (no INI/JSON readers).

## References

- [Lazarus_Embedded_Storage_and_Vector_Plan.md](../Lazarus_Embedded_Storage_and_Vector_Plan.md) §5.1
- `uAppDatabase.pas`
