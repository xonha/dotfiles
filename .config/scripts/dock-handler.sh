#!/usr/bin/env bash
# ~/.config/scripts/dock-handler.sh
# Unified dock handler: monitors display + toggles keyd
# Uses polling to detect dock state

set -Eeuo pipefail

KEYD_SERVICE="keyd.service"
DOCK_ID="0bda:8152"
STATE_FILE="/tmp/dock-handler-state"

apply_dock() {
  echo "Applying docked configuration..."
  notify-send "Dock" "Applying docked configuration" -u low
  hyprctl keyword monitor "eDP-1, disable"
  hyprctl keyword monitor "desc:Shenzhen KTC Technology Group SFPCCB24180 000000000000,1920x1080@60,0x0,1.00000000,transform,0,vrr,0"
  hyprctl keyword monitor "desc:SUE SFP2412FHD 000000000000,1920x1080@60,1920x0,1.00000000,transform,0,vrr,0"
  systemctl stop "$KEYD_SERVICE"
  echo "docked" >"$STATE_FILE"
}

apply_travel() {
  echo "Applying travel configuration..."
  notify-send "Dock" "Applying travel configuration" -u low
  hyprctl keyword monitor "eDP-1,1920x1080@60.02,192x2160,1.0"
  hyprctl keyword monitor "desc:Invalid Vendor Codename - RTK 0x1920 demoset-1,1920x1080@60.0,192x1080,1.0"
  systemctl start "$KEYD_SERVICE"
  echo "undocked" >"$STATE_FILE"
}

apply_default() {
  echo "Applying default configuration..."
  notify-send "Dock" "Applying default configuration" -u low
  hyprctl keyword monitor "eDP-1,1920x1080@60.02000,0x0,1.00000000,transform,0,vrr,0"
  systemctl start "$KEYD_SERVICE"
  echo "default" >"$STATE_FILE"
}

check_dock() {
  if lsusb | grep -q "$DOCK_ID"; then
    return 0
  else
    return 1
  fi
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
