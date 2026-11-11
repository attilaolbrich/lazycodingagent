# m1-read-through-chat-sessions — Chat session repository

**Status:** Not started

**Depends on:** [m1-workspace-schema-v2.md](m1-workspace-schema-v2.md)

## Goal

`IChatSessionRepository` (or split read/write ports) + SQLite adapter. `uChatSessionStore.pas` reads and writes sessions/messages only in workspace `workspace.db`. Field mapping aligned with parent §5.2 (`toolCallId`, `toolCalls`, etc.).

## Deliverables

- Interface(s) in `data/uRepositoryInterfaces.pas`.
- `data/sqlite/uSqliteChatSessionRepository.pas`.
- Refactor `uChatSessionStore.pas` to use repository for load/save/list/archive; stop using `sessions/<wsId>.json` at runtime.

## Acceptance criteria

- [ ] Chat history in UI matches prior behavior for new installs using SQLite only.
- [ ] New messages persist to `messages` with monotonic `seq`.
- [ ] `lastSessionId` / active session stored in `session_prefs` or coordinated with global `workspaces.last_session_id`.
- [ ] Archived sessions flag respected.

## References

- Parent §5.2, `uChatSessionStore.pas`
