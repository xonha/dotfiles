#!/usr/bin/env bash
BAZZITE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$BAZZITE_ROOT/.." && pwd)"
source "$DOTFILES_ROOT/setup/_shared.sh"

require_command() {
  command -v "$1" >/dev/null 2>&1 || { error "Required command not found: $1"; return 1; }
}

deploy_unit_file() {
  local source="$1" target="$HOME/.config/containers/systemd/$(basename "$1")"
  mkdir -p "$(dirname "$target")"
  if [[ -e "$target" || -L "$target" ]]; then
    if [[ -L "$target" || ! -f "$target" ]] || ! cmp -s "$source" "$target"; then
      error "Existing unit differs from $source: $target. Review it before replacing."
      return 1
    fi
    info "$(basename "$source") is already installed."
    return 0
  fi
  install -m 0644 "$source" "$target"
}

start_quadlet() {
  local service="$1"
  systemctl --user daemon-reload
  systemctl --user start "$service.service"
  systemctl --user is-active --quiet "$service.service" || { error "$service.service failed to start."; return 1; }
  success "$service.service is active."
}
