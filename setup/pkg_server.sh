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

# Extra mise tools saved by the add command.
PKG_SERVER_MISE=(
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
  local -a packages=("${PKG_SERVER_EXTRA[@]}")
  local package
  if command -v omarchy >/dev/null 2>&1; then
    packages=()
    for package in "${PKG_SERVER_EXTRA[@]}"; do
      case "$package" in
        opencode|uv|go) continue ;;
      esac
      packages+=("$package")
    done
  fi
  if ! command -v mise >/dev/null 2>&1; then
    packages+=(mise)
  fi
  header "Install shared CLI packages"
  info "Installing packages from extra and AUR..."
  yay -Syu --needed --noconfirm --removemake \
    "${packages[@]}" "${PKG_SERVER_AUR[@]}"
  if command -v omarchy >/dev/null 2>&1; then
    info "Installing development tools with mise..."
    mise use -g go@1.27 ruby@3.4 rust@stable npm:wrangler@4
    # Node supplies npm. Preserve the user's existing release-age and lazy settings.
    mise use -g --tool-option minimum_release_age=0s --tool-option lazy=true node@26
    # The Go backend needs the mise-managed Go on PATH in non-interactive shells.
    mise exec -- mise use -g 'go:github.com/wailsapp/wails/v3/cmd/wails3@3.1.0'
  else
    info "Installing the stable Rust toolchain..."
    rustup default stable
    install_system_node
  fi
  if ((${#PKG_SERVER_MISE[@]})); then
    if ! command -v mise >/dev/null 2>&1; then
      yay -S --needed --noconfirm mise
    fi
    mise exec -- mise use -g "${PKG_SERVER_MISE[@]}"
  fi
  success "Shared CLI packages installed."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
