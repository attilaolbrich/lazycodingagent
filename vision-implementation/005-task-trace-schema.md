# 005 — Execution trace schema

Depends on: [004-task-storage-help.md](004-task-storage-help.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

`workspace.db` can store a redacted execution trace: who asked, what was sent to the model (already redacted), tool name, arguments, result, and assistant text.

Nothing in the UI changes. The in-memory log in [`uAgentExecutionLog.pas`](../uAgentExecutionLog.pas) still works as today. This task is schema plus repository plus tests. Task 006 connects the engine.

## 2. Out of scope

- Do not change `TAgentEngine` to write rows (task 006).
- Do not add export (task 007) or plan tables (task 008).
- Do not record chain-of-thought or hidden provider reasoning. If the provider does not send it, do not invent it.

## 3. Read these files first

- [`uAgentExecutionLog.pas`](../uAgentExecutionLog.pas) — `TExecutionLogKind` = `elUserPrompt`, `elToolExecution`, `elAssistantResponse`, `elLlmWire`. Fields on `TExecutionLogEntry`.
- [`uAgentEngine.pas`](../uAgentEngine.pas) — where `AddUserPrompt`, `AddTool`, `AddAssistant`, `AddLlmWire` are called, so the columns match those arguments. Search for `FExecutionLog.Add`.
- [`uAppDatabase.pas`](../uAppDatabase.pas) — workspace migration runner from task 001. Current workspace version is **1**. This task adds version **2**.

## 4. Design decisions already made

- Workspace migration **v2** only. Chat tables from v1 stay. Do not rebuild them.
- Kind strings, exact spelling: `user_prompt`, `tool`, `assistant`, `llm_wire`.
- `payload_text` is the exact redacted body to show in Execution Detail later. `summary_text` is the short caption/summary. Do not collapse them into one column.
- One trace has many entries. `seq` starts at 1 for each trace.

```sql
CREATE TABLE execution_traces (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);

CREATE TABLE execution_trace_entries (
  trace_id TEXT NOT NULL,
  seq INTEGER NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('user_prompt','tool','assistant','llm_wire')),
  created_at TEXT NOT NULL,
  summary_text TEXT NOT NULL DEFAULT '',
  payload_text TEXT NOT NULL DEFAULT '',
  tool_name TEXT NOT NULL DEFAULT '',
  tool_args_json TEXT NOT NULL DEFAULT '',
  tool_output_json TEXT NOT NULL DEFAULT '',
  tool_success INTEGER NOT NULL DEFAULT 0,
  step INTEGER NOT NULL DEFAULT 0,
  max_steps INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (trace_id, seq),
  FOREIGN KEY (trace_id) REFERENCES execution_traces(id) ON DELETE CASCADE
);

CREATE INDEX idx_trace_entries_trace ON execution_trace_entries(trace_id, seq);
CREATE INDEX idx_traces_session ON execution_traces(session_id);
```

- Interface GUID: `{D1A4E6B8-0C72-4F55-8A19-3B6D7E2C9041}`

```pascal
TTraceEntryRow = record
  Seq: Integer;
  Kind: string;
  CreatedAt: string;
  SummaryText: string;
  PayloadText: string;
  ToolName: string;
  ToolArgsJson: string;
  ToolOutputJson: string;
  ToolSuccess: Boolean;
  Step: Integer;
  MaxSteps: Integer;
end;
TTraceEntryRows = array of TTraceEntryRow;

IExecutionTraceRepository = interface
  ['{D1A4E6B8-0C72-4F55-8A19-3B6D7E2C9041}']
  function StartTrace(const ASessionId: string): string;
  procedure AppendEntry(const ATraceId: string; const AEntry: TTraceEntryRow);
  procedure LoadEntries(const ATraceId: string; out ARows: TTraceEntryRows);
  function FindTrace(const ATraceId: string; out ASessionId, ACreatedAt: string): Boolean;
  procedure DeleteTrace(const ATraceId: string);
end;
```

- `StartTrace` generates id `trace_` + hex ticks. `AppendEntry` assigns `seq` as `MAX(seq)+1` inside a transaction if `AEntry.Seq <= 0`. If the caller passes `Seq > 0`, use it only when that `(trace_id, seq)` is free; otherwise raise.
- `TAppDatabase.ExecutionTraces(AWsId)` returns the repository for an open workspace database.
- Repository unit: `data/sqlite/uSqliteExecutionTraceRepository.pas`.
- No API key columns. The repository does not call `EncryptSecret`. Callers must already have redacted wire JSON. This task's tests pass redacted strings only.

## 5. Step-by-step implementation

1. Add workspace migration v2 in `RunWorkspaceMigrations`, one transaction, `RecordMigration` 2.
2. If a buggy pre-001 database took the compatibility path and its version is not 1, still add this DDL as the next version when `execution_traces` is missing. Fresh tests expect version **2** after open. Document the number you assert: fresh file created by current `OpenWorkspace` must be version 2. Update the task 001 test assertion that expected workspace version **1** so the suite stays green (those tests now see version 2). Do not remove their table-presence checks.
3. Add the interface and SQLite class. Bound parameters only.
4. Register the unit in `lazycodingagent.lpi` and the test `.lpi`.
5. Tests:
   - Fresh workspace schema version is 2.
   - `sessions` still exists.
   - Start a trace, append one of each kind, close, reopen, `LoadEntries` returns 4 rows in seq order with payload text unchanged.
   - `DeleteTrace` removes entries (cascade). Assert zero rows. You may add `class function Scalar(AScope, AWsId, ASQL): string` only if you cannot see the count through the repository. Prefer `LoadEntries` length 0 after delete.
   - Append with kind `nope` fails the CHECK. The test expects an exception and the trace has no extra row.
   - Global database has no `execution_traces` table.

## 6. Security

- Do not add a column for raw provider keys.
- `payload_text` is still sensitive (source code, prompts). The repository does not write it to a log file.
- `DeleteTrace` is the hook task 007 and a later privacy action will use. Cascade must work. Test it.
- Workspace id stays sanitized by `OpenWorkspace`.

## 7. Speed

- Index `(trace_id, seq)` is required.
- `AppendEntry` is one insert. Do not reload the whole trace after each append inside the repository.
- WAL and `busy_timeout` stay as they are.

## 8. Cloud extraction seam

`IExecutionTraceRepository` is the port. The engine must not learn SQL in task 006. A hosted trace service can implement the same interface later. Do not add HTTP here.

## 9. Tests

```bash
lazbuild tests/test_app_database.lpi && tests/test_app_database
```

Add cases to that program unless the `.lpi` cannot see the new unit; then add the unit to the `.lpi`.

## 10. README and help updates

No user-visible change. Do not document replay yet. You may add one sentence to [`help/app-data-storage.md`](../help/app-data-storage.md): workspace databases also store execution traces for the session (redacted). Add keyword `execution trace` on that help entry.

Mention traces in the README storage bullet in one sentence.

## 11. Done when

- [ ] Workspace migration creates the two tables and indexes; chat tables remain.
- [ ] Repository round-trip and cascade delete pass.
- [ ] Invalid kind does not insert.
- [ ] Help/README one-liners added.
- [ ] Checkbox 005 checked, **NEXT** is task 006.

## 12. Stop

Do not hook the agent engine.
