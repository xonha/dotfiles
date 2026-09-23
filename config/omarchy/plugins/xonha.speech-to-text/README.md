# Speech to Text (Voxtype wrapper that's good looking)





https://github.com/user-attachments/assets/55d86289-ce72-4d24-94a0-d4888110cc01






Dictation for Omarchy: press a key, talk, press it again, and the words are pasted where your cursor is. A live waveform and the words as they are recognised show in the bar while you talk; every recording is kept with its text so you can play it back, copy or paste it again.

> Tested only on **Omarchy 4** (Arch Linux, Hyprland, omarchy-shell).

## What you get

- **One key per language** (default: `SUPER ALT D` for English; set your own in Settings). Press to start, press again to stop and paste. Esc discards.
- **+ Return** per language: also press Return after pasting (for chat boxes and prompts).
- **Ask your agent**: a second key per language hands the text to Omarchy's default coding agent (`omarchy default agent`) instead of pasting it.
- **Live waveform and live text** in the bar, in the language you are dictating: yellow while the microphone opens, green once your voice is actually coming through; the bar goes back to the icon the moment the text is pasted. Pick the look in Settings: bars, wave, pulse or dots.
- **Never miss the first words**: Settings → Advanced → "Keep the microphone open" keeps the stream running between recordings, so a recording starts instantly and even includes the half second before the key press. (Not for a Bluetooth headset: it would stay in headset mode all the time.)
- **Stop is instant**: the recording is transcribed at every pause while you talk, so only the last phrase is left when you stop.
- **History** of every recording (text + audio) with play, copy and delete, searchable, in the bar popup; kept for a month by default (Settings).
- **Languages** picked from Whisper's list; the model a language needs is downloaded by itself the first time, from a pinned commit of ggerganov/whisper.cpp and only kept when its size and SHA-256 match the checksums shipped in the daemon (about 150 MB for the default model; the bar shows the progress). English-only models are swapped for the multilingual one.
- **Engine**: Omarchy's own dictation engine, [voxtype](https://github.com/peteonrails/voxtype) (local Whisper), by default, so there is nothing new to install. whisper.cpp (`whisper-cli`) and any custom command are also supported (Settings → Advanced).
- **Safe key bindings**: a key that anything else already uses is refused, never taken over.
- Local only. Nothing leaves your machine.

## Install

```bash
omarchy plugin add https://github.com/alanfortlink/speech-to-text.git --enable
```

That is all. The microphone icon appears in the bar, the daemon starts with the shell and applies the key bindings itself (nothing in `~/.config/hypr` is touched).

If Omarchy's dictation engine (voxtype) is not installed yet, the popup says so and offers an **Install** button, which runs `omarchy-voxtype-install` in a floating terminal (about 150 MB, asks for your password). Everything else the plugin needs is part of a stock Omarchy: PipeWire, `wl-clipboard`, `curl`, Python 3; `wtype` comes with voxtype.

Optional: `~/.config/omarchy/plugins/xonha.speech-to-text/install.sh` puts the `stt` command on your PATH. From a checkout anywhere else, `./install.sh` also links the checkout into the plugins directory (handy for development).

## Use

- Press the language's key, talk, press it again. `Esc` discards while recording. The first press for a new language downloads its model; the bar shows "Getting ready…" until it is there.
- Click the microphone icon for History and Settings. Right-click it to start recording; while recording, click the waveform to stop, right-click to discard.
- Settings: one row per language: the Dictate key (click it, press the key; Backspace clears), the + Return switch, and the Ask-agent key. The first row is the default language; use the arrows to reorder. Add languages from the picker.
- `stt` from a terminal: `stt toggle --lang en [--enter]`, `stt status --follow`, `stt history`, `stt paste ID`, `stt set liveText false`.

## Files

| What | Where |
|---|---|
| Config | `~/.config/speech-to-text/config.json` |
| History database and audio | `~/.local/share/speech-to-text/` |
| Models | `~/.local/share/voxtype/models/` (shared with voxtype) |
| Daemon socket and log | `$XDG_RUNTIME_DIR/speech-to-text/` |

## Uninstall

```bash
~/.config/omarchy/plugins/xonha.speech-to-text/install.sh --uninstall
omarchy plugin remove xonha.speech-to-text
```
