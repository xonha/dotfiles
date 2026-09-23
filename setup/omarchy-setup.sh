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

source "$SETUP_DIR/10-server-packages.sh"
run

# Dotdrop is provided by the server package stage above.
source "$SETUP_DIR/20-dotfiles.sh"
run

# Configure the login shell after the shell packages are installed.
source "$SETUP_DIR/30-login-shell.sh"
run

if is_omarchy && confirm_step \
    "Install Omarchy client packages and plugins" \
    "Keeps Omarchy's native desktop and adds the client applications and shell plugins.
  Skip this on headless machines."; then
  source "$SETUP_DIR/40-omarchy.sh"
  run
fi

source "$SETUP_DIR/50-services.sh"
run

printf "\n${BOLD}${GREEN}All selected steps completed.${RESET}\n"
printf "You may need to ${BOLD}log out and back in${RESET} for group changes to take effect.\n\n"
