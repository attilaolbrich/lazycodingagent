# 026 — Brain candidates

Depends on: [025-task-brain-schema.md](025-task-brain-schema.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

Learning is **off** by default. When the user turns it on for a workspace, the app proposes candidate memories after a run finishes. The Brain dialog lists candidates and can approve, edit, or reject them. Candidates that look like secrets are dropped and not stored.

Extraction does not run on the UI thread and does not change tools or the system prompt.

## 2. Out of scope

- Do not inject approved memories into the model prompt (task 027).
- Do not call a live LLM in tests. Extraction can be a deterministic function.
- Do not enable learning globally without a setting.

## 3. Read these files first

- `IBrainBackend` and statuses `candidate`, `approved`, `rejected`.
- [`frmTheBrainConfig.pas`](../frmTheBrainConfig.pas) and its `.lfm`.
- Where a run finishes in [`uAgentEngine.pas`](../uAgentEngine.pas) (`RunThreadFinished` or the success path). Hook **after** the run, not inside the tool loop.
- `EncryptSecret` prefix so the secret filter can recognize `lca-sec:v2:`.

## 4. Design decisions already made

- Setting: workspace `session_prefs` is the wrong place (it is chat). Use `app_settings` on **global** db key `brain.enabled.<workspaceId>` values `0`/`1`. Default missing means off. Do not use a workspace table that task 001 removed (`app_settings` is global).
- The dialog's existing "Enable The Brain for this workspace" checkbox becomes the real setting. Other Coming Soon controls that are not approve/edit/reject stay disabled.
- Extractor `uBrainExtract.pas`:

```pascal
function ProposeCandidates(const AUserText, AAssistantText: string;
  out ABodies: TStringArray): Integer;
```

  Deterministic rules, no network:
  - If the user text contains `remember that ` then the rest of that sentence (max 500 chars) is one procedural candidate.
  - Else if both texts are non-empty, produce **no** candidate. Do not auto-summarize the whole chat in this task. One explicit phrase is enough for the MVP.
  - Drop a candidate if the body contains, case-insensitive: `api_key`, `api key`, `bearer `, `lca-sec:v2:`, or `sk-` plus 8 characters. Dropped items are not passed to `Add`.
- After a run, if the setting is off, do not call `ProposeCandidates`.
- If on, call it on a `TThread`, then `Queue` to the main thread to `Add` each body with status `candidate`, scope `workspace`, type `procedural`, confidence `0.4`, evidence trace id if the run has one else `''`.
- The thread must not touch form controls and must not call `RegisterTool` or `BuildSystemPrompt`.
- Dialog: list candidates for this workspace. **Approve** sets status `approved` (optional edit memo writes `body` first — add `UpdateBody` on `IBrainBackend` if missing). **Reject** sets `rejected`. Rejected rows stay in the database but the list shows candidates only by default.
- Edit uses the memo. Empty body cannot be approved.

## 5. Step-by-step implementation

1. `UpdateBody` on the interface and SQLite repository. Bound parameter.
2. Extractor and secret filter. Pure tests first.
3. Hook the end of a run. If that path is hard to fire in a test, put the hook body in `procedure MaybeProposeBrainCandidates(const AWsId, AUser, AAssistant, ATraceId: string)` and test that procedure with a fake backend. The engine calls it. The test does not need the UI thread: call the procedure synchronously in the test, but the production engine must `TThread.CreateAnonymousThread` (or equivalent) so the UI is not blocked. Guard the test by reading the engine procedure and also unit-testing `MaybePropose` logic in a form that takes a `TProposeMode` — **simpler:** `MaybeProposeBrainCandidates` is synchronous and safe, and the engine wraps the call in a thread. The test calls it synchronously. Add a comment at the engine call site: `do not call this on the UI thread`.
4. A counter test double for `IBrainBackend.Add`: when enabled is 0, `Add` count stays 0. When enabled is 1 and text is `remember that tests come first`, one candidate body contains `tests come first`. When text is `remember that my api_key is abc`, `Add` count stays 0.
5. Approve/reject test on the real repository: candidate becomes approved; reject does not delete the row; `List` for status candidate no longer returns it.
6. Form wiring in `.lfm`. No `SetBounds`. `lazbuild` the app.
7. `run_tests.sh`.

## 6. Security

- Secret filter test is mandatory.
- Default off test is mandatory.
- Extractor cannot grant tools. Do not add a code path from candidate text to `tools_json` or `allow_write`.
- Thread does not touch LCL controls.

## 7. Speed

- Extraction runs after the run, off the UI thread, and only when the setting is on.
- Rules are string searches, not a model call. Do not add an LLM call "to be smarter" in this task.
- Cap stored body at 500 characters.

## 8. Cloud extraction seam

`ProposeCandidates` is local and pure. Saving goes through `IBrainBackend`. A cloud brain can implement `Add` later without the dialog knowing. The dialog uses `CreateBrainBackend`.

## 9. Tests

```bash
lazbuild tests/test_brain_candidates.lpi && tests/test_brain_candidates
lazbuild lazycodingagent.lpi
```

## 10. README and help updates

[`help/workspace-layout.md`](../help/workspace-layout.md) and a short section in [`help/how-the-agent-works.md`](../help/how-the-agent-works.md): The Brain is off until enabled; it stores a candidate only from an explicit "remember that"; secrets are dropped; the user approves before the memory counts. Do not say memories already change the prompt (task 027). Keywords: `brain`, `remember`, `candidate`.

## 11. Done when

- [ ] Setting off means zero writes.
- [ ] Secret-like "remember that" is dropped.
- [ ] Approve and reject update status.
- [ ] Engine hook is not on the UI thread.
- [ ] Checkbox 026 checked, **NEXT** is task 027.

## 12. Stop

Do not inject memories into the prompt.
