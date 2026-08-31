# Dotfiles

CachyOS + Hyprland + Noctalia dotfiles managed with GNU Stow. Run `stow .`
from the repo root to deploy. The previous Archcraft-oriented setup remains on
the `main` branch; the Noctalia migration lives on `noctalia`.

## Index

- [Overview](docs/overview.md) — what this repo does and covers
- [Constitution](docs/constitution.md) — purpose, principles, philosophy
- [Infrastructure](docs/infra.md) — machines, Tailscale network, how to reach each host
- [devbox](docs/devbox.md) — Arch Linux dev container on Bazzite (Podman + systemd)
- [n8n](docs/n8n-bazzite.md) — n8n self-hosted on Bazzite (Podman + Quadlet)
- [Minecraft](docs/minecraft.md) — Crafty Controller on console; Tailscale-only access for friends
- [Storage](docs/storage.md) — 1 TB HDD on console shared over Tailscale via Samba (rootless Podman + Quadlet)
- [Setup notes](.setup/README.md) — wake-from-suspend, udev rules, hardware quirks
- [Stow layout](#stow-layout) — directory map for this repo

## Stow Layout

| Path                          | Purpose                                                     |
| ----------------------------- | ----------------------------------------------------------- |
| `.config/hypr/`               | Hyprland WM — Lua config, custom bindings, focus workflow, window rules and monitor profiles |
| `.config/noctalia/`           | Noctalia shell — bar, launcher, control center, notifications, lock, wallpaper and session UI |
| `.config/kitty/`              | Kitty terminal                                              |
| `.config/nvim/`               | Neovim — LazyVim (`lazy-lock.json` gitignored)              |
| `.config/opencode/`           | OpenCode                                                    |
| `.config/scripts/`            | Custom shell scripts                                        |
| `.tmux.conf`                  | Tmux                                                        |
| `.zshrc` / `.zshenv`          | Zsh + Powerlevel10k (`.p10k.zsh`)                           |
| `.keyd.conf`                  | Keyd keyboard remapping                                     |
| `.ssh/config`                 | SSH host aliases                                            |
| `.docker/Dockerfile`          | devbox container image                                      |
| `.config/containers/systemd/` | Podman Quadlet units for `console` services (Crafty, Samba) |
| `.setup/`                     | Setup scripts sourced by `.install.sh`                      |

## Adding Dotfiles

Drop file under repo root at its `$HOME`-relative path, then re-run `stow .`.

<!-- SPECKIT START -->

For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
at `specs/003-nvim-clipboard-sync/plan.md`.

<!-- SPECKIT END -->
