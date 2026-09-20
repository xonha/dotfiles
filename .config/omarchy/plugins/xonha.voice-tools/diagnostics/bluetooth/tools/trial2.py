#!/usr/bin/env python3
"""One F13-path dictation startup trial, timed against the kernel.

usage: trial2.py LABEL [--wp-restart SECS]   (--wp-restart: restart WirePlumber, wait SECS, then start)
Needs tools/kernel-probes.sh installed and `echo mono > /sys/kernel/tracing/trace_clock` (passwordless sudo).
Starts dictation the way F13 does (`stt start`), polls the daemon for 6 s, cancels the take (nothing is
pasted or kept), then prints a timeline relative to the start command.
"""
import json, os, re, socket, subprocess, sys, time

STT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "bin", "stt")
SOCK = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "speech-to-text", "ctl.sock")
TR = "/sys/kernel/tracing"

def sudo(cmd):
    return subprocess.run(["sudo", "-n", "sh", "-c", cmd], capture_output=True, text=True).stdout

def profile():
    out = subprocess.run(["pactl", "list", "cards"], capture_output=True, text=True).stdout
    card = out.split("Name: bluez_card.88_C9_E8_A7_EC_7E", 1)
    if len(card) < 2: return "no-card"
    m = re.search(r"Active Profile: (\S+)", card[1].split("Card #")[0])
    return m.group(1) if m else "?"

def status():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect(SOCK); s.settimeout(2)
    buf = b""
    while b"\n" not in buf:
        buf += s.recv(65536)
    s.close()
    return json.loads(buf.split(b"\n", 1)[0])

label = sys.argv[1]
if "--wp-restart" in sys.argv:
    wait = float(sys.argv[sys.argv.index("--wp-restart") + 1])
    subprocess.run(["systemctl", "--user", "restart", "wireplumber"], check=True)
    time.sleep(wait)
assert status()["state"] == "idle", "stt busy"
p0 = profile()
assert p0.startswith("a2dp"), f"headset not in A2DP before start: {p0}"
sudo(f"echo > {TR}/trace")
t0m, t0w = time.monotonic(), time.time()
subprocess.Popen([STT, "start"], stdout=subprocess.DEVNULL)
first_nz = first_sig = listening = None
levels = []; window = None
while time.monotonic() - t0m < 6.0:
    st = status(); t = time.monotonic() - t0m
    if st["state"] == "recording" and st["levels"]:
        lv = st["levels"][-1]
        levels.append((round(t, 2), lv))
        if lv > 0 and first_nz is None: first_nz = t
        if lv >= 0.05 and first_sig is None: first_sig = t   # rms >= 2e-4
        if st["listening"] and listening is None: listening = t
        if window is None and t >= 2.3: window = (round(t, 2), st["levels"])
    elif st["state"] != "recording" and st["state"] != "idle" and st["state"] != "opening":
        pass
    time.sleep(0.02)
subprocess.run([STT, "cancel"], stdout=subprocess.DEVNULL)
time.sleep(0.3)
p_rec = profile()

# kernel timeline (trace clock must be "mono")
ev = {}
trace = sudo(f"cat {TR}/trace")
rx = tx = 0
for line in trace.splitlines():
    m = re.match(r"\s*\S+\s+\[\d+\]\s+\S+\s+([\d.]+):\s+(\S+):\s*(.*)", line)
    if not m: continue
    t = float(m.group(1)) - t0m; name = m.group(2); rest = m.group(3)
    if name == "sco_rx_urb": rx += 1; ev.setdefault("first_sco_rx_urb", t); continue
    if name == "sco_tx": tx += 1; ev.setdefault("first_sco_tx", t); continue
    if name == "conn_add" and "type=2" in rest: ev.setdefault("esco_connect", t)
    elif name == "cs_enh_setup_sync": ev.setdefault("enh_setup_cmd_status", t)
    elif name == "sync_complete": ev.setdefault("esco_up", t)
    elif name == "submit_isoc_ret" and "ret=-" in rest: ev.setdefault("isoc_submit_fail", t)
    elif name == "notify": ev.setdefault("notify", []).append((round(t, 3), rest))
    elif name == "switch_alt": ev.setdefault("switch_alt", []).append((round(t, 3), rest))
    elif name == "conn_complete": ev.setdefault("conn_complete", []).append((round(t, 3), rest))
dmesg = sudo(f"journalctl -k --since @{int(t0w)-1} --no-pager -o short-precise | grep -E 'submission failed|Bluetooth' | cut -c1-140")

print(f"== {label}")
for k in ("esco_connect", "enh_setup_cmd_status", "esco_up", "first_sco_rx_urb", "first_sco_tx", "isoc_submit_fail"):
    print(f"{k:22s} {ev[k]:.3f}" if k in ev else f"{k:22s} -")
print(f"sco rx urbs {rx}  sco tx {tx}")
print(f"{'first nonzero level':22s} {first_nz:.3f}" if first_nz else f"{'first nonzero level':22s} -")
print(f"{'first level>=0.05':22s} {first_sig:.3f}" if first_sig else f"{'first level>=0.05':22s} -")
print(f"{'UI listening':22s} {listening:.3f}" if listening else f"{'UI listening':22s} -")
print("notify:", ev.get("notify")); print("switch_alt:", ev.get("switch_alt")); print("conn_complete:", ev.get("conn_complete"))
print("levels:", [l for l in levels if l[1] > 0][:12])
if window: print(f"level window at {window[0]} s (oldest first, 50 ms each):", window[1])
print("dmesg:", dmesg.strip() or "-")
print("ERROR90" if "submission failed (90)" in dmesg else "no error 90")
time.sleep(3.5)
print(f"profile: before {p0}, during {p_rec}, 3.5 s after cancel {profile()}")
