# Local File Sorter 0.3.0 — Homebrew packaging candidate

**Draft only.** The attached candidate is ad-hoc signed and has not been notarized. Gatekeeper rejects it. It is for local packaging review, not a public installable release. Replace the archive, checksum, cask and provenance together with a Developer ID signed/notarized build before publishing.

A native, local Mac utility that automatically sorts finished downloads into Invoices, Work, Research, Images, Installers, Archives and Needs Review. Folders and categories are configurable. Clear file types use rules; documents use Apple's on-device Foundation Models with local text extraction and PDF OCR. No cloud classification, API keys or paid runtime dependencies.

- Apple Silicon, macOS 26 or later. Apple Intelligence is optional: rules and Needs Review remain usable without it.
- First launch starts paused. Enable once to sort subsequent downloads without per-file approval. Upgrades preserve the existing enabled/paused choice.
- Waits for downloads/writers to settle; existing files remain excluded from automation.
- Preserves filenames, never overwrites existing destinations, and records moves with conflict-safe Undo.
- Keeps sorting when the window closes. Login startup is an explicit user choice.
- Cask installation/removal preserves sorted files, configuration and undo history.

The release ZIP contains only the native app. A SHA-256 checksum, generated cask, source/build provenance and 20-suite safety report accompany it. Homebrew installation and removal were tested using the real archive in an isolated temporary directory. Signing/notarization, clean-user Gatekeeper launch, actual Homebrew upgrade and logout/login remain untested.

This is an early prototype. Office extraction has limits, cross-volume moves fail safely, and classification can be wrong. Review History and Needs Review periodically. See the README and `docs/RELEASING.md` for supported formats, limits and release instructions.
