---
document_id: facade_contract_proof_2026_09_29
document_role: navigation_only
execution_authority: false
status_authority: false
behavior_authority: false
verification_authority: false
inspected_source: "d6896d7d6c00390b05b4c0cf59e17a37b2fc2419"
inspected_tree: "fac82dbe728dff43a3b3d570ab60cee9e95346df"
---

# Facade contract proof navigation — 29 September 2026

This records the bounded continuation of `dwm-sx8` from records head `955e0bfb449eac0829388ee4ba0ff7e20938bcae`: **15 corrected contract mappings and two retired unused queries**. It is navigation for source and evidence, not a new authority or a claim that the parent task is complete. Read the [live handoff](2026-09-23-next-session-handoff.md) for accepted results and the next source head. The [earlier follow-up](2026-09-29-facade-contract-follow-up.md) preserves the preceding restore-isolation and candidate-retirement work.

At the inspected source, the required manifest has **236 current GameState rows; 114 mapping occurrences still name absent test functions across 28 distinct names**. This changes the previous 238 / 131 / 28 by correcting 15 mappings and removing two obsolete rows. An existing test name does not by itself establish adequate behavior coverage. SaveManager's wider behavioral completeness is not established by this increment.

## Exact mappings

These are existing behavioral tests, run through five unchanged selected suites. The only test-code change preserves historical-source reconstruction after retirement. The retained rows keep their existing `retain` or `replace` disposition and replacement text.

| Symbols | Exact test | Source |
|---|---|---|
| `stats` | `test_restore_after_a_crash_between_checkpoint_commit_and_live_adoption_recovers_the_paid_first_reveal` | [First Reveal transaction](../../tests/integration/test_minesweeper_first_reveal_transaction.gd) |
| `friend_attitude` | `test_offer_freezes_generation_facts_and_missing_history_is_not_recreated` | [Contacts frozen context](../../tests/unit/test_contacts_frozen_context.gd) |
| `dating_route_state` | `test_terminal_profile_ahead_replays_frozen_effect_once_after_checkpoint_retry` | [Dating attempt runtime](../../tests/unit/test_dating_attempt_runtime.gd) |
| `missed_invitations` | `test_prepared_restore_plan_and_installed_owner_remain_independent_until_finalize` | [Restore isolation](../../tests/integration/test_run_restore_isolation.gd) |
| `daily_opened_contacts` | `test_retiring_solo_interactions_preserves_tone_mastery_and_destination_gates` | [Canonical dating mastery](../../tests/unit/test_canonical_dating_mastery.gd) |
| `set_stat`, `change_money`, `finish_minesweeper_app_round`, `apply_minesweeper_money_reward`, `check_and_claim_minesweeper_task_rewards`, `unlock_contact_message_after_minesweeper_finished` | `test_gameplay_mount_uses_real_ports_and_first_reveal_persists_one_charge` | [Desktop bootstrap wiring](../../tests/integration/test_desktop_bootstrap_wiring.gd) |
| `try_spend_money`, `change_minesweeper_round_floor` | `test_supportz_purchase_decrements_the_real_round_floor_and_spends_real_money` | [Shop transaction](../../tests/integration/test_minesweeper_shop_transaction.gd) |
| `try_spend_coins`, `add_inventory` | `test_lucky_charm_purchase_transacts_exactly_once_against_real_ports` | [Shop transaction](../../tests/integration/test_minesweeper_shop_transaction.gd) |

The [required manifest](../../evidence/phase_2r/runtime/game_state_required_surface.json) and generated [GameState inventory](../../evidence/phase_2r/runtime/game_state_surface.json) carry these mappings. Remaining generated GameState differences are caller-line shifts and two reconstruction string literals counted lexically as call sites, not new executable callers. The [SaveManager inventory](../../evidence/phase_2r/runtime/save_manager_surface.json) retains 74 records; only four GameState caller-line locations change. Exact final inventory SHA256 values are GameState `23d43604951254a65baa9c5fdcd2cf34b1399cce6dce6c1e16eda00cf91003b8` and SaveManager `b3d04e0b66b29ee45b84151418db21cf280247759fdf3279ed1f476519f5ddef`.

