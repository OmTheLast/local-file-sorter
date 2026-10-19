<h1 align="center">Local File Sorter</h1>

**Sort completed Mac downloads into your folders, review uncertain documents, and undo a move from history.**

Apple Silicon. macOS 26+ and macOS 26 SDK. On-device classification; files stay on your Mac. Single-volume moves.

By Om Patnaik · repository created September 2026.

## Install

| Platform / path | Start here |
| --- | --- |
| Homebrew | `brew tap omthelast/local-file-sorter https://github.com/OmTheLast/local-file-sorter`, then `brew install omthelast/local-file-sorter/local-file-sorter` |

Run `local-file-sorter`, choose source and destination folders, and review existing documents before moving them. Try temporary sample files first with `local-file-sorter --demo`.

```bash
local-file-sorter --demo
```

## Why

Your Downloads folder mixes documents worth filing with installers, archives, and unfinished downloads. Local File Sorter waits for completed arrivals and combines file rules with optional Apple Intelligence. Uncertain documents need review; model output can misclassify a file.

## Review before filing

Setup offers a source, destination, and editable categories. Existing files move only after selection and approval. Automatic sorting handles eligible new downloads; code, datasets, weights, installers, archives, and subfolders stay out of that path.

## Recover a move

History records destinations and reasons. Use Undo to restore a moved file, pause from the menu bar, or open Configure to change folders. Unknown-origin files remain available for manual review.

## Notes from building it

I treated file arrival and file safety as separate parts of the sorter. Preserving names, avoiding overwrites, and recording undo information make classification mistakes recoverable. I would broaden the extraction tests before accepting more document formats.

## Commands

```bash
local-file-sorter               # open setup and the menu-bar app
local-file-sorter --demo        # try temporary sample files
swift run SorterTests           # run deterministic safety checks without AI
swift run SorterCheck           # optional on-device classifier fixture evaluation
scripts/build-app.sh            # build an app from source
```

## Verify it yourself

```bash
swift run SorterTests
```

The safety executable checks collisions, approval, undo, recovery, extraction, and automatic-arrival handling with AI disabled. `SorterCheck` separately evaluates classification on synthetic fixtures and can use Apple Intelligence. Packaging and interaction evidence is documented under `docs/` and `automatic-ui-results.txt`; model availability and permissions depend on the Mac.

## Credits, license and pointers

Built with Swift, SwiftUI, Apple Foundation Models, and local document extraction. No source license file is present. [Technical details](docs/TECHNICAL.md) · [Release instructions](docs/RELEASING.md).

[Full setup, original notes, and project history](README-DETAILS.md).
