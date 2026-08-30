# devbox — Arch Linux Dev Container on Bazzite

Arch Linux container running under rootless Podman on a Bazzite host, auto-started via systemd user service.

## Specs

| | |
|-|-|
| Container name | `devbox` |
| Hostname | `devbox` |
| Image | `devbox:latest` (built from `.docker/Dockerfile`) |
| SSH | host port `2222` → container port `22` |
| Workspace | `~/devbox/workspace` → `/workspace` (bind mount) |
| Memory | 14 GB RAM + 14 GB swap |
| User | `henrique` (UID 1000, passwordless sudo) |
| Systemd unit | `~/.config/systemd/user/devbox.service` |

## Access

```bash
# From Bazzite host
podman exec -it devbox bash

# Via SSH (any Tailscale machine)
ssh -p 2222 henrique@console
# or use the SSH alias in ~/.ssh/config: ssh devbox
```

## Manage

```bash
systemctl --user [start|stop|restart|status] devbox.service
journalctl --user -u devbox.service -f
```

## First-Time Setup

```bash
mkdir -p ~/devbox-image ~/devbox/workspace
# Copy Dockerfile content to ~/devbox-image/Dockerfile
podman build -t devbox:latest ~/devbox-image
podman create --name devbox --hostname devbox \
  --memory 14g --memory-swap 14g --pids-limit 4096 \
  -p 2222:22 -v ~/devbox/workspace:/workspace:Z \
  -w /workspace devbox:latest
podman generate systemd --name devbox --files
mkdir -p ~/.config/systemd/user
mv container-devbox.service ~/.config/systemd/user/devbox.service
systemctl --user daemon-reload
systemctl --user enable --now devbox.service
loginctl enable-linger $USER
```

## Rebuild After Dockerfile Changes

```bash
podman build --no-cache -t devbox:latest ~/devbox-image
systemctl --user stop devbox.service
podman rm -f devbox
# re-run podman create ... (same flags as above)
systemctl --user start devbox.service
```

## Notes

- Uses rootless Podman — CPU pinning (`--cpuset-cpus`) requires rootful.
- `--new` flag omitted from `generate systemd` so writable-layer data persists across restarts.
- Linger must be enabled for boot-time start without user login.
