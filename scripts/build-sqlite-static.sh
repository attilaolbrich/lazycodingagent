#!/usr/bin/env bash
# Compile third_party/sqlite/sqlite3.c to a platform object for LazySqliteStatic.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/third_party/sqlite/sqlite3.c"
PKG_LIB="$ROOT/packages/LazySqliteStatic/lib"

if [[ ! -f "$SRC" ]]; then
  echo "Missing $SRC — download SQLite amalgamation into third_party/sqlite/" >&2
  exit 1
fi

OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS" in
  Linux)
    TARGET_OS=linux
    ;;
  Darwin)
    TARGET_OS=darwin
    ;;
  *)
    echo "Unsupported OS for build-sqlite-static.sh: $OS (use build-sqlite-static.ps1 on Windows)" >&2
    exit 1
    ;;
esac

case "$ARCH" in
  x86_64|amd64) TARGET_CPU=x86_64 ;;
  aarch64|arm64) TARGET_CPU=aarch64 ;;
  *)
    echo "Unsupported CPU: $ARCH" >&2
    exit 1
    ;;
esac

OUT_DIR="$PKG_LIB/${TARGET_CPU}-${TARGET_OS}"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/sqlite3.o"
SRC_OBJ="$ROOT/packages/LazySqliteStatic/src/sqlite3_embed.o"

CFLAGS=(
  -c -O2 -fPIC
  -DSQLITE_ENABLE_FTS5
  -DSQLITE_THREADSAFE=1
  -DSQLITE_ENABLE_JSON1
)
if [[ "$TARGET_OS" == darwin ]]; then
  MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-11.0}"
  echo "build-sqlite-static: Darwin MACOS_DEPLOYMENT_TARGET=$MACOS_DEPLOYMENT_TARGET"
  CFLAGS+=( -Wno-ignored-qualifiers -mmacosx-version-min="$MACOS_DEPLOYMENT_TARGET" )
else
  CFLAGS+=( -Wno-discarded-qualifiers )
fi

if [[ "${BUILD_SQLITE_VEC:-0}" == "1" ]]; then
  echo "BUILD_SQLITE_VEC=1: sqlite-vec hook not implemented yet" >&2
  exit 1
fi

CC="${CC:-cc}"
"$CC" "${CFLAGS[@]}" -o "$OUT" "$SRC"
cp -f "$OUT" "$SRC_OBJ"
cp -f "$OUT" "$OUT_DIR/sqlite3_embed.o"
echo "Built $OUT ($SRC_OBJ and $OUT_DIR/sqlite3_embed.o)"
