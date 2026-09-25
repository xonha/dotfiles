#!/usr/bin/env bash
set -euo pipefail

KEEPER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$KEEPER_ROOT/../_shared.sh"

header "Configure Keeper"
env_file="$HOME/.config/containers/systemd/keeper.env"
if [[ ! -f "$env_file" ]] || ! grep -Eq '^BETTER_AUTH_SECRET=[^[:space:]]+' "$env_file" || ! grep -Eq '^ENCRYPTION_KEY=[^[:space:]]+' "$env_file"; then
  error "Create $env_file with BETTER_AUTH_SECRET and ENCRYPTION_KEY before continuing. See bazzite/keeper/README.md."
  exit 1
fi
if ! podman image exists localhost/keeper-standalone:meet; then
  source_dir="$HOME/.local/src/keeper.sh"
  if [[ ! -f "$source_dir/docker/standalone/Dockerfile" ]]; then
    error "Keeper fork missing at $source_dir. Sync it first; see bazzite/keeper/README.md."
    exit 1
  fi
  podman build -f "$source_dir/docker/standalone/Dockerfile" -t localhost/keeper-standalone:meet "$source_dir"
fi
mkdir -p "$HOME/.local/share/keeper/data"
deploy_unit_file "$KEEPER_ROOT/keeper.container"
start_quadlet keeper
