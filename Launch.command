#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
if [[ ! -d "dist/Local File Sorter.app" ]]; then ./scripts/build-app.sh; fi
open "dist/Local File Sorter.app"
