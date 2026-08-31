# Dotfiles

systemctl --user enable --now dock-handler.service

sudo systemctl enable --now tailscaled.service
sudo systemctl enable --now earlyoom.service

## Bazzite Development Container Setup

This repository includes a `Dockerfile` for creating an Arch Linux development container (`devbox`) on Bazzite with automatic startup.

Persistence note: with the systemd unit generated without `--new`, container writable-layer data persists across reboot/restart as long as the same container is reused. If you remove and recreate the container, writable-layer data is lost; keep important data in bind mounts/volumes such as `/workspace`.

### Prerequisites

- Bazzite machine with Podman installed
- SSH access to the Bazzite machine
- User account with sudo privileges (if needed)

### Container Specifications

- **Base Image:** Arch Linux (latest)
- **Container Name:** `devbox`
- **Hostname:** `devbox`
- **Memory Limit:** 14GB RAM + 14GB Swap
- **User:** `henrique` (UID 1000, with passwordless sudo)
- **Password:** `plambas`
- **Workspace:** `~/devbox/workspace` mounted at `/workspace` in container
- **Auto-start:** Enabled via systemd user service
- **SSH Access:** Port 2222 (host) → Port 22 (container)

### Installed Packages

- base-devel (build tools: gcc, make, etc.)
- git, curl, wget, openssh
- sudo, neovim, less, which
- unzip, zip, ca-certificates
- python, python-pip
- nodejs, npm

### Setup Instructions

#### 1. Build the Container Image

```bash
# On the Bazzite machine
mkdir -p "$HOME/devbox-image" "$HOME/devbox/workspace"

# Copy Dockerfile to the build directory
cat > "$HOME/devbox-image/Dockerfile" <<'EOF'
FROM archlinux:latest

# Keep package metadata fresh and install common development tools.
RUN pacman -Sy --noconfirm \
    && pacman -S --noconfirm --needed \
            base-devel \
            git \
            curl \
            wget \
            openssh \
            sudo \
            neovim \
            less \
            which \
            unzip \
            zip \
            ca-certificates \
            python \
            python-pip \
            nodejs \
            npm \
            stow \
            github-cli \
            zsh \
            zsh-syntax-highlighting \
            zsh-autosuggestions \
            zsh-history-substring-search \
            nvm \
            kitty-terminfo \
    && pacman -Scc --noconfirm

# Configure SSH server
RUN ssh-keygen -A \
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Create development user named henrique with sudo privileges
ARG USERNAME=henrique
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} ${USERNAME} \
    && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME} \
    && echo "${USERNAME}:plambas" | chpasswd \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 440 /etc/sudoers.d/${USERNAME}

# Create startup script to run SSH and keep container alive (must run as root)
RUN echo '#!/bin/bash' > /start.sh \
    && echo '/usr/sbin/sshd' >> /start.sh \
    && echo 'exec sleep infinity' >> /start.sh \
    && chmod +x /start.sh

WORKDIR /workspace

# Start the SSH server and keep the container running
CMD ["/start.sh"]
EOF

# Build the image
podman build -t devbox:latest "$HOME/devbox-image"
```

#### 2. Create and Configure the Container

```bash
# Remove any existing devbox container
podman rm -f devbox >/dev/null 2>&1 || true

# Create the container with resource limits and SSH port forwarding
podman create \
    --name devbox \
    --hostname devbox \
    --memory 14g \
    --memory-swap 14g \
    --pids-limit 4096 \
    -p 2222:22 \
    -v "$HOME/devbox/workspace:/workspace:Z" \
    -w /workspace \
    devbox:latest
```

**Note:** Port 2222 on the host is forwarded to port 22 (SSH) in the container.

#### 3. Enable Auto-Start with Systemd

```bash
# Generate systemd service file for the existing container (persistent)
podman generate systemd --name devbox --files

# Move service file to user systemd directory
mkdir -p "$HOME/.config/systemd/user"
mv -f container-devbox.service "$HOME/.config/systemd/user/devbox.service"

# Reload systemd and enable the service
systemctl --user daemon-reload
systemctl --user enable --now devbox.service

# Enable linger so the service starts at boot (even before login)
loginctl enable-linger $USER
```

Note: `podman generate systemd` is currently supported but marked deprecated upstream in favor of Quadlet (`*.container` units). This guide keeps the current command for simplicity.

