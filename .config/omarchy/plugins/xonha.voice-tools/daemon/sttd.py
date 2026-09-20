#!/usr/bin/env python3
"""Speech-to-text daemon for the Omarchy shell plugin.

Owns the microphone (pw-record), the transcription engine, the history
database, the Hyprland key bindings and the paste step. Talks JSON lines over
a unix socket at $XDG_RUNTIME_DIR/speech-to-text/ctl.sock; the shell plugin
and the `stt` CLI are its clients. Standard library only.
"""

import asyncio
import fcntl
import hashlib
import json
import math
import os
import re
import shlex
import shutil
import signal
import sqlite3
import struct
import subprocess
import sys
import tempfile
import threading
import time
import wave

VERSION = "0.1.0"
HOME = os.path.expanduser("~")
RUNTIME = os.environ.get("STT_RUNTIME_DIR") or os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "speech-to-text")
SOCK = os.path.join(RUNTIME, "ctl.sock")
LOCK = os.path.join(RUNTIME, "lock")
BINDS_STATE = os.path.join(RUNTIME, "binds.json")
DATA = os.environ.get("STT_DATA_DIR") or os.path.join(os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local", "share")), "speech-to-text")
TAKES = os.path.join(DATA, "takes")
DB = os.path.join(DATA, "history.db")
CONFIG_DIR = os.environ.get("STT_CONFIG_DIR") or os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config")), "speech-to-text")
CONFIG = os.path.join(CONFIG_DIR, "config.json")
VOXTYPE_CONFIG = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config")), "voxtype", "config.toml")

RATE = 16000
CHUNK = 1600  # bytes = 800 samples = 50 ms of s16 mono
LEVELS = 48  # bars pushed to the bar widget

# Whisper's languages (code -> name). "auto" lets the model detect the language per take.
LANGUAGES = {
    "auto": "Auto-detect", "en": "English", "pt": "Portuguese", "es": "Spanish", "fr": "French", "de": "German",
    "it": "Italian", "ja": "Japanese", "zh": "Chinese", "ko": "Korean", "ru": "Russian", "nl": "Dutch", "pl": "Polish",
    "tr": "Turkish", "sv": "Swedish", "uk": "Ukrainian", "ar": "Arabic", "hi": "Hindi", "cs": "Czech", "da": "Danish",
    "fi": "Finnish", "el": "Greek", "he": "Hebrew", "hu": "Hungarian", "id": "Indonesian", "no": "Norwegian",
    "ro": "Romanian", "th": "Thai", "vi": "Vietnamese", "ca": "Catalan", "bg": "Bulgarian", "hr": "Croatian",
    "sk": "Slovak", "sl": "Slovenian", "lt": "Lithuanian", "lv": "Latvian", "et": "Estonian", "fa": "Persian",
    "ms": "Malay", "ta": "Tamil", "ur": "Urdu", "bn": "Bengali", "tl": "Tagalog", "sw": "Swahili", "af": "Afrikaans",
    "cy": "Welsh", "is": "Icelandic", "gl": "Galician", "eu": "Basque", "sr": "Serbian", "mk": "Macedonian",
    "sq": "Albanian", "az": "Azerbaijani", "ka": "Georgian", "kk": "Kazakh", "hy": "Armenian", "ne": "Nepali",
    "si": "Sinhala", "km": "Khmer", "lo": "Lao", "my": "Burmese", "mn": "Mongolian", "mr": "Marathi", "te": "Telugu",
    "kn": "Kannada", "ml": "Malayalam", "gu": "Gujarati", "pa": "Punjabi", "am": "Amharic", "yo": "Yoruba",
    "ha": "Hausa", "so": "Somali", "uz": "Uzbek", "tg": "Tajik", "be": "Belarusian", "bs": "Bosnian", "mt": "Maltese",
    "ga": "Irish", "la": "Latin", "yi": "Yiddish", "mi": "Maori", "haw": "Hawaiian", "jw": "Javanese", "su": "Sundanese",
}
# What the bar says while recording, in the language being dictated.
UI_STRINGS = {
    "en": {"listening": "Listening…", "opening": "Opening microphone…", "transcribing": "Transcribing…"},
    "pt": {"listening": "Ouvindo…", "opening": "Abrindo o microfone…", "transcribing": "Transcrevendo…"},
    "es": {"listening": "Escuchando…", "opening": "Abriendo el micrófono…", "transcribing": "Transcribiendo…"},
    "fr": {"listening": "À l’écoute…", "opening": "Ouverture du micro…", "transcribing": "Transcription…"},
    "de": {"listening": "Ich höre zu…", "opening": "Mikrofon wird geöffnet…", "transcribing": "Transkribiere…"},
    "it": {"listening": "In ascolto…", "opening": "Apertura del microfono…", "transcribing": "Trascrizione…"},
    "nl": {"listening": "Luistert…", "opening": "Microfoon openen…", "transcribing": "Transcriberen…"},
    "pl": {"listening": "Słucham…", "opening": "Otwieranie mikrofonu…", "transcribing": "Transkrypcja…"},
    "sv": {"listening": "Lyssnar…", "opening": "Öppnar mikrofonen…", "transcribing": "Transkriberar…"},
    "da": {"listening": "Lytter…", "opening": "Åbner mikrofonen…", "transcribing": "Transskriberer…"},
    "no": {"listening": "Lytter…", "opening": "Åpner mikrofonen…", "transcribing": "Transkriberer…"},
    "fi": {"listening": "Kuuntelee…", "opening": "Avataan mikrofonia…", "transcribing": "Litteroidaan…"},
    "tr": {"listening": "Dinliyor…", "opening": "Mikrofon açılıyor…", "transcribing": "Yazıya dökülüyor…"},
    "ru": {"listening": "Слушаю…", "opening": "Открываю микрофон…", "transcribing": "Расшифровка…"},
    "uk": {"listening": "Слухаю…", "opening": "Відкриваю мікрофон…", "transcribing": "Розшифровка…"},
    "cs": {"listening": "Poslouchám…", "opening": "Otevírám mikrofon…", "transcribing": "Přepisuji…"},
    "el": {"listening": "Ακούω…", "opening": "Άνοιγμα μικροφώνου…", "transcribing": "Απομαγνητοφώνηση…"},
    "he": {"listening": "מקשיב…", "opening": "פותח מיקרופון…", "transcribing": "מתמלל…"},
    "ar": {"listening": "أستمع…", "opening": "جارٍ فتح الميكروفون…", "transcribing": "جارٍ التفريغ…"},
    "hi": {"listening": "सुन रहा है…", "opening": "माइक्रोफ़ोन खुल रहा है…", "transcribing": "लिख रहा है…"},
    "ja": {"listening": "聞いています…", "opening": "マイクを開いています…", "transcribing": "文字起こし中…"},
    "zh": {"listening": "正在聆听…", "opening": "正在打开麦克风…", "transcribing": "正在转写…"},
    "ko": {"listening": "듣고 있습니다…", "opening": "마이크 여는 중…", "transcribing": "받아쓰는 중…"},
    "id": {"listening": "Mendengarkan…", "opening": "Membuka mikrofon…", "transcribing": "Menyalin…"},
    "vi": {"listening": "Đang nghe…", "opening": "Đang mở micrô…", "transcribing": "Đang ghi lại…"},
    "th": {"listening": "กำลังฟัง…", "opening": "กำลังเปิดไมโครโฟน…", "transcribing": "กำลังถอดความ…"},
    "hu": {"listening": "Hallgatom…", "opening": "Mikrofon megnyitása…", "transcribing": "Átírás…"},
    "ro": {"listening": "Ascult…", "opening": "Deschid microfonul…", "transcribing": "Transcriu…"},
    "ca": {"listening": "Escoltant…", "opening": "Obrint el micròfon…", "transcribing": "Transcrivint…"},
}
VOXTYPE_MODELS = os.environ.get("STT_MODELS_DIR") or os.path.join(os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local", "share")), "voxtype", "models")
# Models come from one pinned commit of ggerganov/whisper.cpp on Hugging Face, and a
# download is only used when its size and SHA-256 match this table (taken from that
# commit's LFS pointers). An unlisted model name is refused rather than fetched.
MODEL_COMMIT = "5359861c739e955e79d9a303bcbc70fb988958b1"
MODEL_URL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/" + MODEL_COMMIT + "/ggml-{model}.bin"
MODEL_DIGESTS = {  # name: (sha256, bytes)
    "base": ("60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe", 147951465),
    "base-q5_1": ("422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898", 59707625),
    "base-q8_0": ("c577b9a86e7e048a0b7eada054f4dd79a56bbfa911fbdacf900ac5b567cbb7d9", 81768585),
    "base.en": ("a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002", 147964211),
    "base.en-q5_1": ("4baf70dd0d7c4247ba2b81fafd9c01005ac77c2f9ef064e00dcf195d0e2fdd2f", 59721011),
    "base.en-q8_0": ("a4d4a0768075e13cfd7e19df3ae2dbc4a68d37d36a7dad45e8410c9a34f8c87e", 81781811),
    "large-v1": ("7d99f41a10525d0206bddadd86760181fa920438b6b33237e3118ff6c83bb53d", 3094623691),
    "large-v2": ("9a423fe4d40c82774b6af34115b8b935f34152246eb19e80e376071d3f999487", 3094623691),
    "large-v2-q5_0": ("3a214837221e4530dbc1fe8d734f302af393eb30bd0ed046042ebf4baf70f6f2", 1080732091),
    "large-v2-q8_0": ("fef54e6d898246a65c8285bfa83bd1807e27fadf54d5d4e81754c47634737e8c", 1656129691),
    "large-v3": ("64d182b440b98d5203c4f9bd541544d84c605196c4f7b845dfa11fb23594d1e2", 3095033483),
    "large-v3-q5_0": ("d75795ecff3f83b5faa89d1900604ad8c780abd5739fae406de19f23ecd98ad1", 1081140203),
    "large-v3-turbo": ("1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69", 1624555275),
    "large-v3-turbo-q5_0": ("394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2", 574041195),
    "large-v3-turbo-q8_0": ("317eb69c11673c9de1e1f0d459b253999804ec71ac4c23c17ecf5fbe24e259a1", 874188075),
    "medium": ("6c14d5adee5f86394037b4e4e8b59f1673b6cee10e3cf0b11bbdbee79c156208", 1533763059),
    "medium-q5_0": ("19fea4b380c3a618ec4723c3eef2eb785ffba0d0538cf43f8f235e7b3b34220f", 539212467),
    "medium-q8_0": ("42a1ffcbe4167d224232443396968db4d02d4e8e87e213d3ee2e03095dea6502", 823369779),
    "medium.en": ("cc37e93478338ec7700281a7ac30a10128929eb8f427dda2e865faa8f6da4356", 1533774781),
    "medium.en-q5_0": ("76733e26ad8fe1c7a5bf7531a9d41917b2adc0f20f2e4f5531688a8c6cd88eb0", 539225533),
    "medium.en-q8_0": ("43fa2cd084de5a04399a896a9a7a786064e221365c01700cea4666005218f11c", 823382461),
    "small": ("1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b", 487601967),
    "small-q5_1": ("ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb", 190085487),
    "small-q8_0": ("49c8fb02b65e6049d5fa6c04f81f53b867b5ec9540406812c643f177317f779f", 264464607),
    "small.en": ("c6138d6d58ecc8322097e0f987c32f1be8bb0a18532a3f88f734d1bbf9c41e5d", 487614201),
    "small.en-q5_1": ("bfdff4894dcb76bbf647d56263ea2a96645423f1669176f4844a1bf8e478ad30", 190098681),
    "small.en-q8_0": ("67a179f608ea6114bd3fdb9060e762b588a3fb3bd00c4387971be4d177958067", 264477561),
    "tiny": ("be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21", 77691713),
    "tiny-q5_1": ("818710568da3ca15689e31a743197b520007872ff9576237bda97bd1b469c3d7", 32152673),
    "tiny-q8_0": ("c2085835d3f50733e2ff6e4b41ae8a2b8d8110461e18821b09a15c40c42d1cca", 43537433),
    "tiny.en": ("921e4cf8686fdd993dcd081a5da5b6c365bfde1162e72b08d75ac75289920b1f", 77704715),
    "tiny.en-q5_1": ("c77c5766f1cef09b6b7d47f21b546cbddd4157886b3b5d6d4f709e91e66c7c2b", 32166155),
    "tiny.en-q8_0": ("5bc2b3860aa151a4c6e7bb095e1fcce7cf12c7b020ca08dcec0c6d018bb7dd94", 43550795),
}
MODEL_DOWNLOAD_DEADLINE = 3600  # seconds for the whole transfer, the largest model is ~3 GB

DEFAULT_CONFIG = {
    "engine": "voxtype",          # voxtype | whisper-cpp | command
    "engineCommand": "",          # command engine: shell line, {file} and {lang} are replaced, stdout is the text
    "whisperModel": "",           # whisper-cpp engine: path to a ggml model
    "languages": [                # the first one is the default; autoSend: press Return after pasting;
        {"code": "en", "key": "SUPER ALT D", "autoSend": False, "agentKey": "", "engineArgs": ""},   # agentKey: send the text to the default agent
    ],
    "agentCommand": "omarchy-agent-prompt {text}",   # how a transcription is handed to the agent ({text} is shell-quoted)
    "liveText": True,             # transcribe while recording and show it in the bar
    "liveIntervalMs": 1500,
    "liveWindowSecs": 30,
    "keepAudio": True,            # keep the wav of every recording next to its text
    "historyDays": 30,            # delete recordings older than this (0 = keep forever)
    "outputMode": "paste",        # paste | type | clipboard
    "pasteKeys": "auto",          # auto | ctrl+v | ctrl+shift+v | shift+insert
    "restoreClipboard": True,
    "maxDurationSecs": 300,
    "device": "default",
    "animation": "bars",          # what the bar shows while recording: bars | wave | pulse | dots
    "warmMic": False,             # keep the microphone stream open between recordings: instant start + pre-roll
    "warmHoldSecs": 0,            # with warmMic: close the stream this long after the last recording (0 = keep it open)
    "prerollMs": 600,             # audio from just before the key press that a warm microphone keeps
    "cancelKey": "ESCAPE",
    "notify": True,
}

MARK = " · stt"  # suffix on every bind description this daemon creates
MODMASK = {"SHIFT": 1, "CAPS": 2, "CTRL": 4, "ALT": 8, "MOD2": 16, "MOD3": 32, "SUPER": 64, "MOD5": 128}
BARE_OK = {"ESCAPE", "PAUSE", "PRINT", "SCROLL_LOCK", "INSERT", "MENU", "CAPS_LOCK", "HOME", "END", "PAGE_UP", "PAGE_DOWN"}
KEY_ALIASES = {  # keysyms some keyboards send instead of the plain F-key
    "F13": "XF86Tools", "F14": "XF86Launch5", "F15": "XF86Launch6", "F16": "XF86Launch7",
    "F17": "XF86Launch8", "F18": "XF86Launch9", "F19": "XF86Launch1", "F20": "XF86Launch2",
    "F21": "XF86Launch3", "F22": "XF86Launch4",
}
TERMINAL_CLASSES = {"alacritty", "kitty", "foot", "com.mitchellh.ghostty", "org.omarchy.terminal", "wezterm",
                    "org.wezfurlong.wezterm", "xterm", "konsole", "org.kde.konsole", "gnome-terminal",
                    "org.gnome.terminal", "tilix", "st", "urxvt", "rio", "ptyxis", "org.gnome.ptyxis"}


LOG_FILE = os.path.join(RUNTIME, "daemon.log")
# The CLI next to this daemon: key bindings call it by absolute path, so they work whatever Hyprland's PATH is.
SOURCE = os.path.abspath(__file__)
SOURCE_MTIME = os.stat(SOURCE).st_mtime
EXIT_RELAUNCH = 4   # the source changed underneath us (plugin update): the shell service starts the new one
STT_CLI = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "bin", "stt")


def log(*a):
    line = time.strftime("%H:%M:%S") + " " + " ".join(str(x) for x in a)
    print(line, file=sys.stderr, flush=True)
    try:
        with open(LOG_FILE, "a") as f:
            f.write(line + "\n")
    except OSError:
        pass


def which(name):
    return shutil.which(name) is not None


def notify(title, body):
    cmd = "omarchy-notification-send" if which("omarchy-notification-send") else "notify-send"
    try:
        subprocess.Popen([cmd, title, body], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


# ---------------------------------------------------------------------------
# config
# ---------------------------------------------------------------------------

def load_config():
    cfg = json.loads(json.dumps(DEFAULT_CONFIG))
    try:
        with open(CONFIG) as f:
            user = json.load(f)
        for k, v in user.items():
            if k in DEFAULT_CONFIG:
                cfg[k] = v
        if user.get("autoReturn"):  # older config: one global switch -> per-language autoSend
            for l in cfg.get("languages") or []:
                if isinstance(l, dict):
                    l["autoSend"] = True
    except FileNotFoundError:
        pass
    except (OSError, ValueError) as e:
        log("config unreadable, using defaults:", e)
    cfg["languages"] = normalize_languages(cfg.get("languages"))
    return cfg


def normalize_languages(langs):
    """A language may appear several times (one entry that sends, one that
    does not…): every entry gets its own id (en, en-2, …) that the key
    bindings and `stt toggle --lang` refer to."""
    out, ids = [], set()
    for l in langs or []:
        if not isinstance(l, dict):
            continue
        code = str(l.get("code", "")).strip().lower().replace("_", "-")
        if code not in LANGUAGES:  # "pt-BR", "ptbr", "en_US" -> whisper's two-letter code
            base = code.split("-")[0]
            code = base if base in LANGUAGES else (base[:2] if base[:2] in LANGUAGES else code)
        if code not in LANGUAGES:
            continue  # unknown codes would reach `voxtype --language` and the bind's shell line
        id = str(l.get("id", "") or "").strip().lower()
        if not re.fullmatch(r"[a-z]{2,3}(-\d+)?", id) or not id.startswith(code) or id in ids:
            n, id = 1, code
            while id in ids:
                n += 1
                id = f"{code}-{n}"
        ids.add(id)
        out.append({
            "id": id,
            "code": code,
            "label": LANGUAGES.get(code, code),
            "key": str(l.get("key", "") or "").strip(),
            "autoSend": bool(l.get("autoSend", False)),
            "agentKey": str(l.get("agentKey", "") or "").strip(),
            "engineArgs": str(l.get("engineArgs", "") or ""),
        })
    if not out:
        return normalize_languages(json.loads(json.dumps(DEFAULT_CONFIG["languages"])))
    return out


def save_config(cfg):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    tmp = CONFIG + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cfg, f, indent=2)
    os.replace(tmp, CONFIG)


# ---------------------------------------------------------------------------
# key bindings (Hyprland)
# ---------------------------------------------------------------------------

def parse_key(spec):
    """'CTRL SHIFT F13' / 'ctrl+f13' / 'F13' -> ('CTRL SHIFT', 'F13'); '' -> None."""
    parts = [p for p in re.split(r"[\s+,]+", spec.strip()) if p]
    if not parts:
        return None
    key = parts[-1]
    mods = " ".join(p.upper() for p in parts[:-1])
    mods = mods.replace("CONTROL", "CTRL").replace("META", "SUPER").replace("WIN", "SUPER").replace("MOD4", "SUPER")
    if re.fullmatch(r"f\d{1,2}", key, re.I):
        key = key.upper()
    elif len(key) == 1:
        key = key.upper()
    # A bare letter/digit/symbol would hijack that key in every app: require a modifier.
    if not mods and not (re.fullmatch(r"F\d{1,2}", key) or key.startswith("XF86") or key.upper() in BARE_OK):
        return None
    return mods, key


def hyprctl(*args):
    try:
        return subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired) as e:
        log("hyprctl failed:", e)
        return None


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "") + '"'


