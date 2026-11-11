#!/usr/bin/env bash
# Smoke tests for tool argument parsing and read_file offset validation.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRIVER="${ROOT}/tests/tool_driver"
if [[ ! -x "$DRIVER" ]]; then
  echo "Skip: build tests/tool_driver (fpc/lazbuild) to run smoke tests."
  exit 0
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
FILE="${WORKDIR}/lines.txt"
for i in $(seq 1 63); do echo "line $i" >> "$FILE"; done

run_tool() {
  printf '%s\n' "$1" | "$DRIVER" "$WORKDIR"
}

OUT="$(run_tool '{"tool":"read_file","args":{"path":"lines.txt","offset":64}}')"
echo "$OUT" | grep -q '"error"' || { echo "read_file offset 64: expected error JSON, got: $OUT"; exit 1; }
echo "$OUT" | grep -q 'total_lines: 63' || { echo "read_file offset 64: expected total_lines hint, got: $OUT"; exit 1; }

OUT="$(run_tool '{"tool":"write_file","args":"{\"path\":\"x\",\"content\":\"unclosed"}')"
echo "$OUT" | grep -q 'JSON argument parsing error' || { echo "truncated args: expected parse error, got: $OUT"; exit 1; }

WF="$(run_tool '{"tool":"_json_wellformed","args":"{\"a\":1}"}')"
echo "$WF" | grep -q '"wellformed":true' || { echo "wellformed good json: got: $WF"; exit 1; }

WF="$(run_tool '{"tool":"_json_wellformed","args":"{\"path\":\"x\",\"content\":\"unclosed"}')"
echo "$WF" | grep -q '"wellformed":false' || { echo "wellformed truncated json: got: $WF"; exit 1; }

OUT="$(run_tool '{"tool":"read_file","args":{"path":"lines.txt","offset":1,"limit":2}}')"
echo "$OUT" | grep -q '"lines_returned":2' || { echo "read_file ok: got: $OUT"; exit 1; }

echo "agent_tool_smoke: OK"
