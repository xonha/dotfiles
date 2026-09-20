# F13 Bluetooth startup investigation

Status: **fixed and installed on 2026-09-09** — three faults (btusb
alternate-setting bug, PipeWire stale-error replay, PipeWire counting the
end-of-take SCO hangup as a failure), the 500 ms autoswitch delay, and the
daemon's false "Listening" indicator. Stereo playback with the headset
microphone is not possible with this headset. Full account in the resolution
section at the top of [HANDOFF.md](HANDOFF.md).

## Reproduction

Environment: PipeWire 1.6.8, WirePlumber 0.5.17, BlueZ 5.87,
Linux 7.2.3-arch1-3, Intel AX210 USB Bluetooth, Sony WH-1000XM5.
Measurements taken on 2026-09-09, with the dictation microphone initially idle.

The F13 extension uses its Python daemon and `pw-record`, targeting
`camera-effects-mic`. VoxType performs transcription, not microphone startup.
Tests invoked the same daemon start command, omitting keyboard dispatch, and
cancelled the take without pasting or adding completed recordings to history.

Observed on the stock system:

- Recording state starts in roughly 12–20 ms.
- The virtual microphone supplies buffers before the Bluetooth mic connects;
  even an early nonzero level can be buffered data, not current microphone input.
- Successful HCI synchronous-connection completion was measured around
  0.87–1.02 seconds after the start command. This does not establish when usable
  speech first arrives.
- A failing trial accumulated 0.8 seconds of PCM, then stayed at that duration
  through cancellation at six seconds. Both physical HFP nodes entered error.
- The UI also has a separate signal threshold / two-seconds-of-PCM fallback.
  Its “Listening” indication is not proof of physical microphone readiness.

## Candidate PipeWire fix

An HFP transport can retain `SPA_BT_TRANSPORT_STATE_ERROR` from an earlier use.
`sco_acquire_cb()` starts an asynchronous connection but does not change that
state while waiting. A second node acquiring the same transport executes
`spa_bt_transport_acquire()`'s reference-count path, which re-emits the retained
error to both nodes. This can happen even though the new connection succeeds
shortly afterward.

The debug trace reproduced that sequence: acquire at 01:32:25.430,
second acquire and error re-emission at .447, successful completion at .538 BST.

`0001-bluez5-mark-sco-acquire-pending.patch` sets the state to `PENDING` during
the asynchronous acquire. It does not report readiness early, disable genuine
errors, change the Bluetooth codec, keep the microphone open, or shorten
WirePlumber's profile-switch delay. It applies to PipeWire 1.6.8; the corresponding
acquire function in the upstream master source inspected that day was unchanged.

## Validation and limits

`test_sco_acquire.py` compiles the actual two acquire functions with mocked I/O.
It fails against the unmodified source and passes with the patch. It covers
concurrent cold/retry acquisition, delayed readiness, synchronous success, and
real connection failures. It is a focused reproduction harness, not the full
PipeWire integration suite.

Run it against a PipeWire source checkout:

```sh
python3 diagnostics/bluetooth/test_sco_acquire.py \
  /path/to/pipewire/spa/plugins/bluez5/backend-native.c \
  /path/to/pipewire/spa/plugins/bluez5/bluez5-dbus.c
```

The patched Bluetooth component compiled and was loaded in WirePlumber using
a temporary, process-specific SPA plugin path. Across three cancelled startup
trials, the HFP error-state replay was not observed, but the first trial still
produced only silence. The kernel logged `urb ... submission failed (90)` during
that trial. The other trials produced signal but indicated readiness at about
2.2 seconds. Similar USB errors had also occurred in earlier unpatched tests;
their cause and relation to ordinary cold-start delay remain unproven.

The temporary service override was removed and the stock service restored.
No system packages, permanent microphone settings, or speech-to-text behavior
were changed. Nothing has been submitted upstream.

Further work must distinguish the USB/SCO first-start failure from the
error-state replay and measure current microphone input, not virtual-buffer
arrival or the UI indicator. This patch alone does not meet the requested
instant-start / full-quality experience.

## Later measurements and test-environment caveat

Temporary instrumentation in `media-source.c` measured two successful starts
with the candidate patch and the stock WirePlumber 500 ms switch delay:

- First encoded SCO data: 0.97–0.99 s after the start request.
- First decoded PCM: 1.16–1.19 s.
- First nonzero decoded PCM: 1.48–1.50 s.
- First nonzero PCM delivered to the graph: 1.53–1.55 s.
- Camera Effects input meter first nonzero: about 1.62 s.
- UI listening indication: about 2.14 s.

Nonzero samples establish signal, not intelligibility or preservation of opening
words. The first trial after restarting WirePlumber had no encoded data during
the six-second capture and logged a USB submission error at about 4.46 s.

A later combined test with a 50 ms WirePlumber delay did **not run**: the temporary
data-directory override omitted the user's required `camera-effects-hide-mics.lua`
script, so WirePlumber failed to start. The override was removed, the service's
restart limit reset, and the stock service successfully started again.

That startup log also exposed a build-environment confound: the locally built
PipeWire plugin searched `/usr/local/share/spa-0.2/bluez5/bluez-hardware.conf`,
whereas the installed quirks file is under `/usr/share/spa-0.2/bluez5/`.
Correct the build prefix/data paths before relying on patched-versus-stock
integration comparisons. The focused acquire-function regression test is
independent of this configuration problem.

See [HANDOFF.md](HANDOFF.md) for the complete investigation handoff.
