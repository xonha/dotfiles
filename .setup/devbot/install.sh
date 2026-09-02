#!/usr/bin/env bash
# Build and activate the rootless Devbot Quadlet on the Bazzite host.

set -euo pipefail

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SETUP_ROOT/lib/ui.sh"

run() {
  header "Configure Devbot"

  if ! command -v podman >/dev/null 2>&1; then
    error "Podman is required on the container host."
    return 1
  fi

  local quadlet="$HOME/.config/containers/systemd/devbot.container"
  if [[ ! -f "$quadlet" ]]; then
    error "Missing $quadlet. Stow the dotfiles before running this installer."
    return 1
  fi

  mkdir -p "$HOME/devbot/workspace"

  info "Building localhost/devbot:latest..."
  podman build --tag localhost/devbot:latest "$SETUP_ROOT/devbot"

  info "Reloading user units and starting Devbot..."
  systemctl --user daemon-reload
  # Quadlet generators apply [Install] during daemon-reload. Generated units
  # cannot be enabled again through systemctl; restart also applies new images.
  systemctl --user restart devbot.service
  loginctl enable-linger "$USER"

  success "Devbot is enabled. Connect with: ssh devbot"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
