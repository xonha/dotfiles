#!/usr/bin/env bash
# Step: Nemo file manager — XDG folders, sidebar bookmarks, custom icons
#
# Nemo does NOT auto-list the XDG special folders (Documents, Downloads, ...).
# It only shows Home/Desktop/Filesystem/Trash plus whatever is bookmarked, so
# the standard folders have to be seeded into the bookmarks file explicitly.

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_DIR/lib.sh"

# Personal folders shown in the "Bookmarks" section, with a Papirus icon each.
declare -A ICONS=(
  [Android]=folder-android
  [Dotfiles]=folder-activities
  [Projects]=folder-projects
)

run() {
  header "Configure Nemo sidebar"

  # 1. Apply the Papirus icon theme to Nemo/Cinnamon and GTK applications.
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.cinnamon.desktop.interface icon-theme 'Papirus-Dark'
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
    success "Papirus-Dark icon theme applied."
  else
    warn "gsettings not found; icon theme not applied."
  fi

  # 2. Map the XDG special folders ($HOME/Documents, ...) instead of $HOME.
  #    Also wired into hyprland exec-once so it re-runs on every login.
  if command -v xdg-user-dirs-update >/dev/null 2>&1; then
    LC_ALL=C.UTF-8 xdg-user-dirs-update --force
    success "XDG user dirs generated (~/.config/user-dirs.dirs)."
  else
    warn "xdg-user-dirs not installed; skipping."
  fi

  # 3. Seed the sidebar. First 5 entries are the XDG folders, the rest are
  #    the personal ones (kept in sync with ICONS and the breakpoint below).
  local bookmarks="$HOME/.config/gtk-3.0/bookmarks"
  mkdir -p "$(dirname "$bookmarks")"
  cat > "$bookmarks" <<EOF
file://$HOME/Documents Documents
file://$HOME/Downloads Downloads
file://$HOME/Music Music
file://$HOME/Pictures Pictures
file://$HOME/Videos Videos
file://$HOME/Projects Projects
file://$HOME/Dotfiles Dotfiles
file://$HOME/Android Android
EOF
  success "Sidebar bookmarks seeded."

  # 4. Split point: the first 5 bookmarks group under "My Computer", the
  #    personal ones under "Bookmarks".
  if command -v dconf >/dev/null 2>&1; then
    dconf write /org/nemo/window-state/sidebar-bookmark-breakpoint 5
    success "Sidebar section breakpoint set."
  else
    warn "dconf not found; sidebar grouping not applied."
  fi

  # 5. Custom Papirus folder icons (stored in GIO metadata, per-machine).
  if command -v gio >/dev/null 2>&1; then
    for dir in "${!ICONS[@]}"; do
      mkdir -p "$HOME/$dir"
      gio set -t string "$HOME/$dir" metadata::custom-icon-name "${ICONS[$dir]}"
    done
    success "Custom folder icons applied."
  else
    warn "gio not found; custom icons not applied."
  fi

  info "Run 'nemo -q' to reload Nemo and see the changes."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
