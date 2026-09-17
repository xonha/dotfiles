---
name: dotfiles
description: >
  REQUIRED for changes to this user's Linux dotfiles, setup scripts, desktop
  configuration, systemd services, or development environments. Use when
  editing files under ~/.config/, ~/.setup/, ~/.docs/, shell files, Hyprland,
  Omarchy, GNU Stow, Podman Toolbox, or personal service configuration.
  Excludes unrelated application source development.
metadata:
  short-description: Manage Henrique's versioned Linux dotfiles
---

# Dotfiles Skill

Manage this repository as the source of truth for Henrique's personal Linux
configuration. Configuration changes belong in the repository and are applied
to the host with GNU Stow or one of the setup entrypoints.

## When this skill must be used

- Editing files under `.config/`, `.setup/`, or `.docs/`
- Changing Hyprland, Omarchy, Foot, Neovim, shell, tmux, Starship, or Git config
- Adding or changing systemd, Quadlet, Podman, Toolbox, Keeper.sh, or Immich setup
- Running or changing the repository bootstrap and setup flows
- Deciding whether a configuration should be owned by this repository or Omarchy

Do not use this skill for unrelated application source code or generic Linux
questions that do not affect this dotfiles repository.

## Source of truth and safety rules

- Edit the versioned file in this repository, not its symlinked target in `$HOME`.
- Inspect `git status` before editing and preserve unrelated user changes.
- Do not overwrite Omarchy-managed components without an explicit request.
- Prefer the existing setup modules and shared helpers over duplicating logic.
- Ask for confirmation before destructive resets, removals, or broad service changes.
- Use `sudo` only for the privileged operation that actually requires it.
- After changes, validate the affected configuration and report what was applied.

## Repository architecture

| Area | Responsibility | Location |
|---|---|---|
| Dotfiles | Versioned user configuration | `.config/`, hidden files |
| Setup | Installation and bootstrap | `.setup/` |
| Desktop | Hyprland, Omarchy, Foot | `.config/hypr/`, `.config/omarchy/`, `.config/foot/` |
| Services | Systemd and containers | `.config/containers/`, `.config/systemd/` |
| Operations | Service-specific procedures | `.docs/` |

## Main workflows

### Omarchy and desktop setup

Read [references/omarchy.md](references/omarchy.md) before changing desktop
configuration or Omarchy integration. The main entrypoint is:

```bash
./.setup/omarchy-setup.sh
```

It installs packages, stows the dotfiles, configures the login shell, and
optionally configures the desktop and services.

### Toolbox environments

Read [references/toolbox.md](references/toolbox.md) before changing `lab`,
Quadlet units, or the Toolbox image.

```bash
./.setup/toolbox-setup.sh
```

### Stow and linking

Read [references/stow.md](references/stow.md) before changing ownership,
ignore rules, or files that may conflict with existing host configuration.

## Decision framework

1. Is the change a personal configuration? Edit its versioned repository file.
2. Is the component managed by Omarchy? Preserve the native component unless the
   request explicitly asks for an override.
3. Is it installation or bootstrap behavior? Put it in the appropriate numbered
   `.setup/` module and reuse `_shared.sh` helpers.
4. Is it a persistent service? Update the setup code and the matching `.docs/`
   operational guide.
5. Is it potentially destructive or privileged? Confirm scope, then make the
   smallest reversible change.
6. Validate with the narrowest useful check: shell syntax, Stow dry-run,
   service status, or the relevant application reload.

## Topic references

- [references/setup.md](references/setup.md) — setup stages and validation
- [references/stow.md](references/stow.md) — ownership, exclusions, and conflicts
- [references/omarchy.md](references/omarchy.md) — Omarchy integration boundaries
- [references/toolbox.md](references/toolbox.md) — `lab`, Podman, and Quadlet
- [references/services.md](references/services.md) — system and user services

## Common requests

- “Add a Hyprland shortcut” → edit `.config/hypr/bindings.lua`, then validate or reload Hyprland.
- “Change the Omarchy bar” → inspect `.config/omarchy/shell.json` and preserve Omarchy ownership boundaries.
- “Install a base package” → inspect `.setup/10-server-packages.sh`.
- “Change desktop package behavior” → inspect `.setup/40-desktop.sh` and its modules.
- “Rebuild `lab`” → follow [references/toolbox.md](references/toolbox.md).
- “Change Immich or Keeper.sh” → read the matching guide under `.docs/` before editing.
