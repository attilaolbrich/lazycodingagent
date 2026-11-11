#!/usr/bin/env bash
# Compile lazycodingagent for macOS release (Cocoa app bundle + help/assets beside binary).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

chmod +x "$SCRIPT_DIR"/*.sh

if [[ -z "${LAZBUILD:-}" ]]; then
  # Subprocess exports do not persist; source so LAZBUILD/LAZARUS_DIR apply here.
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/ci-install-lazarus-macos.sh"
fi

export LCL_WIDGETSET=cocoa

"$SCRIPT_DIR/ci-prepare-lazarus-deps.sh"
"$SCRIPT_DIR/install-lca-lazarus.sh" --link-only --widgetset=cocoa
"$SCRIPT_DIR/install-lazarus-sqlite.sh"

cd "$ROOT"
LCL_WIDGETSET=cocoa "$SCRIPT_DIR/ci-lazbuild.sh" lazycodingagent.lpi

LIB_DIR="$ROOT/lib/$(fpc -iTP)-$(fpc -iTO)"
MACOS_DIR="$("$SCRIPT_DIR/resolve-lazycodingagent-output.sh" "$ROOT" "" ci-macos-release-build macos-bundle-macos)"
"$SCRIPT_DIR/post-build.sh" "$ROOT" "$MACOS_DIR"

BIN="$MACOS_DIR/lazycodingagent"
if [[ ! -f "$BIN" && ! -L "$BIN" ]]; then
  echo "ci-macos-release-build: missing $BIN" >&2
  exit 1
fi

if otool -L "$BIN" 2>/dev/null | grep -qE 'libssl|libcrypto'; then
  echo "ci-macos-release-build: OpenSSL dylibs linked (bundle step may copy into Frameworks)"
fi

echo "ci-macos-release-build: OK ($BIN)"
