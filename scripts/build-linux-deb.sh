#!/usr/bin/env bash
# Build a .deb from the Qt5 release tree (run after ci-linux-qt5-release-build.sh).
set -euo pipefail

VERSION="${APP_VERSION:-${1:-}}"
if [[ -z "$VERSION" ]]; then
  echo "build-linux-deb: set APP_VERSION or pass version as first argument" >&2
  exit 1
fi

if [[ "$VERSION" =~ [^0-9a-zA-Z.+~-] ]]; then
  echo "build-linux-deb: invalid version string: $VERSION" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEB_ARCH="${DEB_ARCH:-$("$SCRIPT_DIR/linux-deb-architecture.sh")}"
if [[ -z "${SOURCE_DIR:-}" ]]; then
  SOURCE_DIR="$("$SCRIPT_DIR/resolve-lazycodingagent-output.sh" "$ROOT" "" build-linux-deb)"
fi
DESKTOP_SRC="$ROOT/installer/linux/lazycodingagent.desktop"
ICON_SRC="$ROOT/assets/owl_icon.png"
PKG_NAME="lazycodingagent"
STAGING="$ROOT/build/deb-staging"
DIST="$ROOT/dist"

BIN="$SOURCE_DIR/lazycodingagent"
if [[ ! -f "$BIN" ]]; then
  echo "build-linux-deb: missing binary $BIN (run ci-linux-qt5-release-build.sh first)" >&2
  exit 1
fi
if [[ ! -f "$DESKTOP_SRC" ]]; then
  echo "build-linux-deb: missing $DESKTOP_SRC" >&2
  exit 1
fi
if [[ ! -f "$ICON_SRC" ]]; then
  echo "build-linux-deb: missing $ICON_SRC" >&2
  exit 1
fi

rm -rf "$STAGING"
mkdir -p "$STAGING/DEBIAN"
mkdir -p "$STAGING/usr/lib/lazycodingagent"
mkdir -p "$STAGING/usr/bin"
mkdir -p "$STAGING/usr/share/applications"
mkdir -p "$STAGING/usr/share/icons/hicolor/32x32/apps"
mkdir -p "$STAGING/usr/share/icons/hicolor/48x48/apps"
mkdir -p "$STAGING/usr/share/icons/hicolor/256x256/apps"

install -m 755 "$BIN" "$STAGING/usr/lib/lazycodingagent/lazycodingagent"
if [[ -d "$SOURCE_DIR/help" ]]; then
  cp -a "$SOURCE_DIR/help" "$STAGING/usr/lib/lazycodingagent/"
fi
if [[ -d "$SOURCE_DIR/assets" ]]; then
  cp -a "$SOURCE_DIR/assets" "$STAGING/usr/lib/lazycodingagent/"
fi

cat > "$STAGING/usr/bin/lazycodingagent" <<'EOF'
#!/bin/sh
exec /usr/lib/lazycodingagent/lazycodingagent "$@"
EOF
chmod 755 "$STAGING/usr/bin/lazycodingagent"

install -m 644 "$DESKTOP_SRC" "$STAGING/usr/share/applications/lazycodingagent.desktop"

for size in 32 48 256; do
  install -m 644 "$ICON_SRC" "$STAGING/usr/share/icons/hicolor/${size}x${size}/apps/lazycodingagent.png"
done

SHLIB_WORK="$ROOT/build/deb-shlibdeps"
rm -rf "$SHLIB_WORK"
mkdir -p "$SHLIB_WORK/debian"
cat > "$SHLIB_WORK/debian/control" <<EOF
Source: ${PKG_NAME}
Package: ${PKG_NAME}
Version: ${VERSION}
Architecture: ${DEB_ARCH}
EOF

SHLIBS_RAW="$(
  cd "$SHLIB_WORK" && \
  dpkg-shlibdeps -O \
    -l"$STAGING/usr/lib/lazycodingagent" \
    "$STAGING/usr/lib/lazycodingagent/lazycodingagent" 2>&1
)"

SHLIBS="$(printf '%s\n' "$SHLIBS_RAW" | grep -E '^shlibs:Depends=' | sed 's/^shlibs:Depends=/Depends: /' | head -1)"
if [[ -z "$SHLIBS" ]]; then
  echo "build-linux-deb: dpkg-shlibdeps did not produce shlibs:Depends" >&2
  printf '%s\n' "$SHLIBS_RAW" >&2
  exit 1
fi
# OpenSSL is loaded at runtime (FPC opensslsockets); ensure HTTPS works on minimal installs (Pi bookworm+).
SHLIBS="${SHLIBS}, libssl3 | libssl3t64"
rm -rf "$SHLIB_WORK"

cat > "$STAGING/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Section: devel
Priority: optional
Architecture: ${DEB_ARCH}
Maintainer: LazyCodingAgent Contributors
${SHLIBS}
Homepage: https://github.com/olbrichattila/lazycodingagent
Description: AI coding assistant and editor (Lazarus LCL)
 LazyCodingAgent is a desktop AI coding assistant built with Free Pascal and Lazarus.
EOF

mkdir -p "$DIST"
OUT_DEB="$DIST/LazyCodingAgent-${VERSION}-${DEB_ARCH}.deb"
dpkg-deb --build --root-owner-group "$STAGING" "$OUT_DEB"

echo "build-linux-deb: $OUT_DEB"
