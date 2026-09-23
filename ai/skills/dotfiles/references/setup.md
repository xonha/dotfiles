# Setup workflow

The main setup flow is `setup/omarchy-setup.sh`. It sources these modules in
order:

1. `packages-server.sh` — shared CLI packages
2. `dotfiles.sh` — Dotdrop and Git remote setup
3. `login-shell.sh` — safe login-shell configuration
4. `packages-client.sh` and `omarchy-plugins.sh` — optional Omarchy client setup
5. `services.sh` — system services

Only `packages-server.sh` and `packages-client.sh` declare package lists,
grouped by repository. Shared behavior belongs in `_shared.sh`.

Before changing a stage, inspect its callers and whether it can run on a
headless host. Preserve the existing `run` convention and `set -euo pipefail`.

Useful checks:

```bash
bash -n setup/*.sh
git diff --check
```

Run the complete setup only when the user explicitly wants host changes.
