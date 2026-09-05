#!/usr/bin/env bash
# ~/.config/scripts/dock-handler.sh
# Unified dock handler: applies the right monitor layout for dock state.
# Uses polling to detect dock state

set -Eeuo pipefail

DOCK_USB_ID="${DOCK_USB_ID:-0bda:8152}"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/dock-handler-state"

# Hyprland >= 0.55 com config em lua: `hyprctl keyword` nao existe mais
# ("keyword can't work with non-legacy parsers. Use eval."). O equivalente e
# rodar hl.monitor() via `hyprctl eval`.
set_monitor() {
  hyprctl eval "hl.monitor({ $1 })" >/dev/null
}

apply_dock() {
  echo "Applying docked configuration..."
  notify-send "Dock" "Applying docked configuration" -u low
  set_monitor 'output = "eDP-1", disabled = true'
  set_monitor 'output = "desc:Shenzhen KTC Technology Group SFPCCB24180 000000000000", mode = "1920x1080@120", position = "0x0", scale = 1.0, transform = 0, vrr = 0'
  set_monitor 'output = "desc:SUE SFP2412FHD 000000000000", mode = "1920x1080@120", position = "1920x0", scale = 1.0, transform = 0, vrr = 0'
  echo "docked" >"$STATE_FILE"
}

apply_travel() {
  echo "Applying travel configuration..."
  notify-send "Dock" "Applying travel configuration" -u low
  set_monitor 'output = "eDP-1", mode = "1920x1080@60.02", position = "192x2160", scale = 1.0'
  set_monitor 'output = "desc:Invalid Vendor Codename - RTK 0x1920 demoset-1", mode = "1920x1080@60.0", position = "192x1080", scale = 1.0'
  echo "undocked" >"$STATE_FILE"
}

apply_default() {
  echo "Applying default configuration..."
  notify-send "Dock" "Applying default configuration" -u low
  set_monitor 'output = "eDP-1", mode = "1920x1080@60.02", position = "0x0", scale = 1.0, transform = 0, vrr = 0'
  echo "default" >"$STATE_FILE"
}

check_dock() {
  local device vendor product
  for device in /sys/bus/usb/devices/*; do
    [[ -r "$device/idVendor" && -r "$device/idProduct" ]] || continue
    read -r vendor <"$device/idVendor"
    read -r product <"$device/idProduct"
    [[ "$vendor:$product" == "$DOCK_USB_ID" ]] && return 0
  done
  return 1
}

apply() {
  local current_state
  current_state=$(cat "$STATE_FILE" 2>/dev/null || echo "")

  if check_dock; then
    if [ "$current_state" != "docked" ]; then
      apply_dock
    fi
  else
    if [ "$current_state" != "undocked" ]; then
      apply_travel
    fi
  fi
}

case "${1:-}" in
--apply) apply ;;
--dock) apply_dock ;;
--travel) apply_travel ;;
--default) apply_default ;;
--loop)
  # O estado do compositor pode ter mudado enquanto o servico estava parado.
  # Force a reaplicacao do perfil no primeiro ciclo de cada execucao.
  rm -f "$STATE_FILE"
  echo "Starting dock handler loop (polling every 3s)..."
  while true; do
    apply
    sleep 3
  done
  ;;
*)
  apply
  ;;
esac
