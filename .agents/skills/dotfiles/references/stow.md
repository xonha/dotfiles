# GNU Stow ownership

The repository is designed to be stowed from its root:

```bash
stow .
```

`.setup/20-dotfiles.sh` adds Omarchy-specific exclusions. On Omarchy it
preserves the native shell, browser, Kitty, Neovim, and related legacy desktop
components while applying the versioned Hyprland and Foot configuration.

Before changing an ignored path or adding a new top-level dotfile:

- inspect the existing ignore list in `20-dotfiles.sh`;
- check whether the target is already managed by Omarchy or another package;
- use a Stow dry-run when possible;
- do not delete an existing host file to resolve a conflict without confirmation.

Systemd drop-in directories under `.config/systemd` must be real directories;
the setup script pre-creates them because systemd does not process a symlinked
drop-in directory correctly.
