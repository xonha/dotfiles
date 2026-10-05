---
name: bazzite
description: >
  REQUIRED for operating, troubleshooting, deploying, or changing services on
  Henrique's Bazzite host, including Podman, Compose, Quadlet, systemd user
  services, storage mounts, Tailscale, Lab, Immich, Keeper.sh, Crafty, and
  Samba. Use for host operations even when the deployment files live in the
  dotfiles repository.
metadata:
  short-description: Operate Henrique's Bazzite host and services
---

# Bazzite Skill

Treat the Bazzite host as a distinct server environment. Use this skill for
runtime operations and service administration; use `dotfiles` for repository
ownership, versioned configuration, and setup code.

## Scope

- Diagnose host connectivity, mounts, disk space, permissions, and boot state.
- Operate rootless Podman and `podman compose` containers.
- Manage user systemd services, Quadlet units, linger, and restart behavior.
- Deploy or troubleshoot services under `bazzite/` such as Lab, Immich,
  Keeper.sh, Crafty, and Samba.
- Check Tailscale Serve/Funnel and local service reachability.

## Source of truth and safety

- Inspect the repository's service runbook and deployment artifact before
  changing a service.
- Keep versioned files in the repository authoritative; do not edit generated
  copies on the host unless the operation explicitly requires it.
- Preserve persistent data, especially Immich media and PostgreSQL data.
- Before starting a service that uses removable storage, verify the expected
  filesystem is mounted at the documented path.
- Prefer reversible, narrow operations. Do not run `podman compose down`, remove
  volumes, reset state, or delete data as routine recovery.
- Report the host, container/service state, relevant logs, and validation result.

## Workflow

1. Identify the target host and service.
2. Read the matching runbook in `bazzite/<service>/README.md` and inspect the
   versioned deployment files.
3. Check connectivity, mounts, `podman ps -a`, user systemd status, and recent
   logs before mutating state.
4. Apply the smallest safe recovery or deployment action.
5. Verify container health, local HTTP reachability where applicable, storage
   paths, and persistence across the configured restart mechanism.

## Repository boundary

When the requested change affects files in this repository, use `dotfiles` as
the companion skill. `dotfiles` may route Bazzite-specific runtime work back to
this skill. Do not move generic setup code into `bazzite/` merely because it is
called from a Bazzite orchestrator.

## References

- `bazzite/README.md` — host-level setup and entrypoints
- `bazzite/immich/README.md` — Immich storage, Compose, and Funnel operations
- `bazzite/keeper/README.md` — Keeper.sh deployment
- `bazzite/crafty/README.md` — Crafty deployment
- `bazzite/lab/README.md` — Lab image and container environment
- `bazzite/samba/README.md` — Samba service
