# 003 — Syntax scheme repository

Depends on: [002-task-chat-session-repository.md](002-task-chat-session-repository.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

Syntax highlighting schemes load and save in `global.db`. The editor still highlights with the active scheme. Built-in "Generic C-like" is present on a new database. Custom schemes round-trip after edit, import, and remove.

The app stops writing `syntax-schemes.json` and `syntax-schemes/<id>.json` at runtime. Existing JSON files are not imported and are not deleted.

## 2. Out of scope

- Do not change SynEdit gutter colors or theme hooks.
- Do not add a JSON importer.
- Do not store schemes in `workspace.db` (schemes are global).
- Do not start the storage help pass (task 004) beyond the sentences this task must fix so the docs are not wrong.

## 3. Read these files first

- [`uSyntaxSchemeRegistry.pas`](../uSyntaxSchemeRegistry.pas) — `Load`, `Save`, `ImportFromFile`, `Remove`, `EnsureBuiltinSchemeFile`, `BuiltinSchemeJson`, `SetActive`.
- [`uSyntaxScheme.pas`](../uSyntaxScheme.pas) — how a scheme JSON body becomes `TSyntaxScheme`.
- [`uAppDatabase.pas`](../uAppDatabase.pas) — `RunGlobalMigrations` ends at version 3 after task 001. [`tests/test_app_database.lpr`](../tests/test_app_database.lpr) asserts global version 3. You will change that assertion to **4**.
- [`data/sqlite/uSqliteAppSettingsRepository.pas`](../data/sqlite/uSqliteAppSettingsRepository.pas) — SQL style.

## 4. Design decisions already made

- New **global** migration version **4** only. Do not edit the SQL of versions 1–3.
- Table:

```sql
CREATE TABLE syntax_schemes (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  built_in INTEGER NOT NULL DEFAULT 0,
  json_body TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

- Seed the built-in row in the same migration, inside the same transaction as `CREATE TABLE` and `INSERT INTO schema_migrations`. Id `builtin-generic`. Name `Generic C-like`. `built_in` 1. `json_body` is the current `BuiltinSchemeJson` text. `updated_at` is a fixed UTC-looking stamp `2026-01-01T00:00:00` so the migration is deterministic.
- If a database is already at version 4 or the table exists, do not insert a second seed. `INSERT` the seed only in the version 4 migration, which runs once.
- Active scheme id is `app_settings` key `syntax.active_id` (type `string`). If the key is missing, active id is `builtin-generic`.
- `Remove` refuses when `built_in` is 1 and returns an error string. Same user-visible outcome as today if the built-in file could not be deleted.
- Import assigns a new id (`scheme_` plus hex tick count, same style as `NewSessionId` if the current import already has an id generator — keep the current id generator if one exists). `built_in` 0. Store the file's JSON text as `json_body` after the existing validation that it parses as a scheme. If validation fails, write nothing.
- `Save` writes the in-memory entries back with `INSERT ... ON CONFLICT(id) DO UPDATE`. Do not delete the built-in row.
- Interface GUID: `{C8F02B17-6A44-4E29-B1D0-5A7C3E9F2408}`

```pascal
TSyntaxSchemeRow = record
  Id: string;
  Name: string;
  JsonBody: string;
  UpdatedAt: string;
  BuiltIn: Boolean;
end;
TSyntaxSchemeRows = array of TSyntaxSchemeRow;

ISyntaxSchemeRepository = interface
  ['{C8F02B17-6A44-4E29-B1D0-5A7C3E9F2408}']
  procedure LoadAll(out ARows: TSyntaxSchemeRows);
  procedure Upsert(const ARow: TSyntaxSchemeRow);
  function DeleteCustom(const AId: string; out AError: string): Boolean;
end;
```

`DeleteCustom` returns false and sets `AError` when the row is missing or `built_in` is 1. It does not raise for that case.

## 5. Step-by-step implementation

1. Add global migration v4 in `RunGlobalMigrations` only, one transaction.
2. Add the interface to [`data/uRepositoryInterfaces.pas`](../data/uRepositoryInterfaces.pas).
3. Add [`data/sqlite/uSqliteSyntaxSchemeRepository.pas`](../data/sqlite/uSqliteSyntaxSchemeRepository.pas) using bound parameters.
4. Add `TAppDatabase.GlobalSyntaxSchemes: ISyntaxSchemeRepository` which requires the global database to be open.
5. Change `TSyntaxSchemeRegistry` to load and save through that repository. `EnsureLoaded` calls `TAppDatabase.OpenGlobal` if the app database is not already open (startup already opens it; the test will open it).
6. Stop calling `SyntaxSchemesDir` and `SyntaxSchemesIndexFile` from Load/Save/Import/Remove. Delete those writes. Keep the functions only if an external unit still references them; if nothing does, remove them.
7. Register the unit in [`lazycodingagent.lpi`](../lazycodingagent.lpi) and the test `.lpi`.
8. Tests (extend `test_app_database` or add `tests/test_syntax_schemes.lpr` plus a `run_tests.sh` line):
   - Fresh global database schema version is **4**. Update the old assertions that expected **3**.
   - `syntax_schemes` contains `builtin-generic` with `built_in` true.
   - Upsert a custom scheme, close, reopen, `LoadAll` returns it with the same `json_body`.
   - `DeleteCustom('builtin-generic')` returns false and the row remains.
   - `DeleteCustom` on the custom id returns true and the row is gone.
   - Workspace database from task 001 is still version 1 and has no `syntax_schemes` table (`TableExists`).

## 6. Security

- Scheme JSON is data. Bind it. Do not `sqlite3_exec` a string that includes the JSON body.
- Import reads a user-chosen file path only inside `ImportFromFile`, which already receives a path from a dialog. Do not expand that into directory traversal of the config dir. Read the file, validate JSON, then upsert. If the file is larger than 1 MiB, reject it with an error string (schemes are small). This cap is new; add it.
- Built-in row cannot be deleted.

## 7. Speed

- `LoadAll` is one query, not one query per scheme.
- Do not pretty-print or re-parse the JSON body on every editor keystroke. The registry already keeps `FActiveScheme` in memory; keep that. Hit SQLite on Load, Save, Import, Remove, and SetActive (settings key only).

## 8. Cloud extraction seam

`ISyntaxSchemeRepository` is the port. The registry does not embed SQL. A hosted scheme service is not part of this task; do not add HTTP.

## 9. Tests

```bash
lazbuild tests/test_app_database.lpi && tests/test_app_database
```

Plus the new program if you split it, wired into [`tests/run_tests.sh`](../tests/run_tests.sh).

## 10. README and help updates

- [`README.md`](../README.md) — syntax schemes are in `global.db`, not `syntax-schemes.json`.
- [`help/app-data-storage.md`](../help/app-data-storage.md) — list syntax schemes under `global.db`. Remove them from the JSON list. If the JSON list becomes empty, delete that subsection instead of leaving a placeholder. Chat text should already say `workspace.db` from task 002; do not revert it.
- Do not add a new help topic; task 004 does the full storage pass.

## 11. Done when

- [ ] Global migration v4 creates and seeds `syntax_schemes` once.
- [ ] Registry does not write `syntax-schemes.json` or per-id JSON files.
- [ ] Tests cover seed, custom round-trip, built-in delete refusal, and workspace DB unchanged.
- [ ] Global version assertion is 4 everywhere the test checks it.
- [ ] README and `help/app-data-storage.md` match.
- [ ] Checkbox 003 checked, **NEXT** is task 004.

## 12. Stop

Do not start task 004's extra help topics beyond section 10.
