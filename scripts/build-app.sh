#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
swift build -c release --product LocalFileSorter
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$PWD/dist/Local File Sorter.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/LocalFileSorter" "$APP/Contents/MacOS/LocalFileSorter"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LocalFileSorter</string>
<key>CFBundleIdentifier</key><string>local.ompatnaik.LocalFileSorter</string>
<key>CFBundleName</key><string>Local File Sorter</string>
<key>CFBundleDisplayName</key><string>Local File Sorter</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSDownloadsFolderUsageDescription</key><string>Watch your selected Downloads folder and automatically sort finished downloads.</string>
<key>NSDocumentsFolderUsageDescription</key><string>Store sorted files in your selected destination and maintain undo history.</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
print "Built $APP"
SAMPLES="$PWD/dist/Local File Sorter Samples.app"
mkdir -p "$SAMPLES/Contents/MacOS"
cp "$APP/Contents/MacOS/LocalFileSorter" "$SAMPLES/Contents/MacOS/LocalFileSorter"
cp "$APP/Contents/Info.plist" "$SAMPLES/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.ompatnaik.LocalFileSorter.samples' "$SAMPLES/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName Local File Sorter Samples' "$SAMPLES/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Local File Sorter Samples' "$SAMPLES/Contents/Info.plist"
codesign --force --sign - "$SAMPLES"
print "Built sample preview $SAMPLES"
