# maclisten

> Lightweight macOS ASR CLI — speech-to-text for files and microphone.

`maclisten` wraps Apple's `Speech` framework in a tiny Swift binary. It is intentionally small: list supported locales, transcribe an audio file, record from the microphone, or keep listening for voice keywords.

## Install

```sh
brew install ljh-sh/cli/maclisten   # coming soon
# or
x eget use --tag v0.2.0 ljh-sh/maclisten
```

## Permissions

macOS does **not** reliably prompt CLI tools for Speech Recognition or Microphone access. Before using `file`, `mic`, or `watch`, grant your terminal access in:

- **System Settings > Privacy & Security > Speech Recognition**
- **System Settings > Privacy & Security > Microphone** (for `mic` / `watch`)

Without these permissions, `maclisten` returns a clear JSON error instead of crashing.

You can open the right panes quickly:

```sh
maclisten auth
```

### Important: run from a terminal emulator app

macOS TCC grants permissions to the **app bundle** that owns the terminal — e.g. `Terminal.app`, `iTerm.app`, `Warp.app`. If you run `maclisten` from a bare CLI process without a bundle (like `Kimi Code CLI`), the permission cannot be granted and `file`/`mic`/`watch` will fail even after you click Allow.

If you see the permission error after authorizing, launch `maclisten` from `Terminal.app` instead.

## Usage

```sh
maclisten locales                        # list supported locales
maclisten file ./recording.wav           # transcribe a file
maclisten file ./recording.m4a --locale zh-CN --on-device

maclisten mic --timeout 5                # record 5 seconds from microphone
maclisten mic --auto-stop                # stop when you stop speaking
maclisten mic --partial                  # stream partial results as JSON lines
maclisten mic --output ./note.wav        # also save audio to WAV

# Continuously listen for a keyword / command phrase
maclisten watch --keyword "computer" --partial
maclisten watch --output ./stream.wav    # keep recording while listening
# Press Ctrl-C or Ctrl-D to stop; a "stopped" JSON line is emitted
```

Output is JSON by default:

```json
{
  "ok": true,
  "locale": "en-US",
  "onDevice": false,
  "text": "hello world"
}
```

`watch` emits a JSON line for each captured segment:

```json
{"ok":true,"segment":"computer open safari"}
```

## Build from source

Requires Swift 5.10+ / macOS 12+.

```sh
git clone https://github.com/ljh-sh/maclisten
cd maclisten
swift build -c release
```

## Design

- **Small surface**: `locales`, `file`, `mic`, `watch`, `auth`.
- **JSON output**: easy to pipe to `jq`.
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
