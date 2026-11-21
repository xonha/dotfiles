#!/usr/bin/env bash
SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_ROOT/_shared.sh"

run() {
  header "Configure RTK for coding agents"

  if ! command -v rtk >/dev/null 2>&1; then
    error "rtk not found; it is installed by mise_tools.sh."
    return 1
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
