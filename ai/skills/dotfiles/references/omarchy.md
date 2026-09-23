# Omarchy integration

Omarchy owns parts of the desktop and may update them independently. Keep
native Omarchy components intact unless the user explicitly requests an
override.

The repository intentionally versions user overrides for:

- `.config/hypr/`
- `.config/foot/`
- selected `omarchy/` files

Read the installed Omarchy skill before making end-user desktop changes. Use
the official `omarchy` commands for Omarchy-owned operations, and do not edit
`/usr/share/omarchy/`.

The integration decision is implemented in `setup/_shared.sh` and
`setup/dotfiles.sh`; keep detection and exclusion logic centralized there.
