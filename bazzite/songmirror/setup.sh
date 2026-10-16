#!/usr/bin/env bash
set -euo pipefail

SONGMIRROR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SONGMIRROR_ROOT/../_shared.sh"

header "Configure SongMirror"
mkdir -p "$HOME/.local/share/songmirror/data"
deploy_unit_file "$SONGMIRROR_ROOT/songmirror.container"
start_quadlet songmirror

if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
  tailscale serve --bg --https=8447 http://127.0.0.1:8888
  success "SongMirror is available over Tailscale Serve on HTTPS port 8447."
else
  warn "Tailscale is unavailable; SongMirror is listening only on 127.0.0.1:8888."
fi
