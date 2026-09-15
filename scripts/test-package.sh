#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
[[ $# == 1 ]] || { print -u2 "Usage: $0 RELEASE_DIRECTORY"; exit 2; }
OUTPUT="${1:A}"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_INSTALL_CLEANUP=1
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp/}local-sorter-brew.XXXXXX")"
TEST_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
TAP="localfilesorter/packaging-$TEST_ID"
TOKEN="local-file-sorter-check-$TEST_ID"
TAP_DIR="$(brew --repository)/Library/Taps/localfilesorter/homebrew-packaging-$TEST_ID"
cleanup() {
  if brew list --cask "$TAP/$TOKEN" >/dev/null 2>&1; then brew uninstall --cask "$TAP/$TOKEN"; fi
  brew untrust --cask "$TAP/$TOKEN" >/dev/null 2>&1 || true
  rm -rf "$TAP_DIR" "$TEST_ROOT"
}
trap cleanup EXIT
mkdir -p "$TAP_DIR/Casks" "$TEST_ROOT/Applications"
python3 - "$OUTPUT" "$TAP_DIR/Casks/$TOKEN.rb" "$TOKEN" "$TEST_ROOT" <<'PY'
import hashlib, json, pathlib, plistlib, re, subprocess, sys, zipfile
out, cask_path, token, root = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3], pathlib.Path(sys.argv[4])
p = json.loads((out / 'provenance.json').read_text())
archive = out / p['archive']
assert archive.name == f"LocalFileSorter-{p['version']}-arm64.zip"
assert hashlib.sha256(archive.read_bytes()).hexdigest() == p['sha256']
assert (out / 'SHA256SUMS').read_text() == f"{p['sha256']}  {archive.name}\n"
cask = (out / 'local-file-sorter.rb').read_text()
expected = pathlib.Path('packaging/local-file-sorter.rb.in').read_text().replace('@VERSION@', p['version']).replace('@SHA256@', p['sha256'])
assert cask == expected, 'Cask does not match the release archive and template'
with zipfile.ZipFile(archive) as z:
    for entry in z.namelist():
        path = pathlib.PurePosixPath(entry)
        assert path.parts[0] == 'Local File Sorter.app' and '..' not in path.parts
    info = plistlib.loads(z.read('Local File Sorter.app/Contents/Info.plist'))
assert info['CFBundleShortVersionString'] == p['version']
assert info['CFBundleIdentifier'] == 'local.ompatnaik.LocalFileSorter'
assert info['LSMinimumSystemVersion'] == '26.0'
print('PASS archive checksum, cask checksum/version, bundle metadata and archive layout')
# Use the real archive in an isolated cask/appdir. Remove only the quit hook
# so uninstall cannot quit the user’s separately installed, running sorter.
cask_path.with_name('local-file-sorter.rb').write_text(cask)
cask = cask.replace('cask "local-file-sorter"', f'cask "{token}"')
cask = re.sub(r'^  url .*$', '  url "' + archive.as_uri() + '"', cask, flags=re.M)
cask = cask.replace('  uninstall quit: "local.ompatnaik.LocalFileSorter"\n', '')
cask_path.write_text(cask)
# Snapshot actual settings/history and login configuration by hash only, never contents.
# Keep the test short: if active sorting changes these, this test must be rerun paused.
paths = [pathlib.Path.home() / 'Library/Application Support/LocalFileSorter',
         pathlib.Path.home() / 'Library/LaunchAgents/local.ompatnaik.LocalFileSorter.login.plist']
state = {}
for path in paths:
    for f in ([path] if path.is_file() else path.rglob('*') if path.exists() else []):
        if f.is_file(): state[str(f)] = hashlib.sha256(f.read_bytes()).hexdigest()
(root / 'state.json').write_text(json.dumps(state))
PY
brew style "$TAP_DIR/Casks/local-file-sorter.rb"
brew audit --cask "$TAP/local-file-sorter"
print 'PASS production cask style and offline audit'
brew info --cask "$TAP/$TOKEN"
brew install --cask --require-sha --appdir="$TEST_ROOT/Applications" "$TAP/$TOKEN"
APP="$TEST_ROOT/Applications/Local File Sorter.app"
codesign --verify --deep --strict "$APP"
[[ "$(lipo -archs "$APP/Contents/MacOS/LocalFileSorter")" == arm64 ]]
print 'PASS Homebrew install and installed arm64 bundle signature integrity'
brew uninstall --cask "$TAP/$TOKEN"
[[ ! -e "$APP" ]]
python3 - "$TEST_ROOT/state.json" <<'PY'
import hashlib, json, pathlib, sys
for path, sha in json.loads(pathlib.Path(sys.argv[1]).read_text()).items():
    assert hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest() == sha, f'User state changed: {path}'
print('PASS Homebrew uninstall removed only the test app; existing settings, history and login configuration unchanged')
PY
print 'PASS packaging lifecycle. Launch and Gatekeeper acceptance are separate checks; no quarantine bypass was used.'
