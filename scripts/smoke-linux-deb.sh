#!/usr/bin/env bash
# Brief launch smoke test for a packaged .deb (Linux release CI; requires xvfb-run).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEB="${1:-}"

if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "smoke-linux-deb: xvfb-run not found (install xvfb package)" >&2
  exit 1
fi
if ! command -v dpkg-deb >/dev/null 2>&1; then
  echo "smoke-linux-deb: dpkg-deb not found" >&2
  exit 1
fi

if [[ -z "$DEB" ]]; then
  shopt -s nullglob
  candidates=("$ROOT/dist"/*.deb)
  shopt -u nullglob
  if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "smoke-linux-deb: no .deb under dist/ (pass path as first argument)" >&2
    exit 1
  fi
  if [[ ${#candidates[@]} -gt 1 ]]; then
    echo "smoke-linux-deb: multiple .deb files; pass the one to test:" >&2
    printf '  %s\n' "${candidates[@]}" >&2
    exit 1
  fi
  DEB="${candidates[0]}"
fi

if [[ ! -f "$DEB" ]]; then
  echo "smoke-linux-deb: missing $DEB" >&2
  exit 1
fi

EXTRACT="$(mktemp -d)"
trap 'rm -rf "$EXTRACT"' EXIT

dpkg-deb -x "$DEB" "$EXTRACT"
BIN="$EXTRACT/usr/lib/lazycodingagent/lazycodingagent"
if [[ ! -f "$BIN" ]]; then
  echo "smoke-linux-deb: missing $BIN in package" >&2
  exit 1
fi
chmod +x "$BIN"

echo "smoke-linux-deb: launching packaged binary from $DEB under xvfb"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"

(
  cd "$EXTRACT/usr/lib/lazycodingagent"
  xvfb-run -a "./lazycodingagent"
) &
pid=$!
trap 'kill -TERM "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; rm -rf "$EXTRACT"' EXIT

for _ in $(seq 1 15); do
  if ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid" || code=$?
    echo "smoke-linux-deb: process exited early with code ${code:-1}" >&2
    exit 1
  fi
  sleep 1
done

echo "Smoke test: packaged .deb app still running after 15s (OK)"
