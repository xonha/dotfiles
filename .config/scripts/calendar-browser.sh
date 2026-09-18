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
      --profile-directory="Profile 1" \
      --class=brave-origin-maistodos \
      "$url"
    ;;
  devbot)
    exec brave-origin \
      --profile-directory="Profile 2" \
      --class=brave-origin-devbot \
      "$url"
    ;;
  personal|*)
    exec brave-origin --profile-directory=Default "$url"
    ;;
esac
