# Local File Sorter

**Keep your Downloads organized automatically.**

Local File Sorter is a native Mac app that sorts finished downloads into the right folders. It combines file-type rules with on-device Apple Intelligence to understand documents, with all processing kept on your Mac.

## Features

- **Automatic sorting** — waits for downloads to finish, then organizes new files in the background.
- **Customizable folders** — start with Invoices, Work, Research, Personal, Study, Images, and Archives, or edit the categories to suit your workflow.
- **Document understanding** — reads PDFs, text, and common Office formats, with local OCR for scanned PDFs.
- **Files stay protected** — preserves filenames, never overwrites existing files, and keeps a move history with Undo.
- **You're in control** — pause from the menu bar, review uncertain files, or preview and sort older files manually.
- **Local processing** — uses Apple's on-device model when available; rules and manual review continue working without it.

## Install

Requires an Apple Silicon Mac running macOS 26 or later, Homebrew, and Command Line Tools with the macOS 26 SDK or newer.

```sh
brew tap omthelast/local-file-sorter https://github.com/OmTheLast/local-file-sorter
brew install omthelast/local-file-sorter/local-file-sorter
local-file-sorter
```

## Get started

1. Open **Local File Sorter**. Setup asks for your source, destination and categories. Defaults are `~/Downloads` → category folders directly in `~/Documents`.
2. Choose **Save & review documents** to include existing documents and unchanged files previously moved by the app. Check the destinations, select files and **Sort selected**. Nothing in this review moves without approval.
3. Automatic sorting starts after review when enabled in setup. It handles new, completed browser downloads. Model weights, datasets, code, installers, compressed downloads and subfolders stay untouched.
4. Uncertain documents go to **Archives**, with the reason shown in **History**. Use **Locations…** to see both paths and open Finder, or **Undo move** to restore a file.

Use **Configure…** anytime to change folders and categories. It pauses sorting while you make changes. Browser origin filtering is on by default; supported files with unknown origins remain available for manual review.

Close the window to keep sorting from the menu bar. To try the app with temporary sample files, run `local-file-sorter --demo`.

## Good to know

Documents can be misclassified, so review History and Archives periodically. Sorting currently works within a single filesystem volume, and document extraction has size and format limits.

[Latest release](https://github.com/OmTheLast/local-file-sorter/releases/tag/v0.4.0) · [Setup, updates, and removal](docs/RELEASING.md) · [Technical details](docs/TECHNICAL.md) · [Report an issue](https://github.com/OmTheLast/local-file-sorter/issues)
