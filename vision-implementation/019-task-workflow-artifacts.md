# 019 — Workflow artifacts

Depends on: [018-task-agent-role-model.md](018-task-agent-role-model.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

One agent can pass a bounded artifact to the next: plan text, a diff summary, review findings, and trace ids. The next stage does not receive the previous agent's full chat transcript.

No orchestrator loop yet. This task stores and loads artifacts and tests the size cap.

## 2. Out of scope

- Do not call the model.
- Do not implement repair routing (task 020).
- Do not copy `TChatMessage` history into the artifact.

## 3. Read these files first

- `IExecutionPlanRepository` and trace ids.
- Workspace schema version after task 018 (**5**). This task adds version **6**.

## 4. Design decisions already made

```sql
CREATE TABLE workflow_artifacts (
  id TEXT PRIMARY KEY,
  plan_id TEXT NOT NULL,
  task_id TEXT NOT NULL,
  stage TEXT NOT NULL CHECK (stage IN ('plan','implementation','review')),
  body TEXT NOT NULL,
  trace_id TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  FOREIGN KEY (plan_id) REFERENCES execution_plans(id) ON DELETE CASCADE
);

CREATE INDEX idx_artifacts_task ON workflow_artifacts(plan_id, task_id, created_at);
```

- `body` maximum 32_000 characters. The repository rejects longer text (return false / error string) and does not truncate silently. The caller must summarize first.
- Interface GUID: `{F9C234E6-8150-43DD-A297-B3E5F6A478C9}`

```pascal
TWorkflowArtifact = record
  Id, PlanId, TaskId, Stage, Body, TraceId, CreatedAt: string;
end;

IWorkflowArtifactRepository = interface
  ['{F9C234E6-8150-43DD-A297-B3E5F6A478C9}']
  function Add(const AItem: TWorkflowArtifact; out AError: string): Boolean;
  procedure ListForTask(const APlanId, ATaskId: string; out AItems: TWorkflowArtifactRows);
  function Latest(const APlanId, ATaskId, AStage: string; out AItem: TWorkflowArtifact): Boolean;
end;
```

- `Add` generates id if empty: `art_` + hex ticks.
- There is no method `ListTranscript`. Do not add one.
- Handoff text builder `uWorkflowHandoff.pas`:

```pascal
function BuildHandoff(const AArtifacts: TWorkflowArtifactRows): string;
```

  Includes stage, body, and trace id for each artifact. Does not accept a `TChatMessageArray`. The unit's uses clause must not include `uChatSessionStore`.

## 5. Step-by-step implementation

1. Migration v6. Fix fresh-db version asserts to 6.
2. SQLite repository, bound parameters, length check before insert.
3. Tests:
   - Add plan + task (reuse execution plan helpers or insert via the plan repository).
   - Add a plan artifact and a review artifact. `Latest(..., 'review')` returns the review body.
   - Body of length 32_001 is rejected and `ListForTask` stays empty for that attempt.
   - `BuildHandoff` output contains both bodies and both trace ids and does not contain a marker string you did not put in the body (`FULL_TRANSCRIPT_SENTINEL`).
   - Delete the plan. Artifacts are gone (cascade).
4. Register units and `run_tests.sh`.

## 6. Security

- The size cap limits how much untrusted model output is stored and re-injected.
- Artifact body is data for the next prompt, not a system prompt. `BuildHandoff` prefixes each block with `[handoff stage=review]` so task 020 can keep it out of the trusted prompt. Include that prefix now.
- SQL parameters only.

## 7. Speed

- `Latest` is one query `ORDER BY created_at DESC LIMIT 1`.
- Do not load chat messages to build a handoff.

## 8. Cloud extraction seam

`IWorkflowArtifactRepository` is the port. `BuildHandoff` is pure and can run beside a remote store.

## 9. Tests

```bash
lazbuild tests/test_workflow_artifacts.lpi && tests/test_workflow_artifacts
```

## 10. README and help updates

One sentence in [`help/how-the-agent-works.md`](../help/how-the-agent-works.md): when multi-step workflow runs, agents receive the stored handoff (plan, diff summary, or review), not the previous agent's full chat. Say the automatic loop is not on until the following tasks if it is not.

## 11. Done when

- [ ] Oversize body is rejected.
- [ ] Handoff text has the stage prefix and no transcript API is added.
- [ ] Cascade delete works.
- [ ] Checkbox 019 checked, **NEXT** is task 020.

## 12. Stop

Do not start the sequential workflow.
