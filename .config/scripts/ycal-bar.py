#!/usr/bin/env python3
"""Modulo waybar do waybar-ycal com o formato de data do antigo modulo clock.

O bar.py do pacote e fixo em "%A %H:%M" e mora em /usr/share, entao qualquer
edicao la se perde no proximo update. Este wrapper le o mesmo cache de eventos
e so troca a formatacao -- o popup continua sendo o do pacote.
"""

import datetime
import json
import locale
import os
import zoneinfo

CACHE = os.path.expanduser("~/.cache/waybar-ycal/events.json")
TZ = zoneinfo.ZoneInfo("America/Sao_Paulo")
# escapado de proposito: glifo literal da area privada nao sobrevive a edicao
ICON = "\uef37"

# %a e %b saem em ingles; sem isso herdariam o LC_TIME do ambiente do waybar
try:
    locale.setlocale(locale.LC_TIME, "en_US.UTF-8")
except locale.Error:
    pass

now = datetime.datetime.now(TZ)

try:
    with open(CACHE) as fh:
        events = json.load(fh)
except (OSError, ValueError):
    events = {}

print(json.dumps({
    "text": f"{now:%a %d %b %I:%M} {ICON} ",
    "tooltip": "",
    "class": "has-events" if events.get(now.date().isoformat()) else "",
}))
