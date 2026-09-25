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
    exec google-chrome-stable \
      --profile-directory=Default \
      --class=google-chrome-maistodos \
      "$url"
    ;;
  devbot)
    exec microsoft-edge-stable \
      --profile-directory=Default \
      --class=microsoft-edge-devbot \
      "$url"
    ;;
  personal|*)
    exec brave-origin --profile-directory=Default "$url"
    ;;
esac
