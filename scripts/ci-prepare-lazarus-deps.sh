#!/usr/bin/env bash
# Link SynEdit for headless lazbuild (CI or fresh Linux/macOS install).
set -euo pipefail

LAZBUILD="${LAZBUILD:-lazbuild}"

resolve_lazbuild() {
  local candidate="$1"
  if [[ -f "$candidate" ]] && [[ -x "$candidate" ]]; then
    echo "$candidate"
    return 0
  fi
  if command -v "$candidate" >/dev/null 2>&1; then
    command -v "$candidate"
    return 0
  fi
  return 1
}

LAZBUILD="$(resolve_lazbuild "$LAZBUILD")" || {
  echo "ci-prepare-lazarus-deps: lazbuild not found (set LAZBUILD)" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_lazbuild() {
  if [[ -n "${LAZARUS_PRIMARY_CONFIG:-}" ]] || [[ -n "${LCL_WIDGETSET:-}" ]]; then
    "$SCRIPT_DIR/ci-lazbuild.sh" "$@"
  else
    "$LAZBUILD" "$@"
  fi
}

link_and_build() {
  local lpk="$1"
  if [[ ! -f "$lpk" ]]; then
    echo "ci-prepare-lazarus-deps: missing $lpk" >&2
    return 1
  fi
  run_lazbuild --add-package-link "$lpk"
  run_lazbuild "$lpk"
}

lazarus_root_has_synedit() {
  local root="$1"
  [[ -n "$root" ]] && [[ -f "${root}/components/synedit/synedit.lpk" ]]
}

resolve_lazarus_root() {
  local root lb resolved syn

  lb="$(readlink -f "$LAZBUILD" 2>/dev/null || realpath "$LAZBUILD" 2>/dev/null || echo "$LAZBUILD")"
  root="$(dirname "$lb")"
  if lazarus_root_has_synedit "$root"; then
    echo "$root"
    return 0
  fi

  for root in \
    "${LAZARUS_DIR:-}" \
    "/usr/lib/lazarus" \
    "/usr/share/lazarus" \
    "/Applications/Lazarus/lazarus" \
    "/Applications/Lazarus" \
    ; do
    if lazarus_root_has_synedit "$root"; then
      echo "$root"
      return 0
    fi
  done

  shopt -s nullglob
  for syn in /usr/share/lazarus/*/components/synedit/synedit.lpk; do
    if [[ -f "$syn" ]]; then
      resolved="$(cd "$(dirname "$syn")/../.." && pwd)"
      echo "$resolved"
      return 0
    fi
  done
  shopt -u nullglob

  return 1
}

LAZARUS_ROOT="$(resolve_lazarus_root)" || {
  echo "ci-prepare-lazarus-deps: Lazarus root not found (lazbuild=$LAZBUILD, LAZARUS_DIR=${LAZARUS_DIR:-})" >&2
  exit 1
}

SYNEDIT_LPK="${LAZARUS_ROOT}/components/synedit/synedit.lpk"

link_and_build "$SYNEDIT_LPK"

DSGN_LPK="$(dirname "$SYNEDIT_LPK")/syneditdsgn.lpk"
if [[ -f "$DSGN_LPK" ]]; then
  link_and_build "$DSGN_LPK"
fi

echo "ci-prepare-lazarus-deps: SynEdit linked (LAZARUS_ROOT=$LAZARUS_ROOT)."
