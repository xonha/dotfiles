#!/usr/bin/env python3
"""Bidirectional MaisTodos synchronizer. Dry-run by default; use --apply to write."""
from __future__ import annotations
import argparse, json, subprocess, time, urllib.parse, urllib.request
import urllib.error
from datetime import datetime, timedelta, timezone
from pathlib import Path

API = "https://www.googleapis.com/calendar/v3"
CLIENT_FILE = Path.home() / ".config/gws-omarchy-calendar/client_secret.json"
STATE = Path.home() / ".local/state/maistodos-sync/state.json"
WORK_ACCOUNT = "107159136495973194910"
PERSONAL_ACCOUNT = "108525994900296126593"
WORK_CALENDAR = "henrique.oliveira@maistodos.com.br"
PERSONAL_CALENDAR = "952ffe900736d752e0ac4e11434087fcd9d6c572aaf8a10e1c32a0089f44d439@group.calendar.google.com"

def token(account):
    raw = subprocess.check_output(["secret-tool", "lookup", "application", "omarchy-calendar", "provider", "google", "account", account], text=True)
    data = json.loads(raw)
    client = json.loads(CLIENT_FILE.read_text())['installed']
    form = urllib.parse.urlencode({"client_id": client["client_id"], "client_secret": client["client_secret"], "refresh_token": data["refresh_token"], "grant_type": "refresh_token"}).encode()
    req = urllib.request.Request("https://oauth2.googleapis.com/token", data=form, method="POST")
    with urllib.request.urlopen(req) as response:
        return json.load(response)["access_token"]

def api(method, path, access, body=None, query=None):
    url = API + path + (("?" + urllib.parse.urlencode(query)) if query else "")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={"Authorization": "Bearer " + access, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as response:
            return json.load(response) if response.status != 204 else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        if error.code in (429, 500, 502, 503, 504) or "rateLimitExceeded" in detail:
            raise RetryableError(f"Google Calendar API {error.code}: {detail}") from error
        raise RuntimeError(f"Google Calendar API {error.code}: {detail}") from error

class RetryableError(RuntimeError):
    pass

def write_with_retry(method, path, access, body, query):
    for attempt in range(6):
        try:
            result = api(method, path, access, body, query)
            time.sleep(1.0)
            return result
        except RetryableError:
            if attempt == 5:
                raise
            time.sleep(2 ** attempt)

def cpath(calendar):
    return "/calendars/" + urllib.parse.quote(calendar, safe="")

def fetch(access, calendar, days):
    now = datetime.now(timezone.utc)
    query = {"singleEvents": "true", "showDeleted": "false", "maxResults": "2500", "timeMin": now.isoformat(), "timeMax": (now + timedelta(days=days)).isoformat()}
    result, page = [], None
    while True:
        q = dict(query)
        if page: q["pageToken"] = page
        data = api("GET", cpath(calendar) + "/events", access, query=q)
        result += data.get("items", [])
        page = data.get("nextPageToken")
        if not page: return result

def key(event):
    start = event.get("start", {}).get("dateTime") or event.get("start", {}).get("date", "")
    end = event.get("end", {}).get("dateTime") or event.get("end", {}).get("date", "")
    return (event.get("summary", "").strip().casefold(), start, end)

def sid(event):
    return str(event.get("iCalUID") or event.get("id") or "")

def complete(event):
    fields = ("summary", "description", "location", "start", "end", "recurrence", "attendees", "reminders", "transparency", "visibility", "conferenceData")
    return {field: event[field] for field in fields if field in event}

def private(event):
    return {"summary": "[PESSOAL]", "start": event["start"], "end": event["end"], "transparency": "opaque", "colorId": "11"}

def marked(body, direction, origin):
    body["extendedProperties"] = {"private": {"maistodos_sync": "1", "maistodos_direction": direction, "maistodos_source_id": sid(origin)}}
    return body

def load_state():
    return json.loads(STATE.read_text()) if STATE.exists() else {"work_to_personal": {}, "personal_to_work": {}}

def save_state(state):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n")

def sync(label, sources, destination, access, direction, state, apply):
    source, targets = sources
    by_source = {e.get("extendedProperties", {}).get("private", {}).get("maistodos_source_id"): e for e in targets}
    by_key = {key(e): e for e in targets}
    mappings = state.setdefault(direction, {})
    source_ids = {sid(e) for e in source}
    managed = {e.get("id") for e in targets if e.get("extendedProperties", {}).get("private", {}).get("maistodos_direction") == direction}
    seen = set(); changes = 0
    for origin in source:
        if direction == "work_to_personal" and origin.get("summary", "").strip() == "[PESSOAL]":
            continue
        # Google exposes birthdays from the primary calendar as eventType=birthday.
        # They are not part of the user's Personal agenda sync.
        if direction == "personal_to_work" and origin.get("eventType") == "birthday":
            continue
        if origin.get("status") == "cancelled" or not sid(origin): continue
        target = by_source.get(sid(origin)) or by_key.get(key(origin))
        body = marked(complete(origin) if direction == "work_to_personal" else private(origin), direction, origin)
        action = "UPDATE" if target else "CREATE"
        print(f"{'PLAN ' if not apply else ''}{action} [{label}] {origin.get('summary', '')}")
        if target:
            seen.add(target["id"])
            if direction == "personal_to_work" and target.get("extendedProperties", {}).get("private", {}).get("maistodos_sync") != "1": continue
            target_private = target.get("extendedProperties", {}).get("private", {})
            if target_private.get("maistodos_source_id") == sid(origin) and target_private.get("maistodos_direction") == direction and (direction != "personal_to_work" or target.get("colorId") == "11"):
                continue
            if apply: api("PATCH", cpath(destination) + "/events/" + urllib.parse.quote(target["id"], safe=""), access, body, {"conferenceDataVersion": "1", "sendUpdates": "none"})
            mappings[sid(origin)] = target["id"]
        elif apply:
            created = api("POST", cpath(destination) + "/events", access, body, {"conferenceDataVersion": "1", "sendUpdates": "none"})
            mappings[sid(origin)] = created["id"]
        changes += 1
    if apply:
        for source_key, target_id in list(mappings.items()):
            if source_key not in source_ids and target_id in managed and target_id not in seen:
                print(f"DELETE [{label}] {target_id}")
                api("DELETE", cpath(destination) + "/events/" + urllib.parse.quote(target_id, safe=""), access, query={"sendUpdates": "none"})
                del mappings[source_key]
    return changes

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--days", type=int, default=180)
    args = parser.parse_args()
    state = load_state()
    work_access, personal_access = token(WORK_ACCOUNT), token(PERSONAL_ACCOUNT)
    work = fetch(work_access, WORK_CALENDAR, args.days)
    personal = fetch(personal_access, PERSONAL_CALENDAR, args.days)
    personal_source = fetch(personal_access, "henriquecastro1198@gmail.com", args.days)
    changes = sync("work→personal", (work, personal), PERSONAL_CALENDAR, personal_access, "work_to_personal", state, args.apply)
    changes += sync("personal→work", (personal_source, work), WORK_CALENDAR, work_access, "personal_to_work", state, args.apply)
    if args.apply: save_state(state)
    print(f"changes={changes} mode={'apply' if args.apply else 'dry-run'}")

if __name__ == "__main__": main()
