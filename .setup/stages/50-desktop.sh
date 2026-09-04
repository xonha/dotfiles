#!/usr/bin/env bash
# Stage: Install and configure the graphical desktop.

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SETUP_ROOT/stages/_shared.sh"

run_module() {
  local module="$1"
  source "$module"
  run
}

run() {
  header "Desktop"

  run_module "$SETUP_ROOT/desktop/packages.sh"
  if is_omarchy; then
    info "Skipping Nemo setup; Omarchy's native file manager is preserved."
    run_module "$SETUP_ROOT/desktop/omarchy-plugins.sh"
  else
    run_module "$SETUP_ROOT/desktop/nemo.sh"
  fi
  run_module "$SETUP_ROOT/desktop/keyd.sh"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
