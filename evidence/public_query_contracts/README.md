# GameState public query contracts

2026-09-14; bounded `dwm-sx8` evidence at base `98966c305a52f4a70279b8e1ebc8c2d146b21dc6`.

This checkpoint replaces ten `contract_test` references on current GameState required-surface rows with names that are actually declared and directly exercise the mapped public member. Five focused query tests and three calendar-query tests use fresh in-memory GameState instances. They verify results and unchanged query state; they do not use storage or persistence writers.

| Required member | Declared contract test | Direct coverage |
| --- | --- | --- |
| `day` | `test_day_is_read_only_compatibility` | Reads Day 1 and a lifecycle-selected Day 5; the query itself does not advance the run. |
| `get_stat` | `test_get_stat_returns_canonical_internal_values_without_mutation` | Canonical internal values at representative bounds, unknown-stat neutral read, no mutation signals. |
| `get_stat_display_value` | `test_get_stat_display_value_projects_audience_bounds_without_mutation` | Pressure/health/motivation audience projections at boundaries, unknown-stat neutral projection, no mutation signals. |
| `get_stat_display_max` | `test_get_stat_display_max_returns_each_audience_scale_without_mutation` | Exact public display maxima for every stat and zero for an unknown stat, read-only. |
| `can_spend_money` | `test_can_spend_money_respects_the_exact_overdraft_boundary_without_mutation` | Positive-only requests and the exact `-30` overdraft boundary from negative, zero, and positive balances, read-only. |
| `can_spend_coins` | `test_can_spend_coins_requires_a_positive_owned_amount_without_mutation` | Rejects nonpositive and unaffordable amounts; accepts exact and lower owned amounts, read-only. |
| `is_invitation_day` | `test_is_invitation_day_covers_the_complete_explicit_and_active_day_contract` | All friends across explicit Days 1-7, active-day defaulting, invalid days/friends, read-only. |
| `is_group_invitation_day` | `test_is_group_invitation_day_covers_the_complete_explicit_and_active_day_contract` | Explicit Days 1-7, active-day defaulting, invalid days, read-only. |
| `get_daily_message_friend_for_finished_round` | `test_daily_message_query_covers_all_days_defaults_invalids_and_group_suppression` | Every Day 1-7 message position, default and invalid queries, active same-day group suppression, stale other-day non-suppression, read-only. |
| `advance_day_or_end` | `test_advance_day_resets_and_ends` | Midweek Day 3 to 4 reset and terminal Day 7 to ENDING with no Day 8. |

## Authority and verification

`docs/design/recovered/CONTRACTS.md` lines 43 and 102-106 make the retained GameState implementations authoritative for stat/economy numbers and the daily-message return contract; its Day advancement and Invitation rules sections begin at lines 185 and 214. `docs/design/recovered/CONTENT.md` owns the calendar content. `autoload/GameState.gd` is the queried production owner, and `scripts/domain/contact/ContactInvitationState.gd` supplies the validated active-group fixture. The required-surface file remains the single-script inventory defined by the Phase-2R public-surface plan; the normal generator refreshed GameState source references and exited 0. The same generator for SaveManager exited 0 and changed no SaveManager required-surface or inventory bytes.

The final run executes six suites: both new query suites, the existing GameState facade and seven-day calendar suites, the public-surface inventory tests, and the documentation validator. Result: **37/37 tests, 987 assertions, 24 reported orphans, exit 0**. The focused new-query run is **8/8 tests, 185 assertions, exit 0**. `runs.jsonl` preserves all five terminal attempts and `logs/` preserves their normalized output.

`label-audit.json` checks actual `func test_*` declarations. Across all 239 current required-surface rows, missing contract-label occurrences fall from **169 to 159** and missing unique label names from **35 to 32**. The ten-row improvement is label existence plus the direct behavior above. It is not a claim that the other 159 references, all public GameState behavior, or the `dwm-sx8` goal are complete.

## Baseline and limits

The initial unchanged three-suite baseline ended with **66/77 passing, 11 failing, 727/749 assertions, 24 orphans, exit 1**. Its existing failures are preserved verbatim in the archived log:

- `test_check_immediate_faint_requires_sequela_and_danger`
- `test_check_immediate_faint_sequela_and_low_health`
- `test_should_route_sylvia_special_ending_thresholds`
- `test_hospital_recovery_counts_sylvia_solo`
- `test_resolve_day7_sylvia_special_highest_precedence`
- `test_resolve_day7_priscilla_lavinia_primary_no_epilogue`
- `test_resolve_day7_candidate_binary_tone_sweet`
- `test_request_next_ending_command_plays_primary_first`
- `test_record_gallery_unlocks_the_primary_and_reaches_gallery_recorded`
- `test_full_with_epilogue_ending_flow_records_both_endings`
- `test_gallery_record_recovers_forward_after_a_partial_profile_failure`

The final focused aggregate does not include `test_game_state.gd`, so it does not hide, repair, or supersede those Hospital/ending failures. The SaveManager generation is a no-change compatibility check, not SaveManager behavior evidence. No production GameState, ContactInvitationState, storage, schema, SaveManager, DatingScene, or `dwm-634*` implementation is changed or claimed here. Archived text uses UTF-8, LF, no trailing whitespace, and no final newline. `source-sha256.json` records the bounded sources and generated inventories; `sha256.json` seals this folder except itself.