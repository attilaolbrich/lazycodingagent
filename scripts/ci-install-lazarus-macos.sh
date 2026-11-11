#!/usr/bin/env bash
# Install pinned FPC + Lazarus from SourceForge for GitHub Actions (Homebrew cask is disabled).
set -euo pipefail

# Pinned to Lazarus macOS 4.8 on SourceForge (aarch64 or x86_64 via CI_MACOS_ARCH).
CI_MACOS_ARCH="${CI_MACOS_ARCH:-aarch64}"

case "$CI_MACOS_ARCH" in
  aarch64)
    TARGET_ID="macos-aarch64"
    LAZARUS_ZIP="lazarus-darwin-aarch64-4.8.zip"
    ;;
  x86_64)
    TARGET_ID="macos-x86_64"
    LAZARUS_ZIP="lazarus-darwin-x86_64-4.8.zip"
    ;;
  *)
    echo "ci-install-lazarus-macos: unsupported CI_MACOS_ARCH=$CI_MACOS_ARCH (use aarch64 or x86_64)" >&2
    exit 1
    ;;
esac

FPC_DMG="fpc-3.2.4rc1a.intelarm64-macosx.dmg"

WORKDIR="${CI_LAZARUS_WORKDIR:-${RUNNER_TEMP:-/tmp}/lazarus-ci-${CI_MACOS_ARCH}}"
LAZARUS_INSTALL="${CI_LAZARUS_ROOT:-$WORKDIR/lazarus-tree}"
PRIMARY_CONFIG="$WORKDIR/primary-config"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$WORKDIR"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/ci-lazbuild.sh"

resolve_artifact() {
  local filename="$1" dest="$2"
  "$SCRIPT_DIR/ci-resolve-lazarus-artifact.sh" "$TARGET_ID" "$filename" "$dest"
}

expected_fpc_cpu_for_ci() {
  case "$CI_MACOS_ARCH" in
    aarch64) echo aarch64 ;;
    x86_64) echo x86_64 ;;
    *) echo "$CI_MACOS_ARCH" ;;
  esac
}

fpc_matches_ci_arch() {
  if ! command -v fpc >/dev/null 2>&1; then
    return 1
  fi
  local expected actual
  expected="$(expected_fpc_cpu_for_ci)"
  actual="$(fpc -iPA 2>/dev/null || true)"
  [[ "$actual" == "$expected" ]]
}

ci_append_darwin_fpc_cfg() {
  if [[ "$(uname -s)" != Darwin ]]; then
    return 0
  fi
  if ! command -v fpc >/dev/null 2>&1; then
    echo "ci-install-lazarus-macos: skip fpc.cfg patch (no fpc on PATH)" >&2
    return 0
  fi
  local sdk fpc_cfg marker block
  sdk="$(xcrun --show-sdk-path 2>/dev/null || true)"
  if [[ -z "$sdk" ]]; then
    echo "ci-install-lazarus-macos: skip fpc.cfg patch (no SDK)" >&2
    return 0
  fi
  fpc_cfg="$(fpc -iD 2>/dev/null || true)"
  fpc_cfg="${fpc_cfg%/}/etc/fpc.cfg"
  if [[ ! -f "$fpc_cfg" ]]; then
    echo "ci-install-lazarus-macos: skip fpc.cfg patch (missing $fpc_cfg)" >&2
    return 0
  fi
  marker="ci-darwin-linker-ld_classic"
  if grep -q "$marker" "$fpc_cfg" 2>/dev/null; then
    echo "ci-install-lazarus-macos: $fpc_cfg already has Darwin linker stanza"
    return 0
  fi
  block="# ${marker}
#ifdef darwin
-XR${sdk}
-k-ld_classic
#endif
"
  printf '%s' "$block" | sudo tee -a "$fpc_cfg" >/dev/null
  echo "ci-install-lazarus-macos: appended Darwin linker flags to $fpc_cfg"
}

