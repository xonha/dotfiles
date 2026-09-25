#!/usr/bin/env bash
# Step: Configure RTK integrations for supported coding agents.

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_ROOT/_shared.sh"

run() {
  header "Configure RTK for coding agents"

  if pacman -Q rtk-bin >/dev/null 2>&1; then
    info "RTK package is already installed."
  else
    info "Installing the RTK package from AUR..."
    yay -S --needed --noconfirm aur/rtk-bin
  fi

  info "Installing the global Claude Code hook and RTK instructions..."
  rtk init -g --auto-patch

  info "Installing the global Codex hook and RTK instructions..."
  rtk init -g --codex

  info "Installing the global OpenCode plugin..."
  rtk init -g --opencode

  success "RTK configured for Claude Code, Codex, and OpenCode."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
