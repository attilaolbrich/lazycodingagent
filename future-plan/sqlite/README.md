# SQLite migration — implementation queue

Architecture and schema reference: [Lazarus_Embedded_Storage_and_Vector_Plan.md](../Lazarus_Embedded_Storage_and_Vector_Plan.md).

Coding rules: [`.cursor/rules/persistence-and-data-access.mdc`](../../.cursor/rules/persistence-and-data-access.mdc).

## Rule

**Always implement only the next unchecked item in the table below.**

Do not skip ahead or combine multiple items in one PR unless a document explicitly marks work as optional follow-up.

When an item ships, check it off here and move the **NEXT** marker to the following row.

**Current next item:** [m1-workspace-schema-v2.md](m1-workspace-schema-v2.md)

---

## Implementation queue

| Done | ID | Document | Summary |
| --- | --- | --- | --- |
| [x] | m0 | [m0-foundation.md](m0-foundation.md) | Static SQLite M0 (shipped) |
| [x] | m1a | [m1-global-schema-v2.md](m1-global-schema-v2.md) | Global DB migration v2 tables (gap: `syntax_schemes`, FK on `saved_models`) |
| [ ] | m1b | [m1-workspace-schema-v2.md](m1-workspace-schema-v2.md) | **NEXT** — Workspace DB chat schema + split migrations |
| [x] | m1c | [m1-read-through-workspace-state.md](m1-read-through-workspace-state.md) | `uWorkspaceState` → SQLite repos |
| [x] | m1d | [m1-read-through-workspace-registry.md](m1-read-through-workspace-registry.md) | `uWorkspaceRegistry` → SQLite |
| [ ] | m1e | [m1-read-through-chat-sessions.md](m1-read-through-chat-sessions.md) | `uChatSessionStore` → SQLite |
| [ ] | m1f | [m1-read-through-syntax-schemes.md](m1-read-through-syntax-schemes.md) | `uSyntaxSchemeRegistry` → SQLite |
| [x] | m1g | [m1-startup-open-global-db.md](m1-startup-open-global-db.md) | Open `global.db` at app startup |
| [ ] | m5 | [m5-user-help-storage.md](m5-user-help-storage.md) | In-app User Guide (storage topics) |
| [ ] | m6a | [m6-rag-schema-migration.md](m6-rag-schema-migration.md) | RAG tables + FTS5 (future) |
| [ ] | m6b | [m6-rag-hybrid-retrieval.md](m6-rag-hybrid-retrieval.md) | Hybrid retrieval Phase A |
| [ ] | m6c | [m6-remote-knowledge-brain-backends.md](m6-remote-knowledge-brain-backends.md) | Remote KB / Brain APIs |
| [ ] | m6d | [m6-sqlite-vec-phase-b.md](m6-sqlite-vec-phase-b.md) | sqlite-vec Phase B (optional) |

### Cancelled — no legacy import

One-shot INI/JSON importers, startup orchestrator, `.bak` rename, and `LAZYCODINGAGENT_LEGACY_STORAGE` are **not** planned. Supported recovery: backup/restore `global.db` (and workspace DBs when chat migration ships). See [help/app-data-storage.md](../../help/app-data-storage.md) and parent plan §6.

| ID | Document |
| --- | --- |
| — | [m2-importer-ini-global.md](m2-importer-ini-global.md), [m2-importer-workspaces-json.md](m2-importer-workspaces-json.md), [m2-importer-sessions-json.md](m2-importer-sessions-json.md), [m2-importer-syntax-schemes.md](m2-importer-syntax-schemes.md) |
| — | [m3-migration-orchestrator.md](m3-migration-orchestrator.md), [m3-legacy-storage-flag.md](m3-legacy-storage-flag.md), [m3-cutover-default-sqlite.md](m3-cutover-default-sqlite.md) |
| — | [m4-importer-fixtures-tests.md](m4-importer-fixtures-tests.md) |

---

## Milestone bands

| Band | Theme |
| --- | --- |
| M0 | Static engine, migration v1, first repository, tests (done) |
| M1 | Finish schema (workspace chat, `syntax_schemes`), wire chat/syntax stores — SQLite-only, no read-through |
| M5 | User-facing help for storage layout and backup |
| M6+ | Knowledge base / RAG (after M5) |

Recovery for app settings: quit the app, restore or replace `global.db` from backup ([help/app-data-storage.md](../../help/app-data-storage.md)).
