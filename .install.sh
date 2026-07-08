#!/usr/bin/env bash
# Interactive setup orchestrator.
# Safe to run on both a desktop and an SSH-only server.

set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.setup"
source "$SETUP_DIR/lib.sh"

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

printf "${BOLD}${BLUE}"
printf "╔══════════════════════════════════════╗\n"
printf "║         Henrique's Setup Script      ║\n"
printf "╚══════════════════════════════════════╝\n"
printf "${RESET}\n"

# ── yay ───────────────────────────────────────────────────────────────────
source "$SETUP_DIR/yay.sh"
run

# ── Dotfiles ──────────────────────────────────────────────────────────────
source "$SETUP_DIR/dotfiles.sh"
run

# ── Server packages ───────────────────────────────────────────────────────
source "$SETUP_DIR/server.sh"
run

# ── Desktop packages (optional) ───────────────────────────────────────────
if confirm_step \
    "Install desktop packages" \
    "GUI stack: Hyprland, Waybar, Kitty, Brave, VS Code, nemo, pipewire, etc.
  Skip this on headless / SSH-only machines."; then
  source "$SETUP_DIR/desktop.sh"
  run

  # ── Nemo sidebar (XDG folders, bookmarks, icons) ────────────────────────
  source "$SETUP_DIR/nemo.sh"
  run
fi

# ── GRUB ──────────────────────────────────────────────────────────────────
source "$SETUP_DIR/grub.sh"
run

# ── Services ──────────────────────────────────────────────────────────────
source "$SETUP_DIR/services.sh"
run

# ── Uninstall legacy packages ─────────────────────────────────────────────
source "$SETUP_DIR/uninstall.sh"
run

# ── keyd ──────────────────────────────────────────────────────────────────
source "$SETUP_DIR/keyd.sh"
run

# ── Done ──────────────────────────────────────────────────────────────────
printf "\n${BOLD}${GREEN}All selected steps completed.${RESET}\n"
printf "You may need to ${BOLD}log out and back in${RESET} for group changes to take effect.\n\n"
