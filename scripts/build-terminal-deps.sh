#!/usr/bin/env bash
# Register and compile TerminalEmulator Lazarus packages for lazycodingagent.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TE="$ROOT/third_party/TerminalEmulator"
LAZBUILD="${LAZBUILD:-lazbuild}"

if [[ ! -f "$TE/TerminalFramework/TerminalFramework.lpk" ]]; then
  echo "Missing vendored terminal: third_party/TerminalEmulator (TerminalFramework.lpk not found)" >&2
  exit 1
fi

"$LAZBUILD" --add-package-link "$TE/TerminalFramework/TerminalFramework.lpk"
"$LAZBUILD" --add-package-link "$TE/ViewLCL/ViewLCL.lpk"

echo "TerminalFramework and ViewLCL are linked for lazbuild."
