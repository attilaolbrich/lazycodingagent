# 002 — Chat session repository

Depends on: [001-task-workspace-chat-schema.md](001-task-workspace-chat-schema.md) merged and checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

Chat sessions for a workspace load and save through SQLite `workspace.db`. The Sessions panel, archive, delete, last active session, and the four per-session permission toggles behave as they do today.

New installs do not create `sessions/<workspaceId>.json`. Existing JSON files are left on disk and are **not** read.

## 2. Out of scope

- Do not write a JSON importer.
- Do not change chat UI layout or composer behavior.
- Do not move syntax schemes (task 003).
- Do not put message text into `global.db`.

## 3. Read these files first

- [`uChatSessionStore.pas`](../uChatSessionStore.pas) — public methods on `TChatSessionStore`, `MessageToJson`, `MessageFromJson`, `TChatSessionInfo`.
- [`uAgentTypes.pas`](../uAgentTypes.pas) — `TChatMessage` (role, content, toolCallId, tool calls, attachments, timestamp, tokensUsed, visualSummary).
- [`data/uRepositoryInterfaces.pas`](../data/uRepositoryInterfaces.pas) and [`data/sqlite/uSqliteAppSettingsRepository.pas`](../data/sqlite/uSqliteAppSettingsRepository.pas) — bind parameters with `?1`, `sqlite3_prepare_v2`, `sqlite3_finalize` in `finally`, `SqliteCheck`.
- [`uAppDatabase.pas`](../uAppDatabase.pas) — `OpenWorkspace`, `ConfigRoot`. After task 001 there is no `WorkspaceSettings`.
- [`tests/test_app_database.lpi`](../tests/test_app_database.lpi) — copy this project when you add a new test program, or extend it if the new units are listed in the `.lpi`.

## 4. Design decisions already made

