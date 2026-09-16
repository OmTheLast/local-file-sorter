# Local File Sorter 0.3.0

Keep your Downloads organized automatically with a native Mac app. Local File Sorter combines file-type rules with on-device Apple Intelligence to sort documents, images, installers, and archives into customizable folders.

- Automatically sorts new files after downloads finish.
- Reads PDFs, text, and common Office documents, including local OCR for scanned PDFs.
- Preserves filenames, avoids overwriting files, and provides move history with Undo.
- Runs from the menu bar, with Pause and Resume controls.
- Keeps processing on your Mac. Uncertain files go to Needs Review.

## Install

Requires Apple Silicon, macOS 26+, Homebrew, and Command Line Tools with the macOS 26 SDK or newer.

```sh
brew tap omthelast/local-file-sorter https://github.com/OmTheLast/local-file-sorter
brew install omthelast/local-file-sorter/local-file-sorter
local-file-sorter
```

Choose your folders in Settings, then select **Resume automatic sorting**. Existing files stay untouched unless you choose to sort them manually.

Sorting currently requires source and destination folders on the same filesystem volume. Review History and Needs Review periodically, as document classification can be wrong.

[Setup and usage](https://github.com/OmTheLast/local-file-sorter#readme) · [Supported formats and limits](https://github.com/OmTheLast/local-file-sorter/blob/main/docs/TECHNICAL.md)
