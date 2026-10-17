#!/usr/bin/env bash
# Hyprland keeps a maximized window's old geometry when the bar first moves
# from the middle of the 4K monitor to its top edge. Reapply maximization once
# the bar has reserved its new space.
set -euo pipefail

if jq -e -s '
  .[0] as $monitors | .[1] as $window |
  any($monitors[];
    .name == "DP-1" and .id == $window.monitor and
    .reserved[1] > 0 and $window.fullscreen == 1 and
    $window.at[1] < (.y + .reserved[1]))
' <(hyprctl -j monitors) <(hyprctl -j activewindow) >/dev/null; then
  hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized" })' >/dev/null
  hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized" })' >/dev/null
fi
