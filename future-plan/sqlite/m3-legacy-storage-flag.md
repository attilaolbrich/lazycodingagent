# m3-legacy-storage-flag — legacy storage escape hatch

**Status:** Cancelled — superseded

Application settings use **SQLite only** (`global.db`). There is no `LAZYCODINGAGENT_LEGACY_STORAGE` escape hatch and no INI/JSON config readers for workspace, LLM, web search, or browser settings.

See [help/app-data-storage.md](../../help/app-data-storage.md) for recovery (backup/restore `global.db`).
