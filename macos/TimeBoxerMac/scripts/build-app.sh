#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$MAC_ROOT/../.." && pwd)"
# The project lives under a File Provider-managed Documents directory. macOS can
# reattach Finder metadata there immediately after signing, invalidating the
# bundle. Keep the verified deliverable on a local temporary filesystem.
OUTPUT_APP_ROOT="/private/tmp/timeboxer-mac-build/TimeBoxer.app"
STAGING_DIRECTORY="$(mktemp -d /private/tmp/timeboxer-app-build.XXXXXX)"
trap 'rm -rf "$STAGING_DIRECTORY"' EXIT
APP_ROOT="$STAGING_DIRECTORY/TimeBoxer.app"
CONTENTS="$APP_ROOT/Contents"

if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  XCODE_DEVELOPER_DIR="$DEVELOPER_DIR"
elif [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  XCODE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
else
  XCODE_DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
fi

XCODEBUILD_BIN="$XCODE_DEVELOPER_DIR/usr/bin/xcodebuild"
ASSET_CATALOG_COMPILER="$XCODE_DEVELOPER_DIR/usr/bin/actool"
SWIFT_BIN="$XCODE_DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
MACOS_SDK="$XCODE_DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

cd "$PROJECT_ROOT"

if [[ ! -x "$XCODEBUILD_BIN" || ! -x "$ASSET_CATALOG_COMPILER" || ! -x "$SWIFT_BIN" || ! -d "$MACOS_SDK" ]]; then
  echo "Full Xcode is required to compile the macOS app. Install Xcode, open it once, then select it with xcode-select." >&2
  exit 2
fi

export DEVELOPER_DIR="$XCODE_DEVELOPER_DIR"
export SDKROOT="$MACOS_SDK"

npm run build:child

SWIFT_BUILD_ARGS=(build -c release --package-path "$MAC_ROOT")
if [[ "${TIMEBOXER_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
  SWIFT_BUILD_ARGS+=(--disable-sandbox)
fi
"$SWIFT_BIN" "${SWIFT_BUILD_ARGS[@]}"

mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources/WebApp"
cp "$MAC_ROOT/.build/release/TimeBoxerMac" "$CONTENTS/MacOS/TimeBoxerMac"
cp "$MAC_ROOT/App/Info.plist" "$CONTENTS/Info.plist"
cp -R "$PROJECT_ROOT/dist-child/." "$CONTENTS/Resources/WebApp/"
node "$SCRIPT_DIR/inline-web-assets.mjs" "$CONTENTS/Resources/WebApp"
"$ASSET_CATALOG_COMPILER" \
  --compile "$CONTENTS/Resources" \
  --platform macosx \
  --minimum-deployment-target 13.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$STAGING_DIRECTORY/asset-info.plist" \
  "$MAC_ROOT/App/Assets.xcassets"

xattr -cr "$APP_ROOT"
# iCloud/File Provider can attach these directory attributes immediately after
# assembly. They are harmless metadata but invalidate macOS code signing.
xattr -d com.apple.FinderInfo "$APP_ROOT" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_ROOT" 2>/dev/null || true
codesign --force --deep --sign - "$APP_ROOT"
codesign --verify --deep --strict --verbose=2 "$APP_ROOT"

rm -rf "$OUTPUT_APP_ROOT"
mkdir -p "$(dirname "$OUTPUT_APP_ROOT")"
ditto --norsrc --noextattr "$APP_ROOT" "$OUTPUT_APP_ROOT"

# File Provider may attach Finder metadata again while copying into the project
# directory. Clean and sign the actual deliverable, not only the staging bundle.
xattr -cr "$OUTPUT_APP_ROOT"
xattr -d com.apple.FinderInfo "$OUTPUT_APP_ROOT" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$OUTPUT_APP_ROOT" 2>/dev/null || true
codesign --force --deep --sign - "$OUTPUT_APP_ROOT"
codesign --verify --deep --strict --verbose=2 "$OUTPUT_APP_ROOT"

echo "$OUTPUT_APP_ROOT"
