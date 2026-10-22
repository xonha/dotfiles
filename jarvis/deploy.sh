#!/usr/bin/env bash
set -euo pipefail

jarvis_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
jarvis_host="${JARVIS_HOST:-jarvis}"

ssh "$jarvis_host" 'loginctl enable-linger "$USER" && mkdir -p "$HOME/.config/containers/systemd" "$HOME/.local/share/applications" "$HOME/.local/share/jarvis/homeassistant" "$HOME/.local/share/jarvis/music-assistant" "$HOME/.local/share/jarvis/wyoming-whisper" "$HOME/.local/share/jarvis/wyoming-piper" "$HOME/.local/share/jarvis/voice/local" "$HOME/.local/share/jarvis/voice/configuration"'
scp "$jarvis_root/homeassistant.container" "$jarvis_host:.config/containers/systemd/homeassistant.container"
scp "$jarvis_root/music-assistant.container" "$jarvis_host:.config/containers/systemd/music-assistant.container"
scp "$jarvis_root/wyoming-whisper.container" "$jarvis_host:.config/containers/systemd/wyoming-whisper.container"
scp "$jarvis_root/wyoming-piper.container" "$jarvis_host:.config/containers/systemd/wyoming-piper.container"
scp "$jarvis_root/linux-voice-assistant.container" "$jarvis_host:.config/containers/systemd/linux-voice-assistant.container"
scp "$jarvis_root/jarvis-meet.desktop" "$jarvis_host:.local/share/applications/jarvis-meet.desktop"
scp "$jarvis_root/jarvis-chatgpt.desktop" "$jarvis_host:.local/share/applications/jarvis-chatgpt.desktop"
ssh "$jarvis_host" 'systemctl --user daemon-reload && systemctl --user start homeassistant.service music-assistant.service wyoming-whisper.service wyoming-piper.service linux-voice-assistant.service && systemctl --user is-active homeassistant.service music-assistant.service wyoming-whisper.service wyoming-piper.service linux-voice-assistant.service'
