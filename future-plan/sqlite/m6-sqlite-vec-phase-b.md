# m6-sqlite-vec-phase-b — sqlite-vec (optional)

**Status:** Not started

**Depends on:** [m6-rag-hybrid-retrieval.md](m6-rag-hybrid-retrieval.md)

## Out of scope

- Mandatory ship criterion for desktop v1.

## Goal

Only if Phase A fails profiling gates (§7.2: ~50k+ chunks or p95 > ~200 ms): compile **sqlite-vec** into static amalgamation, extend `chunk_embeddings` usage or vec0 virtual tables, benchmark vs in-process rerank.

## Deliverables

- Build script changes in `third_party/sqlite/` + `LazySqliteStatic`.
- Decision record in parent plan or ADR with measurements.

## Acceptance criteria

- [ ] Profiling report attached before merge.
- [ ] Same single-binary deployment model (no extra dylib).
- [ ] Feature can remain off by default.

## References

- Parent §7.2
