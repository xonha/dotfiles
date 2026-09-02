#!/usr/bin/env bash
# Step: Persist suspend wakeup sources (keyboard, lid) via udev rules

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SETUP_ROOT/lib/ui.sh"

RULES_FILE="/etc/udev/rules.d/90-wakeup-keyboard.rules"

RULES_CONTENT='# Internal ThinkPad keyboard (i8042)
KERNEL=="serio0", SUBSYSTEM=="serio", ATTR{power/wakeup}="enabled"

# External USB keyboard (Corne - 1d50:615e)
# Matched by vendor/product ID so it works regardless of which port it is plugged into.
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="615e", ATTR{power/wakeup}="enabled"

# Lid
ACTION=="add", SUBSYSTEM=="platform", KERNEL=="PNP0C0D:00", ATTR{power/wakeup}="enabled"
'

write_rules() {
  info "Writing $RULES_FILE..."
  if echo "$RULES_CONTENT" | sudo tee "$RULES_FILE" > /dev/null; then
    success "Rules file written."
  else
    error "Failed to write $RULES_FILE."
    exit 1
  fi
}

reload_udev() {
  info "Reloading udev rules..."
  if sudo udevadm control --reload-rules && sudo udevadm trigger; then
    success "udev rules reloaded."
  else
    error "Failed to reload udev rules."
    exit 1
  fi
}

apply_immediately() {
  info "Applying wakeup settings for current session..."

  local nodes=(
    "/sys/devices/platform/i8042/serio0/power/wakeup"
    "/sys/devices/platform/PNP0C0D:00/power/wakeup"
  )

  for node in "${nodes[@]}"; do
    if [[ -f "$node" ]]; then
      echo enabled | sudo tee "$node" > /dev/null
      success "enabled: $node"
    else
      warn "Not found (skipping): $node"
    fi
  done

  # USB keyboard — find by vendor/product ID
  local usb_wakeup
  usb_wakeup=$(grep -rl "1d50" /sys/bus/usb/devices/*/idVendor 2>/dev/null | head -1)
  if [[ -n "$usb_wakeup" ]]; then
    local usb_dir
    usb_dir=$(dirname "$usb_wakeup")
    echo enabled | sudo tee "$usb_dir/power/wakeup" > /dev/null
    success "enabled: $usb_dir/power/wakeup ($(cat "$usb_dir/product" 2>/dev/null || echo USB keyboard))"
  else
    warn "Corne keyboard not found on USB — plug it in and re-run, or just reboot."
  fi
}

run() {
  header "Suspend wakeup sources"

  write_rules
  reload_udev
  apply_immediately

  printf "\n"
  success "Done. Wakeup via keyboard and lid is now persistent across reboots."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
