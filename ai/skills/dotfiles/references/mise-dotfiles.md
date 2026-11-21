# Mise dotfile deployment

`config/mise_dotfiles.json` declares the Omarchy dotfile sources and targets.
`setup/mise_dotfiles.py` generates an isolated mise configuration, expanding
`children` entries into links to direct children while preserving other files
in the destination. Exclusions such as `mimeinfo.cache` apply to child names.

`setup/dotfiles.sh` runs `mise dot apply` with that generated configuration.
It leaves the user's mise tool configuration and Omarchy's configuration alone.
The setup creates systemd drop-in directories as real directories first.

Preview without writing:

```bash
config_file=$(mktemp --suffix=.toml)
python3 setup/mise_dotfiles.py > "$config_file"
MISE_GLOBAL_CONFIG_FILE="$config_file" mise -C /tmp dot apply --dry-run
```

Existing conflicting files are not replaced automatically. Review them and
preserve their contents before migrating; do not use `--force` blindly.
Validate mappings in a temporary home and check links resolve to repository
sources. Do not deploy a directory link over locally managed children.
