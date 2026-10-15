#!/usr/bin/env bash
# pam_exec gate: skip fingerprint auth only when the lid is closed and the
# external CS9711 USB reader is absent. Exit 0 makes PAM skip pam_fprintd;
# exit 1 lets the authentication stack continue.

set -u

lid_closed=false
for state in /proc/acpi/button/lid/*/state; do
  [[ -r $state ]] || continue
  if [[ $(<"$state") == *closed* ]]; then
    lid_closed=true
    break
  fi
done

if [[ $lid_closed == false ]]; then
  exit 1
fi

for device in /sys/bus/usb/devices/*; do
  [[ -r $device/idVendor && -r $device/idProduct ]] || continue
  if [[ $(<"$device/idVendor") == 2541 && $(<"$device/idProduct") == 0236 ]]; then
    exit 1
  fi
done

exit 0
