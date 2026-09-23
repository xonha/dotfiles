# Setup workflow

The main setup flow is `.setup/omarchy-setup.sh`. It sources these stages in
order:

1. `10-server-packages.sh` — base packages
2. `20-dotfiles.sh` — Dotdrop and Git remote setup
3. `30-login-shell.sh` — safe login-shell configuration
4. `40-desktop.sh` — optional graphical setup
5. `50-services.sh` — system services

Desktop-only modules include `desktop-packages.sh` and `omarchy-plugins.sh`.
Shared behavior belongs in `_shared.sh` or `_packages.sh`.

Before changing a stage, inspect its callers and whether it can run on a
headless host. Preserve the existing `run` convention and `set -euo pipefail`.

Useful checks:

```bash
bash -n .setup/*.sh
git diff --check
```

Run the complete setup only when the user explicitly wants host changes.
