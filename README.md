# Local File Sorter · macOS prototype

A small native SwiftUI utility for this Mac. It uses deterministic file-type rules, PDFKit, Vision OCR, and Apple's on-device Foundation Models. No packages, API keys, cloud AI, telemetry, or paid dependencies are included.

## Automatic downloads

Open `dist/Local File Sorter.app`, or double-click `Launch.command` (builds it on first use). The normal app starts watching `~/Downloads` automatically and sorts finished arrivals into `~/Documents/Sorted Files`. There is no preview or per-file approval for new downloads. Existing files present at first setup are recorded locally and excluded, including after app restarts and edits/renames within the source. New files arriving while paused or while the app is closed are processed after resuming. A new file reusing an old filename is detected by file identity.

- **Downloads** shows the automatic-sorter status and Pause/Resume.
- **History** shows moves and **Undo move**. Undo pauses sorting and remembers the restored file so it is not automatically sorted again. Resume when ready.
- **Settings** changes the folders, categories and local AI option. Pause before editing; changing source folders captures a fresh exclusion baseline for that source.
- **Existing files** is optional: pause, scan, select old files and approve their moves manually. This never has to be used for new downloads.

Clear types use rules; documents use on-device AI. Unsupported, ambiguous, unreadable or AI-unavailable documents move directly into **Needs Review**, retaining their filenames and undo history. No cloud AI is used. Open that folder to review them whenever convenient. Failed filesystem moves remain in Downloads and appear under Existing files; pause/resume retries them.

Close the window to keep sorting. The menu-bar tray icon provides Open File Sorter, Pause/Resume, Open Sorted Files and Quit. Pause is remembered across relaunches. Quit stops sorting until the next app launch; it does not disable the saved automatic mode.

For automatic startup at login, run:

```sh
./scripts/build-app.sh
./scripts/install-login.sh
```

This copies the app to `~/Applications/Local File Sorter.app` and installs `~/Library/LaunchAgents/local.ompatnaik.LocalFileSorter.login.plist`. The user-level launch agent opens the app in the background at login; no administrator access is required. The app continues without a window. It does not restart itself immediately after Quit or a crash. To disable login startup, use `launchctl bootout gui/$(id -u)/local.ompatnaik.LocalFileSorter.login` and move that named plist out of LaunchAgents. Pause inside the app is the simpler way to stop sorting while leaving startup installed.

The sample app stays isolated in a temporary folder and starts paused. Press Resume there to test new arrivals without a preview. Sample files already present remain excluded. It never watches real Downloads or installs a login agent.

## Classification and extraction

- Images, disk images/installers and archives use extension/UTType rules. Category renaming retains their built-in rule assignment; removing the corresponding category routes those files to review.
- Documents use filename plus extracted text to classify their main purpose. Invoices use content classification: an early keyword rule misclassified an invoice tutorial and was removed after evaluation.
- PDFKit reads embedded PDF text; Vision performs local OCR on pages with little readable text. Plain UTF-8/UTF-16 text, Markdown, CSV/TSV, JSON/YAML, logs and TeX are supported.
- DOCX, XLSX and PPTX read bounded text members from ZIP containers using the system `unzip`; XML external entities are disabled and entity declarations rejected. DOC, RTF and ODT use system `textutil`. These are text-only conversions: spreadsheet formulas, slides' images/charts, embedded objects, macros and Office formatting are not interpreted or executed.
- Apple `SystemLanguageModel.default` performs on-device classification. A dynamic generation schema restricts output to the configured category IDs. Every non-review AI decision must supply an exact supporting quote found in the extracted text. No confidence value is requested or used. A valid quote does **not** prove the category is correct; representative evaluation and checking History/Needs Review remain important.
- Contents and filenames are untrusted data. They are serialized separately from the classifier's instructions, no model tools are provided, and common instruction-injection patterns route to review. This is defense in depth, not a claim that arbitrary prompt injection is solved.
- Unsupported, empty, encrypted, unreadable, ambiguous or incompletely extracted documents go to Needs Review (or propose it in manual preview). AI errors, refusals and unavailable models fall back to review. Disabling AI leaves rules, preview, category overrides, manual sorting and undo usable.

## File safety and history

Only the source's top-level regular files are considered. The app skips hidden files, temporary names/extensions, unfinished downloads, aliases, symbolic links, folders, bundles, and non-downloaded cloud placeholders. It does not request cloud-placeholder downloads. The destination may be a subfolder of the source; it is excluded from scanning.

Monitoring polls every three seconds while enabled, normally moving completed files after roughly 15–20 seconds of stability. A file must have unchanged inode/device, size and timestamps across observations for at least 15 seconds, an old-enough modification time, and no writer reported by `lsof`. Move-time checks repeat these conditions, take an advisory lock and verify a SHA-256 digest. Readiness is a conservative heuristic: an arbitrary application can close a file and resume writing later. It is not possible to prove completion for every writer. Common browsers' partial-download extensions are always skipped.

