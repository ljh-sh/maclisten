---
layout: default
title: Why maclisten?
---

# Why maclisten?

## Privacy by default

maclisten sends nothing to a third party unless you explicitly disable on-device recognition:

- Audio is processed by Apple's native `Speech` framework.
- With `--on-device`, recognition happens entirely on your Mac.
- No API keys, no audio uploads, no cloud billing.

## Why a CLI instead of a web API?

- **No network round-trip** — audio stays on the Mac.
- **No API keys** — uses the Apple ID already on the machine.
- **Predictable latency** — especially when `--on-device` is available.
- **Pipe-friendly** — output JSON lines can drive shell scripts and agents.

## Tiny footprint

- Single ~500 KB Swift binary.
- No model download.
- No daemon, no background service, no configuration file.
- Starts instantly and exits cleanly.

## Why not whisper.cpp?

`whisper.cpp` is excellent, but:

- It requires downloading and loading a model.
- Model files are large (hundreds of MB to GB).
- It is not the native macOS ASR path.

maclisten uses the `Speech` framework that is already installed, optimized, and kept up to date by Apple. The binary is small and starts instantly.

## Why not Siri?

macOS provides no public API to invoke Siri from a CLI or to register arbitrary voice commands. maclisten gives you the ASR piece; you can feed the text into your own rules engine or LLM to build a Siri-like command layer.

## When maclisten is the right tool

- You need a quick, local transcript of an audio file.
- You want a long-running microphone listener that emits JSON.
- You are building an agent that needs speech input on macOS.
- You want to keep the raw audio alongside the transcript.
