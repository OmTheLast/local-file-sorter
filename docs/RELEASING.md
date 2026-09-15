# Free Homebrew source release

Local File Sorter is distributed as a **Homebrew formula that compiles on the user's Mac**. No Apple Developer membership, Developer ID certificate, notarization service, cloud AI or paid dependency is required. This is a third-party tap, not an official Homebrew/core package.

## Installation

Requirements: Apple Silicon, macOS 26 or later, Homebrew, and Apple's free Command Line Tools with a macOS 26+ SDK. Full Xcode is not required. If the tools are missing, run `xcode-select --install`; if the SDK is too old, update Command Line Tools through Software Update.

Install the published source release:

```sh
brew tap omthelast/local-file-sorter https://github.com/OmTheLast/local-file-sorter
brew install omthelast/local-file-sorter/local-file-sorter
local-file-sorter
```

The formula verifies the source archive's SHA-256 and compiles the native app locally. No precompiled app is downloaded. Homebrew's build sandbox remains enabled; only Swift's nested manifest/macro sandboxes are disabled to avoid unsupported sandbox nesting. The locally generated app receives an ad-hoc integrity signature, which needs no account or certificate. No Gatekeeper setting or quarantine attribute is changed. It is not an Apple-notarized binary.

There are no third-party runtime dependencies. Homebrew may need to install/update its own runtime as part of its normal operation. Building uses the Apple Swift compiler and SDK. The source release archive contains tracked project files only, with no app bundle, user settings, Downloads, undo history, credentials, or build cache.

Fresh installs start paused. Open the app, choose folders/categories if desired and click **Resume automatic sorting** once. Completed downloads then sort automatically, including uncertain files going to Needs Review. Existing files stay excluded. Close the window to keep sorting. Pause and Undo are available in the app. Upgrades preserve the saved enabled/paused choice.

Commands:

```sh
local-file-sorter --version       # Show installed version
local-file-sorter --path          # App location (stable across upgrades)
local-file-sorter --demo          # Separate temporary sample session
local-file-sorter --background    # Open without the main window
```

For login startup, add the path from `local-file-sorter --path` to System Settings → General → Login Items. The formula does not enable sorting, start the app or install a Login Item automatically.

## Updates and removal

Quit the app before upgrading or uninstalling. Then:

```sh
brew update
brew upgrade omthelast/local-file-sorter/local-file-sorter
local-file-sorter

# To remove the installed package:
brew uninstall omthelast/local-file-sorter/local-file-sorter
```

Uninstall removes only Homebrew's app and launcher. It preserves sorted files and `~/Library/Application Support/LocalFileSorter` (settings, exclusions and undo history). Remove a manually added Login Item separately. Existing files are never moved as part of installation, upgrade or removal.

This Mac's earlier copy in `~/Applications` and its login LaunchAgent are separate. To migrate, pause/quit that copy, unload the `local.ompatnaik.LocalFileSorter.login` LaunchAgent, move its plist out of `~/Library/LaunchAgents`, and move the old app out of `~/Applications`. Keep application support/history and all source/destination files. Then launch the Homebrew copy. Do not run both copies against the same history; a process lock allows only one. Migration is not performed by the formula.

## Prepare the next release

1. Update `VERSION` and `BUILD_NUMBER`, finish changes, run `swift run SorterTests`, and commit all release inputs.
2. Run `./scripts/package-source-release.sh`. It creates `dist/releases/VERSION-source` exclusively; set `RELEASE_OUTPUT_DIR` to a fresh directory to repeat without overwriting old artifacts.
3. The output includes `LocalFileSorter-VERSION-source.tar.gz`, `SHA256SUMS`, the generated formula and source provenance. Test the formula's local-source equivalent with a clean Homebrew build, `brew test`, and a native `--demo` launch. Run `brew style` and audit it in a temporary tap. Check removal preserves state.
4. Tag the exact commit from `provenance.json`, push it, and upload the source archive, checksum, provenance and verification report to its GitHub release. Verify remote asset digests. Do not attach the old unnotarized binary candidate.
5. Copy the generated formula into `Formula/local-file-sorter.rb`, commit/push, then test a download/build from the published URL. The app source tag precedes the generated formula commit to avoid a checksum self-reference.

Use a new version for corrections to published artifacts. No workflow auto-publishes or creates bottles. There is intentionally no bottle stanza: users build on their own Macs.

## Binary candidate retained as historical work

The earlier 0.3.0 cask draft required notarization for the intended downloaded-binary experience. That is **not a blocker for this source-based release**. Local candidate artifacts and optional signing scripts remain for reference; the Homebrew installation above does not use them or call Apple's notarization service.

See [the 0.3.0 verification record](RELEASE_VALIDATION_0.3.0.md) for the completed public installation checks.

## Verification limits

The core safety suite covers 20 cases including first-install opt-in, persisted automation, file stability, move/undo conflicts, extraction, OCR and recovery. A source build, app launch and package lifecycle are tested on this M4 Max/macOS 26.2 Mac with Command Line Tools, Swift 6.3.2 and SDK 26.5. Fresh-account installation, a real version-to-version upgrade and logout/login remain untested. Intel is unsupported. Classifier accuracy and document-format limits remain described in the README.

References: [Homebrew formula development](https://docs.brew.sh/Formula-Cookbook), [third-party taps](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap), [Apple Command Line Tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools).
