# Setup workflow

The main setup flow is `omarchy/setup.sh`. It sources these modules in
order:

1. `pkg_server.sh` — shared CLI packages
2. `dotfiles.sh` — Dotdrop and Git remote setup
3. `bash.sh` — safe login-shell configuration
4. `pkg_client.sh` and `omarchy/plugins.sh` — client and Omarchy setup
5. `services.sh` — system services

Only `pkg_server.sh` and `pkg_client.sh` declare shared package lists,
grouped by repository. Shared behavior belongs in `_shared.sh`.

Before changing a stage, inspect its callers and whether it can run on a
headless host. Preserve the existing `run` convention and `set -euo pipefail`.

Useful checks:

```bash
bash -n setup/*.sh
git diff --check
```

Run the complete setup only when the user explicitly wants host changes.
