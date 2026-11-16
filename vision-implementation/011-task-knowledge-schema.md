# 011 — Knowledge schema

Depends on: [010-task-plan-resume.md](010-task-plan-resume.md) checked.

Do this task only when [README.md](README.md) says **NEXT** is this file.

## 1. Goal and user-visible result

`workspace.db` gains knowledge tables and an FTS5 index. No ingest UI and no embedding calls. Chat, trace, and plan tables stay.

## 2. Out of scope

- Do not fetch files or URLs (task 012+).
- Do not add sqlite-vec.
- Do not register agent tools.

## 3. Read these files first

- [`future-plan/Lazarus_Embedded_Storage_and_Vector_Plan.md`](../future-plan/Lazarus_Embedded_Storage_and_Vector_Plan.md) section 5.3 and 7.1.
- [`future-plan/sqlite/m6-rag-schema-migration.md`](../future-plan/sqlite/m6-rag-schema-migration.md).
- Workspace migration runner. After task 008 the fresh workspace version is **3**. This task adds version **4**.
- `third_party/sqlite` build flags. Confirm `SQLITE_ENABLE_FTS5` is still in [`scripts/build-sqlite-static.sh`](../scripts/build-sqlite-static.sh) (or the Windows script). Do not remove it.

## 4. Design decisions already made

- Workspace migration v4, one transaction. Update fresh-db tests that expected version 3 so they expect **4** and still check older tables exist.
- DDL:

```sql
CREATE TABLE knowledge_sources (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  uri TEXT NOT NULL,
  config_json TEXT NOT NULL DEFAULT '{}',
  enabled INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
);

CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  source_id TEXT NOT NULL,
  title TEXT NOT NULL,
  loc TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  fetched_at TEXT NOT NULL,
  FOREIGN KEY (source_id) REFERENCES knowledge_sources(id) ON DELETE CASCADE
);

CREATE TABLE chunks (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  chunk_index INTEGER NOT NULL,
  text TEXT NOT NULL,
  loc_detail TEXT NOT NULL DEFAULT '',
  content_hash TEXT NOT NULL,
  FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
);

CREATE INDEX idx_chunks_document ON chunks(document_id, chunk_index);
CREATE INDEX idx_documents_source ON documents(source_id);

CREATE VIRTUAL TABLE chunks_fts USING fts5(
  text,
  content='chunks',
  content_rowid='rowid'
);
```

- FTS5 external-content tables need the rowid. `chunks` is created without an explicit rowid alias; SQLite's implicit `rowid` is what `content_rowid` uses. Triggers:

```sql
CREATE TRIGGER chunks_ai AFTER INSERT ON chunks BEGIN
  INSERT INTO chunks_fts(rowid, text) VALUES (new.rowid, new.text);
END;
CREATE TRIGGER chunks_ad AFTER DELETE ON chunks BEGIN
  INSERT INTO chunks_fts(chunks_fts, rowid, text) VALUES('delete', old.rowid, old.text);
END;
CREATE TRIGGER chunks_au AFTER UPDATE ON chunks BEGIN
  INSERT INTO chunks_fts(chunks_fts, rowid, text) VALUES('delete', old.rowid, old.text);
  INSERT INTO chunks_fts(rowid, text) VALUES (new.rowid, new.text);
END;
```

- Also create, empty is fine:

```sql
CREATE TABLE chunk_embeddings (
  chunk_id TEXT PRIMARY KEY,
  model_id TEXT NOT NULL,
  dim INTEGER NOT NULL,
  normalized INTEGER NOT NULL DEFAULT 1,
  embedding_blob BLOB NOT NULL,
  FOREIGN KEY (chunk_id) REFERENCES chunks(id) ON DELETE CASCADE
);

CREATE TABLE ingest_jobs (
  id TEXT PRIMARY KEY,
  source_id TEXT,
  status TEXT NOT NULL,
  cursor_json TEXT NOT NULL DEFAULT '{}',
  error_message TEXT NOT NULL DEFAULT '',
  cancelled INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL
);
```

- `ingest_jobs.source_id` may be null for a job that has not attached a source. Do not add a foreign key that would block that. When you do set it, task 012 checks the source exists.
- Global database must not receive these tables.

## 5. Step-by-step implementation

1. Add the migration. If `CREATE VIRTUAL TABLE` fails because FTS5 is missing, stop and fix the static build flags. Do not fall back to `LIKE` search.
2. Tests in `test_app_database`:
   - Version is 4.
   - Insert a source, document, and chunk through a tiny test helper that uses bound SQL **inside the test program** via a new `TAppDatabase` method `class function WorkspaceHandle(...)` is too leaky. Prefer a short repository later. For this task only, add `class procedure ExecWorkspace(const AWsId, ASQL: string)` **is forbidden** if it concatenates values. Instead add test-only procedures on a new unit `uSqliteKnowledgeSchemaProbe.pas` that inserts with bound parameters and is used by the test. The probe is not used by the app. Still no string-built SQL.
   - After insert, `SELECT text FROM chunks_fts WHERE chunks_fts MATCH 'alpha'` returns the chunk. Use `MATCH` with a bound parameter (`?1`), not concatenated user text. The probe word is the constant `alpha`.
   - Update the chunk text to `beta`. Search `alpha` returns nothing. Search `beta` returns the row.
   - Delete the chunk. Both searches return nothing.
   - Delete the source. Documents and chunks are gone (cascade).
   - Global `TableExists` for `chunks` is false.
3. Do not add the probe unit to the main `lazycodingagent.lpi` if the app does not need it. Test `.lpi` only.

## 6. Security

- FTS queries from later tasks must bind the MATCH string. The probe uses a constant and a placeholder so the pattern is established.
- Cascade delete is the removal path. Test it so a removed source cannot leave searchable text behind.

## 7. Speed

- Indexes on `documents(source_id)` and `chunks(document_id, chunk_index)` are part of the migration, not optional.
- FTS5 is the keyword index. Do not add a second full copy of chunk text outside `chunks` and `chunks_fts`.

## 8. Cloud extraction seam

Tables are the local backend's storage. Later `IKnowledgeBackend` does not expose SQL. This task does not define that interface yet (task 015).

## 9. Tests

```bash
lazbuild tests/test_app_database.lpi && tests/test_app_database
```

## 10. README and help updates

One sentence in [`help/app-data-storage.md`](../help/app-data-storage.md): the workspace database may contain a local knowledge index (sources, chunks, full-text search). Do not describe ingest steps that do not exist yet.

Keyword: `knowledge`.

## 11. Done when

- [ ] FTS follows insert, update, and delete.
- [ ] Deleting a source removes chunks.
- [ ] Global database has no `chunks` table.
- [ ] Fresh workspace version assertion updated to 4 without dropping older assertions' table checks.
- [ ] Checkbox 011 checked, **NEXT** is task 012.

## 12. Stop

Do not ingest files.
