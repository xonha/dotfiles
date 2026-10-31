#!/usr/bin/env bash
set -euo pipefail
JELLYFIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$JELLYFIN_ROOT/../_shared.sh"
header "Configure Jellyfin"
require_command findmnt
[[ "$(findmnt -rn -M /run/media/system/hd -o SOURCE)" == /dev/sdb1 ]] || { error "Expected /dev/sdb1 mounted at /run/media/system/hd."; exit 1; }
mkdir -p "$HOME/.local/share/jellyfin/config" "$HOME/.local/share/jellyfin/cache" /run/media/system/hd/mediarium/{movies,tv,music}
deploy_unit_file "$JELLYFIN_ROOT/jellyfin.container"
start_quadlet jellyfin
if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
  tailscale serve --bg --https=8450 http://127.0.0.1:8096
  success "Jellyfin is available over Tailscale Serve on HTTPS port 8450."
else
  warn "Tailscale is unavailable; Jellyfin is listening only on 127.0.0.1:8096."
fi
