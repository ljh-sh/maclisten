# maclisten

[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/ljh-sh/maclisten/badge)](https://scorecard.dev/)
[![CI](https://github.com/ljh-sh/maclisten/actions/workflows/ci.yml/badge.svg)](https://github.com/ljh-sh/maclisten/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/Docs-website-blue.svg)](https://ljh-sh.github.io/maclisten)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE.txt)

> Private, lightweight macOS ASR CLI — local speech-to-text with a tiny footprint.

**maclisten** wraps Apple's `Speech` framework in a tiny Swift binary. It transcribes audio files, records from the microphone, and can keep listening for voice keywords — all locally on your Mac. All output is compact JSON, so it fits neatly into shell pipelines and AI agent workflows.

## Highlights

- **Private by default** — audio is processed by Apple's `Speech` framework; with `--on-device` recognition never leaves your Mac.
- **Tiny footprint** — single ~500 KB Swift binary, no model download, no daemon, no background service.
- **JSON-first** — every command outputs compact JSON for pipes and agents.
- **Continuous listening** — `watch` keeps the microphone open and emits segments/keywords as JSON lines.

Docs: [ljh-sh.github.io/maclisten](https://ljh-sh.github.io/maclisten)

## For AI agents

Paste this one-line prompt into Claude Code, Cursor, or any agent's system prompt:

```md
Use `maclisten` for macOS speech-to-text. Install if missing: `brew install ljh-sh/cli/maclisten`. JSON output, check `ok`. Run `maclisten --help` for subcommands.
```

## Install

### Homebrew (recommended)

```sh
brew install ljh-sh/cli/maclisten
```

Or tap once, then use the short name:

```sh
brew tap ljh-sh/cli
brew install maclisten
```

### Direct binary

```sh
curl -L https://github.com/ljh-sh/maclisten/releases/latest/download/maclisten-darwin-universal.tar.xz | tar xJ -
sudo mv bin/maclisten /usr/local/bin/
```

The `universal` tarball is a fat Mach-O (arm64 + x86_64) — works on Apple Silicon and Intel Macs.

### eget

```sh
x eget use --tag v0.2.1 ljh-sh/maclisten
```

### Build from source

Requires Swift 5.10+ / macOS 12+.

```sh
git clone https://github.com/ljh-sh/maclisten
cd maclisten
swift build -c release
```

## Permissions

macOS does **not** reliably prompt CLI tools for Speech Recognition or Microphone access. Before using `file`, `mic`, or `watch`, grant your terminal access in:

- **System Settings > Privacy & Security > Speech Recognition**
- **System Settings > Privacy & Security > Microphone** (for `mic` / `watch`)

You can open the right panes quickly:

```sh
maclisten auth
```

Example output:

```json
{"ok":true,"opened":["Speech Recognition","Microphone"]}
```

### Important: run from a terminal emulator app

macOS TCC grants permissions to the **app bundle** that owns the terminal — e.g. `Terminal.app`, `iTerm.app`, `Warp.app`. If you run `maclisten` from a bare CLI process without a bundle (like `Kimi Code CLI`), the permission cannot be granted and `file`/`mic`/`watch` will fail even after you click Allow.

If a pane opens but toggles stay disabled, close the permission windows and relaunch your terminal app, then rerun `maclisten auth` from there.

## Usage

```sh
maclisten locales                        # list supported locales
maclisten file ./recording.wav           # transcribe a file
maclisten file ./recording.m4a --locale zh-CN --on-device
maclisten file ./recording.m4a --cn --on-device

maclisten mic --timeout 5                # record 5 seconds from microphone
maclisten mic --auto-stop                # stop when you stop speaking
maclisten mic --partial                  # stream partial results as JSON lines
maclisten mic --output ./note.wav        # also save audio to WAV

# Continuously listen for a keyword / command phrase
maclisten watch --keyword "computer" --partial
maclisten watch --output ./stream.wav    # keep recording while listening
maclisten watch --fr --keyword "ordinateur"
# Press Ctrl-C or Ctrl-D to stop; a "stopped" JSON line is emitted
```

Locale can be set with `--locale`, or with shortcuts like `--cn`, `--hk`, `--fr`, `--de`, `--us`, etc. If neither is given, `maclisten` reads `$MACLISTEN_LOCALE`, then `$LANG`, and falls back to `en-US`.

```sh
MACLISTEN_LOCALE=fr-FR maclisten mic --timeout 5
LANG=de_DE.UTF-8 maclisten file ./recording.wav
```

Output is JSON by default:

```json
{"ok":true,"locale":"en-US","onDevice":false,"text":"hello world"}
```

`watch` emits a JSON line for each captured segment:

```json
{"ok":true,"segment":"computer open safari"}
```

## FAQ

See [docs/faq.md](docs/faq.md) or the [published FAQ](https://ljh-sh.github.io/maclisten/faq) for answers about permissions, TCC, continuous listening, audio recording, and Siri.

## Design

- **Small surface**: `locales`, `file`, `mic`, `watch`, `auth`.
- **JSON output**: compact single-line JSON, easy to pipe to `jq`.
- **Continuous mode**: `watch` keeps the audio engine running and restarts recognition sessions automatically, so it can listen indefinitely until you press `Ctrl-C`.
- **Audio recording**: `--output` saves microphone audio as WAV (16 kHz, 16-bit, mono) alongside transcription.
- **NSApplication lifecycle**: `Speech` framework authorization and recognition callbacks need an app run loop; `maclisten` starts a hidden accessory NSApp internally so the CLI still feels like a normal binary.

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md). All changes are merged via pull request and require admin approval.

## Security

See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Roadmap

See [ROADMAP.md](ROADMAP.md).

## License

Apache-2.0
