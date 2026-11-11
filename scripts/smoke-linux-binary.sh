#!/usr/bin/env bash
# Brief launch smoke test for lazycodingagent (Linux CI; requires xvfb-run).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTEXT="${1:-smoke-linux-binary}"

if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "smoke-linux-binary: xvfb-run not found (install xvfb package)" >&2
  exit 1
fi

OUT_DIR="$("$SCRIPT_DIR/resolve-lazycodingagent-output.sh" "$ROOT" "" "$CONTEXT")"
BIN="$OUT_DIR/lazycodingagent"
if [[ ! -f "$BIN" ]]; then
  echo "smoke-linux-binary: missing $BIN" >&2
  exit 1
fi

echo "smoke-linux-binary: launching $BIN under xvfb"
# GTK2 CI has no display; Qt5 release builds may still need a virtual framebuffer.
if [[ -n "${LCL_WIDGETSET:-}" ]]; then
  export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
fi

xvfb-run -a "$BIN" &
pid=$!
trap 'kill -TERM "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT

for _ in $(seq 1 15); do
  if ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid" || code=$?
    echo "smoke-linux-binary: process exited early with code ${code:-1}" >&2
    exit 1
  fi
  sleep 1
done

echo "Smoke test: app still running after 15s (OK)"
