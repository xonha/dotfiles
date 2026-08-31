#!/usr/bin/env bash
# Step: Bootstrap yay (AUR helper)

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_DIR/lib.sh"

run() {
  header "Bootstrap yay"

  if command -v yay >/dev/null 2>&1; then
    success "yay already installed; skipping bootstrap."
    return 0
  fi

  info "Updating keyring..."
  sudo pacman -Sy --needed --noconfirm archlinux-keyring

  info "Installing yay build dependencies..."
  sudo pacman -S --needed --noconfirm git base-devel

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  info "Cloning yay into $tmp_dir..."
  git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"

  pushd "$tmp_dir/yay" >/dev/null
  makepkg -si --noconfirm
  popd >/dev/null

  rm -rf "$tmp_dir"
  success "yay installed."
}

# Allow sourcing without running (used by the orchestrator)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
