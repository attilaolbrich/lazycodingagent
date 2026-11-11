#!/usr/bin/env bash
# Install TerminalEmulator + LCA Design System packages for Lazarus IDE and lazbuild.
set -euo pipefail

LINK_ONLY=0
SKIP_TERMINAL=0
WIDGETSET="${LCL_WIDGETSET:-}"

usage() {
  cat <<'EOF'
Usage: install-lca-lazarus.sh [options]

  --link-only          Runtime packages for lazbuild only (no IDE palette / --build-ide)
  --skip-terminal      Skip TerminalFramework / ViewLCL
  --widgetset=NAME     Pass --widgetset=NAME to every lazbuild (e.g. qt5, gtk2)
  --widgetset NAME     Same as --widgetset=NAME
  --qt5                Shorthand for --widgetset=qt5

Environment:
  LCL_WIDGETSET        Default widgetset when --widgetset is not passed (e.g. qt5)

On Linux, lazbuild defaults to gtk2. Use --widgetset=qt5 (or LCL_WIDGETSET=qt5) when your
Lazarus IDE is built for Qt5 so --build-ide does not switch the IDE back to GTK2.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --link-only) LINK_ONLY=1; shift ;;
    --skip-terminal) SKIP_TERMINAL=1; shift ;;
    --widgetset=*) WIDGETSET="${1#--widgetset=}"; shift ;;
    --widgetset)
      WIDGETSET="${2:?--widgetset requires a name (e.g. qt5)}"
      shift 2
      ;;
    --qt5) WIDGETSET=qt5; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TE="$ROOT/third_party/TerminalEmulator"
LpkTF="$TE/TerminalFramework/TerminalFramework.lpk"
LpkView="$TE/ViewLCL/ViewLCL.lpk"
LpkRuntime="$ROOT/packages/LcaDesignSystem/LcaDesignSystem.lpk"
LpkDesign="$ROOT/packages/LcaDesignSystem/LcaDesignSystemDesign.lpk"

LAZBUILD="${LAZBUILD:-lazbuild}"
if ! command -v "$LAZBUILD" >/dev/null 2>&1; then
  echo "lazbuild not found. Set LAZBUILD to your lazbuild path." >&2
  exit 1
fi

INSTALL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

lazbuild_cmd() {
  local widget_args=()
  if [[ -n "$WIDGETSET" ]]; then
    widget_args=(--widgetset="$WIDGETSET")
  fi
  if [[ -n "${LAZARUS_PRIMARY_CONFIG:-}" ]]; then
    if [[ -n "$WIDGETSET" ]]; then
      LCL_WIDGETSET="$WIDGETSET" "$INSTALL_SCRIPT_DIR/ci-lazbuild.sh" "$@"
    else
      "$INSTALL_SCRIPT_DIR/ci-lazbuild.sh" "$@"
    fi
  elif [[ ${#widget_args[@]} -gt 0 ]]; then
    "$LAZBUILD" "${widget_args[@]}" "$@"
  else
    "$LAZBUILD" "$@"
  fi
}

# apt-installed Lazarus under /usr/share/lazarus is root-owned; --build-ide may need a new
# units/<cpu>/<widgetset> directory (e.g. qt5) that the user cannot create.
system_lazarus_units_writable() {
  local units_dir
  for units_dir in /usr/share/lazarus/*/units; do
    [[ -d "$units_dir" ]] || continue
    if [[ ! -w "$units_dir" ]]; then
      return 1
    fi
  done
  return 0
}

warn_system_lazarus_build_ide() {
  cat <<'EOF' >&2

System Lazarus (/usr/share/lazarus) is not writable, so lazbuild --build-ide cannot create
widgetset unit directories (e.g. units/<cpu>-linux/qt5 for your `fpc -iTP`). That causes: mkdir: Permission denied

Options:
  1) CLI / app builds only (no palette reinstall):
       ./scripts/install-lca-lazarus.sh --link-only --widgetset=qt5
       lazbuild --widgetset=qt5 lazycodingagent.lpi

  2) One-time writable unit dir, then re-run this script (close Lazarus first):
       ./scripts/ensure-lazarus-qt5-units-dir.sh

  3) Use a user-writable Lazarus tree (e.g. fpcupdeluxe) and set LAZBUILD to its lazbuild.

EOF
}

if [[ -n "$WIDGETSET" ]]; then
  echo "Using LCL widgetset: $WIDGETSET"
fi

if [[ "$SKIP_TERMINAL" -eq 0 ]]; then
  if [[ ! -f "$LpkTF" ]]; then
    echo "Missing vendored terminal: third_party/TerminalEmulator (TerminalFramework.lpk not found)" >&2
    exit 1
  fi
  lazbuild_cmd --add-package-link "$LpkTF"
  lazbuild_cmd --add-package-link "$LpkView"
  lazbuild_cmd "$LpkTF"
  lazbuild_cmd "$LpkView"
fi

lazbuild_cmd --add-package-link "$LpkRuntime"
lazbuild_cmd "$LpkRuntime" --build-all

if [[ "$LINK_ONLY" -eq 0 ]]; then
  GLYPH_SCRIPT="$INSTALL_SCRIPT_DIR/build-lca-glyphs.sh"
  OUT_RES="$ROOT/packages/LcaDesignSystem/res/lca_design_glyphs.res"
  if [[ -x "$GLYPH_SCRIPT" ]]; then
    "$GLYPH_SCRIPT"
  elif [[ ! -f "$OUT_RES" ]]; then
    echo "Missing LCA palette glyphs: $OUT_RES (build-lca-glyphs.sh not runnable)" >&2
    exit 1
  else
    echo "Skipping glyph rebuild; using existing $OUT_RES" >&2
  fi
  lazbuild_cmd --add-package "$LpkDesign"
  lazbuild_cmd "$LpkDesign" --build-all
  if ! system_lazarus_units_writable; then
    warn_system_lazarus_build_ide
    echo "Attempting lazbuild --build-ide anyway (IDE output is usually under ~/.lazarus)..." >&2
  fi
  echo ""
  echo "Close Lazarus completely before rebuilding the IDE (required for the component palette)."
  echo "Rebuilding Lazarus IDE with LcaDesignSystemDesign (runtime stays out of lazarus.exe)..."
  lazbuild_cmd --build-ide
  echo ""
  echo "IDE rebuild complete. Start Lazarus and open the Component palette page: LCA Design."
  echo "If Lazarus hangs on startup, run: ./scripts/recover-lazarus-ide.sh"
else
  echo "Link-only: runtime packages linked for lazbuild (no IDE design install)."
fi

if [[ -n "$WIDGETSET" ]]; then
  echo "Done. Build the app with: lazbuild --widgetset=$WIDGETSET lazycodingagent.lpi"
else
  echo "Done. Open lazycodingagent.lpi in Lazarus or run: lazbuild lazycodingagent.lpi"
fi
