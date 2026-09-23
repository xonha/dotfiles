#!/usr/bin/env bash
# Package catalogs shared by setup stages and the Lab image.

# Development tools that belong on both a regular Arch host and an Arch
# development container. yay can install entries from both official repos and
# the AUR, so this list deliberately does not distinguish their origin.
PKG_DEV_COMMON=(
  neovim
  npm
  nvm
  opencode
  uv
  fastfetch
  ripgrep
  socat
  dotdrop
  wget
  tmux
  lazygit
  lazydocker
  starship
)

# Services and host-management tooling. These are intentionally excluded from
# Lab: containers should not run their own Docker daemon, Tailscale or OOM
# manager.
PKG_HOST_ONLY=(
  earlyoom
  tailscale
  docker
)
