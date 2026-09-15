#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
SIGNED=0
SAMPLES=1
for option in "$@"; do
  case "$option" in
    --signed) SIGNED=1 ;;
    --no-samples) SAMPLES=0 ;;
    *) print -u2 "Usage: $0 [--signed] [--no-samples]"; exit 2 ;;
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
swift build -c release --arch arm64 --product LocalFileSorter
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
mkdir -p dist
STAGING="$(mktemp -d "$PWD/dist/build.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Local File Sorter.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/LocalFileSorter" "$APP/Contents/MacOS/LocalFileSorter"
python3 - "$APP/Contents/Info.plist" "$APP_VERSION" "$APP_BUILD" <<'PY'
import plistlib, sys
info = {
    'CFBundleExecutable': 'LocalFileSorter',
    'CFBundleIdentifier': 'local.ompatnaik.LocalFileSorter',
    'CFBundleName': 'Local File Sorter',
    'CFBundleDisplayName': 'Local File Sorter',
    'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': sys.argv[2],
    'CFBundleVersion': sys.argv[3],
    'LSMinimumSystemVersion': '26.0',
    'NSHighResolutionCapable': True,
    'NSDownloadsFolderUsageDescription': 'Watch your selected Downloads folder and sort finished downloads after you enable sorting.',
    'NSDocumentsFolderUsageDescription': 'Store sorted files in your selected destination and maintain undo history.',
}
with open(sys.argv[1], 'wb') as f:
    plistlib.dump(info, f)
PY
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
