#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "Building Callout (release)..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/Callout"
APP_DIR="$ROOT_DIR/build/Callout.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/Callout"
chmod +x "$MACOS_DIR/Callout"

ICON_SRC="$ROOT_DIR/Resources/AppIcon.icon"
ICTOOL="/Applications/Icon Composer.app/Contents/Executables/ictool"

if [ -d "$ICON_SRC" ]; then
    if xcode-select -p 2>/dev/null | grep -q "Xcode"; then
        echo "Compiling dynamic Assets.car and AppIcon.icns via Xcode actool..."
        xcrun actool "$ICON_SRC" \
            --compile "$RESOURCES_DIR" \
            --app-icon AppIcon \
            --enable-on-demand-resources NO \
            --development-region en \
            --target-device mac \
            --platform macosx \
            --minimum-deployment-target 26.0 \
            --output-partial-info-plist "$ROOT_DIR/build/assetcatalog_generated_info.plist"
    elif [ -x "$ICTOOL" ]; then
        echo "Rendering static AppIcon.icns from AppIcon.icon (Xcode not installed)..."
        cp -R "$ICON_SRC" "$RESOURCES_DIR/AppIcon.icon"
        ICONSET_DIR="$ROOT_DIR/build/AppIcon.iconset"
        rm -rf "$ICONSET_DIR"
        mkdir -p "$ICONSET_DIR"

        for size in 16 32 128 256 512; do
            "$ICTOOL" "$ICON_SRC" --export-image --output-file "$ICONSET_DIR/icon_${size}x${size}.png" --platform macOS --rendition Default --width "$size" --height "$size" --scale 1 >/dev/null
            "$ICTOOL" "$ICON_SRC" --export-image --output-file "$ICONSET_DIR/icon_${size}x${size}@2x.png" --platform macOS --rendition Default --width "$size" --height "$size" --scale 2 >/dev/null
        done

        iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
        rm -rf "$ICONSET_DIR"
    fi
fi

cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Callout</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.callout.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Callout</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.2</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Callout uses Apple Events to get the active browser URL for Copy Link with Highlight and to add Quick Notes in Apple Notes.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "Signing GlassSelect.app (ad-hoc)..."
codesign --force --deep --sign - "$APP_DIR"

echo "Done! App bundle created at: $APP_DIR"
