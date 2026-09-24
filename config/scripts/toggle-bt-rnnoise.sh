#!/usr/bin/env bash
set -Eeuo pipefail

source_name="bt_rnnoise"
mic_on_sound="/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
mic_off_sound="/usr/share/sounds/freedesktop/stereo/network-connectivity-lost.oga"
capture_port="bt_rnnoise.capture:input_MONO"
snowball_capture_port="alsa_input.usb-BLUE_MICROPHONE_Blue_Snowball_SUGA_2021_01_21_75536-00.mono-fallback:capture_MONO"
config="${HOME}/.config/pipewire/bt-rnnoise.conf"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/bt-rnnoise"
pid_file="${runtime_dir}/pipewire.pid"
enabled_file="${runtime_dir}/enabled"
log_file="${runtime_dir}/pipewire.log"

mkdir -p "$runtime_dir"

show_mic_osd() {
  local state="$1"
  if [[ "$state" == on ]]; then
    omarchy-osd -i microphone -m "Open"
  else
    omarchy-osd -i microphone-muted -m "Muted"
  fi
}

notify_error() {
  omarchy-osd -i microphone-muted -m "$1" 2>/dev/null || true
}

link_capture_source() {
  for _ in {1..30}; do
    if pw-link -i bt_rnnoise.capture 2>/dev/null | grep -Fxq "$capture_port"; then
      break
    fi
    sleep 0.1
  done
  pw-link -d "$snowball_capture_port" "$capture_port" 2>/dev/null || true
  pw-link "$snowball_capture_port" "$capture_port" 2>/dev/null || true
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

if pid=$(running_pid); then
  if [[ -f "$enabled_file" ]]; then
    set_all_sources_mute 1
    pactl set-default-source "$source_name" || true
    pw-link -d "$snowball_capture_port" "$capture_port" 2>/dev/null || true
    rm -f "$enabled_file"
    [[ -f "$mic_off_sound" ]] && pw-play "$mic_off_sound" >/dev/null 2>&1 &
    show_mic_osd off
    exit 0
  fi
else
  rm -f "$pid_file"
fi

if ! running_pid >/dev/null; then
  pipewire -c "$config" >"$log_file" 2>&1 &
  printf '%s\n' "$!" >"$pid_file"
fi

for _ in {1..80}; do
  if pactl list short sources | awk '{print $2}' | grep -Fxq "$source_name"; then
    link_capture_source snowball
    pactl set-default-source "$source_name"
    set_all_sources_mute 0
    : >"$enabled_file"
    [[ -f "$mic_on_sound" ]] && pw-play "$mic_on_sound" >/dev/null 2>&1 &
    show_mic_osd on
    exit 0
  fi
  sleep 0.1
done

if pid=$(running_pid); then
  kill "$pid" 2>/dev/null || true
fi
rm -f "$pid_file" "$enabled_file"
notify_error "Falha ao criar o microfone RNNoise"
exit 1
