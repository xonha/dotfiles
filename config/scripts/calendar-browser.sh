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
  # Keep Chrome's normal WM class so Hyprland tiles it instead of treating it
  # as the MaisTodos app window; the Default Chrome profile remains MaisTodos.
  exec google-chrome-stable --profile-directory=Default "$url"
fi

exec brave-origin --profile-directory=Default "$url"
