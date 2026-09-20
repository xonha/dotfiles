#!/usr/bin/env bash
set -Eeuo pipefail

lang="${1:?language is required}"
shift
stt_bin="/home/henrique/.config/omarchy/plugins/xonha.voice-tools/bin/stt"
config_file="/home/henrique/.config/speech-to-text/config.json"
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

stt_source="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("device", "default"))' "$config_file" 2>/dev/null || true)"
if [[ -z "$stt_source" || "$stt_source" == "default" ]]; then
  notify-send "Speech to text" "Configure um microfone exclusivo para o ditado" 2>/dev/null || true
  exit 1
fi
if ! pactl list short sources | awk '{print $2}' | grep -Fxq "$stt_source"; then
  notify-send "Speech to text" "Microfone do ditado indisponível: $stt_source" 2>/dev/null || true
  exit 1
fi

sources=("$stt_source")
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
