#!/usr/bin/bash
set -euo pipefail

exec 3<>/dev/tcp/127.0.0.1/22
IFS= read -r -t 3 banner <&3
[[ "$banner" == SSH-* ]]
