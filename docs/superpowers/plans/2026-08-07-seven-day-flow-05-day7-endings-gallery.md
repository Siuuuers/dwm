# Seven-Day Flow Phase 05: Day 7, Endings, Gallery, and Production Wiring Implementation Plan

> **Owner decision, 2026-09-08:** Eight-master consolidation is cancelled. Retain
> the original scene-oriented DTL arrangement and implement all promised scene
> mechanics with dialogue deferred. References below to 61-to-8 migration,
> eight-only path/count gates, and deleting the original DTL/UID files are
> superseded and must not be executed. Semantic IDs, exact entry resolution,
> safe scene completion, save/load, and promised branches remain required.
> Existing consolidated files are temporary implementation state, not layout
> authority. See the updated base design sections 4.1, 12.1, and 16.4.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Day 7's boardless destination flow, mandatory echo drain, exact faint/Dark-mode precedence, thirteen ending identities, ordered resumable ending steps, full/residue policy, Gallery replay, and one production wiring path from UI through validated owners and Dialogic.

**Architecture:** `DaySevenRules` freezes terminal intent after causal checks. `DatingEndingRules` remains the sole ending resolver but migrates from primary/epilogue slots to ordered steps. `RunLifecycle` stores a cursor over those steps. A concrete `DialogicEndingPlaybackPort` starts the registered entry and reports token-bound completion. The cross-store coordinator commits step completion, Gallery discovery, milestone, pair witness, and cursor consistently. Scenes project state and emit intents only.

**Tech Stack:** Godot 4.6.3, GDScript, existing transaction/autoload architecture, Dialogic semantic bridge, ProfileManager, SaveManager, GUT scenario/headless scene tests.

## Global Constraints

- [ ] Required skills: `domain-modeling`, `api-and-interface-design`, `godot-master` with `state-machine`, `dependency-injection`, `scene-organization`, `dialogue-system`, `save-load-systems`, `godot-ui`, and `testing-patterns`, plus `test-driven-development`, `incremental-implementation`, and `superpowers:verification-before-completion`.
- [ ] Plans 01–04 must be green. Do not duplicate their manifest, state, save, profile, or transaction owners.
- [ ] Day 7 has no dating challenge and calls no dating-board API.
- [ ] Follow-ups and every pending echo must complete before faint-capable controls or Done become available.
- [ ] Dark mode wins over Sylvia Special and blocks all romantic Done commitments on Days 1–7.
- [ ] Observer/Special are not selectable destinations. P–L never replaces Angela/Alone and remains the final applicable layer.
- [ ] Starting an ending label never advances state. Only a matching physical completion token may complete its step.
- [ ] Gallery unlocks exactly the semantic identities physically completed, never every label in `endings.dtl`.
- [ ] No final ending prose, title, art, audio, or animation is authored in this plan.

---

## Task Interface Map

| Task | Consumes | Produces |
|---:|---|---|
| 1 | Echo/follow-up state and committed desktop/Shop actions | Frozen Day 7 intent with exact faint precedence |
| 2 | EndingPlanSchema plus run/profile evidence | Ordered 13-identity resolver candidates |
| 3 | Resolver candidate plus profile discoveries | Frozen entry form/context and derived hidden settings |
| 4 | Frozen plan plus bridge completion/cross-store ports | Token-bound durable ending progression |
| 5 | Manifest-owned opportunities | Validated Observer evidence commands or explicit unavailability |
| 6 | Reached signatures plus Gallery IDs | Hidden-discovery UI and isolated replay |
| 7 | All domain/application ports | One production dependency and scene-intent path |
| 8 | Closed runtime manifest plus coexistence import | Guard proving old resources cannot widen runtime resolution |

## Task 1: Implement Day 7 interaction and terminal intent rules

**Specification:** Sections 7.3, 9.3, 11.1, 11.8, 12.5.

**Files:**

