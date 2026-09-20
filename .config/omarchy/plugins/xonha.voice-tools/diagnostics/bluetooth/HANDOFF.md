# XM5 dictation startup: investigation handoff

Date: 2026-09-09. Status: **fixed and installed** (see the resolution section
below). The older sections are kept as the investigation record.

## Resolution, 2026-09-09 afternoon session

Three independent faults were reproduced, fixed and re-measured with
`tools/trial2.py` (kernel kprobes with the `mono` trace clock, the daemon's own
level stream, the card profile before/during/after each take). Everything below
is installed on this machine; nothing was submitted upstream.

### 1. Silent first start: btusb alternate-setting bug (patch `0002`)

Reproduced on the first stock attempt (`tools/stock-repro-1.log`): eSCO
`connect()` at 0.76 s stuck behind two pages, `btusb_switch_alt_setting(0)` and
the isochronous submit failure at 0.95 s, link up at 6.19 s with **zero** SCO
URBs for its whole life. With the patched module the exact same race
(`tools/patched-repro-3.log`: eSCO request stalled 3 s behind a page timeout,
`HCI_NOTIFY_CONN_DEL` ignored, alt setting 6 programmed on
`ENABLE_SCO_TRANSP`) delivered audio.

Installed: `/usr/lib/modules/7.2.3-arch1-3/updates/btusb.ko` (+ `depmod`);
`modinfo -n btusb` resolves there. btusb is not in the UKI, so no initramfs
rebuild was needed. A kernel upgrade replaces the whole modules directory and
silently returns to the stock driver; rebuild `tools/btusb.c` against the new
kernel and reinstall. `/etc/modprobe.d` needs nothing.

The trigger was `~/.config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf`
matching every card. It is now narrowed to `bluez_card.88_C9_E8_A7_EC_7E`.
Disabling it entirely was tried first and is wrong: after a WirePlumber restart
the XM5's A2DP profile does not come back on its own (the card offered only
`headset-head-unit`), so the XM5 needs the rule. Absent devices are no longer
paged (`journalctl -u bluetooth` shows no "Host is down" after a restart).

### 2. Autoswitch delay: 50 ms script now in effect

`~/.local/share/wireplumber/scripts/device/autoswitch-bluetooth-profile.lua`
(the packaged script with `PROFILE_SWITCH_TIMEOUT_MSEC = 50`). eSCO connect
moved from 0.65–0.85 s to 0.26–0.49 s after the start command. The
ineffective copy under `~/.config/wireplumber/scripts/device/` is still there
(this session could not delete it); it is harmless.

### 3. PipeWire: stale error replay and a hangup counted as failure (patches `0001`, `0003`)

With 1 and 2 in place, 1 take in 3 still came up silent with the stock plugin:
`bluez_input ... running -> error` right at acquire, the `0001` replay
(`tools/normal-5.log`, journal 11:26:46). `0001` is a real, independent bug,
not a symptom of the paging.

With `0001` alone, the 4th of 4 quick takes failed with
`spa.audioadapter: can't send command 2: Input/output error` and no eSCO
request at all (`tools/pw-4.log`). Cause: every take ends with
`Failure in Bluetooth audio transport .../fd60` because `media-sink.c`
converts the SCO hangup (the headset drops SCO when the profile goes back to
A2DP) into `SPA_BT_TRANSPORT_STATE_ERROR`, and `spa_bt_transport_acquire()`
returns `-EIO` once `error_count >= 3` within a 6 s window
(`TRANSPORT_ERROR_TIMEOUT = 2 * BLUEZ_ACTION_RATE_MSEC`). Four takes each
started within ~8 s of the previous one ending is enough. Patch `0003` skips
that escalation for an HFP sink that already wrote data (sco-io only writes
after the first packet came in, so this implies the link was really up).

