#!/usr/bin/env bash
# Step: Install desktop / GUI packages
# Only makes sense on a machine running a graphical session (Hyprland).

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SETUP_ROOT/stages/_shared.sh"

PKG_DESKTOP=(
  # Hyprland ecosystem
  hyprland
  hyprtoolkit
  hyprpicker
  xdg-desktop-portal-hyprland
  noctalia
  kitty

  kdeconnect
  srcrpy

  # Display & hardware
  brightnessctl # usado pelo Noctalia

  # Audio
  pipewire
  pipewire-pulse
  libpulse # fornece pactl para o Audio Switcher
  bluez-utils # fornece bluetoothctl para o Audio Switcher
  noise-suppression-for-voice # RNNoise LADSPA plugin for mic denoising

  # Screenshot & screen capture
  satty
  kooha

  # File manager
  nemo
  nemo-audio-tab
  nemo-fileroller
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

)

PKG_DESKTOP_AUR=(
  aur/brave-bin
  aur/visual-studio-code-bin
  aur/specify-cli-bin
  aur/hyprdynamicmonitors-bin
)

# Omarchy already ships and configures the compositor, portal, shell, terminal,
# screenshot tooling, file manager and browser.  Keep its choices intact and
# only add applications that do not replace a native Omarchy component.
PKG_DESKTOP_OMARCHY=(
  kdeconnect
  srcrpy
  noise-suppression-for-voice
  mpv
  playerctl
  libreoffice-still
  keyd
)

PKG_DESKTOP_OMARCHY_AUR=(
  aur/specify-cli-bin
  aur/hyprmoncfg-bin # used by the crmne.hyprmoncfg Omarchy shell plugin
)

run() {
  header "Install desktop packages"

  if is_omarchy; then
    info "Omarchy detected; retaining its native desktop applications."
    info "Installing optional companion packages from official repos..."
    yay -Syu --needed --noconfirm --removemake "${PKG_DESKTOP_OMARCHY[@]}"

    info "Installing optional companion packages from the AUR..."
    yay -Syu --needed --noconfirm --removemake "${PKG_DESKTOP_OMARCHY_AUR[@]}"
    success "Omarchy companion packages installed."
    return 0
  fi

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
