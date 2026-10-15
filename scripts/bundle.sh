#!/bin/bash
# Build a universal rSplex.app and zip it. Usage: scripts/bundle.sh <version>
set -euo pipefail
VERSION="${1:?usage: scripts/bundle.sh <version>}"
cd "$(dirname "$0")/.."

# Build each arch separately and merge with lipo (multi-arch `swift build` needs full Xcode).
for ARCH in arm64 x86_64; do
    swift build -c release --triple "$ARCH-apple-macosx13.0" --scratch-path ".build/$ARCH"
done

rm -rf dist && mkdir -p dist/rSplex.app/Contents/MacOS
lipo -create -output dist/rSplex.app/Contents/MacOS/rSplex \
    .build/arm64/release/rSplex .build/x86_64/release/rSplex
cat > dist/rSplex.app/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>rSplex</string>
    <key>CFBundleIdentifier</key><string>com.asubichev.rsplex</string>
    <key>CFBundleName</key><string>rSplex</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign --force --deep -s - dist/rSplex.app
ditto -c -k --keepParent dist/rSplex.app dist/rSplex.zip
echo "Built dist/rSplex.zip ($VERSION)"
