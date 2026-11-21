#!/usr/bin/env bash
SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_ROOT/_shared.sh"

# Podman replaces Docker: podman-docker provides the `docker` CLI shim (it
# conflicts with the docker package) and docker-compose is the provider used by
# `podman compose` and by projects that still call `docker-compose` directly.
PKG_SERVER_EXTRA=(
  neovim
  opencode
  uv
  go
  rustup
  fastfetch
  ripgrep
  socat
  wget
  tmux
  lazygit
  podman
  podman-docker
  docker-compose
  starship
  jq
  aria2
  pass
)

PKG_SERVER_AUR=(
  aur/specify-cli-bin
  aur/rtk-bin
)

# Node comes from mise for every user, in place of nvm. The system config and
# install directory belong to the machine, so a persistent home volume (Lab's
# lab-home) does not hide them when the image is rebuilt, and `npm install -g`
# still installs into each user's ~/.local. Callable on its own:
#   source setup/pkg_server.sh && install_system_node
install_system_node() {
  info "Installing Node with mise for all users..."
  sudo install -d /etc/mise
  sudo touch /etc/mise/config.toml
  sudo -H mise config set --file /etc/mise/config.toml tools.node 26
  sudo -H mise config set --file /etc/mise/config.toml env.NPM_CONFIG_PREFIX '{{ env.HOME }}/.local'
  sudo -H mise install --system node
}

run() {
  local -a packages=("${PKG_SERVER_EXTRA[@]}") aur=("${PKG_SERVER_AUR[@]}")
  local package
  if command -v omarchy >/dev/null 2>&1; then
    # Omarchy installs these through mise (config/mise/config.toml).
    packages=()
    for package in "${PKG_SERVER_EXTRA[@]}"; do
      case "$package" in
        opencode|uv|go) continue ;;
      esac
      packages+=("$package")
    done
    aur=()
    for package in "${PKG_SERVER_AUR[@]}"; do
      case "$package" in
        aur/rtk-bin|aur/specify-cli-bin) continue ;;
      esac
      aur+=("$package")
    done
  fi
  if ! command -v mise >/dev/null 2>&1; then
    packages+=(mise)
  fi
  header "Install shared CLI packages"
  info "Installing packages from extra and AUR..."
  yay -Syu --needed --noconfirm --removemake \
    "${packages[@]}" "${aur[@]}"
  if ! command -v omarchy >/dev/null 2>&1; then
    info "Installing the stable Rust toolchain..."
    rustup default stable
    install_system_node
  fi
  success "Shared CLI packages installed."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
