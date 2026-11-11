#!/usr/bin/env bash
# Build LazyCodingAgent (Qt5) with LCA_UI_PAINT_PROFILE — see packages/LcaDesignSystem/README.md
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIDGETSET="${LCL_WIDGETSET:-qt5}"
lazbuild --widgetset="${WIDGETSET}" \
  "${ROOT}/packages/LcaDesignSystem/LcaDesignSystem.lpk" \
  --custom-options="-dLCA_UI_PAINT_PROFILE"
lazbuild --widgetset="${WIDGETSET}" \
  "${ROOT}/lazycodingagent.lpi" \
  --custom-options="-dLCA_UI_PAINT_PROFILE"
