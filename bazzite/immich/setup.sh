#!/usr/bin/env bash
set -euo pipefail

IMMICH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$IMMICH_ROOT/../_shared.sh"

header "Configure Immich"
require_command findmnt
destination="$HOME/immich"
user_systemd_dir="$HOME/.config/systemd/user"
user_exec_dir="$HOME/.local/libexec"
[[ -f "$destination/.env" ]] || { error "Create $destination/.env before continuing; see bazzite/immich/README.md."; exit 1; }
findmnt -rn --target /run/media/system/hd --output TARGET | grep -Fxq /run/media/system/hd || { error "Media disk is not mounted at /run/media/system/hd."; exit 1; }
for key in DB_PASSWORD DB_USERNAME DB_DATABASE_NAME DB_DATA_LOCATION UPLOAD_LOCATION; do
  grep -Eq "^${key}=[^[:space:]]+" "$destination/.env" || { error "Set $key in $destination/.env before continuing."; exit 1; }
done
upload_location="$(sed -n 's/^UPLOAD_LOCATION=//p' "$destination/.env" | tail -n 1)"
[[ "$upload_location" == /run/media/system/hd/* ]] || { error "UPLOAD_LOCATION must be on the mounted media disk."; exit 1; }
[[ -d "$upload_location" ]] || { error "UPLOAD_LOCATION does not exist: $upload_location"; exit 1; }
mount_source="$(findmnt -rn --target /run/media/system/hd --output SOURCE)"
[[ "$mount_source" == /dev/sdb1 ]] || { error "Expected /dev/sdb1 mounted at /run/media/system/hd, found $mount_source."; exit 1; }
install -d "$user_systemd_dir/podman-restart.service.d"
install -m 0644 "$IMMICH_ROOT/podman-restart.service.d/10-immich-mount.conf" \
  "$user_systemd_dir/podman-restart.service.d/10-immich-mount.conf"
install -d "$user_exec_dir"
install -m 0755 "$IMMICH_ROOT/immich-healthcheck.sh" "$user_exec_dir/immich-healthcheck.sh"
install -m 0644 "$IMMICH_ROOT/immich-healthcheck.service" "$user_systemd_dir/immich-healthcheck.service"
install -m 0644 "$IMMICH_ROOT/immich-healthcheck.timer" "$user_systemd_dir/immich-healthcheck.timer"
systemctl --user daemon-reload
source_compose="$IMMICH_ROOT/docker-compose.yml"
target_compose="$destination/docker-compose.yml"
if [[ -e "$target_compose" ]]; then
  if ! cmp -s "$source_compose" "$target_compose"; then
    backup="$target_compose.backup.$(date +%Y%m%d%H%M%S)"
    cp -a "$target_compose" "$backup"
    install -m 0644 "$source_compose" "$target_compose"
    info "Previous Compose file saved to $backup"
  fi
else
  install -m 0644 "$source_compose" "$target_compose"
fi
cd "$destination"
podman compose config >/dev/null
podman compose up -d
systemctl --user enable --now podman-restart.service
systemctl --user enable --now immich-healthcheck.timer
podman compose ps
