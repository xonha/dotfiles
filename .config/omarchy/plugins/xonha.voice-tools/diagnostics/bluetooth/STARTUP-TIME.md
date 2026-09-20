# How we cut Bluetooth microphone startup time

Measured on a Sony WH-1000XM5 over an Intel AX210, PipeWire 1.6.8, WirePlumber
0.5.17, kernel 7.2.3. Times are after the dictation key press.

| | before | after |
|---|---|---|
| mic link (eSCO) up | 0.7–1.0 s, sometimes never | 0.15–0.18 s |
| first real audio at the daemon | 1.5–1.7 s, or never | 0.82–0.86 s |
| "Listening" in the bar | 2.1 s on a timer, even with no audio | 0.86–0.94 s, only on real audio |

"After" is with the daemon recording straight from `bluez_input.<addr>`; via
`camera-effects-mic` add ~0.25 s (its 250 ms poll and processing).

## What changed

| Change | Where it lives | Gain |
|---|---|---|
| Daemon indicator: green on real audio only (RMS > 0.0005 or three consecutive non-silent chunks), no timer | `daemon/sttd.py` | the bar cannot claim to listen to a dead mic |
| Daemon asks for the headset profile itself at capture start (`pactl set-card-profile`), before WirePlumber notices the stream | `daemon/sttd.py` | link up ~0.1 s sooner (0.21–0.27 s → 0.15–0.18 s); WirePlumber still restores A2DP |
| Record from `bluez_input.<addr>` instead of `camera-effects-mic` | `~/.config/speech-to-text/config.json` | ~0.25 s sooner, no noise suppression on dictation |
| WirePlumber profile-switch timeout 500 ms → 50 ms | `~/.local/share/wireplumber/scripts/device/autoswitch-bluetooth-profile.lua` | link up ~0.45 s sooner |
| A2DP auto-connect rule narrowed to the XM5 | `~/.config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf` | no 5 s pages of absent devices at login |
| btusb driver patch `0002` | `/usr/lib/modules/<kernel>/updates/btusb.ko` | mic link no longer comes up silent when a page overlaps it |
| PipeWire bluez5 patches `0001` + `0003` | `~/.local/lib/spa-0.2/bluez5/` via `SPA_PLUGIN_DIR` drop-ins | no stale-error dead takes; back-to-back takes work |

Only the first two rows are part of this repo. The rest are machine-level and are
described, with patches and measurements, in [HANDOFF.md](HANDOFF.md).

## Why ~0.85 s is the floor

```
key press
0.00 s ─┬─ daemon asks for the headset profile, starts pw-record
        │
0.07 s ─┼─ eSCO connect() reaches the kernel
        │   headset leaves sniff mode, radio sets up the link
0.16 s ─┼─ eSCO link up
        │
        │   headset sends encoded digital silence while its own
        │   mic path starts and mSBC syncs: ~0.6 s
        │   (measured at the decoder; Linux cannot shorten it)
        │
0.80 s ─┼─ first non-zero samples leave the headset
        │   decode + 50 ms chunking
0.85 s ─┴─ first real audio reaches the daemon
```

Nothing measurable is left on the Linux side.

The headset's silence after link-up and the eSCO setup are hardware. Words
spoken in the first ~0.9 s are lost unless the microphone is already in
hands-free mode, which drops playback to mono, so it is off by default
(`warmMic`).
