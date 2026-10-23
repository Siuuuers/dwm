# Shop and New Account failure triage — run39837646584

Candidate d1d8313cff343a46733c021ad9125d6c0702eeff; tested merge3b171dbb60f6edc9cd267e6244f786893b146e76. Read-only triage; no product edits, runtime execution, or changed acceptance.

## Original Shop evidence

Job120033199686 failed. Artifact12452890354 (`windows-shop-39837646584-1`) downloaded as `triage-shop/shop-original.zip`:59773bytes, SHA2568369c3f97db728018edde1c53139f5b82a497119a224eec6d045f71bb1fd1fd4. Provider digest and ZIP CRC verified, four files extracted. XML has146cases:112pass/34fail, no inference from summary-only logs.

| Suite | Cases | Failed |
|---|---:|---:|
| shop_app_purchase_bridge |13|0|
| shop_catalog_projection |8|0|
| shop_presentation_port |12|0|
| shop_card |16|2|
| shop_plate |37|15|
| shop_desktop_host |15|13|
| minesweeper_shop_transaction |4|4|
| minesweeper_shop_purchase_participant |41|0|

## Safe bounded UI fixture repair

Current ShopCatalogProjection explicitly owns13ordered slots/12product rows: wine,pineapple_bun,quiet_tea,soft_blanket,weighted_plush,spa_coupon,Supportz(blank),premium_care,lucky_charm,debug_key,bookend_keepsake,metronome_keepsake,pocket_calculator_keepsake. Its unit fixture already reflects this catalogue and all8tests pass.

Scene/Desktop fixtures still assume18slots/17rows and reference retired coffee,bandage_pack,healthy_meal,protein_box,pep_note. Card first-row expectations say Coffee/$20 but actual canonical row is Wine/$55; another case indexes17. ShopPlate hardcodes old counts, Supportz index8, old selected IDs and geometry/navigation positions. DesktopHost's independent ORDER/SPECS still emits17rows, so production projection refuses invalid_item_count; all later empty-window/card errors cascade from that refusal.

Minimal justified change: update these three UI fixture files to the explicit current catalogue, surviving stable IDs and their real prices/currency/batch semantics. Preserve every navigation, focus, admission, failure, locale and pointer assertion; adjust expected grid positions for the same fixed geometry and13slots. Do not derive all expectations dynamically from production (would hide regressions), restore retired products, reduce cases, or skip them. Re-run these suites plus canonical projection/presentation tests in cloud. No architecture question is needed for this fixture update.

## Real production adapter mismatch (not merely stale tests)

The four transaction cases buy still-supported lucky_charm/debug_key/Supportz through real ports. All fail inside `MinesweeperShopPurchaseParticipant._build_action_receipt`, line780, before checkpoint/admission, on `facts["health"]`. Current `GameStateMinesweeperShopPort.capture` returns pressure/carried_sequela but deliberately omits health after retirement. `_prepare_ordinary` and note preparation likewise emit pressure-only condition_after. Participant unit tests use FakeMinesweeperShopStatePort which still supplies health, so41passing unit cases mask the concrete production composition mismatch.

This cannot safely be solved by deleting the receipt's health field or substituting0:

- `DesktopActionReceipt` is frozen schema1 with exact condition keys health/pressure/carried_sequela and includes those bytes in receipt fingerprints/child provenance.
- `DesktopConditionPolicyPort.evaluate` uses health<=0 with pressure and carried_sequela to decide Hospital/departure.
- `DesktopConsequenceSourcePort`, Day7ConditionEndingSource and DesktopContinuationRemapper still consume/validate health.
- DesktopConsequenceState, publication ledger, retained transaction/recovery records and source checkpoint identity carry those authenticated receipts. Rewriting historical receipts changes hashes and custody.
- Bootstrap still constructs the legacy participant/condition pair for retained desktop paths. `ShopApp.configure_scene_catalog` has no current production caller (only test_scene_app_preparation); this is not evidence that a scene-native pressure-only purchase pipeline already exists.

A minimal safe runtime hardening is to reject missing or malformed legacy condition facts before indexing them, before acquiring the causal transaction lease or writing a checkpoint, with a specific unsupported-legacy-condition result. Test refusal leaves currency/inventory/consequence/lease/checkpoint unchanged. This prevents a script error but does NOT qualify successful current Shop purchases or satisfy the four historical success obligations. Do not relabel this as a completed purchase fix.

Enabling successful pressure-only purchases needs a scoped owner decision: a scene-native receipt/consequence contract with explicit version dispatch while preserving legacy schema1 recovery, or an explicit retained-only boundary. That is broader than this test fixture maintenance. No patch inventing new schema semantics is proposed here. Existing retirement authority must not be undone to turn CI green.

## New Account historical Schedule vector failure

Job120033199657's observed failure is `test_phase2r_schedule_gate.gd::test_observed_vectors_for_the_day3_hospital_walk_with_two_superseded_dates`: `unknown_effect_id`, `health:+1`, before hospital_if_triggered. This does not demonstrate a New Account runtime regression; new_account suite includes a large historical Schedule evidence gate.

The test uses real current REGISTRY.load_current and current GameState, commits a Day3 Rest entry and walks every prior stage. GameStateDayResolutionPort._begin_ordinary_action_substage takes effect IDs from the persisted route_plan and calls GameState.commit_effect_transaction. Current EffectResolver deliberately rejects health/motivation; test_effect_resolver expressly tests that refusal. Therefore the retained registry's Rest health:+1 cannot execute under current owner. Handoffs a-exported-gameplay-20261018, a-gallery-rehearsal-20261018 and a-public-inventory-20261017 already classify this unresolved retired-system obligation and prohibit reviving health effects.

Changing Rest to Working, dropping effects, or replacing sealed vectors would alter the historical proof and is not a routine fixture correction. Preserve `evidence/phase_2r/schedule/gate.json`, original source/registry seals, and parser/tamper batteries. Decide the evidence boundary explicitly: authenticate/reproduce historical vectors on a frozen test-only historical substrate, or retain immutable historical proof while adding an honest current refusal/retirement test. Neither option may claim current Hospital gameplay or reuse the old observed-green count as fresh acceptance. No production health restoration or historical resealing is justified.

## Limits

New Account diagnosis used retained last50KB job log plus exact source; full New Account archive not downloaded in this triage. Shop original archive was inspected. Other CI suites may expose adjacent legacy mismatches; this report does not assert they share one fix or that broad CI is accepted.
