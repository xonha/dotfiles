# Lab environment

`.setup/lab/setup.sh` builds `lab/Dockerfile`, reloads the user units,
and restarts the `lab` service. The environment has an independent home,
workspace, and SSH entrypoint.

Before running it, ensure:

- Podman is installed;
- the dotfiles have already been applied with Dotdrop;
- `$HOME/.config/containers/systemd/lab.container` exists.

The normal command is:

```bash
./.setup/lab/setup.sh
```

## Reproduction definition of done

When recreating `lab`, the task is complete only when:

- the Arch image is built from the current repository;
- `https://github.com/xonha/dotfiles.git` is cloned into `~/Dotfiles` inside the
  target machine;
- `dotdrop install --cfg .dotdrop/config.yaml --profile omarchy` is executed from that clone;
- Bash is the login shell;
- `.bashrc` and `.bash_profile` are installed;
- `.config/starship.toml` is installed and `starship` is available;
- `blesh` is installed from the AUR (with an upstream build as fallback) and
  an interactive Bash session exposes `BLE_VERSION`;
- `.tmux.conf` is installed and tmux loads it successfully;
- `lab.service` is active and SSH access works;
- the source and target configuration checksums are compared;
- the clone is on the expected branch/commit and has no unexpected changes.

Foot is a graphical terminal configuration for the host that launches `ssh
lab`. It is not expected inside the headless Arch container; validate it on the
Omarchy/Bazzite host separately when the request concerns the terminal itself.

Operational details belong in `.setup/lab/README.md`, not duplicated here.
