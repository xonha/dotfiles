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
# Lab: containers should not run their own container engine, Tailscale or OOM
# manager.
#
# Podman replaces Docker: podman-docker provides the `docker` CLI shim (it
# conflicts with the docker package) and docker-compose is the provider used by
# `podman compose` and by projects that still call `docker-compose` directly.
# podman-tui (AUR) talks to the local Podman engine, so it stays host-only.
# docker-buildx gives Compose a BuildKit builder (see setup/50-services.sh);
# without it Compose falls back to the classic builder, which lacks build ssh.
PKG_HOST_ONLY=(
  earlyoom
  tailscale
  podman
  podman-docker
  podman-tui-bin
  docker-compose
  docker-buildx
)
