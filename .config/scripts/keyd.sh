#!/usr/bin/env bash
# ~/.config/scripts/keyd.sh
# Start/stop keyd.service.

set -Eeuo pipefail

is_active() {
  systemctl is-active --quiet keyd.service
}

toggle() {
  if is_active; then
    systemctl stop keyd.service
  else
    systemctl start keyd.service
  fi
}

case "${1:-}" in
--start) systemctl start keyd.service ;;
--stop) systemctl stop keyd.service ;;
--status) systemctl is-active keyd.service ;;
--toggle) toggle ;;
*) echo "uso: $0 [--start|--stop|--status|--toggle]" >&2; exit 1 ;;
esac
