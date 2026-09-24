#!/usr/bin/env bash
set -Eeuo pipefail

card="bluez_card.00_02_5B_00_FF_0E"
profile="headset-head-unit"
music_profile="a2dp-sink"
source_name="bt_rnnoise"
config="${HOME}/.config/pipewire/bt-rnnoise.conf"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/bt-rnnoise"
pid_file="${runtime_dir}/pipewire.pid"
previous_source_file="${runtime_dir}/previous-source"
log_file="${runtime_dir}/pipewire.log"

mkdir -p "$runtime_dir"

notify() {
  notify-send "Bluetooth microphone" "$1" 2>/dev/null || true
}

set_all_sources_mute() {
  local target="$1" source
  while read -r source; do
    [[ -n "$source" ]] && pactl set-source-mute "$source" "$target" || true
  done < <(pactl list short sources | awk '$2 !~ /\.monitor$/ { print $2 }')
}

running_pid() {
  if [[ -s "$pid_file" ]]; then
    local pid
    pid=$(<"$pid_file")
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
      printf '%s\n' "$pid"
      return 0
    fi
  fi
  return 1
}

restore_source() {
  local previous fallback
  previous=""
  [[ -f "$previous_source_file" ]] && previous=$(<"$previous_source_file")
  if [[ -n "$previous" && "$previous" != bluez_input.* ]] && pactl list short sources | awk '{print $2}' | grep -Fxq "$previous"; then
    pactl set-default-source "$previous" || true
    return
  fi
  fallback=$(pactl list short sources | awk '$2 !~ /^bluez_input/ && $2 !~ /^bt_rnnoise/ { print $2; exit }')
  [[ -n "$fallback" ]] && pactl set-default-source "$fallback" || true
}

if pid=$(running_pid); then
  set_all_sources_mute 1
  restore_source
  kill "$pid" 2>/dev/null || true
  for _ in {1..30}; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  rm -f "$pid_file" "$previous_source_file"
  pactl set-card-profile "$card" "$music_profile" || true
  notify "desativado; áudio em alta qualidade restaurado"
  exit 0
fi

previous=$(pactl get-default-source 2>/dev/null || true)
printf '%s\n' "$previous" >"$previous_source_file"

if ! pactl set-card-profile "$card" "$profile"; then
  rm -f "$previous_source_file"
  notify "não foi possível ativar o microfone mSBC"
  exit 1
fi

pipewire -c "$config" >"$log_file" 2>&1 &
printf '%s\n' "$!" >"$pid_file"

for _ in {1..80}; do
  if pactl list short sources | awk '{print $2}' | grep -Fxq "$source_name"; then
    pactl set-default-source "$source_name"
    set_all_sources_mute 0
    notify "ativado com RNNoise (mSBC)"
    exit 0
  fi
  sleep 0.1
done

if pid=$(running_pid); then
  kill "$pid" 2>/dev/null || true
fi
rm -f "$pid_file" "$previous_source_file"
pactl set-card-profile "$card" "$music_profile" || true
notify "falha ao criar o microfone RNNoise"
exit 1
