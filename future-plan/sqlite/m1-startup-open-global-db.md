# m1-startup-open-global-db — Open global DB at startup

**Status:** Done

**Depends on:** —

## Goal

Wire `uAppDatabase.OpenGlobal` (and migration runner) from application startup so `global.db` exists and migrates early. Repositories receive connections via `TAppDatabase` (no SQL in UI units).

## Delivered

- `lazycodingagent.lpr`: `EnsureGlobalConfigReady` before main form.
- `data/uGlobalConfigBootstrap.pas`: opens global DB, marks fresh install import timestamp in `app_settings`.
- `LAZYCODINGAGENT_DATA_ROOT` / `SetConfigRootOverride` unchanged for tests.
- `finalization` in `uAppDatabase.pas` closes DB on app exit.

## Acceptance criteria

- [x] Normal app start creates or opens `global.db` under user config dir.
- [x] Repositories use the opened global connection after bootstrap.
- [x] No legacy file rename on startup.

## References

- `uAppDatabase.pas`, `lazycodingagent.lpr`, `data/uGlobalConfigBootstrap.pas`
