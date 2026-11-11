# m0-foundation — Static SQLite engine (done)

**Status:** Done (shipped ~v0.1.31). Post-M0 work extended schema v2 and production wiring in later sprints (see [README.md](README.md) queue).

**Depends on:** —

## Summary

Land statically linked SQLite, connection/migration runner, first repository port, and CI/release build hooks. **M0 scope** is the engine and repository skeleton only; global config at startup and normalized tables were added afterward (not part of original M0 acceptance).

## Delivered

| Area | Location |
| --- | --- |
| Amalgamation + FTS5 build flags | `third_party/sqlite/` |
| Static link package | `packages/LazySqliteStatic/`, `uSqlite3Embed.pas`, `sqlite3_embed.o` via build scripts |
| DB layer | `uAppDatabase.pas` — `global.db`, `workspaces/<wsId>/workspace.db`, migration **v1** (`schema_migrations`, `app_settings`); **v2 global DDL** added in same unit post-M0 |
| Repository ports | `data/uRepositoryInterfaces.pas`, `data/sqlite/` — `uSqliteAppSettingsRepository`, `uSqliteWorkspaceRegistryRepository`, `uSqliteLlmSettingsRepository`, `uSqlitePanelLayoutRepository`, `uSqliteWebSearchRepository`, `uSqliteBrowserReadRepository` |
| Bootstrap / startup | `data/uGlobalConfigBootstrap.pas`, `lazycodingagent.lpr` (`EnsureGlobalConfigReady`) — see [m1-startup-open-global-db.md](m1-startup-open-global-db.md) |
| Tests | `tests/test_app_database.*` (schema v2), `tests/test_settings_import.lpr` |
| Build | `scripts/install-lazarus-sqlite.*`, `build-sqlite-static.*`, PR + release CI |
| Rules | `.cursor/rules/persistence-and-data-access.mdc` |

## Acceptance criteria (met)

- [x] Binary links SQLite without system `libsqlite3` on Linux (`ldd` clean).
- [x] Console test round-trips settings via `IAppSettingsRepository` on global and workspace DBs.
- [x] Main app links `uSqlite3Embed`.

## Post-M0 hygiene (follow-ups — not reopening M0)

- [ ] **Split migrations:** `RunMigrations` should apply global v2 DDL only to `global.db`; workspace DB should get its own migration chain (v1 `app_settings`, then chat tables per [m1-workspace-schema-v2.md](m1-workspace-schema-v2.md)) — today both files receive global tables.
- [ ] **Schema parity:** add `syntax_schemes` to global migration (parent §5.1) or track only in [m1-global-schema-v2.md](m1-global-schema-v2.md) / [m1-read-through-syntax-schemes.md](m1-read-through-syntax-schemes.md).
- [ ] **§5.1 constraint:** add `FOREIGN KEY (provider_ord) REFERENCES llm_providers(provider_ord)` on `saved_models` if strict parity with parent plan is required.
- [ ] **Tests:** assert required v2 table names exist on fresh global open (beyond `MAX(version)=2`).

## References

- Parent plan: [Lazarus_Embedded_Storage_and_Vector_Plan.md](../Lazarus_Embedded_Storage_and_Vector_Plan.md) — M0 status table
