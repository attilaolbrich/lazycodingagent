# m6-rag-hybrid-retrieval — Hybrid retrieval Phase A

**Status:** Not started

**Depends on:** [m6-rag-schema-migration.md](m6-rag-schema-migration.md)

## Out of scope

- sqlite-vec (Phase B).
- Remote paid backends (separate item).

## Goal

`IKnowledgeIndexRepository` + workspace knowledge service: FTS candidate retrieval, load embedding BLOBs, in-process cosine/dot rerank, optional MMR (§7.1).

## Deliverables

- Repository interface in `data/uRepositoryInterfaces.pas`.
- SQLite implementation + Pascal ranker.
- Hook for context assembly / future `search_knowledge` tool.

## Acceptance criteria

- [ ] Query returns top-K chunks with citations (source, title, excerpt).
- [ ] Works on fixture corpus in tests (no cloud required).
- [ ] p95 latency documented on reference hardware.

## References

- Parent §7.1, §7.3, [Lazarus_AI_Agent_Future_Plan.md](../Lazarus_AI_Agent_Future_Plan.md) §7