Installed: `~/.local/lib/spa-0.2/bluez5/libspa-bluez5.so` (PipeWire 1.6.8 +
`0001` + `0003`, built with `--prefix=/usr` so `bluez-hardware.conf` resolves
to `/usr/share`), selected by
`~/.config/systemd/user/{pipewire,wireplumber}.service.d/spa-plugin-dir.conf`
(`SPA_PLUGIN_DIR=/home/tank/.local/lib/spa-0.2:/usr/lib/spa-0.2`). Codec
plugins still come from `/usr/lib/spa-0.2/bluez5`. WirePlumber is the process
that maps the plugin. After a PipeWire upgrade rebuild against the new source
(the build needs `gdbus-codegen`, extracted from `glib2-devel` without
installing it, and a `gio-2.0.pc` copy pointing at it) or delete the two
drop-ins to fall back to the packaged plugin. A copy of the built plugin is in
`tools/libspa-bluez5.so`.

Result: 8 of 8 rapid takes (`tools/pw2-*.log`) and 6 more after that with no
transport failure, no start error, A2DP restored 2 s after every take.

### 4. Honest "Listening" indicator (`daemon/sttd.py`)

The 40-chunk fallback lit the indicator at 2.1 s on a dead microphone. The
level stream showed why a plain "first nonzero chunk" test is wrong too: the
virtual mic emits one stray nonzero chunk at ~0.15 s (level 0.02, processing
residue), then exact zeros until the headset floor ramps in from a few LSB
with the odd all-zero chunk (`tools/win-*.log`). The daemon now turns
`listening` on at RMS > 0.0005 or after three consecutive nonzero chunks, and
never on a timer. Measured: 1.19–1.43 s after the start command, 0–0.14 s
after the first nonzero chunk (`tools/ind2-*.log`).

### Timeline now (normal path, quiet room)

| after F13 | event |
|---|---|
| 0.26–0.49 s | eSCO link up |
| 1.06–1.43 s | first nonzero PCM at the daemon |
| 1.19–1.43 s | UI "Listening" |

The 0.7–0.9 s between link-up and first PCM is the headset's own silence plus
the Camera Effects path; see the earlier analysis. The remaining Linux-side
gain would be requesting the headset profile from the daemon at capture start
(~0.25 s), not done: the autoswitch script only restores a profile it switched
itself, so a daemon-side switch would leave the headset in mono after the take.

### Not fixable

Stereo playback while the headset microphone is in use: A2DP is one-way and
the WH-1000XM5 has no LE Audio. Every OS drops to mono HFP for its mic.

### Files added this session

`0003-media-sink-hfp-hangup-after-audio-is-not-a-failure.patch`,
`tools/trial2.py` (trial driver, replaces `trial.sh`, which needed a `/tmp`
script that is gone), `tools/libspa-bluez5.so`, `tools/*.log`.
`tools/kernel-probes.sh` now disables the events before rewriting them, so it
can be re-run after a module reload.

---

## Earlier record (superseded where the resolution above says so)

## Update, 2026-09-09 later session: silent first start root-caused

Status: **the "first microphone start gets no audio at all" failure is fully
explained and reproduced under kernel tracing; a kernel driver patch is written and
built but not loaded. The remaining startup delay is measured and its floor is set
by the headset, not by Linux.**

### The silent start is a btusb driver bug, triggered by paging absent devices

Reproduced twice out of two attempts by restarting WirePlumber and starting
dictation about 10 s later. Kernel event order (kprobes, see `tools/`):

1. PipeWire `connect()`s the mSBC SCO socket: `hci_conn_add_unset(ESCO)` puts the
   pending link in the connection hash (counted by `hci_conn_num(SCO_LINK)`), and
   the Enhanced Setup Synchronous Connection command is queued.
2. The command does **not** go out for 2.3 s: bluetoothd is paging another paired
   device at that moment, and the kernel's synchronous Create Connection request
   holds the HCI command queue until its Connect Complete arrives (page timeout,
   ~5.1 s). Any dictation start that overlaps such a page stalls the same way.
3. Connect Complete arrives with status 0x04 (Page Timeout) for that other device;
   its `hci_conn_del()` notifies btusb with `HCI_NOTIFY_CONN_DEL`.
