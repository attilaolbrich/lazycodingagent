#!/usr/bin/env bash
# lazbuild wrapper for CI (macOS SourceForge tree): correct LazarusDir and primary config.
set -euo pipefail

# shellcheck disable=SC2329
ci_darwin_linker_flags() {
  if [[ "$(uname -s)" != Darwin ]]; then
    return 0
  fi
  if [[ -n "${CI_DARWIN_LINKER_FLAGS_READY:-}" ]]; then
    echo "ci-lazbuild: Darwin linker flags already set (FPCOPT=${FPCOPT:-})"
    return 0
  fi
  local sdk extra
  sdk="$(xcrun --show-sdk-path 2>/dev/null || true)"
  if [[ -z "$sdk" ]]; then
    echo "ci-lazbuild: xcrun --show-sdk-path failed; install Xcode Command Line Tools" >&2
    exit 1
  fi
  extra="-XR${sdk} -k-ld_classic"
  if [[ -n "${FPCOPT:-}" ]]; then
    export FPCOPT="${FPCOPT} ${extra}"
  else
    export FPCOPT="$extra"
  fi
  export CI_DARWIN_LAZBUILD_OPT_XR="-XR${sdk}"
  export CI_DARWIN_LAZBUILD_OPT_K="-k-ld_classic"
  export CI_DARWIN_LINKER_FLAGS_READY=1
  echo "ci-lazbuild: FPCOPT=${FPCOPT}"
  echo "ci-lazbuild: will pass lazbuild --opt=${CI_DARWIN_LAZBUILD_OPT_XR} --opt=${CI_DARWIN_LAZBUILD_OPT_K}"
}

ci_darwin_apply_fpc_linker_env() {
  ci_darwin_linker_flags
}

LAZBUILD="${LAZBUILD:-lazbuild}"
args=()

if [[ -n "${LAZARUS_DIR:-}" && -n "${LAZARUS_PRIMARY_CONFIG:-}" ]]; then
  args+=(--lazarusdir="$LAZARUS_DIR" --primary-config-path="$LAZARUS_PRIMARY_CONFIG")
fi

if [[ -n "${LCL_WIDGETSET:-}" ]]; then
  args+=(--widgetset="$LCL_WIDGETSET")
fi

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ci_darwin_linker_flags
  if [[ -n "${CI_DARWIN_LAZBUILD_OPT_XR:-}" ]]; then
    args+=(--opt="$CI_DARWIN_LAZBUILD_OPT_XR" --opt="$CI_DARWIN_LAZBUILD_OPT_K")
  fi
  exec "$LAZBUILD" "${args[@]}" "$@"
fi
