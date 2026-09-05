#!/usr/bin/env bash
# Install and enable the Omarchy shell plugins used by these dotfiles.
# ~/.config/omarchy/plugins/ itself is not versioned (Omarchy-owned, see
# CLAUDE.md), so a fresh machine needs this step to get the same bar back.

set -euo pipefail

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SETUP_ROOT/stages/_shared.sh"

run() {
  header "Install Omarchy shell plugins"

  if ! command -v omarchy >/dev/null 2>&1; then
    warn "omarchy CLI not found; skipping shell plugins."
    return 0
  fi

  local plugins=(
    "https://github.com/crmne/omarchy-hyprmoncfg.git"
  )

  local repo
  for repo in "${plugins[@]}"; do
    omarchy plugin add "$repo" --enable --yes
  done

  # hyprmoncfgd watches for hotplug/lid/resume events; needed for
  # crmne.hyprmoncfg's automatic profile switching. aur/hyprmoncfg-bin
  # (installed by packages.sh) ships the binary but does not enable the
  # service on its own.
  if command -v hyprmoncfgd >/dev/null 2>&1; then
    systemctl --user enable hyprmoncfgd.service
    systemctl --user restart hyprmoncfgd.service
  else
    warn "hyprmoncfgd not found; install aur/hyprmoncfg-bin first."
  fi

  # omarchy-shell (and some bar plugins) write shell.json via an atomic
  # rename, which replaces its Stow symlink with a real file. This watcher
  # re-syncs the content back into the repo and restows whenever that
  # happens, instead of it silently drifting out of version control.
  info "Enabling shell.json symlink guard..."
  systemctl --user daemon-reload
  systemctl --user enable --now omarchy-shell-json-guard.service

  success "Omarchy shell plugins installed and enabled."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
