#!/usr/bin/env bash
# Step: Install CLI packages shared by Omarchy, Lab, and headless Arch hosts.

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_ROOT/_shared.sh"

# Arch extra repository.
#
# Podman replaces Docker: podman-docker provides the `docker` CLI shim (it
# conflicts with the docker package) and docker-compose is the provider used by
# `podman compose` and by projects that still call `docker-compose` directly.
PKG_SERVER_EXTRA=(
  neovim
  npm
  nvm
  opencode
  uv
  fastfetch
  ripgrep
  socat
  wget
  tmux
  lazygit
  podman
  podman-docker
  docker-compose
  lazydocker
  starship
)

# Arch User Repository.
PKG_SERVER_AUR=(
  aur/dotdrop
  aur/specify-cli-bin
)

run() {
  header "Install shared CLI packages"
  info "Installing packages from extra and AUR..."
  yay -Syu --needed --noconfirm --removemake \
    "${PKG_SERVER_EXTRA[@]}" "${PKG_SERVER_AUR[@]}"
  success "Shared CLI packages installed."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
