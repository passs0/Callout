<p align="center">
  <img src="assets/icon_mac.png" width="160" height="160" alt="Callout Icon" />
</p>

<h1 align="center">Callout</h1>

<p align="center">
  A macOS 26 floating text-selection bar and context menu that appears right where you select text.
</p>

<p align="center">
  <a href="https://github.com/passs0/Callout/releases/latest"><img src="https://img.shields.io/github/v/release/passs0/Callout?label=Latest%20Release&color=007AFF" alt="Latest Release" /></a>
  <img src="https://img.shields.io/badge/macOS-26.0%2B%20%7C%20Apple%20Silicon-black?logo=apple" alt="macOS 26.0+" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" /></a>
</p>

<p align="center">
  <img src="assets/callout_demo.gif" width="400" alt="Callout Demo" />
</p>

---

## What it does

- **Quick action pill:** Shows `Copy`, `Look Up`, `Translate`, `Find`, and `>` on text selection.
- **Native app context menu:** Clicking `>` (or right-clicking the pill) dismisses the pill and opens the active app's real macOS right-click context menu directly on your selection.
- **On-device translation:** Uses Apple's `Translation` framework with configurable target language in Settings.
- **Shortcuts:** Trigger manually anytime with `⌥ Space` or `⌘⇧E`.

## Install

Download **`Callout-1.0.2.dmg`** from [Releases](https://github.com/passs0/Callout/releases/latest) and drag `Callout.app` to `/Applications`.

Grant **Accessibility** permission in **System Settings → Privacy & Security → Accessibility** so Callout can read selected text across apps.

Or build from source:
```zsh
git clone https://github.com/passs0/Callout.git && cd Callout
./scripts/build_app.sh
open build/Callout.app
```

Built with [Google Antigravity](https://antigravity.google) — 100% AI-written code and UI, steered and tested by hand.

## License

[MIT](LICENSE)
