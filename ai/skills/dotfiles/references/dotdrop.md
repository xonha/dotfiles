# Dotdrop ownership

Dotdrop is the repository's only dotfile deployment tool. Its manifest is
`config/dotdrop.yaml`; mappings are explicit, so the source name and layout do
not need to mirror the destination path.

## Applying the repository

From the repository root:

```bash
dotdrop install --cfg config/dotdrop.yaml --profile omarchy
```

Preview changes first:

```bash
dotdrop install --cfg config/dotdrop.yaml --profile omarchy --dry --no-banner
```

The setup entrypoint calls the same command from `setup/20-dotfiles.sh`.
`dotdrop` is installed by `setup/10-server-packages.sh`.

## Repository mapping

The `omarchy` profile maps the repository's configuration to `$HOME`. The
`ai/` directory is a shared source tree:

```text
ai/
├── agents/
└── skills/
```

The host agent directories contain local state, so only their versioned
children are mapped:

```yaml
agents_profiles:
  src: ai/agents
  dst: ~/.agents/agents
  link: absolute

agents_skills:
  src: ai/skills
  dst: ~/.agents/skills
  link: link_children

claude_skills:
  src: ai/skills
  dst: ~/.claude/skills
  link: absolute
```

This preserves local skills and runtime state in `~/.agents` and `~/.claude`
while exposing the same versioned skills in both applications.

## Link modes

- `absolute` links the complete source file or directory to one destination.
- `link_children` links the children of a directory while keeping the target
  directory itself available for unrelated files.
- Use `link_children` when Omarchy or an application owns other entries in the
  destination directory.
- Use `absolute` only when the repository is intended to own the complete
  target path.

## Safety and conflicts

- Inspect `git status` before changing the manifest.
- Run the dry-run before applying mappings.
- `backup: true` is enabled in the manifest, but avoid relying on repeated
  backups with the same `.dotdropbak` name. Review existing backups before a
  broad replacement.
- `--force` is required for non-interactive replacement of an existing target.
  Use it only after reviewing the dry-run.
- Do not replace Omarchy-managed regular files or directories merely because
  they exist in the repository. Add them to the manifest only when the
  ownership decision is explicit.
- Systemd drop-in directories must remain real directories; map their files or
  children rather than linking the drop-in directory itself.

## Verification

After applying a mapping, verify the target resolves to the intended source:

```bash
readlink -f ~/.agents/agents
readlink -f ~/.agents/skills/dotfiles
readlink -f ~/.claude/skills
```

For a mapping that should already be satisfied, Dotdrop should report:

```text
0 dotfile(s) installed.
```
