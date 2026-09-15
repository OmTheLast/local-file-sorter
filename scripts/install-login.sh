#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
APP="$PWD/dist/Local File Sorter.app"
if [[ ! -d "$APP" ]]; then ./scripts/build-app.sh; fi
INSTALL="$HOME/Applications/Local File Sorter.app"
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
/usr/bin/ditto "$APP" "$INSTALL"
/usr/bin/codesign --verify --deep --strict "$INSTALL"
python3 - "$INSTALL" "$HOME/Library/LaunchAgents/local.ompatnaik.LocalFileSorter.login.plist" <<'PY'
import plistlib,sys,os
app,path=sys.argv[1:]
job={'Label':'local.ompatnaik.LocalFileSorter.login',
     'ProgramArguments':['/usr/bin/open','-g','-a',app,'--args','--background'],
     'RunAtLoad':True,'LimitLoadToSessionType':'Aqua','ProcessType':'Background'}
with open(path+'.tmp','wb') as f: plistlib.dump(job,f)
os.replace(path+'.tmp',path)
PY
LABEL="gui/$(id -u)/local.ompatnaik.LocalFileSorter.login"
PLIST="$HOME/Library/LaunchAgents/local.ompatnaik.LocalFileSorter.login.plist"
if launchctl print "$LABEL" >/dev/null 2>&1; then launchctl bootout "$LABEL"; fi
launchctl bootstrap "gui/$(id -u)" "$PLIST"
print "Installed $INSTALL and enabled start at login. Use the menu-bar icon to pause or open History."
