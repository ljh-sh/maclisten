---
layout: default
title: Alternatives
---

# Alternatives

## Whisper / whisper.cpp

- **Pros**: high accuracy, many languages, runs offline with the right model.
- **Cons**: requires downloading a model, larger memory footprint, not the native macOS ASR path.
- **Use when**: you need state-of-the-art accuracy or a language Apple does not support well.

## macOS Dictation

- **Pros**: built-in, keyboard-triggered, uses the same `Speech` framework.
- **Cons**: GUI-focused, not scriptable, no JSON output, no continuous keyword mode.
- **Use when**: you just want to dictate text into an app.

## Siri

- **Pros**: deeply integrated, can perform system actions.
- **Cons**: no CLI or third-party automation API for arbitrary commands.
- **Use when**: you want Apple's built-in assistant experience.

## Web APIs (OpenAI, Google, etc.)

- **Pros**: often more accurate, supports many languages.
- **Cons**: requires network, API keys, uploads audio to a third party, latency and cost.
- **Use when**: accuracy or language coverage is more important than privacy/latency.

## When to choose maclisten

Choose maclisten when you want:

- A tiny native binary with no model download and minimal resource use.
- Audio processed locally, with an `--on-device` option that keeps it on your Mac.
- Compact JSON output for scripts and agents.
- Continuous keyword listening on macOS.
- Audio and transcript saved together.
