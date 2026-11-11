# Faster default Settings opening with prepared pixel fonts

Base: master `27155b49aeb9a3f00e517b442f445032cb98423d` (PR288).

Outcome: first Settings opening uses the same four CJK pixel fonts at the default 125% size, without runtime WOFF2 font decoding. Replace their WOFF2 files/imports with compressed Godot FontFile `.res` resources containing decoded OTF data. UiTypography remains the single path owner. Other sizes, Latin and readable fonts are unchanged. No new runtime dependency, cache or manager.

## Attribution and selection

Fresh-process Godot 4.6.3 Linux headless probes on authored Day1 found four CJK fallback loads cost 73–94 ms. Primary Latin was already loaded. Style/icon construction together cost under 0.2 ms. The earlier 163–171 ms theme/context span also included initial styling; it was not all font loading.

Raw OTF experiments improved first opening to 393–419 ms but increased four source files by about 9.4 MB. WOFF1 used less space but retained 58–64 ms of font-load cost and inconsistent whole-opening results. Compressed Godot resources retained the decoded font payload with a smaller size penalty.

Final assets total 3,220,479 bytes, replacing 1,612,148 source bytes: +1,608,331 bytes (about 1.53 MiB). This is repository asset size, not a measured full Windows ZIP delta. Original representations and their imports are removed, not shipped alongside replacements. Upstream hashes and conversion provenance remain in `assets/ui/gallery/fonts/sources.json`; OFL and upstream notices remain.

## Matched complete-operation evidence

Same probe, fresh profiles, English instant captions, default125%, Settings opened before Computer. First opening includes first Computer construction and click-helper frame waits. Order: base → candidate → candidate → base, no concurrent engines.

| Revision | First opening |
| --- | ---: |
| Base, first process | 493.209 ms |
| Candidate, first process | 394.443 ms |
| Candidate, second process | 390.663 ms |
| Base, final process | 540.420 ms |

Median 516.815 → 392.553 ms, about124.3 ms /24% lower in this small matched cloud sample. Later openings remain around52–63 ms and are not the target. These are headless elapsed times, not rendered Windows frame measurements. PR287's close-time trim remains unchanged.

## Data and verification

FontTools conversion uses `TTFont(..., recalcBBoxes=False, recalcTimestamp=False)` and `flavor=None`. An initial exploratory conversion used defaults and recalculated the global font bounding box; it was corrected before the final comparison and acceptance. Final decoded tables match every original table byte except `head.checkSumAdjustment`; timestamps, bounding boxes, glyph outlines, metrics and font names match. Counts: zh_hant24804, zh_hans24803, ko24932, ja24805 glyphs.

The decoded bytes are stored in FontFile resources using Godot4.6.3 and `ResourceSaver.FLAG_COMPRESS`. Pixel settings remain no system fallback, antialiasing, hinting or subpixel positioning, with oversampling1. A preliminary copied-import resource needed these settings normalized before final save; all final resources were checked directly as well as through UiTypography.

- Gallery typography: 3 tests /9742 assertions.
- Japanese/Korean UI: 8 tests /3038 assertions.
- Final candidate authored open/close probes: 2 ×52 assertions.
- Total final GUT acceptance:12884 assertions, all passed.
- Four direct-resource font-table comparisons passed.
- Isolated resource-only PCK: dependencies empty; all four FontFiles load with exact embedded SHA256 and rendering settings, without original fonts or editor import files. This is a resource-package check, not a full Windows game export. An initial pack creator ran within the game's autoload context and logged an unrelated preload error at shutdown; rerunning both creation and load from an isolated minimal project passed cleanly.
- Independent caller/reference/provenance review found no blocker. All15 selected font files match declared sizes/hashes. No retained runtime/test paths or UIDs reference removed imports.
- `git diff --check` passes.

## Reproduction and limits

Evidence: `tools/player_latency/evidence/2026-11-12-settings-font-resources/`. Includes instrumented and uninstrumented experiments, final ABBA logs/XML, font equivalence hashes, packed check and scripts. Use fresh run labels. To compare base after removal, use an isolated checkout of the recorded base with its original fonts. The archived comparison runner assumes both representations are present during the experiment and restores candidate source in `finally`.

For conversion, obtain the original four files from the recorded base or pinned upstream archive; verify original hashes in sources.json, decode with both FontTools recalculation flags disabled, then use the archived FontFile save routine. It expects exact OTF inputs under `.godot/ci/settings-open/` and existing output resources as rendering-property templates. Do not use the earlier default conversion as the final artifact.

Skipped: broad gameplay/save suites, full-week replay, Windows rendering/full export and a new lint rule. Typography coverage is directly relevant because shared125% fonts also serve Gallery and localized UI. No claim about 100%/150% performance. Next larger remaining cost is Settings node/control construction and first layout; investigate only against matched whole-operation timings.
