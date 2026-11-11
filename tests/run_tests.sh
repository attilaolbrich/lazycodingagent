#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TEST_OUTPUT="$(mktemp -d)"
cleanup() { rm -rf "$TEST_OUTPUT"; }
trap cleanup EXIT
LAZARUS_DIR="${LAZARUS_DIR:-}"
if [[ -z "$LAZARUS_DIR" && -d /usr/lib/lazarus ]]; then LAZARUS_DIR=/usr/lib/lazarus; fi
if [[ -z "$LAZARUS_DIR" ]]; then echo "Set LAZARUS_DIR"; exit 1; fi
ARCH="$(uname -m)"
FPC_LIB=""
for d in "/usr/lib/${ARCH}-linux-gnu/fpc"/*/units/"${ARCH}-linux" \
         "/usr/lib/fpc"/*/units/"${ARCH}-linux"; do
  if [[ -d "$d/fcl-xml" ]]; then FPC_LIB="$d"; break; fi
done
FPC_EXTRA=()
if [[ -n "$FPC_LIB" ]]; then
  FPC_EXTRA+=(-Fu"$FPC_LIB/fcl-xml" -Fu"$FPC_LIB/fcl-net" -Fu"$FPC_LIB/fcl-web" -Fu"$FPC_LIB/fcl-base" -Fu"$FPC_LIB/fcl-hash" -Fu"$FPC_LIB/paszlib")
fi
FPC_EXTRA+=(-Fu"$ROOT/third_party/fpc-openssl3/src")
fpc -Mobjfpc -Scghi -Fu"$ROOT" -Fu"$ROOT/packages/LcaDesignSystem/src" \
  -Fu"$LAZARUS_DIR/components/lazutils/lib/$ARCH-linux" "${FPC_EXTRA[@]}" \
  -FU"$TEST_OUTPUT" -FE"$TEST_OUTPUT" tests/tool_driver.lpr
fpc -Mobjfpc -Scghi -Fu"$ROOT" -Fu"$ROOT/packages/LcaDesignSystem/src" \
  "${FPC_EXTRA[@]}" -FU"$TEST_OUTPUT" -FE"$TEST_OUTPUT" tests/test_agent_rules.pas
fpc -Mobjfpc -Scghi -Fu"$ROOT" "${FPC_EXTRA[@]}" \
  -FU"$TEST_OUTPUT" -FE"$TEST_OUTPUT" tests/test_web_fetch.lpr
fpc -Mobjfpc -Scghi -Fu"$ROOT" "${FPC_EXTRA[@]}" \
  -FU"$TEST_OUTPUT" -FE"$TEST_OUTPUT" tests/test_browser_read.lpr
fpc -Mobjfpc -Scghi -Fu"$ROOT" "${FPC_EXTRA[@]}" \
  -FU"$TEST_OUTPUT" -FE"$TEST_OUTPUT" tests/test_cdp_connection.lpr
fpc -Mobjfpc -Scghi -Fu"$ROOT" "${FPC_EXTRA[@]}" \
  -FU"$TEST_OUTPUT" -FE"$TEST_OUTPUT" tests/test_web_search.lpr
fpc -Mobjfpc -Scghi -Fu"$ROOT" "${FPC_EXTRA[@]}" \
  -FU"$TEST_OUTPUT" -FE"$TEST_OUTPUT" tests/test_cdp_websocket.lpr
fpc -Mobjfpc -Scghi -Fu"$ROOT" "${FPC_EXTRA[@]}" \
  -FU"$TEST_OUTPUT" -FE"$TEST_OUTPUT" tests/test_llm_cache_usage.pas
fpc -Mobjfpc -Scghi -Fu"$ROOT" "${FPC_EXTRA[@]}" \
  -FU"$TEST_OUTPUT" -FE"$TEST_OUTPUT" tests/test_llm_provider_payload.pas
fpc -Mobjfpc -Scghi -Fu"$ROOT" -Fu"$ROOT/packages/LcaDesignSystem/src" \
  "${FPC_EXTRA[@]}" -FU"$TEST_OUTPUT" -FE"$TEST_OUTPUT" tests/test_llm_prompt_stability.pas
fpc -Mobjfpc -Scghi -Fu"$ROOT" -Fu"$ROOT/packages/LcaDesignSystem/src" \
  "${FPC_EXTRA[@]}" -FU"$TEST_OUTPUT" -FE"$TEST_OUTPUT" tests/test_llm_openai_tools.pas
fpc -Mobjfpc -Scghi -Fu"$ROOT" -Fu"$ROOT/packages/LcaDesignSystem/src" \
  "${FPC_EXTRA[@]}" -FU"$TEST_OUTPUT" -FE"$TEST_OUTPUT" tests/test_llm_tool_schemas.pas
if command -v lazbuild >/dev/null 2>&1; then
  "$ROOT/scripts/install-lazarus-sqlite.sh"
  lazbuild "$ROOT/tests/test_app_database.lpi"
  "$ROOT/tests/test_app_database"
fi
"$TEST_OUTPUT/test_agent_rules" "$TEST_OUTPUT/rules-fixture"
"$TEST_OUTPUT/test_web_fetch" "$ROOT/tests/fixtures/web_fetch/sample.html"
"$TEST_OUTPUT/test_browser_read"
"$TEST_OUTPUT/test_cdp_connection"
"$TEST_OUTPUT/test_web_search"
"$TEST_OUTPUT/test_cdp_websocket"
"$TEST_OUTPUT/test_llm_cache_usage"
"$TEST_OUTPUT/test_llm_provider_payload"
"$TEST_OUTPUT/test_llm_prompt_stability"
"$TEST_OUTPUT/test_llm_openai_tools"
"$TEST_OUTPUT/test_llm_tool_schemas"
python3 tests/test_local_tools.py "$TEST_OUTPUT/tool_driver"
echo "All LazyCodingAgent tool tests passed."