- Create: `scripts/domain/run/DaySevenRules.gd`
- Modify: `scripts/application/run/DesktopActionConditionCoordinator.gd`
- Create: `scripts/application/shop/ShopPurchaseCoordinator.gd`
- Create: `tests/unit/test_day_seven_rules.gd`
- Create: `tests/unit/test_shop_purchase_coordinator.gd`
- Modify: `autoload/GameState.gd`
- Modify: `autoload/EffectResolver.gd`
- Modify: `scripts/domain/schedule/ScheduleRules.gd`
- Modify: `scripts/ui/MinesweeperApp.gd`
- Modify: `scenes/apps/MinesweeperApp.tscn`
- Modify: `scripts/ui/ShopApp.gd`
- Modify: `scenes/apps/ShopApp.tscn`
- Modify: `scripts/ui/ComputerDesktop.gd`
- Modify: `tests/scenario/test_day7_endings.gd`
- Create: `tests/scenario/test_day7_echo_and_faint.gd`
- Create: `tests/integration/test_day7_action_faint_order.gd`
- Create: `tests/integration/test_shop_action_condition_order.gd`

- [ ] Write RED tests for this exact state order:

  1. present all due D6 solo/group follow-ups;
  2. drain every pending echo oldest-first with durable atom receipts;
  3. unlock controls;
  4. round 1/2/3 conditionally unlock Priscilla/Lavinia/Sylvia by durable tier;
  5. read is acceptance/addability;
  6. empty Done -> ordinary Alone;
  7. one selected eligible destination -> boardless ending intent;
  8. qualifying pre-Done faint -> Special chain only if Sylvia was already read, otherwise Hospital-cause Alone;
  9. Dark mode -> Dark-mode Alone in every case.

- [ ] Implement:

```gdscript
class_name DaySevenRules
extends RefCounted

static func eligible_invitations(input: Dictionary) -> Dictionary
static func controls_unlocked(input: Dictionary) -> bool
static func prepare_action_and_faint(input: Dictionary, transaction_id: String) -> Dictionary
static func prepare_done(input: Dictionary, transaction_id: String) -> Dictionary
```

- [ ] Tier eligibility is `ambiguous | love` only. Affection and hostile/upset attitude are not eligibility inputs.
- [ ] Action order for app/Shop is effect commit -> round/unlock state commit -> faint check against invitations read before that action -> no-faint notification publication. A round that unlocks Sylvia cannot retroactively satisfy read-before-action.
- [ ] Bind `DaySevenRules` as the Day-7 policy of Plan 02's `DesktopActionConditionCoordinator`. The common coordinator accepts only a validated committed Minesweeper receipt or Shop receipt, preserves its pending-check checkpoint, evaluates read-before-action precedence, and publishes either Hospital routing or one no-faint notification. Duplicate action receipts cannot repeat effects, faint, unlock, or notification.
- [ ] `ShopPurchaseCoordinator.prepare_purchase(state, item_id, transaction_id)` validates the exact catalog item, price, limits, funds, inventory delta, and allowlisted non-relationship effect IDs. Its receipt has exactly `purchase_id`, `item_id`, `price`, `inventory_before`, `inventory_after`, `money_before`, `money_after`, `condition_before`, `condition_after`, `effect_receipt_ids`, and `transaction_id`; after commit it adapts to Plan 02's `DesktopActionReceipt` with kind `shop_purchase`.
- [ ] Wire `MinesweeperApp`, `ShopApp`, and `ComputerDesktop` to the common coordinator. Shop purchase must commit its catalog/effect candidate before the condition coordinator sees it; neither UI may call the faint predicate, unlock an invitation, or publish success independently. Integration tests assert the exact commit -> unlock -> faint -> notification trace on D1–7 and the no-retrospective-Sylvia case.
- [ ] Prove a legal Special path requires a later app round or Shop action after reading Sylvia. If no legal trigger remains, the route is unavailable by design.
- [ ] Day 7 faint discards UI draft, creates no scheduled/missed record, and sets `alone_cause = hospital_faint` or Special intent. Done suppresses future faint checks.
- [ ] Add Dark-mode gate to `ScheduleRules`: when enabled, reject any solo/group dating commitment on Days 1–7 but permit non-romantic day progression. Offers/read states still exist for presentation.
- [ ] Run GREEN and commit:

