#!/usr/bin/env bash
## Toggle mic noise suppression (RNNoise via PipeWire filter-chain).
##   denoise.sh [toggle|on|off]   (default: toggle)
## Switches the default source between the RNNoise virtual mic and the raw
## Bluetooth headset mic. The filter-chain itself is always loaded by PipeWire
## (see ~/.config/pipewire/pipewire.conf.d/99-rnnoise.conf).

RNNOISE="effect_output.rnnoise"
notify='notify-send -h string:x-canonical-private-synchronous:denoise -u low'
action="${1:-toggle}"

find_raw_source() {
  local configured="${DENOISE_RAW_SOURCE:-}"
  local pipewire_config="${XDG_CONFIG_HOME:-$HOME/.config}/pipewire/pipewire.conf.d/99-rnnoise.conf"

  if [[ -z "$configured" && -r "$pipewire_config" ]]; then
    configured=$(awk -F '"' '/target\.object/ { print $2; exit }' "$pipewire_config")
  fi

  if [[ -n "$configured" ]] && pactl list short sources | cut -f2 | grep -Fxq "$configured"; then
    printf '%s\n' "$configured"
    return
  fi

  # Prefer a Bluetooth microphone, then any physical ALSA capture source.
  pactl list short sources | awk '
    $2 ~ /^bluez_input\./ { print $2; exit }
    $2 ~ /^alsa_input\./ && !fallback { fallback = $2 }
    END { if (fallback) print fallback }
  ' | head -n1
}

[ "$action" = "toggle" ] && {
  [ "$(pactl get-default-source)" = "$RNNOISE" ] && action="off" || action="on"
}

case "$action" in
  on)
    pactl set-default-source "$RNNOISE" && $notify "Supressao de ruido: ON"
    ;;
  off)
    RAW=$(find_raw_source)
    [[ -n "$RAW" ]] || { echo "nenhum microfone fisico encontrado" >&2; exit 1; }
    pactl set-default-source "$RAW" && $notify "Supressao de ruido: OFF"
    ;;
  *)   echo "uso: $0 [toggle|on|off]" >&2; exit 1 ;;
esac
