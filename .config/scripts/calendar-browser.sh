#!/usr/bin/env bash
set -Eeuo pipefail

label="${2:-${CALENDAR_FEED_LABEL:-Personal}}"
label="${label//[[:space:]]/}"
label="${label,,}"
url="${1:-}"

if [[ -z "$url" ]]; then
  echo "calendar-browser: missing URL" >&2
  exit 2
fi

case "$label" in
  maistodos)
    exec brave-origin \
      --profile-directory=Default \
      --class=brave-origin-maistodos \
      --user-data-dir="$HOME/.config/BraveSoftware/Brave-Origin-MaisTodos" \
      "$url"
    ;;
  devbot)
    exec brave-origin \
      --profile-directory=Default \
      --class=brave-origin-devbot \
      --user-data-dir="$HOME/.config/BraveSoftware/Brave-Origin-Devbot" \
      "$url"
    ;;
  personal|*)
    exec brave-origin --profile-directory=Default "$url"
    ;;
esac
