#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
MODE="${1:-}"
if [[ $# != 1 || ( "$MODE" != --candidate && "$MODE" != --notarized ) ]]; then
  print -u2 "Usage: $0 --candidate | --notarized"
  exit 2
fi
if [[ "$MODE" == --notarized ]]; then
  [[ -n "${SIGNING_IDENTITY:-}" && -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]] || {
    print -u2 'A Developer ID Application identity and NOTARY_KEYCHAIN_PROFILE are required. No credentials are stored in this project.'
    exit 1
  }
  [[ -z "$(git status --porcelain)" ]] || { print -u2 'Commit all release inputs before building a notarized release.'; exit 1; }
fi
VERSION="$(<VERSION)"
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { print -u2 'Invalid VERSION.'; exit 1; }
OUTPUT="${RELEASE_OUTPUT_DIR:-$PWD/dist/releases/$VERSION-${MODE#--}}"
mkdir -p "${OUTPUT:h}"
# Refuse to overwrite any earlier release artifacts.
mkdir "$OUTPUT"
OUTPUT="${OUTPUT:A}"
swift run SorterTests 2>&1 | tee "$OUTPUT/safety-results.txt"
if [[ "$MODE" == --notarized ]]; then
  ./scripts/build-app.sh --signed --no-samples
else
  ./scripts/build-app.sh --no-samples
fi
/usr/bin/ditto "$PWD/dist/Local File Sorter.app" "$OUTPUT/Local File Sorter.app"
APP="$OUTPUT/Local File Sorter.app"
if [[ "$MODE" == --notarized ]]; then
  /usr/bin/ditto -c -k --keepParent "$APP" "$OUTPUT/notary-submission.zip"
  xcrun notarytool submit "$OUTPUT/notary-submission.zip" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait --output-format json > "$OUTPUT/notarization.json"
  python3 - "$OUTPUT/notarization.json" <<'PY'
import json, sys
assert json.load(open(sys.argv[1]))['status'] == 'Accepted', 'Apple notarization was not accepted'
PY
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl --assess --type execute --verbose=2 "$APP"
fi
codesign --verify --deep --strict "$APP"
[[ "$(lipo -archs "$APP/Contents/MacOS/LocalFileSorter")" == arm64 ]]
ARCHIVE="$OUTPUT/LocalFileSorter-$VERSION-arm64.zip"
/usr/bin/ditto -c -k --keepParent "$APP" "$ARCHIVE"
python3 - "$OUTPUT" "$VERSION" "$MODE" <<'PY'
import hashlib, json, pathlib, subprocess, sys
out, version, mode = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
archive = out / f'LocalFileSorter-{version}-arm64.zip'
sha = hashlib.sha256(archive.read_bytes()).hexdigest()
(out / 'SHA256SUMS').write_text(f'{sha}  {archive.name}\n')
template = pathlib.Path('packaging/local-file-sorter.rb.in').read_text()
(out / 'local-file-sorter.rb').write_text(template.replace('@VERSION@', version).replace('@SHA256@', sha))
(out / 'provenance.json').write_text(json.dumps({
    'version': version, 'architecture': 'arm64', 'minimum_macos': '26.0',
    'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'working_tree_dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip()),
    'distribution': 'notarized' if mode == '--notarized' else 'local-candidate-only',
    'archive': archive.name, 'sha256': sha,
    'swift': subprocess.check_output(['swift', '--version'], text=True, stderr=subprocess.STDOUT).strip(),
}, indent=2) + '\n')
PY
print "Prepared $OUTPUT"
if [[ "$MODE" == --candidate ]]; then
  print 'LOCAL CANDIDATE ONLY: ad-hoc signed, not notarized. Do not publish as an installable binary release.'
fi
