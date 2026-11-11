# SQLite amalgamation (vendored)

Official amalgamation from [sqlite.org](https://www.sqlite.org/download.html). Version in `VERSION.txt`.

## Build flags (via `scripts/build-sqlite-static.sh` / `.ps1`)

### Linux / macOS / Raspberry Pi

- **`build-sqlite-static.sh`:** GCC/Clang, `-fPIC`, same `SQLITE_*` defines.
- **macOS:** `-mmacosx-version-min` (default **11.0** via `MACOS_DEPLOYMENT_TARGET`) so `sqlite3_embed.o` matches FPC’s default Darwin link minimum; required on newer Xcode / GitHub `macos-15` runners.
- Link: `{$L sqlite3_embed.o}` + `{$linklib c}` / `m` in [`uSqlite3Embed.pas`](../../packages/LazySqliteStatic/src/uSqlite3Embed.pas).

### Windows (default: static MinGW embed)

- **`build-sqlite-static.ps1`** compiles with **MinGW-w64 `x86_64-w64-mingw32-gcc`** when WinLibs/MSYS2 is on PATH (see [`scripts/resolve-mingw-win64.ps1`](../../scripts/resolve-mingw-win64.ps1)). CI installs WinLibs via winget.
- **Link:** FPC internal linker + [`uSqliteWinEmbedBridge.pas`](../../packages/LazySqliteStatic/src/uSqliteWinEmbedBridge.pas) (Win32 `public name` forwarders and a few MinGW-only symbols) + MinGW import archives passed as `-k…/lib*.a` from [`scripts/ci-lazbuild.ps1`](../../scripts/ci-lazbuild.ps1).
- **Fallback:** define **`LCA_SQLITE_USE_WINSQLITE3`** on the project to use OS `winsqlite3.dll` (no static embed).
- **Experimental MSVC object:** `SQLITE_CC=msvc` or `clang` — `/Gy-`, bridge, still **unreliable at runtime** with `LCA_SQLITE_EMBED_WIN`; see [`docs/sqlite-windows-static-review.md`](../../docs/sqlite-windows-static-review.md).

Shared defines:

- `SQLITE_ENABLE_FTS5` — keyword search for future workspace knowledge base
- `SQLITE_THREADSAFE=1`
- `SQLITE_ENABLE_JSON1`

Unix only: `-Wno-discarded-qualifiers` (or `-Wno-ignored-qualifiers` on Darwin) for upstream amalgamation noise. On Darwin, override the deployment target with `MACOS_DEPLOYMENT_TARGET=12.0 ./scripts/build-sqlite-static.sh` if you change the app’s minimum macOS in the Lazarus project.

Runtime: WAL mode is enabled in `uAppDatabase` when opening databases.

## Future: sqlite-vec (Phase B)

When profiling requires approximate nearest-neighbor search, extend the amalgamation build to compile **sqlite-vec** into the same static object (see `future-plan/Lazarus_Embedded_Storage_and_Vector_Plan.md` §7.2). Use `BUILD_SQLITE_VEC=1` when that hook is implemented.

## License

SQLite is in the public domain. See the blessing in `sqlite3.h`.
