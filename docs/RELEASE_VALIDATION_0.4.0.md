# Local File Sorter 0.4.0 validation

Verified on 2026-09-29 on the existing M4 Max / macOS 26.2 development Mac.

- Release app compiled and its ad-hoc signature passed verification.
- **22 safety suites, zero assertion failures.** Covers existing move/undo/collision/write/recovery tests plus document eligibility, recognized-browser metadata, settings migration and explicitly approved review of historical moves and persistent exclusion of unchecked existing files. No personal documents were moved during verification.
- **30/31 representative pipeline cases matched expectations.** The seven new cases added after prompt refinement scored 6/7. One school assignment conservatively went to Archives instead of Study. No wrong non-fallback category was observed in this final run. This small synthetic set is not a real-world accuracy estimate. The evaluation intentionally exits nonzero for the remaining mismatch; it is not a fully passing classification test.
- Earlier failing evaluations are retained alongside the final report. Prompt/category changes, whitespace-normalized quote matching and a separate category-fit check reduced observed misclassification. The category-fit check is another model result, not proof of correctness.
- Native sample UI: setup → preview of five supported files → explicit approval → Invoices, Work, Research, Images and Archives. Four excluded fixtures stayed in place. Image collision used a separate folder with the original filename.
- Native History: Locations opened with original/sorted paths, a disabled missing-original reveal control, working sorted-file Finder action and Done. Undo with an occupied original path preserved both files and showed the restored conflict-folder reason.
- The updated personal app opened its setup sheet with Downloads → Documents, editable categories and browser-origin filtering. Automation was paused for the upgrade. The user completed setup and enabled automation in the app during verification; the final restart preserves their saved choices.

## Limits

The remaining school-assignment mismatch, complex personal documents, arbitrary browsers/download managers, sleep/wake and logout/login were not comprehensively evaluated. Browser metadata was tested with synthetic Safari/terminal attributes, not fresh downloads from every browser. Long documents still hit the bounded extraction limit (8 PDF pages / 6,000 text characters), then go to Archives with an explicit reason. Existing documents can be manually assigned another category in preview. Unknown file types and model/data assets stay untouched. Prior moved files that were modified after sorting are excluded from historical review.

Current reports: [safety](validation-0.4.0/safety-results.txt), [classification](validation-0.4.0/evaluation.txt), [build](validation-0.4.0/build-results.txt).
