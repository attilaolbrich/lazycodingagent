#!/usr/bin/env bash
# Resolve a CI Lazarus/FPC blob: optional repo cache -> workdir -> SourceForge.
# Portable Bash (3.2+ on macOS CI); avoid Bash 4-only builtins such as mapfile.
# Usage: ci-resolve-lazarus-artifact.sh <target-id> <filename> <dest-path>
set -euo pipefail

TARGET_ID="${1:?target-id required}"
FILE_NAME="${2:?filename required}"
DEST_PATH="${3:?dest-path required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$SCRIPT_DIR/lazarus-ci-artifacts.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ci-resolve-lazarus-artifact: missing manifest $MANIFEST" >&2
  exit 1
fi

read_manifest() {
  python3 - "$TARGET_ID" "$FILE_NAME" <<'PY'
import json, os, sys
target_id, file_name = sys.argv[1], sys.argv[2]
with open(os.environ["MANIFEST"], encoding="utf-8") as f:
    data = json.load(f)
targets = data.get("targets") or {}
t = targets.get(target_id)
if not t:
    sys.exit(f"unknown target: {target_id}")
sf_base = t.get("sfBase") or ""
for ent in t.get("files") or []:
    if ent.get("name") == file_name:
        print(sf_base)
        print(ent.get("minBytes") or 0)
        print(1 if ent.get("validatePeMz") else 0)
        sys.exit(0)
sys.exit(f"file {file_name!r} not in target {target_id}")
PY
}

export MANIFEST
{
  IFS= read -r SF_BASE
  IFS= read -r MIN_BYTES
  IFS= read -r VALIDATE_MZ
} < <(read_manifest)
SF_BASE="${LAZARUS_SF_MIRROR:-$SF_BASE}"
MIN_BYTES="${MIN_BYTES:-0}"
VALIDATE_MZ="${VALIDATE_MZ:-0}"

WORKDIR="${CI_LAZARUS_WORKDIR:-${RUNNER_TEMP:-/tmp}/lazarus-ci-unknown}"
case "$TARGET_ID" in
  windows-win64) WORKDIR="${CI_LAZARUS_WORKDIR:-${RUNNER_TEMP:-/tmp}/lazarus-ci-win64}" ;;
  macos-aarch64) WORKDIR="${CI_LAZARUS_WORKDIR:-${RUNNER_TEMP:-/tmp}/lazarus-ci-aarch64}" ;;
  macos-x86_64) WORKDIR="${CI_LAZARUS_WORKDIR:-${RUNNER_TEMP:-/tmp}/lazarus-ci-x86_64}" ;;
esac

ARTIFACTS_DIR="${LAZARUS_ARTIFACTS_DIR:-$ROOT_DIR/tools/lazarus-artifacts}"
mkdir -p "$(dirname "$DEST_PATH")"

artifact_valid() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  if [[ "$MIN_BYTES" -gt 0 ]]; then
    local size
    size="$(wc -c <"$path" | tr -d ' ')"
    if [[ "$size" -lt "$MIN_BYTES" ]]; then
      return 1
    fi
  fi
  if [[ "$VALIDATE_MZ" == 1 ]]; then
    local b1 b2
    b1="$(od -An -tu1 -N1 -j0 "$path" 2>/dev/null | tr -d ' ')"
    b2="$(od -An -tu1 -N1 -j1 "$path" 2>/dev/null | tr -d ' ')"
    [[ "$b1" == 77 && "$b2" == 90 ]] || return 1
  fi
  return 0
}

try_copy() {
  local src="$1"
  if artifact_valid "$src"; then
    if [[ "$(cd "$(dirname "$src")" && pwd)/$(basename "$src")" != "$(cd "$(dirname "$DEST_PATH")" && pwd)/$(basename "$DEST_PATH")" ]]; then
      cp -f "$src" "$DEST_PATH"
    fi
    echo "ci-resolve-lazarus-artifact: using $src"
    return 0
  fi
  return 1
}

if [[ -f "$DEST_PATH" ]] && artifact_valid "$DEST_PATH"; then
  echo "ci-resolve-lazarus-artifact: dest already valid: $DEST_PATH"
  exit 0
fi

for candidate in \
  "$ARTIFACTS_DIR/$FILE_NAME" \
  "$WORKDIR/$FILE_NAME"; do
  if try_copy "$candidate"; then
    exit 0
  fi
done

url="${SF_BASE%/}/$FILE_NAME"
echo "ci-resolve-lazarus-artifact: downloading $url"
curl -fL --retry 3 --retry-delay 5 -o "$DEST_PATH" "$url"

if ! artifact_valid "$DEST_PATH"; then
  echo "ci-resolve-lazarus-artifact: downloaded file failed validation: $DEST_PATH" >&2
  rm -f "$DEST_PATH"
  exit 1
fi

echo "ci-resolve-lazarus-artifact: download OK ($(wc -c <"$DEST_PATH" | tr -d ' ') bytes)"
