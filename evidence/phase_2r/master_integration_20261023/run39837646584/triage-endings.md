# Ending CI failure triage — run 39837646584

Read-only source/evidence review against source `d1d8313cff343a46733c021ad9125d6c0702eeff`, tested merge `3b171dbb60f6edc9cd267e6244f786893b146e76`. No engine/PowerShell, runtime edits, remote writes, or acceptance occurred in this triage. An isolated test-only patch proposal is prepared separately at the coordinator's request.

## Original evidence

| Job / artifact | Verified original ZIP | Finding |
| --- | --- | --- |
| Windows endings job120033199624 / artifact12452725538 | 91,340 bytes; SHA256 `26354bcc33b0efaa662eb314349472d3da5ca9c0ab3b3113f2949ca4b5aa0328`; 4 members; CRC valid | XML has169 cases,21 failing cases in6 scripts; 148 other cases pass. |
| Rendered ordered ending job120033199488 / artifact12451432793 | 30,863 bytes; SHA256 `c99de6aebd74cc7b42f8d56ee3b1b4c5d7a200633f1393120e7856e3c1946c79`;14 members; CRC valid | Write process exits1 after13.692 seconds at combined startup/catalogue injection check. No Save slot, autosave, or quicksave exists; read phase not executed. |

Original archives and extracted bytes: `ending-triage-artifacts/`. Digests match provider artifact metadata. Path traversal checks preceded extraction.

## Unit/integration failures and bounded corrections

| Script | Cases / failing cases | Cause / proposed correction |
| --- | ---: | --- |
| test_gallery_version_register.gd |9 /8| Legacy Alone versions pass signature validation but default physical catalogue cannot resolve their old entries under selected scene registration. Inject bounded test-only physical catalogue into replay owner. |
| test_gallery_navigation.gd |11 /2| Same availability loss; do not weaken navigation/focus expectations. |
| test_gallery_replay_status.gd |6 /5| Same availability loss means Replay never starts, so downstream expected Error/Retry/focus behavior cascades. |
| test_gallery_record_metadata.gd |3 /2| Same availability loss hides exact version metadata and media. |
| test_gallery_art_placements.gd |3 /1| Same availability loss prevents selecting normal/dark versions. |
| test_ending_frozen_context.gd |6 /3| Explicit legacy ending entries are absent from the selected scene context registry; FROZEN.build fails `frozen_context_unknown_entry`, subsequent `.value` use cascades. Reuse existing RetainedFrozenContextFixture for the3 affected cases only. |

`DialogicEntryManifest._select_startup_fixture` now always selects shipped `scene_story_registration.json` unless the explicit debug fixture is selected. `FrozenPresentationContext._load_registry` prefers that registration. `DialogicTimelineCatalog._ensure_entries` also loads the selected entry manifest. Those behaviors are intentional current-story ownership; changing their default or adding production legacy fallback is not justified.

`PresentationSignature.entry_record` remains a separate historical signature vocabulary, so old profile signatures can be recorded while physical replay is unavailable. `GalleryReplayOwner.get_variants` correctly refuses unavailable physical entries through its `_entry_catalog`. The proposed Gallery patch changes only that dependency in synthetic layout/replay-status fixtures. The existing accepted `tests/ui/render_gallery_version_register.gd` already uses precisely this bounded test pattern: only `ending.alone.normal` and `ending.alone.dark_mode`, only locale `en`, exact retained `res://dialogic/timelines/en/ending/alone.dtl`, unknown ID/locale refused. Unreached Priscilla/Sylvia discovery records in these tests remain unreached; no fallback or permissive suffix mapping is added.

The retained context helper is already in source and validates explicit entries against historical declarations. It restores exact prior cache objects. Do not install a legacy-only cache for the entire ending suite: that could obscure current scene schemas used by already-passing owner tests. The proposed patch installs only each failing case's required IDs and restores afterward.

## Isolated patch proposal

`ending-proposal/ending-fixture-maintenance.patch` changes6 existing test files and adds one10-line `tests/support/GalleryEndingFixtureCatalog.gd`. Exact files listed in `ending-proposal/files.json`; hashes/test census in `static-validation.json`.

All38 existing test names in the affected6 scripts remain. No behavioral expectation is deleted or relaxed. All requested retained schemas and the physical Alone DTL exist at the pinned source. Runtime, shipped registration, historical seals and existing RetainedFrozenContextFixture are unchanged. Gallery dependency injection occurs after configure_replay and before scene mount; no live catalogue mutation. Cloud parser/execution qualification is still required, with exact38-case census and all existing assertions. The newly factored test catalogue retains the closed mapping of the already-qualified renderer; static parity is not new cloud acceptance. Canonical inventories need regeneration after integration.

## Rendered ordered ending is a distinct unresolved fixture composition

Actual retained failure is only `ENDING_READING_FAIL: production startup and explicit ending fixture injection`, a compound check at `verify_ending_reading_journey.gd`. It does not identify which operand failed. Static source reveals multiple independent incompatibilities:

1. Current Bootstrap `_configure_registered_scene_runtime` installs the shipped ending reading catalogue in normal startup. `DialogicBridge.configure_reading_catalogue` refuses replacing a nonempty catalogue with a different one. The legacy probe attempts to install `EndingReadingFixture.catalogue()` after startup. A `reading_catalogue_already_configured` refusal is therefore the expected source-level cause when startup is ready; this exact code was not separately logged by the compound assertion.
2. `EndingReadingTimelineCatalog.get_entry` delegates first to the current production entry catalogue, then rewrites paths only if resolution succeeded. Current selected registration lacks `ending.sylvia.special.full` and `ending.sylvia.dark`, so the test override cannot supply those entries. A closed explicit fixture catalogue is needed; production fallback would be wrong.
3. `SoloReadingSession._ending_entry` requires FrozenPresentationContext schemas for those entries. Explicit retained schema scope would be needed as well.
4. The probe starts a real New Account and waits for old ComputerDesktop/day1 before manually seeding a two-step legacy EndingPlan. Current Bootstrap configures scene title NewRun and SceneHost. Thus bypassing catalogue failure alone cannot establish the old fixture journey.

Do not count the Gallery/context patch as repairing this rendered journey, change production to legacy defaults, or remove the old boundary/Save/Load assertions to obtain green. A next diagnostic should split the combined admission check into retained exact receipts. Then choose a deliberately test-only composition of retained ending owners, or an explicitly specified current-scene replacement journey carrying the same physical boundary and fresh-Load obligations. The seven-file handoff already qualifies a current single ending path, but not this old two-step physical-boundary case. Merely substituting that existing pass would lose this obligation.

No user-level narrative choice is inferred here. The engineering question is how the retained ordered-ending proof is hosted under current scene startup; current story defaults and old saved evidence must remain intact.
