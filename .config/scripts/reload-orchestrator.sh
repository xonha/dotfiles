#!/usr/bin/env bash
# Reload orchestrator: recovers pieces of session state that can drift or
# break silently (e.g. a Dotfiles edit a hot-reload watcher never saw).
#
# To extend: write a reload_<name> function and add <name> to TARGETS below.
# Each function should return non-zero on failure instead of exiting the
# script, so one broken target does not stop the others from running.

set -Eeuo pipefail

reload_omarchy_shell() {
  local shell_json="$HOME/.config/omarchy/shell.json"

  # omarchy-shell watches ~/.config/omarchy/shell.json for changes via
  # inotify, but that watch only fires on writes to that exact path. It's a
  # Stow symlink into the Dotfiles repo; editing the repo copy directly
  # writes to a different directory entry, so the watch never sees it and
  # the bar never hot-reloads. Restarting the shell re-reads the file from
  # disk instead of relying on the watch.
  if ! jq empty "$shell_json" 2>/dev/null; then
    echo "shell.json invalido, pulando restart" >&2
    return 1
  fi

  omarchy restart shell
}

TARGETS=(
  omarchy_shell
)

failed=()
for target in "${TARGETS[@]}"; do
  if ! "reload_${target}"; then
    failed+=("$target")
  fi
done

if ((${#failed[@]} > 0)); then
  omarchy osd -m "Reload falhou: ${failed[*]}"
  exit 1
fi

omarchy osd -m "Estado recarregado: ${TARGETS[*]}"
