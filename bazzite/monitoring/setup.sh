#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")" && pwd)
host=${BAZZITE_SSH_HOST:-bazzite}
ssh "$host" 'mkdir -p ~/.local/libexec ~/.config/systemd/user ~/.config/bazzite-monitoring; chmod 700 ~/.config/bazzite-monitoring'
scp -q "$root/check.sh" "$host:.local/libexec/bazzite-healthcheck.sh"
scp -q "$root/"*.service "$root/"*.timer "$host:.config/systemd/user/"
# Apply only restart policy overrides: no container recreation or session loss.
ssh "$host" 'bash -s' <<'REMOTE'
set -eu
for unit in samba crafty caddy lab songmirror keeper mediarium jellyfin cloudflared; do
 mkdir -p "$HOME/.config/systemd/user/$unit.service.d"
 printf '[Unit]\nStartLimitIntervalSec=0\n[Service]\nRestartSec=30\n' > "$HOME/.config/systemd/user/$unit.service.d/30-restart-policy.conf"
done
chmod 755 ~/.local/libexec/bazzite-healthcheck.sh
systemctl --user daemon-reload
systemctl --user enable --now bazzite-healthcheck.timer
systemctl --user reset-failed podman-restart.service
REMOTE
