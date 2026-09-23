#!/usr/bin/env bash
# Interactive setup orchestrator.
# Safe to run on both a desktop and an SSH-only server.

set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_DIR/_shared.sh"

printf "${BOLD}${BLUE}"
printf "╭──────────────────────────────────────╮\n"
printf "│         Henrique's Setup Script      │\n"
printf "╰──────────────────────────────────────╯\n"
printf "${RESET}\n"

run_module() {
  local module="$1"
  source "$SETUP_DIR/$module"
  run
}

run_module packages-server.sh

# Dotdrop is provided by the server package stage above.
run_module dotfiles.sh

# Configure the login shell after the shell packages are installed.
run_module login-shell.sh

if is_omarchy && confirm_step \
    "Install Omarchy client packages and plugins" \
    "Keeps Omarchy's native desktop and adds the client applications and shell plugins.
  Skip this on headless machines."; then
  run_module packages-client.sh
  run_module omarchy-plugins.sh
fi

run_module services.sh

printf "\n${BOLD}${GREEN}All selected steps completed.${RESET}\n"
printf "You may need to ${BOLD}log out and back in${RESET} for group changes to take effect.\n\n"
