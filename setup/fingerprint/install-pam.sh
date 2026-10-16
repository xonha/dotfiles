#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
  printf 'Run this installer as root (for example, with pkexec).\n' >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gate=/usr/local/libexec/xonha-fingerprint-lid-gate
install -D -m 0755 "$SCRIPT_DIR/pam_lid_gate.sh" "$gate"

install -D -m 0644 "$SCRIPT_DIR/90_chipsailing_fprintd_refresh.rules" \
  /etc/udev/rules.d/90_chipsailing_fprintd_refresh.rules
install -D -m 0644 "$SCRIPT_DIR/xonha_fprintd_refresh.service" \
  /etc/systemd/system/xonha_fprintd_refresh.service
install -D -m 0755 "$SCRIPT_DIR/90-xonha-fprintd-resume" \
  /usr/lib/systemd/system-sleep/90-xonha-fprintd-resume
systemctl daemon-reload
udevadm control --reload-rules

updated=0
for pam in /etc/pam.d/sudo /etc/pam.d/polkit-1; do
  [[ -f $pam ]] || continue
  backup=
  if grep -qF '/usr/bin/omarchy-hw-laptop-closed' "$pam"; then
    backup="$pam.backup.$(date +%Y%m%d%H%M%S)"
    cp -a -- "$pam" "$backup"
    sed -i "s|/usr/bin/omarchy-hw-laptop-closed|$gate|g" "$pam"
  fi
  if grep -qF "$gate" "$pam" && ! grep -qF 'omarchy-hw-laptop-closed' "$pam"; then
    if [[ -z $backup ]]; then
      backup="$pam.backup.$(date +%Y%m%d%H%M%S)"
      cp -a -- "$pam" "$backup"
    fi
    sed -i '/pam_fprintd\.so/i # Custom xonha gate replaces omarchy-hw-laptop-closed and preserves its migration marker.' "$pam"
    printf 'Updated %s (backup: %s)\n' "$pam" "$backup"
    updated=$((updated + 1))
  fi
done

if (( updated == 0 )); then
  printf 'PAM unchanged; installed %s and the CS9711 refresh rule.\n' "$gate"
fi
