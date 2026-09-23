# Dotfiles

Arch dotfiles managed with Dotdrop. The installer detects Omarchy and keeps
Foot and other Omarchy-managed native applications outside Dotdrop. Hyprland and
select Omarchy shell config (bar layout, idle/lock) are tracked here as user
overrides on top of Omarchy's defaults. Run `./.setup/omarchy-setup.sh` for a new
machine.

## Index

- [Infrastructure](.setup/infra.md) — machines, Tailscale network, how to reach each host
- [Lab](.setup/lab/README.md) — Arch Linux development environment on Bazzite
- [Crafty / Minecraft](.setup/crafty/README.md) — Crafty Controller on bazzite; Tailscale-only access for friends
- [Samba / Storage](.setup/samba/README.md) — 1 TB HDD on bazzite shared over Tailscale via Samba (rootless Podman + Quadlet)
- [Immich](.setup/immich/README.md) — photo/video library on bazzite with Podman Compose and Tailscale Funnel
- [Keeper.sh](.setup/keeper/README.md) — calendar sync and MCP server on bazzite, behind Tailscale Serve
- [Setup notes](.setup/README.md) — wake-from-suspend, udev rules, hardware quirks
- [Dotdrop layout](#dotdrop-layout) — directory map for this repo
- [`.config/` vs `.setup/`](#config-vs-setup) — which of the two a new file belongs in

## Dotdrop Layout

| Path                          | Purpose                                                     |
| ----------------------------- | ----------------------------------------------------------- |
| `.config/hypr/`               | Hyprland WM — Lua config, custom bindings, focus workflow, window rules and monitor profiles |
| `.config/omarchy/`            | Omarchy shell overrides — `shell.json` (bar layout, idle/lock), menu extensions, hooks, themes. `branding/`, `defaults/`, `plugins/`, `themed/` stay unstowed (Omarchy-owned) |
| `.config/hyprmoncfg/`         | hyprmoncfg monitor profiles (used by the `crmne.hyprmoncfg` Omarchy bar plugin, installed via `.setup/omarchy-plugins.sh`) |
| `.config/kitty/`              | Kitty terminal                                              |
| `.config/nvim/`               | Neovim — LazyVim (`lazy-lock.json` gitignored)              |
| `.config/opencode/`           | OpenCode                                                    |
| `.config/scripts/`            | Custom shell scripts                                        |
| `.config/starship.toml`       | Starship prompt                                             |
| `.tmux.conf`                  | Tmux                                                        |
| `.bashrc` / `.bash_profile` / `.bash_logout` | Bash (used by tmux panes, which default to Bash) |
| `.ssh/config`                 | SSH host aliases                                            |
| `.config/containers/systemd/` | Podman Quadlet units for `bazzite` services (Crafty, Samba, Keeper, Lab) |
| `.setup/`                     | Bootstrap scripts, plus one directory per service holding its deploy artifacts and runbook (`lab/`, `immich/`, `keeper/`, `crafty/`, `samba/`) |

## `.config/` vs `.setup/`

A file belongs in `.config/` only if the program that reads it reads it from
`$HOME` **on the machine where the repo is stowed** — Quadlet units under
`.config/containers/systemd/` qualify, since systemd reads that exact path.
If the file is instead copied, built, or executed somewhere else (another
host, a container image), it is a deploy artifact and belongs in
`.setup/<service>/`, together with that service's runbook (`README.md`).
`.setup/` is excluded from Dotdrop, so nothing there ever lands in `$HOME` as a
dead symlink.

Immich (`.setup/immich/docker-compose.yml`) and the Keeper env template
(`.setup/keeper/keeper.env.example`) follow this rule: both are `scp`'d or
copied into place rather than read from `$HOME`.

## Adding Dotfiles

Add the mapping to `.dotdrop/config.yaml`, then re-run `dotdrop install`.

<!-- SPECKIT START -->

For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
at `specs/003-nvim-clipboard-sync/plan.md`.

<!-- SPECKIT END -->
