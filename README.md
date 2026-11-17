<p align="center">
  <img src="assets/icon_mac.png" width="160" height="160" alt="Callout Icon" />
</p>

<h1 align="center">Callout</h1>

<p align="center">
  <strong>Native macOS 26 Liquid Glass Text-Selection Action Bar</strong><br/>
  Bring the iOS Edit Menu experience to your Mac — a compact Liquid Glass pill &amp; expandable context menu anywhere you select text.
</p>

<p align="center">
  <a href="https://github.com/passs0/Callout/releases/latest"><img src="https://img.shields.io/github/v/release/passs0/Callout?label=Latest%20Release&color=007AFF" alt="Latest Release" /></a>
  <img src="https://img.shields.io/badge/macOS-26.0%2B%20%7C%20Apple%20Silicon-black?logo=apple" alt="macOS 26.0+" />
  <img src="https://img.shields.io/badge/framework-SwiftUI%20%7C%20AppKit%20%7C%20Translation-blue" alt="Frameworks" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" /></a>
</p>

<p align="center">
  <img src="assets/callout_pill.png" width="380" alt="Callout Compact Liquid Glass Pill" />
  <br/><br/>
  <img src="assets/callout_menu.png" width="380" alt="Callout Expanded Context Menu" />
</p>

---

> [!NOTE]
> **AI-Generated Project Disclosure**
> **Callout** is an **AI-generated project** created with **Antigravity** (Google DeepMind).

---

## Features

- **Native Apple Liquid Glass:** Built with SwiftUI's macOS 26 `GlassEffectContainer`, `.glassEffect(_:in:)`, and `.glassEffectID(_:in:)` inside a non-activating floating `NSPanel` that never steals focus from your active app.
- **Compact Pill & Expandable Context Menu:** Appears centered below selected text with `Copy`, `Look Up`, `Translate`, `Find`, and `>` (or right-click) to expand into the full menu (`Open Link`, `Search with Google / DuckDuckGo / Bing / Naver`, `Speak`, `Spell`, `Copy Link with Highlight`, `Share...`, `Add to Quick Note`, and `Ask Siri`).
- **On-Device Apple Translate & Look Up:** Uses Apple's `Translation` framework (`TranslationSession` + `.translationPresentation`) with a target-language picker and `CoreServices` (`DCSCopyTextDefinition`) for instant inline definitions.
- **Universal Selection Detection:** Reads `AXSelectedText` across native apps (enabling `AXEnhancedUserInterface` / `AXManualAccessibility` for browsers and Electron) with a safe `Edit → Copy` availability check before falling back to clipboard read — plus global shortcuts (`⌥ Space` or `⌘⇧E`).
- **Lightweight Menu Bar Utility:** Runs as an accessory app (`LSUIElement`) with SF Symbol menu items, **Preview Floating Bar**, and customizable search engine & translation language settings.

## Installation

### Download Release
1. Download **`Callout-1.0.0.dmg`** from [GitHub Releases](https://github.com/passs0/Callout/releases/latest) and drag **`Callout.app`** to `/Applications`.
2. On first launch, right-click `Callout.app` ➔ **Open**, or run `xattr -cr /Applications/Callout.app`.
3. Grant **Accessibility** permission in **System Settings → Privacy & Security → Accessibility** so Callout can detect text selections across apps.

### Build from Source
```zsh
git clone https://github.com/passs0/Callout.git && cd Callout
./scripts/build_app.sh
```

> [!IMPORTANT]
> **Dynamic Icon Compilation**
> Compiling the Light, Dark, Clear, and Tinted variants from `Resources/AppIcon.icon` into `Assets.car` requires Xcode 26+ (`actool`). Local builds without Xcode automatically fall back to `ictool` + `AppIcon.icns`, while GitHub Actions CI builds the full dynamic icon bundle.

## License

Released under the [MIT License](LICENSE).
