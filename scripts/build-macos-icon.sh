#!/usr/bin/env bash
# Build installer/macos/lazycodingagent.icns from assets/owl_icon_256.png (macOS iconutil or Python fallback).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_PNG="$ROOT/assets/owl_icon_256.png"
OUT_ICNS="$ROOT/installer/macos/lazycodingagent.icns"

if [[ ! -f "$SRC_PNG" ]]; then
  echo "build-macos-icon: missing $SRC_PNG" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT_ICNS")"

if [[ -f "$OUT_ICNS" && "${FORCE_MACOS_ICON_REBUILD:-0}" != "1" ]]; then
  echo "build-macos-icon: using existing $OUT_ICNS"
  exit 0
fi

if [[ "$(uname -s)" == "Darwin" ]] && command -v iconutil >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then
  WORK="$ROOT/build/macos-iconset"
  rm -rf "$WORK"
  mkdir -p "$WORK/lazycodingagent.iconset"
  ICONSET="$WORK/lazycodingagent.iconset"
  for spec in "16:icon_16x16.png" "32:icon_16x16@2x.png" "32:icon_32x32.png" "64:icon_32x32@2x.png" \
    "128:icon_128x128.png" "256:icon_128x128@2x.png" "256:icon_256x256.png" "512:icon_256x256@2x.png" \
    "512:icon_512x512.png" "1024:icon_512x512@2x.png"; do
    size="${spec%%:*}"
    name="${spec#*:}"
    sips -z "$size" "$size" "$SRC_PNG" --out "$ICONSET/$name" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$OUT_ICNS"
  rm -rf "$WORK"
  echo "build-macos-icon: $OUT_ICNS (iconutil)"
  exit 0
fi

python3 - "$SRC_PNG" "$OUT_ICNS" <<'PY'
import struct
import sys
from io import BytesIO
from pathlib import Path

from PIL import Image

src, out = Path(sys.argv[1]), Path(sys.argv[2])
img = Image.open(src).convert("RGBA")
type_map = {16: b"icp4", 32: b"icp5", 128: b"ic07", 256: b"ic08", 512: b"ic09"}
body = b""
for size, typ in type_map.items():
    buf = BytesIO()
    img.resize((size, size), Image.Resampling.LANCZOS).save(buf, format="PNG")
    data = buf.getvalue()
    chunk = typ + struct.pack(">I", len(data) + 8) + data
    body += chunk + b"\x00" * ((4 - len(chunk) % 4) % 4)
icns = b"icns" + struct.pack(">I", len(body) + 8) + body
out.write_bytes(icns)
print(f"build-macos-icon: {out} ({len(icns)} bytes, Python)")
PY