```text
feat(day7): gate endings behind echoes and exact faint order
```

## Task 2: Migrate DatingEndingRules to ordered semantic steps

**Specification:** Sections 11.2–11.9, 14.3–14.4, 16.3.

**Files:**

- Modify: `scripts/domain/ending/DatingEndingRules.gd`
- Modify: `tests/unit/test_dating_ending_rules.gd`
- Modify: `tests/unit/test_dating_ending_rules_migration.gd`
- Inspect/consume without redefining: `scripts/domain/ending/EndingPlanSchema.gd`
- Inspect/consume without redefining: `scripts/domain/run/RunLifecycle.gd`

- [ ] Replace old `primary + optional epilogue` tests with an exhaustive resolver matrix. Define the exact 13 semantic ending IDs:

```gdscript
const ENDING_IDS := [
	"ending.alone",
	"ending.priscilla.sweet", "ending.priscilla.dark", "ending.priscilla.observer",
	"ending.lavinia.sweet", "ending.lavinia.dark", "ending.lavinia.observer",
	"ending.sylvia.sweet", "ending.sylvia.dark", "ending.sylvia.special",
	"ending.priscilla_lavinia.sweet", "ending.priscilla_lavinia.dark", "ending.priscilla_lavinia.observer",
]
```

- [ ] Build every resolver result with Plan 04's exact `EndingPlanSchema`; add no keys, alternate stages, or ending-specific cursor. Validate the complete candidate before returning it.
- [ ] Implement base selection:

  - Dark mode -> `ending.alone` with `alone_dark_mode`;
  - qualifying Special -> Special then Sylvia Dark with `special_forced_dark`;
  - no selected candidate -> normal Alone with `empty_done | hospital_faint` cause;
  - selected P/L/S -> Sweet at dark 0–1 or Dark at 2–4, with durable tier/attitude inserts frozen.

- [ ] Append solo Observer only after the selected P/L Sweet identity, four active-branch attended Perfect solo slots, and validated profile Verification/Restraint evidence. Dark never appends Observer; Sylvia has none.
- [ ] Append P–L Sweet/Dark after any base/Special chain when both windows counted, selecting tone/state from the stable deck only. It is always after Angela steps.
- [ ] Append P–L Observer only after P–L Sweet, two current-run counted visible Perfect pair boards, and four profile-witnessed combinations. Permit a precondition on the P–L Sweet completion receipt when that step will witness the missing fourth combination.
- [ ] Reject causally incompatible P/L solo Observer + P–L ending plans. The resolver must prove the shared D2/D6 attendance contradiction, not merely rely on current UI.
- [ ] Exhaust plan lengths 1–4, ordering, prerequisites, and no duplicate identities.
- [ ] Use Plan 04's generic `RunLifecycle` cursor/step operations while keeping Day at 7 and lifecycle `ENDING -> COMPLETED` only after all steps/gallery are durable.
- [ ] Run GREEN and commit:

```text
feat(endings): resolve ordered thirteen-identity plans
```

## Task 3: Freeze full/residue and ending presentation contexts

**Specification:** Sections 11.10, 12.2–12.3, 13.8.

**Files:**

- Modify: `scripts/domain/ending/DatingEndingRules.gd`
- Create: `scripts/domain/profile/ProfileUnlockRules.gd`
- Modify: `scripts/profile/ProfileSchema.gd`
- Modify: `autoload/ProfileManager.gd`
- Modify: `tests/unit/test_dating_ending_rules.gd`
- Modify: `tests/unit/test_profile_manager.gd`
- Create: `tests/unit/test_profile_unlock_rules.gd`
- Modify: `data/manifests/dialogic_entries.json`

- [ ] Test exceptional identity selection:

  - first discovery -> Full regardless of setting;
  - discovered + replay-full Off -> stable Residue entry/variant;
  - discovered + setting On -> Full;
  - Gallery -> Full;
  - reload cannot change selected mode/variant;
  - setting remains hidden/unavailable until first exceptional discovery.

