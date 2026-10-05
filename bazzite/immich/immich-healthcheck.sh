#!/usr/bin/env bash
set -euo pipefail

log() { printf '[immich-healthcheck] %s\n' "$*"; }
fail() { log "ERROR: $*" >&2; exit 1; }

mount_target=/run/media/system/hd
upload_location=/run/media/system/hd/immich/library

findmnt -rn --target "$mount_target" --output TARGET | grep -Fxq "$mount_target" \
  || fail "media disk is not mounted at $mount_target"
[[ "$(findmnt -rn --target "$mount_target" --output SOURCE)" == /dev/sdb1 ]] \
  || fail "unexpected media device"
[[ -d "$upload_location" ]] || fail "library path is missing: $upload_location"

if ! podman container exists immich_server; then
  fail "immich_server container does not exist"
fi

status="$(podman inspect -f '{{.State.Status}}' immich_server)"
if [[ "$status" != running ]]; then
  log "immich_server is $status; attempting a safe restart"
  podman start immich_server >/dev/null || fail "could not start immich_server"
fi

http_code="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 10 http://127.0.0.1:2283 || true)"
[[ "$http_code" == 2* ]] || fail "Immich HTTP check returned $http_code"

if [[ -n "${HEALTHCHECKS_URL:-}" ]]; then
  curl --fail --silent --show-error --max-time 10 "$HEALTHCHECKS_URL" >/dev/null
  log "heartbeat sent"
fi

log "healthy"
