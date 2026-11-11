#!/usr/bin/env bash
# Build sqlite3.o and link LazySqliteStatic for lazbuild.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAZBUILD="${LAZBUILD:-lazbuild}"
LPK="$ROOT/packages/LazySqliteStatic/LazySqliteStatic.lpk"

"$ROOT/scripts/build-sqlite-static.sh"
"$ROOT/scripts/ci-lazbuild.sh" --add-package-link "$LPK"
echo "LazySqliteStatic is linked for lazbuild."
