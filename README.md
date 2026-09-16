# Local File Sorter

**Keep your Downloads organized automatically.**

Local File Sorter is a native Mac app that sorts finished downloads into the right folders. It combines file-type rules with on-device Apple Intelligence to understand documents, with all processing kept on your Mac.

## Features

- **Automatic sorting** — waits for downloads to finish, then organizes new files in the background.
- **Customizable folders** — start with Invoices, Work, Research, Images, Installers, Archives, and Needs Review, or edit the categories to suit your workflow.
- **Document understanding** — reads PDFs, text, and common Office formats, with local OCR for scanned PDFs.
- **Files stay protected** — preserves filenames, never overwrites existing files, and keeps a move history with Undo.
- **You're in control** — pause from the menu bar, review uncertain files, or preview and sort older files manually.
- **Local processing** — uses Apple's on-device model when available; file-type rules and Needs Review continue working without it.

## Install

Requires an Apple Silicon Mac running macOS 26 or later, Homebrew, and Command Line Tools with the macOS 26 SDK or newer.

```sh
brew tap omthelast/local-file-sorter https://github.com/OmTheLast/local-file-sorter
brew install omthelast/local-file-sorter/local-file-sorter
local-file-sorter
```

## Get started

1. Open **Local File Sorter** and choose your folders in **Settings**. The defaults are `~/Downloads` and `~/Documents/Sorted Files`.
2. Select **Resume automatic sorting** to begin. New downloads sort automatically once they're ready; files already present stay untouched.
3. Check **History** to review or undo moves. Uncertain or unsupported files go to **Needs Review**.

Close the window to keep sorting from the menu bar. To try the app with temporary sample files, run `local-file-sorter --demo`.

## Good to know

Documents can be misclassified, so review History and Needs Review periodically. Sorting currently works within a single filesystem volume, and document extraction has size and format limits.

[Latest release](https://github.com/OmTheLast/local-file-sorter/releases/tag/v0.3.0) · [Setup, updates, and removal](docs/RELEASING.md) · [Technical details](docs/TECHNICAL.md) · [Report an issue](https://github.com/OmTheLast/local-file-sorter/issues)
