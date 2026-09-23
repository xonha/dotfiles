#!/usr/bin/env bash
# Enable wake from the external keyboard connected through this laptop's USB-C hub.
set -euo pipefail

if (( EUID != 0 )); then
  echo "Run as root: sudo ./setup/udev/install-usb-wakeup.sh" >&2
  exit 1
fi

setup_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rule="$setup_dir/90-omarchy-usb-wakeup.rules"
target=/etc/udev/rules.d/90-omarchy-usb-wakeup.rules

install -m 0644 "$rule" "$target"
udevadm control --reload-rules

# Apply to the currently connected hub and input devices without unplugging it.
for device in usb1 1-1 1-1.1 1-1.1.1 1-1.1.2; do
  path="/sys/bus/usb/devices/$device"
  [[ -d "$path" ]] || continue
  udevadm trigger --action=add "$path"
done