4. `btusb_notify()` only compares `hci_conn_num(SCO_LINK)` (now 1, the pending
   link) with its `data->sco_num` (0), stores CONN_DEL as the "air mode" and runs
   `btusb_work()`, which computes `new_alts = 0` and submits isochronous URBs on the
   alternate-setting-0 endpoints (wMaxPacketSize 0). `usb_submit_urb()` returns
   -EMSGSIZE: that is the `urb ... submission failed (90)` line. The `len 0 mtu 0`
   debug print from `__fill_isoc_descriptor` confirms it.
5. 0.14 s later the eSCO link comes up (Synchronous Connect Complete, air mode
   transparent) and `HCI_NOTIFY_ENABLE_SCO_TRANSP` is sent, but the count already
   matches `data->sco_num`, so nothing is scheduled. The interface stays on
   alternate setting 0 for the life of the link: no SCO URBs, no audio either way.
   PipeWire waits for the first incoming packet (USB adapters) forever, the daemon
   sees silence, and "Listening" appears only from the 40-chunk fallback.

All four historical `submission failed (90)` entries (00:49, 00:53, 01:39, 02:17)
sit 2–5 s after a WirePlumber restart, and the "physical HFP nodes enter error"
failures in the stock trials are the same event seen from PipeWire (the pending
SCO connect fails with the paging device's status). The `0001` PipeWire patch
therefore addresses a symptom of this, not an independent bug.

Why a page was in flight: the user's own
`~/.config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf` sets
`bluez5.auto-connect = [ a2dp_sink a2dp_source ]`. On every WirePlumber start
PipeWire calls `ConnectProfile()` on every paired A2DP device that is not connected
("Nothing Ear (3)" and "RB Meta 042Q" here), bluetoothd pages each for 5.1 s, and
the whole HCI command queue is blocked while it does. In normal use that is the
first ~11 s after login or after any WirePlumber restart; every absent paired
device extends it by ~5 s. Dropping that rule, or narrowing its match to the
devices it was written for, removes the trigger. The btusb bug itself fires on
any non-SCO connection add/remove that lands while an eSCO link is pending (an
LE device connecting, another ACL dropping), so it stays worth fixing.

Fix: `0002-btusb-program-isoc-alt-setting-on-every-sco-enable.patch` changes
`btusb_notify()` to program the interface on every `ENABLE_SCO_*` notification and
to ignore count increases from other events. `tools/btusb.ko` is that patch built
against the exact stable 7.2.3 source (identical to the local driver source) with
the installed headers, vermagic `7.2.3-arch1-3 SMP preempt mod_unload`. It is
**not loaded**; test with `sudo rmmod btusb && sudo insmod tools/btusb.ko`
(headset reconnects), revert with `sudo rmmod btusb && sudo modprobe btusb`.
Not submitted upstream.

### Normal-path timing, stock, ACL in sniff mode (trace of 02:49:34.93)

| after F13 | event |
|---|---|
| 0.01 s | daemon recording, pw-record running |
| 0.28 s | Camera Effects helper stream running, autoswitch script triggered |
| 0.79 s | autoswitch 500 ms timer fires, profile set to headset-head-unit |
| 0.82 s | SCO `connect()`; Exit Sniff Mode, Mode Change 65 ms later |
| 1.01 s | eSCO up (Enhanced Setup Sync took 117 ms); first SCO packet 19 ms later |
| ~1.2 s | first decoded PCM, all zeros (earlier instrumented runs) |
| 1.61 s | first nonzero input at Camera Effects; 1.72 s first nonzero daemon level |
| 2.07 s | UI "Listening" (40-chunk fallback; room noise is below the RMS threshold) |

The 0.5–0.6 s between eSCO link-up and the first nonzero sample is the headset:
it sends encoded digital silence for roughly 300 ms after the link opens, plus
mSBC sync. Linux cannot shorten it. What Linux can shorten:

- The 500 ms autoswitch timer (`PROFILE_SWITCH_TIMEOUT_MSEC` in
  `/usr/share/wireplumber/scripts/device/autoswitch-bluetooth-profile.lua`):
  ~0.45 s. A copy with 50 ms placed at
  `~/.config/wireplumber/scripts/device/autoswitch-bluetooth-profile.lua` was
  **not** picked up (measured: still 500 ms). It is still there; remove it, or move
  it to `~/.local/share/wireplumber/scripts/device/` (where the user's other
  script lives) and re-measure the gap between `Triggering profile switch` and
  `Switching profile` in the WirePlumber journal at info level.
- The ~0.27 s before the profile switch is even requested (Camera Effects 250 ms
  maintenance poll opening the helper stream, then WirePlumber noticing it).
  Requesting the headset profile directly when capture starts would remove most
  of it.

With both, eSCO link-up lands near 0.3–0.35 s and first real audio near 0.9 s.
That is the floor with this headset. Words spoken before ~0.9 s are lost unless
the microphone is already in HFP, which the user has rejected; the honest
alternative is an indicator that turns on only when nonzero physical input
arrives, which the current 0.0005 RMS threshold and 40-chunk fallback do not give
(quiet-room noise measured RMS ~1e-4, Camera Effects residue ~4e-5).

### Stereo playback while the microphone is used

Not possible with this headset on any OS. A2DP is one-way; the microphone
needs an HFP SCO link, and the WH-1000XM5 has no LE Audio. Windows and macOS drop
to the same mono hands-free profile when its microphone is used.

### State after this session

Stock btusb loaded (srcversion matches the packaged module), all kprobes and
dynamic-debug prints removed, no btmon running, WirePlumber restarted with default
logging and `WIREPLUMBER_DEBUG` unset, dictation idle, warm mic off. The only
persistent change is the ineffective script copy under
`~/.config/wireplumber/scripts/device/`. `tools/` holds the probe installer
(`kernel-probes.sh`, `off` to remove), the trial driver (`trial.sh`, needs
`/tmp/stt-startup-trace.py`), the restart-and-retry reproducer (`repro-loop.sh`),
and the patched driver source and module.

## Required outcome

F13 dictation must use the Sony WH-1000XM5's own microphone, start immediately
without losing opening words, and preserve headphone playback quality. The user
rejects substituting the webcam microphone and keeping HFP/mic capture permanently
open. Do not compare this with Deadlock. Mac/Windows microphone selection was not
verified; do not assume that comparison establishes an identical Bluetooth path.

## Verified state at handoff

- Stock WirePlumber is active/running, with no service drop-ins and no test SPA or
  data-directory environment overrides.
- Camera Effects explicitly selects `bluez_input.88:C9:E8:A7:EC:7E` (WH-1000XM5).
- Speech-to-text is idle, warm capture is false, Camera Effects is not capturing.
- No btmon, pkexec, startup trace, or patched-test process remains running.
- The earlier unwanted webcam-microphone substitution was reverted.
- No kernel/module replacement, system package installation, permanent candidate
  PipeWire installation, or upstream submission was done.
- Repository status is only untracked `diagnostics/`; STT runtime source was not
  changed by this investigation.

## Actual application path

`F13 -> speech-to-text/bin/stt -> daemon/sttd.py -> pw-record -> camera-effects-mic`

VoxType is the transcription engine here, not the ordinary VoxType microphone
daemon. Testing its separate CLI does not reproduce the F13 startup path.

Camera Effects creates `camera-effects-mic-input`, which links through the
WirePlumber Bluetooth loopback to the physical HFP source. A helper capture named
`camera-effects-mic-headset` triggers automatic profile switching. The user's
Camera Effects permission rule hides raw microphones from unrelated clients;
do not bypass that rule by impersonating an allowed client.

STT requests raw S16, 16 kHz, mono audio in 50 ms chunks. Its `listening` flag
becomes true when RMS exceeds 0.0005, or after 40 chunks (two seconds of PCM).
This flag controls UI readiness, not recording commencement: preceding chunks
are already collected. Therefore quiet input can show a two-second delay, and
silence from a disconnected microphone can falsely become "Listening."

Camera Effects maintenance polls every 250 ms. Its virtual stream supplies
silence before the physical mic is ready and may initially contain residual
buffered audio. First virtual buffers or early virtual nonzero samples are not
reliable proof that current headset speech is being captured. Read-only input
metering and instrumentation at the Bluetooth decoder are more meaningful.

## Measurements

Tests invoked the same daemon start command used by F13, without keyboard
dispatch. Six-second takes were cancelled, not pasted or saved as completed
history. Live transcription may nevertheless have processed data during them.

Stock observations:

- Daemon recording state begins in roughly 12–20 ms; virtual PCM around 160 ms.
- WirePlumber intentionally waits 500 ms before a headset-profile switch and
  restarts that timer on further relevant graph events. Restoration waits 2 s.
- Profile change generally starts around 0.6–0.9 s.
- HCI synchronous connection completion was around 0.87–1.02 s. That is not
  equivalent to microphone audio being ready.
- Some trials fail entirely: physical HFP nodes enter error, or usable audio
  never arrives. A stock failing trial stopped accumulating PCM at 0.8 s.
- Kernel logs sometimes contain `Bluetooth: hci0: urb ... submission failed (90)`.
  Error 90 is EMSGSIZE. Which USB submission path causes it is not yet proven.

With the candidate PipeWire fix and temporary decoder instrumentation, two
successful trials measured: incoming encoded packets at 0.97–0.99 s; first decoded
PCM at 1.16–1.19 s; first nonzero decoded PCM at 1.48–1.50 s; nonzero PCM sent to
the graph at 1.53–1.55 s; Camera Effects input signal around 1.62 s; UI readiness
around 2.14 s. This narrows the delay but does not establish speech intelligibility.
Initial zero packets versus codec synchronization versus headset startup remains
unresolved. The H2 reader itself parses a 60-byte frame without an explicit timer.

The first trial after the instrumented WirePlumber restart received no encoded
audio within six seconds, with a USB submission error around 4.46 s.

## Candidate actual PipeWire bug

An HFP transport can retain ERROR from an earlier use. `sco_acquire_cb()` starts
an asynchronous connection without changing that stale state. A second node
acquiring the same transport takes the reference-count branch in
`spa_bt_transport_acquire()` and re-emits the old ERROR, even though the new
connection subsequently succeeds.

Observed debug sequence: 01:32:25.430 acquire, .447 second acquire/error replay,
.538 successful connection (BST). The candidate sets PENDING while the asynchronous
acquire is in progress. It does not signal readiness early or suppress real errors.

Files in this directory:

- `0001-bluez5-mark-sco-acquire-pending.patch`
- `test_sco_acquire.py`: extracts the actual acquire functions and compiles them
  with mocked I/O. Original source fails; patched source passes cold/retry
  concurrent acquire, delayed readiness, synchronous success, and real failures.

The Bluetooth component builds. No stale-error replay was observed in the three
initial patched trials, but silent startup remained. This is a partial candidate,
not proof of an end-to-end fix. The relevant upstream master acquire function
inspected during the investigation matched 1.6.8; nothing was submitted upstream.

## Important integration-test confounds

The local Meson build used its default `/usr/local` prefix. A later log showed
that the test plugin could not load the installed Bluetooth hardware-quirks file:
it searched `/usr/local/share/spa-0.2/bluez5/bluez-hardware.conf`, while the file is
at `/usr/share/spa-0.2/bluez5/bluez-hardware.conf`. Correct build prefix/data paths
before attributing any patched-versus-stock behavior to the candidate patch.

A separate 50 ms WirePlumber-delay experiment previously removed roughly 450 ms
but did not eliminate failures. The latest attempted combined test did not run:
`WIREPLUMBER_DATA_DIR` pointed to a copied system data directory without the user's
required `camera-effects-hide-mics.lua`. WirePlumber hit its restart limit. The
override was removed and stock service restored/reset successfully. Do not count
this attempt as latency data. Preserve user scripts when building another overlay.

## Machine and relevant paths

- PipeWire 1.6.8, WirePlumber 0.5.17, BlueZ 5.87, kernel 7.2.3-arch1-3.
- Intel AX210 Bluetooth USB 8087:0032; device `/sys/bus/usb/devices/1-9`,
  isochronous interface `1-9:1.1`, full-speed USB.
- Sony WH-1000XM5 address 88:C9:E8:A7:EC:7E.
- Observed profiles: A2DP AAC/SBC/SBC-XQ and HFP CVSD/mSBC. No LE Audio profile
  observed. Idle playback is AAC stereo; mic use selects mSBC mono HFP.
- Those observations do not establish that a Linux-only update can provide the
  headset mic plus unchanged stereo playback. That part of the requirement is
  unresolved; do not promise it as a consequence of reducing switching delay.
- Camera Effects running binary: `/usr/local/lib/camera-effects/camera-effects-server`.
- Camera Effects sources: `/home/tank/.config/omarchy/plugins/alanfortlink.camera-effects/daemon/src/`.
- STT config: `/home/tank/.config/speech-to-text/config.json`.
- Camera Effects config: `/home/tank/.config/camera-effects/config.json`.
- WirePlumber user scripts include both `~/.config/wireplumber/scripts/` and
  `~/.local/share/wireplumber/scripts/camera-effects-hide-mics.lua`.

## Temporary working materials (may disappear after reboot)

Root: `/tmp/stt-bluetooth-switch.uZDCcW/`

- `pipewire-1.6.8/`: official source plus candidate backend patch and temporary
  `media-source.c` timing instrumentation. `build-test/` holds its Meson build.
- `backend-native.c`, `bluez5-dbus.c`, `media-source.c`: original source copies.
- `patched-spa/bluez5/libspa-bluez5.so`: experimental component; **not suitable
  for permanent installation** given the caveat above.
- `build-tools.ini`, `build-tools/`: extracted matching glib2 development tool
  used for gdbus-codegen, without installing system packages.
- `run-patched-test.sh`: temporary service override, three cancelled captures,
  automatic restoration. Correct its environment setup before reuse.
- `autoswitch-bluetooth-profile.lua`: packaged script with 500 changed to 50 ms.
- `filter-hci.py`: btmon metadata-only filter, drops audio/keys/addresses. Fixed
  SCO parser recognizes actual `> BR-ESCO:` RX and `< BR-ESCO:` TX headers.
  Earlier zero RX/TX counts from the incorrect parser were invalid evidence.
- `btusb.c`: upstream v7.2 driver reference, not yet checked against all 7.2.3
  changes; `bluez-packet.c`: BlueZ 5.87 monitor formatting reference.
- `/tmp/stt-startup-trace.py`: daemon start/cancel, graph and input-meter timing.

## Most useful remaining work

1. Correct the test build paths and repeat controlled stock/patched measurements.
2. Trace the first-start USB failure. `sudo -n true` succeeded at the end of this
   investigation, so passwordless scoped tracing may now be available. Earlier
   pending pkexec/btmon authentication was cancelled; it is not running.
3. Tracefs exists at `/sys/kernel/tracing`, accessible with sudo. No probes were
   installed. No perf/bpftrace/bpftool is installed; kernel headers and BTF exist.
4. Determine which `usb_submit_urb` returns EMSGSIZE and the associated endpoint,
   alternate setting, and packet lengths. USB alt6 permits 63 bytes; SCO frames
   observed were 60 bytes. Kernel SCO_OPTIONS reports 96, which PipeWire already
   knows is unreliable for USB and avoids by waiting for incoming packet size.
5. Investigate before changing that wait: native SCO waits for readable data on
   USB before declaring transport ready; sco-io also waits for RX before TX.
   No-RX startup could involve this interaction, the driver, or the headset.
6. Treat quality preservation as a separate capability question, not a side
   effect of a latency patch. Do not restore webcam or warm-mic workarounds.
