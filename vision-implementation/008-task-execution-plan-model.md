# 008 — Execution plan model

Depends on: [007-task-trace-export.md](007-task-trace-export.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

A workspace can store a project execution plan: stable task ids, order, dependencies, approval, and a link to a trace. No tracker window yet (task 009). This task is the model, the repository, markdown files the app writes, and tests.

The session todo list (agent `todo` tool / nav rail **Tasks & Plans**) stays as it is. This is a different store.

## 2. Out of scope

- Do not enable the Execution Plans dialog (task 009).
- Do not run tasks or call the model (task 010 and 020).
- Do not mark a task complete just because a model message says "done".

## 3. Read these files first

- [`future-plan/Lazarus_AI_Agent_Future_Plan.md`](../future-plan/Lazarus_AI_Agent_Future_Plan.md) section 6.
- [`uAppDatabase.pas`](../uAppDatabase.pas) workspace migration head (version 2 after task 005). This task adds workspace version **3**.
- [`frmExecutionPlansConfig.pas`](../frmExecutionPlansConfig.pas) — leave it disabled. Do not wire it yet.
- How `.plan/*.md` is used today (`TToolCreatePlanFile` in the tools unit) so you do not overwrite those files. New files go in `<workspace>/.plan/execution/<planId>/`.

## 4. Design decisions already made

- SQLite is authoritative for status. Markdown is a human-readable copy the app writes. On load, if a checkbox in markdown disagrees with SQLite, SQLite wins and the app rewrites the markdown. Do not parse markdown to decide `running` or `completed`.
- Workspace migration v3:

```sql
CREATE TABLE execution_plans (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  markdown_dir TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
);

CREATE TABLE execution_tasks (
  plan_id TEXT NOT NULL,
  task_id TEXT NOT NULL,
  display_order INTEGER NOT NULL,
  title TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN (
    'pending','running','blocked','awaiting_review','completed','failed')),
  depends_on_json TEXT NOT NULL DEFAULT '[]',
  approval_status TEXT NOT NULL DEFAULT 'none'
    CHECK (approval_status IN ('none','pending','approved')),
  evidence_trace_id TEXT NOT NULL DEFAULT '',
  verification_passed INTEGER NOT NULL DEFAULT 0,
  blocker TEXT NOT NULL DEFAULT '',
  PRIMARY KEY (plan_id, task_id),
  FOREIGN KEY (plan_id) REFERENCES execution_plans(id) ON DELETE CASCADE
);

CREATE INDEX idx_tasks_plan_order ON execution_tasks(plan_id, display_order);
```

- `markdown_dir` is a path **relative to the workspace root**, always starting with `.plan/execution/` and the plan id. Reject absolute paths and any `..` segment.
- Status changes go through repository methods, not a generic "set any column" from the UI:
  - `SetStatus` allows `pending`, `running`, `blocked`, `awaiting_review`, `failed`.
  - `MarkCompleted` sets `completed` only when `verification_passed = 1` and `approval_status` is `none` or `approved`. Otherwise it returns false and leaves the row unchanged.
  - There is no method that sets `completed` from a free string.
- `MarkRunning` on a task that is already `running` does not clear `blocker`. `ReconcileAfterRestart` (used by task 010, implement the method now): every `running` row becomes `blocked` with `blocker` `Interrupted by restart. Not re-run automatically.` It does not set them back to `pending`.
- Eligible task query: status `pending`, every id in `depends_on_json` has status `completed`, and `approval_status` is not `pending`. Return the lowest `display_order`.
- Interface GUID: `{E2B5C7D9-1A83-4C66-9B20-4C7E8F3D0152}`

```pascal
TExecutionTaskRow = record
  PlanId: string;
  TaskId: string;
  DisplayOrder: Integer;
  Title: string;
  Status: string;
  DependsOnJson: string;
  ApprovalStatus: string;
  EvidenceTraceId: string;
  VerificationPassed: Boolean;
  Blocker: string;
end;

IExecutionPlanRepository = interface
  ['{E2B5C7D9-1A83-4C66-9B20-4C7E8F3D0152}']
  procedure UpsertPlan(const AId, ATitle, AMarkdownDir: string);
  procedure UpsertTask(const ATask: TExecutionTaskRow);
  procedure ListTasks(const APlanId: string; out ATasks: array of TExecutionTaskRow);
  { Use a named array type TExecutionTaskRows, not an open array, so the implementation can SetLength. }
  function MarkCompleted(const APlanId, ATaskId: string): Boolean;
  procedure SetStatus(const APlanId, ATaskId, AStatus, ABlocker: string);
  procedure SetVerification(const APlanId, ATaskId: string; APassed: Boolean);
  procedure SetApproval(const APlanId, ATaskId, AApproval: string);
  procedure SetEvidence(const APlanId, ATaskId, ATraceId: string);
  function NextEligibleTaskId(const APlanId: string): string;
  procedure ReconcileAfterRestart(const APlanId: string);
end;
```

Fix the `ListTasks` signature to `out ATasks: TExecutionTaskRows` where `TExecutionTaskRows = array of TExecutionTaskRow`.

- Markdown writer `uExecutionPlanMarkdown.pas` writes `progress.md` in that directory with lines `- [ ] 001 title` or `- [x] 001 title` from SQLite status (`completed` → `[x]`, anything else → `[ ]`). It creates directories with `ForceDirectories` under the workspace root after checking the relative path.
- Changing `display_order` must not change `task_id`.

## 5. Step-by-step implementation

1. Migration v3 on workspace only. Update tests that assumed the previous workspace version so they expect **3** on a fresh file, while still checking chat and trace tables exist.
2. Repository unit `data/sqlite/uSqliteExecutionPlanRepository.pas`. Bound parameters. `depends_on_json` must be a JSON array; if parsing fails, `NextEligibleTaskId` treats the task as not eligible and does not throw out of the query.
3. `TAppDatabase.ExecutionPlans(AWsId)`.
4. Markdown writer. Given workspace root `W` and relative dir `.plan/execution/plan1`, the file is `W/.plan/execution/plan1/progress.md`. If the resolved path is not under `W`, raise and do not write.
5. Tests `tests/test_execution_plans.lpr`:
   - Two tasks, `002` depends on `001`. `NextEligible` returns `001` only.
   - `MarkCompleted('001')` returns false while `verification_passed` is 0.
   - `SetVerification(..., True)` then `MarkCompleted` returns true. `NextEligible` returns `002`.
   - `SetApproval(..., 'pending')` on `002` makes `NextEligible` return `''`.
   - Set `001` back is unnecessary. Insert a third task with status `running`. `ReconcileAfterRestart` makes it `blocked` and the blocker text contains `Not re-run`.
   - `UpsertPlan` with markdown dir `/tmp/x` or `.plan/execution/../../etc` raises or returns an error and does not create a file outside the temp workspace.
   - After status changes, `progress.md` checkboxes match SQLite, including a task that is not completed still showing `[ ]`.
6. Register units in the app `.lpi` and the test `.lpi`. Add `run_tests.sh` line.

## 6. Security

- Path check is mandatory. The test with `..` is a security test.
- Task titles written into markdown must not be interpreted as paths. Strip path separators from the title when building the file name; the file name is always `progress.md`.
- `MarkCompleted` cannot be bypassed by writing status `completed` through `SetStatus`. `SetStatus('completed')` returns without change (or raises). Test that.

## 7. Speed

- `ListTasks` is one query ordered by `display_order`.
- `NextEligibleTaskId` may load tasks for one plan into memory (plans are small, tens of tasks). Do not scan messages or traces.

## 8. Cloud extraction seam

The repository interface is the port. Markdown writing stays local because plans are user-owned files. A cloud orchestrator later calls the same status methods. Do not put SQL in the markdown unit.

## 9. Tests

```bash
lazbuild tests/test_execution_plans.lpi && tests/test_execution_plans
```

## 10. README and help updates

One sentence in [`help/workspace-layout.md`](../help/workspace-layout.md): project execution plans will appear in Workspace → Execution Plans; this build stores them but the dialog may still be a preview until task 009. If the dialog is still Coming Soon, say the data layer exists and the dialog is still a preview. Do not tell users the tracker is live.

README: one bullet that execution plan state is in `workspace.db` and a markdown copy is under `.plan/execution/`.

## 11. Done when

- [ ] Completion requires verification in code, and `SetStatus` cannot set `completed`.
- [ ] Restart reconcile blocks `running` tasks and does not mark them pending.
- [ ] Path escape test passes.
- [ ] Checkbox 008 checked, **NEXT** is task 009.

## 12. Stop

Do not rebuild the Execution Plans form yet.
