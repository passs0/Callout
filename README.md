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
  <img src="assets/callout_pill.png" width="380" alt="Callout Pill" />
  <br/><br/>
  <img src="assets/callout_menu.png" width="380" alt="Callout Expanded Menu" />
</p>

---

## What it does

- **Quick action pill:** Shows `Copy`, `Look Up`, `Translate`, `Find`, and an expand button (`>`) on text selection.
- **Expanded menu:** Open detected links, search with Google/DuckDuckGo/Bing/Naver, speak or spell out text (`AVSpeechSynthesizer`), copy highlight links (`#:~:text=`), share, or start a Quick Note.
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

**AI scope:** All code, assets, and documentation were generated with [Google Antigravity](https://antigravity.google); human involvement was limited to direction and hands-on testing.

## License

[MIT](LICENSE)
