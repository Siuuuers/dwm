# Gallery typography evidence

This bounded checkpoint replaces Gallery's general UI fonts with the exact
locale-specific Fusion Pixel proportional Regular masters required by
`docs/design/2026-08-24-gallery-maintained-microfiche-registrar-standard-palette-and-state-disposition.md`
section 4.3. Work began from source commit
`86c26633a7fb3a5398050e3a5101e736726ebaff`.

## Implemented surface

- Nine upstream `2026.08.11` WOFF2 faces cover native 8, 10, and 12 pixel
  masters for `latin`, `zh_hans`, and `zh_hant`.
- `assets/ui/gallery/fonts/sources.json` pins the upstream release/tag commit,
  three archive hashes, nine individual file hashes, license notices, and the
  registered metrics. The nine font binaries total 4,238,452 bytes.
- `GalleryTypography` normalizes the three supported locale identifiers,
  loads and caches only the selected face, refuses unsupported tuples, and
  disables system fallback, antialiasing, hinting, and subpixel positioning.
- Gallery binds the selected resource directly and adds zero Label leading.
  No art asset changed.

## Test chronology

`runs.jsonl` records every terminal engine attempt available when this archive
was prepared, including failures. The first useful RED executed two tests and
failed both with 166 of 241 assertions passing. The focused GREEN executed 29
tests with 29 passing, 5,676 assertions, 24 existing Dialogic orphans, and exit
0.

The import attempt exited 0 after initially logging loader errors for the new
files, then importing them. It is evidence of successful import completion,
not a claim that the import log was clean. During cleanup, 141 unrelated
editor-generated UID/import sidecars and an automatically added Dialogic
fixture project entry were removed. A separate initial invocation with a
duplicated `--headless` option was refused by the wrapper before an engine run
and produced no run log, so it is outside the terminal ledger.

The final 11-suite regression is **77/77 tests, 6,753 assertions, 24 existing
Dialogic orphans, exit 0**. Both public-inventory generators exited 0. The
GameState inventory is byte-identical to the base. In SaveManager's generated
inventory, only `records[38].call_sites` changes from length 355 to 357, adding
the new test's Profile and Localization initialization references at lines 114
and 118. This is not a semantic-coverage claim, and its required manifest and
implementation are unchanged. Desktop and
Minesweeper handoff sources did not change, and `project.godot` is restored to
the exact base bytes.

Native review exposed 13 existing `zh-HK` record titles that still used the
shared Simplified Chinese forms. The catalog now owns their registered
Traditional Chinese copy. A repeated 77-test regression passed with the same
6,753 assertions and 24 existing orphans. The first Retry capture remains in
`native-retry-historical/`; it is useful font/layout chronology but precedes
that copy correction. The final localized Retry capture is in `native-retry/`.

The final native title run mounted the production Gallery with real catalogs,
themes, and font resources across 3 locales x 3 text sizes x 2 Standard
palettes. It exited 0 with 18 of 18 requested tuples, 57,605 checks, and 19 PNG
captures. The final native Retry run exited 0 with 18 of 18 tuples, 414 checks,
and 19 PNG captures. The current title and localized Retry sets retain 38
captures for 36 tuples and 58,019 native checks. The archived historical Retry
run adds 19 captures and 18 executed tuples. Root visually inspected English
100% After-Hours and Traditional Chinese 150% Midnight captures in both current
sets. The final `zh-HK` Retry image visibly uses `安靜的清晨`; the registered font
was clear and did not overlap its measured regions.

`verify_pixels.py` is a read-only Pillow check over the archived title receipt
and PNG basenames. It verifies native status-box heights of 12, 14, and 16
pixels and proves that every box contains exactly Worn-Cream paper plus the
registered After-Hours or Midnight ink, with nonzero ink pixels. Its output is
archived as `pixel-receipt.json`.

## Archive layout

- `native-title/`: 19 title PNGs and `gallery-measurements.json`.
- `native-retry/`: 19 final localized Retry PNGs and its receipt.
- `native-retry-historical/`: 19 pre-copy-correction Retry PNGs and its receipt.
- `logs/`: terminal engine logs named by the ledger.
- `runs.jsonl`: original command, isolated roots, timestamps, and terminal
  codes.
- `verify_pixels.py` and `pixel-receipt.json`: independent archived-pixel
  verification.

## Limits and remaining work

This checkpoint does not establish the complete Gallery Standard or a full
V-conformance claim. High Contrast, colour-differentiation variants, hardware
input, assistive technology, export packaging, and current-UI dossier cutover
are outside this proof. Full Gallery chronology and cue metadata remain tracked
under `dwm-7wj`; this evidence does not close them. Native fixtures use explicit
test data and injected input where documented by their receipts.

`source-sha256.json` hashes the bounded production, font, test, manual-probe,
and generated-inventory inputs after the final runs. `sha256.json` seals every
archived artifact except itself. Archived text uses UTF-8 and LF line endings.
