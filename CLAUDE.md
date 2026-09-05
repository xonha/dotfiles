# Dotfiles

Arch dotfiles managed with GNU Stow. The installer detects Omarchy and keeps
Foot and other Omarchy-managed native applications outside Stow. Hyprland and
select Omarchy shell config (bar layout, idle/lock) are tracked here as user
overrides on top of Omarchy's defaults. Run `./.setup/install.sh` for a new
machine.

## Index

- [Infrastructure](.docs/infra.md) — machines, Tailscale network, how to reach each host
- [Toolbox](.docs/toolbox.md) — Arch Linux development containers on Bazzite
- [Minecraft](.docs/minecraft.md) — Crafty Controller on bazzite; Tailscale-only access for friends
- [Storage](.docs/storage.md) — 1 TB HDD on bazzite shared over Tailscale via Samba (rootless Podman + Quadlet)
- [Setup notes](.setup/README.md) — wake-from-suspend, udev rules, hardware quirks
- [Stow layout](#stow-layout) — directory map for this repo

## Stow Layout

| Path                          | Purpose                                                     |
| ----------------------------- | ----------------------------------------------------------- |
| `.config/hypr/`               | Hyprland WM — Lua config, custom bindings, focus workflow, window rules and monitor profiles |
| `.config/omarchy/`            | Omarchy shell overrides — `shell.json` (bar layout, idle/lock), menu extensions, hooks, themes. `branding/`, `defaults/`, `plugins/`, `themed/` stay unstowed (Omarchy-owned) |
| `.config/hyprmoncfg/`         | hyprmoncfg monitor profiles (used by the `crmne.hyprmoncfg` Omarchy bar plugin, installed via `.setup/desktop/omarchy-plugins.sh`) |
| `.config/kitty/`              | Kitty terminal                                              |
| `.config/nvim/`               | Neovim — LazyVim (`lazy-lock.json` gitignored)              |
| `.config/opencode/`           | OpenCode                                                    |
| `.config/scripts/`            | Custom shell scripts                                        |
| `.config/starship.toml`       | Starship prompt                                             |
| `.tmux.conf`                  | Tmux                                                        |
| `.bashrc` / `.bash_profile` / `.bash_logout` | Bash (used by tmux panes, which default to Bash) |
| `.ssh/config`                 | SSH host aliases                                            |
| `.config/containers/systemd/` | Podman Quadlet units for `bazzite` services (Crafty, Samba) |
| `.setup/`                     | Setup scripts and the `devbot` container image              |

## Adding Dotfiles

Drop file under repo root at its `$HOME`-relative path, then re-run `stow .`.

<!-- SPECKIT START -->

For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
at `specs/003-nvim-clipboard-sync/plan.md`.

<!-- SPECKIT END -->
