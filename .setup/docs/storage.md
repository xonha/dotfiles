# Storage — 1 TB HDD Shared over Tailscale

The 1 TB spinning disk in `console` is exposed to the whole tailnet as an SMB
share, so any machine (Nemo, Windows Explorer, phone, TV) can browse it as a
regular network drive. Samba runs as a **rootless** Podman container managed by
a systemd user service via Podman Quadlet, listening **only** on the Tailscale
IP — never on the LAN or the internet.

## Architecture

| Item | Value |
|------|-------|
| Disk | `/dev/sdb1`, ext4, label `hd`, 931.5 GB (`ST1000DM010-2EP102`) |
| Host mount | `/run/media/system/hd`, mounted by `ublue-os-media-automount.service` |
| Container | `ghcr.io/servercontainers/samba:latest`, rootless, user `henrique` |
| Share name | `Storage` → `smb://console/storage` |
| Listen address | `100.120.120.72:445` (Tailscale IP only) |
| Quadlet unit | `.config/containers/systemd/samba.container` in this repo |
| Credentials | `~/.config/containers/systemd/samba.env` (mode 600, gitignored) |

## Why the Unit Looks the Way It Does

Four decisions in `samba.container` are non-obvious and easy to "fix" into
breakage. They are commented inline, and explained here:

**`Volume=/run/media/system:/shares:rslave`** — mounts the *parent* directory,
not the disk itself. The disk is mounted by `run-media-system-hd.mount`, a
**system** unit, but this is a **user** unit, and a user unit cannot
`Requires=`/`After=` a system unit. Since `/run` is a `shared` mount,
binding the parent with `rslave` makes the disk propagate into the container
whenever the automount brings it up — even if that happens after the container
started. Binding `/run/media/system/hd` directly would pin an empty directory
on a boot where the container wins the race. Only the share declared in
`SAMBA_VOLUME_CONFIG_storage` is actually exposed over SMB.

**`SecurityLabelDisable=true`** — no `:z`/`:Z` on the volume, on purpose. The
disk holds files labelled `unlabeled_t` (`hydra/`, `SteamLibrary/`) and a
recursive relabel would rewrite the SELinux labels Steam currently relies on.
`label=disable` exempts only this container and writes nothing to the disk.

**`force user = root`** in the share config — counterintuitive but correct
*because* the container is rootless: container UID 0 maps to `henrique`
(UID 1000) on the host, which owns the disk. Without it smbd would write as
container UID 1000, which maps to a subuid, and every new file would land with
broken ownership.

**Port 445 needs a sysctl** — rootless Podman cannot bind a privileged port.
`/etc/sysctl.d/99-unprivileged-smb.conf` lowers
`net.ipv4.ip_unprivileged_port_start` to 445. Trade-off: any unprivileged
process on `console` may then bind ports 445–1023. Acceptable on a
single-user machine; the alternative is a rootful quadlet in
`/etc/containers/systemd/`, which then needs `UID_henrique=1000` instead of
`force user = root`.

## First-Time Setup

### 1. Deploy the Quadlet

```bash
# From the dotfiles repo root on console:
stow .

# Verify the symlink:
ls -la ~/.config/containers/systemd/samba.container
```

### 2. Create the Credentials File

Never committed to git (gitignored).

```bash
PW=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
umask 077
printf 'ACCOUNT_henrique=%s\n' "$PW" > ~/.config/containers/systemd/samba.env
echo "password: $PW"   # store it in your password manager
```

### 3. Allow Rootless Bind on Port 445

```bash
echo 'net.ipv4.ip_unprivileged_port_start=445' | sudo tee /etc/sysctl.d/99-unprivileged-smb.conf
sudo sysctl --system
```

### 4. Open Port 445 to the Tailnet Only

Uses a rich rule scoped to the Tailscale CGNAT range instead of moving
`tailscale0` into a new zone — moving the interface would drop it out of
`FedoraWorkstation`, which is what currently allows the high ports that Crafty
(8443/25565) relies on.

```bash
sudo firewall-cmd --permanent --zone=FedoraWorkstation \
  --add-rich-rule='rule family="ipv4" source address="100.64.0.0/10" port port="445" protocol="tcp" accept'
sudo firewall-cmd --reload
```

If `sudo firewall-cmd --get-zone-of-interface=tailscale0` reports a zone other
than `FedoraWorkstation`, use that zone instead.

