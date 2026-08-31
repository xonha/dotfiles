#!/usr/bin/env bash
# Toggle mute on every capture source, regardless of the current default.
# Monitor sources are outputs exposed as inputs and are intentionally ignored.

set -Eeuo pipefail

MIC_ON_SOUND="/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
MIC_OFF_SOUND="/usr/share/sounds/freedesktop/stereo/network-connectivity-lost.oga"

mapfile -t sources < <(
  pactl list short sources | awk '$2 !~ /\.monitor$/ { print $2 }'
)

if ((${#sources[@]} == 0)); then
  echo "nenhuma entrada de audio encontrada" >&2
  exit 1
fi

# Fail safe: if even one capture source is live, the toggle mutes all of them.
# Unmute only when every capture source is already muted.
target=0
for source in "${sources[@]}"; do
  if ! pactl get-source-mute "$source" | grep -q 'yes$'; then
    target=1
    break
  fi
done

for source in "${sources[@]}"; do
  pactl set-source-mute "$source" "$target"
done

if ((target)); then
  [[ -f "$MIC_OFF_SOUND" ]] && pw-play "$MIC_OFF_SOUND" >/dev/null 2>&1 &
  notify-send -h string:x-canonical-private-synchronous:mic-mute -u low \
    "Microfones mutados" 2>/dev/null || true
else
  [[ -f "$MIC_ON_SOUND" ]] && pw-play "$MIC_ON_SOUND" >/dev/null 2>&1 &
  notify-send -h string:x-canonical-private-synchronous:mic-mute -u normal \
    "Microfones ativos" 2>/dev/null || true
fi
