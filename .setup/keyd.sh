#!/usr/bin/env bash
# Step: Install keyd config

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_DIR/lib.sh"

POLKIT_RULE="/etc/polkit-1/rules.d/49-keyd-nopasswd.rules"

run() {
  header "Configure keyd"
  local dotfiles_dir
  dotfiles_dir="$(cd "$SETUP_DIR/.." && pwd)"
  sudo cp "$dotfiles_dir/.keyd.conf" /etc/keyd/default.conf
  success "keyd config installed."

  # dock-handler.sh toggles keyd on (un)dock; without this it prompts for a
  # password on every state change.
  info "Installing polkit rule so $USER can start/stop keyd without a password..."
  sudo install -Dm644 /dev/stdin "$POLKIT_RULE" \
    < <(sed "s/__USER__/$USER/" "$SETUP_DIR/keyd-nopasswd.rules")
  success "polkit rule installed at $POLKIT_RULE."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
