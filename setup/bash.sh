#!/usr/bin/env bash
SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_ROOT/_shared.sh"

run() {
  header "Configure login shell"

  local target_user="${SUDO_USER:-${USER:-}}"
  if [[ -z "$target_user" || "$target_user" == "root" ]]; then
    error "Could not determine a non-root user for the login shell change."
    return 1
  fi

  local bash_path
  bash_path="$(command -v bash 2>/dev/null || true)"
  [[ -n "$bash_path" ]] && bash_path="$(readlink -f "$bash_path")"
  if [[ -z "$bash_path" || ! -x "$bash_path" ]]; then
    error "Bash is not installed or is not executable; keeping the current login shell."
    return 1
  fi

  if ! grep -Fqx "$bash_path" /etc/shells; then
    error "$bash_path is not listed in /etc/shells; keeping the current login shell."
    error "Fix /etc/shells before rerunning this step."
    return 1
  fi

  local passwd_entry current_shell
  passwd_entry="$(getent passwd "$target_user" || true)"
  if [[ -z "$passwd_entry" ]]; then
    error "User $target_user was not found; keeping the current login shell."
    return 1
  fi
  current_shell="${passwd_entry##*:}"

  if [[ "$current_shell" == "$bash_path" ]]; then
    success "Bash is already the login shell for $target_user ($bash_path)."
    return 0
  fi

  info "Changing the login shell for $target_user: $current_shell -> $bash_path"
  info "Both the executable and its /etc/shells entry were validated."
  sudo usermod -s "$bash_path" "$target_user"

  local configured_shell
  configured_shell="$(getent passwd "$target_user" | cut -d: -f7)"
  if [[ "$configured_shell" != "$bash_path" ]]; then
    error "Login shell verification failed: expected $bash_path, got $configured_shell."
    return 1
  fi

  success "Bash configured as the login shell for $target_user."
  warn "The new login shell takes effect on the next login."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
