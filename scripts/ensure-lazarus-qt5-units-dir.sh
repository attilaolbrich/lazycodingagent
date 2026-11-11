#!/usr/bin/env bash
# Ensure Lazarus can write Qt5 widgetset units under the system tree (apt installs).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FPC_TRIPLE="$("$SCRIPT_DIR/linux-fpc-target-triple.sh")"
user="${SUDO_USER:-${USER:-runner}}"
group="$(id -gn "$user" 2>/dev/null || echo "$user")"

for units_root in /usr/lib/lazarus/*/units/"$FPC_TRIPLE" /usr/share/lazarus/*/units/"$FPC_TRIPLE"; do
  [[ -d "$(dirname "$units_root")" ]] || continue
  qt5_dir="${units_root}/qt5"
  if [[ ! -d "$qt5_dir" ]]; then
    echo "ensure-lazarus-qt5-units-dir: creating writable $qt5_dir"
    sudo install -d -o "$user" -g "$group" "$qt5_dir"
  elif [[ ! -w "$qt5_dir" ]]; then
    echo "ensure-lazarus-qt5-units-dir: fixing ownership on $qt5_dir"
    sudo chown -R "$user:$group" "$qt5_dir"
  fi
  exit 0
done

echo "ensure-lazarus-qt5-units-dir: warning: no lazarus units/$FPC_TRIPLE found" >&2
exit 0
