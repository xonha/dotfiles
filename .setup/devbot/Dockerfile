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
        tmux \
    && pacman -Scc --noconfirm

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

# Create development user named henrique with sudo privileges.
ARG USERNAME=henrique
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} ${USERNAME} \
    && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 440 /etc/sudoers.d/${USERNAME}

# Create startup script to run SSH and keep container alive (as root)
RUN echo '#!/bin/bash' > /start.sh \
    && echo "install -d -m 700 -o ${USERNAME} -g ${USERNAME} /home/${USERNAME}/.ssh" >> /start.sh \
    && echo "install -m 600 -o ${USERNAME} -g ${USERNAME} /run/host_ssh_key /home/${USERNAME}/.ssh/authorized_keys" >> /start.sh \
    && echo '/usr/sbin/sshd' >> /start.sh \
    && echo 'exec sleep infinity' >> /start.sh \
    && chmod +x /start.sh
WORKDIR /workspace

# Start SSH server and keep container alive
CMD ["/start.sh"]
