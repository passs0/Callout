#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

"$ROOT_DIR/scripts/build_app.sh"

APP_DIR="$ROOT_DIR/build/Callout.app"
DMG_STAGE="$ROOT_DIR/build/dmg_stage"
DMG_PATH="$ROOT_DIR/build/Callout-1.0.3.dmg"

rm -rf "$DMG_STAGE" "$DMG_PATH"
mkdir -p "$DMG_STAGE"

cp -R "$APP_DIR" "$DMG_STAGE/Callout.app"
ln -s /Applications "$DMG_STAGE/Applications"

echo "Creating DMG at $DMG_PATH..."
hdiutil create \
    -volname "Callout" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGE"
echo "Done! DMG created at: $DMG_PATH"
