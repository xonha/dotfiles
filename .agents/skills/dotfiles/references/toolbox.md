# Toolbox environment

`.setup/toolbox-setup.sh` builds `toolbox.Dockerfile`, reloads the user units,
and restarts the `lab` service. The environment has an independent home,
workspace, and SSH entrypoint.

Before running it, ensure:

- Podman is installed;
- the dotfiles have already been stowed;
- `$HOME/.config/containers/systemd/lab.container` exists.

The normal command is:

```bash
./.setup/toolbox-setup.sh
```

Operational details belong in `.docs/toolbox.md`, not duplicated here.
