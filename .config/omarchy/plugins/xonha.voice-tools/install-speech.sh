#!/bin/bash
# Install the Speech to Text plugin for the current user.
#   ./install.sh              link the plugin into ~/.config/omarchy/plugins (when run from a checkout elsewhere),
#                             put the `stt` CLI on PATH, enable the bar widget
#   ./install.sh --uninstall
# `omarchy plugin add <git-url> --enable` alone is enough for normal use: the key
# bindings call the CLI by absolute path. This script only adds conveniences.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ID=xonha.voice-tools
PLUGIN=$HOME/.config/omarchy/plugins/$ID
BIN=$HOME/.local/bin
MODE=${1:-}

if [[ $MODE == --uninstall ]]; then
  omarchy-plugin-disable "$ID" >/dev/null 2>&1 || true
  rm -f "$BIN/stt"
  [[ -L $PLUGIN ]] && rm -f "$PLUGIN"
  pkill -f "daemon/sttd.py" 2>/dev/null || true
  echo "uninstalled (history in ~/.local/share/speech-to-text and config in ~/.config/speech-to-text were left alone)"
  echo "If the plugin was added with 'omarchy plugin add', also run: omarchy plugin remove $ID"
  exit 0
fi

missing=()
for c in python3 pw-record pw-play wtype wl-copy wl-paste hyprctl; do
  command -v "$c" >/dev/null 2>&1 || missing+=("$c")
done
if ((${#missing[@]})); then
  echo "error: missing commands: ${missing[*]} (pipewire, wtype, wl-clipboard, hyprland)" >&2
  exit 1
fi
if ! command -v voxtype >/dev/null 2>&1; then
  echo "note: voxtype (Omarchy's dictation engine) is not installed; install it with 'omarchy-voxtype-install' or pick another engine in Settings." >&2
fi

mkdir -p "$BIN" "$(dirname "$PLUGIN")"
ln -sfn "$HERE/bin/stt" "$BIN/stt"
chmod +x "$HERE/bin/stt" "$HERE/daemon/sttd.py"

# A checkout somewhere else is linked in; a checkout that already lives in the
# plugins dir (omarchy plugin add) is used in place.
if [[ $HERE != "$PLUGIN" ]]; then
  if [[ -e $PLUGIN && ! -L $PLUGIN ]]; then
    echo "error: $PLUGIN exists and is not a symlink; remove it first (omarchy plugin remove $ID)" >&2
    exit 1
  fi
  ln -sfn "$HERE" "$PLUGIN"
fi

case ":$PATH:" in *":$BIN:"*) ;; *) echo "note: $BIN is not on your PATH; the key bindings run 'stt' from there." >&2 ;; esac

omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
omarchy-plugin-enable "$ID" --section right >/dev/null 2>&1 || omarchy-plugin-enable "$ID" >/dev/null 2>&1 || true
echo "installed: the Speech to Text icon is in the bar. Default keys: F13 (dictate), CTRL+F13 (dictate and send). Click the icon → Settings to change them."
