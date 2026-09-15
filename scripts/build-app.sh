#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
SIGNED=0
SAMPLES=1
HOMEBREW_BUILD=0
for option in "$@"; do
  case "$option" in
    --homebrew) HOMEBREW_BUILD=1 ;;
    --signed) SIGNED=1 ;;
    --no-samples) SAMPLES=0 ;;
    *) print -u2 "Usage: $0 [--signed] [--no-samples] [--homebrew]"; exit 2 ;;
  esac
done
if [[ "$SIGNED" == 1 && -z "${SIGNING_IDENTITY:-}" ]]; then
  print -u2 'Set SIGNING_IDENTITY to your Developer ID Application certificate identity.'
  exit 1
fi
[[ "$(uname -m)" == arm64 ]] || { print -u2 'Build on an Apple Silicon Mac.'; exit 1; }
APP_VERSION="$(<VERSION)"
APP_BUILD="$(<BUILD_NUMBER)"
[[ "$APP_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' && "$APP_BUILD" =~ '^[0-9]+$' ]] || { print -u2 'Invalid VERSION or BUILD_NUMBER.'; exit 1; }
SDK_VERSION="$(/usr/bin/xcrun --sdk macosx --show-sdk-version)"
[[ "${SDK_VERSION%%.*}" -ge 26 ]] || { print -u2 'Install Apple Command Line Tools with the macOS 26 SDK or newer.'; exit 1; }
SWIFT_ARGS=(-c release --arch arm64)
if [[ "$HOMEBREW_BUILD" == 1 ]]; then
  # Homebrew already sandboxes the build. Nested Swift manifest/macro sandboxes
  # fail on macOS; disable only the nested layers, leaving Homebrew's in place.
  SWIFT_ARGS+=(--disable-sandbox --cache-path "$PWD/.build/swiftpm-cache" -Xswiftc -disable-sandbox)
  export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
  export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-cache"
fi
swift build "${SWIFT_ARGS[@]}" --product LocalFileSorter
BIN_DIR="$(swift build "${SWIFT_ARGS[@]}" --show-bin-path)"
mkdir -p dist
STAGING="$(mktemp -d "$PWD/dist/build.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Local File Sorter.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/LocalFileSorter" "$APP/Contents/MacOS/LocalFileSorter"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LocalFileSorter</string>
<key>CFBundleIdentifier</key><string>local.ompatnaik.LocalFileSorter</string>
<key>CFBundleName</key><string>Local File Sorter</string>
<key>CFBundleDisplayName</key><string>Local File Sorter</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
<key>CFBundleVersion</key><string>$APP_BUILD</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSDownloadsFolderUsageDescription</key><string>Watch your selected Downloads folder and sort finished downloads after you enable sorting.</string>
<key>NSDocumentsFolderUsageDescription</key><string>Store sorted files in your selected destination and maintain undo history.</string>
</dict></plist>
PLIST
/usr/bin/plutil -lint "$APP/Contents/Info.plist"
if [[ "$SIGNED" == 1 ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
  codesign --display --verbose=4 "$APP" 2>&1 | /usr/bin/grep -q '^Authority=Developer ID Application:'
else
  codesign --force --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"
# Only generated dist bundles are replaced; installed apps are never touched.
rm -rf "$PWD/dist/Local File Sorter.app"
mv "$APP" "$PWD/dist/Local File Sorter.app"
print "Built $PWD/dist/Local File Sorter.app"
if [[ "$SAMPLES" == 1 ]]; then
  SAMPLE_APP="$STAGING/Local File Sorter Samples.app"
  /usr/bin/ditto "$PWD/dist/Local File Sorter.app" "$SAMPLE_APP"
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.ompatnaik.LocalFileSorter.samples' "$SAMPLE_APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Set :CFBundleName Local File Sorter Samples' "$SAMPLE_APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Local File Sorter Samples' "$SAMPLE_APP/Contents/Info.plist"
  codesign --force --sign - "$SAMPLE_APP"
  rm -rf "$PWD/dist/Local File Sorter Samples.app"
  mv "$SAMPLE_APP" "$PWD/dist/Local File Sorter Samples.app"
  print "Built sample app $PWD/dist/Local File Sorter Samples.app"
fi