## What the mapped tests establish

- **First Reveal:** a checkpoint lands before an injected failure of live adoption. Disk contains motivation 6 and one remaining round while live values are still 7 and two; restore adopts the paid state, and retry cannot charge it again. The `stats` mapping is this specific motivation recovery contract, not every statistic or mutation boundary.
- **Frozen Contacts attitude:** a real GameState's saved gameplay supplies `seen` to a generated offer; later `hostile` gameplay does not rewrite that retained context. Missing historical context is not fabricated. This tests the presentation read/freeze boundary, not every attitude writer.
- **Dating state:** the real physical owner and Profile storage over FakeFileOps retain a terminal effect ahead of a refused checkpoint. Retry installs its receipt and one date count; rebinding cannot apply it again. The checkpoint writer is injected, and board preparation uses deterministic test generation. This is not a disk restart or a complete relationship-policy proof.
- **Missed invitations:** independently mutated nested records cannot cross the prepared-payload/live-owner boundary in either direction; installation stays silent until finalization. This is ownership and publication evidence without physical storage.
- **Day 7 invitation reading:** actual GameState ending planning refuses a selected unread invitation even when mastery exists, and independently checks tier, tone, destination and missing mastery. The fixture supplies committed Schedule entries and Profile lookup injection, so it does not prove the Schedule commit transaction.
- **Desktop completion:** mounted production ports perform a coffee purchase, first-Reveal charge, terminal failure/retry, actual exploded and no-flag completions, disk-state checks, task claims and replay without a second reward. These are indirect calls through the production owner graph, not proof that arbitrary direct callers of the legacy functions satisfy transaction admission or custody. Reward and clamp expectations partly reuse production queries; they do not independently prove reward tables or `get_stat_min`/`get_stat_max`. Notification assertions cover failure/retry counts and subsequent saved state, not callback-time disk inspection or every emitter.
- **Shop:** Lucky Charm preparation is silent, commit spends one coin and grants one item, and publication reaches the real ledger and releases custody. The test does not call commit twice despite its name. Supportz commits a 45-money charge and one floor decrement; it stops before publication. Both fixtures substitute causal-sequence admission. Neither proves every refusal or the complete production admission/recovery path.

## Two superseded queries

Only `GameState.get_minesweeper_safety_level` and `GameState.should_warn_minesweeper_before_schedule_done` are removed in this continuation. Caller review and the executable retirement gate are required together: generated inventory call lists alone omit unqualified internal references and are insufficient removal evidence.

The [approved desktop amendment](../design/2026-08-11-desktop-minesweeper-shop-schedule-amendment.md), sections 7.1 and 13.1, explicitly replaces scalar safety that lets Debug Key override Lucky Charm with composed capabilities. [MinesweeperCapabilityRules](../../scripts/domain/minesweeper/MinesweeperCapabilityRules.gd) reads registry-owned capability sets and composes zero-cell and no-guess behavior. Removing the unused scalar helper does not change that current owner.

Sections 10 and 13.1 replace the old single Minesweeper-before-Schedule predicate with the ordered Days 1–6 warning queue over the detached uncommitted view. [ScheduleWarningPolicy](../../scripts/domain/schedule/ScheduleWarningPolicy.gd) selects unread invitation, accepted date, then base Minesweeper using the exact fingerprint and consumed receipts. [GameStateScheduleWarningContextPort](../../scripts/application/schedule/GameStateScheduleWarningContextPort.gd) assembles current owner and board facts for that view through the retained `capture_schedule_warning_state` facade. The obsolete query inspected committed entries and could not represent the current pre-Done view contract. See also [Schedule requirements](../../prompt_docs/requirements/schedule.md), `req.schedule.state_models` and `req.schedule.warning_queue`.

The [August 11 authority reconciliation](../design/2026-08-11-phase-2r-foundation-repair-current-authority.md) keeps historical plans as procedural evidence unless adopted by current authority. This cleanup does not promote historical plans, tests or provisional relationship mechanics into new authority. No queue, save field, compatibility policy or current owner is retired with these two methods.

