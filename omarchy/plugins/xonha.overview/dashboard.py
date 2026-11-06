#!/usr/bin/env python3
"""Small, bounded notification snapshot for the combined Omarchy panel."""
import json
from pathlib import Path

home = Path.home()
history = home / '.local/state/omarchy/notifications/history'
notifications = []
try:
    files = sorted(history.glob('*.json'), key=lambda p: p.stat().st_mtime, reverse=True)[:12]
except OSError:
    files = []
for path in files:
    try:
        item = json.loads(path.read_text()[:16384])
        if isinstance(item, dict):
            notifications.append({
                'app': str(item.get('app') or 'Aplicativo')[:80],
                'summary': str(item.get('summary') or '')[:240],
                'body': str(item.get('body') or '')[:400],
            })
    except (OSError, ValueError):
        continue
print(json.dumps({'notifications': notifications}, ensure_ascii=False))