#### 4. Verify Setup

```bash
# Check service status
systemctl --user status devbox.service

# Check container is running
podman ps --filter name=devbox

# Verify memory limits
podman inspect devbox --format 'Memory={{.HostConfig.Memory}} MemorySwap={{.HostConfig.MemorySwap}}'

# Test access
podman exec -it devbox whoami
```

### Accessing the Container

**Via Podman exec (from Bazzite host):**

```bash
podman exec -it devbox bash
```

**Via SSH (from any machine on Tailscale):**

Add this to your `~/.ssh/config` on your local machine:

```
Host devbox
    HostName <bazzite-tailscale-ip>
    Port 2222
    User henrique
```

Then connect with:

```bash
ssh henrique@devbox
# Password: plambas
```

To find your Bazzite Tailscale IP:

```bash
# On the Bazzite machine
tailscale ip -4
```

### Managing the Service

```bash
# Check status
systemctl --user status devbox.service

# Restart the container
systemctl --user restart devbox.service

# Stop the container
systemctl --user stop devbox.service

# Start the container
systemctl --user start devbox.service

# Disable auto-start
systemctl --user disable devbox.service

# View logs
journalctl --user -u devbox.service -f
```

### Rebuilding After Changes

If you modify the `Dockerfile`:

```bash
# Rebuild the image
podman build --no-cache -t devbox:latest "$HOME/devbox-image"

# Stop service before replacing container
systemctl --user stop devbox.service

# Recreate the container from the rebuilt image
podman rm -f devbox
podman create \
    --name devbox \
    --hostname devbox \
    --memory 14g \
    --memory-swap 14g \
    --pids-limit 4096 \
    -p 2222:22 \
    -v "$HOME/devbox/workspace:/workspace:Z" \
    -w /workspace \
    devbox:latest

# Start service again
systemctl --user start devbox.service
```

### Fix Existing Install (If Data Is Being Lost)

If you already generated your unit with `--new`, replace it with a persistent unit:

```bash
# Stop and disable current unit
systemctl --user disable --now devbox.service

# Re-generate service without --new
podman generate systemd --name devbox --files
mkdir -p "$HOME/.config/systemd/user"
mv -f container-devbox.service "$HOME/.config/systemd/user/devbox.service"

# Reload and re-enable
systemctl --user daemon-reload
systemctl --user enable --now devbox.service
```

After this, container writable-layer changes persist across reboots.

### Troubleshooting

**Container won't start:**

- Check logs: `journalctl --user -u devbox.service -n 50`
- Verify image exists: `podman images | grep devbox`
- Check if old container is running: `podman ps -a | grep devbox`

**Service doesn't start at boot:**

- Verify linger is enabled: `loginctl show-user $USER -p Linger`
- Should show `Linger=yes`
- Enable if needed: `loginctl enable-linger $USER`

**Memory limits not applied:**

- Verify with: `podman inspect devbox | grep -i memory`
- Note: CPU pinning (`--cpuset-cpus`) requires rootful Podman

### SSH Access Setup

The container runs an SSH server on port 22, which is forwarded to port 2222 on the Bazzite host.

**Configure your local machine:**

1. Get the Bazzite Tailscale IP:

   ```bash
   # On Bazzite
   tailscale ip -4
   ```

2. Add SSH config entry on your local machine (`~/.ssh/config`):

   ```
   Host devbox
       HostName <bazzite-tailscale-ip>
       Port 2222
       User henrique
   ```

3. Connect:

   ```bash
   ssh henrique@devbox
   # Password: plambas
   ```

**Optional: Set up SSH key authentication:**

```bash
# From your local machine
ssh-copy-id -p 2222 henrique@<bazzite-tailscale-ip>
```

### Notes for AI Agents

When replicating this setup:

1. Use the exact `Dockerfile` content from this repository
2. Execute commands in the order listed
3. Verify each step completes successfully before proceeding
4. Key identifiers: container name = `devbox`, service name = `devbox.service`, user = `henrique`
5. The container uses rootless Podman (user-level systemd service)
6. Memory limit: 14GB is specified as `14g` in Podman arguments
7. The workspace directory must exist before creating the container
8. Linger must be enabled for boot-time startup without user login
9. Port forwarding: Host port 2222 → Container port 22 (SSH)
10. SSH server starts automatically via `/start.sh` script in the container
