#!/usr/bin/env bash
# Run LazyCodingAgent on Linux; on Wayland, prefer XWayland (Qt5 xcb or GDK x11).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXE="$ROOT/lazycodingagent"

if [[ ! -x "$EXE" ]]; then
  echo "Missing executable: $EXE (run lazbuild lazycodingagent.lpi first)" >&2
  exit 1
fi

if [[ "${XDG_SESSION_TYPE:-}" == wayland ]]; then
  if ldd "$EXE" 2>/dev/null | grep -q 'libQt5Core'; then
    if [[ -z "${QT_QPA_PLATFORM:-}" ]]; then
      export QT_QPA_PLATFORM=xcb
    fi
  elif [[ -z "${GDK_BACKEND:-}" ]]; then
    export GDK_BACKEND=x11
  fi
fi

exec "$EXE" "$@"
