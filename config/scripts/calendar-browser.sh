#!/usr/bin/env bash
set -Eeuo pipefail

url="${1:-}"
calendar="${2:-}"

if [[ -z "$url" ]]; then
  echo "calendar-browser: missing URL" >&2
  exit 2
fi

# MaisTodos uses its dedicated Chrome profile. All other event links use Brave.
if [[ "${calendar,,}" == *maistodos* ]]; then
  # MaisTodos is the dedicated Chrome profile. Launch or reuse it, then ask
  # the four-zone layout to bring its window back from the per-zone stash.
  google-chrome-stable --profile-directory=Default --class=google-chrome-maistodos "$url" >/dev/null 2>&1 &
  for _ in {1..40}; do
    if hyprctl clients -j 2>/dev/null | jq -e 'any(.[]; .class == "google-chrome-maistodos")' >/dev/null; then
      "$HOME/.config/scripts/focus-notification-app.sh" google-chrome-maistodos && exit 0
    fi
    sleep 0.25
  done
  exit 0
fi

exec brave-origin --profile-directory=Default "$url"
