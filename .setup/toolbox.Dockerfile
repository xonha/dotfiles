FROM archlinux:latest

# The build context is the dotfiles repository. Copy the actual setup stages
# used by a regular machine so the Toolbox follows the same bootstrap, package
# and login-shell workflow.
COPY .setup/_shared.sh .setup/_packages.sh \
     .setup/toolbox-bootstrap-yay.sh .setup/10-server-packages.sh \
     .setup/30-login-shell.sh /opt/dotfiles-setup/
COPY .bashrc .bash_profile .config/starship.toml /usr/local/share/toolbox-defaults/

# Install only the container runtime/bootstrap prerequisites. The shared
# package stage below installs all development packages.
RUN pacman -Syu --noconfirm \
    && pacman -S --noconfirm --needed \
      base-devel git curl openssh sudo less which unzip zip ca-certificates \
      python python-pip github-cli kitty-terminfo

# Set UTF-8 locale so Neovim renders Unicode/Nerd Font glyphs correctly
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

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

# Run the same user-level stages as a regular installation. Toolbox uses the
# package-stage target to omit host daemons such as Docker and Tailscale.
USER ${USERNAME}
ENV USER=${USERNAME}
ENV SETUP_TARGET=toolbox
RUN /bin/bash -o pipefail -c 'source /opt/dotfiles-setup/toolbox-bootstrap-yay.sh && run \
      && source /opt/dotfiles-setup/10-server-packages.sh && run \
      && source /opt/dotfiles-setup/30-login-shell.sh && run'

USER root
RUN pacman -Scc --noconfirm

# Create startup script to run SSH and keep container alive (as root)
RUN echo '#!/bin/bash' > /start.sh \
    && echo "install -d -m 700 -o ${USERNAME} -g ${USERNAME} /home/${USERNAME}/.ssh" >> /start.sh \
    && echo "install -m 600 -o ${USERNAME} -g ${USERNAME} /run/host_ssh_key /home/${USERNAME}/.ssh/authorized_keys" >> /start.sh \
    && echo "if [[ ! -e /home/${USERNAME}/.bashrc ]]; then install -m 644 -o ${USERNAME} -g ${USERNAME} /usr/local/share/toolbox-defaults/.bashrc /home/${USERNAME}/.bashrc; fi" >> /start.sh \
    && echo "if [[ ! -e /home/${USERNAME}/.bash_profile ]]; then install -m 644 -o ${USERNAME} -g ${USERNAME} /usr/local/share/toolbox-defaults/.bash_profile /home/${USERNAME}/.bash_profile; fi" >> /start.sh \
    && echo "install -d -m 755 -o ${USERNAME} -g ${USERNAME} /home/${USERNAME}/.config" >> /start.sh \
    && echo "if [[ ! -e /home/${USERNAME}/.config/starship.toml ]]; then install -m 644 -o ${USERNAME} -g ${USERNAME} /usr/local/share/toolbox-defaults/starship.toml /home/${USERNAME}/.config/starship.toml; fi" >> /start.sh \
    && echo '/usr/bin/ssh-keygen -A' >> /start.sh \
    && echo '/usr/sbin/sshd' >> /start.sh \
    && echo 'exec sleep infinity' >> /start.sh \
    && chmod +x /start.sh
WORKDIR /workspace

# Start SSH server and keep container alive
CMD ["/start.sh"]
