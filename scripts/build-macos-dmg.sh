#!/usr/bin/env bash
# Package lazycodingagent Cocoa build as Lazy Coding Agent.app inside a release DMG.
set -euo pipefail

VERSION="${APP_VERSION:-${1:-}}"
if [[ -z "$VERSION" ]]; then
  echo "build-macos-dmg: set APP_VERSION or pass version as first argument" >&2
  exit 1
fi

if [[ "$VERSION" =~ [^0-9a-zA-Z.+~-] ]]; then
  echo "build-macos-dmg: invalid version string: $VERSION" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST="$ROOT/dist"
if command -v fpc >/dev/null 2>&1; then
  MACOS_CPU="${MACOS_RELEASE_ARCH:-$(fpc -iTP)}"
else
  MACOS_CPU="${MACOS_RELEASE_ARCH:-aarch64}"
fi
STAGE="$ROOT/build/dmg-staging-${MACOS_CPU}"
WORKDIR="${MACOS_BUNDLE_WORKDIR:-$ROOT/build/macos-bundle-${MACOS_CPU}}"
EXE_NAME=lazycodingagent
DISPLAY_BUNDLE_NAME="Lazy Coding Agent.app"
ICNS_SRC="$ROOT/installer/macos/lazycodingagent.icns"
BUNDLE_ID="com.lazarus.lazycodingagent"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "build-macos-dmg: requires macOS (Darwin)" >&2
  exit 1
fi

"$SCRIPT_DIR/build-macos-icon.sh"

LIB_DIR="$ROOT/lib/$(fpc -iTP)-$(fpc -iTO)"
SOURCE_DIR="${SOURCE_DIR:-$("$SCRIPT_DIR/resolve-lazycodingagent-output.sh" "$ROOT" "" build-macos-dmg)}"

find_source_bundle() {
  local dir="$1"
  local candidate
  for candidate in "$dir/$EXE_NAME.app" "$dir/$DISPLAY_BUNDLE_NAME"; do
    [[ -d "$candidate/Contents" ]] && echo "$candidate" && return 0
  done
  local app
  for app in "$dir"/*.app; do
    [[ -d "$app/Contents" ]] && echo "$app" && return 0
  done
  return 1
}

SRC_BUNDLE="$(find_source_bundle "$SOURCE_DIR" || true)"
BIN="$SOURCE_DIR/$EXE_NAME"

if [[ -z "$SRC_BUNDLE" && ! -f "$BIN" ]]; then
  echo "build-macos-dmg: no bundle or binary under $SOURCE_DIR" >&2
  exit 1
fi

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
OUT_BUNDLE="$WORKDIR/$DISPLAY_BUNDLE_NAME"

if [[ -n "$SRC_BUNDLE" ]]; then
  cp -a "$SRC_BUNDLE" "$OUT_BUNDLE"
else
  mkdir -p "$OUT_BUNDLE/Contents/MacOS" "$OUT_BUNDLE/Contents/Resources"
  install -m 755 "$BIN" "$OUT_BUNDLE/Contents/MacOS/$EXE_NAME"
  cat > "$OUT_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>English</string>
  <key>CFBundleExecutable</key>
  <string>${EXE_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleName</key>
  <string>Lazy Coding Agent</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF
  printf 'APPL????' > "$OUT_BUNDLE/Contents/PkgInfo"
fi

MACOS_DIR="$OUT_BUNDLE/Contents/MacOS"
RES_DIR="$OUT_BUNDLE/Contents/Resources"
mkdir -p "$MACOS_DIR" "$RES_DIR"

# Replace Lazarus debug symlink with a real binary for distribution.
if [[ -L "$MACOS_DIR/$EXE_NAME" ]]; then
  link_target="$(readlink "$MACOS_DIR/$EXE_NAME")"
  resolved="$MACOS_DIR/$link_target"
  if [[ ! -f "$resolved" ]]; then
    resolved="$SOURCE_DIR/$EXE_NAME"
  fi
  if [[ ! -f "$resolved" ]]; then
    echo "build-macos-dmg: cannot resolve bundle symlink to executable" >&2
    exit 1
  fi
  rm -f "$MACOS_DIR/$EXE_NAME"
  install -m 755 "$resolved" "$MACOS_DIR/$EXE_NAME"
elif [[ ! -f "$MACOS_DIR/$EXE_NAME" ]]; then
  install -m 755 "$BIN" "$MACOS_DIR/$EXE_NAME"
fi

"$SCRIPT_DIR/post-build.sh" "$ROOT" "$MACOS_DIR"

if [[ -f "$ICNS_SRC" ]]; then
  install -m 644 "$ICNS_SRC" "$RES_DIR/lazycodingagent.icns"
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$OUT_BUNDLE/Contents/Info.plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string lazycodingagent.icns" "$OUT_BUNDLE/Contents/Info.plist"
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleName 'Lazy Coding Agent'" "$OUT_BUNDLE/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleName string 'Lazy Coding Agent'" "$OUT_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$OUT_BUNDLE/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$OUT_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$OUT_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$OUT_BUNDLE/Contents/Info.plist"

bundle_openssl_libs() {
  local exe="$MACOS_DIR/$EXE_NAME"
  local fw="$OUT_BUNDLE/Contents/Frameworks"
  local dep path base new_id copied=0
  mkdir -p "$fw"
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]] ]] || continue
    dep="${line#"${line%%[![:space:]]*}"}"
    dep="${dep%% *}"
    case "$dep" in
      /usr/lib/*|/System/*|@executable_path/*|@loader_path/*) continue ;;
    esac
    if [[ "$dep" != *libssl* && "$dep" != *libcrypto* ]]; then
      continue
    fi
    base="$(basename "$dep")"
    if [[ ! -f "$fw/$base" ]]; then
      if [[ ! -f "$dep" ]]; then
        echo "build-macos-dmg: warning: missing OpenSSL dylib $dep" >&2
        continue
      fi
      install -m 644 "$dep" "$fw/$base"
      copied=1
    fi
    new_id="@loader_path/../Frameworks/$base"
    install_name_tool -change "$dep" "$new_id" "$exe" 2>/dev/null || true
    install_name_tool -id "$new_id" "$fw/$base" 2>/dev/null || true
  done < <(otool -L "$exe")
  if [[ "$copied" == 1 ]]; then
    for lib in "$fw"/libssl*.dylib "$fw"/libcrypto*.dylib; do
      [[ -f "$lib" ]] || continue
      while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]] ]] || continue
        path="${line#"${line%%[![:space:]]*}"}"
        path="${path%% *}"
        case "$path" in
          /usr/lib/*|/System/*|@*) continue ;;
        esac
        base="$(basename "$path")"
        if [[ -f "$fw/$base" ]]; then
          install_name_tool -change "$path" "@loader_path/$base" "$lib" 2>/dev/null || true
        fi
      done < <(otool -L "$lib")
    done
  fi
}

bundle_openssl_libs

# Future: replace ad-hoc signing with Developer ID + notarization (see README).
codesign --sign - --force --deep --options runtime "$OUT_BUNDLE"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -a "$OUT_BUNDLE" "$STAGE/"
ln -sf /Applications "$STAGE/Applications"

mkdir -p "$DIST"
DMG_PATH="$DIST/LazyCodingAgent-${VERSION}-${MACOS_CPU}.dmg"
rm -f "$DMG_PATH"
hdiutil create -volname "Lazy Coding Agent" -srcfolder "$STAGE" -ov -format UDZO "$DMG_PATH"

echo "build-macos-dmg: $DMG_PATH"
