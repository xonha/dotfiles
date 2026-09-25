#!/usr/bin/env bash
# Interactive setup orchestrator.
# Safe to run on both a desktop and an SSH-only server.

set -euo pipefail

OMARCHY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$OMARCHY_ROOT/.." && pwd)"
SETUP_ROOT="$DOTFILES_ROOT/setup"
source "$SETUP_ROOT/_shared.sh"

# The Omarchy binary may not be on PATH in a non-interactive shell. The
# packaged path and OMARCHY_PATH are stable fallback signals.
is_omarchy() {
  command -v omarchy >/dev/null 2>&1 \
    || [[ -x /usr/share/omarchy/bin/omarchy ]] \
    || [[ -n "${OMARCHY_PATH:-}" && -d "${OMARCHY_PATH}" ]]
}

if ! is_omarchy; then
  error "This setup requires Omarchy."
  exit 1
fi

printf "${BOLD}${BLUE}"
printf "╭──────────────────────────────────────╮\n"
printf "│         Henrique's Setup Script      │\n"
printf "╰──────────────────────────────────────╯\n"
printf "${RESET}\n"

run_module() {
  local module="$1"
  source "$SETUP_ROOT/$module"
  run
}

run_module yay.sh
run_module pkg_server.sh

# Configure RTK after its package is installed and before agent sessions start.
run_module rtk.sh

# Dotdrop is provided by the server package stage above.
run_module dotfiles.sh

# Configure the login shell after the shell packages are installed.
run_module bash.sh

run_module pkg_client.sh
source "$OMARCHY_ROOT/plugins.sh"
run

run_module services.sh

printf "\n${BOLD}${GREEN}All selected steps completed.${RESET}\n"
printf "You may need to ${BOLD}log out and back in${RESET} for group changes to take effect.\n\n"
