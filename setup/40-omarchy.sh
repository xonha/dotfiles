#!/usr/bin/env bash
# Stage: Install Omarchy client packages and shell plugins.

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_ROOT/_shared.sh"

run_module() {
  local module="$1"
  source "$module"
  run
}

run() {
  header "Omarchy client"
  run_module "$SETUP_ROOT/omarchy-packages.sh"
  run_module "$SETUP_ROOT/omarchy-plugins.sh"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