Moves use macOS `renamex_np(..., RENAME_EXCL)`, so the kernel refuses to replace an existing destination. Filenames are unchanged. On a collision the enclosing path becomes `Category/Duplicates/<UUID>/original-name.ext`; if the destination becomes occupied after preview, a fresh conflict folder may be chosen at execution and recorded in History. The app never deletes a file, empties Trash, or cleans up user directories. Empty conflict folders can remain after failed operations.

The normal app stores settings, persistent automation state/exclusions and move records under `~/Library/Application Support/LocalFileSorter/`. Each record contains original/destination paths, timestamps, file identity, hash, short classification reason (possibly a document quote), state, and undo path. It does not store full extracted documents. The parent history directory is private to the current user. A process lock prevents two main-app instances from operating on the same history.

Records are written and flushed before each move or undo. At startup, interrupted operations are reconciled against file identity and content hashes. Ambiguous recovery leaves files untouched with an `attention` record. Corrupt/unreadable history blocks operations rather than resetting or discarding it. Keep the history directory if you want undo.

Undo verifies file identity and content, then restores the original path. If that path is occupied, it restores into `OriginalParent/Duplicates/<UUID>/original-name.ext`, preserving both files. That nested folder is not automatically rescanned.

## Tested on this Mac

Automatic-mode update: `automatic-safety-results.txt` records 19 passing suites, including persistent exclusions, new same-name files, automatic Needs Review fallback, persisted pause, and undo exclusion. `automatic-ui-results.txt` records native window-closed arrival checks. The earlier preview-first reports below are retained as historical evidence; preview is now optional for old files.

macOS 26.2, Apple M4 Max, 64 GB RAM, Swift 6.3.2, the macOS 26.5 SDK, and Apple Command Line Tools (deployment target macOS 26.0). The Foundation Models framework compiled successfully and its runtime availability probe returned `available`; real model generations succeeded. Full Xcode/XCTest was unavailable, so the tests use a standalone Swift executable with failure exit codes.

- `evaluation.txt`: **20/20 pipeline classifications** matched expected results, including 15 model-backed cases, file-type rules, ambiguous/personal/mixed documents, invoice-vs-research, a malicious instruction example, a custom recipe category and a renamed invoice category. Small synthetic evaluation, not a production accuracy estimate. `evaluation-before-fix.txt` retains the earlier tutorial failure.
- `safety-results.txt`: **17 suites, zero assertion failures**. Covers approval, read-only preview, writing/settling, skips, collision-safe moves/undo, stale/modified files, category validation, symlink rejection, kernel no-replace, history corruption, single-instance locking, simulated interrupted moves/undo, extraction size limits/timeouts, Office formats, native PDFs and scanned-PDF OCR.
- `ui-test-results.txt`: native app preview, selected sample move, history, undo, and automatic arrival handling tested end to end. An open writer remained untouched beyond the quiet period, moved after close and settling, while incomplete downloads and existing files stayed in the source. Only temporary fixtures were involved.

## Prototype limits and untested cases

Moves are intentionally restricted to the same filesystem volume; cross-volume moves fail safely without copying or deleting. Both default folders on this Mac work within that constraint. No external-volume test was performed.

Extraction is capped at 30 MB per document, eight PDF pages and 6,000 text characters. Incomplete/oversized extraction routes to review. Office XML output and local subprocesses are bounded; model generation requests have a cancellation timeout. Foundation Models cancellation and native PDF/OCR parsing ultimately depend on Apple's frameworks.

Apple Pages/Numbers/Keynote documents, legacy XLS/PPT, handwriting, image-only Office documents, unusually encoded text and password-protected documents are not comprehensively supported; review them manually. Standalone images use the Images rule; scanned **PDFs** receive OCR. Complex real-world Office files, multilingual/poor-quality scans and your personal Downloads have not been evaluated. Login-agent startup was exercised directly; a full logout/login was not performed. A sudden power loss, disk-full filesystem, actual Apple Intelligence disabled/model-downloading state, and sleep/wake stress have not been induced. Interrupted journal states, corrupted history, disabled-AI fallback and subprocess timeout were tested instead.

The app is locally ad-hoc signed, not notarized or sandboxed for App Store distribution. It needs no full Xcode installation to build. It is a local prototype with automatic sorting explicitly enabled for new arrivals.

## Rebuild and rerun

From this project directory:

```sh
./scripts/build-app.sh
swift run SorterTests
swift run SorterCheck
```

`SorterTests` and `SorterCheck` only create temporary fixtures. They never operate on Downloads. Exit code 0 means the relevant suite passed. Build output is in `dist/`; no downloads or package dependencies are needed.

Apple API references: [Foundation Models guided generation](https://developer.apple.com/videos/play/wwdc2025/301/), [Foundation Models availability](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability), [Vision text recognition](https://developer.apple.com/documentation/vision/recognizetextrequest). The implementation was checked against the installed SDK interfaces for macOS 26 compatibility.
