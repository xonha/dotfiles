---
name: dotfiles
description: >
  REQUIRED for changes to this user's versioned Linux dotfiles, setup scripts,
  desktop configuration, or development environment. Use when editing files
  under ~/.config/ or ~/.setup/, shell files, Hyprland, Omarchy, Dotdrop, or
  repository-owned setup and deployment artifacts.
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
- Adding or changing repository-owned setup and deployment artifacts
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
| Services | Versioned service units and deployment artifacts | `config/systemd/`, `bazzite/` |
| Operations | Per-service deploy artifacts and runbooks | `setup/<service>/` |

## Naming conventions

Prefer `snake_case` for new files and for files being renamed, for example
`pkg_client.sh`, `pkg_server.sh`, and `thinkpad_usb_wakeup.rules`. Preserve a
different naming convention only when it is required by an external tool,
systemd/udev filename contract, upstream project, or an existing public
interface that would break if renamed. When renaming a file, update all
callers, documentation, build contexts, and installation targets.

## Configuration layers

Keep the repository organized by scope. A change must be placed in the
narrowest layer that owns it, so generic setup remains reusable across future
machines and distributions.

### Client machines

- **Generic client layer**: shared desktop/user tools and client packages for
  Arch-based systems. Keep these in `setup/` (for example,
  `pkg_client.sh`, `bash.sh`, `dotfiles.sh`, and `udev/` when the rule is
  hardware-oriented rather than distribution-oriented).
- **Distribution layer**: configuration that depends on a particular desktop
  distribution or environment. Omarchy-specific orchestration and plugins
  belong in `omarchy/`.
- **Hardware layer**: rules tied to a physical model or device belong under a
  hardware-specific path, such as `setup/udev/` for the ThinkPad USB wake rule.
  Do not name hardware configuration after Omarchy merely because the current
  machine runs Omarchy. Future hardware variants, such as Dell, should be
  independently selectable.

Current client targets include:

- `omarchy` — current Omarchy client, composed from generic client setup plus
  Omarchy-specific setup and applicable ThinkPad hardware setup;
- `arch` — hypothetical plain Arch or another Arch-based client using only the
  generic layers and any matching hardware layer;
- hardware variants such as `thinkpad` and future `dell` — selected by device,
  independently of the distribution.

### Server and Bazzite boundary

Generic server setup belongs in `setup/`. Bazzite-specific deployment artifacts
belong in `bazzite/`, while runtime operation and troubleshooting of the host
belongs to the [`bazzite` skill](../bazzite/SKILL.md). Do not move a module into
`bazzite/` solely because a Bazzite orchestrator calls it; move it only when its
behavior depends on that host environment.

## Main workflows

### Omarchy and desktop setup

Read [references/omarchy.md](references/omarchy.md) before changing desktop
configuration or Omarchy integration. The main entrypoint is:

```bash
./omarchy/setup.sh
```

It installs generic client packages, applies Dotdrop mappings, configures the
login shell, and then applies Omarchy-specific plugins and services.

### Bazzite services

For runtime operations, read and use the `bazzite` skill. For repository edits,
read the matching service runbook and setup script here, then validate the
versioned artifact and hand off host execution to the `bazzite` workflow.

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
- [references/services.md](references/services.md) — repository-owned service configuration

## Common requests

- “Add a Hyprland shortcut” → edit `hypr/bindings.lua`, then validate or reload Hyprland.
- “Change the Omarchy bar” → inspect `omarchy/shell.json` and preserve Omarchy ownership boundaries.
- “Install a base package” → decide first whether it is generic client/server,
  Omarchy-specific, hardware-specific, or environment-specific; then inspect
  the narrowest applicable module.
- “Change client packages” → inspect `setup/pkg_client.sh`; keep packages
  reusable across Arch-based clients unless they depend on Omarchy.
- “Change Omarchy-specific setup” → inspect `omarchy/setup.sh` and
  `omarchy/plugins.sh`.
- “Change hardware wake or device rules” → inspect `setup/udev/` and keep the
  filename and path tied to the hardware, not the current distribution.
- “Operate or troubleshoot Bazzite, Lab, Immich, Keeper.sh, Crafty, or Samba” → use the `bazzite` skill.
- “Change the versioned Immich or Keeper.sh deployment” → read the matching Bazzite runbook before editing.
