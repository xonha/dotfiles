#!/usr/bin/env bash
# Step: Enable and start systemd services

SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SETUP_ROOT/_shared.sh"

# Always enabled on every machine
SERVICES_ALWAYS=(
  tailscaled.service
  earlyoom.service
)

# Prompted individually — user decides per machine
SERVICES_OPTIONAL=()

# Rootless Podman API socket: backs the docker CLI shim, docker-compose and
# testcontainers through DOCKER_HOST (see config/bash.conf). Desktop user
# services are configured by their owning desktop modules.
SERVICES_USER=(
  podman.socket
)

enable_service() {
  local svc="$1"
  info "Enabling $svc..."
  if sudo systemctl enable --now "$svc"; then
    success "$svc enabled and started."
  else
    warn "Failed to enable $svc (may not be installed or already active)."
  fi
}

enable_user_service() {
  local svc="$1"
  if ! systemctl --user cat "$svc" &>/dev/null; then
    info "$svc not installed, skipping."
    return
  fi
  info "Enabling $svc (user)..."
  if systemctl --user enable --now "$svc"; then
    success "$svc enabled and started."
  else
    warn "Failed to enable $svc (needs a running user session — retry after login)."
  fi
}

PODMAN_WSL_SRC="$(cd "$SETUP_ROOT/.." && pwd)/config/containers/wsl-network.conf"
PODMAN_WSL_DST="$HOME/.config/containers/containers.conf.d/20-wsl-network.conf"

is_wsl() {
  grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

# The WSL2 kernel lacks the nftables fib expression netavark requires, so
# rootless bridge networks need the firewall driver disabled there.
configure_podman_wsl() {
  is_wsl || return 0
  info "Linking Podman WSL network config..."
  mkdir -p "$(dirname "$PODMAN_WSL_DST")"
  ln -sfn "$PODMAN_WSL_SRC" "$PODMAN_WSL_DST"
  success "Podman firewall driver disabled for WSL."
}

BUILDX_BUILDER=podman
# Call the plugin directly: `docker buildx` resolves to `podman buildx` through
# the podman-docker shim.
BUILDX=/usr/lib/docker/cli-plugins/docker-buildx

# Podman's Docker API has no BuildKit, so Compose builds using `ssh:` or other
# BuildKit features fail. Run BuildKit as a container on Podman and make it the
# default buildx builder; Compose loads the built images back into Podman.
configure_buildx_builder() {
  if [[ ! -x $BUILDX ]]; then
    info "docker-buildx not installed, skipping builder."
    return
  fi
  if ! "$BUILDX" inspect "$BUILDX_BUILDER" &>/dev/null \
    && ! "$BUILDX" create --name "$BUILDX_BUILDER" --driver docker-container; then
    warn "Failed to create buildx builder (is podman.socket active?)."
    return
  fi
  if "$BUILDX" use --default "$BUILDX_BUILDER"; then
    success "buildx builder $BUILDX_BUILDER is the default."
  else
    warn "Failed to select buildx builder $BUILDX_BUILDER."
  fi
}

run() {
  header "Enable services"

  configure_podman_wsl

  for svc in "${SERVICES_ALWAYS[@]}"; do
    enable_service "$svc"
  done

  for svc in "${SERVICES_OPTIONAL[@]}"; do
    if confirm_step "Enable $svc" ""; then
      enable_service "$svc"
    fi
  done

  for svc in "${SERVICES_USER[@]}"; do
    enable_user_service "$svc"
  done

  configure_buildx_builder

}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run
fi
