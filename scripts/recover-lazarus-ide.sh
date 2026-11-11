#!/usr/bin/env bash
# Remove LCA packages from the IDE link list and rebuild lazarus.exe (emergency recovery).
set -euo pipefail

SKIP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --skip-build-ide) SKIP_BUILD=1 ;;
  esac
done

CONFIG_DIR="${LAZARUSCONFIG:-${HOME}/.lazarus}"
STATIC_INC="$CONFIG_DIR/staticpackages.inc"

if [[ ! -f "$STATIC_INC" ]]; then
  echo "staticpackages.inc not found: $STATIC_INC" >&2
  exit 1
fi

echo "Close Lazarus completely before continuing."
tmp="$(mktemp)"
awk '{
  line = $0
  gsub(/^[ \t]+|[ \t]+$/, "", line)
  sub(/,$/, "", line)
  if (line != "LcaDesignSystem" && line != "LcaDesignSystemDesign")
    print $0
}' "$STATIC_INC" > "$tmp"
mv "$tmp" "$STATIC_INC"
echo "Updated: $STATIC_INC"

if [[ "$SKIP_BUILD" -eq 1 ]]; then
  echo "Skipped --build-ide. Run lazbuild --build-ide after closing Lazarus."
  exit 0
fi

LAZBUILD="${LAZBUILD:-lazbuild}"
if ! command -v "$LAZBUILD" >/dev/null 2>&1; then
  echo "lazbuild not found. Set LAZBUILD." >&2
  exit 1
fi

echo "Rebuilding Lazarus IDE..."
"$LAZBUILD" --build-ide
echo ""
echo "Recovery complete. Start Lazarus."
echo "If startup still hangs, hide CodingAgentChatForm in environmentoptions.xml, then rebuild IDE."
echo "Reinstall palette later: ./scripts/install-lca-lazarus.sh"
