#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$MAC_ROOT/../.." && pwd)"
APP_ROOT="$MAC_ROOT/build/TimeBoxer.app"
CONTENTS="$APP_ROOT/Contents"

if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  XCODE_DEVELOPER_DIR="$DEVELOPER_DIR"
elif [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  XCODE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
else
  XCODE_DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
fi

XCODEBUILD_BIN="$XCODE_DEVELOPER_DIR/usr/bin/xcodebuild"
SWIFT_BIN="$XCODE_DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
MACOS_SDK="$XCODE_DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

cd "$PROJECT_ROOT"

if [[ ! -x "$XCODEBUILD_BIN" || ! -x "$SWIFT_BIN" || ! -d "$MACOS_SDK" ]]; then
  echo "Full Xcode is required to compile the macOS app. Install Xcode, open it once, then select it with xcode-select." >&2
  exit 2
fi

export DEVELOPER_DIR="$XCODE_DEVELOPER_DIR"
export SDKROOT="$MACOS_SDK"

npm run build

SWIFT_BUILD_ARGS=(build -c release --package-path "$MAC_ROOT")
if [[ "${TIMEBOXER_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
  SWIFT_BUILD_ARGS+=(--disable-sandbox)
fi
"$SWIFT_BIN" "${SWIFT_BUILD_ARGS[@]}"

rm -rf "$APP_ROOT"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources/WebApp"
cp "$MAC_ROOT/.build/release/TimeBoxerMac" "$CONTENTS/MacOS/TimeBoxerMac"
cp "$MAC_ROOT/App/Info.plist" "$CONTENTS/Info.plist"
cp -R "$PROJECT_ROOT/dist/." "$CONTENTS/Resources/WebApp/"
node "$SCRIPT_DIR/inline-web-assets.mjs" "$CONTENTS/Resources/WebApp"

xattr -cr "$APP_ROOT"
codesign --force --deep --sign - "$APP_ROOT"
codesign --verify --deep --strict --verbose=2 "$APP_ROOT"

echo "$APP_ROOT"
