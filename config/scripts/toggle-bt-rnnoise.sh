#!/usr/bin/env bash
set -Eeuo pipefail

card="bluez_card.00_02_5B_00_FF_0E"
profile="headset-head-unit"
music_profile="a2dp-sink"
source_name="bt_rnnoise"
capture_port="bt_rnnoise.capture:input_MONO"
bluetooth_capture_port="bluez_input.00:02:5B:00:FF:0E:capture_MONO"
internal_capture_ports=(
  "alsa_input.pci-0000_06_00.6.analog-stereo:capture_FL"
  "alsa_input.pci-0000_06_00.6.analog-stereo:capture_FR"
)
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
  local source="$1" port
  pw-link -d "$bluetooth_capture_port" "$capture_port" 2>/dev/null || true
  for port in "${internal_capture_ports[@]}"; do
    pw-link -d "$port" "$capture_port" 2>/dev/null || true
  done

  if [[ "$source" == bluetooth ]]; then
    pw-link "$bluetooth_capture_port" "$capture_port" 2>/dev/null || true
  else
    for port in "${internal_capture_ports[@]}"; do
      pw-link "$port" "$capture_port" 2>/dev/null || true
    done
  fi
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
    link_capture_source internal
    rm -f "$enabled_file"
    # Keep the virtual source alive so applications such as Brave do not lose
    # their capture device while the Bluetooth profile changes.
    pactl set-card-profile "$card" "$music_profile" || true
    show_mic_osd off
    exit 0
  fi
else
  rm -f "$pid_file"
fi

if [[ -f "$enabled_file" ]]; then
  rm -f "$enabled_file"
  pactl set-default-source "$source_name" || true
  link_capture_source internal
  pactl set-card-profile "$card" "$music_profile" || true
  show_mic_osd off
  exit 0
fi

if ! pactl set-card-profile "$card" "$profile"; then
  notify_error "Não foi possível ativar o microfone mSBC"
  exit 1
fi

if ! running_pid >/dev/null; then
  pipewire -c "$config" >"$log_file" 2>&1 &
  printf '%s\n' "$!" >"$pid_file"
fi

for _ in {1..80}; do
  if pactl list short sources | awk '{print $2}' | grep -Fxq "$source_name"; then
    link_capture_source bluetooth
    pactl set-default-source "$source_name"
    set_all_sources_mute 0
    : >"$enabled_file"
    show_mic_osd on
    exit 0
  fi
  sleep 0.1
done

if pid=$(running_pid); then
  kill "$pid" 2>/dev/null || true
fi
rm -f "$pid_file" "$enabled_file"
pactl set-card-profile "$card" "$music_profile" || true
notify_error "Falha ao criar o microfone RNNoise"
exit 1
