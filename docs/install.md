---
layout: default
title: Install
---

# Install maclisten

## Homebrew (recommended)

```sh
brew install ljh-sh/cli/maclisten
```

Or tap once, then use the short name:

```sh
brew tap ljh-sh/cli
brew install maclisten
```

## Direct binary

```sh
curl -L https://github.com/ljh-sh/maclisten/releases/latest/download/maclisten-darwin-universal.tar.xz | tar xJ -
sudo mv bin/maclisten /usr/local/bin/
```

The `universal` tarball is a fat Mach-O (arm64 + x86_64) — works on Apple Silicon and Intel Macs.

## eget

```sh
x eget use --tag v0.2.1 ljh-sh/maclisten
```

## Build from source

Requires Swift 5.10+ / macOS 12+.

```sh
git clone https://github.com/ljh-sh/maclisten
cd maclisten
swift build -c release
```

The binary will be at `.build/release/maclisten`.

## Permissions

Before using `file`, `mic`, or `watch`, grant your terminal access in:

- **System Settings > Privacy & Security > Speech Recognition**
- **System Settings > Privacy & Security > Microphone** (for `mic` / `watch`)

Then run from a real terminal emulator such as Terminal.app, iTerm, or Warp. Bare CLI processes (e.g. launched by an editor plugin) cannot receive TCC grants because they have no app bundle ID.

You can open the right panes quickly:

```sh
maclisten auth
```
