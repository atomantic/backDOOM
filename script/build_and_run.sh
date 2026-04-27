#!/usr/bin/env bash
set -euo pipefail

APP_NAME="backDOOM"
PRODUCT_NAME="backDOOM"
BUNDLE_ID="com.atomantic.backDOOM"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

MODE="${1:-run}"

cd "$ROOT_DIR"

if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  pkill -x "$APP_NAME" || true
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"

SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
TARGET_TRIPLE="$(uname -m)-apple-macosx26.0"
SOURCE_FILES=()

while IFS= read -r source_file; do
  SOURCE_FILES+=("$source_file")
done < <(find "$ROOT_DIR/Sources/$PRODUCT_NAME" -name '*.swift' | sort)

swiftc \
  -swift-version 6 \
  -target "$TARGET_TRIPLE" \
  -sdk "$SDKROOT" \
  "${SOURCE_FILES[@]}" \
  -o "$APP_BINARY"

chmod +x "$APP_BINARY"
cp -R "$ROOT_DIR/Sources/$PRODUCT_NAME/Assets" "$APP_RESOURCES/Assets"
xattr -dr com.apple.quarantine "$APP_BUNDLE" 2>/dev/null || true

cat > "$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>backDOOM</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>26.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

case "$MODE" in
  --verify)
    /usr/bin/open -n "$APP_BUNDLE"
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME launched"
    ;;
  --telemetry)
    /usr/bin/open -n "$APP_BUNDLE"
    echo "Streaming backDOOM telemetry. Press Ctrl-C to stop."
    /usr/bin/log stream --style compact --info --predicate "process == '$APP_NAME' || subsystem == '$BUNDLE_ID'"
    ;;
  --logs)
    /usr/bin/open -n "$APP_BUNDLE"
    echo "Streaming backDOOM process logs. Press Ctrl-C to stop."
    /usr/bin/log stream --style compact --info --predicate "process == '$APP_NAME'"
    ;;
  --debug)
    /usr/bin/lldb "$APP_BINARY"
    ;;
  run|"")
    /usr/bin/open -n "$APP_BUNDLE"
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    echo "Usage: $0 [--verify|--telemetry|--logs|--debug]" >&2
    exit 2
    ;;
esac
