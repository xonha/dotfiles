#!/usr/bin/env bash
SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_ROOT/_shared.sh"

run() {
  header "Dotfiles & user setup"

  ensure_aur_package dotdrop

  local dotfiles_dir
  dotfiles_dir="$(cd "$SETUP_ROOT/.." && pwd)"

  # systemd silently ignores a drop-in directory that is a symlink —
  # DropInPaths comes back empty, no error — so every *.d must exist as a real
  # directory before dotfiles are applied, leaving only the .conf symlinked.
  info "Pre-creating systemd drop-in directories (must not be symlinks)..."
  while IFS= read -r d; do
    mkdir -p "$HOME/$d"
  done < <(cd "$dotfiles_dir" && find config/systemd -type d -name '*.d' 2>/dev/null)

  info "Applying Dotdrop mappings from $dotfiles_dir..."
  pushd "$dotfiles_dir" >/dev/null
  dotdrop install --cfg config/dotdrop.yaml --profile omarchy --no-banner --nodiff
  popd >/dev/null
  success "Dotfiles applied with Dotdrop."

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
