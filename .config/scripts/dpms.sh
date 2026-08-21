#!/usr/bin/env bash
# ~/.config/scripts/dpms.sh on|off|toggle
#
# Liga/desliga as telas via Hyprland. Existe porque a partir do Hyprland 0.55
# (config em lua) `hyprctl dispatch` recebe lua em vez do nome do dispatcher
# antigo, e essa sintaxe tem chaves/aspas que sao chatas de escapar dentro do
# hypridle.conf.

set -euo pipefail

ACTION="${1:-toggle}"

case "$ACTION" in
on | off | toggle) ;;
*)
  echo "usage: ${0##*/} on|off|toggle" >&2
  exit 1
  ;;
esac

exec hyprctl dispatch "hl.dsp.dpms({ action = \"$ACTION\" })"
