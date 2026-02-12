#!/bin/zsh
set -e
swift build
mkdir -p .build/arm64-apple-macosx/debug/Enjoyable.app/Contents/MacOS
cp .build/arm64-apple-macosx/debug/enjoyable .build/arm64-apple-macosx/debug/Enjoyable.app/Contents/MacOS/
cat >.build/arm64-apple-macosx/debug/Enjoyable.app/Contents/Info.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.yukkurigames.Enjoyable</string>
    <key>CFBundleName</key>
    <string>Enjoyable</string>
    <key>CFBundleExecutable</key>
    <string>enjoyable</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF
codesign --force --deep --sign - --entitlements Enjoyable.entitlements .build/arm64-apple-macosx/debug/Enjoyable.app 2>/dev/null || true
mkdir -p Dist
cp -R .build/arm64-apple-macosx/debug/Enjoyable.app Dist/
codesign --force --deep --sign - --entitlements Enjoyable.entitlements Dist/Enjoyable.app 2>/dev/null || true
