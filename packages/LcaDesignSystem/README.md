# LcaDesignSystem

Lazy Coding Agent **design system** for Lazarus: theme tokens and palette components stream on `.lfm` forms.

## Palette (`LCA Design`)

The **main window** and **app dialogs** (Settings, rules, model search, themed message box, etc.) use the **painted** stack (`TLcaPaint*`, `TLcaScrollHost` inside markdown/lists). Legacy `TLcaThemed*` types remain on the palette for older forms or gradual migration.

| Component | Purpose |
|-----------|---------|
| `TLcaThemedPageTabBar` | Painted tab strip for `TPageControl` with `ShowTabs = False` |
| `TLcaPaintButton` | Primary / cancel / destructive / ghost — fully custom-painted on all platforms |
| `TLcaPaintComboBox` | Painted field + dropdown list; set `Height`/`ItemHeight` in the form |
| `TLcaPaintNavRailButton` | Navigation rail cell (icon caption, `Active` state) |
| `TLcaPaintNavList` | Painted nav list with `TLcaScrollHost` scrollbars |
| `TLcaPaintSurface` | Themed fill/border surface (`TLcaThemedControl`) |
| `TLcaScrollHost` | Painted scroll container (used inside markdown view and nav list) |
| `TLcaThemedButton` | Legacy `TButton` + theme roles (dialogs, older forms) |
| `TLcaThemedComboBox` | Legacy owner-draw `TComboBox` (e.g. Settings) |
| `TLcaNavRailButton` | Legacy `TSpeedButton` rail cell |
| `TLcaSurfacePanel` | Card surface with optional accent border |
| `TLcaMarkdownView` | Canvas-painted Markdown subset (chat, help, previews) with integrated themed scrollbar |
| `TLcaTerminalPanel` | Embedded PTY terminal (requires TerminalEmulator packages) |
| `TLcaThemedMainMenu` | In-window main menu (pairs with `TLcaThemedTitleBar` / menu bar) |
| `TLcaThemedMenuBar` | Top menu strip inside the custom title bar |
| `TLcaThemedTitleBar` | Frameless window chrome: logo, menu, drag region, min/max/close |

Theme API lives in **`LcaTheme`** (`TThemeKind`, `ThemePalette`, `ApplyThemedForm`, etc.). Palette tokens target a **neutral IDE** look (muted grays/blues); shared owner-draw helpers live in **`LcaPaintPrimitives`**.

### Palette icons

Every class on **LCA Design** must have a **dedicated 24×24 IDE glyph** (not the generic LCL default). Sources live in `res/glyphs/`; build `res/lca_design_glyphs.res` with [`scripts/build-lca-glyphs.sh`](../../scripts/build-lca-glyphs.sh) (or `.bat`). Wire-up is design-time only via [`design/LcaDesignReg.pas`](design/LcaDesignReg.pas) / `LcaDesignSystemDesign`. See [PALETTE-ICONS.md](../../docs/delivery/lca-painted-controls/PALETTE-ICONS.md). After adding or changing glyphs, **close Lazarus** and re-run [`scripts/install-lca-lazarus.sh`](../../scripts/install-lca-lazarus.sh) with `--build-ide` (e.g. `--widgetset=qt5` on Linux).

## Opening in Lazarus (Form Designer)

`lazbuild` only needs the **runtime** package (`LcaDesignSystem.lpk`). The **Form Designer** also needs **`LcaDesignSystemDesign`** compiled, installed into the IDE, and a rebuilt IDE binary (`lazbuild --build-ide`; see install below). On Linux/Qt5, **`make build` alone does not update the designer** — use **`make ide`** or **`./scripts/install-lca-lazarus.sh --widgetset=qt5`**. After install, reopen **`mainunit`** (F12); LCA chrome should use the **light palette** in the designer (readable dark-first `.lfm`).

If opening **`mainunit.pas`** (F12) shows **Unable to find component class 'TLcaThemedMainMenu'** (or another `TLca*` type):

1. **Quit Lazarus completely** (no `lazarus.exe` in Task Manager).
2. From the repo root, run **`scripts\install-lca-lazarus.bat`** (or `.sh` on Linux/macOS).
3. Start **`C:\lazarus\lazarus.exe`** (or the Lazarus tree your `lazbuild` uses — check **Tools → Configure Build Lazarus**).
4. Confirm **Component → LCA Design** lists `TLcaThemedMainMenu`, `TLcaThemedTitleBar`, etc.
5. Open **`lazycodingagent.lpi`**, then **`mainunit.pas`**. Prefer **Retry** if prompted; avoid **Cancel loading this component** (that can strip `.lfm` nodes). Restore **`mainunit.lfm`** from git if you already cancelled and saved.

Do **not** add `LcaDesignSystemDesign` to the application `.lpi` `RequiredPackages`; design-time packages belong in the IDE only.

## Install (Windows)

From the repo root:

```bat
scripts\install-lca-lazarus.bat
```

Do **not** run `.\scripts\install-lca-lazarus.ps1` directly if PowerShell reports scripts are disabled; use **`.bat`** above. Equivalent: `powershell -ExecutionPolicy Bypass -File scripts\install-lca-lazarus.ps1` from the repo root.

