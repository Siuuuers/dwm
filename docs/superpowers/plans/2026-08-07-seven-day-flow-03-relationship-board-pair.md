# Seven-Day Flow Phase 03: Relationship, Board, Promotion, and Pair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the hidden relationship axes, real Minesweeper-derived dating outcomes, terminal post-clear special mine, fixed promotion valves, pure P–L observation boards, and run-stable unseen-first pair deck.

**Architecture:** A deterministic board component owns cells, mines, metrics, and hidden explosion classes. `DatingChallengeRules` converts terminal board evidence into exactly one relationship receipt. `RelationshipRules` owns clamped per-friend state; `PromotionRules` owns fixed valves. `PairObservationRules` owns P–L window board truth and delegates profile deck draws through an injected port. `GameState` coordinates these modules but cannot accept caller-supplied deltas.

**Tech Stack:** Godot 4.6.3, GDScript, deterministic RNG, pure domain modules, GUT seeded/property tests, accessible Control-based board UI.

## Global Constraints

- [ ] Required skills: `domain-modeling`, `godot-master` with `math-essentials`, `input-handling`, `godot-ui`, `responsive-ui`, `save-load-systems`, and `testing-patterns`, plus `test-driven-development`, `incremental-implementation`, and `superpowers:verification-before-completion`.
- [ ] Use the approved Minesweeper round interface owned by the reconciled `dwm-p2r.9`. If its exact board-result/snapshot contract is unavailable, stop before board implementation; do not invent a second contract.
- [ ] Reuse the game's approved difficulty, safety, 3BV, efficiency, and No-flag definitions. This plan only separates board truth from relationship outcome and adds the dating terminal phase.
- [ ] The shipped date never presents six relationship-result buttons. Development simulation controls must be hidden behind an explicit debug capability.
- [ ] Board RNG is deterministic. Hidden explosion assignment is an independent uniform 1/3 draw per ordinary mine and never consults story state.
- [ ] A clear commits board truth only. Relationship effects commit once after the player finishes without the special mine or deliberately activates it.
- [ ] Pair boards never mutate Angela relationship state, consent, pair state/tone, or ending eligibility.
- [ ] Profile persistence and branch/attempt reconciliation are Plan 04. This plan exposes detached snapshots and receipts for that owner.
- [ ] Plan 02's pure calendar/contact/Hospital receipts are green. This plan must not write profile state or finalize the profile-backed P–L draw.

---

## Task Interface Map

| Task | Consumes | Produces |
|---:|---|---|
| 1 | Approved axes/outcome law and Sylvia receipt | One typed relationship owner |
| 2 | Committed `.9` board contract | Deterministic board/snapshot/metric owners |
| 3 | Board terminal truth | Six derived solo outcomes and post-clear special state |
| 4 | Board owner plus existing app rewards | Real desktop round coordinator and committed-action receipt |
| 5 | Relationship receipts and fixed calendar slots | Non-relocating promotion receipts |
| 6 | Pair window input plus board owner | Pure pair/deck rules and visible pair coordinator |
| 7 | Tasks 1–6 plus Plan 02 day intents | Exactly-once solo/Hospital effects and challenge continuations |

## Task 1: Replace legacy relationship bags with one typed pure owner

**Specification:** Sections 6.1–6.2, 8.1, 16.3, 17.

**Files:**

- Create: `scripts/domain/relationship/RelationshipRules.gd`
- Create: `tests/unit/test_relationship_rules.gd`
- Modify: `autoload/GameState.gd`
- Modify: `autoload/EffectResolver.gd`
- Modify: `tests/unit/test_game_state.gd`
- Modify: `tests/unit/test_effect_resolver.gd`

- [ ] Write RED tests for exact defaults and validation:

```gdscript
{
	"priscilla": {"affection": 0, "tier": "friend", "dark": 0, "attitude": "neutral"},
	"lavinia": {"affection": 0, "tier": "friend", "dark": 0, "attitude": "neutral"},
	"sylvia": {"affection": 0, "tier": "friend", "dark": 0, "attitude": "neutral"},
}
```

Allowed tiers: `friend | ambiguous | love`; attitudes: `neutral | hostile | upset | amused | affectionate | seen | fixated`; affection clamp `-4..10`; dark clamp `0..4`.
- [ ] Implement pure methods:

