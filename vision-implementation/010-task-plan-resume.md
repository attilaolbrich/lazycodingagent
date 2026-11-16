# 010 — Plan resume

Depends on: [009-task-execution-plan-tracker-ui.md](009-task-execution-plan-tracker-ui.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

When the app starts and a workspace opens, execution plans are reconciled before anyone runs an agent. Tasks left `running` become `blocked` with the restart reason from task 008. Completed tasks stay completed. The tracker shows the blocked row. The app does not call tools or the model during this step.

## 2. Out of scope

- Do not implement the multi-agent orchestrator (task 020).
- Do not auto-start the next eligible task.
- Do not delete traces.

## 3. Read these files first

- `ReconcileAfterRestart` and `NextEligibleTaskId` on `IExecutionPlanRepository`.
- Where a workspace becomes active in [`mainunit.pas`](../mainunit.pas) or [`uWorkspaceRegistry.pas`](../uWorkspaceRegistry.pas). Search `BindWorkspace` and active workspace id.
- [`lazycodingagent.lpr`](../lazycodingagent.lpr) — startup already opens `global.db`. Do not reconcile before a workspace id is known.

## 4. Design decisions already made

- Call reconcile once per workspace open, including the workspace restored at startup. Guard with a set or a boolean on the plan id so a second bind in the same process does not append a second blocker sentence. `ReconcileAfterRestart` itself must be idempotent: a second call finds no `running` rows and changes nothing.
- Completed tasks with an empty `evidence_trace_id` stay completed. Do not demote them. Evidence may predate traces. Do not "helpfully" fail them.
- Do not call `NextEligibleTaskId` to launch work. You may call it to set a status-bar hint `Next task: 002` if the main form already has a status bar. If that is awkward, skip the hint. The required behavior is the status change and the tracker refresh.
- No tool interface is used. The startup procedure's uses clause must not include `uAgentTools`.

## 5. Step-by-step implementation

1. Add `procedure ReconcileExecutionPlans(const AWsId: string)` in a small unit `uExecutionPlanResume.pas`. It opens the workspace database if needed, lists plans, calls `ReconcileAfterRestart` on each, rewrites `progress.md` for each plan.
2. Call it from the workspace-activated path, not from unit `initialization`.
3. If rewrite of markdown fails (disk full), leave SQLite as the authority, surface one status message, do not crash startup.
4. Tests in `tests/test_execution_plans.lpr`:
   - Insert plan with tasks: completed, running, pending depending on the completed one.
   - Call `ReconcileExecutionPlans`.
   - Assert running became blocked with `Not re-run`.
   - Assert completed is still completed.
   - Assert pending is still pending.
   - Call it again. Blocker text is still a single sentence, not duplicated.
   - Assert the test unit does not use `uAgentTools` or `uLlmClient`.

## 6. Security

- Reconcile is not an execution path. It must not invoke `ExecuteToolDirect`.
- Markdown rewrite uses the path checks from task 008.

## 7. Speed

- One query per plan for tasks, not per task a separate connection.
- Do this only when the workspace is activated, not on a timer.

## 8. Cloud extraction seam

`uExecutionPlanResume` uses `IExecutionPlanRepository` from `TAppDatabase.ExecutionPlans`. It does not construct the SQLite class directly.

## 9. Tests

```bash
lazbuild tests/test_execution_plans.lpi && tests/test_execution_plans
lazbuild lazycodingagent.lpi
```

## 10. README and help updates

[`help/workspace-layout.md`](../help/workspace-layout.md): after a restart, tasks that were running show as blocked and are not executed again until a person acts. [`README.md`](../README.md): one clause on that recovery behavior.

## 11. Done when

- [ ] Second reconcile does not duplicate the blocker.
- [ ] Completed and pending rows stay put.
- [ ] Startup path does not reference tool execution.
- [ ] Checkbox 010 checked, **NEXT** is task 011.

## 12. Stop

Do not add RAG tables in this session.
