#!/usr/bin/env bash
# Copy help/ and assets/ next to the built executable (post lazbuild).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJ_DIR="${1:-$ROOT}"
TARGET_DIR="${2:-}"

if [[ -z "$TARGET_DIR" ]]; then
  if ! command -v fpc >/dev/null 2>&1; then
    echo "post-build: set TARGET_DIR or install fpc to auto-detect lib/\$(cpu)-\$(os) via fpc -iTP / -iTO" >&2
    exit 1
  fi
  TARGET_DIR="${PROJ_DIR}/lib/$(fpc -iTP)-$(fpc -iTO)"
fi

for DEST in "$TARGET_DIR" "$PROJ_DIR"; do
  "$SCRIPT_DIR/copy-help.sh" "$PROJ_DIR" "$DEST"
  "$SCRIPT_DIR/copy-assets.sh" "$PROJ_DIR" "$DEST"
  echo "post-build: deployed help/ and assets/ to ${DEST}"
done
