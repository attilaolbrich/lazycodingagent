#!/usr/bin/env bash
# Copy assets/ (splash image, etc.) next to the built executable ($TargetDir).
set -euo pipefail
PROJ_DIR="${1:?project dir}"
TARGET_DIR="${2:?target dir}"
SRC="${PROJ_DIR}/assets"
DEST="${TARGET_DIR}/assets"
if [ ! -d "$SRC" ]; then
  echo "copy-assets: missing ${SRC}" >&2
  exit 0
fi
SRC_REAL="$(cd "$SRC" && pwd)"
DEST_REAL="$(mkdir -p "$DEST" && cd "$DEST" && pwd)"
if [ "$SRC_REAL" != "$DEST_REAL" ]; then
  rm -rf "$DEST"
  cp -r "$SRC" "$DEST"
fi
OWL_RES="${PROJ_DIR}/packages/LcaDesignSystem/res"
for f in owl_icon.bmp owl_icon.png; do
  if [ -f "${OWL_RES}/${f}" ]; then
    cp -f "${OWL_RES}/${f}" "${DEST}/${f}"
  fi
done
