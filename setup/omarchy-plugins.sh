#!/usr/bin/env bash
# Install and enable the Omarchy shell plugins used by these dotfiles.
# ~/.config/omarchy/plugins/ itself is not versioned (Omarchy-owned, see
# CLAUDE.md), so a fresh machine needs this step to get the same bar back.

set -euo pipefail

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

  # Keep the local plugin forks in sync with the versioned copies. Plugin code
  # must be copied: Omarchy does not load plugin directories through symlinks.
  local fork source target
  for fork in xonha.bar xonha.omavoice xonha.microphone-rnnoise; do
    source="$SETUP_ROOT/../omarchy/plugins/$fork"
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
  # (installed by packages-client.sh) ships the binary but does not enable the
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