- [ ] Use Plan 01's exact entry forms: `.observer.full`, `.observer.residue`, `.special.full`, `.special.residue`; one semantic ending ID owns both presentation entries.
- [ ] Freeze `stored_tone` separately from `ending_form`. Special-forced Sylvia Dark does not mutate raw dark. Alone requires cause; P–L/Alone schemas reject fake friend/tier/attitude fields.
- [ ] Residue variant is a finite manifest value derived before plan freeze. Do not use runtime randomness after plan creation.
- [ ] Add/validate the hidden profile settings `dark_mode.available/enabled` and `exceptional_replay.available/replay_full`. Migration defaults both unavailable/disabled.
- [ ] `ProfileUnlockRules.prepare_after_ending_discovery()` derives Dark-mode availability only when Gallery contains `ending.priscilla.dark`, `ending.lavinia.dark`, `ending.sylvia.dark`, and `ending.sylvia.special`. The mutation is monotonic/idempotent, cannot be claimed by payload, and does not auto-enable the setting. Task 4 includes the derived candidate in the same ending-completion transaction.
- [ ] Run GREEN and commit:

```text
feat(endings): freeze exceptional replay and ending forms
```

## Task 4: Implement token-bound ending playback and cross-store completion

**Specification:** Sections 11.9, 12.4–12.5, 14.3–14.5.

**Files:**

- Create: `scripts/narrative/DialogicEndingPlaybackPort.gd`
- Modify: `scripts/ui/EndingScene.gd`
- Modify: `scenes/ending/EndingScene.tscn`
- Modify: `autoload/GameState.gd`
- Modify: `scripts/application/transaction/CrossStoreTransactionCoordinator.gd`
- Create: `tests/unit/test_dialogic_ending_playback_port.gd`
- Modify: `tests/scenario/test_day7_endings.gd`
- Create: `tests/integration/test_ending_dialogic_wiring.gd`

- [ ] Write RED tests around every step/cursor state: crash before start, after start, after physical completion, after profile side, after run side, after cursor, during gallery publication, and before Menu.
- [ ] `DialogicEndingPlaybackPort.play(step)` validates the step/entry/context through Plan 01 and calls `DialogicBridge.start_entry()`. It returns the bridge playback token and never advances the plan.
- [ ] Implement Plan 01's exact playback-completion interface. Adapt `EndingScene` away from its legacy `start_ending_id/is_ready/playback_completed/playback_failed` assumptions to the single `play(step)` plus token-bound `complete_entry(intent)` result; do not keep two callback protocols.
- [ ] `EndingScene._ready()` must use one configured port path. Remove/disable legacy `_show_ending()` and any direct catalog/bridge start.
- [ ] `GameState.request_next_ending_command()` returns one command for the current cursor: play step, reconcile pending completion, complete run, or no-op. It never exposes physical locator data.
- [ ] On matching `timeline_ended`, prepare one cross-store transaction containing:

  - run step completion and next cursor;
  - semantic Gallery discovery for that one identity;
  - first-ending milestone when this is the profile's first completed semantic step;
  - exceptional setting availability when applicable;
  - derived Dark-mode availability when the completed discovery makes all four prerequisites present;
  - pair combination witness when a completed P–L visible ending portrays it;
  - prerequisite receipts needed by a following Observer.

- [ ] Only after both profile and run sides validate may the next step start. Duplicate matching completion is no-op; mismatched/stale token stops safely.
- [ ] Full ending sequence completes to Menu only after every step and gallery receipt are durable. Abandoning later steps does not revoke the first-step milestone.
- [ ] Run GREEN and commit:

```text
feat(endings): transact token-bound playback and discovery
```

## Task 5: Implement Observer evidence command windows

**Specification:** Sections 10.4, 11.4, 11.7, 12.8.

**Files:**

