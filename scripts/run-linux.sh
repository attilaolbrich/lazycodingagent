#!/usr/bin/env bash
# Run LazyCodingAgent on Linux; Qt5 uses xcb (XWayland on Wayland), Gtk2 uses x11 on Wayland.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXE="$ROOT/lazycodingagent"

if [[ ! -x "$EXE" ]]; then
  echo "Missing executable: $EXE (run lazbuild lazycodingagent.lpi first)" >&2
  exit 1
fi

if ldd "$EXE" 2>/dev/null | grep -q 'libQt5Core'; then
  export QT_QPA_PLATFORM=xcb
elif [[ "${XDG_SESSION_TYPE:-}" == wayland ]] && [[ -z "${GDK_BACKEND:-}" ]]; then
  export GDK_BACKEND=x11
fi

exec "$EXE" "$@"