### 5. Start It

```bash
systemctl --user daemon-reload
systemctl --user start samba.service
```

Quadlet units are *generated*, so `systemctl --user enable` fails with
"Unit ... is transient or generated". That is expected — the
`WantedBy=default.target` inside `samba.container` is what starts it at boot.
Linger must be on (it already is for Crafty):

```bash
loginctl show-user $USER | grep Linger   # should show Linger=yes
```

## Access

| From | Address |
|------|---------|
| Nemo / GNOME Files | `smb://console/storage` |
| Windows Explorer | `\\console\storage` |
| CLI | `smbclient //console/storage -U henrique` |

User is `henrique`, password from `samba.env`.

### Making Nemo Show Just "Storage"

gvfs hardcodes network mount labels as `"<share> on <server>"`, so the entry
under **Network** always reads `storage on console` and cannot be renamed. To
get a clean name, use a sidebar bookmark with an explicit label — Nemo reads
`~/.config/gtk-3.0/bookmarks` in `URI Label` format:

```bash
echo 'smb://console/storage Storage' >> ~/.config/gtk-3.0/bookmarks
```

The bookmark then shows exactly `Storage`. Note this file is local to each
machine and is **not** managed by stow (it holds machine-specific paths).

An alternative is mounting it via `/etc/fstab` with cifs, which also survives
without a graphical session:

```
//console/storage /mnt/Storage cifs credentials=/etc/samba/creds-console,uid=1000,gid=1000,_netdev,nofail,x-systemd.automount,x-gvfs-name=Storage 0 0
```

> **Untested.** `x-gvfs-name` is implemented in
> `gvfs-udisks2-volume-monitor`, which handles block devices — whether it also
> applies to a cifs network mount has not been verified here. The bookmark
> above is the approach that was actually confirmed working.

## Service Management

```bash
systemctl --user status samba.service
systemctl --user restart samba.service
systemctl --user stop samba.service
journalctl --user -u samba -f
```

To change the password, edit `samba.env` and restart the service.

To add a second share (e.g. the 447 GB SSD, already visible inside the
container at `/shares/ssd`), add another `Environment=` line following the same
pattern and restart.

## Performance

Measured over the tailnet with a direct (non-relayed) connection:

| Path | Throughput |
|------|-----------|
| SMB read (large file, via gvfs) | ~35 MB/s |
| SMB write | ~10 MB/s |
| Link baseline (SSH, 200 MB) | ~82 MB/s |
| HDD local write, no network | 17–23 MB/s |
| SSD local write, same test | 384 MB/s |

The container and the network are **not** the bottleneck — an SMB read has hit
~92 MB/s, above the SSH baseline. Write speed is limited by the HDD itself: it
writes at 17–23 MB/s with no network involved, while the SSD in the same
machine does 384 MB/s on an identical test. A healthy `ST1000DM010` (7200 rpm,
CMR) should sustain roughly 150 MB/s, and the SATA link negotiated fine with
write cache enabled and no `dmesg` errors — so the drive is a candidate for
replacement. Check before trusting it with anything important:

```bash
sudo smartctl -a /dev/sdb | grep -iE 'reallocated|pending|uncorrect|health|error'
```

## Troubleshooting

### `Listen failed for HOST TCP port .../445: Permission denied`

The sysctl from step 3 is missing or was not reapplied after a reboot:

```bash
sysctl net.ipv4.ip_unprivileged_port_start   # must be <= 445
```

### Share is empty / disk missing after a reboot

The automount did not bring the disk up. `rslave` propagation means the
container does not need a restart once it appears:

```bash
systemctl status run-media-system-hd.mount
ls /run/media/system/hd
```

### Connection times out from another tailnet machine

Check the listener is bound to the Tailscale IP and the firewall rule exists:

```bash
ss -tln | grep 445        # expect 100.120.120.72:445
sudo firewall-cmd --list-rich-rules
```

If the Tailscale IP of `console` ever changes, update `PublishPort=` in
`samba.container`.

### Permission denied writing to the share

Confirm `force user = root` is still in the share config — see
[Why the Unit Looks the Way It Does](#why-the-unit-looks-the-way-it-does). A
correctly written file shows as `1000:1000` on the host:

```bash
ls -ln /run/media/system/hd/
```
