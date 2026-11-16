# 001 — Workspace chat schema

Depends on: nothing in this queue. Global SQLite v3 is already shipped.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

Split database migrations so `global.db` and `workspaces/<wsId>/workspace.db` do not share one DDL script.

After this task:

- A new `global.db` still ends at schema version **3** with today's tables (`app_settings`, `workspaces`, `llm_providers`, `saved_models`, `panel_layout`, `web_search_connections`, `mcp_connections`). It does **not** contain `sessions`, `messages`, or `session_prefs`.
- A new `workspace.db` ends at schema version **1** and contains only `schema_migrations`, `sessions`, `messages`, and `session_prefs`.
- No menu or chat behavior changes yet. Chat still uses JSON until task 002.

## 2. Out of scope

- Do not wire [`uChatSessionStore.pas`](../uChatSessionStore.pas) to SQLite (task 002).
- Do not add `syntax_schemes` (task 003).
- Do not drop or rewrite existing global v1–v3 SQL. Databases already in the field have those versions recorded.
- Do not import old `sessions/<id>.json` files.
- Do not add RAG, trace, plan, or brain tables.

## 3. Read these files first

- [`uAppDatabase.pas`](../uAppDatabase.pas) — `RunMigrations` (about lines 151–260), `OpenDatabaseFile`, `OpenWorkspace`, `WorkspaceSettings`, `SchemaVersion`.
- [`tests/test_app_database.lpr`](../tests/test_app_database.lpr) — expects global version 3 and, today, workspace version 3 plus `WorkspaceSettings`.
- [`future-plan/Lazarus_Embedded_Storage_and_Vector_Plan.md`](../future-plan/Lazarus_Embedded_Storage_and_Vector_Plan.md) section 5.2.
- [`uChatSessionStore.pas`](../uChatSessionStore.pas) `TChatSessionInfo` — four permission flags that must be columns now so task 002 does not need another migration.

## 4. Design decisions already made

- `OpenDatabaseFile` takes a scope. `OpenGlobal` calls global migrations. `OpenWorkspace` calls workspace migrations. Do not pass one function that applies both.
- Fresh workspace version is **1**, not 2 and not 3. Version 3 is the global MCP migration. Reusing that number on workspace files is what this task stops.
- Workspace DDL does **not** create `app_settings` or any global registry/LLM/MCP table.
- `TAppDatabase.WorkspaceSettings` is only called from the test. Remove that method. Nothing else in the app uses it. Per-workspace settings are not this task.
- Chat permission flags live on `sessions` because they are per session today: `allow_modify_outside`, `allow_browser_localhost`, `allow_browser_interactive`, `allow_browser_sensitive` (`INTEGER NOT NULL DEFAULT 0`).
- Message attachments are not in the old sketch. Add `attachments_json TEXT NOT NULL DEFAULT '[]'` beside `tool_calls_json`. Task 002 stores the same JSON shape `MessageToJson` writes for `toolCalls` and `attachments`.
- Wrap each new workspace migration in `BEGIN IMMEDIATE` … `COMMIT`. On exception `ROLLBACK` and re-raise. Do not change the historical global v1–v3 statements into a different shape; only stop running them on workspace files.
- Existing buggy `workspace.db` files may already be at version 3 **with global tables** and no `sessions` table. If `schema_migrations` max version is greater than 0 and `sessions` does not exist, run only the chat `CREATE TABLE` statements and record the next version (`current + 1`). Do not re-run global DDL. Do not `DROP` the mistaken global tables in this task. Fresh temp databases used by tests never hit this branch and stay at version 1.
- Identifiers passed into SQL are bound or are the fixed DDL strings in this file. Do not concatenate workspace ids into SQL. Path safety stays in `SanitizeWorkspaceId` (letters, digits, `-`, `_` only).

## 5. Step-by-step implementation

1. In `uAppDatabase.pas`, rename the current body of `RunMigrations` to `RunGlobalMigrations`. Leave the SQL text for versions 1, 2, and 3 unchanged.
2. Add `RunWorkspaceMigrations`. If version is 0 (no `schema_migrations` table, same `SQLITE_ERROR` detection as `QuerySchemaVersion` today):
   - Create `schema_migrations` exactly as global v1 does (`version INTEGER PRIMARY KEY`, `applied_at TEXT NOT NULL`).
   - Create:

