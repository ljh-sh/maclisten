---
layout: default
title: Command reference
---

# Command reference

All commands print compact JSON lines by default. Use `--json` to ensure the final summary is printed (default for most commands).

## `maclisten locales`

List the locales supported by the system's `SFSpeechRecognizer`.

```sh
maclisten locales
```

**Output fields**

| Field | Type | Meaning |
|---|---|---|
| `ok` | bool | Always `true` if the command succeeds |
| `count` | int | Number of supported locales |
| `locales` | [string] | BCP-47 locale identifiers, sorted |

**Example**

```json
{"count":63,"locales":["ar-SA","ca-ES","cs-CZ","da-DK","de-AT",...,"zh-CN","zh-HK","zh-TW"],"ok":true}
```

---

## `maclisten file <path>`

Transcribe an audio file.

```sh
maclisten file ./recording.wav
maclisten file ./recording.m4a --locale zh-CN --on-device
```

**Options**

| Option | Default | Description |
|---|---|---|
| `--locale` | `en-US` | Locale identifier for recognition |
| `--on-device` | false | Require on-device recognition |

**Output fields**

| Field | Type | Meaning |
|---|---|---|
| `ok` | bool | Success or failure |
| `locale` | string | Locale used |
| `onDevice` | bool | Whether on-device recognition was requested |
| `text` | string | Transcribed text |
| `error` | string | Present only if `ok` is `false` |

---

## `maclisten mic`

Record from the microphone and transcribe.

```sh
maclisten mic --timeout 5
maclisten mic --auto-stop --auto-stop-silence 3.0
maclisten mic --partial --output ./note.wav
```

**Options**

| Option | Default | Description |
|---|---|---|
| `--locale` | `en-US` | Locale identifier |
| `--on-device` | false | Require on-device recognition |
| `--timeout` | `10.0` | Maximum recording time in seconds |
| `--auto-stop` | false | Stop when partial text stops changing |
| `--auto-stop-silence` | `5.0` | Seconds of stable partial text before auto-stop |
| `--partial` | false | Stream partial results as JSON lines |
| `--output` | — | Save microphone audio to this WAV file |
| `--json` | true | Print final JSON summary |

**Output fields**

| Field | Type | Meaning |
|---|---|---|
| `ok` | bool | Success or failure |
| `locale` | string | Locale used |
| `onDevice` | bool | On-device flag |
| `timeout` | double | Timeout value |
| `text` | string | Final transcript |
| `recordedSeconds` | double | Actual recording duration |
| `output` | string | Path to saved WAV file, if `--output` was given |
| `stoppedEarly` | bool | True if `--auto-stop` fired before timeout |

**Partial output** (`--partial`)

```json
{"ok":true,"partial":true,"text":"hello"}
{"ok":true,"partial":true,"text":"hello world"}
{"ok":true,"locale":"en-US","onDevice":false,"timeout":10.0,"text":"hello world","recordedSeconds":2.1}
```

---

## `maclisten watch`

Continuously listen for voice keywords or commands. Restarts recognition sessions automatically so it can run until you press `Ctrl-C` or `Ctrl-D`.

```sh
maclisten watch
maclisten watch --keyword "computer" --partial
maclisten watch --output ./stream.wav
```

**Options**

| Option | Default | Description |
|---|---|---|
| `--locale` | `en-US` | Locale identifier |
| `--on-device` | false | Require on-device recognition |
| `--keyword` | — | Only emit segments containing this keyword |
| `--output` | — | Save microphone audio to this WAV file |
| `--partial` | false | Stream partial results as JSON lines |
| `--json` | true | Print final JSON summary |

**Output fields**

| Field | Type | Meaning |
|---|---|---|
| `ok` | bool | Success or failure |
| `locale` | string | Locale used |
| `onDevice` | bool | On-device flag |
| `keyword` | string \| null | Keyword filter, if any |
| `segments` | [string] | All captured segments |
| `count` | int | Number of captured segments |
| `recordedSeconds` | double | Total listening duration |
| `output` | string | Path to saved WAV file, if `--output` was given |
| `stopReason` | string \| null | `"Ctrl-C"`, `"Ctrl-D"`, or `null` |

**Segment output**

When a segment is captured, a JSON line is emitted immediately:

```json
{"ok":true,"segment":"computer open safari"}
```

When stopped, a log line is emitted:

```json
{"ok":true,"event":"stopped","reason":"Ctrl-C"}
```

---

## `maclisten auth`

Open System Settings to the Speech Recognition and Microphone privacy panes.

```sh
maclisten auth
```

**Output fields**

| Field | Type | Meaning |
|---|---|---|
| `ok` | bool | `true` if the settings URLs were opened |
| `message` | string | Instructions for the user |

---

## Common error fields

When a command fails, the output contains:

| Field | Type | Meaning |
|---|---|---|
| `ok` | bool | `false` |
| `error` | string | Human-readable error message |

Common causes:

- **Speech Recognition permission not granted** — run `maclisten auth`, grant access to your terminal, then retry.
- **Microphone permission not granted** — required for `mic` and `watch`.
- **Running from a bare CLI process** — TCC cannot grant access to processes without a terminal app bundle. Use Terminal.app / iTerm / Warp.
- **Unsupported locale** — run `maclisten locales` to see valid identifiers.
