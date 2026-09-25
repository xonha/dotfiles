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
  )

  local repo
  for repo in "${plugins[@]}"; do
    omarchy plugin add "$repo" --enable --yes
  done

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
  for fork in xonha.bar xonha.omavoice xonha.microphone-rnnoise xonha.next-event; do
    source="$OMARCHY_ROOT/plugins/$fork"
    target="$HOME/.config/omarchy/plugins/$fork"
    if [[ -L $target ]]; then
      error "Refusing to replace symlinked plugin: $target"
      return 1
    fi
    mkdir -p "$target"
    cp -aL "$source/." "$target/"
  done
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
