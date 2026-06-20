---
layout: default
title: FAQ
---

# FAQ

## Installation & permissions

### Why does `maclisten mic` say permission denied even after I clicked Allow?

macOS TCC grants Speech Recognition / Microphone access to the **terminal emulator app bundle** (Terminal.app, iTerm, Warp), not to the shell or the `maclisten` binary. If you run `maclisten` from a bare CLI process without a bundle ID (e.g. an editor plugin), the system settings pane won't even list it.

**Fix**: run `maclisten` from Terminal.app / iTerm / Warp after granting those apps access.

### Can `maclisten` request permissions itself?

No — calling `SFSpeechRecognizer.requestAuthorization()` from a bare CLI binary aborts on macOS 14+. maclisten only checks `authorizationStatus()` and returns a JSON error. Use `maclisten auth` to open the right settings panes.

### Do I need to grant Microphone access for `maclisten file`?

No. Only `mic` and `watch` use the microphone.

---

## Speech recognition

### Which locales are supported?

Run `maclisten locales`. The list comes directly from `SFSpeechRecognizer.supportedLocales()` and varies by macOS version.

### Can maclisten auto-detect the spoken language?

Not currently. `SFSpeechRecognizer` is single-locale. Speak English into `zh-CN` and recognition quality will be poor. Start `watch` with the locale you expect.

### What does `--on-device` do?

It requires recognition to happen on the Mac instead of Apple's servers. Availability depends on locale and macOS version. If on-device is unavailable, the command returns an error.

---

## `watch` and continuous listening

### How long can `watch` run?

Indefinitely. `watch` restarts the recognition session automatically every 60 seconds or whenever the current session finalizes. Audio capture is continuous.

### How do I stop `watch`?

Press `Ctrl-C` or `Ctrl-D`. A `"stopped"` JSON line tells you which key was used.

### Why doesn't `watch` capture anything?

- Check microphone permission.
- Check that you are in a real terminal emulator.
- If you used `--keyword`, only segments containing that keyword are emitted.
- Speak clearly and pause — `SFSpeechRecognizer` needs a detectable utterance boundary to produce a final segment.

---

## Audio recording

### What format is `--output`?

WAV, 16 kHz, 16-bit, mono. This is the standard input format for most speech recognition tools, including Whisper.

### Can I record without transcribing?

`maclisten mic --timeout N --output file.wav` still runs transcription. If you only need recording, use `sox`, `ffmpeg`, or `AVAudioRecorder` directly.

---

## Siri and intelligence

### Can maclisten invoke Siri?

No. macOS does not expose a public Siri API for CLI tools.

### Can I build a Siri-like command system?

Yes. Use `maclisten watch` as the ASR front-end, then pipe the JSON text into a rules engine or LLM that maps commands to actions (e.g. open apps, run `macli` subcommands, call AppleScript).

---

## Internals

### Why does maclisten start an `NSApplication`?

`SFSpeechRecognizer` recognition callbacks and `AVAudioEngine` need a run loop. A hidden accessory `NSApplication` provides that without showing any UI.

### Is the binary signed?

Release binaries are ad-hoc signed. Homebrew removes the quarantine attribute in `post_install`. Direct downloads may need:

```sh
xattr -dr com.apple.quarantine /usr/local/bin/maclisten
```
