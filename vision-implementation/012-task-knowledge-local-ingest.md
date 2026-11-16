# 012 — Local knowledge ingest

Depends on: [011-task-knowledge-schema.md](011-task-knowledge-schema.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

The app can index local Markdown, plain text, and a pasted string into `documents` and `chunks`. Unchanged content is skipped. A job row can be cancelled. No UI beyond what a test calls. No embeddings yet.

## 2. Out of scope

- Do not fetch HTTP, PDF, or Confluence (tasks 022–024).
- Do not call an embedding API (task 013).
- Do not add agent tools (task 016).
- Do not enable the Knowledge Base dialog (task 017).

## 3. Read these files first

- Knowledge tables from task 011.
- [`uChatSessionStore.pas`](../uChatSessionStore.pas) path helpers are a bad model for security. Follow workspace-root checks like task 008's markdown writer.
- Unit `sha1` (already used by [`data/uSecurityManager.pas`](../data/uSecurityManager.pas)). There is no project SHA-256 wrapper. Hash function is specified below.

## 4. Design decisions already made

- Content hash is `sha1:` plus lowercase hex from `SHA1Print` in unit `sha1`. Prefix is required so a later algorithm change does not collide. This hash is for skip-if-unchanged, not for passwords.
- Chunking: window 1200 characters, overlap 200. If a newline exists in the last 200 characters of the window, break there. Each chunk stores `chunk_index` starting at 0, `loc_detail` like `chars 0-1180`. Hash the chunk text, not the whole file, for the chunk row. Hash the whole document text for `documents.content_hash`.
- If an existing chunk for that document has the same `chunk_index` and same `content_hash`, leave it (do not delete and reinsert). If the hash differs, update the text. If the new chunk count is smaller, delete trailing chunk indexes.
- Skip embedding work. Do not write `chunk_embeddings` in this task. If a chunk's text changes, delete that chunk's embedding row if one exists so task 013 will not keep a stale vector. `DELETE FROM chunk_embeddings WHERE chunk_id = ?1`.
- Paths: only files under the workspace root, extension `.md` or `.txt` (case-insensitive). Reject `..`, absolute paths outside the root, and symlinks that resolve outside the root (`ExpandFileName` / real path compare). Maximum file size 2 MiB. Larger files set the job error and index nothing from that file.
- Pasted text: `kind = text`, no path. Maximum 2 MiB. `documents.loc` is `paste:<id>`.
- Jobs:

```text
status: queued | running | done | error | cancelled
```

- Interface GUID: `{F3C6D8E0-2B94-4D77-AC31-5D8F904E1263}`

```pascal
TIngestRequest = record
  WorkspaceRoot: string;
  Kind: string;       { 'file' or 'text' }
  Locator: string;    { relative path for file; empty for text }
  Text: string;       { pasted body; empty for file }
  Title: string;
end;

TIngestJobSnapshot = record
  Id: string;
  SourceId: string;
  Status: string;
  ErrorMessage: string;
  Cancelled: Boolean;
end;

IKnowledgeIngest = interface
  ['{F3C6D8E0-2B94-4D77-AC31-5D8F904E1263}']
  function Start(const AWorkspaceId: string; const AReq: TIngestRequest): string;
  procedure RequestCancel(const AWorkspaceId, AJobId: string);
  function GetJob(const AWorkspaceId, AJobId: string; out AJob: TIngestJobSnapshot): Boolean;
end;
```

- Implementation `TLocalKnowledgeIngest` in `uKnowledgeIngest.pas` uses a **repository** `IKnowledgeStore` (GUID `{A4D7E9F1-3C05-4E88-BD42-6E90A15F2374}`) implemented in `data/sqlite/uSqliteKnowledgeStore.pas`. The ingest unit must not call `sqlite3_*`.
- `IKnowledgeStore` methods this task needs: `UpsertSource`, `FindDocumentByLoc`, `UpsertDocument`, `ListChunks`, `UpsertChunk`, `DeleteChunk`, `DeleteEmbeddingsForChunk`, `InsertJob`, `UpdateJob`, `GetJob`. Define them with records, bound SQL, transactions around one document's chunk replace.
- `Start` runs synchronously in this task (tests need determinism). Still check `cancelled` between chunks. Task 017 moves the call onto a thread; do not start a thread here.
- `kind` for a file source is `file`. URI stored is the relative path using `/` separators.

## 5. Step-by-step implementation

1. Add the two interfaces to [`data/uRepositoryInterfaces.pas`](../data/uRepositoryInterfaces.pas). `IKnowledgeIngest` may live in `uKnowledgeIngest.pas` instead if you want the repository unit free of ingest types. **Decision:** both interfaces live in `uRepositoryInterfaces.pas` so later HTTP code can implement them without depending on the local ingest unit. If that creates a uses cycle, move the ingest interface to `uKnowledgeTypes.pas` with no SQL.
2. Implement the SQLite store and `TLocalKnowledgeIngest`.
3. `TAppDatabase` exposes `KnowledgeStore(AWsId): IKnowledgeStore`. A factory function `CreateLocalKnowledgeIngest: IKnowledgeIngest` lives in `uKnowledgeIngest.pas` and calls `TAppDatabase` only from the local class. Tests can construct the local class with a fake `IKnowledgeStore`.
4. Tests `tests/test_knowledge_ingest.lpr` with temp workspace root and temp config root:
   - Write `notes/a.md` containing a unique word `ZephyrToken` repeated enough to make two chunks (more than 1200 characters). Ingest. Assert two chunks and FTS can see `ZephyrToken` (through the store or a probe query inside the SQLite test, not the UI).
   - Ingest the same file again. Chunk ids for unchanged hashes stay. `GetJob` status `done`.
   - Change the file. Ingest. The changed chunk hash differs. Embedding row, if you inserted one manually before the second ingest, is deleted.
   - Locator `../secret.txt` does not read a file outside the root. Job status `error`. No document row.
   - File bigger than 2 MiB: error, no chunks. You can pass a fake store and a request whose text length is checked before read; for the file path, write a sparse or a short test that stubs size. Easiest: `TLocalKnowledgeIngest` checks `FileSize` and the test writes 2 MiB + 1 of the letter `a` in temp. That is acceptable.
   - `RequestCancel` before `Start` returns: set cancelled on a queued job and `Start` must observe it. Because `Start` is synchronous, add `RequestCancel` support by a test double store whose `GetJob` returns cancelled after the first chunk. Assert the second chunk is not written.
5. Register units in the app `.lpi` only for units the app will link. The ingest unit should be in the app `.lpi` even before the UI, so task 017 does not hunt for it. Add the test to `run_tests.sh`.

## 6. Security

- Path escape test is mandatory.
- File content is data. It is stored as chunk text. It is not executed and not concatenated into SQL.
- Do not follow a path that resolves outside the workspace after symlink expansion.
- Job `error_message` may include the relative path, not the full user home path if you can avoid it. Relative path is enough.

## 7. Speed

- One transaction per document, not per chunk.
- Unchanged hash skips update.
- Do not embed and do not open network sockets. The ingest unit's uses clause must not include `fphttpclient` or `opensslsockets`.

## 8. Cloud extraction seam

`IKnowledgeIngest` is what a remote ingest service can implement later. Local code is `TLocalKnowledgeIngest`. Callers in task 017 must depend on the interface.

## 9. Tests

```bash
lazbuild tests/test_knowledge_ingest.lpi && tests/test_knowledge_ingest
```

## 10. README and help updates

[`help/app-data-storage.md`](../help/app-data-storage.md): local markdown and text can be indexed into the workspace database. No menu steps yet. Do not document URL ingest.

README: one short sentence.

## 11. Done when

- [ ] Two-chunk ingest and FTS hit work.
- [ ] Unchanged file does not churn chunk ids.
- [ ] `../` and oversize file do not index.
- [ ] Cancel stops later chunks in the double test.
- [ ] Checkbox 012 checked, **NEXT** is task 013.

## 12. Stop

Do not call an embedding provider.
