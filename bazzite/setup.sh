#!/usr/bin/env bash
set -euo pipefail

BAZZITE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$BAZZITE_ROOT/.." && pwd)"
source "$DOTFILES_ROOT/setup/_shared.sh"

host="${BAZZITE_SSH_HOST:-bazzite}"
services=()

usage() {
  printf 'Usage: %s [lab|crafty|keeper|samba|immich ...]\n' "$0"
  printf 'With no arguments, choose services interactively. SSH host: %s\n' "$host"
}

for service in "$@"; do
  case "$service" in
    lab|crafty|keeper|samba|immich) services+=("$service") ;;
    -h|--help) usage; exit 0 ;;
    *) error "Unknown service: $service"; usage >&2; exit 2 ;;
  esac
done

if (( ${#services[@]} == 0 )); then
  for service in lab crafty keeper samba immich; do
    if confirm_step "Set up $service"; then
      services+=("$service")
    fi
  done
fi

if (( ${#services[@]} == 0 )); then
  info "No services selected."
  exit 0
fi

for dependency in ssh tar; do
  command -v "$dependency" >/dev/null 2>&1 || { error "$dependency is required on this client."; exit 1; }
done

ssh_options=(-o BatchMode=yes -o ConnectTimeout=5)
if ! ssh "${ssh_options[@]}" "$host" 'grep -qi bazzite /etc/os-release && test "$(id -u)" -ne 0 && command -v podman >/dev/null && command -v tar >/dev/null && command -v loginctl >/dev/null'; then
  error "SSH access to $host or Bazzite prerequisites are unavailable. Verify with: ssh $host"
  exit 1
fi

cd "$DOTFILES_ROOT"
stage="$(ssh "${ssh_options[@]}" "$host" 'mktemp -d /tmp/dotfiles-bazzite.XXXXXXXX')"
if [[ ! "$stage" =~ ^/tmp/dotfiles-bazzite\.[[:alnum:]]{8}$ ]]; then
  error "Unexpected remote staging path; refusing to continue."
  exit 1
fi

cleanup() { ssh "${ssh_options[@]}" "$host" rm -r -- "$stage" || warn "Remove remote staging directory: $stage"; }
trap cleanup EXIT

tar -cf - \
  setup/_shared.sh setup/yay.sh setup/pkg_server.sh setup/bash.sh \
  bazzite/_shared.sh bazzite/host_setup.sh \
  bazzite/lab/Dockerfile bazzite/lab/containers.conf bazzite/lab/lab.container bazzite/lab/lab-home.volume bazzite/lab/setup.sh \
  bazzite/crafty/crafty.container bazzite/crafty/setup.sh \
  bazzite/keeper/keeper.container bazzite/keeper/setup.sh \
  bazzite/samba/samba.container bazzite/samba/setup.sh \
  bazzite/immich/docker-compose.yml bazzite/immich/setup.sh \
  | ssh "${ssh_options[@]}" "$host" tar -xf - -C "$stage"

ssh "${ssh_options[@]}" "$host" bash "$stage/bazzite/host_setup.sh" "${services[@]}"
