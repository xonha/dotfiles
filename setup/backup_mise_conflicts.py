#!/usr/bin/env python3
"""Move conflicting mise targets to a timestamped backup before applying."""
import datetime
import os
import shutil
import sys
import tomllib
from pathlib import Path

home = Path.home()
entries = tomllib.loads(Path(sys.argv[1]).read_text())["dotfiles"]
conflicts = []
for name, entry in sorted(entries.items(), key=lambda item: len(Path(item[0]).parts)):
    target = Path(name)
    source = Path(entry["source"])
    if any(parent in conflicts for parent in target.parents):
        continue
    if not os.path.lexists(target) or target.resolve() == source.resolve():
        continue
    conflicts.append(target)

if conflicts:
    backup = home / ".local/state/dotfiles-backups" / datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    for target in conflicts:
        destination = backup / target.relative_to(home)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(target), str(destination))
    print(f"Existing dotfiles backed up to {backup}", flush=True)
