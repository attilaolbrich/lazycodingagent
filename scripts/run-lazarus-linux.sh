#!/usr/bin/env bash
# Start the user Lazarus IDE on Linux; on Wayland, prefer X11 Qt platform for stability.
set -euo pipefail

LAZARUS="${LAZARUS:-$HOME/.lazarus/bin/lazarus}"

if [[ ! -x "$LAZARUS" ]]; then
  echo "Missing Lazarus: $LAZARUS" >&2
  exit 1
fi

if [[ "${XDG_SESSION_TYPE:-}" == wayland ]] && [[ -z "${QT_QPA_PLATFORM:-}" ]]; then
  export QT_QPA_PLATFORM=xcb
fi

exec "$LAZARUS" "$@"
