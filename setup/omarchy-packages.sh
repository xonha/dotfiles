#!/usr/bin/env bash
# Step: Install Omarchy client packages beyond its native desktop defaults.

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_ROOT/_shared.sh"

# Arch extra repository: desktop applications and host services.
#
# Podman replaces Docker: podman-docker provides the `docker` CLI shim (it
# conflicts with the docker package) and docker-compose is the provider used by
# `podman compose` and by projects that still call `docker-compose` directly.
# docker-buildx gives Compose a BuildKit builder (see the services step);
# without it Compose falls back to the classic builder, which lacks build ssh.
PKG_OMARCHY_EXTRA=(
  kdeconnect
  scrcpy
  noise-suppression-for-voice
  mpv
  playerctl
  libreoffice-still
  earlyoom
  tailscale
  podman
  podman-docker
  docker-compose
  docker-buildx
)

# Arch User Repository.
PKG_OMARCHY_AUR=(
  aur/hyprmoncfg-bin # Used by the crmne.hyprmoncfg Omarchy shell plugin.
  aur/podman-tui-bin # Talks to the local Podman engine, so it stays host-only.
)

run() {
  header "Install Omarchy client packages"
  info "Installing packages from extra and AUR..."
  yay -Syu --needed --noconfirm --removemake \
    "${PKG_OMARCHY_EXTRA[@]}" "${PKG_OMARCHY_AUR[@]}"
  success "Omarchy client packages installed."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