install_fpc_from_dmg() {
  if fpc_matches_ci_arch; then
    echo "ci-install-lazarus-macos: fpc on PATH matches CI_MACOS_ARCH=$CI_MACOS_ARCH ($(fpc -iV 2>/dev/null || true)), skipping FPC DMG"
    return 0
  fi
  if command -v fpc >/dev/null 2>&1; then
    echo "ci-install-lazarus-macos: fpc CPU $(fpc -iPA 2>/dev/null || true) does not match CI_MACOS_ARCH=$CI_MACOS_ARCH, installing from DMG"
  fi

  echo "ci-install-lazarus-macos: installing FPC from $FPC_DMG"
  local fpc_path="$WORKDIR/$FPC_DMG"
  resolve_artifact "$FPC_DMG" "$fpc_path"

  local fpc_mount="$WORKDIR/fpc-mount"
  mkdir -p "$fpc_mount"
  hdiutil attach "$fpc_path" -mountpoint "$fpc_mount" -nobrowse -quiet
  local fpc_pkg
  fpc_pkg="$(find "$fpc_mount" -maxdepth 2 -name '*.pkg' -print -quit)"
  if [[ -z "$fpc_pkg" ]]; then
    echo "ci-install-lazarus-macos: no .pkg found in FPC DMG" >&2
    hdiutil detach "$fpc_mount" -quiet || true
    exit 1
  fi
  sudo installer -pkg "$fpc_pkg" -target /
  hdiutil detach "$fpc_mount" -quiet
}

install_lazarus_tree() {
  local lazbuild_bin zip_path
  lazbuild_bin="$(find "$LAZARUS_INSTALL" -name lazbuild -type f -print -quit 2>/dev/null || true)"
  if [[ -n "$lazbuild_bin" && -x "$lazbuild_bin" ]]; then
    echo "ci-install-lazarus-macos: Lazarus tree already present at $LAZARUS_INSTALL"
    return 0
  fi

  echo "ci-install-lazarus-macos: installing Lazarus from $LAZARUS_ZIP"
  zip_path="$WORKDIR/$LAZARUS_ZIP"
  resolve_artifact "$LAZARUS_ZIP" "$zip_path"
  xattr -cr "$zip_path"
  rm -rf "$LAZARUS_INSTALL"
  mkdir -p "$LAZARUS_INSTALL"
  unzip -q "$zip_path" -d "$LAZARUS_INSTALL"
}

install_fpc_from_dmg
ci_append_darwin_fpc_cfg
install_lazarus_tree

LAZBUILD_BIN="$(find "$LAZARUS_INSTALL" -name lazbuild -type f -print -quit)"
if [[ -z "$LAZBUILD_BIN" ]]; then
  echo "ci-install-lazarus-macos: lazbuild not found under $LAZARUS_INSTALL" >&2
  exit 1
fi
LAZARUS_ROOT="$(cd "$(dirname "$LAZBUILD_BIN")" && pwd)"
LAZBUILD_BIN="$LAZARUS_ROOT/lazbuild"

if [[ ! -x "$LAZBUILD_BIN" ]]; then
  chmod +x "$LAZBUILD_BIN"
fi

mkdir -p "$PRIMARY_CONFIG"
export LAZARUS_DIR="$LAZARUS_ROOT"
export LAZBUILD="$LAZBUILD_BIN"
export LAZARUS_PRIMARY_CONFIG="$PRIMARY_CONFIG"
export LCL_WIDGETSET=cocoa
export PATH="$LAZARUS_ROOT:/usr/local/bin:${PATH}"

ci_darwin_apply_fpc_linker_env

"$SCRIPT_DIR/ci-lazbuild.sh" --version

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "LAZARUS_DIR=$LAZARUS_ROOT"
    echo "LAZBUILD=$LAZBUILD_BIN"
    echo "LAZARUS_PRIMARY_CONFIG=$PRIMARY_CONFIG"
    echo "LCL_WIDGETSET=cocoa"
    echo "PATH=$LAZARUS_ROOT:/usr/local/bin:${PATH}"
    if [[ -n "${FPCOPT:-}" ]]; then
      echo "FPCOPT=$FPCOPT"
    fi
  } >>"$GITHUB_ENV"
fi

echo "ci-install-lazarus-macos: ready (arch=$CI_MACOS_ARCH, LAZARUS_DIR=$LAZARUS_ROOT, LAZARUS_PRIMARY_CONFIG=$PRIMARY_CONFIG)"
