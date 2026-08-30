#!/usr/bin/env bash
# Step: Install desktop / GUI packages
# Only makes sense on a machine running a graphical session (Hyprland).

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_DIR/lib.sh"

PKG_DESKTOP=(
  # Hyprland ecosystem
  hyprland
  hyprtoolkit
  hyprpicker
  xdg-desktop-portal-hyprland
  noctalia

  # Display & hardware
  brightnessctl # usado pelo Noctalia

  # Audio
  pipewire
  pipewire-pulse
  noise-suppression-for-voice # RNNoise LADSPA plugin for mic denoising

  # Screenshot & screen capture
  satty
  kooha

  # File manager
  nemo
  nemo-audio-tab
  nemo-fileroller
  nemo-preview
  nemo-python

  # Media
  mpv
  playerctl

  # Productivity
  libreoffice-still

  # Keyboard
  keyd

  # Clipboard
  wl-clipboard

  # Fonts
  ttf-jetbrains-mono-nerd

  # Theming
  papirus-folders-catppuccin-git

  # Container & misc
  docker
)

PKG_DESKTOP_AUR=(
  aur/brave-bin
  aur/visual-studio-code-bin
  aur/pinta
  aur/valent

  # Spec Kit — spec-driven development CLI (uses uv from server step)
  aur/specify-cli-bin

)

run() {
  header "Install desktop packages"

  info "Installing packages from official repos..."
  yay -Syu --needed --noconfirm --removemake "${PKG_DESKTOP[@]}"

  info "Installing AUR packages..."
  yay -Syu --needed --noconfirm --removemake "${PKG_DESKTOP_AUR[@]}"

  info "Setting up Papirus folder theme..."
  papirus-folders -C cat-mocha-red --theme Papirus-Dark
  success "Papirus folders configured."

  success "Desktop packages installed."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