- Create: `scripts/domain/ending/ObserverEvidenceRules.gd`
- Create: `tests/unit/test_observer_evidence_rules.gd`
- Modify: `scripts/narrative/DialogicSignalCommandPort.gd`
- Modify: `data/manifests/dialogic_ids.json`
- Modify: `data/manifests/dialogic_entries.json`
- Create: `tests/integration/test_observer_signal_boundary.gd`

- [ ] Define finite mechanical evidence IDs without final prose: `observer.priscilla.capture`, `observer.priscilla.compare`, `observer.lavinia.restraint`. Bind source entries/atoms only when the approved production card provides that opportunity; absent capability means the evidence is unavailable, not guessed.
- [ ] Because this suite is structure-only, an empty production opportunity map is valid and makes Observer behavior evidence unearnable until content authorization. Resolver/unit tests use an explicitly test-only fixture manifest; final-mode tests prove fixture capabilities cannot load or mutate the real profile. Do not claim production Observer reachability without an approved source card.
- [ ] Write RED tests for different-run Capture/Compare, matching comparison key, source line/atom validation, time-bounded Restraint opportunity, accessibility-neutral close, intervention/no-intervention, duplicates, Rehearsal denial, and generic history denial.
- [ ] `observer.evidence.commit` derives the evidence mutation from manifest capability; payload cannot claim run IDs, comparison success, clocks, or relationship effects beyond its exact registered IDs/tokens.
- [ ] A timer/window belongs to an engine command state, not DTL dwell time. Pause/accessibility assistance freezes or adjusts the window according to the registered policy and cannot make it harder.
- [ ] Run GREEN and commit:

```text
feat(observer): validate canonical evidence opportunities
```

## Task 6: Implement Gallery identity replay and hidden discovery UI

**Specification:** Sections 10.5, 11.2, 11.10, 14.4.

**Files:**

- Modify: `scripts/ui/GalleryScene.gd`
- Modify: `scenes/menu/GalleryScene.tscn`
- Modify: `autoload/ProfileManager.gd`
- Create: `tests/scene/test_gallery_scene.gd`
- Create: `tests/integration/test_gallery_replay_isolation.gd`

- [ ] Replace stale `.true`/generic P–L lists with the exact 13 IDs.
- [ ] Render buttons only for discovered identities. Unseen identities produce no placeholder, silhouette, percentage, count, locked tile, or question mark.
- [ ] Button labels use authored/localized title metadata when available; structural tests may use semantic fixture titles but must not ship them as final prose.
- [ ] Gallery replay resolves exceptional Observer/Special identities to their Full entry. Ordinary Sweet/Dark/P–L identities use their sole callable entry. Alone uses the most recently physically completed reached form (`ending.alone.normal` or `.dark_mode`) by durable completion sequence; it never fabricates an unreached form. Build the validated Gallery context from that exact reached signature and run in Rehearsal mode. Replay cannot mutate run state, Observer evidence, pair witnesses, attempts, ending plan, or duplicate Gallery receipts.
- [ ] Add keyboard/controller focus order and screen-reader accessible names for visible discovered entries only.
- [ ] Run GREEN and commit:

```text
feat(gallery): replay only discovered ending identities
```

## Task 7: Complete production dependency injection and scene intent wiring

**Specification:** Sections 12.4–12.8, 14.5, 16.2.

**Files:**

- Modify: `autoload/ApplicationBootstrap.gd`
- Modify: `autoload/SceneRouter.gd`
- Modify: `autoload/DialogicBridge.gd`
- Modify: `scripts/ui/OpeningScene.gd`
- Modify: `scripts/ui/MenuScene.gd`
- Modify: `scripts/ui/TutorialOverlay.gd`
- Modify: `scripts/ui/ContactListApp.gd`
- Modify: `scenes/apps/ContactListApp.tscn`
- Modify: `scripts/ui/ScheduleApp.gd`
- Modify: `scenes/apps/ScheduleApp.tscn`
- Modify: `scripts/ui/DatingScene.gd`
- Modify: `scripts/ui/HospitalScene.gd`
- Modify: `scripts/ui/EndingScene.gd`
- Modify: `scripts/ui/ComputerDesktop.gd`
- Create: `tests/integration/test_application_bootstrap_seven_day.gd`
- Create: `tests/scene/test_seven_day_scene_ports.gd`

