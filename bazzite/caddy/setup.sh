#!/usr/bin/env bash
set -euo pipefail

CADDY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CADDY_ROOT/../_shared.sh"

header "Configure Caddy"
env_file="$HOME/.config/containers/systemd/caddy.env"
if [[ ! -f "$env_file" ]] || ! grep -Eq '^CLOUDFLARE_API_TOKEN=[^[:space:]]+' "$env_file"; then
  error "Create $env_file with CLOUDFLARE_API_TOKEN before continuing. See bazzite/caddy/README.md."
  exit 1
fi

caddyfile="$HOME/.config/caddy/Caddyfile"
mkdir -p "$(dirname "$caddyfile")" "$HOME/.local/share/caddy/data" "$HOME/.local/share/caddy/config"
if [[ -e "$caddyfile" ]] && ! cmp -s "$CADDY_ROOT/Caddyfile" "$caddyfile"; then
  error "Existing Caddyfile differs from the versioned copy: $caddyfile. Review it before replacing."
  exit 1
fi
install -m 0644 "$CADDY_ROOT/Caddyfile" "$caddyfile"

if ! podman image exists localhost/caddy-cloudflare:2; then
  podman build -f "$CADDY_ROOT/Containerfile" -t localhost/caddy-cloudflare:2 "$CADDY_ROOT"
fi
deploy_unit_file "$CADDY_ROOT/caddy.container"
start_quadlet caddy

if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
  tailscale serve --bg --tcp=443 tcp://127.0.0.1:8453
  success "Tailscale port 443 now forwards to Caddy on 127.0.0.1:8453."
else
  warn "Tailscale is unavailable; Caddy is listening only on 127.0.0.1:8453."
fi
