# Retained contact query contracts

2026-09-14; bounded `dwm-sx8` checkpoint at base `b51946fe6a326842157a587724934fe9b7dd345b`.

Two fresh, out-of-tree GameState query tests replace exactly two missing public-contract labels. There are no production changes, persistence commands, shared-autoload mutations, or changes to the externally owned `dwm-634*` / `dwm-6fl` implementation and tests.

| Required member | Direct behavioral test |
| --- | --- |
| `get_missed_invitation_for_friend` | `test_missed_invitation_query_uses_prior_day_filters_and_returns_a_detached_record`: active-day default, explicit target, prior-day and friend filters, absent result, and a returned copy that cannot change the retained record. |
| `should_route_priscilla_lavinia_post_ending` | `test_pair_route_query_counts_canonical_distinct_windows_and_retains_legacy_eligibility`: zero/one/two distinct windows, duplicate Day 2 receipts, a non-group day, attended-solo suppression, and compatibility with already-earned legacy eligibility. |

Both tests compare detached relevant query state before/after reads and watch relevant mutation signals. The pair matrix also checks `get_counted_pair_window_count`; its existing contract mapping is retained. Receipt fixtures come from the pure `ContactInvitationState.prepare_resolve_day_end` builder, with assertions that preparation leaves the live input unchanged.

## Authority

The D+1 missed-invitation copy contract is specified in `docs/design/recovered/CONTRACTS.md`, the follow-up rule at lines 237-244. The pair matrix follows the owner-confirmed calendar-bound Day 2/Day 6 architecture in `docs/design/2026-09-02-narrative-constitution-working-decision-ledger.md`, section 2.3.1: an attended solo prevents the pair meeting, and one occurring window does not earn the pair ending. It does not promote the superseded raw missed-group counter into current law. The retained GameState query explicitly preserves already-earned legacy eligibility; that compatibility behavior is checked without exercising a restore or save path.

## Verification and limits

- New suite: **2/2 tests, 55 assertions, exit 0**.
- Final seven-suite aggregate: **39/39 tests, 1,042 assertions, exit 0**. This includes the new suite, prior public/calendar queries, GameState facade, seven-day calendar, public-surface inventory, and documentation validator. Both GUT runs report the same 24 existing Dialogic orphans.
- Both inventories regenerated with the standard isolated runner, exit 0. SaveManager inventory bytes are unchanged. GameState changes contain only the two mapped labels and references from the new test file; no previous source references were removed.
- `label-audit.json` measures missing labels across 239 current GameState rows: **159 to 157 occurrences**, still **32 distinct missing names**. Label existence is not a substitute for the behavior evidence above; the remaining gaps and `dwm-sx8` stay open.

This focused run does not rerun, repair, or supersede the eleven older Hospital/ending failures retained in `evidence/public_query_contracts/README.md`. Their source-test ownership remains excluded from this checkpoint. No claim of complete game, full-suite, save/load, or ending-playback acceptance is made.

`runs.jsonl` retains all four terminal attempts and `logs/` their normalized UTF-8 output. `source-sha256.json` identifies the queried source, pure fixture builder, new tests, and inventories. `sha256.json` seals this folder except itself.
