#!/usr/bin/env bash
set -euo pipefail

IMMICH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$IMMICH_ROOT/../_shared.sh"

header "Configure Immich"
require_command findmnt
destination="$HOME/immich"
[[ -f "$destination/.env" ]] || { error "Create $destination/.env before continuing; see bazzite/immich/README.md."; exit 1; }
findmnt -rn --target /run/media/system/hd --output TARGET | grep -Fxq /run/media/system/hd || { error "Media disk is not mounted at /run/media/system/hd."; exit 1; }
for key in DB_PASSWORD DB_USERNAME DB_DATABASE_NAME DB_DATA_LOCATION UPLOAD_LOCATION LAN_IP TAILSCALE_IP; do
  grep -Eq "^${key}=[^[:space:]]+" "$destination/.env" || { error "Set $key in $destination/.env before continuing."; exit 1; }
done
upload_location="$(sed -n 's/^UPLOAD_LOCATION=//p' "$destination/.env" | tail -n 1)"
[[ "$upload_location" == /run/media/system/hd/* ]] || { error "UPLOAD_LOCATION must be on the mounted media disk."; exit 1; }
tailscale_ip="$(sed -n 's/^TAILSCALE_IP=//p' "$destination/.env" | tail -n 1)"
command -v tailscale >/dev/null 2>&1 && tailscale ip -4 | grep -Fxq "$tailscale_ip" || { error "TAILSCALE_IP does not match this host."; exit 1; }
source_compose="$IMMICH_ROOT/docker-compose.yml"
target_compose="$destination/docker-compose.yml"
if [[ -e "$target_compose" ]]; then
  cmp -s "$source_compose" "$target_compose" || { error "Existing Compose file differs: $target_compose. Review before replacing."; exit 1; }
else
  install -m 0644 "$source_compose" "$target_compose"
fi
cd "$destination"
podman compose config >/dev/null
podman compose up -d
systemctl --user enable --now podman-restart.service
podman compose ps