## Install (Linux / macOS)

```bash
chmod +x scripts/install-lca-lazarus.sh
./scripts/install-lca-lazarus.sh
```

### Options

- **`--link-only`** — Register and compile runtime packages for `lazbuild` only (no IDE palette install).
- **`--skip-terminal`** — Skip `TerminalFramework` / `ViewLCL` (terminal component will not build).
- **`--widgetset=NAME`** / **`--qt5`** — Use the same LCL widgetset for every `lazbuild` call, including **`--build-ide`** (Linux default without this is **gtk2**). Example: `./scripts/install-lca-lazarus.sh --widgetset=qt5`. Or set **`LCL_WIDGETSET=qt5`**.

Requires:

- Lazarus + `lazbuild` on `PATH` (or `LAZBUILD` / `$env:LAZBUILD`)
- Vendored `third_party/TerminalEmulator` (unless `--skip-terminal`)
- IDE packages: **SynEdit** (app project)

The install script links the **runtime** package for `lazbuild`, installs **`LcaDesignSystemDesign`** into the IDE, and runs **`lazbuild --build-ide`** (close Lazarus first). Only the lightweight design package is linked into `lazarus.exe`; terminal support stays in the runtime package used by projects.

After it finishes, start Lazarus, open the **Component** palette, and select the **LCA Design** page.

### IDE crash when opening `lazycodingagent.lpi`

If the whole IDE closes when you open the project (often while loading `mainunit` in the designer), the crash is usually **`TryLoadOwlIconInto`** from **`TLcaThemedTitleBar.Loaded`**. JIT form loading runs **`Loaded` before `csDesigning` is set**, so guards that only check **`ComponentState`** are not enough; current sources also skip owl loading when **`ParamStr(0)`** is the **`lazarus`** IDE binary.

Close Lazarus, rebuild **both** packages for your widgetset (e.g. **qt5**), then **`lazbuild --widgetset=qt5 --build-ide`** (or **`./scripts/install-lca-lazarus.sh --widgetset=qt5`**). **`--link-only` does not refresh the IDE binary** — you need **`--build-ide`** after LCA code changes. On Wayland, start the IDE with **`./scripts/run-lazarus-linux.sh`** (`QT_QPA_PLATFORM=xcb`) if Qt logs a fatal Wayland protocol error.

### IDE hangs on startup

If Lazarus windows appear but the UI never finishes loading (e.g. undrawn toolbar buttons):

```bat
scripts\recover-lazarus-ide.bat
```

(Linux/macOS: `./scripts/recover-lazarus-ide.sh`.) That removes LCA entries from `staticpackages.inc` and rebuilds the IDE. Then run **`install-lca-lazarus`** again with Lazarus closed.

If it still hangs with **Coding Agent Chat** restored on the desktop, set that IDE window not visible in `environmentoptions.xml` (from the **lazaruscodingagent** plugin), rebuild the IDE once, then retry.

## UI paint profiling (Windows / Linux)

Optional counters for scroll, markdown, and themed control paint cost. Add custom define **`LCA_UI_PAINT_PROFILE`** to the app or **`LcaDesignSystem`** package (Lazarus: **Compiler Options → Custom options → `-dLCA_UI_PAINT_PROFILE`**), rebuild, run the app, and read **View → Debug Output** (once per second while the app runs). On Linux Qt5: **`scripts/build-with-ui-paint-profile.sh`** (`LCL_WIDGETSET=qt5` by default).

Compare idle, chat scroll, and live resize. To force double-buffered scroll hosts on Windows (default is off for large surfaces), add **`-dLCA_SCROLL_HOST_FORCE_DOUBLEBUFFER`**.

## Package

- **`LcaDesignSystem.lpk`** — **RunTimeOnly** (app + `lazbuild`; all component units under `src/`). **`OtherUnitFiles=src`** is required at compile time (removing it breaks with `Can't find unit LcaTheme`).
- **`LcaDesignSystemDesign.lpk`** — **DesignTime** ([`design/LcaDesignReg.pas`](design/LcaDesignReg.pas) only; **LCA Design** palette). Uses **`OtherUnitFiles=design`** (not `src`) so the IDE does not duplicate the runtime `src` search path. **`UsageOptions` / `UnitPath`** must stay **`$(PkgOutDir)` only** — component types come from the linked runtime package.

### Windows form designer (main form)

1. Close Lazarus completely.
2. Run **`scripts/install-lca-lazarus.ps1`** (or `.bat`) **without** `-LinkOnly` so **`LcaDesignSystemDesign`** is installed and **`lazbuild --build-ide`** runs.
3. In the IDE, confirm **Package → Install/Uninstall packages**: **LcaDesignSystem**, **LcaDesignSystemDesign**, and **SynEditDsgn** (required by `lazycodingagent.lpi`).
4. Open `mainunit.pas` and press **F12**. If there is still no form tab, check **View → IDE Internals → Debug Output** for the first `mainunit.lfm` / `TLca` / `SynEdit` error.
5. Verify streaming locally: **`python scripts/verify-main-form-streaming.py`** (published field order must match `mainunit.lfm` DFS).

After changing either `.lpk`, close Lazarus and re-run **`scripts/install-lca-lazarus`**.