```gdscript
class_name RelationshipRules
extends RefCounted

static func make_defaults() -> Dictionary
static func validate(state: Dictionary) -> Dictionary
static func prepare_outcome(state: Dictionary, friend_id: String, outcome: String, challenge_slot_id: String, transaction_id: String) -> Dictionary
static func prepare_sylvia_hospital_witness(state: Dictionary, invitation_id: String, transaction_id: String) -> Dictionary
static func tone_for(state: Dictionary, friend_id: String) -> String
```

- [ ] `prepare_outcome()` derives the exact table: Hatred `-1/hostile`; Upset `0/upset`; Amused `+1/amused`; Loved `+2/affectionate`; Foresight `+2/seen`; Dark `+2,+1 dark/fixated`.
- [ ] Reject arbitrary deltas and unknown outcome strings. A receipt stores before/after values, slot ID, outcome, and transaction ID.
- [ ] Migrate `GameState.affection`, `friend_attitude`, and `dating_route_state` behind one primitive `relationships` bag. Keep compatibility getters during migration; remove computed/regressing Hatred/Just Friend tiers, `true_path_count`, and `previous_entered_true_path` from live state.
- [ ] Narrow `EffectResolver`: DTL/general effect IDs cannot change affection, attitude, dark, tier, inter-friend state, or relationship outcome. Engine-owned adapters call `RelationshipRules` directly through registered commands.
- [ ] Run GREEN and commit:

```text
refactor(relationships): centralize durable tiers tone and attitude
```

## Task 2: Build deterministic Minesweeper state and hidden mine assignments

**Specification:** Sections 6.4, 8.1, 10.1.

**Files:**

- Create: `scripts/domain/minesweeper/MinesweeperBoardState.gd`
- Create: `scripts/domain/minesweeper/MinesweeperBoardGenerator.gd`
- Create: `scripts/domain/minesweeper/MinesweeperBoardMetrics.gd`
- Create: `tests/unit/test_minesweeper_board_state.gd`
- Create: `tests/unit/test_minesweeper_board_generator.gd`
- Create: `tests/unit/test_minesweeper_board_metrics.gd`

- [ ] Write seeded RED tests for board dimensions/configuration, first-click safety, reveal/flag/chord legality, win/explosion, exact snapshot round-trip, and deterministic RNG advancement. Preserve existing approved difficulty/safety rules rather than duplicating constants.
- [ ] Define the primitive snapshot contract:

```gdscript
{
	"schema_version": 1,
	"board_id": String,
	"nonce": String,
	"seed_before": int,
	"seed_after": int,
	"width": int,
	"height": int,
	"mine_count": int,
	"mine_indices": Array[int],
	"revealed_indices": Array[int],
	"flagged_indices": Array[int],
	"action_history": Array[Dictionary],
	"explosion_classes": Dictionary,
	"click_count": int,
	"three_bv": int,
	"used_flag": bool,
	"phase": String,
	"exploded_index": Variant,
}
```

Allowed phases at this layer: `READY | ACTIVE | EXPLODED | CLEARED`. The dating wrapper owns its later terminal-choice phase.
- [ ] Each `action_history` record has exactly `sequence`, `action`, `cell_index`, `revealed_delta`, `flagged_after`, `phase_after`, and `receipt_id`. Allowed actions are `reveal | flag | unflag | chord`; sequences are contiguous and receipts unique. Snapshot validation recomputes aggregate click/flag/reveal state from the ordered history and rejects disagreement.
- [ ] At generation, assign each ordinary mine independently using a board-local RNG draw in `[0,2] -> hatred/upset/amused`. Persist `explosion_classes` with canonical unsigned base-10 String keys (`"0"`, `"1"`, and so on), never integer Dictionary keys; validate each decoded index is a mine and unique. Do not balance quotas.
- [ ] Add a property test over many seeds that proves every class is reachable and roughly uniform within a broad deterministic tolerance; the exact oracle is per-seed determinism and state independence, not a flaky exact distribution.
- [ ] Test identical board seed/config with different friend/day/tier/dark/affection inputs produces byte-identical board/assignment data because those fields are not accepted by the generator.
- [ ] `MinesweeperBoardMetrics` preserves the existing calculations and reports:

