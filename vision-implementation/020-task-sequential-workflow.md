# 020 — Sequential workflow

Depends on: [019-task-workflow-artifacts.md](019-task-workflow-artifacts.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

A workspace can run one plan task through a fixed sequence: Planner → human approval → Coder → Reviewer. Review findings can send the task back to the coder at most N times (default 3, from the coder role `max_retries`). The fourth repair does not start. The reviewer cannot write files.

The orchestrator is not `TAgentEngine`. The engine runs a single role when asked. The orchestrator decides who runs next.

## 2. Out of scope

- Do not add parallel reviewers, conditional graphs, or git worktrees (later advanced work; not in the numbered queue except as "do not").
- Do not call a live network model in tests.
- Do not let the reviewer role pass `TryAuthorizeTool` for `write_file`.

## 3. Read these files first

- `IAgentRoleRepository`, `TryAuthorizeTool`, seed ids `role-planner`, `role-coder`, `role-reviewer`.
- `IExecutionPlanRepository.NextEligibleTaskId`, `SetApproval`, `SetVerification`, `MarkCompleted`, `SetEvidence`.
- `IWorkflowArtifactRepository` and `BuildHandoff`.
- [`uAgentEngine.pas`](../uAgentEngine.pas) public `Run` / chat entry. You need a way to run one bounded turn with a fake client. Search for the LLM client interface. If `TLlmClient` is concrete, add a narrow interface in this task rather than subclassing HTTP.

## 4. Design decisions already made

- New unit `uWorkflowOrchestrator.pas`. It must not contain `sqlite3_*` and must not contain HTTP.
- Stages in order: `plan`, `await_approval`, `implement`, `review`, `repair` (repair returns to implement), `done`, `stopped`.
- Human approval: after a plan artifact is stored, status of the task becomes `awaiting_review` is wrong. Use plan task status `pending` and `approval_status` `pending` until the user approves. The orchestrator method `ApprovePlan(planId, taskId)` sets `approved` and only then allows `implement`. `Start` on an unapproved task returns without calling the coder.
- Repair cap: `max_retries` on `role-coder` (default 3). Count repair entries. When the reviewer artifact body contains the line `VERDICT: changes` and the count is less than `max_retries`, run coder again with the review artifact in the handoff. When the count is equal to `max_retries`, set task `blocked` and blocker `Repair limit reached`. Do not call the coder again.
- Reviewer verdict `VERDICT: accept` sets `verification_passed` true and calls `MarkCompleted`. Only the orchestrator does that, after the verdict, not the model.
- Fake model for tests:

```pascal
IWorkflowModel = interface
  ['{A0D345F7-9261-44EE-B3A8-C4F607B589DA}']
  function Complete(const ARoleId, AHandoff, AUserGoal: string): string;
end;
```

  Test double returns scripted strings per role id and increments a call counter.
- Coder tool use: the orchestrator asks the engine to run tools only with `role-coder`. The test does not need a real engine if `IWorkflowModel` returns text and a separate `IRoleToolGate` calls `TryAuthorizeTool`. **Required test:** before any coder file write, `TryAuthorizeTool('role-reviewer','write_file')` is false and the orchestrator never calls the gate with reviewer + write. Simulate a reviewer model that returns `CALL write_file`. The orchestrator must not invoke a write. It stores a review artifact with the model text and continues the verdict parser. If the text has no verdict line, treat it as `VERDICT: changes`.
- Planner and reviewer calls use their role ids only.
- The orchestrator writes artifacts via `IWorkflowArtifactRepository` and never via chat session save.

## 5. Step-by-step implementation

1. Define `TWorkflowOrchestrator` with `Start`, `ApprovePlan`, `RunNext` (one stage per call so tests can step), and `RepairCount`.
2. Dependencies are interfaces passed to `Create`, not globals: plan repo, role repo, artifact repo, model, and a tool runner interface:

```pascal
IRoleToolRunner = interface
  function RunTool(const ARoleId, AToolName, AArgsJson: string; out AOutput: string): Boolean;
end;
```

   The real adapter calls `TryAuthorizeTool` then `ExecuteToolDirect`. The test adapter records calls and returns false when authorize fails.
3. Tests `tests/test_workflow_orchestrator.lpr` with in-memory interface stubs (no SQLite required if stubs are easier). Also one SQLite test that `ApprovePlan` persists, using the real repositories, if time; the stub test is mandatory:
   - `RunNext` before approve does not call the model with `role-coder` (counter 0).
   - After approve, coder is called.
   - Reviewer script `CALL write_file` then `VERDICT: accept` results in zero write-tool calls and `MarkCompleted` path (stub plan repo records verification true). If you stub plan repo, assert `MarkCompleted` was requested once.
   - Reviewer script `VERDICT: changes` four times: coder implement/repair runs 1 initial + 3 repairs = 4 coder calls, then the fifth reviewer changes does not call coder again. Blocker is set. **Count carefully and document the expected number in the test name.** The rule is: at most 3 **repairs after** the first implementation. The 4th repair attempt must not call the coder. Assert the coder call count equals 4 (1 + 3) and a further `RunNext` does not make it 5.
4. Wire a real runner only if the app already has a single place to start a plan task. A menu item **Run next plan task** on the Execution Plans form is enough. It calls `Approve` only from the existing Approve button (task 009) and `RunNext` from the new button. If that UI is too large, ship the unit and tests and add the button with `.lfm` wiring. The button must be real, not only a test. Disable it while no task is eligible.
5. `lazbuild` the app and the test.

## 6. Security

- Reviewer write is denied in the runner before `Execute`.
- Orchestrator does not mark complete from a coder message. Only `VERDICT: accept` from the reviewer stage.
- Repair limit is enforced with an integer, not by asking the model to stop.
- Handoff uses `BuildHandoff`, not the chat transcript.

## 7. Speed

- One model call per `RunNext`. Do not loop all repairs inside a single UI call without returning to the message queue. The test can call `RunNext` in a loop. The button runs **one** stage per click so the UI cannot freeze on four model calls. Document that in help.
- No sleep/polling.

## 8. Cloud extraction seam

`IWorkflowModel` hides the provider. Roles and artifacts are repositories. A hosted orchestrator can replace `TWorkflowOrchestrator` later; do not hard-code SQLite inside it.

## 9. Tests

```bash
lazbuild tests/test_workflow_orchestrator.lpi && tests/test_workflow_orchestrator
lazbuild lazycodingagent.lpi
```

## 10. README and help updates

[`help/how-the-agent-works.md`](../help/how-the-agent-works.md) and [`help/workspace-layout.md`](../help/workspace-layout.md): sequence, approval, reviewer is read-only, repair limit 3, one stage per click. [`help/index.json`](../help/index.json) keyword `workflow`.

README: short paragraph. Do not claim parallel agents.

## 11. Done when

- [ ] Coder does not run before approval.
- [ ] Fourth repair does not run (coder call count stays 4).
- [ ] Reviewer `write_file` is not executed.
- [ ] Complete happens only on reviewer accept.
- [ ] Help describes the real button.
- [ ] Checkbox 020 checked, **NEXT** is task 021.

## 12. Stop

Do not add trace columns for agent id in this task if you did not need them. Task 021 does that. You may store the role id inside the artifact stage only.
