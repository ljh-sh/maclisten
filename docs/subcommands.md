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
maclisten file ./recording.m4a --cn --on-device
maclisten file ./recording.m4a --fr --on-device

# Multiple locales → run each, return the highest-confidence result
maclisten file ./clip.m4a --locale zh-CN --locale en-US
maclisten file ./clip.m4a --cn --en                 # shortcuts work too
maclisten file ./clip.m4a --cn --en --no-pick       # one JSON line per locale
```

**Supported formats** — any audio file Apple's AVFoundation can decode: `.wav`, `.m4a`/`.aac`, `.mp3`, `.caf`, `.aiff`, and audio tracks from `.mov`/`.mp4`. PCM WAV and AAC/M4A are the most reliable.

### Multi-locale (auto language pick)

Apple's `Speech` framework is single-locale with no language-detection step. When a recording's language is uncertain, pass a **short candidate list** (your guesses). `file` runs each and, by default, returns the **highest-confidence** result with a `candidates` scoreboard. The caller chooses the candidates — `maclisten` never iterates every supported locale.

```sh
# best-confidence winner (default)
maclisten file ./clip.m4a --locale zh-CN --locale en-US

# let an agent / jq judge instead
maclisten file ./clip.m4a --locale zh-CN --locale en-US --no-pick | jq -s 'max_by(.confidence)'
```

Confidence is a recognizer heuristic (mean of per-segment confidences), not a true language ID — wrong-locale recognition can still hallucinate, so keep candidates plausible.

**Options**

| Option | Default | Description |
|---|---|---|
| `--locale` | inferred | Locale identifier, **repeatable**. Defaults to `$MACLISTEN_LOCALE`, then `$LANG` (e.g. `fr_FR.UTF-8` → `fr-FR`), then `en-US`. With 2+ values, the highest-confidence result is returned |
| `--cn`, `--hk`, `--tw`, `--us`, `--gb`, `--fr`, `--de`, ... | — | Region/language shortcut for `--locale <value>`; **multiple stack** (`--cn --en` = zh-CN + en-US). Run `maclisten file --help` for the full list |
| `--on-device` | false | Require on-device recognition |
| `--no-pick` | false | With 2+ locales, emit one JSON line per locale instead of picking the best |
| `--segments` | false | Include a per-segment `segments` array of `{text, confidence, start, duration}` |

**Output fields**

| Field | Type | Meaning |
|---|---|---|
| `ok` | bool | Success or failure |
| `locale` | string | Locale used (the winner when 2+ are given) |
| `onDevice` | bool | Whether on-device recognition was requested |
| `confidence` | float | Mean per-segment confidence of the best transcription, `0`–`1` |
| `text` | string | Transcribed text |
| `candidates` | array | Present with 2+ locales (non-`--no-pick`): `{locale, confidence, text, ok}` per candidate |
| `segments` | array | Present with `--segments`: `{text, confidence, start, duration}` per segment |
| `error` | string | Present only if `ok` is `false` |

---

## `maclisten mic`

Record from the microphone and transcribe.

```sh
maclisten mic --timeout 5
maclisten mic --auto-stop --auto-stop-silence 3.0
maclisten mic --partial --output ./note.wav
maclisten mic --hk --partial
maclisten mic --de --partial
```

**Options**

| Option | Default | Description |
|---|---|---|
| `--locale` | inferred | Locale identifier. Defaults to `$MACLISTEN_LOCALE`, then `$LANG`, then `en-US` |
| `--cn`, `--hk`, `--tw`, `--us`, `--gb`, `--fr`, `--de`, ... | — | Region/language shortcut for `--locale <value>`. Run `maclisten mic --help` for the full list |
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
maclisten watch --cn --keyword "电脑"
maclisten watch --fr --keyword "ordinateur"
```

**Options**

| Option | Default | Description |
|---|---|---|
| `--locale` | inferred | Locale identifier. Defaults to `$MACLISTEN_LOCALE`, then `$LANG`, then `en-US` |
| `--cn`, `--hk`, `--tw`, `--us`, `--gb`, `--fr`, `--de`, ... | — | Region/language shortcut for `--locale <value>`. Run `maclisten watch --help` for the full list |
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
