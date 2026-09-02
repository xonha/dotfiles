#!/usr/bin/env bash
# Build and activate the shared rootless Arch development environments.

set -euo pipefail

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SETUP_ROOT/stages/_shared.sh"

SERVICES=(devbot lab)

run() {
  header "Configure Toolbox development environments"

  if ! command -v podman >/dev/null 2>&1; then
    error "Podman is required on the container host."
    return 1
  fi

  local service quadlet
  for service in "${SERVICES[@]}"; do
    quadlet="$HOME/.config/containers/systemd/$service.container"
    if [[ ! -f "$quadlet" ]]; then
      error "Missing $quadlet. Stow the dotfiles before running this installer."
      return 1
    fi
    mkdir -p "$HOME/$service/workspace"
  done

  info "Building localhost/toolbox:latest..."
  podman build --tag localhost/toolbox:latest "$SETUP_ROOT/toolbox"

  info "Reloading user units and starting development environments..."
  systemctl --user daemon-reload
  # Quadlet generators apply [Install] during daemon-reload. Generated units
  # cannot be enabled again through systemctl; restart also applies new images.
  for service in "${SERVICES[@]}"; do
    systemctl --user restart "$service.service"
  done
  loginctl enable-linger "$USER"

  success "Development environments are active. Connect with: ssh devbot / ssh lab"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
