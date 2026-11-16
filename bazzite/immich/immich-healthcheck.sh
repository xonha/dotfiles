#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
export PODMAN_COMPOSE_PROVIDER="$HOME/.local/bin/podman-compose"
exec 9>"${XDG_RUNTIME_DIR:?}/immich-recovery-v2.lock"
flock -w 180 9

log() { printf '[immich-healthcheck] %s\n' "$*"; }
fail() { log "ERROR: $*" >&2; exit 1; }

mount_target=/run/media/system/hd
upload_location=/run/media/system/hd/immich/library

findmnt -rn --target "$mount_target" --output TARGET | grep -Fxq "$mount_target" \
  || fail "media disk is not mounted at $mount_target"
[[ "$(findmnt -rn --target "$mount_target" --output SOURCE)" == /dev/sdb1 ]] \
  || fail "unexpected media device"
[[ -d "$upload_location" ]] || fail "library path is missing: $upload_location"

status="$(podman inspect -f '{{.State.Status}}' immich_server 2>/dev/null || true)"
http_ok() { curl --fail --silent --output /dev/null --max-time 10 http://127.0.0.1:2283/api/server/ping; }
if [[ "$status" != running ]] || ! http_ok; then
  log "immich_server is $status; attempting recovery"
  (cd "$HOME/immich" && podman compose up -d immich-server 9>&-)
  if [[ "$status" == running ]]; then podman restart immich_server 9>&-; fi

fi

for attempt in {1..30}; do
  if http_ok; then break; fi
  sleep 2
done
http_ok || fail "Immich did not become ready within the recovery window"

if [[ -n "${HEALTHCHECKS_URL:-}" ]]; then
  curl --fail --silent --show-error --max-time 10 "$HEALTHCHECKS_URL" >/dev/null
  log "heartbeat sent"
fi

log "healthy"
