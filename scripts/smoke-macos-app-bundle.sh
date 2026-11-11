#!/usr/bin/env bash
# Brief launch smoke test for a packaged .app (macOS CI; no GNU timeout).
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" ]]; then
  echo "smoke-macos-app-bundle: usage: smoke-macos-app-bundle.sh path/to/App.app" >&2
  exit 1
fi

if [[ ! -d "$APP/Contents/MacOS" ]]; then
  echo "smoke-macos-app-bundle: missing $APP/Contents/MacOS" >&2
  exit 1
fi

BIN="$APP/Contents/MacOS/lazycodingagent"
chmod +x "$BIN"

set +e
"$BIN" &
pid=$!
set -e
for _ in $(seq 1 15); do
  if ! kill -0 "$pid" 2>/dev/null; then
    set +e
    wait "$pid"
    code=$?
    set -e
    exit "$code"
  fi
  sleep 1
done
kill "$pid" 2>/dev/null || true
set +e
wait "$pid" 2>/dev/null
set -e
echo "Smoke test: app still running after 15s (OK)"
