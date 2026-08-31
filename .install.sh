#!/usr/bin/env bash
# Interactive setup orchestrator.
# Safe to run on both a desktop and an SSH-only server.

set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.setup"
source "$SETUP_DIR/lib.sh"

printf "${BOLD}${BLUE}"
printf "╭──────────────────────────────────────╮\n"
printf "│         Henrique's Setup Script      │\n"
printf "╰──────────────────────────────────────╯\n"
printf "${RESET}\n"

source "$SETUP_DIR/yay.sh"
run

source "$SETUP_DIR/dotfiles.sh"
run

source "$SETUP_DIR/server.sh"
run

# Configure the login shell only after Zsh has been installed.
source "$SETUP_DIR/shell.sh"
run

if confirm_step \
    "Install desktop packages" \
    "GUI stack: Hyprland, Noctalia, Kitty, Brave, VS Code, Nemo, PipeWire, etc.
  Skip this on headless / SSH-only machines."; then
  source "$SETUP_DIR/desktop.sh"
  run

  source "$SETUP_DIR/desktop/nemo.sh"
  run

  source "$SETUP_DIR/desktop/keyd.sh"
  run
fi

source "$SETUP_DIR/services.sh"
run

printf "\n${BOLD}${GREEN}All selected steps completed.${RESET}\n"
printf "You may need to ${BOLD}log out and back in${RESET} for group changes to take effect.\n\n"
