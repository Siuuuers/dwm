# Additional broad CI triage

Run: 38725742391. Read-only source/log diagnosis; no engine execution, edits to project source, or dispatches. Baseline comparisons use 3ae6d9138fb53c388380c78550cf6082eafc0ea3.

| Job | First concrete failure | Diagnosis and justified next step |
| --- | --- | --- |
| Localization 116392942076 | tests/unit/test_japanese_korean_ui.gd:48, test_both_catalogs_cover_all_308_source_ids_and_exact_placeholders: actual 310, expected 308 | Test and all UI catalogs byte-identical to baseline. English/Japanese/Korean each contain 310; added IDs are scene.controls.check_computer and scene.controls.close_computer. Correct test name/count and explicitly assert those two required IDs, retaining existing per-ID translation/nonempty/placeholder checks. Job finished 154 tests, 25342/25343 assertions. |
| Day7 producer 116392941795 | tools/testing/derive_save_admission_baseline.py:59: Expected 3 current-source admission anchors | Tool unchanged; baseline and current SaveManager have only 2 occurrences of the Admission already returned the validated, detached document comment. Failure occurs before benchmark starts. Do not merely lower expected count: locate the removed third operation and re-establish complete paired-operation equivalence before changing baseline derivation. |
| Rendered desktop 116392941709 | tests/ui/render_desktop_scaling.gd:448: dictionary key 1 absent | Test and scripts/ui/ComputerDesktop.gd unchanged from baseline. LABELS[locale] is keyed by app ID. Use LABELS[locale][&"contacts"] for intended unread-marker/plain-caption assertion. Further independent stale Shop fixtures prevent calling this job fixed. |
| Shop 116392941996 | tests/scene/test_shop_card.gd:43-46 expects Coffee/$20; actual Wine/$55 | Test and canonical fixture owner tests/unit/test_shop_catalog_projection.gd unchanged. Fixture now starts Wine/$55 and has 12 ordinary rows; old consumers still use Coffee, index 17, 17 cards, retired IDs. Update expectations against approved current catalog and select IDs explicitly; retain geometry, accessibility, public-copy, blank-target and purchase guarantees. Do not restore retired catalog entries. |
| Performance 116392941616 | tests/manual/benchmark_minesweeper_click_latency.gd:303: PLAYABLE_STARTUP_FAIL: app first reveal accepted | Baseline-zh-CN child exited 1; timing comparison never completed. Benchmark and MinesweeperPanelPort/RoundCoordinator unchanged, but state/checkpoint dependencies changed. Unresolved regression status. Need instrumented cloud execution exposing underlying board-owner refusal before changing behavior. |
| Rendered journeys 116392941683 | All 6 journey children fail first Reveal with minesweeper_panel_command_refused | Same unresolved first-Reveal family; cannot classify by unchanged public port alone. Cases: condition-hospital-dialogue-retry; seven-days-ending-gallery; seven-days-condition-ending; dating-reload; practice-empty-dtl; practice-legacy-compatibility. Keep these as merge blockers. |

## Additional rendered-desktop and Shop blockers

- tests/ui/render_desktop_scaling.gd:314 references retired protein_box; line 283 uses out-of-range catalog index 12 and assumes lucky_charm; line 328 expects 17 cards rather than current 12. Result 36/38 captures. Use live registered IDs and locate lucky_charm by ID; maintain page-two, sold-out, contrast, hover, scrolling and absence-of-blank-target coverage.
- Same job UI-literal audit fails unchanged sources: scripts/ui/ComputerDesktop.gd:1045 localized fallback expression, scripts/ui/SceneHost.gd:82 conditional localization key, scripts/ui/pause/PauseSurface.gd:89 literal Back. First two need narrowly justified audit recognition; Back needs actual localization treatment. Do not broadly whitelist text sinks.
- Shop scene tests also access cards.coffee in tests/scene/test_shop_plate.gd:54,87,161,225; file unchanged. Numerous later failures were not independently qualified.

## Evidence boundary

Baseline above means bytewise source comparison against 3ae6d913, not baseline execution. No claim that whole Shop/rendered suites become green after fixture corrections. First-Reveal underlying refusal is intentionally unresolved: the unchanged public panel collapses failures to minesweeper_panel_command_refused, so logs do not establish the failing inner guard or PR causality.

## Follow-up: first-Reveal scene-family mismatch

Coordinator-supplied candidate diagnostic reports FIRST_REVEAL_OWNER_RESULT invalid_base_snapshot_input with legacy committed_schedule/dating and missing scene. This supplements source diagnosis; baseline cloud execution was still pending at this review.

The approved docs/design/2026-10-09-scene-runtime-integration-seam.md already resolves the architecture direction:

- Lines 25-38 require explicit Run9/Save9, retained discriminated historical families, normal host route scene, and no synthesized dating/committed_schedule/schedule_view.
- Lines 70-83 retire Health/Motivation/calendar/Hospital state, preserve desktop round accounting, and explicitly require DesktopFirstRevealSnapshotComposer's exact scene input and candidate {transaction_id,rounds_left,starts_today}.
- Lines 89 and 204 preserve authenticated scene input/route admission and existing builder/checkpoint owners. A route string alone cannot certify content or custody.

Current scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd follows the specified exact key set. GameStateDesktopBoardPort.capture_base_snapshot_input forwards the real GameState capture, without conversion. autoload/GameState.gd:3295 selects scene capture only when the real lifecycle contains scene_assignment; otherwise it returns historical dating/committed_schedule shape. The diagnostic therefore identifies incompatible family setup at this boundary.

The current benchmark calls title NewAcc without installing a scene registration. ApplicationBootstrap._configure_registered_scene_creation returns success without configuration when scene registration is absent. Existing scene test fixtures instead install a registered TEST programme and create an authenticated scene NewRun.

Smallest justified next correction direction: construct a focused connected scene fixture with real scene NewRun, retained desktop owners and first-Reveal/payment persistence, using replaceable TEST story content. Do not revive seven-day/Hospital or fabricate scene fields in the captured legacy input. Do not weaken composer or Run/Save schema. Keep old diagnostic results retained and explicitly supersede obsolete journey expectations only with coverage of surviving guarantees.

A concrete next dependency is SaveManagerDesktopBoardPort.prepare_checkpoint: it currently hardcodes route_id=main, dialogic_checkpoint={}, active_app_id=null, content_version=1. Merely feeding the composer scene input will not complete valid scene persistence. Its scene branch must obtain genuine current checkpoint/route/active-app/content context from existing authorized owners/providers, preserve scene host/frontier identity while Computer is open, and continue delegating to the existing SaveManagerCheckpointPort. Preserve historical variant behavior explicitly; do not infer authority from an optional scene key or relabel legacy input.

No new product architecture choice is needed for this direction: the approved seam specifies it. Exact provider wiring and recovery tests are implementation investigation, and successful cloud execution remains required. No source edit or engine test was performed in this follow-up.
