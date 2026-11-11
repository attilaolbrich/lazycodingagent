# m6-rag-schema-migration — RAG tables + FTS5

**Status:** Not started

**Depends on:** [m5-user-help-storage.md](m5-user-help-storage.md) (do not start M6 until M5 done)

## Out of scope

- Ingest UI, embedding API calls, agent tools.

## Goal

Workspace DB migration adding §5.3 tables (`knowledge_sources`, `documents`, `chunks`, `chunk_embeddings`, `ingest_jobs`) and `chunks_fts` virtual table with sync triggers.

## Deliverables

- Migration vN on workspace DB only.
- Schema version bump documented in parent plan.

## Acceptance criteria

- [ ] Fresh workspace can migrate to RAG schema without affecting chat tables.
- [ ] FTS5 triggers maintain `chunks_fts` on chunk CRUD.
- [ ] Static SQLite build includes FTS5 (already in M0 amalgamation flags).

## References

- Parent §5.3, §7.1
