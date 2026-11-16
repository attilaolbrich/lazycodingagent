# 004 — Storage help

Depends on: [003-task-syntax-scheme-repository.md](003-task-syntax-scheme-repository.md) checked. Chat and syntax schemes are on SQLite.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

The in-app User Guide and the README describe where data lives, how to back it up, and how to recover it. A person can find that topic from Help search.

This task is documentation plus a small test that the help index still parses. Do not change database code unless you discover a factual error in the docs; if behavior is wrong, stop and report it instead of "fixing" it while rewriting help.

## 2. Out of scope

- Do not add importers, legacy flags, or a settings-export menu.
- Do not change schema.
- Do not document sqlite-vec, RAG, or The Brain as if they exist.

## 3. Read these files first

- [`help/app-data-storage.md`](../help/app-data-storage.md)
- [`help/index.json`](../help/index.json)
- [`help/chat-and-modes.md`](../help/chat-and-modes.md) and [`help/getting-started.md`](../help/getting-started.md) — fix only sentences that still say chat or schemes are JSON files.
- [`README.md`](../README.md) sections that mention `global.db`, sessions, or syntax schemes.
- [`uHelpContent.pas`](../uHelpContent.pas) — how `index.json` is loaded, so the file stays valid JSON.
- [`.cursor/rules/user-help.mdc`](../.cursor/rules/user-help.mdc) — help style: plain Markdown, no mermaid in help bodies.

## 4. Design decisions already made

- One topic is enough: keep id `app-data-storage`. Do not add a second storage article.
- Paths:
  - Config root: `GetAppConfigDir` + `lazycodingagent/`.
  - `global.db` — settings, workspace registry, LLM and web-search and MCP secrets (encrypted blobs), panel layout, browser prefs, syntax schemes.
  - `workspaces/<workspaceId>/workspace.db` — chat sessions, messages, session prefs.
  - On disk in the project folder, not in SQLite: `.rules/*.md`, `.plan/*.md`, source files.
  - Shipped help stays beside the executable, not in SQLite.
- Recovery: quit the app, then replace `global.db` and, for chat, the matching `workspace.db`. Deleting `global.db` resets settings and the workspace list; it does not delete the user's project folder. Say that clearly.
- State that there is no INI/JSON import and no `LAZYCODINGAGENT_LEGACY_STORAGE`.
- Secrets: describe the real mechanism in [`data/uSecurityManager.pas`](../data/uSecurityManager.pas) (prefix `lca-sec:v2:`, obfuscation, not a defense against someone who has the binary and the database). Do not claim AES-256-GCM or SQLCipher unless the code actually does that. Read the unit before writing the sentence.
- Keywords to have on the `app-data-storage` object: `sqlite`, `database`, `backup`, `global.db`, `workspace.db`, `migration`, `encrypted`, `api key`. Keep keywords that are still true. Remove `legacy` and `ini` if the body no longer tells people to use INI files.

## 5. Step-by-step implementation

1. Rewrite [`help/app-data-storage.md`](../help/app-data-storage.md) so every sentence matches sections 4. Use short headings: Location, What is stored, Secrets, Recovery.
2. Update [`help/index.json`](../help/index.json) keywords for that topic. The file must remain a JSON array. Do not break other entries.
3. Search `help/*.md` and `README.md` for `syntax-schemes.json`, `sessions/<`, and "JSON persistence". Update the ones that are now false. Leave historical future-plan documents alone.
4. Add a console check if one does not already exist: a few lines in an existing test, or `tests/test_help_index.lpr`, that loads `help/index.json` with `fpjson`, asserts an entry with `"id": "app-data-storage"` exists, and asserts the keywords include `workspace.db` and `backup`. Resolve the `help/` path relative to the repo when the test is run from `tests/run_tests.sh` (pass the path as an argument, the same pattern as `test_agent_rules`).
5. Wire that test into [`tests/run_tests.sh`](../tests/run_tests.sh). If it is plain `fpc` without SQLite, compile it like `test_mcp_mentions` (no `lazbuild` required).

## 6. Security

- The help text must tell users to quit the app before copying database files (WAL sidecars `-wal` and `-shm` belong with the copy; say to copy those too if they exist, or checkpoint by quitting first).
- Do not paste real key material, connection strings, or example API keys.
- Do not tell users to chmod the database world-readable as a fix.

## 7. Speed

- Help text stays a single small markdown file. Do not embed images.
- The index test reads one JSON file. No database.

## 8. Cloud extraction seam

The article describes the local desktop layout only. Add one sentence: a future hosted knowledge base or brain is not stored in these files. Do not design that API here.

## 9. Tests

```bash
bash tests/run_tests.sh
```

If the full script is too heavy because optional tools are missing, run at least the new help-index test and `lazbuild tests/test_app_database.lpi && tests/test_app_database`. Record which commands you ran. The help-index test is mandatory.

## 10. README and help updates

This task **is** the README and help update. Section 5 is the work.

Also add a short "Application data" pointer in [`README.md`](../README.md) to `help/app-data-storage.md` if the README does not already link it.

## 11. Done when

- [ ] Help topic matches real tables and paths after tasks 001–003.
- [ ] Search keywords include `sqlite`, `backup`, and `workspace.db`.
- [ ] No help sentence sends users through a cancelled importer.
- [ ] Help index test passed.
- [ ] Checkbox 004 checked, **NEXT** is task 005.

## 12. Stop

Do not start trace tables.
