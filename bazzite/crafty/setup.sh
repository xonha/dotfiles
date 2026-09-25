#!/usr/bin/env bash
set -euo pipefail

CRAFTY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CRAFTY_ROOT/../_shared.sh"

header "Configure Crafty"
for directory in config servers backups logs import; do
  target="$HOME/.local/share/crafty/$directory"
  if [[ ! -d "$target" ]]; then
    mkdir -p "$target"
    podman unshare chown 1000:0 "$target"
  fi
done
deploy_unit_file "$CRAFTY_ROOT/crafty.container"
start_quadlet crafty
