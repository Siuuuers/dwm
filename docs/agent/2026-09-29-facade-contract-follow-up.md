---
document_id: facade_contract_follow_up_2026_09_29
document_role: navigation_only
execution_authority: false
status_authority: false
behavior_authority: false
verification_authority: false
inspected_source: "9958c66fd345ca8c30d7114fdff4c4bb1b356ec7"
---

# Facade contract follow-up — 29 September 2026

Historical bounded increment below. The later [facade contract proof](2026-09-29-facade-contract-proof.md)
records the next fifteen mapping repairs and two query retirements, with its own
exact-source cloud receipt. Follow that record and the live handoff for current counts.

Navigation for `dwm-sx8` at source `9958c66fd345ca8c30d7114fdff4c4bb1b356ec7`. This records reviewed changes and remaining work, not cloud acceptance or closure. Check the live handoff for later results. Checkpoint performance acceptance is tracked separately in the live handoff.

The required surface contains **238 current GameState rows**. **131 still reference absent test functions across 28 distinct labels**. A name's existence alone does not establish meaningful coverage. SaveManager has 74 current rows with no absent labels; their broader behavioral completeness is a separate question.

## Bounded mapping corrections

These names identify demonstrated behavior, not exhaustive contracts.

| Symbols | Exact test | File |
|---|---|---|
| FRIEND_IDS | test_the_friend_roster_has_one_owner_and_two_aliases | [Contact state](../../tests/unit/test_contact_invitation_state.gd) |
| contact_message_unlocked, minesweeper_app_rounds_finished_today, minesweeper_task_rewards_claimed, is_contact_message_unlocked | test_gameplay_mount_uses_real_ports_and_first_reveal_persists_one_charge | [Desktop bootstrap](../../tests/integration/test_desktop_bootstrap_wiring.gd) |
| money | test_shop_purchase_saves_authored_effects_and_retries_without_a_second_charge | [Desktop bootstrap](../../tests/integration/test_desktop_bootstrap_wiring.gd) |
| coins, inventory | test_lucky_charm_purchase_transacts_exactly_once_against_real_ports | [Shop transaction](../../tests/integration/test_minesweeper_shop_transaction.gd) |
| minesweeper_round_floor | test_supportz_purchase_decrements_the_real_round_floor_and_spends_real_money | [Shop transaction](../../tests/integration/test_minesweeper_shop_transaction.gd) |
| inter_friend_route_state | test_first_count_draw_is_profile_durable_before_run_candidate_and_retry_reuses_it | [Pair draw](../../tests/unit/test_pair_deck_draw_port.gd) |
| minesweeper_rounds_left | test_restore_after_a_crash_between_checkpoint_commit_and_live_adoption_recovers_the_paid_first_reveal | [First Reveal](../../tests/integration/test_minesweeper_first_reveal_transaction.gd) |
| route_context | test_game_owner_hospital_request_is_bound_durable_detached_and_idempotent | [Hospital context](../../tests/unit/test_hospital_frozen_context.gd) |
| save_relevant_state_changed | test_prepared_restore_plan_and_installed_owner_remain_independent_until_finalize | [Restore isolation](../../tests/integration/test_run_restore_isolation.gd) |
| has_minesweeper_app_round_available, is_date_unlocked | test_sylvia_achieved_third_round_offer_uses_tier_without_granting_a_round | [Seven-day calendar](../../tests/unit/test_seven_day_calendar.gd) |
| capture_live_run_state | test_active_run_capture_and_owner_keep_independent_nested_gameplay | [Active rollback isolation](../../tests/integration/test_live_run_rollback_isolation.gd) |
| restore_live_run_state, apply_save_dict | test_active_run_rollback_keeps_independent_nested_gameplay_and_existing_publication | [Active rollback isolation](../../tests/integration/test_live_run_rollback_isolation.gd) |

The active capture/rollback tests exercise both alias directions, raw and wrapped backups, independent expected values, restoration of day 3 and money 17, and the existing single publication.

The apply_save_dict mapping covers installation within active rollback. It does not establish strict admission or detached ownership for arbitrary direct callers. Its disposition changes from a dangling replacement to retain; the other listed rows retain their dispositions.

Evidence limits:

- The roster assertion proves equal contents, not object identity or absence of duplicate declarations.
- Contact notification checks cover failure/retry counts and subsequent saved state, not callback-time disk inspection or every emitter.
- Lucky Charm substitutes causal-sequence admission and does not commit twice. Supportz stops after commit, without proving publication or lease release.
- Pair draw uses real Profile/JsonFileStorage over FakeFileOps. Hospital uses an in-memory CheckpointWriter.
- Restore signal/isolation cases contain no physical storage.
- Day7 query mappings cover the named Sylvia/zero-capacity scenario, not every friend, day or refusal.
- A production query used to calculate an expected value is not independent proof of that query.

## Retired unused candidate pair

Only GameState.prepare_run_candidate and GameState.commit_run_candidate are retired. The first copied a nonempty dictionary; the second reported success without installing it. The caller audit found no production consumer. The obsolete existence-only test is removed; live capture/rollback and saved fields remain.

Required metadata removes two obsolete rows and corrects apply_save_dict's dangling replacement. The retirement gate scans both names without exempting executable test code.

Exactly **696 historical bytes**, including the obsolete header and separators, remain in the non-executable [source-fragment artifact](../../tests/fixtures/source/game_state_retired_candidate_seams.json).

- Artifact SHA256: `a5cdc71da32cc7d6bbe2298157d63e8edda3511658b346e8536023ecd4874e82`
- Historical source: `226d3da868784baacc6fc33f58823f95b5815a51`
- Original GameState SHA256: `95073205c6016935a3fb6339f004129e0ac93cf8728e64f812a940891a27da5c`

The [provenance check](../../tests/integration/test_run_restore_isolation.gd) pins the artifact, exact fields and source identity, reinserts fragments at unique anchors, and reverses five isolation substitutions to reproduce the original whole-file hash. Four frozen method hashes remain in the [restore control](../../tests/support/RunRestoreAliasingReference.gd) and [active rollback control](../../tests/support/LiveRunRollbackAliasingReference.gd).

## Remaining work

One identified existence-only mapping remains: commit_variable_transaction → test_variable_transaction_api_is_required. It checks has_method, not admission, refusal, idempotence or custody. This is not a claim that every other existing label is behaviorally sufficient.

Review remaining rows individually. Do not substitute unrelated passing tests, setup calls, helper occurrences or default-state round trips for missing contracts. Do not broaden CI just to improve a count.

The [August11 authority](../design/2026-08-11-phase-2r-foundation-repair-current-authority.md) treats retained July plans as historical procedure unless adopted by current authority. Preserve those plans and the August8 handoff as evidence. Current requirements still govern atomic restore, typed transactions and ownership.

Other legacy APIs need caller and authority review. Live capture, rollback and apply_save_dict have active consumers; this retirement does not authorize removing them or legacy queues.

Before accepting this batch, bind cloud results to exact source/merge, verify the full retirement scan and both inventories, and require selected behavior/provenance suites to pass. Static review and prior green runs do not substitute.
