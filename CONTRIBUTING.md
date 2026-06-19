# Contributing to maclisten

Thanks for your interest! maclisten is a small, focused macOS ASR CLI. Please read this short guide before opening an issue or PR.

## Reporting issues

Open a [GitHub issue](../../issues) and include:

- macOS version
- maclisten version (`maclisten --version`)
- The exact command you ran
- Expected vs actual output
- If relevant, the full JSON output (`maclisten <cmd> --json`)

## Feature requests

maclisten deliberately stays small. We only add things that are hard or slow to do from shell, Python, or AppleScript. If your idea fits, open an issue and explain the use case.

## Building from source

Requires Swift 5.10+ / macOS 12+.

```sh
git clone https://github.com/ljh-sh/maclisten
cd maclisten
swift build -c release
```

The binary will be at `.build/release/maclisten`.

## Running tests

```sh
swift test
```

## Pull requests

- Keep the change minimal and focused.
- Follow the existing Swift style.
- Update README / changelog / ROADMAP if your change affects CLI behavior.
- Do not add heavy dependencies.

All changes must be submitted through a pull request and approved by a repository admin before merging.

## License

By contributing, you agree that your contributions will be licensed under the Apache 2.0 License.
