#!/usr/bin/env python3
"""Fila do /human-review sem argumento: PRs abertos de Banking que ainda faltam aprovacao.

Uso:
    python3 list_pending.py          # tabela
    python3 list_pending.py --json   # pra script

Regras (espelham a secao "Sem argumento" do SKILL.md):
- Escopo: org MaisTodos, PR aberto, nao draft, repo com nome comecando em "banking"
  (case-insensitive: banking.*, banking-*, BankingAPI), menos EXCLUDED_REPOS.
  PR do proprio usuario fica fora.
- Falta aprovacao: reviewDecision APPROVED -> fora. Quando o GitHub devolve null (ruleset
  nao preenche o campo), conta aprovacoes (ultimo review de cada pessoa = APPROVED) contra
  o minimo: 2 em develop/main/master dos repos de codigo, 1 no atlas e em branch de epico.
- Ja fiz minha parte: meu ultimo review e APPROVED, ou ja revisei o head atual -> fora.
- IGNORED_REVIEWERS (reviews de IA automatizada) nao contam como review nem como
  thread em aberto.
- Fila:
    1 = sem review nenhum de outra pessoa
    2 = tem review, mas todas as threads estao resolvidas
    fora = tem thread em aberto (alguem do time ja ta revisando)
- Repos de approve direto (atlas e frontend) entram com acao "approve".
"""
import json
import subprocess
import sys

ORG = "MaisTodos"
IGNORED_REVIEWERS = {"guilhermeadsferreira"}  # reviews dele sao de IA automatizada
APPROVE_ONLY = {"banking.atlas", "banking-pj-app", "banking-pj-web", "banking-frontend-core"}
ONE_APPROVAL_REPOS = {"banking.atlas"}
EXCLUDED_REPOS = {"banking-playwright"}  # repo de QA, fora da fila
PROTECTED_BASES = {"develop", "main", "master"}

QUERY = """
query($q:String!,$cursor:String){search(query:$q,type:ISSUE,first:50,after:$cursor){
 pageInfo{hasNextPage endCursor}
 nodes{... on PullRequest{number title url createdAt author{login} repository{name}
  reviewDecision headRefOid baseRefName
  reviews(last:100){nodes{author{login} state commit{oid}}}
  reviewThreads(first:100){nodes{isResolved comments(first:1){nodes{author{login}}}}}}}}}
"""


def gh(*args):
    return subprocess.run(["gh", *args], check=True, capture_output=True, text=True).stdout


def search(me):
    q = f"org:{ORG} is:pr is:open draft:false -author:{me}"
    cursor, out = None, []
    while True:
        args = ["api", "graphql", "-f", f"query={QUERY}", "-F", f"q={q}"]
        if cursor:
            args += ["-F", f"cursor={cursor}"]
        data = json.loads(gh(*args))["data"]["search"]
        out += [n for n in data["nodes"] if n]
        if not data["pageInfo"]["hasNextPage"]:
            return out
        cursor = data["pageInfo"]["endCursor"]


def classify(pr, me):
    repo = pr["repository"]["name"]
    author = (pr["author"] or {}).get("login")
    latest = {}
    for r in pr["reviews"]["nodes"]:
        login = (r["author"] or {}).get("login")
        if not login or login == author or r["state"] == "PENDING":
            continue
        latest[login] = r  # reviews vem em ordem cronologica
    approvals = sorted(u for u, r in latest.items() if r["state"] == "APPROVED")

    decision = pr["reviewDecision"]
    if decision == "APPROVED":
        return None
    required = 1 if (repo in ONE_APPROVAL_REPOS or pr["baseRefName"] not in PROTECTED_BASES) else 2
    if decision is None and len(approvals) >= required:
        return None

    mine = latest.get(me)
    if mine and (mine["state"] == "APPROVED" or (mine["commit"] or {}).get("oid") == pr["headRefOid"]):
        return None

    reviewers = set(latest) - IGNORED_REVIEWERS
    open_threads = sum(
        1
        for t in pr["reviewThreads"]["nodes"]
        if not t["isResolved"]
        and ((t["comments"]["nodes"] or [{}])[0].get("author") or {}).get("login") not in IGNORED_REVIEWERS
    )
    if not reviewers:
        queue = 1
    elif open_threads == 0:
        queue = 2
    else:
        return None

    return {
        "queue": queue,
        "action": "approve" if repo in APPROVE_ONLY else "review",
        "repo": repo,
        "number": pr["number"],
        "title": pr["title"],
        "author": author,
        "base": pr["baseRefName"],
        "approvals": f"{len(approvals)}/{required if decision is None else '?'}",
        "reviewers": sorted(reviewers),
        "created": pr["createdAt"][:10],
        "url": pr["url"],
    }


def main():
    me = gh("api", "user", "--jq", ".login").strip()
    rows = [
        c
        for pr in search(me)
        if pr["repository"]["name"].lower().startswith("banking")
        and pr["repository"]["name"] not in EXCLUDED_REPOS
        for c in [classify(pr, me)]
        if c
    ]
    rows.sort(key=lambda r: (r["queue"], r["action"] == "approve", r["created"]))
    if "--json" in sys.argv:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
        return
    for r in rows:
        print(
            f"{r['queue']}\t{r['action']}\t{r['repo']}#{r['number']}\t{r['author']}\t"
            f"{r['base']}\t{r['approvals']}\t{','.join(r['reviewers']) or '-'}\t{r['title'][:60]}"
        )


if __name__ == "__main__":
    main()
