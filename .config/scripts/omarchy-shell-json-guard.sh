#!/usr/bin/env bash
# Watches ~/.config/omarchy/ for shell.json losing its Stow symlink.
#
# omarchy-shell (and some third-party bar plugins) write shell.json via an
# atomic rename over the existing path. When that path is a symlink into the
# Dotfiles repo, the rename replaces the symlink itself with a real file,
# silently detaching it from version control. This re-syncs the live content
# back into the repo and restows whenever that happens.

set -euo pipefail

WATCH_DIR="$HOME/.config/omarchy"
LIVE="$WATCH_DIR/shell.json"
REPO="$HOME/Dotfiles/.config/omarchy/shell.json"
DOTFILES_DIR="$HOME/Dotfiles"

resync_if_needed() {
  [ -e "$LIVE" ] || return 0
  [ -L "$LIVE" ] && return 0 # still a symlink, nothing to do

  cp "$LIVE" "$REPO"
  rm "$LIVE"
  (cd "$DOTFILES_DIR" && stow .)

  command -v omarchy-notification-send >/dev/null 2>&1 &&
    omarchy-notification-send -u low "Dotfiles" "shell.json re-linked into the Stow repo" || true
}

# Catch a break that already happened before this service started.
resync_if_needed

inotifywait -m -e close_write -e moved_to -e create --format '%f' "$WATCH_DIR" |
  while read -r file; do
    [ "$file" = "shell.json" ] && resync_if_needed
  done
