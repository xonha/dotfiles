#!/usr/bin/env bash
# Step: Install client packages beyond the native desktop defaults.

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_ROOT/_shared.sh"

# Arch extra repository: desktop applications and host services.
#
# Podman itself comes from the shared CLI stage. docker-buildx gives Compose a
# BuildKit builder (see the services step); without it Compose falls back to
# the classic builder, which lacks build ssh.
PKG_CLIENT_EXTRA=(
  kdeconnect
  scrcpy
  noise-suppression-for-voice
  mpv
  playerctl
  libreoffice-still
  earlyoom
  tailscale
  docker-buildx
)

# Arch User Repository. These packages are client-side but not Omarchy-specific.
PKG_CLIENT_AUR=(
  aur/hyprmoncfg-bin # Used by the crmne.hyprmoncfg shell plugin.
  aur/podman-tui-bin # Talks to the local Podman engine, so it stays host-only.
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
