#!/usr/bin/env bash
# Single press toggles media; double press toggles every microphone.

set -Eeuo pipefail

DOUBLE_CLICK_SECONDS="${MEDIA_DOUBLE_CLICK_SECONDS:-0.30}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/media-play-pause-$UID"
STATE_FILE="$RUNTIME_DIR/pending"
LOCK_FILE="$RUNTIME_DIR/lock"
SELF=$(readlink -f "$0")

mkdir -p "$RUNTIME_DIR"

run_single_click() {
  local token=$1 pending_pid="" pending_token=""

  sleep "$DOUBLE_CLICK_SECONDS"
  exec 9>"$LOCK_FILE"
  flock 9

  if [[ -r "$STATE_FILE" ]]; then
    read -r pending_pid pending_token <"$STATE_FILE" || true
  fi
  [[ "$pending_token" == "$token" ]] || exit 0

  rm -f "$STATE_FILE"
  flock -u 9
  exec 9>&-
  exec noctalia msg media toggle
}

if [[ "${1:-}" == "--single" ]]; then
  run_single_click "${2:?token ausente}"
  exit
fi

exec 9>"$LOCK_FILE"
flock 9

pending_pid=""
pending_token=""
if [[ -r "$STATE_FILE" ]]; then
  read -r pending_pid pending_token <"$STATE_FILE" || true
fi

if [[ "$pending_pid" =~ ^[0-9]+$ ]] && kill -0 "$pending_pid" 2>/dev/null \
    && tr '\0' ' ' <"/proc/$pending_pid/cmdline" 2>/dev/null | grep -Fq -- "$SELF --single $pending_token"; then
  kill "$pending_pid" 2>/dev/null || true
  rm -f "$STATE_FILE"
  flock -u 9
  exec 9>&-
  exec "$HOME/.config/scripts/mic-mute.sh"
fi

rm -f "$STATE_FILE"
token="$(date +%s%N)-$$"
"$SELF" --single "$token" 9>&- >/dev/null 2>&1 &
printf '%s %s\n' "$!" "$token" >"$STATE_FILE"