```sql
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  created_at TEXT NOT NULL,
  modified_at TEXT NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0,
  archived_at TEXT,
  allow_modify_outside INTEGER NOT NULL DEFAULT 0,
  allow_browser_localhost INTEGER NOT NULL DEFAULT 0,
  allow_browser_interactive INTEGER NOT NULL DEFAULT 0,
  allow_browser_sensitive INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE messages (
  session_id TEXT NOT NULL,
  seq INTEGER NOT NULL,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  tool_call_id TEXT NOT NULL DEFAULT '',
  tokens_used INTEGER NOT NULL DEFAULT 0,
  visual_summary TEXT NOT NULL DEFAULT '',
  tool_calls_json TEXT NOT NULL DEFAULT '[]',
  attachments_json TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL,
  PRIMARY KEY (session_id, seq),
  FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

CREATE TABLE session_prefs (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE INDEX idx_messages_session ON messages(session_id);
CREATE INDEX idx_sessions_archived ON sessions(archived);
```

   - `RecordMigration` version **1**.
3. Add the compatibility branch from section 4 for a database that already has `schema_migrations` but no `sessions` table. Detect the missing table with `SELECT 1 FROM sqlite_master WHERE type='table' AND name='sessions'`.
4. Change `OpenDatabaseFile` so the caller chooses the runner. `OpenGlobal` uses global. `OpenWorkspace` uses workspace.
5. Delete `WorkspaceSettings` from the class declaration and implementation.
6. Update [`tests/test_app_database.lpr`](../tests/test_app_database.lpr):
   - Keep global round-trip and version **3**.
   - Workspace test: after `OpenWorkspace('test-ws-1')`, `SchemaVersion(adsWorkspace, 'test-ws-1')` is **1**.
   - Do not call `WorkspaceSettings`.
   - Add a helper that prepares `SELECT name FROM sqlite_master WHERE type='table' AND name=?1` on the open database. You need a small public test hook because the sqlite handle is private. Add `class function TableExists(AScope: TAppDatabaseScope; const AWsId, ATable: string): Boolean` on `TAppDatabase`. It uses a bound parameter. Return false when the database is not open.
   - Assert workspace has `sessions`, `messages`, `session_prefs`.
   - Assert workspace does **not** have `workspaces`, `llm_providers`, `mcp_connections`, `saved_models`.
   - Assert global does **not** have `sessions` or `messages`.
   - Assert `SanitizeWorkspaceId` still rejects `../` and empty id: call `OpenWorkspace('../evil')` and expect an exception (use try/except, fail the test if it does not raise).
7. [`tests/run_tests.sh`](../tests/run_tests.sh) already builds and runs `tests/test_app_database`. Do not add a second copy.

## 6. Security

- Reject workspace ids that are not `[A-Za-z0-9_-]+` before any path join. This already exists; keep it and test it.
- `foreign_keys=ON` stays in `ApplyPragmas` so deleting a session cannot leave message rows behind once task 002 deletes sessions.
- No secrets are stored in these tables. Do not put API keys in `session_prefs`.

## 7. Speed

- Keep `journal_mode=WAL` and `busy_timeout=5000`.
- The two indexes above are required so task 002 can list messages by session without a full scan.
- Do not run global and workspace DDL on the same file.

## 8. Cloud extraction seam

This task is local schema only. Do not add an HTTP client. Later chat storage goes through `IChatSessionRepository` (task 002), not through this unit's SQL, from the UI.

## 9. Tests

Run:

```bash
lazbuild tests/test_app_database.lpi && tests/test_app_database
```

The program must print `SQLite app database tests passed.` and exit 0.

If `lazbuild` is missing, do not check the box. Say so in the session summary.

## 10. README and help updates

No user-visible storage change yet (chat is still JSON). Do not rewrite [`help/app-data-storage.md`](../help/app-data-storage.md) in this task. Do not claim chat is in SQLite in [`README.md`](../README.md).

## 11. Done when

- [ ] `OpenGlobal` and `OpenWorkspace` use different migration procedures.
- [ ] Fresh workspace schema version is 1 and has the three chat tables plus the four permission columns and `attachments_json`.
- [ ] Fresh global schema version is still 3 and has no chat tables.
- [ ] `WorkspaceSettings` is gone.
- [ ] `tests/test_app_database` passed with the command in section 9.
- [ ] Checkbox for 001 in [README.md](README.md) is checked and **NEXT** points at task 002.

## 12. Stop

Do not start task 002. Do not edit other unchecked task files.
