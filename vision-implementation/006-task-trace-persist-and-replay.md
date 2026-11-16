# 006 — Persist traces and replay

Depends on: [005-task-trace-schema.md](005-task-trace-schema.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

While an agent run records an execution log, the same entries are stored in the workspace database. Later, the user can open that trace in Execution Detail from stored rows.

Replay does **not** call the model and does **not** run tools. It only displays what was stored.

If the database write fails, the agent loop still finishes. The in-memory log still updates. Show a single status or tool-error line that the trace was not saved. Do not raise into the run.

## 2. Out of scope

- Do not add file export (task 007).
- Do not add multi-agent fields (task 021).
- Do not change tool behavior or prompts.
- Do not re-execute `AddTool` side effects during replay.

## 3. Read these files first

- [`uAgentEngine.pas`](../uAgentEngine.pas) — `AddUserPrompt`, `AddTool`, `AddAssistant`, `AddLlmWire`, `NotifyExecutionLogAdded`, `ClearConversation`.
- [`uAgentExecutionLog.pas`](../uAgentExecutionLog.pas) — entry fields and `BuildInspectorMarkdown`.
- [`mainunit.pas`](../mainunit.pas) — `ShowExecutionLogDetail`, `BindExecutionLogToNav`. Search those names.
- `IExecutionTraceRepository` from task 005.

## 4. Design decisions already made

- The engine keeps the in-memory `TAgentExecutionLog` for the live session. The repository is a second writer, not a replacement, so a failed insert does not blank the screen.
- On the first log entry of a run, `StartTrace` and remember the trace id on the engine (`FTraceId: string`). `ClearConversation` and a new user run start a new trace. Do not append a new run onto the previous trace id.
- Map kinds: `elUserPrompt` → `user_prompt`, `elToolExecution` → `tool`, `elAssistantResponse` → `assistant`, `elLlmWire` → `llm_wire`.
- `payload_text` for wire entries is the redacted request plus a newline plus the redacted response (the strings already passed to `AddLlmWire`). Do not read `FClient` for a second unredacted copy.
- `payload_text` for tools is `tool_output_json`. Arguments stay in `tool_args_json`.
- Session id stored on the trace is the active chat session id. If there is none, store `''`.
- Replay API, new unit `uTraceReplay.pas` (no SQL inside):

```pascal
function LoadTraceForDisplay(ARepo: IExecutionTraceRepository; const ATraceId: string;
  ALog: TAgentExecutionLog): Boolean;
```

  It `Clear`s `ALog` and adds entries with the existing `Add*` methods so Execution Detail stays the same viewer. It returns false if the trace id is unknown.

- A menu or list action: **Replay saved trace…** is too large if there is no list UI. Minimum UI: when opening Execution Detail, if `FTraceId` is non-empty, the detail is already live. Add a button on the existing execution-detail surface only if one already exists in the `.lfm`. If there is no natural button, add `Replay last saved trace` on the Workspace or View menu using the current session's latest trace. Repository needs one extra method, add it in this task (do not wait):

```pascal
function LatestTraceId(const ASessionId: string): string;
```

  SQL: `SELECT id FROM execution_traces WHERE session_id = ?1 ORDER BY created_at DESC LIMIT 1`. Empty string if none.

- Replay path must not call `ExecuteToolDirect`, `TLlmClient`, or HTTP units. `uTraceReplay.pas` uses clause must not include `uLlmClient` or `uAgentTools`.

## 5. Step-by-step implementation

1. Add `LatestTraceId` to the interface and SQLite repository.
2. Add a small writer class `TTraceLogSink` in `uTraceReplay.pas` or `uTraceSink.pas` with `procedure WriteEntry(ALogEntry: TExecutionLogEntry)` that maps fields and calls `AppendEntry`. The engine calls it from the same places it calls `NotifyExecutionLogAdded`.
3. Wrap sink calls in try/except. On failure set a flag and surface one message through the existing tool-error or status path (`NotifyToolErrorAdded` / run status). Do not except out of the model loop.
4. Wire menu or existing button to `LoadTraceForDisplay` + the existing detail form. Follow `.lfm` rules: published field, event in the `.lfm`, no manual `SetBounds`.
5. Tests in a new `tests/test_trace_replay.lpr` (clone `test_app_database.lpi`, no LCL forms required):
   - Build a repository on a temp workspace.
   - Append a tool entry whose output is `ran-tool`.
   - `LoadTraceForDisplay` into a fresh `TAgentExecutionLog`.
   - Assert count, kind, tool name, and output match.
   - Pass a fake callback counter only if you have one. The test unit itself must not reference `uAgentTools`. Assert the test source does not call `ExecuteToolDirect` (the test simply never links the tool registry). That is the proof: the replay unit's uses clause has no tool or LLM unit, and the test still passes.
   - A second test: `AppendEntry` is replaced by a repository double that raises. Call the sink the engine uses (extract the try/except into `procedure SaveTraceEntrySafely(...)` so the test can call it). Assert it returns false and does not raise.
6. Add the test to the `lazbuild` block in [`tests/run_tests.sh`](../tests/run_tests.sh).

## 6. Security

- Persist only the redacted wire strings the engine already stores (`LastWireRequestRedacted` or the argument already given to `AddLlmWire`). If you find a path that passes a non-redacted body, store the redacted one instead. Do not add a new redactor in this task (task 007 owns export scrubbing).
- Replay is read-only. Do not add a "run this tool again" button.

## 7. Speed

- One insert per log entry. Do not wrap the whole agent run in a single transaction that stays open while the model thinks.
- `LatestTraceId` uses `idx_traces_session`.
- Replay loads one trace, not every trace in the workspace.

## 8. Cloud extraction seam

The sink depends on `IExecutionTraceRepository`, not on `uSqlite*`. Tests can pass an in-memory implementation of the interface (a `TInterfacedObject` in the test program) for the "raise on append" case. The SQLite round-trip test uses the real adapter.

## 9. Tests

```bash
lazbuild tests/test_trace_replay.lpi && tests/test_trace_replay
```

Also rerun `tests/test_app_database` so version assertions still pass.

## 10. README and help updates

- [`help/chat-and-modes.md`](../help/chat-and-modes.md) or [`help/how-the-agent-works.md`](../help/how-the-agent-works.md): one short paragraph. Execution Detail can show a saved trace after restart. Replay does not call the model or tools again. Mention the menu or button name you actually added.
- Add keywords `replay`, `execution trace` to that help entry in [`help/index.json`](../help/index.json).
- README: one sentence under the educational / execution-log feature.

## 11. Done when

- [ ] Live runs append to `execution_trace_entries` and keep the in-memory log.
- [ ] A failed insert does not abort the run (test covers the safe wrapper).
- [ ] Replay fills the log from rows and does not link tool execution.
- [ ] Help names the real command.
- [ ] Checkbox 006 checked, **NEXT** is task 007.

## 12. Stop

Do not implement export scrubbing.
