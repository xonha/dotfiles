#!/usr/bin/env python3
"""Bounded notification history snapshot for the combined Omarchy panel."""
import json
import re
from pathlib import Path

history = Path.home() / '.local/state/omarchy/notifications/history'
notifications = []
try:
    files = sorted(history.glob('*.json'), key=lambda p: p.stat().st_mtime, reverse=True)[:50]
except OSError:
    files = []
for path in files:
    match = re.fullmatch(r'(\d+)-(\d+)\.json', path.name)
    if not match:
        continue
    try:
        item = json.loads(path.read_text()[:16384])
        if not isinstance(item, dict):
            continue
        if item.get('timestamp') != int(match[1]) or item.get('originalId') != int(match[2]):
            continue
        notifications.append({
            'key': match[1] + '-' + match[2],
            'timestamp': int(match[1]),
            'app': str(item.get('app') or 'Aplicativo')[:80],
            'summary': str(item.get('summary') or '')[:240],
            'body': str(item.get('body') or '')[:400],
        })
    except (OSError, ValueError):
        continue
print(json.dumps({'notifications': notifications}, ensure_ascii=False))
