# m1-workspace-schema-v2 — Workspace DB migration v2

**Status:** Not started

**Depends on:** [m0-foundation.md](m0-foundation.md) post-M0 hygiene — **split global vs workspace `RunMigrations`** (today workspace files incorrectly receive global v2 DDL).

## Out of scope

- Chat store wiring ([m1-read-through-chat-sessions.md](m1-read-through-chat-sessions.md)).

## Goal

Add migration **version 2** on per-workspace `workspace.db` for chat persistence tables §5.2.

## Deliverables

- Split migration runner: global file vs workspace file.
- Migration v2 SQL on workspace DB only: `sessions`, `messages`, `session_prefs` (with `ON DELETE CASCADE` on messages).
- Test: create workspace DB under temp dir, migrate to v2, optional smoke insert/select.

## Acceptance criteria

- [ ] `OpenWorkspace(wsId)` applies workspace v2 only (not global registry/LLM tables).
- [ ] Schema version row shows **2** after migrate on workspace DB.
- [ ] Tables match §5.2; composite PK on `(session_id, seq)` for messages.

## References

- Parent plan §5.2
- `uAppDatabase.pas`, `uChatSessionStore.pas` (field names for later mapping)
