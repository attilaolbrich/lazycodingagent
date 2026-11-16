# 021 — Workflow trace links

Depends on: [020-task-sequential-workflow.md](020-task-sequential-workflow.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

Each stored trace entry can say which role ran, which workflow stage it was, and which plan revision it belongs to. The Execution Plans tracker can open that evidence. Help describes the real sequential flow instead of a Coming Soon blurb for multi-agent.

## 2. Out of scope

- Do not add new workflow stages.
- Do not add parallel execution.
- Do not export a different file format (task 007 export should include the new fields if they are on the entry; update the export unit to print them).

## 3. Read these files first

- `execution_trace_entries` columns from task 005.
- Trace sink from task 006 and export from task 007.
- Orchestrator from task 020.
- [`frmExecutionPlansConfig.pas`](../frmExecutionPlansConfig.pas) Open evidence action.
- [`frmMultiAgentWorkspace.pas`](../frmMultiAgentWorkspace.pas).

## 4. Design decisions already made

- Workspace migration. Fresh version after task 019 is **6**. This adds version **7**:

```sql
ALTER TABLE execution_trace_entries ADD COLUMN agent_role_id TEXT NOT NULL DEFAULT '';
ALTER TABLE execution_trace_entries ADD COLUMN stage TEXT NOT NULL DEFAULT '';
ALTER TABLE execution_trace_entries ADD COLUMN plan_revision INTEGER NOT NULL DEFAULT 0;
```

  SQLite allows ADD COLUMN with a constant default. One transaction. Record migration 7.
- Update `TTraceEntryRow` and `AppendEntry` / `LoadEntries` to read and write the three columns. Old rows default to empty role, empty stage, revision 0.
- When the orchestrator starts a model or tool stage, it sets the sink context: role id, stage (`plan`, `implement`, `review`, `repair`), and `execution_plans.revision`.
- Normal single-agent chat leaves the three fields empty. Do not invent a role.
- Tracker: task row shows role/stage if the linked trace's latest entry has them. Open evidence still uses `LoadTraceForDisplay`. Extend display so Execution Detail shows role and stage when non-empty. If the detail view is a memo fed by `BuildInspectorMarkdown`, append the three fields there.
- Multi-agent form: replace Coming Soon body with a short read-only explanation of the sequential flow and the seed roles, plus a note that limits are enforced in the app. Do not build a workflow graph editor. Disable buttons that would add custom roles (that is advanced work, not this task). You may list the three seed roles from `IAgentRoleRepository` in the existing list box and enable that list as read-only (`Enabled` true but no add button, or list enabled and add button stays disabled).

## 5. Step-by-step implementation

1. Migration and repository field mapping.
2. Sink context setter `SetTraceContext(const ARoleId, AStage: string; ARevision: Integer)` on the sink. Engine single-chat path calls it with empty strings and 0.
3. Orchestrator sets context before each stage.
4. Export markdown includes role and stage lines.
5. Tests:
   - Append an entry with role `role-reviewer`, stage `review`, revision 2. Reopen. Fields match.
   - Append without setting them. They load as empty and 0.
   - Export contains `role-reviewer` and does not drop the redaction behavior from task 007 (run the old secret fixture too if the test project can call `RedactForExport`).
6. Update version asserts to 7.
7. `lazbuild` app and tests.

## 6. Security

- Role id on a trace is a label. It does not grant tools. `TryAuthorizeTool` remains the check.
- Export still runs `RedactForExport` on payloads.

## 7. Speed

- Three columns on the insert that already happens. No extra query per token.
- Tracker reads the trace it already loads for evidence. Do not scan all traces for the list view. Optional: show evidence id only, and show role after Open evidence. That is faster and acceptable if the list would otherwise query every task's trace. Prefer that. Do not add an N+1 query per task on dialog open.

## 8. Cloud extraction seam

The three fields are part of `TTraceEntryRow` and `IExecutionTraceRepository`. A remote trace store persists the same record.

## 9. Tests

```bash
lazbuild tests/test_trace_replay.lpi && tests/test_trace_replay
lazbuild tests/test_trace_export.lpi && tests/test_trace_export
lazbuild lazycodingagent.lpi
```

Add the new assertions to those programs if that is where append/export live. A new program is fine if linking the old ones is harder; then register it in `run_tests.sh`.

## 10. README and help updates

- [`help/workspace-layout.md`](../help/workspace-layout.md): Multi-Agent Workspace describes Planner → approval → Coder → Reviewer, repair limit, read-only reviewer. Remove "COMING SOON" for that item if the form no longer says the feature is absent. If add-role is still disabled, say custom roles are not editable yet.
- [`help/how-the-agent-works.md`](../help/how-the-agent-works.md): traces record role, stage, and plan revision.
- [`help/chat-and-modes.md`](../help/chat-and-modes.md): export includes those fields and is still scrubbed.
- README: one update. Do not claim conditional routing.

## 11. Done when

- [ ] New columns round-trip and default for old-style inserts.
- [ ] Export shows stage and still redacts secrets.
- [ ] Help matches the sequential flow that actually runs.
- [ ] Checkbox 021 checked, **NEXT** is task 022.

## 12. Stop

Do not start URL ingest.
