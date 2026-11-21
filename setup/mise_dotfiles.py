#!/usr/bin/env python3
"""Generate a mise config from the versioned dotfile mappings."""
import fnmatch
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
home = Path.home()
entries = json.loads((root / "config/mise_dotfiles.json").read_text())
targets = {}
for entry in entries:
    source = root / entry["source"]
    target = home / entry["target"]
    if not source.exists():
        sys.exit(f"Missing dotfile source: {source}")
    if entry["children"]:
        for child in sorted(source.iterdir()):
            if not any(fnmatch.fnmatch(child.name, pattern) for pattern in entry.get("exclude", [])):
                targets[target / child.name] = child
    else:
        targets[target] = source

# A parent directory link already covers any redundant child mapping.
print("[dotfiles]")
for target, source in sorted(targets.items(), key=lambda item: (len(item[0].parts), str(item[0]))):
    # A parent may already point at the repository itself (for example ~/.agents).
    # Replacing the child would otherwise overwrite the source directory.
    if target.exists() and target.resolve() == source.resolve() and not target.is_symlink():
        continue
    for parent in target.parents:
        if parent in targets and targets[parent].is_dir():
            if targets[parent] / target.relative_to(parent) != source:
                sys.exit(f"Conflicting nested dotfile mapping: {target}")
            break
    else:
        print(f"{json.dumps(str(target))} = {{ source = {json.dumps(str(source))}, mode = \"symlink\" }}")