```gdscript
{
	"board_result": "solved" or "perfect",
	"perfect_reasons": ["efficiency_gt_100", "no_flag"], # Array[String]
	"efficiency_percent": float,
	"three_bv": int,
	"click_count": int,
}
```

Reasons are sorted, unique, nonempty only for Perfect. Accessibility configuration is absent from classification inputs.
- [ ] Run GREEN and commit:

```text
feat(minesweeper): add deterministic board snapshots and mine classes
```

## Task 3: Add the dating terminal-choice state machine

**Specification:** Sections 6.4, 8.1, 10.1, 12.5.

**Files:**

- Create: `scripts/domain/relationship/DatingChallengeRules.gd`
- Create: `tests/unit/test_dating_challenge_rules.gd`
- Modify: `scripts/ui/MinesweeperChallengeOverlay.gd`
- Modify: `scenes/dating/MinesweeperChallengeOverlay.tscn`
- Modify: `tests/unit/test_minesweeper_rewards.gd` only for preserved app/dating separation

- [ ] Write RED tests for every terminal path and duplicate/conflicting receipt:

  - exploded H/U/A -> corresponding relationship outcome;
  - non-Perfect clear -> `CLEARED_AWAITING_TERMINAL_CHOICE` with `board_result = solved`;
  - Perfect clear -> same phase with sorted Perfect reasons;
  - normal finish -> Loved or Foresight;
  - special-mine activation -> Dark while preserving solved/perfect truth;
  - save/restore in post-clear phase offers the same terminal decision and no payout yet;
  - finishing twice applies one outcome; conflicting second choice fails.

- [ ] Implement:

```gdscript
class_name DatingChallengeRules
extends RefCounted

static func prepare_enter(slot_id: String, friend_id: String, board_snapshot: Dictionary, attempt_id: String, transaction_id: String) -> Dictionary
static func prepare_board_terminal(state: Dictionary, board_snapshot: Dictionary, transaction_id: String) -> Dictionary
static func prepare_finish_without_special(state: Dictionary, transaction_id: String) -> Dictionary
static func prepare_activate_special_mine(state: Dictionary, transaction_id: String) -> Dictionary
static func validate(state: Dictionary) -> Dictionary
```

- [ ] Dating phases are `BOARD_ACTIVE | CLEARED_AWAITING_TERMINAL_CHOICE | TERMINAL`. Explosion moves directly to TERMINAL. Clear cannot apply relationship effects.
- [ ] Dating state also owns an ordered `terminal_action_history`; its only legal records are `finish_without_special` or `activate_special_mine` with sequence, pre/post phase, and receipt ID. It is empty before post-clear choice and has exactly one record at terminal clear; explosion needs none because its board action history is the terminal cause.
- [ ] The special mine is a distinct unnumbered cell/control created only after clear; it cannot be focused or activated earlier. The ordinary finish action remains available without turning the experience into a six-result menu.
- [ ] Terminal receipt fields are exact: slot, friend, attempt, board result, Perfect reason set, relationship outcome, explosion mine/class when applicable, terminal choice, and effect receipt ID.
- [ ] Replace the six shipped result buttons with the live board and one post-clear finish/special interaction. Preserve a debug-only simulator behind `OS.is_debug_build()` plus an injected test capability; production scene tests assert it is hidden/unreachable.
- [ ] App rounds still use the existing money/task path; dating context never reaches app rewards.
- [ ] Run GREEN and commit:

```text
feat(dating): resolve one outcome after the post-clear mine choice
```

## Task 4: Replace the desktop Minesweeper placeholder with the real round path

**Specification:** Sections 7.4, 8.1, 11.1, 12.5.

**Files:**

- Create: `scripts/application/minesweeper/MinesweeperRoundCoordinator.gd`
- Modify: `scripts/ui/MinesweeperApp.gd`
- Modify: `scenes/apps/MinesweeperApp.tscn`
- Modify: `autoload/GameState.gd`
- Create: `tests/unit/test_minesweeper_round_coordinator.gd`
- Create: `tests/integration/test_minesweeper_app_round.gd`
- Create: `tests/scene/test_minesweeper_app_scene.gd`

