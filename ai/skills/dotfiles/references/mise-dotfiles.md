# Mise dotfile deployment

`mise.toml` at the repository root declares the dotfiles in mise's native
`[dotfiles]` table. Shared directories whose children are files
(`~/.local/share/applications`, icons, Nautilus extensions) use
`mode = "symlink-each"`: mise links each file, leaves files owned by other
applications alone, removes links whose source was deleted, and honours
`exclude` (for example `mimeinfo.cache`).

`setup/apply_mise_dotfiles.sh` is the entrypoint (`mise run dotfiles` runs it).
It adds what mise cannot declare statically, in a temporary config that
replaces the user's global mise config for that run only:

- one directory link per direct child of `ai/skills` (into `~/.agents/skills`)
  and `omarchy/themes` (into `~/.config/omarchy/themes`), including local,
  gitignored children such as `ai/skills/synced`;
- `~/.claude/skills` and `~/.agents/agents`;
- a guard that skips any of these whose target already *is* the source. On the
  Omarchy host `~/.claude` and `~/.agents` link to `ai/` as a whole, and mise
  would otherwise report the source itself as a conflict (`--force` would
  destroy it);
- real directories for every `config/systemd/**/*.d` drop-in directory;
- `--backup-conflicts`, which moves each path that mise refuses to replace to
  `~/.local/state/dotfiles-backups/<timestamp>` and never moves a path inside
  the repository.

Add a mapping by adding a line to `[dotfiles]` in `mise.toml`. New skills and
themes need no change. Never map a `*.d` drop-in directory as a whole.

Preview and inspect without writing:

```bash
bash setup/apply_mise_dotfiles.sh --dry-run
bash setup/apply_mise_dotfiles.sh status   # or: mise run dotfiles:status
bash setup/apply_mise_dotfiles.sh diff
```

Existing conflicting files are not replaced automatically. Review them and
preserve their contents (`--backup-conflicts` moves them aside); do not use
`--force` blindly. Validate mapping changes in a temporary home first, for
example with `HOME`, `XDG_STATE_HOME`, `XDG_CONFIG_HOME` and `XDG_DATA_HOME`
pointing at an empty directory, and check that the links resolve to repository
sources. mise records `symlink-each` links in `~/.local/state/mise/dotfiles`;
keep that directory.
