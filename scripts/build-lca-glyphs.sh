#!/usr/bin/env bash
# Build packages/LcaDesignSystem/res/lca_design_glyphs.res from res/glyphs/*.png
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GLYPH_DIR="$ROOT/packages/LcaDesignSystem/res/glyphs"
OUT_RES="$ROOT/packages/LcaDesignSystem/res/lca_design_glyphs.res"

LAZRES="${LAZRES:-}"
if [[ -z "$LAZRES" ]]; then
  for candidate in \
    /usr/lib/lazarus/tools/lazres \
    /usr/share/lazarus/tools/lazres \
    "$HOME/lazarus/tools/lazres" \
    /opt/lazarus/tools/lazres; do
    if [[ -x "$candidate" ]]; then
      LAZRES="$candidate"
      break
    fi
  done
  if [[ -z "$LAZRES" ]]; then
    for candidate in /usr/share/lazarus/*/tools/lazres; do
      if [[ -x "$candidate" ]]; then
        LAZRES="$candidate"
        break
      fi
    done
  fi
fi
if [[ -z "$LAZRES" ]] && command -v lazres >/dev/null 2>&1; then
  LAZRES="$(command -v lazres)"
fi
if [[ -z "$LAZRES" || ! -x "$LAZRES" ]]; then
  echo "lazres not found; set LAZRES to your Lazarus tools/lazres binary" >&2
  exit 1
fi

shopt -s nullglob
pngs=("$GLYPH_DIR"/*.png)
if [[ ${#pngs[@]} -eq 0 ]]; then
  echo "No PNG glyphs in $GLYPH_DIR" >&2
  exit 1
fi

rm -f "$OUT_RES"
"$LAZRES" "$OUT_RES" "${pngs[@]}"
echo "Wrote $OUT_RES (${#pngs[@]} glyph(s))"
