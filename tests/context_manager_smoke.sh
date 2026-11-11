#!/usr/bin/env bash
# Smoke tests for uChatContextManager helpers via tool_driver.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRIVER="${ROOT}/tests/tool_driver"
if [[ ! -x "$DRIVER" ]]; then
  echo "Skip: build tests/tool_driver (fpc/lazbuild) to run smoke tests."
  exit 0
fi

run_tool() {
  printf '%s\n' "$1" | "$DRIVER" "$ROOT"
}

OUT="$(run_tool '{"tool":"_context_is_limit_error","args":{"text":"Error: context_length_exceeded"}}')"
echo "$OUT" | grep -q '"match":true' || { echo "context limit detect: got $OUT"; exit 1; }

OUT="$(run_tool '{"tool":"_context_is_limit_error","args":{"text":"HTTP 500"}}')"
echo "$OUT" | grep -q '"match":false' || { echo "context limit negative: got $OUT"; exit 1; }

OUT="$(run_tool '{"tool":"_context_finish_truncated","args":{"reason":"length"}}')"
echo "$OUT" | grep -q '"truncated":true' || { echo "finish length: got $OUT"; exit 1; }

OUT="$(run_tool '{"tool":"_context_finish_truncated","args":{"reason":"stop"}}')"
echo "$OUT" | grep -q '"truncated":false' || { echo "finish stop: got $OUT"; exit 1; }

echo "context_manager_smoke: OK"