- [ ] Write RED tests that the current `SimulationButtons` cannot complete a production round. A real app board must start from the round/task contract, accept reveal/flag/chord intents, persist its board snapshot, resolve money/task reward once, and emit one typed `desktop_action_committed` receipt only after the reward commit.
- [ ] `MinesweeperRoundCoordinator` consumes the same deterministic board owner as dating but uses the existing app reward contract, never relationship outcomes, Perfect mastery, or the post-clear Dark mine.
- [ ] Replace the player-facing placeholder controls with the live board. Keep simulation controls only behind `OS.is_debug_build()` plus an injected test capability; a final-mode scene test proves they are absent and unreachable.
- [ ] After the reward/unlock commit, adapt it into Plan 02's exact `DesktopActionReceipt`: `action_id = round_id`, kind `minesweeper_round`, source receipt = reward receipt, exact before/after condition record, and sorted unlock receipt IDs. Pass it immediately to `DesktopActionConditionCoordinator`; UI cannot perform or bypass that check.
- [ ] Run the focused coordinator/app tests RED then GREEN and commit:

```text
feat(minesweeper): run real desktop boards through committed rewards
```

## Task 5: Implement fixed promotion valves

**Specification:** Section 8.2.

**Files:**

- Create: `scripts/domain/relationship/PromotionRules.gd`
- Create: `tests/unit/test_promotion_rules.gd`
- Modify: `scripts/domain/relationship/RelationshipRules.gd`

- [ ] Write exhaustive RED cases for friend × canonical window × attended/missed/Hospital × starting tier × affection `3,4,7,8`.
- [ ] Encode only these gates:

```gdscript
const PROMOTION_GATES := {
	"priscilla": {4: {"from": "friend", "to": "ambiguous", "minimum": 4}, 6: {"from": "ambiguous", "to": "love", "minimum": 8}},
	"lavinia": {5: {"from": "friend", "to": "ambiguous", "minimum": 4}, 6: {"from": "ambiguous", "to": "love", "minimum": 8}},
	"sylvia": {4: {"from": "friend", "to": "ambiguous", "minimum": 4}, 5: {"from": "ambiguous", "to": "love", "minimum": 8}},
}
```

- [ ] Implement `prepare_after_challenge(relationships, friend_id, day, challenge_receipt, transaction_id)`. It requires an attended terminal relationship receipt for that exact fixed slot, advances at most one tier, and records `promoted=false` when fuel/state fails.
- [ ] Prove a missed third valve never relocates and a fourth valve cannot repair Friend directly to Love. Raw affection cannot change tier.
- [ ] Keep Sylvia Hospital promotion in `RelationshipRules.prepare_sylvia_hospital_witness()` as the sole exception; it does not call a fake challenge gate.
- [ ] Run GREEN and commit:

```text
feat(relationships): enforce non-relocating promotion valves
```

## Task 6: Implement P–L pure observation boards and stable deck rules

**Specification:** Sections 6.1, 7.5, 10.4, 11.6–11.7.

**Files:**

- Create: `scripts/domain/pair/PairObservationRules.gd`
- Create: `scripts/domain/pair/PairDeckRules.gd`
- Create: `scripts/application/pair/PairDeckPort.gd`
- Create: `scripts/application/pair/PairChallengeCoordinator.gd`
- Create: `tests/unit/test_pair_observation_rules.gd`
- Create: `tests/unit/test_pair_deck_rules.gd`
- Create: `tests/support/FakePairDeckPort.gd`
- Create: `tests/integration/test_pair_challenge_coordinator.gd`
- Modify: `scripts/domain/contact/ContactInvitationState.gd`
- Modify: `scripts/ui/DatingScene.gd`
- Modify: `scenes/dating/DatingScene.tscn`

- [ ] Write RED tests for exactly five classifier outcomes after actual solo attendance is known: Prevented is not an encounter and counts `0`; Group, Missed, Private-visible, and Private-offscreen are the four counted encounter forms and count `+1`. Exactly Group/Missed/Private-visible are witnessed and create a board; Private-offscreen has no scene/board.
- [ ] Pair terminal classification accepts only `perfect | solved | exploded`. It records no relationship outcome and produces no relationship command. Assert the entire relationship state is byte-equal before/after every pair result.
- [ ] Perfect/Solved permit the registered full observation atom; Exploded permits only truncated observation; offscreen has no board/atom capability.
- [ ] Implement the stable four-combination deck:

