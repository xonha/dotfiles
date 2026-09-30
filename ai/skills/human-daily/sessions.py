#!/usr/bin/env python3
"""Resume sessoes do Claude Code e do Codex numa janela de tempo, pra daily.

Le os JSONL locais e imprime, por sessao: cwd, horario, os prompts do usuario,
as acoes que mudaram estado fora da maquina (commit, PR, Jira, n8n, Slack...)
e a ultima resposta do agente. Nao imprime saida de ferramenta nem raciocinio.

Filtro de relevancia vem de ~/.agents/local.json (fora do git):

    "sessions": {
      "cwd_prefixes": ["~/projeto-do-trabalho"],
      "keywords": ["PROJ-", "n8n"]
    }

Sessao entra se o cwd bate com um prefixo OU se algum prompt/acao cita uma
keyword. Sem a chave "sessions", nada e filtrado (e um aviso vai pro stderr).

Uso:
    sessions.py                      # desde 00:00 de 3 dias atras
    sessions.py --since 2026-09-29   # desde a data (local), ate agora
    sessions.py --since 2026-09-29 --until 2026-09-30
    sessions.py --all                # ignora o filtro de relevancia
"""

import argparse
import glob
import json
import os
import re
import sys
from datetime import datetime, timedelta

HOME = os.path.expanduser("~")
CLAUDE_GLOB = os.path.join(HOME, ".claude/projects/*/*.jsonl")  # sem subagents/
CODEX_GLOB = os.path.join(HOME, ".codex/sessions/*/*/*/*.jsonl")
LOCAL_CONFIG = os.path.join(HOME, ".agents/local.json")

MAX_PROMPTS = 15
PROMPT_CHARS = 280
ANSWER_CHARS = 500
ACTION_CHARS = 160

# Ultimo segmento de uma tool MCP (mcp__server__nome) que indica escrita.
MCP_WRITE = re.compile(
    r"^(create|update|upsert|publish|unpublish|delete|archive|restore|send|add|"
    r"edit|transition|move|execute|test|append|assign|mute|retry|run|sync)",
    re.IGNORECASE,
)
MCP_NAME = re.compile(r"mcp__[\w-]+__[\w-]+")
SHELL_WRITE = re.compile(
    r"\bgit (commit|push|merge|rebase|tag)\b[^\n\"']*"
    r"|\bgh (pr (create|merge|review|comment|edit|close|ready)|issue (create|comment|close))\b[^\n\"']*"
    r"|\bgh api\b[^\n\"']*(-X ?(POST|PATCH|PUT|DELETE)|--method ?(POST|PATCH|PUT|DELETE)|--input)[^\n\"']*"
    r"|\bjira issue (move|comment|create|edit|assign|link)\b[^\n\"']*"
)
FILE_TOOLS = {"Edit", "Write", "NotebookEdit", "MultiEdit"}
SKIP_COMMANDS = {"/clear", "/human-daily", "/compact", "/model", "/config"}


