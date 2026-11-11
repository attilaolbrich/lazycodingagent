# m6-remote-knowledge-brain-backends — Remote KB / Brain APIs

**Status:** Not started

**Depends on:** [m6-rag-hybrid-retrieval.md](m6-rag-hybrid-retrieval.md) (local path first)

## Out of scope

- Hosting the paid service (client only).

## Goal

`IKnowledgeBackend` / `IBrainBackend` abstractions with HTTP clients under `data/remote/`; composite implementation merges local SQLite index with remote results per persistence rule.

## Deliverables

- Interfaces + config in settings (endpoints, API keys in same practical security model as LLM keys).
- Feature flags to disable remote.

## Acceptance criteria

- [ ] App runs with remote disabled (local only).
- [ ] Remote errors degrade gracefully (local fallback).
- [ ] No SQL from remote layer into UI units.

## References

- `.cursor/rules/persistence-and-data-access.mdc`, parent §7
