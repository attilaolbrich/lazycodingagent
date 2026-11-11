#!/usr/bin/env bash
# Print FPC target triple for Linux paths (e.g. x86_64-linux, aarch64-linux).
set -euo pipefail
if ! command -v fpc >/dev/null 2>&1; then
  echo "linux-fpc-target-triple: fpc not found on PATH" >&2
  exit 1
fi
echo "$(fpc -iTP)-$(fpc -iTO)"