def parse_ts(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone()
    except ValueError:
        return None


def clip(text, limit):
    text = " ".join(str(text).split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def load_config():
    try:
        with open(LOCAL_CONFIG) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def load_filter(config):
    cfg = config.get("sessions")
    if not cfg:
        print(f"aviso: sem 'sessions' em {LOCAL_CONFIG}, nada filtrado", file=sys.stderr)
        return None
    prefixes = [os.path.expanduser(p).rstrip("/") for p in cfg.get("cwd_prefixes", [])]
    keywords = [k.lower() for k in cfg.get("keywords", [])]
    return prefixes, keywords


def is_relevant(session, rule):
    if rule is None:
        return True
    prefixes, keywords = rule
    cwd = session["cwd"] or ""
    if any(cwd == p or cwd.startswith(p + "/") for p in prefixes):
        return True
    blob = " ".join(session["prompts_text"] + [a for _, a in session["actions"]]).lower()
    return any(k in blob for k in keywords)


def user_prompt(text):
    """Texto digitado pelo usuario, ou None se for injecao do harness."""
    text = text.strip()
    if not text:
        return None
    if text.startswith("<command-name>"):
        name = re.search(r"<command-name>(.*?)</command-name>", text, re.S)
        args = re.search(r"<command-args>(.*?)</command-args>", text, re.S)
        name = name.group(1).strip() if name else ""
        if name in SKIP_COMMANDS:
            return None
        return f"{name} {args.group(1).strip() if args else ''}".strip()
    if text.startswith("<") or text.startswith("# AGENTS.md"):
        return None
    return text


def show_path(path, cwd):
    """Path legivel; None pra arquivo temporario (scratchpad, /tmp)."""
    if not path or path.startswith("/tmp/"):
        return None
    if cwd and path.startswith(cwd.rstrip("/") + "/"):
        return os.path.relpath(path, cwd)
    return path.replace(HOME, "~", 1)


def shell_actions(text):
    return [clip(m.group(0), ACTION_CHARS) for m in SHELL_WRITE.finditer(text)]


def new_session(tool, path):
    return {
        "tool": tool,
        "id": os.path.basename(path).rsplit(".", 1)[0][-8:],
        "cwd": None,
        "first": None,
        "last": None,
        "prompts": [],
        "prompts_text": [],
        "actions": [],  # (ts, texto)
        "files": set(),
        "answer": None,
    }


def touch(session, ts):
    session["first"] = min(filter(None, [session["first"], ts]))
    session["last"] = max(filter(None, [session["last"], ts]))


def add_prompt(session, ts, text):
    touch(session, ts)
    session["prompts_text"].append(text)
    session["prompts"].append((ts, clip(text, PROMPT_CHARS)))


def read_claude(path, since, until):
    s = new_session("claude", path)
    pending = {}  # tool_use_id -> indice em actions
    with open(path, errors="replace") as fh:
        for line in fh:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            ts = parse_ts(d.get("timestamp"))
            if not ts or not (since <= ts < until) or d.get("isSidechain"):
                continue
            s["cwd"] = s["cwd"] or d.get("cwd")
            msg = d.get("message") or {}
            content = msg.get("content")
            if d.get("type") == "user":
                if d.get("isMeta") or d.get("isCompactSummary"):
                    continue
                if isinstance(content, str):
                    text = user_prompt(content)
                    if text:
                        add_prompt(s, ts, text)
                    continue
                for block in content or []:
                    kind = block.get("type")
                    if kind == "text":
                        text = user_prompt(block.get("text", ""))
                        if text:
                            add_prompt(s, ts, text)
                    elif kind == "tool_result" and block.get("tool_use_id") in pending:
                        if block.get("is_error"):
                            i = pending.pop(block["tool_use_id"])
                            at, act = s["actions"][i]
                            s["actions"][i] = (at, act + "  [FALHOU]")
            elif d.get("type") == "assistant":
                for block in content or []:
                    kind = block.get("type")
                    if kind == "text" and block.get("text", "").strip():
                        s["answer"] = block["text"]
                    elif kind == "tool_use":
                        name, args = block.get("name", ""), block.get("input") or {}
                        if name in FILE_TOOLS:
                            fp = show_path(args.get("file_path") or args.get("notebook_path"), s["cwd"])
                            if fp:
                                s["files"].add(fp)
                        elif name == "Bash":
                            for act in shell_actions(args.get("command", "")):
                                pending[block.get("id")] = len(s["actions"])
                                s["actions"].append((ts, act))
                        elif name.startswith("mcp__") and MCP_WRITE.match(
                            name.split("__")[-1].removeprefix("slack_")
                        ):
                            pending[block.get("id")] = len(s["actions"])
                            label = name.split("__", 1)[1]
                            s["actions"].append((ts, clip(f"{label} {json.dumps(args, ensure_ascii=False)}", ACTION_CHARS)))
                        else:
                            continue
                        touch(s, ts)
    return s


def read_codex(path, since, until):
    s = new_session("codex", path)
    with open(path, errors="replace") as fh:
        for line in fh:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            p = d.get("payload") or {}
            if d.get("type") == "session_meta":
                s["cwd"] = p.get("cwd")
                continue
            ts = parse_ts(d.get("timestamp"))
            if not ts or not (since <= ts < until):
                continue
            kind = (d.get("type"), p.get("type"))
            if kind == ("event_msg", "item_completed"):
                item = p.get("item") or {}
                if item.get("type") == "UserMessage":
                    text = " ".join(c.get("text", "") for c in item.get("content", []))
                    text = user_prompt(text)
                    if text:
                        add_prompt(s, ts, text)
            elif kind == ("event_msg", "task_complete") and p.get("last_agent_message"):
                s["answer"] = p["last_agent_message"]
            elif kind in (("response_item", "custom_tool_call"), ("response_item", "function_call")):
                text = p.get("input") or f"{p.get('name', '')} {p.get('arguments', '')}"
                acts = shell_actions(text)
                for name in MCP_NAME.findall(text):
                    if MCP_WRITE.match(name.split("__")[-1].removeprefix("slack_")):
                        acts.append(name.split("__", 1)[1])
                for path_ in re.findall(r"\*\*\* (?:Update|Add) File: ([^\s\\]+)", text):
                    fp = show_path(path_, s["cwd"])
                    if fp:
                        s["files"].add(fp)
                for act in acts:
                    s["actions"].append((ts, act))
                if acts:
                    touch(s, ts)
    return s


def recent_files(pattern, since):
    cutoff = since.timestamp()
    return [f for f in glob.glob(pattern) if os.path.getmtime(f) >= cutoff]


def render(s):
    home_cwd = (s["cwd"] or "?").replace(HOME, "~")
    span = f"{s['first']:%Y-%m-%d %H:%M}–{s['last']:%H:%M}"
    if s["first"].date() != s["last"].date():
        span = f"{s['first']:%Y-%m-%d %H:%M}–{s['last']:%Y-%m-%d %H:%M}"
    out = [f"## {s['tool']} {s['id']} · {home_cwd} · {span}"]
    prompts = s["prompts"]
    if len(prompts) > MAX_PROMPTS:
        omitted = len(prompts) - MAX_PROMPTS
        prompts = prompts[:5] + [(None, f"(… {omitted} prompts omitidos …)")] + prompts[-(MAX_PROMPTS - 5):]
    out.append("prompts:")
    out += [f"  {ts:%m-%d %H:%M} {t}" if ts else f"  {t}" for ts, t in prompts]
    if s["actions"]:
        out.append("acoes:")
        out += [f"  {ts:%m-%d %H:%M} {a}" for ts, a in s["actions"]]
    if s["files"]:
        out.append("arquivos editados: " + ", ".join(sorted(s["files"])[:20]))
    if s["answer"]:
        out.append("ultima resposta: " + clip(s["answer"], ANSWER_CHARS))
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--since", help="data local AAAA-MM-DD (padrao: 3 dias atras)")
    ap.add_argument("--until", help="data local AAAA-MM-DD, exclusiva (padrao: agora)")
    ap.add_argument("--all", action="store_true", help="ignora o filtro de relevancia")
    args = ap.parse_args()

    now = datetime.now().astimezone()
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    since = datetime.fromisoformat(args.since).astimezone() if args.since else today - timedelta(days=3)
    until = datetime.fromisoformat(args.until).astimezone() if args.until else now
    config = load_config()
    rule = None if args.all else load_filter(config)
    # A propria daily enviada pro canal de conferencia nao e trabalho do dia.
    daily_channel = (config.get("slack") or {}).get("daily_channel")

    sessions = [read_claude(f, since, until) for f in recent_files(CLAUDE_GLOB, since)]
    sessions += [read_codex(f, since, until) for f in recent_files(CODEX_GLOB, since)]
    for s in sessions:
        if daily_channel:
            s["actions"] = [(t, a) for t, a in s["actions"] if daily_channel not in a]
    sessions = [s for s in sessions if s["prompts"] and is_relevant(s, rule)]
    sessions.sort(key=lambda s: s["first"])

    print(f"# sessoes {since:%Y-%m-%d %H:%M} → {until:%Y-%m-%d %H:%M} · {len(sessions)} relevantes\n")
    print("\n\n".join(render(s) for s in sessions) if sessions else "(nenhuma)")


if __name__ == "__main__":
    main()
