#!/usr/bin/env bash
# Install and enable the Noctalia plugins used by these dotfiles.

set -euo pipefail

if ! command -v noctalia >/dev/null 2>&1; then
  printf 'noctalia nao encontrado; instale-o antes de continuar.\n' >&2
  exit 1
fi

if ! noctalia msg status >/dev/null 2>&1; then
  printf 'noctalia nao esta rodando; inicie-o e execute este script novamente.\n' >&2
  exit 1
fi

noctalia msg plugins update community

plugins=(
  "xonha/desktop-controls"
  "icefish/phone-operate"
  "oldirtty/color_picker"
  "yuuto/calculator"
  "noctalia/screen_recorder"
  "nomadcxx/gamer-mode"
  "noctalia/notes"
  "blackbartblues/keymap"
  "raycursive/github-prs"
  "kenn/keybind-cheatsheet"
)

for plugin in "${plugins[@]}"; do
  noctalia msg plugins enable "$plugin"
done

noctalia msg config-reload
printf 'Plugins do Noctalia instalados e habilitados.\n'
