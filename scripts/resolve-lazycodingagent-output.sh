#!/usr/bin/env bash
# Print directory containing lazycodingagent after lazbuild (Linux/macOS CI and packaging).
set -euo pipefail

EXE_NAME=lazycodingagent
PROJECT_ROOT="$(cd "${1:-.}" && pwd)"
EXPLICIT="${2:-}"
CONTEXT="${3:-resolve-lazycodingagent-output}"
# When set to "macos-bundle-macos", print Contents/MacOS inside the .app bundle.
OUTPUT_KIND="${4:-}"

has_exe() {
  [[ -f "$1/$EXE_NAME" ]]
}

find_app_bundle() {
  local dir="$1"
  local candidate
  for candidate in \
    "$dir/$EXE_NAME.app" \
    "$dir/Lazy Coding Agent.app"; do
    if [[ -d "$candidate/Contents/MacOS" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  local app
  for app in "$dir"/*.app; do
    [[ -d "$app" ]] || continue
    if [[ -d "$app/Contents/MacOS" ]]; then
      echo "$app"
      return 0
    fi
  done
  return 1
}

if [[ -n "$EXPLICIT" ]]; then
  EXPLICIT="$(cd "$EXPLICIT" && pwd)"
  if has_exe "$EXPLICIT"; then
    echo "$EXPLICIT"
    exit 0
  fi
  if [[ "$OUTPUT_KIND" == "macos-bundle-macos" ]]; then
    bundle="$(find_app_bundle "$EXPLICIT" || true)"
    if [[ -n "$bundle" && ( -f "$bundle/Contents/MacOS/$EXE_NAME" || -L "$bundle/Contents/MacOS/$EXE_NAME" ) ]]; then
      echo "$(cd "$bundle/Contents/MacOS" && pwd)"
      exit 0
    fi
  fi
  echo "$CONTEXT: missing $EXPLICIT/$EXE_NAME" >&2
  exit 1
fi

candidates=()
if command -v fpc >/dev/null 2>&1; then
  candidates+=("$PROJECT_ROOT/lib/$(fpc -iTP)-$(fpc -iTO)")
fi
candidates+=(
  "$PROJECT_ROOT/lib/aarch64-darwin"
  "$PROJECT_ROOT/lib/aarch64-linux"
  "$PROJECT_ROOT/lib/x86_64-darwin"
  "$PROJECT_ROOT/lib/x86_64-linux"
  "$PROJECT_ROOT"
)

for dir in "${candidates[@]}"; do
  [[ -d "$dir" ]] || continue
  if [[ "$OUTPUT_KIND" == "macos-bundle-macos" ]]; then
    bundle="$(find_app_bundle "$dir" || true)"
    if [[ -n "$bundle" && ( -f "$bundle/Contents/MacOS/$EXE_NAME" || -L "$bundle/Contents/MacOS/$EXE_NAME" ) ]]; then
      echo "$(cd "$bundle/Contents/MacOS" && pwd)"
      exit 0
    fi
    if has_exe "$dir"; then
      echo "$(cd "$dir" && pwd)"
      exit 0
    fi
    continue
  fi
  if has_exe "$dir"; then
    echo "$(cd "$dir" && pwd)"
    exit 0
  fi
  bundle="$(find_app_bundle "$dir" || true)"
  if [[ -n "$bundle" ]]; then
    if [[ -L "$bundle/Contents/MacOS/$EXE_NAME" || -f "$bundle/Contents/MacOS/$EXE_NAME" ]]; then
      echo "$(cd "$dir" && pwd)"
      exit 0
    fi
  fi
done

echo "$CONTEXT: $EXE_NAME not found under $PROJECT_ROOT (run lazbuild first)" >&2
exit 1