class Binds:
    """Applies the configured toggle keys as Hyprland binds, remembers what it
    applied so a config change or a clean exit can take them back, and
    re-applies after Hyprland reloads its own config (which drops runtime binds).

    Hyprland with the Lua config (Omarchy 4) takes runtime binds through
    `hyprctl eval` and the o.bind/hl.unbind helpers; the legacy parser takes
    `hyprctl --batch keyword bindd/unbind`. Which one works is probed once."""

    def __init__(self):
        self.applied = []  # [(mods, key)]
        self.cancel_applied = None
        self.conflicts = []  # keys refused because something else is bound to them
        self.lua = None  # unknown until probed
        try:
            with open(BINDS_STATE) as f:
                saved = json.load(f)
            if isinstance(saved, dict):
                self.applied = [tuple(x) for x in saved.get("applied", [])]
                self.cancel_applied = tuple(saved["cancel"]) if saved.get("cancel") else None
            else:  # older format: a bare list
                self.applied = [tuple(x) for x in saved]
        except (OSError, ValueError, TypeError):
            pass

    @property
    def enabled(self):
        return "HYPRLAND_INSTANCE_SIGNATURE" in os.environ

    def probe(self):
        if self.lua is None:
            r = hyprctl("eval", "return type(o) == 'table' and type(o.bind) == 'function'")
            if r is not None:  # a timeout / missing hyprctl is not an answer: ask again next time
                self.lua = r.returncode == 0 and r.stdout.strip() in ("ok", "true")
        return bool(self.lua)

    def _save(self):
        try:
            os.makedirs(RUNTIME, exist_ok=True)
            with open(BINDS_STATE, "w") as f:
                json.dump({"applied": self.applied, "cancel": self.cancel_applied}, f)
        except OSError:
            pass

    def forget(self):
        """Hyprland reloaded its config: every runtime bind is gone, whatever we remember."""
        self.applied = []
        self.cancel_applied = None

    def sweep(self):
        """Startup: drop binds a previous daemon left behind (crash mid-recording), on keys nobody else uses."""
        if not self.enabled:
            return
        existing = self.current() or []
        stale = {(b[0], b[1]) for b in existing if self.ours(b[2])}
        unbinds = []
        for mask, key in stale:
            mods = " ".join(name for name, bit in MODMASK.items() if mask & bit)
            if not self.foreign(existing, mods, key):
                unbinds.append((mods, key))
        if unbinds:
            self._run(unbinds, [])
        self.applied = []
        self.cancel_applied = None

    @staticmethod
    def specs(cfg):
        out = []
        for lang in cfg["languages"]:
            code, label, lid = lang["code"], lang["label"], lang.get("id") or lang["code"]
            if not code:
                continue
            if "-" in lid:  # a second entry for the same language: tell them apart in the keybindings list
                label = f"{label} {lid.split('-')[1]}"
            if lang.get("autoSend"):
                label += ", sends"
            for field, desc, cmd in (
                ("key", f"Dictate ({label}){MARK}", f"{shlex.quote(STT_CLI)} toggle --lang {lid}"),
                ("agentKey", f"Ask agent ({label}){MARK}", f"{shlex.quote(STT_CLI)} toggle --lang {lid} --agent"),
            ):
                pk = parse_key(lang.get(field, ""))
                if not pk:
                    continue
                mods, key = pk
                out.append((mods, key, desc, cmd))
                alias = KEY_ALIASES.get(key)
                if alias:
                    out.append((mods, alias, desc, cmd))
        return out

    @staticmethod
    def current():
        """Every bind Hyprland has right now: [(modmask, key_lower, description, dispatcher)]."""
        r = hyprctl("binds", "-j")
        if not r or r.returncode != 0:
            return None
        try:
            return [(int(b.get("modmask", 0)), str(b.get("key", "")).lower(), str(b.get("description", "")),
                     str(b.get("dispatcher", ""))) for b in json.loads(r.stdout)]
        except ValueError:
            return None

    @staticmethod
    def modmask(mods):
        return sum(MODMASK.get(m, 0) for m in mods.split())

    @staticmethod
    def foreign(existing, mods, key):
        """Binds on (mods, key) that are not ours. hl.unbind / keyword unbind
        remove *every* bind on a key, so a key with a foreign bind is never
        touched: neither bound (both would fire) nor unbound (theirs would go)."""
        mask = Binds.modmask(mods)
        return [b for b in existing if b[0] == mask and b[1] == key.lower() and not Binds.ours(b[2])]

    @staticmethod
    def ours(desc):
        # Current binds carry MARK; the patterns cover binds left by a daemon from before the marker.
        return desc.endswith(MARK) or desc == "Cancel dictation" or re.fullmatch(r"(Dictate( and send)?|Ask agent) \(.+\)", desc) is not None

    def _run(self, unbinds, binds):
        """unbinds: [(mods, key)], binds: [(mods, key, desc, cmd)]."""
        if not unbinds and not binds:
            return
        # Unbinds and binds go in separate calls: within one eval Hyprland
        # applies the unbind of a key after the bind of the same key, which
        # would remove what was just added.
        results = []
        if self.probe():
            if unbinds:
                results.append(hyprctl("eval", "\n".join(
                    f"pcall(hl.unbind, {lua_str(' + '.join(m.split() + [k]))})" for m, k in unbinds)))
            if binds:
                results.append(hyprctl("eval", "\n".join(
                    f"o.bind({lua_str(' + '.join(m.split() + [k]))}, {lua_str(desc)}, {lua_str(cmd)})"
                    for m, k, desc, cmd in binds)))
        else:
            if unbinds:
                results.append(hyprctl("--batch", " ; ".join(f"keyword unbind {m},{k}" for m, k in unbinds)))
            if binds:
                results.append(hyprctl("--batch", " ; ".join(
                    f"keyword bindd {m},{k},{desc.replace(',', ' ')},exec,{cmd}" for m, k, desc, cmd in binds)))
        for r in results:
            if r is None or r.returncode != 0 or "error" in r.stdout.lower():
                log("binds failed:", r.stdout.strip() if r else "", r.stderr.strip() if r else "")
                return
        log("binds:", "lua" if self.lua else "keyword", f"-{len(unbinds)} +{len(binds)}")

    suspended = False

    def apply(self, cfg):
        if not self.enabled or self.suspended:
            return
        specs = self.specs(cfg)
        existing = self.current()
        if existing is None:
            log("binds: cannot list current binds; not touching anything")
            return
        wanted, conflicts = [], []
        for m, k, desc, cmd in specs:
            others = self.foreign(existing, m, k)
            if others:
                if k not in KEY_ALIASES.values():  # a refused alias is not worth a message
                    conflicts.append({"mods": m, "key": k, "desc": desc[: -len(MARK)],
                                      "takenBy": others[0][2] or others[0][3] or "another bind"})
                continue
            wanted.append((m, k, desc, cmd))
        # Refresh: drop what we applied before plus the keys about to be (re)bound —
        # but only keys nothing else uses.
        keys = list(self.applied) + [(m, k) for m, k, _, _ in wanted if (m, k) not in self.applied]
        unbinds = [(m, k) for m, k in keys if not self.foreign(existing, m, k)]
        self._run(unbinds, wanted)
        self.applied = [(m, k) for m, k, _, _ in wanted]
        self.conflicts = conflicts
        for c in conflicts:
            log("bind refused:", (c["mods"] + " " if c["mods"] else "") + c["key"], "is taken by", c["takenBy"])
        self._save()

    def clear(self):
        if not self.enabled or (not self.applied and not self.cancel_applied):
            return
        existing = self.current() or []
        unbinds = list(self.applied)
        if self.cancel_applied:
            unbinds.append(self.cancel_applied)
        self._run([(m, k) for m, k in unbinds if not self.foreign(existing, m, k)], [])
        self.applied = []
        self.cancel_applied = None
        self._save()

    def set_cancel(self, cfg, on):
        if not self.enabled:
            return
        pk = parse_key(cfg.get("cancelKey", "") or "")
        if on and pk:
            if self.cancel_applied == pk:
                return
            existing = self.current() or []
            if self.foreign(existing, pk[0], pk[1]):
                log("cancel key", pk, "is taken; Esc will not cancel this take")
                return
            self._run([self.cancel_applied] if self.cancel_applied else [], [(pk[0], pk[1], "Cancel dictation" + MARK, f"{shlex.quote(STT_CLI)} cancel")])
            self.cancel_applied = pk
            self._save()
        elif self.cancel_applied:
            existing = self.current() or []
            if not self.foreign(existing, *self.cancel_applied):
                self._run([self.cancel_applied], [])
            self.cancel_applied = None
            self._save()


