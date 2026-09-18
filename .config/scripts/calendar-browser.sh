#!/usr/bin/env bash
set -Eeuo pipefail

label="${CALENDAR_FEED_LABEL:-Personal}"
url="${1:-}"

if [[ -z "$url" ]]; then
  echo "calendar-browser: missing URL" >&2
  exit 2
fi

case "$label" in
  MaisTodos)
    exec brave-origin \
      --profile-directory=brave-origin-maistodos \
      --class=brave-origin-maistodos \
      --user-data-dir=.brave-origin-maistodos \
      "$url"
    ;;
  Devbot)
    exec brave-origin \
      --profile-directory=brave-origin-devbot \
      --class=brave-origin-devbot \
      --user-data-dir=.brave-origin-devbot \
      "$url"
    ;;
  Personal|*)
    exec brave-origin --profile-directory=Default "$url"
    ;;
esac
