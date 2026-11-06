#!/usr/bin/env bash
# Install and enable the Omarchy shell plugins used by these dotfiles.
# ~/.config/omarchy/plugins/ itself is not versioned (Omarchy-owned, see
# CLAUDE.md), so a fresh machine needs this step to get the same bar back.

set -euo pipefail

OMARCHY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$OMARCHY_ROOT/.." && pwd)"
SETUP_ROOT="$DOTFILES_ROOT/setup"
source "$SETUP_ROOT/_shared.sh"

run() {
  header "Install Omarchy shell plugins"

  if ! command -v omarchy >/dev/null 2>&1; then
    warn "omarchy CLI not found; skipping shell plugins."
    return 0
  fi

  local plugins=(
    "https://github.com/crmne/omarchy-hyprmoncfg.git"
    "https://github.com/promaaa/sync-calendar-omarchy.git"
    "https://github.com/birajdotdev/omacore.git"
  )

  # Omacore reads each P30i earbud through the OpenSCQ30 CLI.
  if ! command -v openscq30 >/dev/null 2>&1; then
    omarchy pkg add openscq30-cli
  fi

  local repo
  for repo in "${plugins[@]}"; do
    omarchy plugin add "$repo" --enable --yes
  done

  # Use a plain bar-colored earbud glyph and hide it when disconnected.
  local omacore_dir="$HOME/.config/omarchy/plugins/io.github.birajdotdev.omacore"
  local omacore_patch="$OMARCHY_ROOT/patches/omacore_panel.patch"
  if patch --dry-run --batch -p1 -d "$omacore_dir" < "$omacore_patch" >/dev/null; then
    patch --batch -p1 -d "$omacore_dir" < "$omacore_patch"
  elif ! patch --dry-run --batch -R -p1 -d "$omacore_dir" < "$omacore_patch" >/dev/null; then
    error "Omacore panel changed upstream; review $omacore_patch before applying."
    return 1
  fi

  # promaa.clock may retain a local development path for the calendar
  # launcher. Keep its event links on the Dotfiles-managed script instead.
  local clock_panel="$HOME/.config/omarchy/plugins/promaa.clock/Panel.qml"
  if [[ -f $clock_panel ]]; then
    sed -i \
      "s|/home/henrique/Dotfiles/.config/scripts/calendar-browser.sh|$HOME/.config/scripts/calendar-browser.sh|g" \
      "$clock_panel"
  fi

  # Keep the local plugin forks in sync with the versioned copies. Plugin code
  # must be copied: Omarchy does not load plugin directories through symlinks.
  local fork source target
  for fork in xonha.bar xonha.omavoice xonha.microphone-rnnoise xonha.next-event xonha.notifications xonha.overview xonha.fingerprint xonha.lg-pl5; do
    source="$OMARCHY_ROOT/plugins/$fork"
    target="$HOME/.config/omarchy/plugins/$fork"
    if [[ -L $target ]]; then
      error "Refusing to replace symlinked plugin: $target"
      return 1
    fi
    mkdir -p "$target"
    cp -aL "$source/." "$target/"
  done
  install -m 0644 "$OMARCHY_ROOT/plugins/intelligentwolf.taskbar/Taskbar.qml" \
    "$HOME/.config/omarchy/plugins/intelligentwolf.taskbar/Taskbar.qml"
  install -m 0644 "$OMARCHY_ROOT/plugins/rtome85.audio-plus/Panel.qml" \
    "$HOME/.config/omarchy/plugins/rtome85.audio-plus/Panel.qml"
  local fingerprint_helper="$HOME/.config/omarchy/plugins/xonha.fingerprint/bin/fingerprint_device.py"
  mkdir -p "$(dirname "$fingerprint_helper")"
  install -m 0755 "$DOTFILES_ROOT/setup/fingerprint/fingerprint_device.py" "$fingerprint_helper"
  if omarchy-shell shell ping >/dev/null 2>&1; then
    omarchy-shell shell rescanPlugins
  fi

  # hyprmoncfgd watches for hotplug/lid/resume events; needed for
  # crmne.hyprmoncfg's automatic profile switching. aur/hyprmoncfg-bin
  # (installed by pkg_client.sh) ships the binary but does not enable the
  # service on its own.
  if command -v hyprmoncfgd >/dev/null 2>&1; then
    systemctl --user enable hyprmoncfgd.service
    systemctl --user restart hyprmoncfgd.service
  else
    warn "hyprmoncfgd not found; install aur/hyprmoncfg-bin first."
  fi

  success "Omarchy shell plugins installed and enabled."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
