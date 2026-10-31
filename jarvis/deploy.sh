#!/usr/bin/env bash
set -euo pipefail

jarvis_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
jarvis_host="${JARVIS_HOST:-jarvis}"
services=(music-assistant wyoming-whisper wyoming-piper)
quadlet_dir=.config/containers/systemd

ssh "$jarvis_host" 'loginctl enable-linger "$USER" && mkdir -p "$HOME/.config/containers/systemd" "$HOME/.config/systemd/user" "$HOME/.local/bin" "$HOME/.cache/jarvis" "$HOME/.local/share/applications" "$HOME/.local/share/jarvis/music-assistant" "$HOME/.local/share/jarvis/wyoming-whisper" "$HOME/.local/share/jarvis/wyoming-piper"'

# Remove Home Assistant from the active deployment while preserving its data.
ssh "$jarvis_host" 'systemctl --user disable --now homeassistant.service linux-voice-assistant.service 2>/dev/null || true; rm -f "$HOME/.config/containers/systemd/homeassistant.container" "$HOME/.config/containers/systemd/linux-voice-assistant.container"'

# A running service keeps its old image and settings until restarted, so restart
# exactly the services whose unit file differs from the copy on Jarvis.
remote_sums="$(ssh "$jarvis_host" "cd $quadlet_dir && sha256sum *.container 2>/dev/null || true")"
units=()
changed=()
for service in "${services[@]}"; do
  units+=("$jarvis_root/$service.container")
  sum="$(sha256sum "$jarvis_root/$service.container" | cut -d' ' -f1)"
  grep -qxF "$sum  $service.container" <<<"$remote_sums" || changed+=("$service.service")
done

scp -q "${units[@]}" "$jarvis_host:$quadlet_dir/"
scp -q "$jarvis_root/jarvis-meet.desktop" "$jarvis_root/jarvis-chatgpt.desktop" "$jarvis_host:.local/share/applications/"
scp -q "$jarvis_root/jarvis-backup.service" "$jarvis_root/jarvis-backup.timer" "$jarvis_host:.config/systemd/user/"
scp -q "$jarvis_root/jarvis-backup.sh" "$jarvis_host:.local/bin/jarvis-backup"
scp -q "$jarvis_root/logind-lid.conf" "$jarvis_host:.cache/jarvis/logind-lid.conf"

# The lid drop-in lives in /etc, so sudo only asks for a password when it changed.
ssh -t "$jarvis_host" 'conf=/etc/systemd/logind.conf.d/jarvis-lid.conf; cmp -s .cache/jarvis/logind-lid.conf "$conf" || { sudo install -Dm644 .cache/jarvis/logind-lid.conf "$conf" && sudo systemctl kill -s HUP systemd-logind && echo "Installed $conf"; }'

restart=""
if ((${#changed[@]})); then
  echo "Restarting: ${changed[*]}"
  restart="systemctl --user restart ${changed[*]} && "
fi
ssh "$jarvis_host" "chmod +x .local/bin/jarvis-backup && systemctl --user daemon-reload && systemctl --user enable --now jarvis-backup.timer && ${restart}systemctl --user start ${services[*]/%/.service} && systemctl --user is-active ${services[*]/%/.service} jarvis-backup.timer && ! systemctl --user is-active -q homeassistant.service && ! systemctl --user is-active -q linux-voice-assistant.service"
