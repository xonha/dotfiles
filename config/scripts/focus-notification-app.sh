#!/bin/bash
set -euo pipefail

app=${1:?Application name required}
address=$(hyprctl clients -j | jq -r --arg pattern "$app" '
  def matches($value): ($value // "") | test($pattern; "i");
  sort_by(.focusHistoryID) |
  first(
    (.[] | select(matches(.class))),
    (.[] | select(.initialClass == "org.omarchy.agent" and matches(.initialTitle)))
  ).address // empty')
[[ -n $address ]] || exit 1
[[ $address =~ ^0x[[:xdigit:]]+$ ]] || exit 1

hyprctl eval "require('hypr.four_zones').focus_window('$address')" >/dev/null
