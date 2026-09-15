# Source release 0.3.0 verification

Verified on 2026-09-15: Apple M4 Max, macOS 26.2, Command Line Tools, Swift 6.3.2, macOS SDK 26.5, Homebrew 6.0.16.

- Source commit: `e53fa1457f7fed130b2d481089b1c787e3f23e77` (tag `v0.3.0`).
- Published prerelease: https://github.com/OmTheLast/local-file-sorter/releases/tag/v0.3.0
- All six release assets matched their local SHA-256 digests before publication; source archive contains no prebuilt app or build cache.
- Formula style and offline audit passed. A local-source build completed in 66 seconds inside Homebrew's default sandbox.
- The native app launched in temporary sample mode without a certificate, account, quarantine removal or Gatekeeper override. UI showed the isolated sample source and paused automation.
- Package removal preserved the existing personal sorter's settings, undo history and login configuration (hash comparison).
- The actual published `brew tap` and `brew install` commands passed; public source download, checksum verification and clean compilation completed in 57 seconds.
- `brew test` on the public installation passed (version 0.3.0, app bundle, arm64 binary, ad-hoc signature integrity).
- `brew audit --online --formula omthelast/local-file-sorter/local-file-sorter` passed after installation completed.
- All 20 core safety suites passed, including first-install opt-in and saved automation mode across upgrades.

The Homebrew package is installed alongside the earlier personal app; that existing app and its login setup were not migrated. Its automatic mode remains enabled. Fresh users enable the Homebrew app once. Migration steps for the earlier installation are in RELEASING.md.

A fresh user account, an actual version-to-version Homebrew upgrade, and logout/login were not tested. No notarized binary is distributed or promised. This remains an early prototype with the extraction, classification and filesystem limits in README.md.
