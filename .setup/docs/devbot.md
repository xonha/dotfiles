# devbot — Arch Linux Dev Container on Bazzite

Devbot is a rootless Podman Quadlet on `console`. Its container definition and
image recipe are versioned; its state is explicit and survives image rebuilds.

## Specs

| | |
|-|-|
| Container / service | `devbot` / `devbot.service` |
| Image | `localhost/devbot:latest`, built from `.setup/devbot/Dockerfile` |
| SSH | host port `2223` → container port `22` |
| Workspace | `~/devbot/workspace` → `/workspace` (bind mount) |
| Home | named volume `devbot-home` → `/home/henrique` |
| User | `henrique` (UID 1000, passwordless sudo, SSH key only) |
| Limits | 14 GB RAM; 4096 PIDs |
| Quadlets | `~/.config/containers/systemd/devbot.container` and `devbot-home.volume` |

The authorized keys from `~/.ssh/authorized_keys` on `console` are mounted
read-only and copied into the container home at every start.

## Access

```bash
# From a Tailscale machine
ssh -p 2223 henrique@console
# or use the SSH alias in ~/.ssh/config: ssh devbot

# On console
podman exec -it -u henrique devbot bash
```

## Manage

```bash
systemctl --user [start|stop|restart|status] devbot.service
journalctl --user -u devbot.service -f
```

## First-time setup

On `console`, clone or update this repository, apply it with Stow, then run:

```bash
cd ~/Dotfiles
stow .
./.setup/devbot/install.sh
```

The installer builds the image, creates `~/devbot/workspace`, reloads the
user units, starts `devbot.service`, and enables user lingering. Its Quadlet
`[Install]` section starts it after boot without an interactive login.

## Rebuild After Dockerfile Changes

```bash
cd ~/Dotfiles
./.setup/devbot/install.sh
```

## Notes

The workspace bind mount and `devbot-home` volume are retained. To deliberately
remove the development home, stop the service and delete that named volume:

```bash
systemctl --user stop devbot.service
podman volume rm devbot-home
```
