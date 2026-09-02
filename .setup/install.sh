#!/usr/bin/env bash
# Interactive setup orchestrator.
# Safe to run on both a desktop and an SSH-only server.

set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_DIR/stages/_shared.sh"

printf "${BOLD}${BLUE}"
printf "╭──────────────────────────────────────╮\n"
printf "│         Henrique's Setup Script      │\n"
printf "╰──────────────────────────────────────╯\n"
printf "${RESET}\n"

source "$SETUP_DIR/stages/10-bootstrap-yay.sh"
run

source "$SETUP_DIR/stages/20-dotfiles.sh"
run

source "$SETUP_DIR/stages/30-server-packages.sh"
run

# Configure the login shell only after Zsh has been installed.
source "$SETUP_DIR/stages/40-login-shell.sh"
run

if confirm_step \
    "Install desktop packages" \
    "GUI stack: Hyprland, Noctalia, Kitty, Brave, VS Code, Nemo, PipeWire, etc.
  Skip this on headless / SSH-only machines."; then
  source "$SETUP_DIR/stages/50-desktop.sh"
  run

  if confirm_step \
      "Configure ThinkPad monitor profile" \
      "HyprDynamicMonitors, lid-closed policy and the USB-C hub layout for this ThinkPad."; then
    source "$SETUP_DIR/desktop/thinkpad_t495/monitors.sh"
    run
  fi
fi

source "$SETUP_DIR/stages/60-services.sh"
run

printf "\n${BOLD}${GREEN}All selected steps completed.${RESET}\n"
printf "You may need to ${BOLD}log out and back in${RESET} for group changes to take effect.\n\n"
