# Retired development-phase and ineffective tests

Decision: 10 November 2026. Baseline: `490e36a10796371ac54766de46522c9cff1ae110`.
The owner approved retiring these three tests and narrowing compact-History setup.
No runtime behavior or test comments outside the removed methods change.

## Missing generator artifacts

From `tests/unit/test_minesweeper_board_generator.gd`:

- `test_begin_debug_returns_generator_budget_unavailable_while_the_budget_manifest_is_absent`
- `test_run_debug_slice_returns_generator_budget_unavailable_while_the_budget_manifest_is_absent`

These checked unavailable-budget behavior before generated artifacts existed.
Both now immediately skip with zero assertions because the budget and fallback
manifests are committed. The baseline narrow run confirmed two pending tests and
zero assertions. Production missing-manifest handling remains unchanged.

Current shipped-artifact coverage remains in
`test_both_generated_manifests_exist_and_pass_their_own_schema_validators`,
`test_validate_budget_freshness_accepts_the_real_fallback_manifest_digest`, and
`test_begin_debug_and_run_debug_slice_reach_certified_against_the_real_beginner_difficulty`.
These cover shipped artifacts and successful generation, not the intentionally
retired absent-file scenario. No new fault-injection scenario replaces it.

## Ineffective check-mode assertion

From `tests/unit/tooling/test_desktop_amendment_evidence.gd`:
`test_check_mode_never_opens_either_target_for_write`.

The test loaded the script before capturing its baseline, then read the same file
twice without invoking check mode between reads. Its byte/mtime assertions never
proved check-mode write behavior. Script-loading coverage remains in
`test_evidence_classes_generator_and_schemas_exist`; no claim is made that this
retirement establishes actual no-write coverage elsewhere.

## Compact-History setup

`compact_history_restore_child.gd` uses the existing authored setup cutoff:
creation prepares through Day2 (six entries), while Load prepares through Day1
(one entry). The full registration and English catalogue remain available.
All real caption, Save/Load, bounded-History and global-discovery assertions stay.
The former 28-entry setup compiled unvisited route entries in both phases.

No deleted method has a runner reference. The three retired tests belong to
historical suites, so their removal is housekeeping, not a normal-CI speed claim.
Focused results are recorded in the implementation PR. Broad matrices, Windows
qualification and performance claims are outside this slice.

Verification: the baseline create/load pair passed with 3,792/101 assertions;
the narrowed pair passed with 3,748/47. The 98 removed assertions belonged only
to setup for unvisited entries. Four retained artifact, freshness, generation and
script/schema checks passed with 8/1/8/8 assertions. Independent diff review found
no issues; `git diff --check` passed. These are focused Linux headless results,
not Windows/rendered qualification or a measured speedup.
