---
name: dotfiles
description: >
  REQUIRED for changes to this user's Linux dotfiles, setup scripts, desktop
  configuration, systemd services, or development environments. Use when
  editing files under ~/.config/ or ~/.setup/, shell files, Hyprland,
  Omarchy, Dotdrop, Podman containers, or personal service configuration.
  Excludes unrelated application source development.
metadata:
  short-description: Manage Henrique's versioned Linux dotfiles
---

# Dotfiles Skill

Manage this repository as the source of truth for Henrique's personal Linux
configuration. Configuration changes belong in the repository and are applied
to the host with Dotdrop or one of the setup entrypoints.

## When this skill must be used

- Editing files under `config/` or `setup/`
- Changing Hyprland, Omarchy, Foot, Neovim, shell, tmux, Starship, or Git config
- Adding or changing systemd, Quadlet, Podman, Lab, Keeper.sh, or Immich setup
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
| Dotfiles | Versioned user configuration | `config/`, hidden files |
| Setup | Installation and bootstrap | `setup/`, numbered modules |
| Desktop | Hyprland, Omarchy, Foot | `hypr/`, `omarchy/`, `config/foot.ini` |
| Services | Systemd and containers | `config/containers/`, `config/systemd/` |
| Operations | Per-service deploy artifacts and runbooks | `setup/<service>/` |

## Main workflows

### Omarchy and desktop setup

Read [references/omarchy.md](references/omarchy.md) before changing desktop
configuration or Omarchy integration. The main entrypoint is:

```bash
./setup/omarchy-setup.sh
```

  It installs packages, applies the Dotdrop mappings, configures the login shell, and
optionally configures the desktop and services.

### Lab environment

Read [references/lab.md](references/lab.md) before changing `lab`, Quadlet
units, or the Lab image.

Recreating a system such as `lab` is not complete until its applicable
dotfiles are provisioned and verified inside the recreated environment. At
minimum, validate Bash, Starship, and tmux; treat host-only desktop config such
as Foot separately and document that boundary.

```bash
./setup/lab/setup.sh
```

### Dotdrop and linking

Read [references/dotdrop.md](references/dotdrop.md) before changing mappings,
ignore rules, or files that may conflict with existing host configuration.

## Decision framework

1. Is the change a personal configuration? Edit its versioned repository file.
2. Is the component managed by Omarchy? Preserve the native component unless the
   request explicitly asks for an override.
3. Is it installation or bootstrap behavior? Put it in the appropriate numbered
   `setup/` module and reuse `_shared.sh` helpers.
4. Is it a persistent service? Update the setup code and the matching
   `setup/<service>/README.md` runbook.
5. Is it potentially destructive or privileged? Confirm scope, then make the
   smallest reversible change.
6. Validate with the narrowest useful check: shell syntax, Dotdrop dry-run,
   service status, or the relevant application reload. For a recreated system,
   also verify that the expected dotfiles exist in the target and match the
   repository source.

## Topic references

- [references/setup.md](references/setup.md) — setup stages and validation
- [references/dotdrop.md](references/dotdrop.md) — mappings, ownership, and conflicts
- [references/omarchy.md](references/omarchy.md) — Omarchy integration boundaries
- [references/lab.md](references/lab.md) — `lab`, Podman, and Quadlet
- [references/services.md](references/services.md) — system and user services

## Common requests

- “Add a Hyprland shortcut” → edit `hypr/bindings.lua`, then validate or reload Hyprland.
- “Change the Omarchy bar” → inspect `omarchy/shell.json` and preserve Omarchy ownership boundaries.
- “Install a base package” → inspect `setup/10-server-packages.sh`.
- “Change desktop package behavior” → inspect `setup/40-desktop.sh` and its modules.
- “Rebuild `lab`” → follow [references/lab.md](references/lab.md).
- “Change Immich or Keeper.sh” → read `setup/immich/README.md` or `setup/keeper/README.md` before editing.
