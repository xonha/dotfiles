#!/usr/bin/env bash
# Step: Install server / headless packages
# Safe to run on both a laptop and an SSH-only cloud server.

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SETUP_ROOT/stages/_shared.sh"

PKG_SERVER=(
  # Shell & terminal tooling
  zsh
  zsh-completions
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-history-substring-search
  zsh-theme-powerlevel10k

  # Editors & language runtimes
  neovim
  npm
  nvm
  opencode
  uv

  # CLI utilities
  debugedit
  earlyoom
  fastfetch
  ripgrep
  socat
  stow
  wget
  tmux

  # Networking
  tailscale

  # Containers & git tooling
  docker
  lazygit
  lazydocker
)

run() {
  header "Install server packages"

  info "Installing packages from official repos..."
  yay -Syu --needed --noconfirm --removemake "${PKG_SERVER[@]}"

  success "Server packages installed."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
