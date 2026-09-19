#!/usr/bin/env bash
set -Eeuo pipefail

lang="${1:?language is required}"
shift
stt_bin="/home/henrique/.config/omarchy/plugins/xonha.voice-tools/bin/stt"
session_dir="${XDG_RUNTIME_DIR:-/tmp}/speech-to-text-mic-restore"
session_file="$session_dir/session"

mkdir -p "$session_dir"
if [[ ! -x "$stt_bin" ]]; then
  notify-send "Speech to text" "stt nao encontrado" 2>/dev/null || true
  exit 1
fi
# The second press of the same shortcut must stop the existing take. It must
# not snapshot the already-open microphone and later overwrite the first
# wrapper's restoration.
if [[ -f "$session_file" ]]; then
  "$stt_bin" toggle --lang "$lang" "$@"
  exit $?
fi

mapfile -t sources < <(pactl list short sources | awk '$2 !~ /\.monitor$/ { print $2 }')
declare -A was_muted
for source in "${sources[@]}"; do
  was_muted["$source"]=$(pactl get-source-mute "$source" | grep -q 'yes$' && echo 1 || echo 0)
  pactl set-source-mute "$source" 0
done
restore() {
  local source
  for source in "${sources[@]}"; do
    pactl set-source-mute "$source" "${was_muted[$source]}" || true
  done
}
trap restore EXIT INT TERM

touch "$session_file"
"$stt_bin" toggle --lang "$lang" "$@"
started=0
for _ in $(seq 1 1200); do
  status=$("$stt_bin" status 2>/dev/null || true)
  if [[ "$status" == recording* || "$status" == transcribing* ]]; then
    started=1
    break
  fi
  sleep 0.05
done
if ((started)); then
  # The second key press ends capture and changes the daemon to
  # transcribing. Restore mute at that boundary; Whisper does not need the
  # microphone while it processes the audio.
  for _ in $(seq 1 6000); do
    status=$("$stt_bin" status 2>/dev/null || true)
    if [[ "$status" != recording* ]]; then
      break
    fi
    sleep 0.05
  done
else
  notify-send "Speech to text" "o daemon nao iniciou a gravacao" 2>/dev/null || true
fi
rm -f "$session_file"