- Keep every public method of `TChatSessionStore`. Callers (main form, chat panel) stay source-compatible.
- The repository is the only unit that runs chat SQL.
- `lastSessionId` is the `session_prefs` row with key `last_session_id`. Do not also write `workspaces.last_session_id` from this store (that column is the registry's last session and is a different feature).
- `ReplaceMessages` deletes existing rows for that session and inserts `seq` 1, 2, 3… in one transaction. Seq is monotonic for that write. Do not update rows in place.
- Store `tool_calls_json` and `attachments_json` as the JSON arrays `MessageToJson` already builds (`toolCalls`, `attachments`). Reuse `MessageToJson` / `MessageFromJson` rather than a second parser. You may make those two functions usable from the repository unit (move them to a shared unit only if the uses-cycle requires it). Do not drop attachment fields.
- Map permission booleans to the integer columns added in task 001. `0` is false, anything else is true.
- Timestamps stay ISO text `yyyy-mm-ddThh:nn:ss`, the format already used by `DateTimeToJsonIso`.
- `BindWorkspace` opens that workspace database via `TAppDatabase.OpenWorkspace`. Empty workspace id does not create a file.
- `DeleteSession` deletes the `sessions` row and relies on `ON DELETE CASCADE` for messages. Then if `last_session_id` pointed at it, set the pref to the previous remaining session or `''`.
- `DeleteAllForWorkspace` deletes all sessions for that database (the database is already one workspace).
- No read of `sessions/<id>.json` at runtime. You may leave the unused path helpers unreferenced; delete them if nothing else calls them. Do not delete user JSON files from disk.

Interface GUID (do not reuse an existing one): `{B7E1A9C4-2D55-4F0A-9C31-6E8A0B4D17F2}`

```pascal
TChatSessionRow = record
  Id: string;
  Title: string;
  CreatedAt: string;
  ModifiedAt: string;
  ArchivedAt: string;
  Archived: Boolean;
  AllowModifyOutside: Boolean;
  AllowBrowserLocalhost: Boolean;
  AllowBrowserInteractive: Boolean;
  AllowBrowserSensitive: Boolean;
end;
TChatSessionRows = array of TChatSessionRow;

IChatSessionRepository = interface
  ['{B7E1A9C4-2D55-4F0A-9C31-6E8A0B4D17F2}']
  procedure ListSessions(out ARows: TChatSessionRows);
  function FindSession(const ASessionId: string; out ARow: TChatSessionRow): Boolean;
  procedure UpsertSession(const ARow: TChatSessionRow);
  procedure DeleteSession(const ASessionId: string);
  procedure DeleteAllSessions;
  procedure LoadMessages(const ASessionId: string; out AMessages: TChatMessageArray);
  procedure ReplaceMessages(const ASessionId: string; const AMessages: TChatMessageArray);
  function GetPref(const AKey: string): string;
  procedure SetPref(const AKey, AValue: string);
end;
```

`TChatMessage` / `TChatMessageArray` live in `uAgentTypes`. The interface unit may use `uAgentTypes`.

## 5. Step-by-step implementation

1. Add the types and `IChatSessionRepository` to [`data/uRepositoryInterfaces.pas`](../data/uRepositoryInterfaces.pas).
2. Create [`data/sqlite/uSqliteChatSessionRepository.pas`](../data/sqlite/uSqliteChatSessionRepository.pas):
   - `TSqliteChatSessionRepository = class(TInterfacedObject, IChatSessionRepository)`.
   - Constructor takes `PSqlite3`. Raise if nil.
   - All statements use bound parameters. Never build SQL with session titles or message content.
   - `ReplaceMessages` and `DeleteSession`: `BEGIN IMMEDIATE` / `COMMIT`, `ROLLBACK` on exception.
   - List order: `modified_at DESC, id`.
   - Load messages: `ORDER BY seq`.
3. Add `class function ChatSessions(const AWsId: string): IChatSessionRepository` on `TAppDatabase`. It requires `OpenWorkspace` already called, same lookup pattern the old `WorkspaceSettings` used (`GWorkspaceDbs`). Raise a clear exception if that workspace is not open.
4. Refactor `TChatSessionStore` so load/save/list/archive/permissions/last session call the repository. Remove runtime use of `SessionFilePath`, `ReadRootFromFile`, and `WriteRootToFile`.
5. `CreateSession` still uses `NewSessionId`, sets created and modified to now, archived false, all allow-flags false, empty message list, and returns the id.
6. Add the new unit to [`lazycodingagent.lpi`](../lazycodingagent.lpi) next to `uSqliteMcpRepository.pas` (`<Unit><Filename Value="data\sqlite\uSqliteChatSessionRepository.pas"/>…`).
7. Add the unit to the test `.lpi` as well.
8. Tests in `tests/test_app_database.lpr` or a new `tests/test_chat_sessions.lpr` cloned from that `.lpi`:
   - Temp config root via `SetConfigRootOverride`. `OpenWorkspace('chat-ws')`.
   - Upsert two sessions. Replace messages on the first: user text, assistant text, one tool call JSON, one attachment JSON, `tokens_used` 12.
   - Close and reopen. Load messages. Assert role, content, tool call id/name/arguments, attachment path, token count, seq order.
   - Set `last_session_id`. Reopen. Assert pref.
   - Archive one session. Assert `archived` and `archived_at` survive reopen.
   - Set `AllowModifyOutside` true. Reopen. Assert the flag.
   - Delete the session. Assert messages are gone (`LoadMessages` returns empty and `FindSession` is false).
   - `DeleteAllSessions` leaves zero sessions.
   - Call `OpenWorkspace('bad/id')` and expect an exception (no directory named `bad/id` created under the temp root).

## 6. Security

- Session ids and message bodies are data, not SQL. Bind them.
- Permission flags must round-trip. Losing `allow_modify_outside` would silently change what the agent is allowed to touch. Test that flag.
- Do not log full message content from the repository.
- Workspace id still goes through `SanitizeWorkspaceId` before the path is built.

## 7. Speed

- One transaction per `ReplaceMessages`, not one transaction per message.
- Use the `idx_messages_session` index from task 001 (`WHERE session_id = ?1 ORDER BY seq`).
- Do not read every workspace database at startup. Open a workspace database when that workspace is bound, which is the current store behavior.

## 8. Cloud extraction seam

UI and engine keep calling `TChatSessionStore`. A later hosted chat service would implement `IChatSessionRepository` and be selected behind `TAppDatabase.ChatSessions` (or a future factory). Do not call sqlite from `mainunit.pas`.

## 9. Tests

If you extended `test_app_database`:

```bash
lazbuild tests/test_app_database.lpi && tests/test_app_database
```

If you added `tests/test_chat_sessions.lpi`, run that program the same way and add it inside the `lazbuild` block in [`tests/run_tests.sh`](../tests/run_tests.sh) immediately after `test_app_database`.

## 10. README and help updates

Update the persistence bullets so they match behavior:

- [`README.md`](../README.md) — the Embedded SQLite bullet and the `uChatSessionStore.pas` bullet currently say chat is JSON. Say chat sessions and messages are in `workspaces/<wsId>/workspace.db`. Say old JSON files are not imported.
- [`help/app-data-storage.md`](../help/app-data-storage.md) — move chat out of "Still on JSON". Say backup of chat is that `workspace.db` (quit the app first). Leave syntax schemes on JSON until task 003.
- [`help/chat-and-modes.md`](../help/chat-and-modes.md) — if it says sessions are stored as JSON, replace that sentence with the workspace database. Do not document an importer.

Add keyword `workspace.db` to the `app-data-storage` entry in [`help/index.json`](../help/index.json) if it is missing. Do not remove existing keywords.

## 11. Done when

- [ ] `TChatSessionStore` does not read or write `sessions/*.json` at runtime.
- [ ] Public methods of the store are unchanged.
- [ ] Messages, attachments, tool calls, archive, last session, and permission flags round-trip in the test.
- [ ] README and the two help topics match the new layout.
- [ ] The test command exited 0.
- [ ] Checkbox for 002 is checked and **NEXT** is task 003.

## 12. Stop

Do not start task 003.
