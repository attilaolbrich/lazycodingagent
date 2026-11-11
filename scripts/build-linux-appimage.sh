#!/usr/bin/env bash
# Bundle lazycodingagent as an AppImage with linuxdeploy + Qt plugin (Ubuntu 22.04 baseline).
set -euo pipefail

VERSION="${APP_VERSION:-${1:-}}"
if [[ -z "$VERSION" ]]; then
  echo "build-linux-appimage: set APP_VERSION or pass version as first argument" >&2
  exit 1
fi

if [[ "$VERSION" =~ [^0-9a-zA-Z.+~-] ]]; then
  echo "build-linux-appimage: invalid version string: $VERSION" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -z "${SOURCE_DIR:-}" ]]; then
  SOURCE_DIR="$("$SCRIPT_DIR/resolve-lazycodingagent-output.sh" "$ROOT" "" build-linux-appimage)"
fi
DESKTOP_SRC="$ROOT/installer/linux/lazycodingagent.desktop"
# linuxdeploy requires square icons at standard sizes (e.g. 256x256); owl_icon.png is not.
ICON_APPIMAGE="$ROOT/assets/owl_icon_256.png"
DIST="$ROOT/dist"
WORKDIR="$ROOT/build/appimage"
APPDIR="$WORKDIR/AppDir"

LINUXDEPLOY_VERSION="${LINUXDEPLOY_VERSION:-continuous}"
LINUXDEPLOY_QT_VERSION="${LINUXDEPLOY_QT_VERSION:-continuous}"
LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/${LINUXDEPLOY_VERSION}/linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_QT_URL="https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/${LINUXDEPLOY_QT_VERSION}/linuxdeploy-plugin-qt-x86_64.AppImage"

BIN="$SOURCE_DIR/lazycodingagent"
if [[ ! -f "$BIN" ]]; then
  echo "build-linux-appimage: missing binary $BIN" >&2
  exit 1
fi
if [[ ! -f "$ICON_APPIMAGE" ]]; then
  echo "build-linux-appimage: missing $ICON_APPIMAGE (256x256 icon for linuxdeploy)" >&2
  exit 1
fi

rm -rf "$WORKDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"

install -m 755 "$BIN" "$APPDIR/usr/bin/lazycodingagent"
if [[ -d "$SOURCE_DIR/help" ]]; then
  cp -a "$SOURCE_DIR/help" "$APPDIR/usr/bin/"
fi
if [[ -d "$SOURCE_DIR/assets" ]]; then
  cp -a "$SOURCE_DIR/assets" "$APPDIR/usr/bin/"
fi

install -m 644 "$DESKTOP_SRC" "$APPDIR/usr/share/applications/lazycodingagent.desktop"
install -m 644 "$ICON_APPIMAGE" "$APPDIR/usr/share/icons/hicolor/256x256/apps/lazycodingagent.png"
install -m 644 "$ICON_APPIMAGE" "$APPDIR/lazycodingagent.png"

LINUXDEPLOY="$WORKDIR/linuxdeploy.AppImage"
LINUXDEPLOY_QT="$WORKDIR/linuxdeploy-plugin-qt.AppImage"
curl -fsSL -o "$LINUXDEPLOY" "$LINUXDEPLOY_URL"
curl -fsSL -o "$LINUXDEPLOY_QT" "$LINUXDEPLOY_QT_URL"
chmod +x "$LINUXDEPLOY" "$LINUXDEPLOY_QT"

export PATH="$WORKDIR:$PATH"
export QMAKE="$(command -v qmake)"
if [[ -z "$QMAKE" ]]; then
  echo "build-linux-appimage: qmake not found (install qtbase5-dev)" >&2
  exit 1
fi

# Bundle Qt5 and dependencies; xcb platform matches app RunParams / Wayland workaround.
export LINUXDEPLOY_PLUGIN_QT="$LINUXDEPLOY_QT"
"$LINUXDEPLOY" \
  --appdir="$APPDIR" \
  --executable="$APPDIR/usr/bin/lazycodingagent" \
  --desktop-file="$APPDIR/usr/share/applications/lazycodingagent.desktop" \
  --icon-file="$APPDIR/lazycodingagent.png" \
  --plugin qt

mkdir -p "$DIST"
OUT_IMAGE="$DIST/LazyCodingAgent-${VERSION}-x86_64.AppImage"
OUTPUT="$OUT_IMAGE" "$LINUXDEPLOY" --appdir="$APPDIR" --output appimage
chmod +x "$OUT_IMAGE"

echo "build-linux-appimage: $OUT_IMAGE"
