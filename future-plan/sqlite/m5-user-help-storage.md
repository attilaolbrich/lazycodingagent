# m5-user-help-storage — In-app User Guide (storage)

**Status:** Not started (partial content in `help/app-data-storage.md`)

**Depends on:** Chat/syntax SQLite cutover optional for full topic; global storage topic can ship earlier.

## Goal

When storage behavior stabilizes, update in-app User Guide per user-help rule: where `global.db` and `workspace.db` live, what is stored where, backup tips, manual recovery (restore or replace `global.db`).

## Deliverables

- Extend or add help topic(s); update `help/index.json` keywords (`sqlite`, `database`, `backup`, `migration`).
- Align with [help/app-data-storage.md](../../help/app-data-storage.md) — no legacy INI/JSON recovery or `LAZYCODINGAGENT_LEGACY_STORAGE`.

## Acceptance criteria

- [ ] Help menu topic discoverable via search keywords.
- [ ] Describes SQLite layout and backup/recovery without referencing cancelled importers.

## References

- `.cursor/rules/user-help.mdc`, `uHelpContent.pas`
