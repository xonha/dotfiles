FROM archlinux:latest

# The build context is the dotfiles repository. Copy the actual setup stages
# used by a regular machine so Lab follows the same bootstrap, package
# and login-shell workflow.
COPY .setup/_shared.sh .setup/_packages.sh \
     .setup/lab-bootstrap-yay.sh .setup/10-server-packages.sh \
     .setup/30-login-shell.sh /opt/dotfiles-setup/
# Install only the container runtime/bootstrap prerequisites. The shared
# package stage below installs all development packages.
RUN pacman -Syu --noconfirm \
    && pacman -S --noconfirm --needed \
      base-devel git curl openssh sudo less which unzip zip ca-certificates \
      python python-pip github-cli kitty-terminfo

# Set UTF-8 locale so Neovim renders Unicode/Nerd Font glyphs correctly
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV DOTFILES_REPO=https://github.com/xonha/dotfiles.git

# Configure SSH server
RUN ssh-keygen -A \
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && echo 'AcceptEnv TERM' >> /etc/ssh/sshd_config \
    && echo 'SetEnv LANG=C.UTF-8' >> /etc/ssh/sshd_config \
    && echo 'SetEnv LC_ALL=C.UTF-8' >> /etc/ssh/sshd_config

# Create the development user. The shared login-shell stage sets its final
# shell after Bash has been validated by the shared login-shell stage.
ARG USERNAME=henrique
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} ${USERNAME} \
    && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 440 /etc/sudoers.d/${USERNAME}

# Run the same user-level stages as a regular installation. Lab uses the
# package-stage target to omit host daemons such as Docker and Tailscale.
USER ${USERNAME}
ENV USER=${USERNAME}
ENV SETUP_TARGET=lab
RUN /bin/bash -o pipefail -c 'source /opt/dotfiles-setup/lab-bootstrap-yay.sh && run \
      && source /opt/dotfiles-setup/10-server-packages.sh && run \
      && source /opt/dotfiles-setup/30-login-shell.sh && run \
      && (yay -S --needed --noconfirm blesh || true)'

USER root
# Prefer the stable AUR package above. Plain Arch mirrors do not provide
# blesh, so keep an upstream build as a deterministic fallback for image
# builds where the AUR package is temporarily unavailable.
RUN if [[ ! -r /usr/share/blesh/ble.sh ]]; then \
      git clone --recursive --depth 1 --shallow-submodules \
        https://github.com/akinomyoga/ble.sh.git /tmp/ble.sh \
      && make -C /tmp/ble.sh install PREFIX=/usr/local \
      && rm -rf /tmp/ble.sh; \
    fi
RUN pacman -Scc --noconfirm

# Create startup script to run SSH and keep container alive (as root)
RUN echo '#!/bin/bash' > /start.sh \
    && echo "install -d -m 700 -o ${USERNAME} -g ${USERNAME} /home/${USERNAME}/.ssh" >> /start.sh \
    && echo "install -m 600 -o ${USERNAME} -g ${USERNAME} /run/host_ssh_key /home/${USERNAME}/.ssh/authorized_keys" >> /start.sh \
    && echo "install -d -m 755 -o ${USERNAME} -g ${USERNAME} /home/${USERNAME}/.config" >> /start.sh \
    && echo "if [[ ! -d /home/${USERNAME}/Dotfiles/.git ]]; then runuser -u ${USERNAME} -- git clone \"${DOTFILES_REPO}\" /home/${USERNAME}/Dotfiles; fi" >> /start.sh \
    && echo "runuser -u ${USERNAME} -- bash -lc 'cd /home/${USERNAME}/Dotfiles && test -f .bashrc && test -f .bash_profile && test -f .tmux.conf && test -f .config/starship.toml && (test -r /usr/share/blesh/ble.sh || test -r /usr/local/share/blesh/ble.sh) && stow --restow .'" >> /start.sh \
    && echo '/usr/bin/ssh-keygen -A' >> /start.sh \
    && echo '/usr/sbin/sshd' >> /start.sh \
    && echo 'exec sleep infinity' >> /start.sh \
    && chmod +x /start.sh
WORKDIR /workspace

# Start SSH server and keep container alive
CMD ["/start.sh"]
