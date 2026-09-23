#!/usr/bin/env python3
"""Posta um PR review com comentarios inline via gh api.

Tom dos comentarios: PT-BR informal, sem acento ("vc", "pra", "tb"). Um por achado.
Posta so achados 🔴 e 🟡. Da sugestao de codigo (bloco suggestion) quando for simples.

Uso:
    1. Pega o SHA do head:
         gh pr view <N> --repo <owner>/<repo> --json headRefOid -q .headRefOid
    2. Preenche OWNER / REPO / PR / SHA e a lista FINDINGS.
    3. python3 post_review.py            # monta payload.json e posta
       python3 post_review.py --dry-run  # so monta payload.json (nao posta)
"""
import json
import subprocess
import sys

OWNER = "owner"
REPO = "repo"
PR = 0
SHA = "<head-sha>"  # gh pr view PR --json headRefOid -q .headRefOid
EVENT = "COMMENT"  # ou "REQUEST_CHANGES"

# Cada achado: path + (line) OU (start_line, line) + body.
# body em PT-BR informal, sem acento. Pra sugerir codigo, inclui no body um bloco:
#   ```suggestion\n<linhas novas, com a indentacao final>\n```
FINDINGS = [
    {
        "path": "caminho/do/arquivo.py",
        "start_line": 112,
        "line": 130,
        "body": (
            "explica o problema direto, com o porque. se der, sugere remover/trocar. "
            "referencia outras linhas/arquivos quando ajudar."
        ),
    },
    {
        "path": "caminho/do/arquivo.py",
        "start_line": 128,
        "line": 129,
        "body": (
            "campo errado aqui.\n\n"
            "```suggestion\n"
            "                code,\n"
            '                "Mensagem amigavel pro usuario.",\n'
            "```"
        ),
    },
    {
        "path": "tests/.../test_x.py",
        "line": 26,
        "body": "falta cobertura da variante Y (a DoD pede). vale um teste cobrindo.",
    },
]


def to_comment(finding):
    comment = {"path": finding["path"], "side": "RIGHT", "body": finding["body"]}
    comment["line"] = finding["line"]
    if "start_line" in finding:
        comment["start_line"] = finding["start_line"]
        comment["start_side"] = "RIGHT"
    return comment


def main():
    payload = {
        "commit_id": SHA,
        "event": EVENT,
        "body": "",
        "comments": [to_comment(f) for f in FINDINGS],
    }
    with open("payload.json", "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=True)
    print(f"{len(payload['comments'])} comentarios -> payload.json")

    if "--dry-run" in sys.argv:
        return

    subprocess.run(
        [
            "gh", "api", "--method", "POST",
            f"/repos/{OWNER}/{REPO}/pulls/{PR}/reviews",
            "--input", "payload.json",
        ],
        check=True,
    )


if __name__ == "__main__":
    main()
