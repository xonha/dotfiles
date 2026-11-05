#!/usr/bin/env bash
set -euo pipefail

device=/org/bluez/hci0/dev_C4_30_18_9C_96_75

if [[ $(busctl --system get-property org.bluez "$device" org.bluez.Device1 Connected 2>/dev/null || true) != 'b true' ]]; then
  printf '{"connected":false,"percent":-1}\n'
  exit 0
fi

battery=$(busctl --system get-property org.bluez "$device" org.bluez.Battery1 Percentage 2>/dev/null || true)
if [[ $battery =~ ^y[[:space:]]+([0-9]+)$ ]] && (( ${BASH_REMATCH[1]} <= 100 )); then
  printf '{"connected":true,"percent":%d}\n' "${BASH_REMATCH[1]}"
else
  # The PL5 may keep a Bluetooth control link after its audio and battery
  # interfaces disappear. Treat that state as disconnected in the bar.
  printf '{"connected":false,"percent":-1}\n'
fi
