#!/usr/bin/env bash
# Step: Enable and start systemd services

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_DIR/lib.sh"

# Always enabled on every machine
SERVICES_ALWAYS=(
  tailscaled.service
  earlyoom.service
)

# Prompted individually — user decides per machine
SERVICES_OPTIONAL=(
  docker.service
)

enable_service() {
  local svc="$1"
  info "Enabling $svc..."
  if sudo systemctl enable --now "$svc"; then
    success "$svc enabled and started."
  else
    warn "Failed to enable $svc (may not be installed or already active)."
  fi
}

enable_user_service() {
  local svc="$1"
  if ! systemctl --user cat "$svc" &>/dev/null; then
    info "$svc not installed, skipping."
    return
  fi
  info "Enabling $svc (user)..."
  if systemctl --user enable --now "$svc"; then
    success "$svc enabled and started."
  else
    warn "Failed to enable $svc (needs a running user session — retry after login)."
  fi
}

run() {
  header "Enable services"

  for svc in "${SERVICES_ALWAYS[@]}"; do
    enable_service "$svc"
  done

  for svc in "${SERVICES_OPTIONAL[@]}"; do
    if confirm_step "Enable $svc" ""; then
      enable_service "$svc"
    fi
  done

}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