```gdscript
const COMBINATIONS := [
	"ambiguous_sweet", "ambiguous_dark", "love_sweet", "love_dark",
]
```

`PairDeckRules.prepare_draw(profile_witnessed, run_id, rng_nonce, transaction_id)` draws uniformly among unseen combinations while any remain, else among all four. It returns chosen combination, witnessed-set fingerprint, nonce, and receipt ID.
- [ ] Keep the production deck port unbound in this plan. Unit/integration tests use `FakePairDeckPort`; Plan 04 implements the profile-backed port and adds draw/counter/deferred-entry references to the day-resolution receipt. A second window, old save, visibility change, pair result, or later profile discovery must reuse that durable draw.
- [ ] `PairChallengeCoordinator` accepts only visible Group/Missed/Private-visible intents with the stable pair slot IDs `pair.priscilla_lavinia.day_2` and `.day_6`. It launches the shared board UI in pair mode, accepts only `perfect | solved | exploded`, freezes full/truncated post context, and returns to the same day-resolution plan. Private-offscreen launches nothing.
- [ ] Wire `DatingScene` to dispatch explicitly between solo and pair modes. Hospital-deferred visible pair intents use the same pair coordinator after Hospital presentation; they cannot fall into solo relationship payout.
- [ ] Combination witness is not granted here. Plan 04 routes the allowlisted full Perfect/Solved observation atom through an idempotent profile transaction; Exploded/offscreen contexts have no capability.
- [ ] Run GREEN and commit:

```text
feat(pair): add pure observation boards and unseen-first deck
```

## Task 7: Wire challenge results and promotion through GameState once

**Specification:** Sections 8, 10.4, 12.5.

**Files:**

- Modify: `autoload/GameState.gd`
- Modify: `scripts/application/run/GameStateDayResolutionPort.gd`
- Modify: `scripts/ui/DatingScene.gd`
- Modify: `scenes/dating/DatingScene.tscn`
- Create: `tests/integration/test_dating_challenge_transaction.gd`
- Create: `tests/scenario/test_promotion_windows.gd`

- [ ] Write RED integration cases for challenge entry -> board terminal -> terminal choice -> relationship receipt -> promotion receipt -> post-challenge presentation context.
- [ ] Replace `GameState.apply_dating_challenge_result(entry, result)` caller-supplied deltas with a command that accepts only validated challenge state/receipt IDs. The state owner looks up the committed receipt and derives effects.
- [ ] Commit order is board truth -> one terminal relationship outcome -> fixed promotion -> post-entry frozen context. If any checkpoint/commit fails, rollback all prepared candidates or latch fatal on unprovable recovery.
- [ ] Bind Plan 02's `sylvia_hospital_witness` receipt through `RelationshipRules.prepare_sylvia_hospital_witness()` at the Hospital-resolution boundary. Apply its +2 affection, +1 dark, Fixated attitude, and one tier step exactly once before Hospital/care presentation; it records no board/mastery/promotion-valve result.
- [ ] Record current-run mastery from final canonical board truth, not prose outcome. Perfect-then-Dark counts Perfect.
- [ ] `DatingScene` requests pre/post semantic entries through the bridge but does not select outcomes or mutate stats. It waits on the board coordinator and passes only token-bound intents.
- [ ] Run the focused integration cluster and commit:

```text
feat(dating): transact challenge outcomes and promotion receipts
```

## Phase 03 Verification Gate

- [ ] Relationships use exact clamps, monotonic tiers, derived tone, and persistent attitude.
- [ ] Every mine's hidden H/U/A assignment is deterministic, independent, uniform 1/3, and story-state-free.
- [ ] Clear enters a resumable terminal-choice phase and pays exactly one outcome.
- [ ] Perfect reasons are disjoint from the Foresight relationship outcome; Perfect-then-Dark retains mastery.
- [ ] Fixed promotion gates never move or skip a tier.
- [ ] Pair boards have only three results and cannot mutate relationship state.
- [ ] The pure P–L deck is unseen-first and independent of Angela/board performance; fake-port tests prove a supplied draw is stable. Plan 04 alone proves profile ownership and cross-save run stability.
- [ ] Production dating UI contains no six-result chooser; supported non-mouse input reaches every board action.
