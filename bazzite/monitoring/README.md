# Bazzite monitoring

Deploy from the client with `bash bazzite/monitoring/setup.sh`.
The timer checks all 13 containers every five minutes, media mount, application
HTTP endpoints, SSH banner, SMB port, PostgreSQL and Redis readiness, and ML ping.
Failures appear in `journalctl --user -u bazzite-healthcheck.service`.
The monitor reports failures without restarting applications with active work.

Optional independent Healthchecks check: create
`~/.config/bazzite-monitoring/health.env` on Bazzite, mode 600, containing
`HEALTHCHECKS_URL=https://hc-ping.com/PRIVATE_CHECK_ID`.
Use a separate check from Immich: sharing a URL lets healthy Immich heartbeats
hide failures in other services. Configure its period to five minutes and grace
time to at least three minutes and enable the email integration.

Quadlet restart policies use a 30-second retry interval and disable the start
rate limit so network or storage delays do not permanently exhaust retries.
Mediarium and Jellyfin already gate startup on the expected media disk.
Samba uses mount propagation from the parent media directory.
Immich retains its separate mount-aware recovery and serialized Compose startup.
Podman boot restart owns the Compose stack; Quadlets use systemd restart policies.

Initial audit found Lab SSH unresponsive and ML with a stale running state
(the recorded process no longer existed). Restarting Lab and stopping/starting
ML restored both probes. Lab now runs the versioned SSH healthcheck with
HealthOnFailure=kill so systemd can recover it.
Container-running checks for cloudflared do not prove external tunnel reachability;
SMB TCP checks do not validate authenticated file access or write permissions.
No reboot or destructive recovery was performed during this audit.
