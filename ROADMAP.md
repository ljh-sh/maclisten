# Roadmap

This is the high-level plan for `maclisten`. For already-released changes see [`changelog/`](changelog/).

Guiding principle: **maclisten only does what is hard to do from shell or Python** — direct use of Apple's `Speech` framework and reliable microphone access on macOS.

---

## Shipped

- [x] List supported `SFSpeechRecognizer` locales (`maclisten locales`)
- [x] Transcribe audio files (`maclisten file`)
- [x] Transcribe microphone input (`maclisten mic`)
- [x] Continuous keyword/command listening (`maclisten watch`)
- [x] Save microphone audio alongside transcription (`--output`)
- [x] Auto-stop and partial-results streaming (`--auto-stop`, `--partial`)
- [x] Open System Settings privacy panes (`maclisten auth`)

---

## v0.3.0 — Stability & packaging

Goal: harden the core ASR paths and prepare for distribution.

- [ ] Add unit tests for CLI argument parsing and JSON output formatting
- [ ] Add a minimal mock-based test for `AsrCtrl` error paths
- [ ] Homebrew tap formula in [`ljh-sh/homebrew-cli`](https://github.com/ljh-sh/homebrew-cli)
- [x] Signed GitHub releases
- [ ] OpenSSF Scorecard >= 8.5
  - branch protection with required admin review
  - dependency update automation
  - signed releases
  - security policy and code owners in place

Success criteria:
- `maclisten` installs cleanly via Homebrew and `x eget`.
- CI passes on every PR before merge.

---

## v0.4.0 — ASR quality

Goal: improve transcription accuracy and flexibility.

- [ ] On-device recognition availability matrix per locale
- [ ] Support for multiple locales in a single session (auto-detect or fallback chain)
- [ ] Confidence scores and alternative transcriptions in JSON output
- [ ] Punctuation formatting options

---

## Infrastructure & hardening

These run in parallel with feature milestones.

- [x] Branch protection policy documented; CODEOWNERS file added
- [ ] Enforce "require admin approval" branch protection rule in GitHub settings
- [ ] OpenSSF Scorecard workflow
- [ ] Dependabot for GitHub Actions and Swift packages
- [ ] Reproducible build verification in CI for every release

---

## Not planned

These are intentionally out of scope for `maclisten`:

- **GUI** — maclisten is CLI-only by design.
- **Linux / Windows** — macOS-only by design.
- **Built-in natural-language understanding** — use `maclisten` as the ASR front-end and pipe text to an LLM or rules engine.
- **Siri integration** — there is no public Siri API for CLI tools.

---

## How decisions are made

New candidates are evaluated with two questions:

1. Is the API truly permission-sensitive or framework-specific enough that shell / Python is unreliable?
2. Does centralizing it in `maclisten` reduce duplicated patch work across OS upgrades?

If both are yes, it belongs in a future milestone. If only the second is no, it stays in shell-land.
