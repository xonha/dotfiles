#!/usr/bin/env bash
# Step: Configure automatic Hyprland monitor profiles.

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SETUP_ROOT/stages/_shared.sh"

run() {
  header "Hyprland monitor profiles"

  if ! command -v hyprdynamicmonitors >/dev/null 2>&1; then
    warn "hyprdynamicmonitors is not installed; skipping monitor services."
    return 0
  fi

  local logind_file=/etc/systemd/logind.conf.d/90-hyprland-lid-ignore.conf
  local policy_file="$SETUP_ROOT/desktop/thinkpad_t495/90-hyprland-lid-ignore.conf"
  if [[ -f "$logind_file" ]] && ! cmp -s "$policy_file" "$logind_file"; then
    local backup_dir="$HOME/.config/dotfiles-backups/logind"
    mkdir -p "$backup_dir"
    cp -a "$logind_file" "$backup_dir/90-hyprland-lid-ignore.conf.$(date +%Y%m%d-%H%M%S)"
    info "Backed up existing logind lid policy."
  fi

  info "Installing lid policy..."
  sudo install -Dm644 "$policy_file" "$logind_file"
  sudo systemctl restart systemd-logind

  # The old polling daemon conflicts with HyprDynamicMonitors.
  systemctl --user disable --now dock-handler.service 2>/dev/null || true
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable hyprdynamicmonitors-prepare.service
  systemctl --user enable hyprdynamicmonitors.service

  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    systemctl --user start hyprdynamicmonitors-prepare.service
    systemctl --user restart hyprdynamicmonitors.service
    hyprdynamicmonitors validate
    success "HyprDynamicMonitors configured and running."
  else
    warn "No Wayland session detected; services enabled for next login."
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
