#!/usr/bin/env bash
set -euo pipefail

data="$HOME/.local/share/jarvis"
dest="${JARVIS_BACKUP_DIR:-$HOME/.local/share/jarvis-backups}"
keep="${JARVIS_BACKUP_KEEP:-14}"
stage="$(mktemp -d)"
restart_music=""
cleanup() {
  [[ -z "$restart_music" ]] || systemctl --user start music-assistant.service
  rm -rf "$stage"
}
trap cleanup EXIT

# Music Assistant opens its SQLite files with an exclusive lock, so they can only
# be read while it is stopped; the copy takes a few seconds.
if systemctl --user is-active -q music-assistant.service; then
  restart_music=1
  systemctl --user stop music-assistant.service
fi

# Whisper and Piper models are downloaded again on start; caches and logs are disposable.
rsync -a \
  --exclude='/wyoming-*/' \
  --exclude='/homeassistant/.cache/' \
  --exclude='/homeassistant/backups/' \
  --exclude='/homeassistant/tts/' \
  --exclude='/homeassistant/home-assistant.log*' \
  --exclude='/homeassistant/home-assistant_v2.db*' \
  --exclude='/music-assistant/.cache/' \
  "$data/" "$stage/jarvis/"

if [[ -n "$restart_music" ]]; then
  systemctl --user start music-assistant.service
  restart_music=""
fi

# Home Assistant keeps writing its history while running; a copy of the live file
# can capture a half-written page, so take a consistent SQLite snapshot instead.
if [[ -f "$data/homeassistant/home-assistant_v2.db" ]]; then
  python3 -c 'import sqlite3, sys; src = sqlite3.connect(sys.argv[1], timeout=30); dst = sqlite3.connect(sys.argv[2]); src.backup(dst); dst.close(); src.close()' \
    "$data/homeassistant/home-assistant_v2.db" "$stage/jarvis/homeassistant/home-assistant_v2.db"
fi

mkdir -p "$dest"
archive="$dest/jarvis-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -C "$stage" -czf "$archive.partial" jarvis
mv "$archive.partial" "$archive"
echo "$archive"

ls -1t "$dest"/jarvis-*.tar.gz | tail -n +"$((keep + 1))" | xargs -r rm --
