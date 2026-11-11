# Windows SQLite static embedding — review (branch)

## Summary

| Approach | Link (FPC 3.2 internal) | Runtime | Static in EXE | Bridge |
|----------|-------------------------|---------|---------------|--------|
| **winsqlite3.dll** (v0.1.35) | N/A | OK | No | None |
| **MSVC `cl` + bridge** | OK with `/Gy-` + bridge | **AV in `sqlite3_initialize`** | Intended | ~420 lines + `__imp_*` |
| **MinGW-w64 gcc + bridge + `.a`** | OK with `-k` MinGW libs | **OK** (`test_app_database`, smoke) | Yes | Win32 forwarders + few MinGW-only symbols |

**Recommendation:** Use **MinGW-w64** as the default Windows amalgamation compiler. Keep **`uSqliteWinEmbedBridge.pas`** as a thin Win32/CRT forwarder layer (smaller than MSVC-only path: MinGW `.a` files resolve CRT and most `__imp_*`). Optional **`LCA_SQLITE_USE_WINSQLITE3`** for emergency fallback. **`LCA_SQLITE_EMBED_WIN`** remains for MSVC object experiments.

## Platform matrix (after change)

| OS | Runtime | Build |
|----|---------|--------|
| Linux / macOS / Pi | Static `{$L sqlite3_embed.o}` | `build-sqlite-static.sh` |
| Windows | Static MinGW object | `build-sqlite-static.ps1` (default MinGW; `SQLITE_CC=msvc\|clang`) |

## Diagnostics

- MSVC undefined symbols: `docs/win-sqlite-embed-msvc-undef.txt` (from `scripts/diagnose-sqlite-embed.ps1`)
- MinGW: run `diagnose-sqlite-embed.ps1` after `SQLITE_CC=mingw` build

## API fix

`sqlite3_free` is declared as **`procedure`** (C `void`), not `function: cint`.

## Future sqlite-vec

Static amalgamation on all platforms is required; OS `winsqlite3.dll` cannot load custom extensions.

## Reproduce MSVC static failure

Build with `SQLITE_CC=msvc`, define `LCA_SQLITE_EMBED_WIN` on the project, run `tests/test_app_database` — expect access violation during DB open (same as pre-v0.1.35 embed path).
