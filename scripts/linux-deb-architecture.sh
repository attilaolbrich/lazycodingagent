#!/usr/bin/env bash
# Map FPC -iTP CPU to Debian package Architecture (amd64, arm64, ...).
set -euo pipefail
if ! command -v fpc >/dev/null 2>&1; then
  echo "linux-deb-architecture: fpc not found on PATH" >&2
  exit 1
fi
case "$(fpc -iTP)" in
  x86_64) echo amd64 ;;
  aarch64) echo arm64 ;;
  arm) echo armhf ;;
  *)
    echo "linux-deb-architecture: unsupported FPC CPU: $(fpc -iTP)" >&2
    exit 1
    ;;
esac
