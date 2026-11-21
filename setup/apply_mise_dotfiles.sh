#!/usr/bin/env bash
set -euo pipefail

setup_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_file="$(mktemp --suffix=.toml)"
trap 'rm -f "$config_file"' EXIT
python3 "$setup_root/mise_dotfiles.py" > "$config_file"
if [[ ${1:-} == --backup-conflicts ]]; then
  python3 "$setup_root/backup_mise_conflicts.py" "$config_file"
  shift
fi
MISE_GLOBAL_CONFIG_FILE="$config_file" mise -C /tmp dot apply "$@"
