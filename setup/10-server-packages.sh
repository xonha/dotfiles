#!/usr/bin/env bash
# Step: Install server / headless packages
# Safe to run on both a laptop and an SSH-only cloud server.

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_ROOT/_shared.sh"
source "$SETUP_ROOT/_packages.sh"

run() {
  header "Install server packages"

  info "Installing packages from official repos..."
  local packages=("${PKG_DEV_COMMON[@]}")
  if [[ "${SETUP_TARGET:-host}" == "host" ]]; then
    packages+=("${PKG_HOST_ONLY[@]}")
  else
    info "Skipping host-only packages for target: ${SETUP_TARGET}"
  fi

  yay -Syu --needed --noconfirm --removemake "${packages[@]}"

  success "Server packages installed."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
