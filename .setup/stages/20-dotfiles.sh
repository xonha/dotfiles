#!/usr/bin/env bash
# Step: Stow dotfiles and switch remote to SSH

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SETUP_ROOT/stages/_shared.sh"

run() {
  header "Dotfiles & user setup"

  local dotfiles_dir
  dotfiles_dir="$(cd "$SETUP_ROOT/.." && pwd)"

  # stow folds a whole directory into a single symlink when the target does
  # not exist yet. systemd silently ignores a drop-in directory that is a
  # symlink — DropInPaths comes back empty, no error — so every *.d must exist
  # as a real directory before stow runs, leaving only the .conf symlinked.
  info "Pre-creating systemd drop-in directories (must not be symlinks)..."
  while IFS= read -r d; do
    mkdir -p "$HOME/$d"
  done < <(cd "$dotfiles_dir" && find .config/systemd -type d -name '*.d' 2>/dev/null)

  info "Stowing dotfiles from $dotfiles_dir..."
  pushd "$dotfiles_dir" >/dev/null
  if is_omarchy; then
    info "Omarchy detected; preserving native desktop configuration except the versioned Hyprland overrides."
    # These are configuration and launchers for the previous
    # CachyOS/Hyprland/Kitty desktop. Omarchy owns equivalent
    # settings (Quickshell, Foot and the native browser) and updates them over
    # time, so they must remain outside Stow's control. Hyprland is intentionally
    # versioned here as user overrides loaded after Omarchy's defaults.
    local -a omarchy_ignores=(
      '\\.config/kitty(/|$)'
      '\\.config/(gh|nvim)(/|$)'
      '\\.config/brave-flags\\.conf$'
      '\\.local/share/applications/(brave-.*|kitty.*)\\.desktop$'
      '\\.local/share/icons/hicolor/scalable/apps/kitty-.*\\.svg$'
      '\\.config/systemd/user/dock-handler\\.service$'
    )
    local -a stow_args=()
    local ignore
    for ignore in "${omarchy_ignores[@]}"; do
      stow_args+=(--ignore="$ignore")
    done
    stow "${stow_args[@]}" .
    success "Legacy desktop dotfiles skipped; Omarchy defaults preserved."
  else
    stow .
  fi
  popd >/dev/null
  success "Dotfiles stowed."

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
