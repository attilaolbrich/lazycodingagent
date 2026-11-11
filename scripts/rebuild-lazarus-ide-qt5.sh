#!/usr/bin/env bash
# Rebuild your custom Lazarus IDE for Qt5 (uses ~/.lazarus idemake.cfg + installed packages).
set -euo pipefail

LAZBUILD="${LAZBUILD:-lazbuild}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FPC_TRIPLE="$("$SCRIPT_DIR/linux-fpc-target-triple.sh")"
LAZARUS_UNITS_QT5=""
LAZARUS_SYS=""
for base in /usr/share/lazarus/* /usr/lib/lazarus/*; do
  [[ -d "$base" ]] || continue
  if [[ -f "$base/lazarus" || -x "$base/lazarus" ]]; then
    LAZARUS_SYS="$base/lazarus"
    LAZARUS_UNITS_QT5="$base/units/${FPC_TRIPLE}/qt5"
    break
  fi
done
if [[ -z "$LAZARUS_UNITS_QT5" ]]; then
  echo "Could not find system Lazarus under /usr/share/lazarus or /usr/lib/lazarus." >&2
  exit 1
fi
LAZARUS_USER="${HOME}/.lazarus/bin/lazarus"

if ! command -v "$LAZBUILD" >/dev/null 2>&1; then
  echo "lazbuild not found. Set LAZBUILD." >&2
  exit 1
fi

if pgrep -x lazarus >/dev/null 2>&1; then
  echo "Close Lazarus completely, then run this script again." >&2
  exit 1
fi

if [[ ! -d "$LAZARUS_UNITS_QT5" ]]; then
  echo "Creating $LAZARUS_UNITS_QT5 (requires sudo on apt Lazarus)..."
  sudo install -d -o "$(id -un)" -g "$(id -gn)" "$LAZARUS_UNITS_QT5"
elif [[ ! -w "$LAZARUS_UNITS_QT5" ]]; then
  echo "Fixing ownership on $LAZARUS_UNITS_QT5..."
  sudo chown -R "$(id -un):$(id -gn)" "$LAZARUS_UNITS_QT5"
fi

echo "Rebuilding your Lazarus IDE with Qt5 (this can take several minutes)..."
echo "Output should be $LAZARUS_USER per ~/.lazarus/idemake.cfg — do not copy $LAZARUS_SYS."
"$LAZBUILD" --widgetset=qt5 --build-ide

if [[ ! -f "$LAZARUS_USER" ]]; then
  echo "ERROR: $LAZARUS_USER was not created." >&2
  echo "Open Lazarus → Tools → Configure Build Lazarus → Normal IDE → LCL qt5 → Build Lazarus," >&2
  echo "or check -FE in ~/.lazarus/idemake.cfg." >&2
  exit 1
fi

if ! ldd "$LAZARUS_USER" 2>/dev/null | grep -qi 'libQt5Gui'; then
  echo "WARNING: $LAZARUS_USER does not appear to link Qt5." >&2
  echo "Use Tools → Configure Build Lazarus → Profile Normal IDE → LCL qt5 (not Debug/Optimized gtk2)." >&2
  exit 1
fi

if [[ -f "$LAZARUS_SYS" ]] && cmp -s "$LAZARUS_USER" "$LAZARUS_SYS"; then
  echo "WARNING: $LAZARUS_USER is identical to the stock $LAZARUS_SYS binary." >&2
  echo "That is the minimal system IDE, not your package-linked build." >&2
  echo "Rebuild from the IDE (Configure Build Lazarus) or fix idemake.cfg -FE/-FU paths." >&2
  exit 1
fi

echo ""
echo "OK: custom Qt5 IDE at $LAZARUS_USER ($(stat -c%s "$LAZARUS_USER") bytes)."
echo "Start from the menu or: $LAZARUS_USER"
echo ""
echo "Do not copy $LAZARUS_SYS over your user binary."
echo ""
echo "LCA Design packages for Qt5:"
echo "  ./scripts/install-lca-lazarus.sh --widgetset=qt5"
