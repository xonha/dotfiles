#!/usr/bin/env bash
set -euo pipefail

BAZZITE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BAZZITE_ROOT/_shared.sh"

if ! grep -qi bazzite /etc/os-release; then
  error "This setup must run on a Bazzite host."
  exit 1
fi
if (( EUID == 0 )); then
  error "Run as the regular user with an active systemd user session."
  exit 1
fi
require_command podman
require_command systemctl
require_command loginctl
loginctl enable-linger "$USER"
if command -v tailscale >/dev/null 2>&1; then
  tailscale status >/dev/null || warn "Tailscale is not connected; remote access may be unavailable."
else
  warn "Tailscale is not installed; check remote access after setup."
fi

for service in "$@"; do
  case "$service" in
    lab|crafty|keeper|samba|immich) ;;
    *) error "Unknown service: $service"; exit 2 ;;
  esac
  bash "$BAZZITE_ROOT/$service/setup.sh"
done
