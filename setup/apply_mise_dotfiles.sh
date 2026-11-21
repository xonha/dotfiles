#!/usr/bin/env bash
# Apply the dotfiles declared in mise.toml, plus what mise cannot declare
# statically:
#
# - one link per direct child of ai/skills and omarchy/themes, so tracked and
#   local skills or themes appear next to those other tools install;
# - the AI directories, skipped where ~/.claude or ~/.agents already link to
#   ai/ as a whole (mise would see the source itself as a conflict);
# - real systemd drop-in directories;
# - with --backup-conflicts, moving conflicting files to
#   ~/.local/state/dotfiles-backups/<timestamp> before applying.
#
# Usage: apply_mise_dotfiles.sh [apply|status|diff] [--backup-conflicts] [mise flags]
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command=apply
case ${1:-} in apply | status | diff) command=$1 && shift ;; esac
backup=0 dry_run=0
args=()
for arg in "$@"; do
  case $arg in
    --backup-conflicts) backup=1 ;;
    -n | --dry-run) dry_run=1 && args+=("$arg") ;;
    *) args+=("$arg") ;;
  esac
done

generated="$(mktemp --suffix=.toml)"
trap 'rm -f "$generated"' EXIT

# Where a path lives, following its parents but not the path itself.
physical() { printf '%s/%s' "$(realpath -m -- "$(dirname -- "$1")")" "${1##*/}"; }
toml_string() { local s=${1//\\/\\\\}; printf '"%s"' "${s//\"/\\\"}"; }
link() {
  [[ $(physical "$1") == "$(physical "$2")" ]] && return
  printf '%s = { source = %s }\n' "$(toml_string "~/${1#"$HOME"/}")" "$(toml_string "$2")"
}
link_children() {
  local child
  for child in "$1"/*; do
    # Skills that link to Omarchy's own (ai/skills/omarchy) exist only there.
    [[ -e $child ]] || continue
    link "$2/${child##*/}" "$child"
  done
}

shopt -s nullglob dotglob
{
  echo '[dotfiles]'
  link "$HOME/.claude/skills" "$root/ai/skills"
  link "$HOME/.agents/agents" "$root/ai/agents"
  link_children "$root/ai/skills" "$HOME/.agents/skills"
  link_children "$root/omarchy/themes" "$HOME/.config/omarchy/themes"
} >"$generated"
shopt -u nullglob dotglob

# The generated file replaces the global mise config for this run only, so
# the user's own mise configuration is neither read nor changed.
run_mise() {
  MISE_GLOBAL_CONFIG_FILE="$generated" MISE_TRUSTED_CONFIG_PATHS="$root" \
    mise -C "$root" dot "$@"
}

backup_conflicts() {
  local output target location destination backup_dir
  local -a conflicts=()
  # mise lists every path it refuses to replace; nothing to do if it refuses none.
  output="$(run_mise apply --dry-run 2>&1)" && return 0
  mapfile -t conflicts < <(sed -n '/refusing to overwrite existing files/,/^[^ ]/s/^  //p' <<<"$output")
  if ((${#conflicts[@]} == 0)); then
    printf '%s\n' "$output" >&2
    return 1
  fi
  backup_dir="$HOME/.local/state/dotfiles-backups/$(date +%Y%m%d-%H%M%S-%N)"
  for target in "${conflicts[@]}"; do
    target=${target/#\~/$HOME}
    location="$(physical "$target")"
    if [[ $target != "$HOME"/* || $location == "$root" || $location == "$root"/* ]]; then
      printf 'Refusing to move %s; resolve this conflict manually.\n' "$target" >&2
      return 1
    fi
    destination="$backup_dir/${target#"$HOME"/}"
    mkdir -p -- "$(dirname -- "$destination")"
    mv -- "$target" "$destination"
  done
  printf 'Existing dotfiles backed up to %s\n' "$backup_dir"
}

if [[ $command == apply ]] && ((!dry_run)); then
  # systemd silently ignores a drop-in directory that is a symlink, so each
  # *.d directory under config/systemd must exist as a real directory and
  # only the files inside it may be links.
  if [[ -d $root/config/systemd ]]; then
    while IFS= read -r -d '' dir; do
      mkdir -p -- "$HOME/.config/systemd/${dir#"$root/config/systemd/"}"
    done < <(find "$root/config/systemd" -type d -name '*.d' -print0)
  fi
  ((backup)) && backup_conflicts
fi

run_mise "$command" "${args[@]}"
