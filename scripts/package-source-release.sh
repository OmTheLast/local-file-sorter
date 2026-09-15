#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
[[ -z "$(git status --porcelain)" ]] || { print -u2 'Commit release inputs before packaging source.'; exit 1; }
VERSION="$(<VERSION)"
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || exit 1
OUTPUT="${RELEASE_OUTPUT_DIR:-$PWD/dist/releases/$VERSION-source}"
mkdir -p "${OUTPUT:h}"
mkdir "$OUTPUT"
OUTPUT="${OUTPUT:A}"
COMMIT="$(git rev-parse HEAD)"
git archive --format=tar.gz --prefix="LocalFileSorter-$VERSION/" --output="$OUTPUT/LocalFileSorter-$VERSION-source.tar.gz" "$COMMIT"
python3 - "$OUTPUT" "$VERSION" "$COMMIT" <<'PY'
import hashlib,json,pathlib,sys
out,version,commit=pathlib.Path(sys.argv[1]),sys.argv[2],sys.argv[3]
archive=out/f'LocalFileSorter-{version}-source.tar.gz'
sha=hashlib.sha256(archive.read_bytes()).hexdigest()
(out/'SHA256SUMS').write_text(f'{sha}  {archive.name}\n')
template=pathlib.Path('packaging/local-file-sorter-formula.rb.in').read_text()
(out/'local-file-sorter.rb').write_text(template.replace('@VERSION@',version).replace('@SHA256@',sha))
(out/'provenance.json').write_text(json.dumps({'version':version,'commit':commit,'distribution':'build-from-source','archive':archive.name,'sha256':sha},indent=2)+'\n')
PY
print "Prepared source release in $OUTPUT"
