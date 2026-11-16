# 017 — Knowledge settings UI

Depends on: [016-task-knowledge-tools.md](016-task-knowledge-tools.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

**Workspace → Workspace Knowledge Base…** manages **local** sources: add a markdown or text file, add pasted text, remove a source, reindex, cancel a job, and show the last error.

URL, PDF, and Confluence controls stay disabled with a short "later" caption. Coming Soon for the whole dialog goes away.

Ingest runs off the UI thread. The form stays responsive.

## 2. Out of scope

- Do not implement URL fetch, PDF, or Confluence here.
- Do not add a new main-window page. This stays a modal `frm*`.
- Do not let the dialog run SQL.

## 3. Read these files first

- [`frmKnowledgeBaseConfig.pas`](../frmKnowledgeBaseConfig.pas) and its `.lfm`.
- `IKnowledgeIngest`, `IKnowledgeStore`, `IEmbeddingProvider`, `CreateKnowledgeBackend`.
- `.cursor/rules/lazarus-lcl-layout.mdc` — no `Align` plus `SetBounds` on the same control. No layout work inside `OnResize` without a re-entry guard. This task should not need `OnResize`.

## 4. Design decisions already made

- Enable only controls for local file, pasted text, remove, reindex, cancel, and a memo or label for the last error.
- Leave other preview controls disabled.
- Add file: use a file-open dialog. Copy is not required; store the relative path if the file is under the workspace, otherwise the ingest service returns the error from task 012. Show that error. Do not copy arbitrary files into the workspace automatically.
- Paste: a memo already on the form or a new memo in the `.lfm` with `Align = alClient` inside an existing panel.
- Remove: confirm dialog, then delete the source through `IKnowledgeStore` (add `DeleteSource` if missing). Cascade drops documents, chunks, FTS rows, embeddings.
- Reindex: call `IKnowledgeIngest.Start` then `EmbedMissingChunks` for that document.
- Threading: `TThread` (or the app's existing worker if one is obvious in `mainunit.pas`). The thread must not touch controls. When finished, `TThread.Queue` or `Synchronize` updates the label and the list. Catch exceptions on the thread and pass the message back.
- Cancel sets `RequestCancel` on the job id. The synchronous ingest from task 012 checks cancel between chunks; call it from the worker so the UI thread is free. If ingest is one shot, still do not run it on the main thread. For a huge file the UI would freeze. The worker calls `Start`.
- `EmbedMissingChunks` also runs on that worker, after ingest, unless the job was cancelled.
- Default embedding provider: `TDeterministicEmbedding` unless `embed.provider` is `http` and task 013 settings are complete. If HTTP is selected but `Embed` returns not configured, show the error and keep the chunks (keyword index still exists, search may drop them until vectors exist — that is acceptable). Do not block the UI on a retry loop.
- No workspace: disable write buttons, same pattern as task 009.

## 5. Step-by-step implementation

1. Update `.lfm` captions, `Enabled`, `OnClick`. Published handlers.
2. Hide or clear the Coming Soon banner for this form.
3. List sources with `IKnowledgeBackend.ListSources` on show and after each job.
4. Worker procedure owns no visual control.
5. `lazbuild lazycodingagent.lpi` must succeed.
6. Add a test that does not need the form: `DeleteSource` removes FTS hits. Put it in `tests/test_knowledge_ingest.lpr` or the backend test. The form itself is checked by `lazbuild` plus a manual note in the summary (open dialog, buttons enabled only for local actions).
7. Resize: do not add resize code. If you touch `OnResize`, you have gone outside this task.

## 6. Security

- The dialog cannot index a path outside the workspace; ingest already rejects it. Show the error. Test remains the one from task 012. Re-run it.
- Do not display decrypted API keys on this form.
- Removed sources disappear from search. The delete test covers that.

## 7. Speed

- Worker thread for ingest and embed. UI thread only paints.
- Do not reindex every source when the dialog opens. Only list them.
- One document per add action.

## 8. Cloud extraction seam

The form uses `IKnowledgeIngest`, `IKnowledgeBackend`, and `IEmbeddingProvider`. It does not name `TSqliteKnowledgeStore`. A cloud backend can replace `CreateKnowledgeBackend` later. Local ingest stays `CreateLocalKnowledgeIngest` until a remote ingest exists; the form should call a factory `CreateKnowledgeIngest` added in `uKnowledgeIngest.pas` that returns the local class, so the form does not name `TLocalKnowledgeIngest`.

## 9. Tests

```bash
lazbuild tests/test_knowledge_ingest.lpi && tests/test_knowledge_ingest
lazbuild lazycodingagent.lpi
```

## 10. README and help updates

- New or updated section in [`help/workspace-layout.md`](../help/workspace-layout.md) and a short [`help/`](../help/) subsection (the layout topic is enough if it stays readable): how to add a local file or paste, remove, reindex, cancel. State URL/PDF/Confluence are not available yet.
- [`help/index.json`](../help/index.json) keywords: `knowledge base`, `reindex`, `markdown`.
- README: the menu item is functional for local sources.

## 11. Done when

- [ ] Dialog enables local actions and leaves URL/PDF/Confluence disabled.
- [ ] Ingest is not called on the UI thread (the worker is visible in the code path the button uses).
- [ ] Delete-source test shows the chunk is gone from FTS.
- [ ] Help matches the buttons you enabled.
- [ ] Checkbox 017 checked, **NEXT** is task 018.

## 12. Stop

Do not add agent roles.
