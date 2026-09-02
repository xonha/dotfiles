# Local Development Infrastructure

All machines connected via Tailscale MagicDNS.

## Quick Reference

| Alias | Resolves to | Port | Notes |
|-------|-------------|------|-------|
| `laptop` | `laptop` | 22 | ThinkPad — Arch Linux desktop |
| `maistodos` | `maistodos` | 22 | Work machine — Arch WSL2 |
| `devbot` | `console` | 2223 | Arch dev container on `console`; forwards local :3000 |
| `console` | `console` | 22 | Direct — no alias; see [console access](#console--bazzite-host) |

```bash
ssh laptop       # ThinkPad
ssh maistodos    # work machine (Arch WSL2)
ssh devbot       # Arch devbot container on console (port 2223)
```

> **devbot port forward**: `ssh devbot` automatically binds local port 3000 to
> `localhost:3000` inside the container (for web services running in the dev
> environment). This is intentional — you may see port 3000 appear open on your
> connecting machine while the session is active.

> **console direct access**: No named alias exists for `console` in
> `~/.ssh/config`. Connect directly via Tailscale MagicDNS:
> ```bash
> ssh <your-user>@console
> ```
> To add a `console` alias, add a `Host console` block to `.ssh/config` and
> re-run `stow .` from the repo root — it deploys automatically.

## Machines

| Host | Hardware | OS | Role |
|------|-----------|----|------|
| `laptop` | ThinkPad | Arch Linux | Primary client — Hyprland desktop |
| `console` | Desktop PC | Bazzite (Fedora Silverblue) | Home server — runs containers |
| `maistodos` | Work PC | Windows + Arch WSL2 | Work machine |

## Tailscale

MagicDNS resolves hostnames across all machines. No IP addresses needed for
routine work — use the hostname (e.g., `laptop`, `console`) directly in SSH
and other tools.

```bash
tailscale ip -4      # get this machine's Tailscale IP
tailscale status     # show all peers and their online/offline state
```

## Per-Machine Details

### laptop — ThinkPad (Arch Linux)

Primary development client. Runs Hyprland desktop. No persistent services.
SSH access via the `laptop` alias.

### console — Bazzite Host

Home server running rootless Podman containers as systemd user services.
SSH access via direct connection (`ssh <your-user>@console`) — the `devbot`
alias also lands on this machine (on port 2223, into the container).

### maistodos — Work Machine (Arch WSL2)

Windows host running Arch Linux under WSL2. **Tailscale runs on the Windows
host** — not inside WSL2. Reachability depends on Tailscale being active on
the Windows side. If `ssh maistodos` fails, verify Tailscale is running in
the Windows system tray (not just in the WSL2 environment).

## Services on console

| Container | SSH Port | Service Port | Purpose |
|-----------|----------|--------------|---------|
| `devbot` | 2223 | — | Arch Linux dev environment (see [devbot.md](devbot.md)) |
| `crafty` | — | 8443, 25565 | Minecraft server manager (see [minecraft.md](minecraft.md)) |

Manage services on `console`:

```bash
systemctl --user status devbot.service    # check devbot container
systemctl --user start  devbot.service    # start if stopped
systemctl --user stop   devbot.service    # stop
```

## Troubleshooting

### Peer shows offline in `tailscale status`

**Symptom**: `tailscale status` lists the target machine as offline or
`ssh <alias>` times out immediately.

**Diagnosis**: Tailscale is not running on the remote host.

**Recovery**: Log into the remote machine via another path (console, local
keyboard) and start Tailscale:

```bash
sudo systemctl start tailscaled   # Linux hosts
# Windows: resume Tailscale from the system tray
```

---

### `ssh devbot` times out or refuses (container stopped)

**Symptom**: `tailscale status` shows `console` as **online**, but `ssh devbot`
hangs or returns "Connection refused".

**Diagnosis**: The `devbot` container on `console` is not running. Verify:

```bash
ssh <your-user>@console
systemctl --user status devbot.service
```

**Recovery**:

```bash
systemctl --user start devbot.service
```

---

### `ssh maistodos` times out (Windows Tailscale not running)

**Symptom**: `tailscale status` shows `maistodos` as offline even though the
Windows machine is powered on.

**Diagnosis**: Tailscale is running **only inside WSL2**, not on the Windows
host. WSL2-only Tailscale does not expose the machine to the network.

**Recovery**: Open the Tailscale app in the Windows system tray and ensure it
is connected. Tailscale must run at the Windows level for `maistodos` to be
reachable.

---

### `console` is powered off (devbot and console both unreachable)

**Symptom**: Both `ssh devbot` and `ssh <your-user>@console` fail
simultaneously. `tailscale status` shows `console` as offline.

**Diagnosis**: This is distinct from the container-stopped case — the entire
`console` machine is offline, including `devbot`.

**Recovery**: Power on `console`. `devbot.service` starts automatically on
boot via the user service. No manual intervention is needed once the machine
is on and Tailscale reconnects.

## Typical Workflow

- Code on `laptop` (Arch, local editor) or inside `devbot` (SSH + Neovim).
- Services on `console` accessible from any machine via Tailscale.
- Work tasks on `maistodos` (WSL2 Arch for dev, Windows for meetings/Office).
