# GlassSelect

A native macOS 26 Liquid Glass text-selection action bar and expandable context menu.

## Features
- **Compact Liquid Glass Pill**: `Copy`, `Look Up`, `Translate`, `Find`, and `>` (or right-click to expand)
- **Expanded Context Menu**:
  - `Copy` header
  - `Open Link` (when a URL is selected)
  - `Look Up` (inline dictionary definition via CoreServices + Dictionary.app)
  - `Translate` (native on-device Apple `Translation` framework with target language picker)
  - `Find` (populates macOS Find pasteboard and triggers `⌘F`)
  - `Search with Google / DuckDuckGo / Bing / Naver`
  - `Speak` & `Spell` (`AVSpeechSynthesizer` + `NLLanguageRecognizer`)
  - `Copy Link with Highlight` (`#:~:text=` for Safari/Chrome/Arc/Brave/Edge)
  - `Share...` (`NSSharingServicePicker`)
  - `New Quick Note` (Apple Notes)

## Build & Run
```bash
./scripts/build_app.sh
open build/GlassSelect.app
```

> Grant **Accessibility** permission in **System Settings → Privacy & Security → Accessibility** so GlassSelect can detect text selections across apps. You can also press `⌥ Space` or `⌘⇧E` anytime.
