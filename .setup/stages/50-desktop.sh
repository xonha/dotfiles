#!/usr/bin/env bash
# Stage: Install and configure the graphical desktop.

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SETUP_ROOT/lib/ui.sh"

run_module() {
  local module="$1"
  source "$module"
  run
}

run() {
  header "Desktop"

  run_module "$SETUP_ROOT/desktop/packages.sh"
  run_module "$SETUP_ROOT/desktop/apps/nemo.sh"
  run_module "$SETUP_ROOT/system/input/keyd.sh"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
