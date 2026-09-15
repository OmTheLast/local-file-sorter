# Homebrew release

Local File Sorter is packaged as a Homebrew **cask** containing one native `.app`, for Apple Silicon and macOS 26 or later. End users need no compiler, Python, model API key or Homebrew formula dependencies. Classification stays on their Mac.

The first binary release is **0.3.0**. It is currently a local candidate: this machine has no Developer ID Application signing identity. Its ad-hoc signature verifies file integrity but Gatekeeper rejects it. Do not publish this candidate as a working public binary download, add it to a live tap, or recommend removing quarantine. No Apple Developer enrollment or other paid service has been purchased.

## Build a candidate

Build prerequisites: an Apple Silicon Mac, Apple Command Line Tools or Xcode with a macOS 26+ SDK, Swift 6+, Python 3, and Homebrew for the packaging test. The scripts use Apple/system tools and the existing Homebrew installation.

```sh
./scripts/package-release.sh --candidate
./scripts/verify-release.py dist/releases/0.3.0-candidate
./scripts/test-package.sh dist/releases/0.3.0-candidate
```

Each output directory is created exclusively. Existing output directories are never reused. Set `RELEASE_OUTPUT_DIR` to a new directory to repeat a build while preserving an earlier candidate.

The output contains the app, `LocalFileSorter-0.3.0-arm64.zip`, `SHA256SUMS`, a generated `local-file-sorter.rb`, build provenance and safety-test output. Only the main app is in the ZIP; sample files, user settings, source folders, personal history and signing credentials are not included. A dirty candidate records that fact in provenance. For distribution, build from a clean committed revision.

`test-package.sh` installs the real archive using an isolated temporary cask and application directory, then uninstalls it. The temporary cask changes the token and URL and omits the quit hook so it cannot stop another installed instance. It verifies the checksum, metadata, architecture, signature integrity and preservation of the existing settings/history/login configuration. It does not launch the app, test the production quit hook or prove Gatekeeper acceptance. Downloads may continue sorting during this test; pause the app if that causes its state-preservation assertion to fail.

## Sign and notarize

Use an existing **Developer ID Application** signing identity and a `notarytool` profile already stored in Keychain. Do not put passwords, private keys, API keys or certificates in this repository. Check available identities with `security find-identity -v -p codesigning`. Follow [Apple's notarization guide](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) to configure the Keychain profile outside this project.

```sh
SIGNING_IDENTITY='Developer ID Application: YOUR EXISTING IDENTITY' \
NOTARY_KEYCHAIN_PROFILE='YOUR EXISTING KEYCHAIN PROFILE' \
./scripts/package-release.sh --notarized

./scripts/verify-release.py dist/releases/0.3.0-notarized --notarized
./scripts/test-package.sh dist/releases/0.3.0-notarized
```

The notarized path requires a clean Git working tree, runs the safety suite, signs with hardened runtime and a secure timestamp, submits the binary to Apple, requires an Accepted response, staples and validates the ticket, assesses Gatekeeper, then creates the final ZIP and its checksum. Only the release binary is submitted to Apple, not documents or file contents being sorted. This path has not been exercised on this machine because no signing identity is installed.

The ZIP must be created **after** stapling. Rebuilding/signing/stapling changes the bytes and therefore requires regenerating the cask checksum. Never reuse a checksum from the local candidate.

## Publish after signing is ready

Review the exact source revision, release notes and signed artifacts before publishing. No workflow auto-publishes on push. Keep `VERSION` and `BUILD_NUMBER` increasing for subsequent releases. Keep published artifacts immutable: use a new version to replace a bad release.

1. Run the notarized verification and packaging tests above. Test opening the downloaded, quarantined app on a fresh macOS user account; enable sorting with sample downloads, verify pause, undo, window-closed operation and login. That clean-account test is still outstanding.
2. Create/update a GitHub **draft prerelease** for `v0.3.0`, targeting exactly the commit recorded in `provenance.json`. Upload the final ZIP, `SHA256SUMS`, generated cask, provenance and safety results. Use `docs/RELEASE_NOTES_0.3.0.md` as the body, replacing its candidate-status paragraph with the verified signing status. When updating the draft candidate, replace all assets as a set; never mix its checksum with the signed ZIP.
3. Publish the prerelease only after the signed build passes. Download the now-public archive and check its SHA-256 against the generated cask.
4. Make the existing public repository a tap by copying the generated **notarized** cask into `Casks/local-file-sorter.rb`, running `brew style` and `brew audit --cask --online` on that cask in a local tap, then committing/pushing it. The live `Casks/` entry is deliberately absent while its download is an unpublished, unnotarized draft.

Once those steps are complete, the supported installation commands will be:

```sh
brew tap omthelast/local-file-sorter https://github.com/OmTheLast/local-file-sorter
brew install --cask omthelast/local-file-sorter/local-file-sorter
open -a 'Local File Sorter'
```

If Homebrew requests trust, trust just `omthelast/local-file-sorter/local-file-sorter` as a cask. This is a third-party tap, not a submission to the official Homebrew repository. The command is intentionally **not advertised as available yet**.

Updates: `brew update` then `brew upgrade --cask omthelast/local-file-sorter/local-file-sorter`. The cask quits the running app when upgrading; reopen it afterward. Saved automation preferences and undo history survive. Removal: `brew uninstall --cask omthelast/local-file-sorter/local-file-sorter`. There is no `zap` stanza; source files, sorted files and application support data are preserved. Remove any manually added Login Item separately.

## First launch and migration

Fresh installs start paused. Choose folders/categories in Settings, optionally preview old files, then enable automatic sorting from Downloads. Further finished downloads sort without per-file approval; unclear files go directly into Needs Review. Existing saved enabled/paused settings are preserved during upgrades. Installing a cask does not launch sorting or silently add login startup. To start at login, add the installed app under System Settings → General → Login Items. It keeps running when its window is closed.

For this Mac's earlier script installation in `~/Applications`, pause and quit before switching to the Homebrew copy. Unload the old `local.ompatnaik.LocalFileSorter.login` LaunchAgent and move that named plist out of `~/Library/LaunchAgents`; move the old app out of `~/Applications`. Keep `~/Library/Application Support/LocalFileSorter` and all source/destination files. Install/open the Homebrew copy and add that copy to Login Items if desired. Do not run both copies concurrently; the history lock permits one sorter only. No migration has been performed automatically on this Mac.

## Current verification limits

Twenty safety suites passed on macOS 26.2 with Swift 6.3.2 and the macOS 26.5 SDK, including first-install opt-in and preserving enabled state during an upgrade. The local Homebrew install/uninstall test passed. Signature integrity passed; Gatekeeper rejection of the ad-hoc candidate was confirmed. A real signed/notarized download, public release URL, clean-account launch, actual Homebrew version upgrade, logout/login, and Intel execution were not tested. Intel is explicitly unsupported by this package.

References: [Homebrew cask format](https://docs.brew.sh/Cask-Cookbook), [third-party taps](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap), [official cask Gatekeeper requirements](https://docs.brew.sh/Acceptable-Casks).