# ---------------------------------------------------------------------------
# recorder
# ---------------------------------------------------------------------------

def bt_card_for(device):
    """bluez_input.88:C9:E8:A7:EC:7E (or bluez_input.88_C9_....0) -> bluez_card.88_C9_E8_A7_EC_7E, else None."""
    if not device.startswith("bluez_input."):
        return None
    return "bluez_card." + device[len("bluez_input."):].split(".")[0].replace(":", "_")


def request_headset_profile(device):
    """Ask for the headset (HFP) profile the moment capture starts. WirePlumber would do the same
    once it notices the stream, plus its switch timer: asking first saves ~0.15 s on the microphone
    link. Fire and forget: no-op if the profile is already active, and WirePlumber still restores
    A2DP when the stream goes away, whoever switched."""
    card = bt_card_for(device)
    if not card:
        return
    try:
        subprocess.Popen(["pactl", "set-card-profile", card, "headset-head-unit"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


class Recorder:
    def __init__(self, device):
        self.device = device
        self.proc = None
        self.thread = None
        self.buf = bytearray()
        self.levels = []
        self.lock = threading.Lock()
        self.started = 0.0
        self.error = ""
        self.listening = False  # real audio is arriving (a Bluetooth mic sends silence while it switches profile)
        self.chunks = 0
        self.nonzero_run = 0    # consecutive chunks that were not digital silence
        self.standby = False    # warm mode: the stream runs but only the last second is kept

    def start(self):
        fake = os.environ.get("STT_FAKE_INPUT")  # tests: stream a 16 kHz mono wav at real-time pace instead of the mic
        if fake:
            cmd = ["python3", "-c",
                   "import sys,time\nd=open(sys.argv[1],'rb').read()[44:]\n"
                   "for i in range(0,len(d),3200):\n sys.stdout.buffer.write(d[i:i+3200]); sys.stdout.buffer.flush(); time.sleep(0.1)\n"
                   "time.sleep(600)", fake]
        else:
            cmd = ["pw-record", "--raw", "--format=s16", f"--rate={RATE}", "--channels=1"]
            if self.device and self.device != "default":
                cmd += ["--target", self.device]
            cmd.append("-")
        self.proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.started = time.time()
        self.thread = threading.Thread(target=self._pump, daemon=True)
        self.thread.start()

    def _pump(self):
        out = self.proc.stdout
        while True:
            data = out.read(CHUNK)
            if not data:
                break
            n = len(data) // 2
            samples = struct.unpack(f"<{n}h", data[: n * 2])
            rms = math.sqrt(sum(s * s for s in samples) / max(1, n)) / 32768.0
            level = min(1.0, math.sqrt(rms * 12.0))  # perceptual-ish: speech at normal level fills most of the bar
            self.chunks += 1
            # Green means "your voice is getting through". Clear input (speech, room noise on most
            # mics) turns it on at once. Otherwise wait for three consecutive chunks that are not
            # digital silence: a Bluetooth headset delivers exact zeros until its microphone link
            # is up, the virtual mic emits one stray nonzero chunk right after start (processing
            # residue), and the headset's own floor then ramps in from a few LSB with the odd
            # all-zero chunk. No time-based fallback: a mic that only sends zeros is not listening.
            self.nonzero_run = self.nonzero_run + 1 if rms > 0 else 0
            if rms > 0.0005 or self.nonzero_run >= 3:
                self.listening = True
            with self.lock:
                self.buf += data
                self.levels.append(round(level, 3))  # one per 50 ms; indexed by absolute offset, never trimmed while recording
                if self.standby and len(self.buf) > 3 * RATE * 2:  # warm: keep only the last 1.5 s
                    drop = len(self.buf) - int(1.5 * RATE) * 2
                    drop -= drop % CHUNK
                    del self.buf[:drop]
                    del self.levels[: drop // CHUNK]
        err = self.proc.stderr.read().decode(errors="replace").strip()
        rc = self.proc.wait()
        if rc not in (0, -15, -9) and err:
            self.error = err.splitlines()[-1]

    def stop(self):
        """Blocking (up to ~1 s): call it from an executor, never on the event loop."""
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=0.5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()
        if self.thread:
            self.thread.join(timeout=1)

    @property
    def alive(self):
        return self.proc is not None and self.proc.poll() is None

    def park(self):
        """Warm mode: keep the stream open between recordings, remembering only the last moment."""
        with self.lock:
            self.standby = True

    def begin(self, preroll_secs):
        """Turn a parked stream into a recording, keeping `preroll_secs` of what was just heard."""
        keep = int(preroll_secs * RATE) * 2
        keep -= keep % CHUNK
        with self.lock:
            self.standby = False
            if keep and len(self.buf) > keep:
                drop = len(self.buf) - keep
                del self.buf[:drop]
                del self.levels[: drop // CHUNK]
            kept = len(self.buf)
        self.started = time.time() - kept / 2 / RATE
        self.error = ""

    @property
    def duration(self):
        with self.lock:
            return len(self.buf) / 2 / RATE

    def snapshot(self, last_secs=None):
        with self.lock:
            if last_secs is None:
                return bytes(self.buf)
            n = int(last_secs * RATE) * 2
            return bytes(self.buf[-n:])

    @property
    def size(self):
        with self.lock:
            return len(self.buf)

    def snapshot_range(self, a, b):
        with self.lock:
            return bytes(self.buf[a:b])

    def levels_copy(self):
        with self.lock:
            return list(self.levels)

    def recent_levels(self, n=LEVELS):
        with self.lock:
            lv = self.levels[-n:]
        return [0.0] * (n - len(lv)) + lv


def write_wav(path, pcm):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm)


# ---------------------------------------------------------------------------
# engines
# ---------------------------------------------------------------------------

def available_engines():
    out = []
    if which("voxtype"):
        out.append("voxtype")
    if which("whisper-cli") or which("whisper-cpp") or which("whisper"):
        out.append("whisper-cpp")
    out.append("command")
    return out


def voxtype_model():
    try:
        with open(VOXTYPE_CONFIG) as f:
            m = re.search(r'^\s*model\s*=\s*"([^"]+)"', f.read(), re.M)
        return m.group(1) if m else "base.en"
    except OSError:
        return "base.en"


VOXTYPE_QUIET_CONFIG = os.path.join(RUNTIME, "voxtype.toml")


def voxtype_config():
    """voxtype's config with pause_media, audio feedback and typing turned off:
    transcribing a file must not pause the music or beep. Rebuilt whenever the
    user's config changes; falls back to the user's own file."""
    try:
        src = os.stat(VOXTYPE_CONFIG)
    except OSError:
        return None
    try:
        if os.stat(VOXTYPE_QUIET_CONFIG).st_mtime >= src.st_mtime:
            return VOXTYPE_QUIET_CONFIG
    except OSError:
        pass
    try:
        with open(VOXTYPE_CONFIG) as f:
            text = f.read()
        text = re.sub(r"^(\s*pause_media\s*=\s*)true", r"\1false", text, flags=re.M)
        text = re.sub(r"^(\s*state_file\s*=\s*).*$", r'\1"disabled"', text, flags=re.M)
        if "pause_media" not in text:
            text += "\n[audio]\npause_media = false\n"
        tmp = VOXTYPE_QUIET_CONFIG + ".tmp"
        with open(tmp, "w") as f:
            f.write(text)
        os.replace(tmp, VOXTYPE_QUIET_CONFIG)
        return VOXTYPE_QUIET_CONFIG
    except OSError:
        return VOXTYPE_CONFIG


def model_for(cfg, lang):
    """The whisper model a take in `lang` will use with the voxtype engine (None for other engines)."""
    if cfg.get("engine", "voxtype") != "voxtype":
        return None
    m = voxtype_model()
    if lang["code"] != "en" and m.endswith(".en"):
        m = m[:-3]  # an English-only model cannot do other languages
    if "/" in m:  # a custom path in voxtype's config
        return None
    return m


def model_path(model):
    return os.path.join(VOXTYPE_MODELS, f"ggml-{model}.bin")


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


class EngineRun:
    """The transcription process now running (if any), so cancel/shutdown can kill it."""
    proc = None
    lock = threading.Lock()

    @classmethod
    def run(cls, args, shell=False):
        proc = subprocess.Popen(args, shell=shell, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        with cls.lock:
            cls.proc = proc
        try:
            out, err = proc.communicate(timeout=600)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.communicate()
            raise
        finally:
            with cls.lock:
                if cls.proc is proc:
                    cls.proc = None
        return proc.returncode, out, err

    @classmethod
    def kill(cls):
        with cls.lock:
            proc = cls.proc
        if proc and proc.poll() is None:
            proc.kill()


def run_engine(cfg, lang, path):
    """Blocking. Returns (text, error)."""
    engine = cfg.get("engine", "voxtype")
    code = lang["code"]
    try:
        extra = shlex.split(lang.get("engineArgs", "") or "")
    except ValueError as e:
        return "", f"bad engine arguments: {e}"
    try:
        if engine == "voxtype":
            if not which("voxtype"):
                return "", "voxtype is not installed — run omarchy-voxtype-install"
            args = ["voxtype", "-q"]
            quiet = voxtype_config()
            if quiet:
                args += ["-c", quiet]
            args += ["--language", code]
            model = model_for(cfg, lang)
            if model and model != voxtype_model():
                args += ["--model", model]
            args += extra + ["transcribe", path]
            rc, out, err = EngineRun.run(args)
            if rc != 0:
                return "", (err.strip().splitlines() or ["voxtype failed"])[-1]
            lines = out.splitlines()
            for i, l in enumerate(lines):
                if l.startswith("Processing ") and "samples" in l:
                    lines = lines[i + 1:]
                    break
            return " ".join(l.strip() for l in lines if l.strip()).strip(), ""
        if engine == "whisper-cpp":
            binary = next((b for b in ("whisper-cli", "whisper-cpp", "whisper") if which(b)), None)
            if not binary:
                return "", "whisper-cli is not installed"
            model = cfg.get("whisperModel") or ""
            if not model:
                return "", "set the whisper.cpp model path in Settings"
            args = [binary, "-m", os.path.expanduser(model), "-l", code, "-nt", "-np"] + extra + ["-f", path]
            rc, out, err = EngineRun.run(args)
            if rc != 0:
                return "", (err.strip().splitlines() or ["whisper failed"])[-1]
            return " ".join(l.strip() for l in out.splitlines() if l.strip()).strip(), ""
        if engine == "command":
            tmpl = cfg.get("engineCommand") or ""
            if not tmpl.strip():
                return "", "set the recognition command in Settings"
            line = tmpl.replace("{file}", shlex.quote(path)).replace("{lang}", shlex.quote(code))
            if extra:
                line += " " + " ".join(shlex.quote(a) for a in extra)
            rc, out, err = EngineRun.run(line, shell=True)
            if rc != 0:
                return "", (err.strip().splitlines() or ["command failed"])[-1]
            return out.strip(), ""
        return "", f"unknown engine {engine}"
    except subprocess.TimeoutExpired:
        return "", "transcription timed out"
    except OSError as e:
        return "", str(e)


# ---------------------------------------------------------------------------
# output (paste / type / clipboard)
# ---------------------------------------------------------------------------

def clipboard_text():
    try:
        types = subprocess.run(["wl-paste", "--list-types"], capture_output=True, text=True, timeout=2).stdout
        if "text/plain" not in types:
            return None
        r = subprocess.run(["wl-paste", "--no-newline", "--type", "text/plain"], capture_output=True, timeout=2)
        return r.stdout if r.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def wl_copy(data):
    if isinstance(data, str):
        data = data.encode()
    try:
        subprocess.run(["wl-copy"], input=data, timeout=5)
    except (OSError, subprocess.TimeoutExpired) as e:
        notify("Speech to text", f"wl-copy failed: {e}")


def active_is_terminal():
    r = hyprctl("activewindow", "-j")
    if not r or r.returncode != 0:
        return False
    try:
        w = json.loads(r.stdout)
    except ValueError:
        return False
    for tag in w.get("tags") or []:
        if str(tag).rstrip("*") == "terminal":
            return True
    cls = str(w.get("class") or w.get("initialClass") or "").lower()
    return cls in TERMINAL_CLASSES


def wtype(*args):
    try:
        subprocess.run(["wtype", *args], timeout=10)
    except (OSError, subprocess.TimeoutExpired) as e:
        notify("Speech to text", f"wtype failed: {e}")


def press_paste(keys):
    if keys == "auto":
        keys = "ctrl+shift+v" if active_is_terminal() else "ctrl+v"
    if keys == "ctrl+shift+v":
        wtype("-M", "ctrl", "-M", "shift", "-k", "v", "-m", "shift", "-m", "ctrl")
    elif keys == "shift+insert":
        wtype("-M", "shift", "-k", "Insert", "-m", "shift")
    else:
        wtype("-M", "ctrl", "-k", "v", "-m", "ctrl")


def deliver(cfg, text, enter):
    """Blocking. Puts the text where the cursor is, then optionally presses Return."""
    mode = cfg.get("outputMode", "paste")
    saved = None
    if mode in ("paste", "clipboard"):
        if mode == "paste" and cfg.get("restoreClipboard", True):
            saved = clipboard_text()
        wl_copy(text)
        if mode == "paste":
            time.sleep(0.08)
            press_paste(cfg.get("pasteKeys", "auto"))
    elif mode == "type":
        wtype("-d", "1", "--", text)
    if enter:
        time.sleep(0.15)
        wtype("-k", "Return")
    if saved is not None:
        time.sleep(0.4)
        wl_copy(saved)


def audio_sources():
    """Microphones PipeWire offers: [{name, label}] (a virtual one like Microphone Effects included)."""
    try:
        r = subprocess.run(["pw-dump"], capture_output=True, text=True, timeout=5)
        nodes = json.loads(r.stdout) if r.returncode == 0 else []
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return []
    out = []
    for n in nodes:
        props = (n.get("info") or {}).get("props") or {}
        if props.get("media.class") != "Audio/Source":
            continue
        name = str(props.get("node.name") or "")
        if not name or name.startswith("alsa_output") or "monitor" in name:
            continue
        out.append({"name": name, "label": str(props.get("node.description") or props.get("node.nick") or name)})
    return out


def missing_tools(cfg):
    """What a stock machine may still lack; the panel offers to install it."""
    out = []
    if not which("pw-record"):
        out.append("pipewire")
    if not which("wtype"):
        out.append("wtype")
    if cfg.get("engine", "voxtype") == "voxtype" and not which("voxtype"):
        out.append("voxtype")
    if not which("wl-copy"):
        out.append("wl-clipboard")
    return out


def deliver_agent(cfg, text):
    """Blocking. Hands the text to the default coding agent (a new terminal) instead of pasting it."""
    tmpl = cfg.get("agentCommand") or "omarchy-agent-prompt {text}"
    line = tmpl.replace("{text}", shlex.quote(text)) if "{text}" in tmpl else tmpl + " " + shlex.quote(text)
    try:
        subprocess.Popen(["sh", "-c", line], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError as e:
        notify("Speech to text", f"Could not launch the agent: {e}")


# ---------------------------------------------------------------------------
# history
# ---------------------------------------------------------------------------

class History:
    def __init__(self):
        os.makedirs(TAKES, exist_ok=True)
        self.db = sqlite3.connect(DB)
        self.db.execute(
            "CREATE TABLE IF NOT EXISTS takes (id INTEGER PRIMARY KEY, created_at REAL, duration REAL,"
            " lang TEXT, engine TEXT, text TEXT, audio TEXT, delivered INTEGER)"
        )
        self.db.commit()

    def add(self, created_at, duration, lang, engine, text, audio, delivered):
        cur = self.db.execute(
            "INSERT INTO takes (created_at, duration, lang, engine, text, audio, delivered) VALUES (?,?,?,?,?,?,?)",
            (created_at, duration, lang, engine, text, audio, int(delivered)),
        )
        self.db.commit()
        return cur.lastrowid

    @staticmethod
    def row(r):
        return {"id": r[0], "createdAt": r[1], "duration": r[2], "lang": r[3], "engine": r[4], "text": r[5],
                "audio": r[6] or "", "delivered": bool(r[7])}

    def get(self, id):
        r = self.db.execute("SELECT * FROM takes WHERE id=?", (id,)).fetchone()
        return self.row(r) if r else None

    def list(self, query="", limit=50, offset=0):
        q = f"%{query}%"
        rows = self.db.execute(
            "SELECT * FROM takes WHERE text LIKE ? ORDER BY id DESC LIMIT ? OFFSET ?", (q, limit, offset)
        ).fetchall()
        total = self.db.execute("SELECT COUNT(*) FROM takes WHERE text LIKE ?", (q,)).fetchone()[0]
        return [self.row(r) for r in rows], total

    def delete(self, id):
        t = self.get(id)
        if not t:
            return
        if t["audio"]:
            try:
                os.remove(t["audio"])
            except OSError:
                pass
        self.db.execute("DELETE FROM takes WHERE id=?", (id,))
        self.db.commit()

    def clear(self):
        for (audio,) in self.db.execute("SELECT audio FROM takes").fetchall():
            if audio:
                try:
                    os.remove(audio)
                except OSError:
                    pass
        self.db.execute("DELETE FROM takes")
        self.db.commit()

    def update_text(self, id, text):
        self.db.execute("UPDATE takes SET text=? WHERE id=?", (text, id))
        self.db.commit()

    def prune(self, days):
        """Delete recordings older than `days` (0: keep everything). Returns how many went."""
        if not days or days <= 0:
            return 0
        cutoff = time.time() - days * 86400
        rows = self.db.execute("SELECT id, audio FROM takes WHERE created_at < ?", (cutoff,)).fetchall()
        for id, audio in rows:
            if audio:
                try:
                    os.remove(audio)
                except OSError:
                    pass
        self.db.execute("DELETE FROM takes WHERE created_at < ?", (cutoff,))
        self.db.commit()
        return len(rows)


# ---------------------------------------------------------------------------
# daemon
# ---------------------------------------------------------------------------

class Daemon:
    def __init__(self):
        self.cfg = load_config()
        self.binds = Binds()
        self.history = History()
        self.clients = set()
        self.state = "idle"  # idle | recording | transcribing
        self.lang = self.cfg["languages"][0]
        self.rec = None
        self.partial = ""
        self.last = None
        self.error = ""
        self.playing = 0
        self.play_proc = None
        self.enter_pending = False
        self.agent_mode = False   # this recording goes to the agent, not the cursor
        # Incremental transcription of the running take: text for audio before
        # committed_off is final; tail_text is the live guess for what follows.
        self.committed = []
        self.committed_off = 0
        self.tail_text = ""
        self.engine_lock = None
        self.download = None   # {"model", "pct", "error"} while a model is being fetched
        self.download_task = None
        self.wanted_model = ""   # model a refused recording was waiting for
        self.engines = available_engines()  # cached: state is pushed 20×/s while recording
        self.agent = self.agent_name()
        self.sources = audio_sources()
        self.missing = missing_tools(self.cfg)
        self.error_clear = None  # timer handle: errors fade by themselves
        self.warm = None         # a parked Recorder (warmMic): the stream is already open when the key is pressed
        self.warm_close = None   # timer handle: with warmHoldSecs, the parked stream closes after a quiet spell
        self.loop = None
        self.stopping = False
        self.stop_event = None
        self.exit_code = 0

    # ---- state ----
    def state_msg(self, full=False):
        """full: include the static language table (initial greeting and explicit `get`)."""
        rec = self.rec if self.state != "idle" else None
        msg = {
            "type": "state",
            "version": VERSION,
            "state": self.state,
            "lang": self.lang["code"],
            "langLabel": self.lang["label"],
            "startedAt": rec.started if rec else 0,
            "elapsed": round(rec.duration, 1) if rec else 0,
            "listening": bool(rec and rec.listening),
            "levels": rec.recent_levels() if rec and self.state == "recording" else [],
            "partial": self.partial,
            "last": self.last,
            "error": self.error,
            "playing": self.playing,
            "config": self.cfg,
            "engines": self.engines,
            "binds": [{"mods": m, "key": k, "desc": d[: -len(MARK)]} for m, k, d, _ in Binds.specs(self.cfg)
                      if k not in KEY_ALIASES.values() and (m, k) in self.binds.applied],
            "conflicts": self.binds.conflicts,
            "download": self.download,
            "agentName": self.agent,
            "agentMode": self.agent_mode if self.state != "idle" else False,
            "missing": self.missing,
            "strings": UI_STRINGS.get(self.lang["code"], UI_STRINGS["en"]),
            "warm": bool(self.warm and self.warm.alive),
        }
        if full:
            msg["languageNames"] = LANGUAGES
            msg["sources"] = self.sources
        return msg

    def refresh_environment(self):
        """Things that change rarely and cost a subprocess: only on demand."""
        self.engines = available_engines()
        self.agent = self.agent_name()
        self.sources = audio_sources()
        self.missing = missing_tools(self.cfg)

    def broadcast(self, msg=None):
        line = (json.dumps(msg or self.state_msg()) + "\n").encode()
        for w in list(self.clients):
            try:
                if w.transport.get_write_buffer_size() > 1_000_000:  # a client that stopped reading
                    raise ConnectionError("client not draining")
                w.write(line)
            except Exception:
                self.clients.discard(w)
                try:
                    w.close()
                except Exception:
                    pass

    # ---- recording ----
    def find_lang(self, ref):
        """The entry with this id (en-2), else the first with this code, else the default (the first in the list)."""
        usable = [l for l in self.cfg["languages"] if l["code"]]
        if ref:
            for l in usable:
                if l.get("id") == ref:
                    return l
            for l in usable:
                if l["code"] == ref:
                    return l
        return usable[0] if usable else self.cfg["languages"][0]

    @staticmethod
    def agent_name():
        try:
            with open(os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config")), "omarchy", "defaults", "agent")) as f:
                return f.read().strip()
        except OSError:
            return ""

    # ---- models ----
    def missing_models(self):
        out = []
        for l in self.cfg["languages"]:
            m = model_for(self.cfg, l)
            if m and not os.path.exists(model_path(m)) and m not in out:
                out.append(m)
        return out

    def ensure_models(self):
        """Fetch every model the configured languages need, one after the other, in the background."""
        if self.download_task and not self.download_task.done():
            return
        missing = self.missing_models()
        if missing:
            self.download_task = self.loop.create_task(self.fetch_model(missing[0]))

    def lang_for_model(self, model):
        for l in self.cfg["languages"]:
            if model_for(self.cfg, l) == model:
                return l["label"]
        return model

    async def fetch_model(self, model):
        if model not in MODEL_DIGESTS:
            self.fail(f"No pinned checksum for the {model} model; put ggml-{model}.bin in {VOXTYPE_MODELS} yourself")
            return
        want_sha, want_size = MODEL_DIGESTS[model]
        os.makedirs(VOXTYPE_MODELS, exist_ok=True)
        dest = model_path(model)
        fd, part = tempfile.mkstemp(prefix=f"ggml-{model}.", suffix=".part", dir=VOXTYPE_MODELS)
        os.close(fd)
        url = MODEL_URL.format(model=model)
        self.download = {"model": model, "lang": self.lang_for_model(model), "pct": 0, "error": ""}
        self.broadcast()
        log("downloading model", model)
        proc = None
        try:
            proc = await asyncio.create_subprocess_exec(
                "curl", "-sSL", "--fail", "--proto", "=https",
                "--max-filesize", str(want_size), "--max-time", str(MODEL_DOWNLOAD_DEADLINE),
                "--speed-limit", "1000", "--speed-time", "60",  # give up when stalled for a minute
                "-o", part, url, stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.PIPE)
            while proc.returncode is None:
                try:
                    await asyncio.wait_for(proc.wait(), timeout=0.5)
                except asyncio.TimeoutError:
                    pass
                try:
                    done = os.path.getsize(part)
                except OSError:
                    done = 0
                self.download["pct"] = int(done * 100 / want_size)
                self.broadcast()
            err = (await proc.stderr.read()).decode(errors="replace").strip()
            if proc.returncode != 0:
                raise RuntimeError(err.splitlines()[-1] if err else f"curl exited {proc.returncode}")
            size = os.path.getsize(part)
            if size != want_size:
                raise RuntimeError(f"unexpected size ({size} bytes, expected {want_size})")
            got_sha = await self.loop.run_in_executor(None, sha256_file, part)
            if got_sha != want_sha:
                raise RuntimeError("checksum mismatch; the file was discarded")
            os.chmod(part, 0o644)  # mkstemp makes it private; models are plain shared files
            os.replace(part, dest)
            log("model ready", dest)
            self.download = None
            if self.wanted_model == model:  # a recording was refused while waiting for this one
                self.wanted_model = ""
                self.error = ""
                if self.cfg.get("notify", True):
                    label = self.lang_for_model(model)
                    key = next((l["key"] for l in self.cfg["languages"] if l["label"] == label and l["key"]), "")
                    notify("Speech to text", f"Ready for {label}" + (f" — press {key} to dictate" if key else ""))
        except asyncio.CancelledError:
            if proc and proc.returncode is None:
                proc.kill()
            self.download = None
            raise
        except Exception as e:  # noqa: BLE001 - anything here is "the download failed"
            self.download = None
            self.fail(f"Could not download the {model} model: {e}")
        finally:
            try:
                os.remove(part)
            except OSError:
                pass
        self.broadcast()
        self.download_task = None
        self.ensure_models()  # next one, if any

    # ---- warm microphone ----
    def ensure_warm(self):
        """With warmMic on, keep a parked stream ready whenever nothing is recording."""
        if self.stopping or self.state != "idle":
            return
        if not self.cfg.get("warmMic"):
            if self.warm:
                w, self.warm = self.warm, None
                self.loop.run_in_executor(None, w.stop)
            return
        if self.warm and self.warm.alive:
            return
        if self.warm:
            self.loop.run_in_executor(None, self.warm.stop)
        if self.missing or not which("pw-record"):
            self.warm = None
            return
        if self.cfg.get("warmHoldSecs", 0) and self.cfg.get("warmHoldSecs", 0) > 0 and not self.rec:
            # With a hold time the stream is only kept open *after* a recording, not opened ahead of one.
            self.warm = None
            return
        rec = Recorder(self.cfg.get("device", "default"))
        try:
            rec.start()
        except (OSError, ValueError, TypeError) as e:
            log("warm microphone failed:", e)
            self.warm = None
            return
        rec.park()
        self.warm = rec

    def _arm_warm_close(self):
        """With a hold time, a parked stream is closed once nothing has been recorded for that long
        (a Bluetooth headset then drops back to its music profile)."""
        if self.warm_close:
            self.warm_close.cancel()
            self.warm_close = None
        hold = self.cfg.get("warmHoldSecs", 0)
        if self.cfg.get("warmMic") and hold and hold > 0:
            self.warm_close = self.loop.call_later(hold, self._close_warm)

    def _close_warm(self):
        self.warm_close = None
        if not self.warm:
            return
        if self.state != "idle":  # still transcribing: look again in a moment
            self.warm_close = self.loop.call_later(2, self._close_warm)
            return
        w, self.warm = self.warm, None
        self.loop.run_in_executor(None, w.stop)
        self.broadcast()

    async def release_rec(self, rec):
        """A recording is over: park the stream (warm) or close it (off the loop: pw-record can take a moment to die)."""
        if self.cfg.get("warmMic") and rec.alive and not self.stopping:
            rec.park()
            self.warm = rec
            self._arm_warm_close()
        else:
            if self.warm is rec:
                self.warm = None
            await self.loop.run_in_executor(None, rec.stop)

    async def start(self, code=None, agent=False):
        if self.state != "idle":
            self.broadcast()
            return
        self.missing = missing_tools(self.cfg)
        if self.missing:
            self.fail("Dictation needs " + ", ".join(self.missing) + " — open the microphone icon to install it")
            self.broadcast()
            return
        self.agent_mode = bool(agent)
        self.lang = self.find_lang(code)
        model = model_for(self.cfg, self.lang)
        if model and not os.path.exists(model_path(model)):
            # Not an error: the bar shows "Getting ready for <language> · N%" while it downloads.
            self.ensure_models()
            self.wanted_model = model
            self.broadcast()
            return
        self.error = ""
        self.partial = ""
        self.committed = []
        self.committed_off = 0
        self.tail_text = ""
        if self.warm and self.warm.alive and self.warm.device == self.cfg.get("device", "default"):
            # The stream is already open: no start-up gap, and the moment before the key press comes along.
            self.rec = self.warm
            self.warm = None
            self.rec.begin(max(0, int(self.cfg.get("prerollMs", 600))) / 1000)
        else:
            if self.warm:
                self.warm.stop()
                self.warm = None
            self.rec = Recorder(self.cfg.get("device", "default"))
            request_headset_profile(self.rec.device or "")
            try:
                self.rec.start()
            except (OSError, ValueError, TypeError) as e:
                self.rec = None
                self.fail(f"cannot record: {e}")
                self.broadcast()
                return
        self.state = "recording"
        self.binds.set_cancel(self.cfg, True)
        self.broadcast()
        self.loop.create_task(self.pump_levels())
        if self.cfg.get("liveText", True):
            self.loop.create_task(self.live_loop())

    async def pump_levels(self):
        rec = self.rec
        while self.state == "recording" and self.rec is rec:
            if rec.proc.poll() is not None:
                self.fail(rec.error or "The microphone stopped")
                await self.cancel()
                return
            if rec.duration >= self.cfg.get("maxDurationSecs", 300):
                await self.stop(False)
                return
            self.broadcast()
            await asyncio.sleep(0.05)

    # ---- incremental transcription ----
    # Whisper has no streaming mode, so the take is cut at pauses: everything
    # up to the last pause is transcribed once and kept ("committed"), and only
    # the part after it is re-transcribed on every tick and again at stop. That
    # keeps the live text cheap on long takes and makes stop fast: it only has
    # to transcribe the last phrase.
    LEVEL_SECS = CHUNK / 2 / RATE  # one level per chunk (50 ms)

    def _thresholds(self, levels):
        """(silence, voice) thresholds adapted to the take's noise floor."""
        if len(levels) < 10:
            return 0.10, 0.14
        floor = sorted(levels)[len(levels) // 4]
        return floor + 0.04, max(0.14, floor + 0.10)

    def _voiced(self, levels, a, b):
        lv = levels[a // CHUNK: max(a // CHUNK + 1, b // CHUNK)]
        return bool(lv) and max(lv) > self._thresholds(levels)[1]

    def _find_cut(self, levels):
        """Byte offset in the middle of the last pause after committed_off, or None.
        A pause is >= 0.6 s under the silence threshold, ending >= 0.3 s ago,
        with >= 1 s of audio before it. Very long uncommitted stretches are cut
        at their quietest recent point so the tail never grows unbounded."""
        n = len(levels)
        first = self.committed_off // CHUNK
        silent, _ = self._thresholds(levels)
        gap, settle, min_chunk = 12, 6, 20
        i = n - settle
        while i - gap >= first + min_chunk:
            if max(levels[i - gap:i]) < silent:
                return (i - gap // 2) * CHUNK
            i -= 1
        if n - first > 25 * 20:
            window = levels[n - 100:n - settle]
            j = min(range(len(window)), key=lambda k: window[k])
            return (n - 100 + j) * CHUNK
        return None

    async def _transcribe_range(self, audio, a, b, prefix):
        """Run the engine on audio[a:b] (under the engine lock). Returns text ('' for noise) or None on error."""
        pcm = bytes(audio[a:b])
        if len(pcm) < int(0.3 * RATE) * 2:
            return ""
        fd, tmp = tempfile.mkstemp(prefix=prefix, suffix=".wav", dir=RUNTIME)
        os.close(fd)
        write_wav(tmp, pcm)
        try:
            async with self.engine_lock:
                text, err = await self.loop.run_in_executor(None, run_engine, self.cfg, self.lang, tmp)
        finally:
            try:
                os.remove(tmp)
            except OSError:
                pass
        if err:
            self.error = err
            return None
        return text if re.search(r"\w", text) else ""  # whisper answers noise with lone punctuation

    def _partial_text(self):
        return " ".join(self.committed + ([self.tail_text] if self.tail_text else []))

    async def live_loop(self):
        rec = self.rec
        interval = max(0.4, self.cfg.get("liveIntervalMs", 1500) / 1000)
        await asyncio.sleep(interval)
        while self.state == "recording" and self.rec is rec:
            levels = rec.levels_copy()
            audio = rec.snapshot()
            cut = self._find_cut(levels)
            if cut is not None and cut > self.committed_off:
                a = self.committed_off
                text = await self._transcribe_range(audio, a, cut, "live-") if self._voiced(levels, a, cut) else ""
                if self.rec is not rec:
                    return
                if text is not None:  # on an engine error the segment stays uncommitted and is retried
                    if text:
                        self.committed.append(text)
                    self.committed_off = cut
                    self.tail_text = ""
            else:
                a, b = self.committed_off, len(audio)
                if b - a > int(0.8 * RATE) * 2 and self._voiced(levels, a, b):
                    text = await self._transcribe_range(audio, a, b, "live-")
                    if self.rec is not rec:
                        return
                    if text:
                        self.tail_text = text
            self.partial = self._partial_text()
            self.broadcast()
            await asyncio.sleep(interval)

    async def stop(self, enter=False, agent=False):
        if self.state != "recording":
            self.broadcast()
            return
        rec = self.rec
        pcm = rec.snapshot()          # frozen now: a parked stream keeps only its last moment
        levels = rec.levels_copy()
        started = rec.started
        self.state = "transcribing"
        await self.release_rec(rec)
        self.enter_pending = bool(enter)
        agent = bool(agent) or self.agent_mode
        lang = self.lang
        self.binds.set_cancel(self.cfg, False)
        self.broadcast()
        path = ""
        try:
            duration = len(pcm) / 2 / RATE
            stamp = time.strftime("%Y%m%d-%H%M%S", time.localtime(started))
            path = os.path.join(TAKES, f"{stamp}-{lang['code']}.wav")
            write_wav(path, pcm)
            if duration < 0.3:
                text, err = "", "nothing recorded"
            elif self.cfg.get("liveText", True) and (self.committed or self.committed_off):
                # The live loop already transcribed everything before committed_off
                # (a call in flight finishes under the engine lock and commits);
                # only the tail after the last pause is left.
                async with self.engine_lock:
                    pass
                if self.rec is not rec:
                    raise asyncio.CancelledError
                committed, off = list(self.committed), self.committed_off
                a, b = off, len(pcm)
                tail = await self._transcribe_range(pcm, a, b, "final-") if self._voiced(levels, a, b) else ""
                if tail is None:
                    text, err = "", self.error
                else:
                    text, err = " ".join(committed + ([tail] if tail else [])), ""
            else:
                text, err = await self.loop.run_in_executor(None, run_engine, self.cfg, lang, path)
            if self.rec is not rec:  # cancelled (or restarted) meanwhile: this recording is void
                raise asyncio.CancelledError
            if err:
                self._discard(path)
                self.fail(err)
            elif not re.search(r"\w", text):  # empty, or whisper's lone punctuation for noise
                self._discard(path)
                self.fail("Nothing heard")
            else:
                if not self.cfg.get("keepAudio", True):
                    self._discard(path)
                    path = ""
                id = self.history.add(started, duration, lang["code"], self.cfg.get("engine", "voxtype"),
                                      text, path, self.cfg.get("outputMode", "paste") != "clipboard")
                self.last = {"id": id, "text": text, "lang": lang["code"], "duration": round(duration, 1),
                             "createdAt": started, "enter": self.enter_pending, "agent": agent}
                self.error = ""
                if agent:
                    await self.loop.run_in_executor(None, deliver_agent, self.cfg, text)
                else:
                    await self.loop.run_in_executor(None, deliver, self.cfg, text, self.enter_pending)
                if self.history.prune(self.cfg.get("historyDays", 30)):
                    log("history pruned")
                self.broadcast({"type": "history-changed"})
        except asyncio.CancelledError:
            self._discard(path)
            return
        except Exception as e:  # noqa: BLE001 - whatever failed, the daemon must not get stuck in "transcribing"
            self._discard(path)
            log("stop failed:", repr(e))
            self.fail(f"Transcription failed: {e}")
        finally:
            if self.rec is rec:
                self.state = "idle"
                self.rec = None
                self.partial = ""
                self.ensure_warm()
                self.broadcast()

    @staticmethod
    def _discard(path):
        try:
            os.remove(path)
        except OSError:
            pass

    async def cancel(self):
        if self.state == "idle":
            self.broadcast()
            return
        rec = self.rec
        self.state = "idle"
        self.rec = None
        self.partial = ""
        EngineRun.kill()   # a transcription in flight is for a recording nobody wants
        self.binds.set_cancel(self.cfg, False)
        self.broadcast()
        if rec:
            await self.release_rec(rec)
        self.ensure_warm()
        self.broadcast()

    async def toggle(self, code=None, enter=False, agent=False):
        if self.state == "idle":
            await self.start(code, agent)
        elif self.state == "recording":
            await self.stop(enter or bool(self.lang.get("autoSend")), agent)
        else:
            self.broadcast()  # transcribing: nothing to do, but answer whoever asked

    def fail(self, msg):
        self.error = msg
        log("error:", msg)
        if self.cfg.get("notify", True):
            notify("Speech to text", msg)
        # The bar and the popup show it for a moment; it must not stay lit until someone dismisses it.
        if self.error_clear:
            self.error_clear.cancel()
        self.error_clear = self.loop.call_later(8, self._clear_error, msg)

    def _clear_error(self, msg):
        if self.error == msg:
            self.error = ""
            self.broadcast()

    # ---- history actions ----
    async def play(self, id):
        self.stop_play()
        t = self.history.get(id)
        if not t or not t["audio"] or not os.path.exists(t["audio"]):
            self.fail("This recording has no audio")
            self.broadcast()
            return
        try:
            self.play_proc = subprocess.Popen(["pw-play", t["audio"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError as e:
            self.fail(str(e))
            self.broadcast()
            return
        self.playing = id
        self.broadcast()
        proc = self.play_proc
        while proc.poll() is None:
            await asyncio.sleep(0.2)
        if self.play_proc is proc:
            self.play_proc = None
            self.playing = 0
            self.broadcast()

    def stop_play(self):
        if self.play_proc and self.play_proc.poll() is None:
            self.play_proc.terminate()
        self.play_proc = None
        self.playing = 0

    # ---- config ----
    def set_config(self, patch):
        for k, v in (patch or {}).items():
            if k not in DEFAULT_CONFIG:
                continue
            want = type(DEFAULT_CONFIG[k])
            if want is bool and isinstance(v, bool):
                pass
            elif want in (int, float) and isinstance(v, (int, float)) and not isinstance(v, bool):
                v = want(v)
            elif want is str and isinstance(v, str):
                pass
            elif want is list and isinstance(v, list):
                pass
            elif want is int and isinstance(v, str) and v.strip().lstrip("-").isdigit():
                v = int(v)
            else:
                self.fail(f"{k}: expected {want.__name__}, got {type(v).__name__}")
                continue
            self.cfg[k] = v
        if not (5 <= self.cfg.get("maxDurationSecs", 300) <= 7200):
            self.cfg["maxDurationSecs"] = DEFAULT_CONFIG["maxDurationSecs"]
        self.cfg["languages"] = normalize_languages(self.cfg.get("languages"))
        if self.lang.get("id") not in [l.get("id") for l in self.cfg["languages"]]:
            self.lang = self.cfg["languages"][0]
        try:
            save_config(self.cfg)
        except OSError as e:
            self.fail(f"cannot save config: {e}")
        self.binds.apply(self.cfg)
        self.refresh_environment()
        if "historyDays" in (patch or {}) and self.history.prune(self.cfg.get("historyDays", 30)):
            self.broadcast({"type": "history-changed"})
        if self.warm and ("device" in (patch or {}) or not self.cfg.get("warmMic")):
            w, self.warm = self.warm, None
            self.loop.run_in_executor(None, w.stop)
        self.ensure_warm()
        if self.warm:
            self._arm_warm_close()
        self.ensure_models()

    # ---- socket ----
    async def handle(self, reader, writer):
        self.clients.add(writer)
        try:
            writer.write((json.dumps(self.state_msg(full=True)) + "\n").encode())
            while True:
                try:
                    line = await reader.readline()
                except (ValueError, asyncio.LimitOverrunError):  # a line longer than the limit
                    break
                if not line:
                    break
                try:
                    msg = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(msg, dict):
                    continue
                try:
                    await self.dispatch(msg, writer)
                except Exception as e:  # noqa: BLE001 - one bad request must not take the connection down
                    log("request failed:", repr(msg)[:200], repr(e))
        except (ConnectionError, asyncio.CancelledError):
            pass
        finally:
            self.clients.discard(writer)
            try:
                writer.close()
            except Exception:
                pass

    def spawn(self, coro):
        """Slow work (a recording's stop, a paste) runs as its own task so the
        connection keeps answering — the shell's cancel/get must not queue
        behind a transcription."""
        task = self.loop.create_task(coro)
        task.add_done_callback(lambda t: log("task failed:", repr(t.exception())) if not t.cancelled() and t.exception() else None)
        return task

    @staticmethod
    def _id(msg):
        try:
            return int(msg.get("id") or 0)
        except (TypeError, ValueError):
            return 0

    @staticmethod
    def _lang(msg):
        v = msg.get("lang")
        return str(v) if isinstance(v, str) and v else None

    async def dispatch(self, msg, writer):
        cmd = msg.get("cmd")
        if cmd == "get":
            self.refresh_environment()
            writer.write((json.dumps(self.state_msg(full=True)) + "\n").encode())
        elif cmd == "install":
            # Omarchy's own installer (asks for confirmation and the password in a floating terminal).
            self.spawn(self.loop.run_in_executor(None, lambda: subprocess.Popen(
                ["omarchy-launch-floating-terminal-with-presentation", "omarchy-voxtype-install"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)))
        elif cmd == "toggle":
            self.spawn(self.toggle(self._lang(msg), bool(msg.get("enter")), bool(msg.get("agent"))))
        elif cmd == "start":
            self.spawn(self.start(self._lang(msg), bool(msg.get("agent"))))
        elif cmd == "stop":
            self.spawn(self.stop(bool(msg.get("enter")) or bool(self.lang.get("autoSend")), bool(msg.get("agent"))))
        elif cmd == "suspendBinds":   # the panel is capturing a key: ours must not fire
            self.binds.clear()
            self.binds.suspended = True
        elif cmd == "resumeBinds":
            self.binds.suspended = False
            self.binds.apply(self.cfg)
            self.broadcast()
        elif cmd == "cancel":
            await self.cancel()
        elif cmd == "history":
            query = str(msg.get("query", "") or "")[:200]
            limit = max(1, min(1000, self._id({"id": msg.get("limit", 50)}) or 50))
            offset = max(0, self._id({"id": msg.get("offset", 0)}))
            items, total = self.history.list(query, limit, offset)
            writer.write((json.dumps({"type": "history", "items": items, "total": total,
                                      "query": query, "offset": offset}) + "\n").encode())
        elif cmd == "delete":
            self.history.delete(self._id(msg))
            self.broadcast({"type": "history-changed"})
        elif cmd == "clearHistory":
            self.history.clear()
            self.broadcast({"type": "history-changed"})
        elif cmd == "copy":
            t = self.history.get(self._id(msg))
            if t:
                self.spawn(self.loop.run_in_executor(None, wl_copy, t["text"]))
        elif cmd == "paste":
            t = self.history.get(self._id(msg))
            if t:
                self.spawn(self.loop.run_in_executor(None, deliver, self.cfg, t["text"], bool(msg.get("enter"))))
        elif cmd == "edit":
            self.history.update_text(self._id(msg), str(msg.get("text", ""))[:100_000])
            self.broadcast({"type": "history-changed"})
        elif cmd == "play":
            self.spawn(self.play(self._id(msg)))
        elif cmd == "stopPlay":
            self.stop_play()
            self.broadcast()
        elif cmd == "set":
            patch = msg.get("config")
            self.set_config(patch if isinstance(patch, dict) else {})
            self.broadcast()
        elif cmd == "setLang":
            if self.state == "idle":
                self.lang = self.find_lang(str(msg.get("lang", "")))
                self.broadcast()
        elif cmd == "rebind":
            self.binds.apply(self.cfg)
            self.broadcast()
        elif cmd == "clearError":
            self.error = ""
            self.broadcast()
        elif cmd == "quit":
            self.loop.create_task(self.shutdown())

    # ---- hyprland events: re-apply binds after a config reload ----
    async def hypr_events(self):
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        if not sig:
            return
        path = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "hypr", sig, ".socket2.sock")
        while not self.stopping:
            try:
                reader, writer = await asyncio.open_unix_connection(path)
                while True:
                    line = await reader.readline()
                    if not line:
                        break
                    if line.startswith(b"configreloaded"):
                        await asyncio.sleep(0.3)
                        self.binds.forget()   # the reload dropped every runtime bind
                        self.binds.apply(self.cfg)
                        if self.state == "recording":
                            self.binds.set_cancel(self.cfg, True)
                writer.close()
            except OSError:
                pass
            await asyncio.sleep(5)

    async def warm_watch(self):
        """A parked stream can die (device unplugged, headset off): reopen it when it does."""
        while not self.stopping:
            await asyncio.sleep(3)
            if self.cfg.get("warmMic") and self.state == "idle" and (not self.warm or not self.warm.alive) and not self.cfg.get("warmHoldSecs", 0):
                self.ensure_warm()

    async def source_watch(self):
        """Plugin updated while running: exit when idle so the shell service relaunches the new code."""
        while not self.stopping:
            await asyncio.sleep(5)
            try:
                changed = os.stat(SOURCE).st_mtime != SOURCE_MTIME
            except OSError:
                changed = False
            if changed and self.state == "idle" and not (self.download_task and not self.download_task.done()):
                log("daemon source changed; relaunching")
                self.exit_code = EXIT_RELAUNCH
                await self.shutdown()
                return

    async def shutdown(self):
        if self.stopping:
            return
        self.stopping = True
        if self.rec:
            self.rec.stop()
        if self.warm:
            self.warm.stop()
            self.warm = None
        EngineRun.kill()
        if self.download_task and not self.download_task.done():
            self.download_task.cancel()
            try:
                await self.download_task
            except (asyncio.CancelledError, Exception):  # noqa: BLE001
                pass
        self.stop_play()
        self.binds.clear()
        for w in list(self.clients):
            try:
                w.close()
            except Exception:
                pass
        self.stop_event.set()

    async def run(self):
        self.loop = asyncio.get_running_loop()
        self.stop_event = asyncio.Event()
        self.engine_lock = asyncio.Lock()
        os.makedirs(RUNTIME, exist_ok=True)
        try:
            os.remove(SOCK)
        except OSError:
            pass
        server = await asyncio.start_unix_server(self.handle, path=SOCK, limit=1 << 20)
        self.binds.sweep()
        self.binds.apply(self.cfg)
        if self.history.prune(self.cfg.get("historyDays", 30)):
            log("history pruned")
        self.ensure_warm()
        self.ensure_models()
        self.loop.create_task(self.hypr_events())
        self.loop.create_task(self.warm_watch())
        self.loop.create_task(self.source_watch())
        for s in (signal.SIGTERM, signal.SIGINT):
            self.loop.add_signal_handler(s, lambda: self.loop.create_task(self.shutdown()))
        log(f"sttd {VERSION} listening on {SOCK}")
        async with server:
            await server.start_serving()
            await self.stop_event.wait()


def main():
    os.makedirs(RUNTIME, exist_ok=True)
    try:
        if os.path.getsize(LOG_FILE) > 200_000:
            os.remove(LOG_FILE)
    except OSError:
        pass
    lockf = open(LOCK, "w")
    try:
        fcntl.flock(lockf, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        log("another sttd holds the lock; exiting")
        sys.exit(3)
    # The socket is not removed on exit: the shell may already have started a
    # replacement daemon that listens on the same path.
    daemon = Daemon()
    asyncio.run(daemon.run())
    sys.exit(daemon.exit_code)


if __name__ == "__main__":
    main()
