# Local File Sorter 0.3.0 — free Homebrew source release

Install a small native Mac utility that sorts finished downloads using file-type rules and Apple's on-device Foundation Models. The Homebrew formula builds the app on your Mac: **no paid Apple Developer membership or signing certificate is needed**.

Requirements: Apple Silicon, macOS 26+, Homebrew and Apple's free Command Line Tools with a macOS 26+ SDK. Full Xcode is not required.

```sh
brew tap omthelast/local-file-sorter https://github.com/OmTheLast/local-file-sorter
brew install omthelast/local-file-sorter/local-file-sorter
local-file-sorter
```

- Enable automatic sorting once; subsequent finished downloads need no per-file approval. Fresh installations start paused, and upgrades preserve the saved choice.
- Configurable folders and categories: Invoices, Work, Research, Images, Installers, Archives and Needs Review.
- Local document extraction, scanned-PDF OCR and on-device AI. Rules and Needs Review remain usable when Apple Intelligence is unavailable.
- Preserves filenames, waits for writes to finish, avoids overwriting files and records moves with conflict-safe Undo.
- Continues sorting when the window closes. Login startup is an explicit user choice in System Settings.
- No cloud AI, API key, paid runtime dependency or Gatekeeper/quarantine workaround.

The downloadable artifact contains source code, not a precompiled app. Its SHA-256 and source commit accompany it. The formula downloads that source, builds locally and gives the new app an ad-hoc integrity signature. It is not an Apple-notarized binary and does not claim to be one.

The 20-suite safety tests cover opt-in, file stability, moves/undo, extraction and recovery. See the attached source-release verification report for Homebrew build and launch results. Fresh-account installs, real version-to-version upgrades and logout/login have not been tested.

This remains an early prototype: classification can be wrong, extraction has limits, and cross-volume moves fail safely. Review History and Needs Review periodically. See the README and `docs/RELEASING.md` for details.
