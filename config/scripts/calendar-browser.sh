#!/usr/bin/env bash
set -Eeuo pipefail

url="${1:-}"

if [[ -z "$url" ]]; then
  echo "calendar-browser: missing URL" >&2
  exit 2
fi

# Both calendar widgets pass the source calendar as an optional second argument.
# Open every calendar and meeting link in Brave, regardless of its source.
exec brave-origin --profile-directory=Default "$url"
