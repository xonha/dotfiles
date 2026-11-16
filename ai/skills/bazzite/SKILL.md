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

## Current service architecture and monitoring

- Bazzite runs rootless Podman as `henrique` with lingering enabled. Most
  services are Quadlets managed by user systemd; Immich is a Compose stack
  under `~/immich`. Read `bazzite/monitoring/README.md` for the current list
  of monitored services and deployment procedure.
- `bazzite-healthcheck.timer` runs a host-side script every five minutes. It
  checks container state, the media mount, application HTTP endpoints, Lab SSH,
  Samba TCP, PostgreSQL, Redis, and Immich machine learning. Failures are in
  `journalctl --user -u bazzite-healthcheck.service`. The script reports
  failures; it does not automatically restart every service.
- `bazzite-health-endpoint.service` exposes only `127.0.0.1:8297/healthz`.
  Cloudflare Tunnel publishes it at `https://monitor.plu.nz/healthz`. It returns
  200 when the host-side monitor completed a run within 12 minutes and 503
  otherwise. It reveals no individual service status. A successful response
  means the monitor ran recently, not that every service passed.
- UptimeRobot was requested for that public endpoint using
  `henriquecastro1198@gmail.com`. Its API accepted the request, but the user
  must confirm the activation email. Other requested public monitors cover
  Immich, Jellyfin, Mediarium, and Keeper; do not assume they are activated
  without checking the UptimeRobot account. Private services are not directly
  reachable by UptimeRobot.
- Healthchecks.io has an Immich heartbeat in
  `~/.config/immich/healthcheck.env` on the host. The generic monitor accepts
  an optional separate URL in `~/.config/bazzite-monitoring/health.env`, but
  it has not been configured. There are no per-service Healthchecks checks yet.
  A single shared URL cannot give independent alerts per service. Successful
  pings are silent; `/fail` actively reports a failure. Email delivery also
  depends on a verified, enabled integration in the Healthchecks account.
- Public traffic for `immich.plu.nz`, `jellyfin.plu.nz`, `mediarium.plu.nz`,
  `keeper.plu.nz`, and `monitor.plu.nz` uses the `bazzite-immich` Cloudflare
  Tunnel. Tailscale Serve/Funnel has separate routes; several other services
  remain private to the tailnet. Check the current Cloudflare ingress and DNS
  before changing exposure.

## Failure patterns already observed

- `podman-restart.service` starts all Compose containers with `restart=always`
  at boot. It previously raced Immich startup and a removable-media mount,
  leading to bind mount errors and conmon coredumps. Its override waits for
  `/run/media/system/hd`; `immich-start.service` runs after it and uses the
  serialized recovery script. Verify the mount is `/dev/sdb1` before recovery.
- Immich's recovery script needs `~/.local/bin` in PATH and the rootless
  `podman-compose` provider. Without that environment, systemd recovery failed
  despite interactive Compose working. Its timer runs every five minutes;
  avoid rapid `Restart=on-failure` loops for one-shot health checks.
- A Podman container may report `running` after its process has died. This
  happened to `immich_machine_learning`: `podman exec` failed until the
  container was stopped and started. Check the recorded PID and an application
  endpoint, not just `podman ps`.
- Lab's original SSH probe referenced a file missing from the installed image,
  causing `HealthOnFailure=kill` to restart a working container repeatedly.
  The versioned Quadlet now uses an inline SSH banner check. Validate the
  health command inside the actual image after any image or Quadlet update.
- Quadlet restart policies now use a 30-second interval and no start rate
  limit, avoiding permanent failure after transient network or media delays.
  Confirm generated user units match versioned Quadlets after deployment.

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
- `bazzite/monitoring/README.md` — monitor, public health endpoint, and alerts
