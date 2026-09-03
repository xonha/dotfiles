#!/usr/bin/env bash
# Install and enable the Noctalia plugins used by these dotfiles.

set -euo pipefail

run() {
  if ! command -v noctalia >/dev/null 2>&1; then
    printf 'noctalia nao encontrado; instale-o antes de continuar.\n' >&2
    return 1
  fi

  if ! noctalia msg status >/dev/null 2>&1; then
    printf 'noctalia nao esta rodando; inicie-o e execute este script novamente.\n' >&2
    return 1
  fi

  if [[ ${1:-} == "--update" ]]; then
    noctalia msg plugins update community
  fi

  local plugins=(
    "xonha/desktop-controls"
    "icefish/phone-connect"
    "oldirtty/color_picker"
    "noctalia/screen_recorder"
    "nomadcxx/gamer-mode"
    "noctalia/notes"
    "blackbartblues/keymap"
    "blackbartblues/audio-switcher"
    "raycursive/github-prs"
    "kenn/keybind-cheatsheet"
  )

  local plugin
  for plugin in "${plugins[@]}"; do
    noctalia msg plugins enable "$plugin"
  done

  noctalia msg config-reload
  printf 'Plugins do Noctalia instalados e habilitados.\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
