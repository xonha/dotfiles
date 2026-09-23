#!/usr/bin/env bash
# Build and activate the rootless Arch development environment.

set -euo pipefail

LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_ROOT="$(cd "$LAB_ROOT/.." && pwd)"
DOTFILES_ROOT="$(cd "$SETUP_ROOT/.." && pwd)"
source "$SETUP_ROOT/_shared.sh"

SERVICES=(lab)

run() {
  header "Configure Lab development environment"

  if ! command -v podman >/dev/null 2>&1; then
    error "Podman is required on the container host."
    return 1
  fi

  local service quadlet
  for service in "${SERVICES[@]}"; do
    quadlet="$HOME/.config/containers/systemd/$service.container"
    if [[ ! -f "$quadlet" ]]; then
      error "Missing $quadlet. Apply the dotfiles with Dotdrop before running this installer."
      return 1
    fi
    mkdir -p "$HOME/$service/workspace"
  done

  info "Building localhost/lab:latest..."
  podman build \
    --file "$LAB_ROOT/Dockerfile" \
    --tag localhost/lab:latest \
    "$DOTFILES_ROOT"

  info "Reloading user units and starting development environment..."
  systemctl --user daemon-reload
  # Quadlet generators apply [Install] during daemon-reload. Generated units
  # cannot be enabled again through systemctl; restart also applies new images.
  for service in "${SERVICES[@]}"; do
    systemctl --user restart "$service.service"
  done
  loginctl enable-linger "$USER"

  success "Development environment is active. Connect with: ssh lab"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