- [ ] Write RED final-mode bootstrap tests. Every named `STAGE_ORDER` stage must have one implemented dispatcher/target: restore participants, day resolution, Minesweeper rounds/board coordinator, Dialogic manifest/signal port, ending playback, cross-store recovery, and scene routing.
- [ ] Construct the six existing restore participants and pass them to `SaveManager.configure_restore_participants()`. Configure day resolution through the existing `ApplicationBootstrap.configure_day_resolution()` seam.
- [ ] Wire scenes to typed intents:

  - Contacts renders the stacked view and opens the registered ordinary-message semantic entry; only `DialogicSignalCommandPort` handling `message.reply.commit` with the active token/source commits A/B/C, so `ContactListApp` never commits an ordinary reply. Contacts may issue the separately defined group open/reply intents;
  - Schedule owns `ScheduleDraftController` and passes a snapshot on Done;
  - Dating waits on the real board coordinator and bridge pre/post entries;
  - Hospital starts the day-specific semantic entry, then reports completion to the coordinator—never directly advances/recoveries;
  - Opening/Tutorial use `start_entry()` with exact IDs/context;
  - Ending uses only the injected playback port;
  - Desktop keeps controls disabled during mandatory echo/Hospital/ending transactions.

- [ ] `MenuScene` requests New Game through the Plan 04 cross-store coordinator and receives the allocated run ID only after both profile allocator and initial slot are durable. Remove its tick/`randi()` ID generation. Retire or make private `SceneRouter.start_game_from_menu()` if it bypasses `SaveManager.start_new_run()`; one transaction owns run/profile/restore setup.
- [ ] Add a static scan proving no production scene calls `Dialogic.start`, `start_timeline_path`, legacy `start_timeline_id`, `finish_current_timeline`, `timeline_marker`, direct `GameState` bag mutation, `ProfileManager` internal mutation, or direct Hospital day advance.
- [ ] Run GREEN and commit:

```text
feat(runtime): wire seven-day scenes through production ports
```

## Task 8: Guard manifest-only runtime resolution during DTL coexistence

**Specification:** Sections 12.1, 13, 16.4.

**Files:**

- Modify: `tools/config/ProjectConfigGuard.gd`
- Modify: `tests/unit/tooling/test_project_config_guard.gd`
- Inspect: eight new `.dtl.uid` files
- Inspect only: `project.godot`
- Preserve until Plan 06: 61 old `.dtl` and 61 old `.dtl.uid` files

- [ ] Write RED guard tests that tolerate Dialogic's 69-resource coexistence index while requiring the semantic manifest to expose exactly eight master paths and 139 entries. No production locator/caller may resolve any old path.
- [ ] Do not prune `project.godot` while old `.dtl` resources remain under `res://`; Dialogic import would re-add them. Exact-eight physical registration belongs to Plan 06's authorized deletion transaction.
- [ ] Run editor import, manifest validation, all 139 bridge-start smokes, and scene port tests. Assert import cannot widen the closed runtime catalog.
- [ ] Run GREEN and commit:

```text
test(dialogic): guard master-only runtime resolution during coexistence
```

## Phase 05 Verification Gate

- [ ] D7 drains every echo before controls and never runs a dating challenge.
- [ ] Tier-only invitations, read-before-later-action Special, Hospital Alone, and Dark-mode precedence pass.
- [ ] Exactly 13 ending identities resolve into legal ordered plans of length 1–4.
- [ ] Solo/P–L Observer gates and their causal incompatibility pass.
- [ ] Full/residue mode and variants are frozen; Gallery uses Full only for exceptional identities and an actually reached form for every other identity.
- [ ] Matching physical completion plus cross-store durability is the only step-advance path.
- [ ] All scenes use injected ports/semantic entries; legacy direct ending/Hospital starts are gone.
- [ ] Runtime manifest resolution uses only eight masters while Dialogic's editor resource index may still list 69 coexistence resources pending Plan 06.
