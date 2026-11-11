#!/usr/bin/env bash
# Download CI Lazarus/FPC artifacts into tools/lazarus-artifacts/.
# Portable Bash (3.2+ on macOS CI); avoid Bash 4-only builtins such as mapfile.
# Usage: prefetch-lazarus-ci-artifacts.sh [target-id ...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="${LAZARUS_ARTIFACTS_DIR:-$ROOT_DIR/tools/lazarus-artifacts}"
MANIFEST="$SCRIPT_DIR/lazarus-ci-artifacts.json"

mkdir -p "$OUT_DIR"

TARGETS=("$@")
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=()
  while IFS= read -r line; do
    TARGETS+=("$line")
  done < <(python3 - "$MANIFEST" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
for k in sorted((data.get("targets") or {}).keys()):
    print(k)
PY
)
fi

for tid in "${TARGETS[@]}"; do
  FILES=()
  while IFS= read -r line; do
    FILES+=("$line")
  done < <(python3 - "$MANIFEST" "$tid" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
t = (data.get("targets") or {}).get(sys.argv[2])
if not t:
    sys.exit(f"unknown target: {sys.argv[2]}")
for ent in t.get("files") or []:
    print(ent["name"])
PY
)
  for name in "${FILES[@]}"; do
    dest="$OUT_DIR/$name"
    "$SCRIPT_DIR/ci-resolve-lazarus-artifact.sh" "$tid" "$name" "$dest"
  done
done

echo "prefetch-lazarus-ci-artifacts: done -> $OUT_DIR"
