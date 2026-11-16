# 009 — Execution plan tracker UI

Depends on: [008-task-execution-plan-model.md](008-task-execution-plan-model.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

**Workspace → Execution Plans…** opens a real tracker for the active workspace: plans, tasks in `display_order`, status, blocker, and a way to open the linked trace in Execution Detail (task 006 replay).

The left nav **Tasks & Plans** item still shows the live session todo list from the agent todo tool. Do not replace that list.

## 2. Out of scope

- Do not start the orchestrator (task 020).
- Do not auto-run the next task on open (task 010 only reconciles at startup).
- Do not add knowledge-base controls to this form.

## 3. Read these files first

- [`frmExecutionPlansConfig.pas`](../frmExecutionPlansConfig.pas) and [`frmExecutionPlansConfig.lfm`](../frmExecutionPlansConfig.lfm).
- [`uFutureFeatureFormCommon.pas`](../uFutureFeatureFormCommon.pas) — Coming Soon helpers. You may stop calling them for this form once the controls are real.
- [`mainunit.lfm`](../mainunit.lfm) menu item that calls `TExecutionPlansConfigForm.Execute`.
- LCL rules in `.cursor/rules/lazarus-lcl-layout.mdc` and `.cursor/rules/lazarus-visual-designer.mdc`.

## 4. Design decisions already made

- Keep this form. Do not create a second plan window.
- Remove the Coming Soon label's role: hide `lblComingSoon` or leave it unused with `Visible = False` in the `.lfm`. Enable the list and buttons that this task implements.
- Buttons that do real work:
  - **Refresh** — `ListTasks` for the selected plan.
  - **Open evidence** — if `evidence_trace_id` is non-empty, call `LoadTraceForDisplay` and the existing detail view. If empty, a dialog says there is no trace yet.
  - **New plan** — asks for a title (input dialog), creates id `plan_` + hex ticks, `markdown_dir` `.plan/execution/<id>`, inserts one sample task only if the user also... no sample task. Empty plan is allowed. Write `progress.md`.
- Do not add a button that marks complete without verification. The UI may show status text. It does not call `MarkCompleted`. Completion stays with the orchestrator later.
- User may set approval to approved via a button **Approve** which calls `SetApproval(..., 'approved')` only when current approval is `pending` or `none`. That is a human action, not completion.
- Layout: existing panels stay `Align`ed. Do not add `SetBounds` in `FormShow`. Do not set combo heights in code.
- Theme with the same `ApplyTheme` path the form already uses (`ThemePalette`, list box helper). No hard-coded colors in the `.lfm`.
- If there is no active workspace, the dialog shows an empty list and a label `Open a workspace first.` Buttons that write stay disabled.

## 5. Step-by-step implementation

1. Edit the `.lfm` in text only for properties the designer would store: `Visible`, `Enabled`, captions, `OnClick` names. Add published methods before `private` in the class.
2. `FormShow` loads plans. You need `ListPlans` on the repository. Add it in this task:

```pascal
procedure ListPlans(out AIds, ATitles: TStringArray);
```

   If `TStringArray` is awkward, use two `TStringList` parameters the caller owns. One query: `SELECT id, title FROM execution_plans ORDER BY updated_at DESC`.
3. Selecting a plan fills `lstPlans` or a task list. The current list box was a fake plan list. Use it for **tasks** (`001  pending  title`) and add a combo or second list for plans if the `.lfm` already has room in `pnlActions`. If you need a new control, add it in the `.lfm` with `Align` on its parent panel, not floating coordinates mixed with align.
4. **Open evidence** uses the trace repository and `LoadTraceForDisplay`. No model call.
5. After any status-independent refresh, you may rewrite `progress.md` from SQLite so the file matches the screen.
6. Manual check (write it in the session summary; there is no GUI test harness):
   - Open the dialog from the menu with a workspace.
   - Create a plan, see it after closing and reopening the dialog.
   - Nav rail Tasks & Plans still shows session todos, not this plan.
   - Resize the window. No ChangeBounds dialog.
7. Add a repository test for `ListPlans` order in `tests/test_execution_plans.lpr`.

## 6. Security

- The form calls `IExecutionPlanRepository` and `IExecutionTraceRepository` only. No `sqlite3_*` in the form unit.
- Evidence open uses the trace id from the row, not a path from the title string.
- Approve cannot set `verification_passed`.

## 7. Speed

- Load tasks for one plan when the user selects it, not all messages in the workspace.
- Do not poll on a timer.

## 8. Cloud extraction seam

The form depends on interfaces obtained from `TAppDatabase` (or a later factory). Do not construct `TSqliteExecutionPlanRepository` inside the form.

## 9. Tests

```bash
lazbuild tests/test_execution_plans.lpi && tests/test_execution_plans
lazbuild lazycodingagent.lpi
```

`lazbuild` of the app must succeed. Say if you could not click the dialog because there is no display.

## 10. README and help updates

- [`help/workspace-layout.md`](../help/workspace-layout.md) — replace the Coming Soon sentence for **Execution Plans…** with what the dialog does now. Keep the sentence that nav-rail Tasks & Plans is the session todo list.
- [`help/index.json`](../help/index.json) keywords already include `execution plans`. Add `tracker` if missing.
- README menu/feature list: Execution Plans opens the project tracker.

## 11. Done when

- [ ] Dialog loads real rows and can create a plan.
- [ ] Open evidence does not call the model.
- [ ] Coming Soon banner is not shown on this dialog.
- [ ] App `lazbuild` succeeded.
- [ ] Help matches the dialog.
- [ ] Checkbox 009 checked, **NEXT** is task 010.

## 12. Stop

Do not implement startup reconcile.
