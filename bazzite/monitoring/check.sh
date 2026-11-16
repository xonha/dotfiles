#!/usr/bin/env bash
set -uo pipefail
export PATH="$HOME/.local/bin:/usr/bin:/bin"
failed=0
check() {
 local name=$1; shift
 if "$@" >/dev/null 2>&1; then echo "OK $name"; else echo "FAIL $name"; failed=1; fi
}
for name in immich_server immich_postgres immich_redis immich_machine_learning samba crafty caddy lab songmirror keeper cloudflared-immich mediarium jellyfin; do
 check "$name:running" bash -c '[[ $(podman inspect -f "{{.State.Status}}" "$1") == running ]]' _ "$name"
done
check media-disk bash -c '[[ $(findmnt -rn -M /run/media/system/hd -o SOURCE) == /dev/sdb1 ]]'
for entry in 'immich|http://127.0.0.1:2283/api/server/ping' 'keeper|http://127.0.0.1:8088/' 'songmirror|http://127.0.0.1:8888/' 'mediarium|http://127.0.0.1:8264/' 'jellyfin|http://127.0.0.1:8096/health' 'crafty|https://127.0.0.1:8443/'; do
 IFS='|' read -r name url <<< "$entry"
 check "$name:http" curl -kfLsS --max-time 10 "$url"
done
check caddy:https curl -kfLsS --max-time 10 --resolve keeper.plu.nz:8453:127.0.0.1 https://keeper.plu.nz:8453/
check lab:ssh bash -c 'exec 3<>/dev/tcp/127.0.0.1/2224; read -r -t 5 banner <&3; [[ $banner == SSH-* ]]'
check samba:tcp timeout 5 bash -c 'exec 3<>/dev/tcp/100.120.120.71/445'
check postgres:ready podman exec immich_postgres pg_isready
check redis:ping podman exec immich_redis redis-cli ping
check machine-learning:http podman exec immich_machine_learning python -c 'import urllib.request; urllib.request.urlopen("http://127.0.0.1:3003/ping",timeout=5)'
if [[ -n ${HEALTHCHECKS_URL:-} ]]; then
 suffix=''; (( failed )) && suffix=/fail
 check heartbeat curl -fsS --max-time 10 "${HEALTHCHECKS_URL%/}$suffix"
fi
exit "$failed"
