#!/usr/bin/env bash
set -euo pipefail

SAMBA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SAMBA_ROOT/../_shared.sh"

header "Configure Samba"
require_command tailscale
require_command firewall-cmd
require_command findmnt
env_file="$HOME/.config/containers/systemd/samba.env"
if [[ ! -f "$env_file" ]] || ! grep -Eq '^ACCOUNT_henrique=[^[:space:]]+' "$env_file"; then
  error "Create $env_file with ACCOUNT_henrique before continuing. See bazzite/samba/README.md."
  exit 1
fi
findmnt -rn --target /run/media/system/hd --output TARGET | grep -Fxq /run/media/system/hd || { error "Storage disk is not mounted at /run/media/system/hd."; exit 1; }
listen_ip="$(sed -n 's/^PublishPort=\([0-9.]*\):445:445$/\1/p' "$SAMBA_ROOT/samba.container")"
[[ -n "$listen_ip" ]] && tailscale ip -4 | grep -Fxq "$listen_ip" || { error "Samba listen address does not match this host's Tailscale IP."; exit 1; }
[[ "$(sysctl -n net.ipv4.ip_unprivileged_port_start)" -le 445 ]] || { error "Configure net.ipv4.ip_unprivileged_port_start <= 445; see bazzite/samba/README.md."; exit 1; }
zone="$(firewall-cmd --get-zone-of-interface=tailscale0)"
firewall-cmd --zone="$zone" --query-rich-rule='rule family="ipv4" source address="100.64.0.0/10" port port="445" protocol="tcp" accept' >/dev/null || { error "Allow TCP 445 from the tailnet in firewalld; see bazzite/samba/README.md."; exit 1; }
deploy_unit_file "$SAMBA_ROOT/samba.container"
start_quadlet samba
