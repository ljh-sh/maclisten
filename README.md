# maclisten

> Lightweight macOS ASR CLI — speech-to-text for files and microphone.

`maclisten` wraps Apple's `Speech` framework in a tiny Swift binary. It is intentionally small: list supported locales, transcribe an audio file, or record from the microphone for a fixed duration.

## Install

```sh
brew install ljh-sh/cli/maclisten   # coming soon
# or
x eget use --tag v0.1.0 ljh-sh/maclisten
```

## Permissions

macOS does **not** reliably prompt CLI tools for Speech Recognition or Microphone access. Before using `file` or `mic`, grant your terminal access in:

- **System Settings > Privacy & Security > Speech Recognition**
- **System Settings > Privacy & Security > Microphone** (for `mic`)

Without these permissions, `maclisten` returns a clear JSON error instead of crashing.

You can open the right panes quickly:

```sh
maclisten auth
```

### Important: run from a terminal emulator app

macOS TCC grants permissions to the **app bundle** that owns the terminal — e.g. `Terminal.app`, `iTerm.app`, `Warp.app`. If you run `maclisten` from a bare CLI process without a bundle (like `Kimi Code CLI`), the permission cannot be granted and `file`/`mic` will fail even after you click Allow.

If you see the permission error after authorizing, launch `maclisten` from `Terminal.app` instead.

## Usage

```sh
maclisten locales                        # list supported locales
maclisten file ./recording.wav           # transcribe a file
maclisten file ./recording.m4a --locale zh-CN --on-device
maclisten mic --timeout 5                # record 5 seconds from microphone
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

## Build from source

Requires Swift 5.10+ / macOS 12+.

```sh
git clone https://github.com/ljh-sh/maclisten
cd maclisten
swift build -c release
```

## Design

- **Small surface**: `locales`, `file`, `mic`.
- **JSON output**: easy to pipe to `jq`.
- **NSApplication lifecycle**: `Speech` framework authorization and recognition callbacks need an app run loop; `maclisten` starts a hidden accessory NSApp internally so the CLI still feels like a normal binary.

## License

Apache-2.0
