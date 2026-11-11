# LazyCodingAgent

[https://lazycodingagent.com/](https://lazycodingagent.com/)

LazyCodingAgent is a cross-platform desktop AI coding assistant and editor built with Free Pascal and Lazarus (LCL). Inspired by tools such as Hermes, Cursor, and Codex, it provides a focused, high-productivity development workspace.

The **interaction model** is a native Lazarus/LCL desktop app (menu bar, docked panels, modal **Settings** and task dialogs), while **agent capabilities** are inspired by tools such as Hermes, Cursor, and Codex.

> **Status:** Multi-window workspace layout implemented. AI/model execution is in active integration.

## Community

- [Contributing](CONTRIBUTING.md) — workflow, CI, Lazarus UI conventions, and tests
- [Code of conduct](CODE_OF_CONDUCT.md)
- [Security policy](SECURITY.md) — report vulnerabilities via GitHub private advisories
- [License](LICENSE.md) — MIT

## Key Features & Workspace Layout

### 1. Lazarus Visual Form Designer Architecture
- Designed directly with Lazarus Visual Designer (`mainunit.lfm` and `mainunit.pas`).
- **LCA Design** palette ([`packages/LcaDesignSystem/`](packages/LcaDesignSystem/)): themed tab bars, buttons, combos, markdown view, terminal panel, and surfaces stream on `.lfm` forms after running [`scripts/install-lca-lazarus`](scripts/install-lca-lazarus.sh) (or `.bat` on Windows).
- Published event handlers hooked cleanly into the state management and theme engine ([`LcaTheme`](packages/LcaDesignSystem/src/LcaTheme.pas), [`uThemeHooks.pas`](uThemeHooks.pas)).

### 2. Modern Dark-First Design & Painted Chrome
- Crisp, modern theme with prominent boundary lines (`BorderStrong` and `Border` tokens) and high-contrast styling.
- **Painted main-window chrome** (all platforms): nav rail (`TLcaPaintNavRailButton`), action/chrome buttons (`TLcaPaintButton`), composer combos (`TLcaPaintComboBox`), nav lists (`TLcaPaintNavList`), and tab strips (`TLcaThemedPageTabBar`) use LCA custom paint — no native Qt/GTK button or combo styling on those controls.
- **Stable cross-platform combo layout**: combo **Height** and **ItemHeight** come from the form resource (`.lfm`); painted combos do not resize at theme apply time. Legacy `TLcaThemedComboBox` in dialogs still uses `StyleComboBox` in [`LcaTheme.pas`](packages/LcaDesignSystem/src/LcaTheme.pas).
- **Designer-first layout**: the main window streams **LCA Design** and stock LCL controls in `.lfm` files (`TLcaPaint*`, `TLcaMarkdownView`, `TLcaTerminalPanel`, `TSynEdit`, etc.). Open `mainunit.pas` in Lazarus (F12) to edit the full layout.
- **Native islands** (intentionally stock LCL): code editor (`TSynEdit`), chat prompt (`TMemo`), project tree (`TTreeView`), embedded terminal (`TLcaTerminalPanel` PTY view), and some Settings/dialog controls.
- **Clean Minimalist Top**: Full vertical viewport space for navigation, chat, and guidelines panels, with comprehensive menu bar and status bar controls.
- Seamless Dark Mode default with instant Light Mode toggle via `View > Toggle Light / Dark Theme`.
- **Navigation rail**: icon captions, tooltips, and accent `Active` state on painted rail buttons.
- **Accent text selection** on navigation lists (painted rows — accent text, no OS highlight band).
- **LCA-painted scrollbars** on chat/plan markdown (`TLcaMarkdownView`) and nav file/log/error lists. Scrollbars on the editor, prompt memo, tree, and terminal still follow the **OS widget theme**.
- **Linux**: **Qt5** widgetset is recommended (`./scripts/install-lca-lazarus.sh --widgetset=qt5`, `lazbuild --widgetset=qt5`) for consistent LCL behavior with painted controls.
- **Linux main menubar**: in-app dark/light toggle syncs the native top menu bar (File, View, …) via the LCL widgetset — Qt5 `QMenuBar` stylesheet, or GTK2/GTK3 colors/CSS — so labels stay readable; dropdown menus are left on the OS theme. **macOS** uses the native menu bar (no in-app menubar sync).
- Clean splitters allowing custom width resizing between all panels.

#### Platform verification checklist

| Check | Windows | Linux (Qt5 recommended) | macOS (Cocoa) |
|-------|---------|-------------------------|---------------|
| Nav rail icons + accent selection | Yes | Yes | Yes |
| List rows: accent text, painted scroll | Yes | Yes | Yes |
| Editor + terminal monospace (no wide char gaps) | Consolas / Cascadia | DejaVu / Liberation | Menlo / SF Mono |
| Primary / Cancel / Stop (main form `TLcaPaintButton`) | Painted | Painted | Painted |
| Markdown + nav list scrollbars | LCA painted | LCA painted | LCA painted |
| Editor / prompt / tree scrollbars | OS theme | OS theme | OS theme |
| Light/dark toggle coherent | Yes | Yes | Yes |
| Main menubar readable in app dark mode | Yes | Yes (Qt5/GTK) | OS menu |

### 3. Docked panels (show / hide)
- Navigation, guidelines, utility, and terminal panels dock on the main form.
- **Window → Panels** and panel **✕** buttons toggle visibility; sizes and visibility persist in workspace settings.

### 4. Vertical Navigation Rail & Panel
- Sleek 56px left navigation rail with icon-only slots, tooltips, and accent active indicator for:
  - **⌂ Home**: Workspace dashboard and overview.
  - **◫ Projects**: Project explorer and file tree.
  - **💬 Sessions**: Per-workspace chat sessions (active and archived lists, archive/restore/delete actions).
  - **⚡ Bots**: Custom coding agents and prompt setups.
- Connected content area with contextual actions for the active navigation selection.

### 5. Primary AI Agent & Chat Workspace
- **Multiple parallel sessions** per workspace: each session has its own `TAgentEngine` and async run thread. Switch sessions from the left **Sessions** nav without stopping other sessions. Background runs continue when you switch workspace and return later.
- **New chat:** **Sessions** → **+ New Chat Session**; the center **Chat** tab shows the active session name.
- **Single chat surface** (no session tab strip). Archive, restore, or delete sessions from the Sessions list.
- **Archive** via Sessions panel (**Archive Session** / **Restore Session**), `Delete` on an active session, or `Shift+Delete` to permanently delete an archived session.
- Clean hero greeting: `What should we build in <project name>?`.
- Embedded workspace badge and live conversation history stream.
- Multiline prompt composer with mode dropdown selector:
  - **Ask**: Fast Q&A without direct workspace mutations.
  - **Plan**: Architecture design, checklists, and specs.
  - **Agent** (*Default*): Full autopilot coding and editing.
- Instant mode and model switching synced with application state and status bar.
- Model selector dropdown supporting `anthropic/claude-3.7-sonnet`, `Hermes-4-70B`, `Hermes-4-405B` (Nous Research), `openai/gpt-4o`, `deepseek/deepseek-r1`, etc. (OpenRouter slugs where noted).

### 6. In-app User Guide
- **Help → User Guide…** (F1) opens a searchable help browser with topics under [`help/`](help/), including how the agent and tools work.
- After `lazbuild`, run [`scripts/post-build.sh`](scripts/post-build.sh) (or [`scripts/post-build.cmd`](scripts/post-build.cmd) on Windows) to copy `help/` and `assets/` next to the executable; when developing from the IDE, topics also resolve from the project `help/` folder.

### 7. Debugging mode and project rules
- **Debugging Mode** (Settings → Agent Behavior): when enabled, full tool JSON results appear in the chat history; when disabled, only tool errors are shown (successful tool calls stay hidden in chat).
- **Project Rules** (main menu → Workspace → Project Rules…): edit per-workspace Markdown files under `<workspace>/.rules/*.md`. Combined rule text is injected into the agent system prompt for Ask, Plan, and Agent modes.

### 8. Reserved Context & Instructions Panel
- Dedicated right-side panel for workspace guidelines, coding rules, and instructions context.

### 9. Utility panel (right)
- **Utility panel** with a `TPageControl`: Execution Detail and Plan.
- **Hidden by default**; toggle via **Window → Panels → Utility Panel**.

### 10. Integrated terminal (bottom panel)
- **View → Terminal** toggles a full-width bottom dock (above the status bar) with a real PTY shell (`$SHELL` / `/bin/bash` on Unix, `%COMSPEC%` on Windows).
- Terminal chrome is on the main form via **`TLcaTerminalPanel`** ([`LcaTerminalPanel.pas`](packages/LcaDesignSystem/src/LcaTerminalPanel.pas)); [`uTerminalPanel.pas`](uTerminalPanel.pas) is a thin alias type for app code.
- Docked height defaults to about **one quarter** of the client area (resizable splitter); floating window size is stored separately from docked height.
- When you open the panel with an active workspace, the shell starts in the **workspace root** (`pwd` / `cd`); switching workspaces restarts the shell in the new folder if the terminal is already visible.
- Powered by a vendored copy of [TerminalEmulator](https://github.com/andrewd207/TerminalEmulator) in `third_party/TerminalEmulator` (BSD 3-Clause; see `third_party/TerminalEmulator/LICENSE`). **Windows** requires Windows 10 1809+ (ConPTY).
- **Linux PTY:** the embedded terminal needs `forkpty` from **libutil** (Debian/Ubuntu: `bsdutils` / `util-linux`). Build the terminal packages via `./scripts/build-terminal-deps.sh` before compiling the app. If the panel stays blank, check the status bar for a PTY error and verify `$SHELL` or `/bin/bash` exists.

#### Terminal manual test checklist

| Step | Linux / macOS | Windows |
|------|----------------|---------|
| View → Terminal shows bottom panel | `pwd` matches workspace | `cd` matches workspace |
| Resize splitter; restart app | Height restored | Height restored |
| Hide / show terminal & utility | Yes | Yes |
| Theme toggle | Colors readable | Colors readable |
| Interactive TUI | `ls` colors; optional `vim`/`nano` | `dir`, `git status` |

---

## Technology Stack

- [Free Pascal (FPC)](https://www.freepascal.org/)
- [Lazarus IDE](https://www.lazarus-ide.org/)
- Lazarus Component Library (LCL)
- Chat history, Markdown file preview, and Help topics use **`TLcaMarkdownView`** — a canvas-painted Markdown subset (no HTML engine).
- **Embedded SQLite:** vendored amalgamation in [`third_party/sqlite/`](third_party/sqlite/), static link via [`LazySqliteStatic`](packages/LazySqliteStatic/) — no system `libsqlite3` at runtime. App settings and workspace registry use `global.db`; chat and syntax schemes still use JSON until later M1 work. See [`future-plan/Lazarus_Embedded_Storage_and_Vector_Plan.md`](future-plan/Lazarus_Embedded_Storage_and_Vector_Plan.md) and [`future-plan/sqlite/README.md`](future-plan/sqlite/README.md).

---

## Building & Running

Clone the repository normally; `third_party/TerminalEmulator` is included in the tree (required for the integrated terminal and **TerminalFramework** / **ViewLCL** packages).

Install **terminal packages**, **LcaDesignSystem** runtime, and (for the Form Designer) the **LCA Design** palette once per machine:

**Linux / macOS:**

```bash
chmod +x scripts/install-lca-lazarus.sh
./scripts/install-lca-lazarus.sh
```

**Windows** (use `.cmd` if PowerShell blocks `.ps1` scripts):

```bat
scripts\install-lca-lazarus.bat
```

(Same as `install-lca-lazarus.cmd`.) Or: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-lca-lazarus.ps1`

**Close Lazarus** before running the full install: the script installs **`LcaDesignSystemDesign`** (palette only) and runs **`lazbuild --build-ide`**. The **runtime** `LcaDesignSystem` package is linked for builds but not embedded in `lazarus.exe`.

On **Linux**, plain `lazbuild` defaults to **GTK2**, so a full install without a widgetset rebuilds the IDE for GTK2. To **rebuild the Lazarus IDE itself for Qt5** (apt install under `/usr/share/lazarus`), close Lazarus and run:

```bash
chmod +x scripts/rebuild-lazarus-ide-qt5.sh
./scripts/rebuild-lazarus-ide-qt5.sh
```

That script creates a writable `units/<cpu>-linux/qt5` directory (see `fpc -iTP`; or run [`ensure-lazarus-qt5-units-dir.sh`](scripts/ensure-lazarus-qt5-units-dir.sh)) with `sudo` when needed, then runs `lazbuild --widgetset=qt5 --build-ide` so **your** IDE (SynEdit, LCA Design, etc. from `~/.lazarus`) is linked into `~/.lazarus/bin/lazarus`. **Do not copy** `/usr/share/lazarus/4.8.0/lazarus` over that file — the system binary is a smaller stock build without your installed design packages. `startlazarus` and the desktop entry use `~/.lazarus/bin/lazarus`; `/usr/share/.../lazarus` is only the apt source tree.

For **LCA Design** packages on Qt5, pass the same widgetset to the install script:

```bash
./scripts/install-lca-lazarus.sh --widgetset=qt5
# or: LCL_WIDGETSET=qt5 ./scripts/install-lca-lazarus.sh
```

If Lazarus **hangs on startup** after an install, run **`scripts\recover-lazarus-ide.bat`**, then reinstall with **`install-lca-lazarus.bat`** (Lazarus closed). See [`packages/LcaDesignSystem/README.md`](packages/LcaDesignSystem/README.md).

Use **`--link-only`** for CI/headless builds without IDE palette install or IDE rebuild (then pass **`--widgetset=qt5`** to `lazbuild` when building the app, if desired).

### Static SQLite (`LazySqliteStatic`)

Before the first **`lazbuild`** (or after a clean clone), compile the embedded SQLite object and register the package:

**Linux / macOS:**

```bash
chmod +x scripts/install-lazarus-sqlite.sh
./scripts/install-lazarus-sqlite.sh
```

On **macOS**, [`build-sqlite-static.sh`](scripts/build-sqlite-static.sh) passes **`-mmacosx-version-min=11.0`** (override with `MACOS_DEPLOYMENT_TARGET`) so the embed object matches FPC’s link minimum on CI and local builds.

**Windows:** compile the amalgamation with **MinGW-w64** (WinLibs or MSYS2 on PATH; CI installs WinLibs via winget). Run `scripts\install-lazarus-sqlite.bat`. Linking uses FPC’s internal linker, **`uSqliteWinEmbedBridge`** (Win32 forwarders), and MinGW import libs from [`ci-lazbuild.ps1`](scripts/ci-lazbuild.ps1). Optional **`SQLITE_CC=msvc`** or **`clang`** for experimental MSVC objects; **`LCA_SQLITE_USE_WINSQLITE3`** falls back to OS `winsqlite3.dll`. See [`docs/sqlite-windows-static-review.md`](docs/sqlite-windows-static-review.md).

```bat
scripts\install-lazarus-sqlite.bat
```

If your policy blocks `.ps1` files, use the `.bat` wrapper (same as [`install-lca-lazarus.bat`](scripts/install-lca-lazarus.bat)). Equivalent: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-lazarus-sqlite.ps1`

This runs [`scripts/build-sqlite-static.sh`](scripts/build-sqlite-static.sh) (or [`.ps1`](scripts/build-sqlite-static.ps1)) and links [`packages/LazySqliteStatic/LazySqliteStatic.lpk`](packages/LazySqliteStatic/LazySqliteStatic.lpk) for `lazbuild`. You do **not** need to edit **Project → Options → Linker** manually: [`lazycodingagent.lpi`](lazycodingagent.lpi) already sets **Libraries** to `packages/LazySqliteStatic/src` and depends on **`LazySqliteStatic`**.

**Lazarus IDE:** open `lazycodingagent.lpi` and **Build** after the install script above (same as CLI). Compile **`LazySqliteStatic.lpk`** once in the IDE if the package is not resolved. The main app links SQLite through **`uSqlite3Embed`**; it does not open databases at startup yet.

**Verify:** `lazbuild tests/test_app_database.lpi` then `./tests/test_app_database` (or run [`tests/run_tests.sh`](tests/run_tests.sh), which includes this when `lazbuild` is available).

Legacy scripts [`scripts/build-terminal-deps.sh`](scripts/build-terminal-deps.sh) / [`.ps1`](scripts/build-terminal-deps.ps1) only link terminal packages; prefer `install-lca-lazarus.*`.

If `lazbuild` is not on `PATH`, set `$env:LAZBUILD` to your `lazbuild.exe` (for example `C:\lazarus\lazbuild.exe`).

**Form designer:** Chrome controls (`TLcaThemedPageTabBar`, `TLcaMarkdownView`, `TLcaTerminalPanel`, etc.) stream on **`mainunit.lfm`** from the **LCA Design** palette after running the install script. **`mainunit.lfm` is the source of truth** for dock layout (Align-based panels and spacer hosts); edit it in the Lazarus IDE. Use `scripts/gen-main-lfm.py` only as a legacy nav-rail scaffold—do not overwrite the live `.lfm` without updating that script first. Open forms from the **`.pas`** unit (**View → Toggle Form Unit** / F12).

Open `lazycodingagent.lpi` in Lazarus, or build from the command line:

**Linux / macOS:**

```bash
./scripts/install-lca-lazarus.sh --link-only
./scripts/install-lazarus-sqlite.sh
lazbuild lazycodingagent.lpi
./scripts/post-build.sh
```

On **Linux**, prefer the **Qt5** LCL widgetset (`lazbuild --widgetset=qt5 lazycodingagent.lpi` or use `make build`, which passes `--widgetset=qt5`). The project file pins **Widget set: qt5** so IDE **Build** matches command-line builds. **`make build` does not refresh the Form Designer** (no `LcaDesignSystemDesign` install or `--build-ide`); after LCA package changes, close Lazarus and run **`make ide`** or **`./scripts/install-lca-lazarus.sh --widgetset=qt5`**. GTK2/GTK3 are also supported with GTK menubar sync.

**Running on Linux:** `make` runs `post-build.sh` automatically. Start the app with `./scripts/run-linux.sh` (on Wayland: sets `QT_QPA_PLATFORM=xcb` for Qt5 builds or `GDK_BACKEND=x11` for GTK2). You can also run `./lazycodingagent` directly; Qt5 builds set `QT_QPA_PLATFORM=xcb` in [`uLinuxDisplayEnv.pas`](uLinuxDisplayEnv.pas) **before** the LCL loads Qt (same effect as IDE **Run** env). GTK2 builds set `GDK_BACKEND=x11` the same way when `WAYLAND_DISPLAY` is set.

### Local web search (SearXNG)

The agent **web_search** tool can use a **local SearXNG** instance (no Brave/Tavily API key). This repo ships a dev-only Compose stack under [`docker/searxng/`](docker/searxng/) with JSON search enabled for LazyCodingAgent. Full notes: [`docker/searxng/README.md`](docker/searxng/README.md).

**Requirements:** [Docker](https://docs.docker.com/get-docker/) with Compose.

```bash
cd docker/searxng
cp .env.example .env
docker compose up -d
```

Check JSON search: `curl -s 'http://127.0.0.1:8080/search?q=test&format=json' | head -c 200` (should print JSON, not HTML). Stop with `docker compose down` from that directory.

**In LazyCodingAgent:**

1. **Settings → Tools → Web Search** — enable Web Search, **Add** provider **SearXNG**, instance URL `http://127.0.0.1:8080`, then **Test** and **OK**.
2. Allow local hosts (blocked by default): set `AllowPrivateInstances=true` under `[WebSearch]` in your user `config.ini`, or launch with `LCA_WEB_SEARCH_TRUSTED_LOCAL=1` (for example `LCA_WEB_SEARCH_TRUSTED_LOCAL=1 ./scripts/run-linux.sh`).

Brave and Tavily are configured in the same settings screen with API keys. See **Help → Web Search** in the app for provider behavior and limits.

### Raspberry Pi 4/5 (64-bit Linux / aarch64)

LazyCodingAgent is not tuned for low-RAM boards, but the same **Linux aarch64** build applies on **Raspberry Pi OS (64-bit)** and similar distros. You need **Lazarus 3.0+**; if apt’s Lazarus is too old, use [fpcupdeluxe](https://github.com/LongDirtyAnimAlf/fpcupdeluxe) for a current FPC/Lazarus install.

**Packages (Debian / Raspberry Pi OS bookworm+):** `git`, `fpc`, `lazarus`, `lcl`, `libqt5pas-dev`, `qtbase5-dev`, `libssl-dev`, `build-essential`, and the same SynEdit prep as desktop Linux (`ci-prepare-lazarus-deps`). For the integrated terminal, ensure **util-linux** / **bsdutils** (`forkpty`).

**Build on the Pi (native, Qt5 recommended):**

```bash
git clone <your-fork-or-upstream> lazycodingagent && cd lazycodingagent
chmod +x scripts/*.sh
./scripts/ensure-lazarus-qt5-units-dir.sh   # once, if apt Lazarus needs a writable qt5 unit dir
./scripts/install-lca-lazarus.sh --link-only --widgetset=qt5
./scripts/install-lazarus-sqlite.sh
lazbuild --widgetset=qt5 lazycodingagent.lpi
./scripts/post-build.sh
./scripts/run-linux.sh
```

The binary is under `lib/aarch64-linux/lazycodingagent`. Use **Qt5 + XWayland** (`run-linux.sh` sets `QT_QPA_PLATFORM=xcb` on Wayland) for the same windowing behavior as desktop Linux. Expect long `lazbuild` times on Pi hardware; 4 GB RAM may need swap during linking.

**Releases:** tagged builds publish an **`arm64` `.deb`** for Pi / ARM64 Linux (system Qt5 and **`libssl3`** via `Depends`). The portable **AppImage** remains **x86_64** only.

**arm64 `.deb` on Pi:** `sudo apt install ./LazyCodingAgent-*-arm64.deb` pulls in Qt5 and OpenSSL 3 runtime packages. HTTPS (Settings **Fetch Models**, chat) needs **`libssl3`** (`libssl.so.3`); the package declares that dependency. If you built from source instead of the `.deb`, install `libssl3` yourself: `sudo apt install libssl3`.

**Release QA on Pi (64-bit OS):** After installing a new **`arm64` `.deb`**, confirm startup and the editor load cleanly (catches SynEdit / form-resource mismatches that only appear at runtime on distro Lazarus builds):

1. `sudo apt install ./LazyCodingAgent-<version>-arm64.deb`
2. Launch from the menu or `/usr/bin/lazycodingagent` — there must be **no** dialog about unknown SynEdit properties (for example `MaxExtraMarksColums`).
3. Open the **Editor** tab; line numbers and gutter should render.
4. Optional: **Settings → Fetch Models** (HTTPS / `libssl3` on the device).

Older release `.deb` packages built before the SynEdit gutter `.lfm` trim may fail at step 2; upgrade to a release that includes that fix or build from current `main`.

**Linux troubleshooting:**

- **No window on Wayland (GTK2 build):** The process runs but nothing appears (not even the splash). Default `lazbuild` on Linux uses GTK2, which often fails to map windows on Wayland. Use `GDK_BACKEND=x11 ./lazycodingagent`, `./scripts/run-linux.sh`, rebuild with the **Qt5** widgetset, or use an X11 session. Requires XWayland (`echo $DISPLAY` should be set, e.g. `:0`). If a window still does not appear on X11, check multi-monitor or saved off-screen bounds in workspace state under your config directory.
- **Title bar drag / resize works in IDE Run but not when launching the built exe (Qt5 + Wayland):** IDE **Run** injects `QT_QPA_PLATFORM=xcb`; rebuild after pulling fixes so startup sets the same, or use `./scripts/run-linux.sh` / `QT_QPA_PLATFORM=xcb ./lazycodingagent`.
- **Canberra Gtk-Message:** `Failed to load module "canberra-gtk-module"` is an optional event-sound module; the GUI still runs. Install with `sudo apt install libcanberra-gtk-module` (Debian/Ubuntu, GTK2 builds), or `GTK_MODULES= ./lazycodingagent`.
- **`install-lca-lazarus.sh` / `mkdir: Permission denied` on `--build-ide`:** With **apt** Lazarus (`/usr/share/lazarus`), rebuilding the IDE for a **new** widgetset (e.g. **qt5**) tries to create `units/<cpu>-linux/qt5` under the system tree (see `fpc -iTP`), which is root-owned. Use **`--link-only --widgetset=qt5`** for command-line builds, or run **`./scripts/ensure-lazarus-qt5-units-dir.sh`** once (sudo), then rerun the full install (Lazarus closed). A user-writable Lazarus install (fpcupdeluxe) avoids this entirely.
- **Lazarus exits when opening `lazycodingagent.lpi`:** Access violation in **`TryLoadOwlIconInto`** while the designer loads **`mainunit`**. Rebuild LCA for **qt5**, then **`lazbuild --widgetset=qt5 --build-ide`** (close Lazarus first; **`--link-only` does not update the IDE**). Or run **`./scripts/install-lca-lazarus.sh --widgetset=qt5`**. On Wayland/Qt5, use **`./scripts/run-lazarus-linux.sh`** if the IDE dies with a Wayland protocol error. Match **Project → Compiler Options → Widget set: qt5**. Emergency: **`./scripts/recover-lazarus-ide.sh`**.

**Windows:**

```bat
scripts\install-lca-lazarus.cmd --link-only
scripts\install-lazarus-sqlite.ps1
lazbuild lazycodingagent.lpi
scripts\post-build.cmd
```

**CI:** GitHub Actions workflow [`.github/workflows/build.yml`](.github/workflows/build.yml) runs the same flow on Linux (**x86_64** and **aarch64** / `ubuntu-24.04-arm` with Qt5), Windows, and macOS (headless `--link-only` install, no IDE palette rebuild), including **`install-lazarus-sqlite`** and the **`test_app_database`** console test on Linux jobs. Linux uses distro Lazarus; Windows and macOS install pinned Lazarus 4.8 from SourceForge on **`macos-15`** (Apple Silicon / `aarch64`) and **`macos-15-intel`** (Intel / `x86_64`; GitHub plans to retire Intel macOS runners around 2027). The Homebrew Lazarus cask is disabled for CI. **SourceForge caching:** pins live in [`scripts/lazarus-ci-artifacts.json`](scripts/lazarus-ci-artifacts.json); [`ci-resolve-lazarus-artifact`](scripts/ci-resolve-lazarus-artifact.sh) checks optional [`tools/lazarus-artifacts/`](tools/lazarus-artifacts/README.md) (`LAZARUS_ARTIFACTS_DIR`), then the runner workdir under **`actions/cache`**, then SourceForge (`LAZARUS_SF_MIRROR` overrides the manifest base URL). Warm Windows jobs cache the installer and the Lazarus tree under `${{ runner.temp }}/lazarus-ci-win64`; prefetch locally with [`prefetch-lazarus-ci-artifacts.sh`](scripts/prefetch-lazarus-ci-artifacts.sh). On **macOS CI**, [`ci-lazbuild.sh`](scripts/ci-lazbuild.sh) passes **`-XR$(xcrun --show-sdk-path)`** and **`-k-ld_classic`** via **`lazbuild --opt`** (and sets **`FPCOPT`** for direct `fpc` calls) so FPC 3.2.4 links under Xcode 16 (`macos-15` runners); install also appends the same flags to system **`fpc.cfg`**. If Apple drops `ld-classic`, pin an older runner or upgrade FPC. [`ci-prepare-lazarus-deps`](scripts/ci-prepare-lazarus-deps.sh) links SynEdit from the Lazarus tree. On Windows, [`gen-owl-branding.bat`](scripts/gen-owl-branding.bat) builds `lazycodingagent_appicon.res` with the Windows SDK **`rc.exe`** when available ([`compile-lazycodingagent-appicon-res.ps1`](scripts/compile-lazycodingagent-appicon-res.ps1)); FPC `windres` is only a fallback for Lazarus-only machines.

### Releasing

Pushing a version tag builds Windows, Linux, and macOS packages and publishes a [GitHub Release](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).

1. Choose the release version (for example `0.1.0`).
2. Tag and push: `git tag v0.1.0` then `git push origin v0.1.0`.
3. Open **Actions → Release** on GitHub and wait for `build-windows`, `build-linux`, `build-linux-aarch64`, `build-macos-aarch64`, `build-macos-x86_64`, and `publish` to finish.
4. Download assets from the release page for that tag:
   - **`LazyCodingAgent-0.1.0-win64-Setup.exe`** — Windows installer ([Inno Setup](https://jrsoftware.org/isinfo.php))
   - **`LazyCodingAgent-0.1.0-amd64.deb`** — Debian/Ubuntu/Mint on **x86_64** (system Qt5 runtime via `Depends`)
   - **`LazyCodingAgent-0.1.0-arm64.deb`** — Debian/Ubuntu/Raspberry Pi OS **64-bit** (ARM64; system Qt5 via `Depends`)
   - **`LazyCodingAgent-0.1.0-x86_64.AppImage`** — portable Linux build on **x86_64** (Qt5 bundled via [linuxdeploy](https://github.com/linuxdeploy/linuxdeploy))
   - **`LazyCodingAgent-0.1.0-aarch64.dmg`** — macOS Apple Silicon (Cocoa app bundle; drag **Lazy Coding Agent** to Applications)
   - **`LazyCodingAgent-0.1.0-x86_64.dmg`** — macOS Intel (same install flow; pick the DMG that matches your Mac)

The workflow [`.github/workflows/release.yml`](.github/workflows/release.yml) runs parallel jobs like [`.github/workflows/build.yml`](.github/workflows/build.yml) (including **`install-lazarus-sqlite`** via release build scripts on Linux/macOS and a dedicated step on Windows): Windows mirrors `build.yml` and runs [`scripts/build-windows-installer.ps1`](scripts/build-windows-installer.ps1) against [`installer/lazycodingagent.iss`](installer/lazycodingagent.iss). Linux **amd64** uses **ubuntu-24.04** (apt Lazarus 3.0+; 22.04’s Lazarus 2.2 is too old), builds with **`--widgetset=qt5`** ([`scripts/ci-linux-qt5-release-build.sh`](scripts/ci-linux-qt5-release-build.sh)), then [`scripts/build-linux-deb.sh`](scripts/build-linux-deb.sh) and [`scripts/build-linux-appimage.sh`](scripts/build-linux-appimage.sh). Linux **arm64** uses **`ubuntu-24.04-arm`**, the same Qt5 release build, and an **`arm64` `.deb`** only (no AppImage). macOS builds twice: **Apple Silicon** on `macos-15` and **Intel** on `macos-15-intel`, each with SourceForge Lazarus 4.8, **`--widgetset=cocoa`** ([`scripts/ci-macos-release-build.sh`](scripts/ci-macos-release-build.sh)), then [`scripts/build-macos-dmg.sh`](scripts/build-macos-dmg.sh) (`hdiutil` DMG with **Lazy Coding Agent.app**). Release DMGs are **ad-hoc signed**; macOS may block the first launch until you right-click the app and choose **Open**, or run `xattr -cr` on the app (Developer ID notarization can be added later). A final **publish** job uploads all artifacts. Tags must match `v*` (for example `v1.2.3`); the `v` prefix is stripped for file names and the release title.

**Linux QA (manual):** CI smoke-tests the built binary, packaged **`.deb`** ([`scripts/smoke-linux-deb.sh`](scripts/smoke-linux-deb.sh)), and **AppImage** under Xvfb with `QT_QPA_PLATFORM=xcb`. Before shipping a tag, test the AppImage and `.deb` on real desktops under **X11 and Wayland** — detachable panels, docking, and multi-monitor behavior differ between compositors. The app sets `QT_QPA_PLATFORM=xcb` on Wayland when unset ([`uLinuxDisplayEnv.pas`](uLinuxDisplayEnv.pas)); verify that still works for your environment.

**Local Linux packages (optional):** after a Qt5 `lazbuild` and [`post-build.sh`](scripts/post-build.sh):

```bash
export APP_VERSION=0.0.0-local
./scripts/build-linux-deb.sh
./scripts/build-linux-appimage.sh
```

DEB installs to `/usr/lib/lazycodingagent` with a `/usr/bin/lazycodingagent` wrapper; runtime libraries come from distribution packages (`dpkg-shlibdeps`, plus an explicit **`libssl3`** dependency for HTTPS). The AppImage bundles Qt5 from the build host — match the **ubuntu-24.04** CI environment when producing release-quality AppImages locally.

**Local installer (optional):** after `lazbuild` and `post-build.ps1`, install Inno Setup 6 and run:

```powershell
./scripts/build-windows-installer.ps1 -Version 0.0.0-local
```

Output is written to `dist/`.

**Local macOS DMG (optional):** after a Cocoa `lazbuild` and [`post-build.sh`](scripts/post-build.sh) into the app bundle `Contents/MacOS` folder:

```bash
export APP_VERSION=0.0.0-local
./scripts/build-macos-icon.sh   # optional if installer/macos/lazycodingagent.icns exists
./scripts/build-macos-dmg.sh
```

**Manual IDE install:** compile `LcaDesignSystem.lpk` (runtime), then `LcaDesignSystemDesign.lpk` → **Use → Install** (after terminal packages). Do not install the runtime package into the IDE.

If the Lazarus IDE hangs when opening this project, use **`recover-lazarus-ide`**, or quit Lazarus and remove `lazycodingagent.lps` (session file), then open `lazycodingagent.lpi` again.

### HTTPS for LLM providers (Fetch Models, chat, agent)

All HTTPS traffic goes through [`uLlmClient.pas`](uLlmClient.pas) (Settings **Fetch Models**, agent completions).

| Platform | Transport | Notes |
|----------|-----------|--------|
| **Windows** | WinHTTP + Schannel ([`uWindowsHTTP.pas`](uWindowsHTTP.pas)) | HTTPS does not need OpenSSL DLLs. Connect/send timeouts and response read timeout follow **Settings → Agent Behavior** (defaults 60s connect, 600s read). Retries and backoff match Linux/macOS. |
| **Linux / macOS** | `fphttpclient` + `opensslsockets` | **OpenSSL 3** runtime (`libssl3` on Debian / Raspberry Pi OS bookworm+). The project vendors a small FPC `openssl` unit tweak so `libssl.so.3` is found (see [`third_party/fpc-openssl3/`](third_party/fpc-openssl3/)). `ConnectTimeout` and `IOTimeout` use the same Settings values (defaults 60s / 600s). Failed requests retry with exponential backoff (Settings → Agent Behavior; default 3 retries from 1s). |

If Fetch Models or chat fails with an OpenSSL error on Linux, install the runtime package: `sudo apt install libssl3` (on some releases the package name is `libssl3t64`). You do **not** need `libssl-dev` to run the app. The app surfaces a dialog instead of crashing when SSL is unavailable. On macOS, use system libs or Homebrew `openssl@3` as usual.

---

## Architecture & Unit Structure

- `lazycodingagent.lpr` — Application entry point
- `mainunit.pas` / `mainunit.lfm` — Main form: nav rail, nav body, center `TPageControl`, utility `TPageControl`, terminal view, menus, splitters, status bar
- `packages/LcaDesignSystem/` — **LcaDesignSystem** runtime package (`LcaTheme`, LCA palette components, Win32 paint helpers)
- `uTerminalPanel.pas` — Alias for `TLcaTerminalPanel` (PTY + `TTerminalLCLView` inside the design-system component)
- `uMainFileEditor.pas` — Single `TSynEdit` load/save/highlighter
- `uPlanView.pas` — Plan utility tab (path, build, memo)
- `third_party/TerminalEmulator/` — Vendored TerminalEmulator: TerminalFramework + ViewLCL packages (see `VENDORED.md` there)
- `uNavigationPanel.pas` — `TNavContentControl` binds to streamed nav controls on the main form
- `uChatPanel.pas` — Binds composer memos/combos/buttons; chat history on `TLcaMarkdownView`
- `packages/LcaDesignSystem/src/LcaMarkdownView.pas` — Canvas Markdown preview for chat, center preview, and Help
- `uPanelDetach.pas` — Detach navigation, chat, guidelines, utility, and terminal panels to floating windows
- `uThemeHooks.pas` — App hooks (SynEdit gutter); registers [`LcaThemeHooks`](packages/LcaDesignSystem/src/LcaThemeHooks.pas) for LCA components and terminal view
- `uChatSessionStore.pas` — Per-workspace JSON persistence for chat sessions (messages, archive flag)
- `uChatSessionHub.pas` — Per-workspace session hub: one `TAgentEngine` per session, parallel runs, save/shutdown
- `uWorkspaceState.pas` — State management; bounds, docking, modes, themes, and LLM settings in `global.db`
- `packages/LcaDesignSystem/src/LcaTheme.pas` — Dark/light design tokens, platform chrome (`ApplyPlatformChrome`), ComboBox/list owner-draw; on Windows, `LcaThemeWin32Buttons.pas` custom-paints primary/cancel/destructive buttons
- `uAppTypes.pas` — Shared enumerations, modes, and helpers
- `uAgentTypes.pas` — Chat roles, LLM providers, tool schemas, and token usage records
- `uAgentEngine.pas` — Autonomous ReAct execution loop, state management, and LLM communication
- `uAgentRules.pas` — Per-workspace `.rules/*.md` load/save for project rules
- `frmWorkspaceRules.pas` / `frmEditRule.pas` — Project rules editor (main menu)
- `uAgentToolBase.pas` — Base tool abstract class (`TAgentTool`), session context, JSON helpers (`ToolError`, `ToolResultFromJson`), mode gating
- `uAgentToolPaths.pas` — Workspace path sandbox, byte I/O, glob matching, symlink/reparse handling
- `uToolProcessCore.pas` — Shared subprocess runner (stdout/stderr caps, timeouts, changed-path tracking)
- `uAgentTools.pas` — Tool factory and registry (`TAgentToolRegistry`) aggregating modular tool classes
- `uToolReadFile.pas` — `read_file` (16 MiB cap, UTF-8/binary checks)
- `uToolWriteFile.pas` — `write_file`
- `uToolApplyPatch.pas` / `uToolEditFile.pas` — `apply_patch` unified diff and `edit_file` search-replace
- `uToolListDirectory.pas` / `uToolGlob.pas` — directory listing and glob (500 entry cap)
- `uToolSearchCode.pas` — `search_code` / alias `grep` (regex, 500 match cap)
- `uToolRunProcess.pas` — `shell` (aliases `terminal`, `run_process`); Windows uses `cmd.exe /C`, Unix uses `/bin/sh -c`
- `uToolDiagnostics.pas` — cached diagnostics + Agent-mode builds (auto-detected toolchains or explicit `command`)
- `uBuildTargetResolver.pas` — maps workspace targets/manifests to build invocations
- `uToolGit.pas` — read-only git inspect (status/diff/log/show)
- `uToolCreatePlanFile.pas` — Plan-mode `.plan/plan-*.md` writer
- `uToolTodo.pas` — session task list (alias `plan`)
- `uMainWorkspace.pas` — Compatibility alias unit

### Agent tools (JSON contract)

Advertised tools: `read_file`, `write_file`, `list_directory`, `glob`, `search_code`, `apply_patch`, `edit_file`, `shell`, `diagnostics`, `git`, `todo`, `create_plan_file`.

Tool messages returned to the LLM are **JSON strings**. Failures include an `error` field; patch failures often add `error_kind` (`context_mismatch`, `format`, `hunk_count_mismatch`, `incomplete_hunk`, `invalid_hunk`, `empty_patch`, `patch_apply`), plus optional `path`, `line`, `hint`, and `partial` when a multi-file patch stops mid-batch. Successful `apply_patch` may include `warnings` when minor hunk headers were auto-corrected.

| Mode | Write / shell / patch | Plan files |
|------|------------------------|------------|
| Ask | Blocked | Blocked |
| Plan | Blocked | `create_plan_file` allowed |
| Agent | Full mutating set | Allowed |

### Running tool integration tests

[`tests/run_tests.sh`](tests/run_tests.sh) / [`.bat`](tests/run_tests.bat) compile tool-driver tests and, when `lazbuild` is on `PATH`, run **`tests/test_app_database`** (embedded SQLite M0: `global.db` / `workspace.db` round-trip via `IAppSettingsRepository`).

### Manual check: parallel chat sessions

1. In workspace A, start an agent run in session 1; switch to session 2 (nav or tab) and start another run — both should finish; session 1 transcript updates when re-selected.
2. Switch to workspace B while A still has a run; return to A — run completed or still active; messages persisted.
3. Archive an active session — run stops; session appears under **Archived**; composer disabled until restored.
4. Close the app with multiple runs — confirm prompt to stop all runs; exit cleanly.
5. Toggle dark/light theme and resize the chat dock — no `ChangeBounds` loop.

Requires FPC, Lazarus `lazutils` on the unit path, and Python 3:

```bat
tests\run_tests.bat
```

```bash
tests/run_tests.sh
```

Builds `tests/tool_driver.lpr` and runs `tests/test_local_tools.py` (patch, path sandbox, shell, diagnostics fixtures ported from lazcodingagent).
