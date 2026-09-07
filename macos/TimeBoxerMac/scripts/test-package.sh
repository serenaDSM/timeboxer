#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAGING_DIRECTORY="$(mktemp -d /private/tmp/timeboxer-tests.XXXXXX)"
trap 'rm -rf -- "$STAGING_DIRECTORY"' EXIT
SWIFT_PACKAGE_ROOT="$STAGING_DIRECTORY/SwiftPackage"

mkdir -p "$SWIFT_PACKAGE_ROOT"
cp "$MAC_ROOT/Package.swift" "$SWIFT_PACKAGE_ROOT/Package.swift"
cp -R "$MAC_ROOT/Sources" "$SWIFT_PACKAGE_ROOT/Sources"
cp -R "$MAC_ROOT/Tests" "$SWIFT_PACKAGE_ROOT/Tests"

export CLANG_MODULE_CACHE_PATH="/private/tmp/timeboxer-test-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="/private/tmp/timeboxer-test-swiftpm-cache"

swift test \
  --package-path "$SWIFT_PACKAGE_ROOT" \
  --disable-index-store \
  --disable-sandbox \
  --jobs 1 \
  -Xswiftc -num-threads -Xswiftc 1 \
  -Xswiftc -module-cache-path -Xswiftc /private/tmp/timeboxer-test-swift-cache
