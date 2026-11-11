# m3-cutover-default-sqlite — SQLite-only default backend

**Status:** Partial — global config done; chat and syntax still JSON

## Global config (done)

- `uWorkspaceState`, `uWorkspaceRegistry`, web search, browser read settings: **SQLite only** in `global.db`.
- New installs do not create legacy INI or `workspaces.json` for these concerns.

## Still on disk (pending M1)

- Chat: `uChatSessionStore.pas` → `sessions/<workspaceId>.json`
- Syntax: `uSyntaxSchemeRegistry.pas` → `syntax-schemes.json` and per-scheme files

## Acceptance criteria

- [x] Fresh install: `global.db` holds app settings and workspace registry.
- [ ] Chat and syntax use only DB files under config (after m1e / m1f).

## References

- [m1-read-through-chat-sessions.md](m1-read-through-chat-sessions.md), [m1-read-through-syntax-schemes.md](m1-read-through-syntax-schemes.md)
