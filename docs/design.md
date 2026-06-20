---
layout: default
title: Design
---

# Design & principles

maclisten is intentionally small. It does one thing well: turn macOS audio into text using Apple's native `Speech` framework.

## Small surface

There are five top-level commands:

- `locales` — discover what the system can recognize
- `file` — transcribe existing audio
- `mic` — record and transcribe
- `watch` — continuous listening
- `auth` — open privacy settings

No GUI, no daemon, no configuration file.

## JSON-first output

Every command prints JSON. This makes maclisten easy to pipe into `jq`, Python, or an LLM agent. Errors are also JSON:

```json
{"ok":false,"error":"Speech Recognition permission has not been granted..."}
```

## Native frameworks only

maclisten uses `SFSpeechRecognizer` and `AVAudioEngine`. It does not bundle a speech model and does not send audio to third-party services (unless on-device recognition is disabled and Apple's servers are used).

## CLI that feels like a binary

`Speech` framework callbacks need an app run loop. maclisten starts a hidden `NSApplication` with `accessory` activation policy so the CLI still behaves like a normal binary: you run it, it prints JSON, it exits.

## Respect macOS permissions

maclisten never calls `requestAuthorization()` from a bare CLI process — that crashes on macOS 14+. It only queries `authorizationStatus()` and returns a friendly JSON error if permission is missing.

## Continuous listening is a loop

`watch` keeps the audio engine running and creates a new `SFSpeechAudioBufferRecognitionRequest` whenever the previous one finalizes or hits a safety timeout. This works around the framework's practical single-session limits without dropping audio.
