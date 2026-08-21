<!--
SYNC IMPACT REPORT
==================
Version change: 1.0.0 → 1.0.1 (PATCH — wording clarification, no semantic change)
Bump rationale: Strengthened the "No secrets in git" bullet to enumerate what
  counts as sensitive (credentials, API keys, tokens, personal data, internal
  addresses) and made the public-repo constraint explicit. No principle was added
  or removed; this is a non-semantic refinement.

Modified principles: None renamed.
Added sections: None.
Removed sections: None.

Templates reviewed:
  ✅ .specify/templates/plan-template.md   — no principle names hard-coded; no update needed.
  ✅ .specify/templates/spec-template.md   — no constitution references; no update needed.
  ✅ .specify/templates/tasks-template.md  — no constitution references; no update needed.
  ✅ .specify/templates/checklist-template.md — not referenced by constitution; no update needed.
  (No commands/ sub-directory exists in templates.)

Deferred TODOs: None.
-->

# Dotfiles Constitution

Governing principles for this Arch Linux dotfiles repository. Any change —
new config, new setup step, new package, new doc — must satisfy these.

## Core Principles

### I. Stow-First, $HOME-Mirrored Layout (NON-NEGOTIABLE)
Every tracked file lives at its `$HOME`-relative path inside the repo. Deployment
happens through `stow .` from the repo root — never hand-copy, never symlink by
hand. Adding a dotfile means dropping it at the correct path and re-running
`stow .`. A file that cannot be expressed as a `$HOME`-relative symlink target
does not belong in this repo.

### II. Reproducible From Bare Metal
`.install.sh` must bootstrap a fresh Arch machine end-to-end. Every system
dependency is declared in a `.setup/` step and installed through the package
manager — no undocumented manual steps, no "remember to also install X". If a
machine needs it, the installer installs it. System tooling is installed
system-wide via `yay`/`pacman`, never vendored into the repo as a project-local
runtime or virtualenv.

### III. Idempotent & Re-Runnable
Every setup step is safe to run repeatedly and safe to run partially. Use
`pacman -S --needed`, tolerate already-enabled services, and never assume a
clean slate. Re-running `.install.sh` on a configured machine converges, it does
not break.

### IV. Server Base, Desktop Additive
`server.sh` is the headless-safe baseline that runs on every machine. `desktop.sh`
is the opt-in GUI layer (Hyprland stack) gated behind a confirmation. A desktop
machine = server packages + desktop packages; a server gets only the base.
Shared/CLI dependencies belong in `server.sh`; GUI-only dependencies belong in
`desktop.sh`. Never put a GUI dependency in the server layer. Services follow the
same split: `SERVICES_ALWAYS` for every machine, `SERVICES_OPTIONAL` prompted
per-machine.

### V. Machine-Specific Stays Untracked
Host-specific and generated files are gitignored, never committed:
`monitors.lua`, `lazy-lock.json`, and anything that differs per machine or is
produced by a tool. The repo holds the portable configuration; the machine
supplies its own specifics.

## Packaging & Dependencies

- **One distro, one helper.** Arch Linux with `yay` as the single package
  front-end (repos + AUR in one call).
- **Official repos before AUR.** Prefer `extra`/`core`; reach for AUR only when
  necessary, and mark every AUR package with the explicit `aur/` prefix in the
  `PKG_*` arrays so provenance is obvious.
- **Declarative package lists.** Packages live in named arrays
  (`PKG_SERVER`, `PKG_DESKTOP`, `PKG_DESKTOP_AUR`, …), not inline `yay -S` calls
  scattered through logic.
- **System tools are system deps.** CLIs used across projects (e.g. `uv`,
  `specify`) are installed at the system level through the installer — the repo
  carries no language-runtime or virtualenv dependency of its own.

## Setup, Docs & Workflow

- **Modular steps.** Each `.setup/*.sh` is one concern, sources `lib.sh`, exposes
  `run()`, and is wired into `.install.sh` in order. Destructive or system-altering
  steps are gated by `confirm_step` or require explicit `sudo`.
- **`CLAUDE.md` is the canonical index.** Every new doc under `docs/` is linked
  from the index. Docs must reflect what `.setup/` actually does — when a step
  changes, its doc changes in the same commit.
- **No secrets in git (PUBLIC REPO).** This repository is public. Nothing that
  could identify a person, expose infrastructure, or grant access MUST ever be
  committed. This includes — but is not limited to — API keys, auth tokens,
  passwords, SSH private keys, personal email addresses, internal hostnames or
  IP addresses, and any credential of any kind. Machine-local secrets stay
  machine-local; service credentials are provisioned outside the repo.
- **Conventional commits.** Keep history readable (`docs:`, `feat:`, `fix:`, …).

## Governance

This constitution supersedes ad-hoc practice. Any change that adds files must
follow the stow layout (Principle I) and update the `CLAUDE.md` index when it
adds a doc. Any change that adds a dependency must place it in the correct layer
(Principle IV) and install it reproducibly (Principle II). Steps that alter the
system must be idempotent (Principle III).

Amendments are made by editing this file and bumping the version below using
semantic versioning: MAJOR for a removed/redefined principle, MINOR for a new
principle or section, PATCH for clarifications. The ratification and amendment
dates are updated on every change.

**Version**: 1.0.1 | **Ratified**: 2026-06-11 | **Last Amended**: 2026-06-11
