#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

"$ROOT_DIR/scripts/build_app.sh"

APP_DIR="$ROOT_DIR/build/Selection.app"
DMG_STAGE="$ROOT_DIR/build/dmg_stage"
DMG_PATH="$ROOT_DIR/build/Selection-1.3.0.dmg"

rm -rf "$DMG_STAGE" "$DMG_PATH"
mkdir -p "$DMG_STAGE"

cp -R "$APP_DIR" "$DMG_STAGE/Selection.app"
ln -s /Applications "$DMG_STAGE/Applications"

echo "Creating DMG at $DMG_PATH..."
hdiutil create \
    -volname "Selection" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGE"
echo "Done! DMG created at: $DMG_PATH"
