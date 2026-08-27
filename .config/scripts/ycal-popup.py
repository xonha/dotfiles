#!/usr/bin/env python3
"""Sobe o popup do waybar-ycal ancorado no canto superior direito.

O popup do pacote ancora so na borda TOP, o que o centraliza horizontalmente, e
nao expoe nenhuma configuracao de posicao. popup.py chama app.run() no nivel do
modulo, sem guarda __main__, entao nao da pra importar e corrigir depois -- este
launcher aplica o patch no fonte antes de executar.

Preferido a forkar popup.py (~950 linhas, mantido pelo pacote): so a linha da
ancora e nossa. Se um update mexer nela, o launcher morre com mensagem clara em
vez de voltar em silencio pro centro da tela.
"""

import sys

SRC = "/usr/share/waybar-ycal/popup.py"

# margem 10 casa a borda direita do popup com a da waybar (margin-right: 10)
OLD = "        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, False)\n"
NEW = (
    "        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)\n"
    "        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, 10)\n"
)

src = open(SRC, encoding="utf-8").read()
if OLD not in src:
    sys.exit(
        f"{SRC}: ancora RIGHT nao encontrada -- o pacote mudou de forma "
        f"incompativel, revise {__file__}"
    )

exec(compile(src.replace(OLD, NEW, 1), SRC, "exec"), {"__name__": "__main__", "__file__": SRC})
