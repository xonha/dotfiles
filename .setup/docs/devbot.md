# devbot — Arch Linux Dev Container on Bazzite

Arch Linux container running under rootless Podman on a Bazzite host, auto-started via systemd user service.

## Specs

| | |
|-|-|
| Container name | `devbot` |
| Hostname | `devbot` |
| Image | `devbot:latest` (built from `.setup/devbot/Dockerfile`) |
| SSH | host port `2222` → container port `22` |
| Workspace | `~/devbot/workspace` → `/workspace` (bind mount) |
| Memory | 14 GB RAM + 14 GB swap |
| User | `henrique` (UID 1000, passwordless sudo, SSH key only) |
| Systemd unit | `~/.config/systemd/user/devbot.service` |

## Access

```bash
# From Bazzite host
podman exec -it devbot bash

# Via SSH (any Tailscale machine)
ssh -p 2222 henrique@console
# or use the SSH alias in ~/.ssh/config: ssh devbot
```

## Manage

```bash
systemctl --user [start|stop|restart|status] devbot.service
journalctl --user -u devbot.service -f
```

## First-Time Setup

```bash
# From the dotfiles repository root:
mkdir -p ~/devbot/workspace
podman build -t devbot:latest -f .setup/devbot/Dockerfile .setup/devbot
podman create --name devbot --hostname devbot \
  --memory 14g --memory-swap 14g --pids-limit 4096 \
  -p 2222:22 \
  -v ~/.ssh/id_ed25519.pub:/run/host_ssh_key:ro,Z \
  -v ~/devbot/workspace:/workspace:Z \
  -w /workspace devbot:latest
podman generate systemd --name devbot --files
mkdir -p ~/.config/systemd/user
mv container-devbot.service ~/.config/systemd/user/devbot.service
systemctl --user daemon-reload
systemctl --user enable --now devbot.service
loginctl enable-linger $USER
```

## Rebuild After Dockerfile Changes

```bash
# From the dotfiles repository root:
podman build --no-cache -t devbot:latest -f .setup/devbot/Dockerfile .setup/devbot
systemctl --user stop devbot.service
podman rm -f devbot
# re-run podman create ... (same flags as above)
systemctl --user start devbot.service
```

## Notes

- Uses rootless Podman — CPU pinning (`--cpuset-cpus`) requires rootful.
- `--new` flag omitted from `generate systemd` so writable-layer data persists across restarts.
- Linger must be enabled for boot-time start without user login.
