#!/usr/bin/env bash
SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_ROOT/_shared.sh"

# Install the tools declared in the user's global mise config
# (config/mise/config.toml, linked by dotfiles.sh on Omarchy).
run() {
  header "Install mise tools"
  if ! command -v mise >/dev/null 2>&1; then
    error "mise is required to install tools."
    return 1
  fi
  mise install
  success "mise tools installed."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
