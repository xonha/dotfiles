#!/usr/bin/env bash
set -euo pipefail
MEDIARIUM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MEDIARIUM_ROOT/../_shared.sh"
header "Configure Mediarium"
require_command findmnt
[[ "$(findmnt -rn -M /run/media/system/hd -o SOURCE)" == /dev/sdb1 ]] || { error "Expected /dev/sdb1 mounted at /run/media/system/hd."; exit 1; }
mkdir -p "$HOME/.local/share/mediarium/config" /run/media/system/hd/mediarium
deploy_unit_file "$MEDIARIUM_ROOT/mediarium.container"
start_quadlet mediarium
if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
  tailscale serve --bg --https=8449 http://127.0.0.1:8264
  success "Mediarium is available over Tailscale Serve on HTTPS port 8449."
else
  warn "Tailscale is unavailable; Mediarium is listening only on 127.0.0.1:8264."
fi
