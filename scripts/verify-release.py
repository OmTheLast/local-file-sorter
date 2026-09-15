#!/usr/bin/env python3
"""Verify release contents; --notarized is a mandatory gate before publication."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import re
import subprocess
import tempfile
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('directory', type=Path)
parser.add_argument('--notarized', action='store_true')
args = parser.parse_args()
out = args.directory.resolve()
p = json.loads((out / 'provenance.json').read_text())
assert re.fullmatch(r'\d+\.\d+\.\d+', p['version']), 'Invalid version'
assert p['archive'] == f"LocalFileSorter-{p['version']}-arm64.zip"
archive = out / p['archive']
sha = hashlib.sha256(archive.read_bytes()).hexdigest()
assert sha == p['sha256'], 'Archive checksum mismatch'
assert (out / 'SHA256SUMS').read_text() == f'{sha}  {archive.name}\n'
template = (Path(__file__).resolve().parent.parent / 'packaging/local-file-sorter.rb.in').read_text()
assert (out / 'local-file-sorter.rb').read_text() == template.replace('@VERSION@', p['version']).replace('@SHA256@', sha), 'Cask mismatch'
with zipfile.ZipFile(archive) as z:
    for entry in z.namelist():
        parts = PurePosixPath(entry).parts
        assert parts and parts[0] == 'Local File Sorter.app' and '..' not in parts
    info = plistlib.loads(z.read('Local File Sorter.app/Contents/Info.plist'))
    assert info['CFBundleIdentifier'] == 'local.ompatnaik.LocalFileSorter'
    assert info['CFBundleShortVersionString'] == p['version']
    assert info['LSMinimumSystemVersion'] == '26.0'
with tempfile.TemporaryDirectory(prefix='LocalFileSorter-verify-') as folder:
    subprocess.run(['/usr/bin/ditto', '-x', '-k', str(archive), folder], check=True)
    app = Path(folder) / 'Local File Sorter.app'
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    arch = subprocess.check_output(['lipo', '-archs', str(app / 'Contents/MacOS/LocalFileSorter')], text=True).strip()
    assert arch == 'arm64'
    if args.notarized:
        assert p['distribution'] == 'notarized', 'Local candidate: rebuild with --notarized before publishing'
        assert not p['working_tree_dirty'], 'Release was built with uncommitted changes'
        signature = subprocess.check_output(['codesign', '--display', '--verbose=4', str(app)], stderr=subprocess.STDOUT, text=True)
        assert 'Authority=Developer ID Application:' in signature
        subprocess.run(['xcrun', 'stapler', 'validate', str(app)], check=True)
        subprocess.run(['spctl', '--assess', '--type', 'execute', '--verbose=2', str(app)], check=True)
print(f"Verified {archive.name}: {'notarized distribution' if args.notarized else 'archive integrity only (not publication approval)'}")