Exactly **1,378 retired method bytes**, plus both versions of the adjusted nearby comment, remain in the non-executable [query fragment artifact](../../tests/fixtures/source/game_state_retired_query_seams.json), SHA256 `9c896f9f868f5d3b7d4fcbc59c4db013ba626284974d428a440e54cc174fe442`. The extended restore provenance check validates its exact fields and unique anchors, reinstates these fragments and the earlier retired candidate pair, and reverses the five prior isolation substitutions to reconstruct historical GameState source `226d3da868784baacc6fc33f58823f95b5815a51`, SHA256 `95073205c6016935a3fb6339f004129e0ac93cf8728e64f812a940891a27da5c`. This preserves the frozen negative control instead of weakening its source binding.

The [public-surface gate](../../tools/testing/Invoke-PublicSurfaceValidation.ps1) now checks ten retired names across `autoload`, `scripts`, `scenes` and executable tests. Non-executable historical source artifacts remain evidence. Static review and provenance reconstruction do not substitute for cloud execution.

## Accepted cloud evidence

Final source is `d6896d7d6c00390b05b4c0cf59e17a37b2fc2419`, tree `fac82dbe728dff43a3b3d570ab60cee9e95346df`. [Run74](https://github.com/Siuuuers/dwm/actions/runs/36519455086) passed **six jobs, 1,107 cases across 85 unique scripts, zero skips**. All six actual checkout logs name that source; the auxiliary workflow head `f7070d5998dadf8f6c1f5c531fc1f728f031fad4` is a different commit and is not the tested checkout. Its only source delta is the scoped workflow, whose two job bodies match the existing definitions except explicit checkout refs and matrix selection. The main PR workflow stays unchanged.

| Suite | Passed cases | Scripts |
|---|---:|---:|
| Public surfaces | 11 | 1 |
| Settings | 288 | 25 |
| Persistence | 183 | 19 |
| Shop | 144 | 8 |
| Desktop | 319 | 20 |
| Dating | 162 | 12 |

The public gate verifies ten retired names over 925 executable source files with zero references, then reproduces both canonical committed inventories without regeneration. All five restore-isolation and three active-rollback cases pass. The [retained receipt](../../evidence/beads_cloud_review/facade-contract-run74.json) includes every selected script, checkout evidence, log hashes, exact mapping deltas and replay instructions. Root and independent source/inventory review found no blocker. This is focused acceptance, not a new full 18-job, PR-merge, benchmark or rendered-journey result.

The initial three-mapping [run 36517901665](https://github.com/Siuuuers/dwm/actions/runs/36517901665) passed 492 cases across 33 scripts, but is superseded and does not accept the later 12 mappings or retirements. The inventory-generation [run 36519025775](https://github.com/Siuuuers/dwm/actions/runs/36519025775) used source `a0b16752a422238789a1b7fd405871163ce1e851`; it is generation evidence, not acceptance of the final source. Earlier Run71 evidence continues to describe its own source only.

## Remaining review candidates

`dwm-sx8` remains in progress. Potential follow-ups are the existing relationship-policy, day-resolution and Schedule-preservation suites. They are **unselected and unverified for a new increment**: inspect current bodies and authority before proposing mappings or targeted execution. Do not broaden CI merely to reduce the missing-label count.

Legacy mutation functions retain active internal callers; a `replace` disposition is not proof that their replacement has occurred. Continue caller and ownership review before removal. Save fields and legacy queues may still carry load/recovery obligations even without an obvious direct consumer. Broad signal labels remain a blind spot: count checks after a transaction do not establish every emitter, callback-time durable state, silence under all failures or detached signal payloads.

`commit_variable_transaction` still maps to an existence-only assertion. The test named `test_variable_transaction_commits_registered_value_once` actually asserts refusal of an unregistered variable; it must not be cited as successful commit or idempotence evidence. Preserve these limits rather than substituting unrelated passing tests. None of these candidates authorizes a new architecture or closes the parent task.
