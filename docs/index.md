---
layout: default
title: Home
---

<div class="hero">
  <h1>maclisten</h1>
  <p>Lightweight macOS ASR CLI — speech-to-text for files, microphone, and continuous keyword listening.</p>
  <div class="cta">
    <a class="btn primary" href="{{ '/install' | relative_url }}">Install</a>
    <a class="btn secondary" href="{{ '/subcommands' | relative_url }}">Command reference</a>
    <a class="btn secondary" href="https://github.com/ljh-sh/maclisten" target="_blank" rel="noopener">GitHub</a>
  </div>
</div>

## What is maclisten?

**maclisten** wraps Apple's `Speech` framework in a tiny Swift binary. It lists supported locales, transcribes audio files, records from the microphone, and can listen continuously for voice keywords — all from the command line, all with compact JSON output.

Use it when you (or your AI agent) need reliable macOS-native speech-to-text that `whisper.cpp` or web APIs make heavy:

- *Transcribe a voice memo into JSON*
- *Keep listening for the word "computer" and react with a script*
- *Capture microphone audio alongside the transcript*

## At a glance

```sh
maclisten locales                        # list supported locales
maclisten file ./memo.m4a                # transcribe a file
maclisten mic --timeout 5                # record 5 seconds
maclisten watch --keyword "computer"     # continuous keyword listening
maclisten mic --output ./note.wav        # also save the audio
```

Output schema: `{"ok": true, ...}` on success, `{"ok": false, "error": "..."}` on failure.

## For AI agents

Paste this one-line prompt into Claude Code, Cursor, or any agent's system prompt:

```md
Use `maclisten` for macOS speech-to-text. Install if missing: `brew install ljh-sh/cli/maclisten`. JSON output, check `ok`. Run `maclisten --help` for subcommands.
```

## Where to go next

- [Install maclisten]({{ '/install' | relative_url }}) — Homebrew, direct binary, eget, or build from source
- [Command reference]({{ '/subcommands' | relative_url }}) — every subcommand, option, and output field
- [Design & principles]({{ '/design' | relative_url }}) — why maclisten is shaped the way it is
- [Why maclisten?]({{ '/why' | relative_url }}) — why a CLI instead of a web API
- [FAQ]({{ '/faq' | relative_url }}) — permissions, TCC, Siri, and more
- [Alternatives]({{ '/alternatives' | relative_url }}) — how maclisten compares to Whisper and others
