#!/usr/bin/env bash
SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_ROOT/_shared.sh"

run() {
  header "Dotfiles & user setup"

  if ! command -v mise >/dev/null 2>&1; then
    error "mise is required to apply dotfiles."
    return 1
  fi

  local dotfiles_dir
  dotfiles_dir="$(cd "$SETUP_ROOT/.." && pwd)"

  # Trust the repository's mise.toml so `mise run dotfiles` and
  # `mise dot status` also work from the repository.
  mise trust --quiet "$dotfiles_dir/mise.toml"

  info "Applying mise dotfile mappings from $dotfiles_dir..."
  if ! bash "$SETUP_ROOT/apply_mise_dotfiles.sh"; then
    error "Dotfile application failed; review existing files and retry."
    return 1
  fi
  success "Dotfiles applied with mise."

  info "Switching git remote to SSH..."
  local current
  current="$(git -C "$dotfiles_dir" remote get-url origin)"

  if [[ "$current" == git@github.com:* ]]; then
    warn "Remote is already SSH: $current"
  elif [[ "$current" != https://github.com/* ]]; then
    error "Unexpected remote URL format: $current"
  else
    local new="${current/https:\/\/github.com\//git@github.com:}"
    git -C "$dotfiles_dir" remote set-url origin "$new"
    success "Remote updated: $current -> $new"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
