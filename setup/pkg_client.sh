#!/usr/bin/env bash
SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_ROOT/_shared.sh"

# Podman itself comes from the shared CLI stage. docker-buildx gives Compose a
# BuildKit builder (see the services step); without it Compose falls back to
# the classic builder, which lacks build ssh.
PKG_CLIENT_EXTRA=(
  kdeconnect
  scrcpy
  noise-suppression-for-voice
  mpv
  playerctl
  earlyoom
  tailscale
  docker-buildx
  google-chrome
  microsoft-edge-stable-bin
)

PKG_CLIENT_AUR=(
  aur/hyprmoncfg-bin # Used by the crmne.hyprmoncfg shell plugin.
)

run() {
  header "Install client packages"
  info "Installing packages from extra and AUR..."
  yay -Syu --needed --noconfirm --removemake \
    "${PKG_CLIENT_EXTRA[@]}" "${PKG_CLIENT_AUR[@]}"
  success "Client packages installed."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
