# Dotfiles

CachyOS + Hyprland + Noctalia dotfiles managed with GNU Stow. Run `stow .`
from the repo root to deploy, or `./.install.sh` for a new machine.

## Index

- [Infrastructure](.setup/docs/infra.md) — machines, Tailscale network, how to reach each host
- [devbot](.setup/docs/devbot.md) — Arch Linux development container on Bazzite
- [Minecraft](.setup/docs/minecraft.md) — Crafty Controller on console; Tailscale-only access for friends
- [Storage](.setup/docs/storage.md) — 1 TB HDD on console shared over Tailscale via Samba (rootless Podman + Quadlet)
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
| `.config/containers/systemd/` | Podman Quadlet units for `console` services (Crafty, Samba) |
| `.setup/`                     | Setup scripts and the `devbot` container image              |

## Adding Dotfiles

Drop file under repo root at its `$HOME`-relative path, then re-run `stow .`.

<!-- SPECKIT START -->

For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
at `specs/003-nvim-clipboard-sync/plan.md`.

<!-- SPECKIT END -->
