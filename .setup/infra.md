# Local Development Infrastructure

All machines connected via Tailscale MagicDNS.

## Quick Reference

| Alias | Resolves to | Port | Notes |
|-------|-------------|------|-------|
| `omarchy` | `omarchy` | 22 | ThinkPad T495 — Omarchy (Arch Linux) desktop |
| `maistodos` | `maistodos` | 22 | Work machine — Arch WSL2 |
| `lab` | `bazzite` | 2224 | Arch development container; forwards local :3000 |
| `bazzite` | `bazzite` | 22 | Direct — no alias; see [bazzite access](#bazzite--bazzite-host) |

```bash
ssh omarchy      # ThinkPad T495 (Omarchy)
ssh maistodos    # work machine (Arch WSL2)
ssh lab          # Arch development container on bazzite (port 2224)
```

> **lab port forward**: `ssh lab` automatically binds local port 3000 to
> `localhost:3000` inside the development container.

> **bazzite direct access**: No named alias exists for `bazzite` in
> `~/.ssh/config`. Connect directly via Tailscale MagicDNS:
> ```bash
> ssh <your-user>@bazzite
> ```
> To add a `bazzite` alias, add a `Host bazzite` block to `.ssh/config` and
> re-run `dotdrop install --cfg .dotdrop/config.yaml --profile omarchy` from the repo root — it deploys automatically.

## Machines

| Host | Hardware | OS | Role |
|------|-----------|----|------|
| `omarchy` | ThinkPad T495 | Arch Linux (Omarchy) | Primary client — Hyprland desktop |
| `bazzite` | Desktop PC | Bazzite (Fedora Silverblue) | Home server — runs containers |
| `maistodos` | Work PC | Windows + Arch WSL2 | Work machine |

## Tailscale

MagicDNS resolves hostnames across all machines. No IP addresses needed for
routine work — use the hostname (e.g., `omarchy`, `bazzite`) directly in SSH
and other tools.

```bash
tailscale ip -4      # get this machine's Tailscale IP
tailscale status     # show all peers and their online/offline state
```

## Per-Machine Details

### omarchy — ThinkPad T495 (Omarchy, Arch Linux)

Primary development client. Runs Omarchy (Hyprland-based). No persistent
services. SSH access via the `omarchy` alias. Formerly aliased `laptop`,
running a hand-rolled CachyOS/Hyprland/Noctalia desktop before migrating to
Omarchy — see CLAUDE.md's Stow Layout notes for what's still versioned as
Hyprland overrides on top of Omarchy's defaults.

### bazzite — Bazzite Host

Home server running rootless Podman containers as systemd user services.
SSH access via direct connection (`ssh <your-user>@bazzite`). The `lab` alias
lands on the development container through port 2224.

### maistodos — Work Machine (Arch WSL2)

Windows host running Arch Linux under WSL2. **Tailscale runs on the Windows
host** — not inside WSL2. Reachability depends on Tailscale being active on
the Windows side. If `ssh maistodos` fails, verify Tailscale is running in
the Windows system tray (not just in the WSL2 environment).

## Services on bazzite

| Container | SSH Port | Service Port | Purpose |
|-----------|----------|--------------|---------|
| `lab` | 2224 | — | Arch development environment (see [lab/README.md](lab/README.md)) |
| `crafty` | — | 8443, 25565 | Minecraft server manager (see [crafty/README.md](crafty/README.md)) |

Manage services on `bazzite`:

```bash
systemctl --user status lab.service
systemctl --user start lab.service
```

## Troubleshooting

### Peer shows offline in `tailscale status`

**Symptom**: `tailscale status` lists the target machine as offline or
`ssh <alias>` times out immediately.

**Diagnosis**: Tailscale is not running on the remote host.

**Recovery**: Log into the remote machine via another path (bazzite, local
keyboard) and start Tailscale:

```bash
sudo systemctl start tailscaled   # Linux hosts
# Windows: resume Tailscale from the system tray
```

---

### `ssh lab` times out or refuses (container stopped)

**Symptom**: `tailscale status` shows `bazzite` as **online**, but `ssh lab`
hangs or returns "Connection refused".

**Diagnosis**: The `lab` container on `bazzite` is not running. Verify:

```bash
ssh <your-user>@bazzite
systemctl --user status lab.service
```

**Recovery**:

```bash
systemctl --user start lab.service
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

### `bazzite` is powered off (lab and bazzite both unreachable)

**Symptom**: Both `ssh lab` and `ssh <your-user>@bazzite` fail
simultaneously. `tailscale status` shows `bazzite` as offline.

**Diagnosis**: This is distinct from the container-stopped case — the entire
`bazzite` machine is offline, including `lab`.

**Recovery**: Power on `bazzite`. `lab.service` starts automatically on
boot via the user service. No manual intervention is needed once the machine
is on and Tailscale reconnects.

## Typical Workflow

- Code on `omarchy` (Arch, local editor) or inside `lab` (SSH + Neovim).
- Services on `bazzite` accessible from any machine via Tailscale.
- Work tasks on `maistodos` (WSL2 Arch for dev, Windows for meetings/Office).
