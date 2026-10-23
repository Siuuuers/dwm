# Desktop Board, Minesweeper Safety, and Shop Contracts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `dwm-p2r.9`'s obsolete lifetime board lock and simulator authority with deterministic desktop-board, Minesweeper safety, Shop-capability, exact-save, logout, board-fate, consequence-state, and shared causal-sequence contracts that later player-facing phases can compose without changing product law.

**Architecture:** `GameState` remains the active-run facade, but delegates canonical desktop-board state to one pure `DesktopBoardState` owner and accepts mutations only through typed application ports. One shared pure generation kernel uses separately persisted placement, Debug, and explosion streams; tooling builds certified fallbacks and freezes measured budgets before the bounded runtime adapter exists. One injected production issuer mints every root identity/nonce and ledger-verifies every deterministic child from a persisted namespace/counter. One external operation journal makes New Run/selected Load recoverable before allocation or live apply. Snapshot v4 is installed before any production first-Reveal checkpoint and stores one closed `desktop={board,consequence}` aggregate. `DesktopConsequenceState` owns the run revision, shared causal sequence, gameplay-transaction recovery state, receipts, and intent outboxes; reversible board-fate, opaque condition-departure view, and causal-sequence seams are reusable by Plan 03, which alone owns ScheduleView and installs real Hospital/Day-7 destination composition and the player-facing simulator replacement.

**Tech Stack:** Godot 4.6.3 stable Mono, GDScript, GUT 9.6.1, strict primitive JSON, JSON Schema, the existing `CommandResult`, `ApplicationMutationGate`, `SaveManagerCheckpointPort`, `StrictJson`, `CanonicalJsonWriter`, and GUID-isolated PowerShell test wrapper.

**Plan status:** `approved`

**Owning Beads issues:** precursor Task 1 = `dwm-p2r.16`; Tasks 2–9 and final handoff = `dwm-p2r.9`.

**Implementation authorization:** `false`. This plan is an executable procedure only after separate runtime authority is granted. Claim `dwm-p2r.16` for Task 1 only after `dwm-wks` closes; close `.16`, then complete Plan-01 v3/`.13`; only afterward may `dwm-p2r.9` be ready/claimed for Tasks 2–9.

## Global Constraints

- The accepted authority is `docs/design/2026-08-11-desktop-minesweeper-shop-schedule-amendment.md`; the approved packets are `req.desktop.*`, `req.minesweeper.*`, and `req.save.desktop_board_continuity`. A conflict is a hard stop and plan-author review, never a reason to preserve an older lock.
- This is a Phase-2R domain-contract issue. It MUST NOT edit `scripts/ui/ComputerDesktop.gd`, `scripts/ui/MinesweeperApp.gd`, `scripts/ui/ShopApp.gd`, `scripts/ui/ShopItemBox.gd`, their scenes, final copy, art, audio, or visible composition. The existing player-facing simulator may remain as a non-authoritative adapter until `dwm-oyo.3`; it cannot be registered as state, board, consequence, checkpoint, identity, or route authority. Later phases consume these ports and may replace presentation adapters only; they MUST NOT duplicate or reinterpret this plan's board, generator, verifier, persistence, Shop, fate, or causal-order law.
- This plan MUST NOT implement or own ScheduleView, the Schedule warning queue, warning fingerprints, warning modals, or final Schedule Done/day-resolution composition. It freezes only opaque hashed ScheduleView recovery transport and the condition-departure port seam needed to keep an admitted action recoverable. Plan 03 alone creates the production ScheduleView owner/port and interprets, prepares, commits, or validates those bytes; this plan uses only a contract fake and produces no view state or view rule.
- It MUST NOT change relationship outcomes, invitation/group rules, Hospital predicates, Day-7 destinations, ending selection, or notification law. This plan exercises consequence and outbox recovery only through a contract fake; `dwm-oyo.3` owns the production condition-policy adapter, real destination intents, routing, and player-facing simulator replacement.
- A desktop app round starts only at the successful canonical commit of its first semantic Reveal. Opening the app, choosing difficulty, Debug preparation, flags, chords, and failed or duplicate-uncommitted commands cost nothing.
- Default/Lucky first Reveal materializes around the chosen cell. Debug preparation freezes one forced cell and a certified layout before Reveal, costs nothing, and never changes the forced cell while searching.
- The saved board phases are exactly `NONE`, `PREPARING`, `PREPARED_UNSTARTED`, `ACTIVE_VISIBLE`, `ACTIVE_SUSPENDED`, and `SETTLING`.
- A stable board command is short and revisioned; there is no lifetime board mutex or SaveManager `minesweeper_board` lock. Save, quick Save, same-day app switching, and Logout capture the latest completed command/preparation slice.
- Leaving the causal day discards an unstarted candidate or forfeits a started board. Load/New Run replace a continuation and are not forfeits.
- Lucky Charm, Debug Key, and Supportz facts come from one immutable registry. Caller dictionaries, UI fields, item-name parsing, current inventory after candidate freeze, and restored derived fields are never gameplay authority.
- Placement, Debug forced-cell/search, hidden explosion, Shop, pair-deck, presentation, identity-namespace, and Rehearsal randomness remain isolated. Placement, Debug, and explosion each have a distinct stream ID, nonce, and persisted state; drawing or retrying one cannot advance, reconstruct, or bias either other stream.
- Run, branch, desktop-generation, causal-day, board, transaction, nonce, and root-receipt identities come only from the injected `DesktopIdentityNonceIssuer`. Its exact namespace/counter state is persisted before an issued token becomes observable. The initial New-Run/restore causal-day identity is part of the continuation allocation bundle; every later Days-1–6 day advance MUST use the root-atomic `CausalDayAdvanceIdentityPort` contract below. Direct `issue(&"causal_day_instance")` returns `causal_day_advance_allocation_required`, so a crash cannot burn an unkeyed next-day identity and force replay to adopt a different token. A deterministic child identity is legal only through that same issuer's `derive_child()` after it ledger-verifies an issuer-issued parent whose purpose is exactly `transaction_id`; its domain-separated preimage is exactly the verified parent namespace/counter/receipt ID plus one registered child kind, nonnegative ordinal, and sorted unique source IDs. No child may anchor to a run/board/nonce/receipt-purpose token. No standalone hash, syntactically plausible caller ID, clock, `randi()`, global `RandomNumberGenerator`, instance ID, scene name, or fallback text may mint canonical identity.
- The issuer namespace, monotonic counter, token receipts, and allocation receipts live outside selectable run snapshots in one append-only injected storage owner. Save/Load may carry issued identity provenance only. New Run and selected Load durably allocate before live apply; the same restore transaction reuses its allocation, and no rollback/profile reset/older snapshot may decrement or replace the issuer root.
- New Run and selected Load additionally use one `DesktopContinuationOperationJournal` stored beside—but never inside—the issuer root and selectable saves. Issuing the root `transaction_id` may burn one durable token, but its exact continuation intent MUST be durable before allocation commits or any live participant applies. Startup reconciliation reloads a restore source by semantic locator/exact document hash or revalidates New Run's frozen initial-context hash, verifies the allocation-candidate fingerprint, reuses the same allocation receipt, and resumes forward; it never guesses from whichever slot is current.
- Every dictionary written to a snapshot, receipt, journal, fixture, or evidence file is detached primitive JSON with exact keys. Every public mutator returns the master `CommandResult` union:

```gdscript
# success
{"ok": true, "code": StringName, "value": Variant, "receipt": Dictionary}
# failure
{"ok": false, "code": StringName, "message": String, "details": Dictionary}
```

- GUT work is RED -> inspect the intended failure -> minimal GREEN -> focused regression. Parse errors, production-path access, and an unrelated failure are not valid RED evidence.
- Every test command uses `tools/testing/Invoke-IsolatedGodot.ps1`; no test process may touch production `user://`.
- Existing dirty work is never staged or rewritten. Every proposed commit is separately gated by `DWM_COMMIT_AUTHORIZED=1` and `tools/git/Invoke-ExactPathCommit.ps1`; the blocks below are boundaries, not authorization.
- Generated `.gd.uid` companions are optional-present members of the same boundary as their scripts. Never fabricate UID bytes.
- The frozen issue/task order is Plan-01 Tasks 1–2/`dwm-wks` -> this plan's Task 1/`dwm-p2r.16` -> Plan-01 Tasks 3–6/`dwm-p2r.13` v3 plus Schedule-foundation composition -> this plan's Tasks 2–9/`dwm-p2r.9`. Plan-01 Task 2 creates and proves `ScheduleActionRegistry`/its manifest, removes GameState's `_SCHEDULE_ACTION_EFFECTS`, and MUST NOT edit `scripts/data/DataCatalog.gd`; `.16` is the sole suite editor that removes legacy Schedule/Shop rows, delegates projections, and lands the issuer/root/journal boundary. Plan-01 Task 3 onward MUST prove the closed `.16` boundary SHA is an ancestor and consume that exact issuer seam. `.9` MUST NOT be partially claimed or paused around the v3 dependency: before Task 2, require both `.16` closed and all six Plan-01 `.13` tasks, including their recorded v3 boundary and retained foundation identities, integrated. Task 5 remains a pure/fake-checkpoint contract slice and cannot configure a production checkpoint provider. Task 6 repeats the v3 gate before changing schemas. This plan never guesses or reimplements Plan 01.
- Before `dwm-p2r.9` closes, its Beads acceptance text MUST be reconciled by the plan author (outside this plan's file map): `.9` owns the reusable board, persistence, Shop, consequence-state, causal-sequence, discard/forfeit ports, and removal of simulator **authority**. Real Days-1–6/Day-7 destination composition and removal/replacement of the player-facing simulator belong explicitly to `dwm-oyo.3`. Executing this plan does not itself authorize a Beads database edit.

---

## Frozen Data Contracts

### Desktop attempt identity

Every candidate command and every started-board command carries this exact identity. `app_round_ordinal` is the next eligible ordinal while a Debug candidate is unstarted and becomes consumed only by first-Reveal commit.

```gdscript
{
	"run_id": String,
	"branch_id": String,
	"desktop_timeline_generation": int, # >= 0
	"causal_day_instance": String,
	"app_round_ordinal": int,            # 1..5
}
```

`DesktopIdentity.validate()` rejects extra keys, blank strings, non-integral values, and ordinals outside `1..5`. `DesktopIdentity.fingerprint()` canonicalizes this exact object and returns lowercase SHA-256 hex. Difficulty, seed, day number, and board revision are not identity substitutes.

### Frozen board spec

The trusted state port, never the UI, builds this exact `BoardSpec` from the selected registered difficulty, current pressure/penalty inputs, future-facing capability ownership, and an isolated nonce:

```gdscript
{
	"schema_version": 1,
	"board_kind": "desktop" | "solo_challenge" | "pair_challenge",
	"board_token": String,
	"board_token_receipt_id": String,
	"difficulty_id": String,
	"width": int,
	"height": int,
	"base_mine_count": int,
	"pressure": int,
	"penalty_points_today": int,
	"raw_extra_mines": int,
	"requested_mine_count": int,
	"capability_ids": Array[String],
	"placement_stream_id": "minesweeper_placement_v1",
	"placement_nonce": String,
	"placement_nonce_receipt_id": String,
	"debug_stream_id": "minesweeper_debug_v1",
	"debug_nonce": String,
	"debug_nonce_receipt_id": String,
	"explosion_stream_id": "minesweeper_explosion_v1",
	"explosion_nonce": String,
	"explosion_nonce_receipt_id": String,
	"generator_version": "dwm_generator_v1",
	"verifier_version": "visible_deduction_v1",
}
```

`raw_extra_mines == floor(pressure / 3) + penalty_points_today`. Lucky transforms requested extras to `floor(raw_extra_mines / 2)`. Debug may reduce only extras during deterministic certification. Base mines are never reduced. Each nonce receipt must validate against the single issuer and its named purpose. Placement alone determines mine permutations; Debug alone determines forced-cell selection and deterministic search control; explosion alone determines hidden H/U/A assignment. This plan validates dimensions and base mines supplied by the registered difficulty adapter; it does not invent or revise player-facing difficulty balance.

### Canonical desktop state

`DesktopBoardState.capture()` returns exactly:

```gdscript
{
	"schema_version": 1,
	"phase": String,
	"revision": int,
	"identity": Dictionary | null,
	"candidate": Dictionary | null,
	"board": Dictionary | null,
	"settlement": Dictionary | null,
	"command_receipts": Dictionary,
	"terminal_receipts": Dictionary,
}
```

Phase invariants are closed:

| Phase | identity | candidate | board | settlement |
|---|---|---|---|---|
| `NONE` | null | null | null | null |
| `PREPARING` | exact | frozen spec + deterministic frontier, no layout | null | null |
| `PREPARED_UNSTARTED` | exact | frozen spec + certified layout + forced cell | null | null |
| `ACTIVE_VISIBLE` | exact | null | exact materialized board + paid start receipt | null |
| `ACTIVE_SUSPENDED` | exact | null | exact materialized board + paid start receipt | null |
| `SETTLING` | exact | null | terminal exact board | exact completion/forfeit journal stage |

`command_receipts` maps transaction ID to request fingerprint, identity fingerprint, pre/post revision, command kind, and detached result. `terminal_receipts` retains completed discard/forfeit/completion truth after the live phase returns to `NONE`; these ledgers are bounded by the same checkpoint retention policy as their board/day scope.

### Snapshot-v4 desktop aggregate

`RunSnapshotSchema` v4 adds exactly one top-level member named `desktop`. Its value has exactly two keys and no compatibility aliases:

```gdscript
{
	"board": Dictionary,       # exact DesktopBoardState.capture() value
	"consequence": Dictionary, # exact DesktopConsequenceState.capture() value
}
```

`consequence` is the sole persisted owner of causal order and recovery state:

```gdscript
{
	"schema_version": 1,
	"run_revision": int,             # >= 0
	"last_causal_sequence": int,     # >= 0; initial value 0
	"issuer_provenance": {
		"schema_version": 1,
		"namespace": String,                 # nonblank opaque lowercase hex
		"observed_counter": int,             # >= 1; evidence, never authority
		"run_id_receipt_id": String,
		"branch_id_receipt_id": String,
		"generation_receipt_id": String,
		"causal_day_receipt_id": String,
	},
	"sequence_receipts": Dictionary,
	"pending_transaction": Dictionary | null,
	"action_receipts": Dictionary,
	"destination_outbox": Dictionary,
	"notification_outbox": Dictionary,
}
```

The valid empty consequence value has `run_revision=0`, `last_causal_sequence=0`, exact issuer provenance for the already allocated New-Run identity bundle, and empty sequence/action/outbox dictionaries. `issuer_provenance` is evidence only: selectable snapshots never own or restore the monotonic issuer counter. A nonnull `pending_transaction` uses the exact union below. Unused participant receipts are null; a nonnull receipt must match both `source_kind` and the stage already crossed. There is no generic stage order:

- `minesweeper_round|shop_purchase`: `action_checkpointed -> action_prepared -> sequence_committed -> action_committed -> condition_committed -> board_fate_committed -> schedule_view_committed -> consequence_checkpointed -> publication_pending`.
- `schedule_done`: `prepared_checkpointed -> sequence_committed -> schedule_committed -> board_fate_committed -> day_start_committed -> departure_checkpointed -> publication_pending`.

Receipt ordinals are zero-based and frozen; inserting/reordering a stage requires a new schema/version rather than renumbering v1:

| Source kind | Stage -> `continuation_operation` ordinal |
|---|---|
| `minesweeper_round|shop_purchase` | `action_checkpointed=0`, `action_prepared=1`, `sequence_committed=2`, `action_committed=3`, `condition_committed=4`, `board_fate_committed=5`, `schedule_view_committed=6`, `consequence_checkpointed=7`, `publication_pending=8` |
| `schedule_done` | `prepared_checkpointed=0`, `sequence_committed=1`, `schedule_committed=2`, `board_fate_committed=3`, `day_start_committed=4`, `departure_checkpointed=5`, `publication_pending=6` |

Publication progress uses appended operation ordinals without inventing another stage. For action sources the frozen callback ordinals are `causal_sequence=9`, `action_source=10`, optional `board_fate=11`, and terminal cleanup `12`. For Schedule Done they are `causal_sequence=7`, `schedule_commit=8`, `board_fate=9`, `day_resolution_start=10`, `resolution_resume=11`, and terminal cleanup `12`. A progress checkpoint keeps `stage=publication_pending`; its unique operation ordinal and exact cursor distinguish its immutable bytes from the initial publication-pending checkpoint. An omitted optional action board callback does not renumber anything.

`action_checkpointed` means only the detached source action candidate/receipt is durable while live gameplay remains byte-equal. Under the retained lease, the coordinator deterministically prepares the sequence reservation, condition, optional board/view participants, consequence, and publication plan, then atomically writes a distinct `action_prepared` checkpoint with the complete admission payload; it never overwrites changed bytes at ordinal 0. `prepared_checkpointed` is the complete Schedule-source equivalent. The final causal-sequence/run-revision compare-and-swap is the admission point for every source kind. No cost, Schedule commit, board fate, ScheduleView, day start, action result, or outbox may mutate live state before `sequence_committed`. CAS loss marks the latest unpromoted checkpoint abandoned and releases the lease with live Schedule/view/board/day/economy unchanged. After CAS succeeds, rollback across the admission boundary is forbidden: recovery resumes the source-kind path forward exactly once. Outbox records have exact identity, source-receipt, causal-sequence, payload, and published members; this plan validates and persists their transport shape but supplies no production destination law.

The stage discriminator also fixes receipt presence; a schema-valid dictionary with the wrong presence pattern is invalid even when its stage name occurs in the graph:

- For `minesweeper_round|shop_purchase`, `action_receipt` is nonnull at every stage while `schedule_commit_receipt` and `day_start_receipt` are always null. `sequence_candidate` is null only at `action_checkpointed` and nonnull from `action_prepared` onward; before `sequence_committed` it is a reservation only. `condition_receipt` becomes nonnull exactly at/after `condition_committed`. `board_fate_receipt` is always null before `board_fate_committed`; at/after that stage it is nonnull exactly when the committed condition requested a departure, including a `fate=none` departure, and remains null for `decision=no_departure`. `schedule_view_commit_receipt` is always null before `schedule_view_committed`; at/after that stage it is nonnull exactly for a departure decision and remains null for `decision=no_departure`. A no-departure transaction still crosses the named stage as a validated no-op so every action source has one deterministic recovery graph. The destination/notification fields remain null before `consequence_checkpointed`; from there a departure has exactly one destination and no notification, while no-departure has no destination and zero or one notification.
- For `schedule_done`, `schedule_commit_receipt` and the mutation-free `sequence_candidate` are nonnull at every stage while `action_receipt`, `condition_receipt`, and `schedule_view_commit_receipt` are always null. The candidate in `prepared_checkpointed` is only a reservation and has not advanced live sequence/run revision. `board_fate_receipt` becomes nonnull exactly at/after `board_fate_committed`; `day_start_receipt` becomes nonnull exactly at/after `day_start_committed`. Destination/notification fields remain null before `departure_checkpointed`, and from there follow the exact zero-or-one intent rule.
- `checkpoint_receipt` is nonnull at every nonnull pending stage and its `pending_stage` equals the outer stage. Its disposition is `prepared_unpromoted` for `action_checkpointed`, `action_prepared`, or `prepared_checkpointed`; `admitted` only for `sequence_committed`; `forward_stage` for later stage entry; and `publication_progress` for an appended callback-progress operation. `admission_checkpoint_receipt` is null at every pre-admission stage. At `sequence_committed` it is nonnull and byte-equal to that stage's admitted `checkpoint_receipt`; every later stage preserves those admission bytes unchanged while `checkpoint_receipt` rotates to the current forward/progress receipt. `publication_progress` is null before `publication_pending` and nonnull there. A completed progress cursor is durably checkpointed before terminal cleanup clears `pending_transaction`; cleanup produces a journal-only receipt with `pending_stage=null,disposition=terminal_cleanup` and leaves no receipt field inside the now-empty pending union. No terminal `completed` alias is legal inside this union.

```gdscript
# exact pending_transaction when nonnull
{
	"transaction_id": String,
	"transaction_issuer_receipt": Dictionary,
	"request_fingerprint": String,
	"source_kind": "minesweeper_round" | "shop_purchase" | "schedule_done",
	"source_commit_receipt_id": String,
	"source_commit_receipt_provenance": Dictionary,
	"stage": String,
	"recovery_payload": Dictionary,
	"recovery_payload_sha256": String,
	"sequence_candidate": Dictionary | null,
	"action_receipt": Dictionary | null,
	"schedule_commit_receipt": Dictionary | null,
	"condition_receipt": Dictionary | null,
	"board_fate_receipt": Dictionary | null,
	"schedule_view_commit_receipt": Dictionary | null,
	"day_start_receipt": Dictionary | null,
	"destination_intent": Dictionary | null,
	"notification_intent": Dictionary | null,
	"publication_progress": Dictionary | null,
	"admission_checkpoint_receipt": Dictionary | null,
	"checkpoint_receipt": Dictionary | null,
}

# exact value in destination_outbox or notification_outbox
{
	"intent_id": String,
	"intent_id_provenance": Dictionary,
	"source_commit_receipt_id": String,
	"source_commit_receipt_provenance": Dictionary,
	"causal_sequence": int,
	"payload": Dictionary,
	"published": bool,
}
```

`published=false` means no designated downstream consumer has yet returned a
durable acceptance receipt for these exact intent bytes. `published=true`
means only that such acceptance is durable; it does **not** mean a Hospital
timeline, deferred P–L scene, notification presentation, Day-7 ending plan, or
playback has physically completed. The acceptance receipt and any later
presentation-completion receipts belong to the designated downstream owner's
persisted delivery/resolution state and are deliberately not added to this v1
outbox record.

Plan 03's sole `DesktopIntentOutboxDispatcher` must drive that Boolean through
the narrow state transition below; no scene, signal handler, consumer, or
direct dictionary write may set it. This v1/Plan-03 dispatcher offers only a
Days-1–6 `hospital_day` destination to `ConditionHospitalResolutionPort` and a
notification to `DesktopNoDepartureNotificationPort`; it never offers Day 7.
After eligible consumer acceptance it uses
its sole `DesktopOutboxAckCheckpointPort` for the recoverable adoption:

```gdscript
# DesktopConsequenceState.gd addition; this does not change either frozen
# source-kind stage graph or any stage/callback/cleanup ordinal.
func prepare_outbox_publication(request: Dictionary) -> Dictionary
```

The request is exactly:

```gdscript
{
	"outbox_kind": "destination" | "notification",
	"intent_id": String,
	"expected_unpublished_record": Dictionary,
	"consumer_acceptance_receipt": Dictionary,
}
```

`consumer_acceptance_receipt` is one exact closed variant:

```gdscript
# notification acceptance
{
	"acceptance_kind": "notification_intent",
	"receipt_id": String,
	"receipt_provenance": Dictionary,
	"consumer_id": "desktop_no_departure_notification",
	"outbox_kind": "notification",
	"intent_id": String,
	"intent_id_provenance": Dictionary,
	"payload_sha256": String,
	"status": "accepted",
}

# Days 1–6 condition-Hospital destination acceptance
{
	"acceptance_kind": "condition_hospital_resolution",
	"receipt_id": String,
	"receipt_provenance": Dictionary,
	"consumer_id": "condition_hospital_resolution",
	"outbox_kind": "destination",
	"intent_id": String,
	"intent_id_provenance": Dictionary,
	"condition_receipt_id": String,
	"accepted_source_receipt_ids": Array[String],
	"payload_sha256": String,
	"status": "accepted",
}
```

`expected_unpublished_record` is byte-equal to the current exact outbox record
with `published=false`. The retained Plan-03 dispatcher must first validate the
full acceptance provenance through the production issuer and the configured
consumer's root-scoped ledger. For `hospital_day`, durable acceptance lives in
the sole `ConditionHospitalState`, keyed by destination `intent_id`; later
Hospital/deferred presentation progress lives in `ConditionHospitalPlan` under
`ConditionHospitalCoordinator`. Notification acceptance requires
`receipt_id == intent_id`, byte-equal receipt/intent provenance, and existing
child kind `notification_intent`; it allocates no root or child. Condition-
Hospital acceptance instead requires Plan 03's exact persisted
`hospital_resolution` receipt/provenance: it is derived under the same verified
source-action root as the destination and binds that destination intent, its
condition receipt, and the exact lexically sorted accepted-source receipt IDs.
Those IDs must equal the Hospital payload's issuer-validated accepted/read,
unfulfilled source set. It uses the already registered child kind
`hospital_resolution`, never `destination_intent` as a fake resolution and
never a new `outbox_delivery`/acceptance child kind; the separately carried
`intent_id_provenance` must still validate as the existing `destination_intent`
child under that same root. This v1/Plan-03 method contract rejects every Day-7
destination, which therefore remains `published=false` throughout this suite.
`dwm-oyo.6` may add a successor third acceptance variant under its own later
plan/authority using a registered existing semantic identity; it may not
reinterpret either variant here or write the bit directly. This pure state method then requires
`pending_transaction == null`, exact map-key/intent/provenance/outbox-kind
agreement, and `payload_sha256 == H(expected_unpublished_record.payload)`.
Success is exactly
`value={consequence_candidate,consumer_acceptance_receipt}` with an outer
receipt byte-equal to `consumer_acceptance_receipt`; the candidate is the
complete detached current consequence state with only that one record's
`published` member changed to true. `capture()` plus the existing `commit()`
are the sole live adoption seam. A byte-identical replay after the true state
is durable returns the same candidate/receipt when the current record differs
from `expected_unpublished_record` only by `published=true`; changed payload,
identity, provenance, consumer, receipt, or another live-state difference
conflicts before mutation. The designated consumer's persisted acceptance truth
remains the retry authority because this v1 record intentionally stores no
acceptance receipt. Plan 03's sole external `ConditionHospitalDeliveryLedger`
at fixed root-scoped path `condition-hospital-deliveries.json` stores both closed
acceptance variants in exact document `{schema_version:1,records:Dictionary}`.
The map key is `outbox_kind + ":" + intent_id`; each value is exactly
`{key,identity_context,outbox_record,outbox_record_sha256,consumer_acceptance_receipt,presentation_state,presentation_receipt}`,
where `identity_context` is exact `{run_id,branch_id,desktop_timeline_generation,causal_day_instance}`
derived from the issuer-validated source action/condition/outbox ancestry rather
than a caller or UI.
For condition-Hospital, the dispatcher records and atomically re-reads the
acceptance only after `ConditionHospitalResolutionPort` has durably checkpointed
the active plan and returned that exact receipt, and always before requesting
the outbox-ack checkpoint. For notification, the notification port atomically
records the queued acceptance before it may return or emit. Both paths return
byte-identical ledger replay and reject changed bytes at an occupied key.
Hospital records require `presentation_state="not_applicable"` and null
presentation receipt because Hospital progress belongs only to the lifecycle
`ConditionHospitalPlan`; notification records use `queued|null` until their
separate physical UI acknowledgement is durably recorded as
`acknowledged|nonnull`. Current delivery/ack queries require byte-equal identity
context; New Run/selected Load does not delete historical records or allow them
to present in another run/branch/generation/day. This ledger is nonselectable and never substitutes for
the lifecycle plan, Hospital/deferred completion, or day-advance truth.
Hospital miss, optional witness, and Hospital/deferred presentation-completion
receipts remain distinct from this durable acceptance and may not borrow a
`P01.*` Schedule-Done row.

At `publication_pending`, `publication_progress` is exactly the following state and lives outside `recovery_payload`; therefore advancing it never changes `recovery_payload_sha256` or `publication_plan_sha256`:

```gdscript
{
	"publication_plan_sha256": String,
	"callback_ids": Array[String],
	"next_callback_index": int,
	"callback_receipts": Dictionary,
}
```

`callback_ids` is exactly the applicable ordered list frozen in the appended-ordinal table. An action no-departure list is `causal_sequence,action_source`; a departure appends `board_fate`. Schedule Done is exactly `causal_sequence,schedule_commit,board_fate,day_resolution_start,resolution_resume`. `next_callback_index` is `0..callback_ids.size()`. `callback_receipts` has exactly the completed prefix IDs as keys and no others; each value is exactly `{callback_id:String,source_receipt:Dictionary,disposition:"published"|"resolution_resumed"}` and its `callback_id` equals the map key. All prefix values use `published` except `resolution_resume`, which uses `resolution_resumed`. The initial publication-pending checkpoint has cursor zero and `{}`. Each successful callback produces one deterministic source receipt, then one appended-ordinal progress checkpoint advances the cursor by exactly one. Gaps, a receipt beyond the cursor, reordered IDs, changed source receipts, a plan-hash mismatch, or an extra key reject.

The callback receipt mapping is exact: causal sequence stores `{causal_sequence_receipt,admission_checkpoint_receipt}`; action source stores its `action_receipt`; board fate stores `board_fate_receipt`; Schedule commit stores `schedule_commit_receipt`; day-resolution start and resolution resume each store `day_resolution_start_receipt` under their distinct callback IDs. Participant delivery durability is exact rather than process-local: the three Plan-02 publications use the desktop publication ledger frozen below; Schedule and day-start use Plan 01's already-frozen `ScheduleFoundationPublicationLedger`; resolution resume uses the persisted plan cursor. Each participant first validates its committed owner state/receipt, then records the exact publication before any signal and returns the original semantic success after a crash; no callback relies on `publication_progress` having been written. Plan 03 adds `DayResolutionCoordinator.resume_publication(day_resolution_start_receipt) -> Dictionary`, which verifies the active plan's exact start receipt and uses the already-persisted `DayResolutionPlan` stage cursor as its durable idempotency truth: the first call requires every stage pending and returns only after ordinary `resume()` has durably checkpointed the first nonpending stage; same-receipt retry on that valid progressed plan returns the original success without calling ordinary `resume()` again; changed receipt bytes or an incompatible cursor conflict before another stage runs. Success is exactly `value={resolution_resumed:true}` with outer receipt byte-equal to the start receipt. It adds no saved field or parallel resume ledger.

Plan 02 creates one `scripts/infrastructure/save/DesktopPublicationLedger.gd` over the same exact root-scoped `StorageAdapter` object retained by bootstrap, at distinct fixed relative path `desktop-publications.json`. It is append-only and outside selectable saves, profiles, autosaves, RunSnapshot/SaveDocument, consequence checkpoints, and continuation/remap participants. Its strict schema is `schemas/save/desktop-publication-ledger.schema.json`; its document is exactly `{schema_version:1,records:Dictionary}`. Every record value is exactly:

```gdscript
{
	"key": String,
	"kind": "causal_sequence" | "action_source" | "board_fate",
	"semantic_receipt": Dictionary,
	"publication": Dictionary,
	"publication_sha256": String,
}
```

The exact interface is `const FIXED_PATH := "desktop-publications.json"`, `configure(storage)`, `load()`, and `record_before_emit(request)`. Configuration/load/storage validation, canonical UTF-8 JSON plus one LF, atomic write/re-read, same-object replay, replacement rejection, missing-file initialization, and malformed-file startup failure are byte-for-byte the Plan-01 ledger laws, but the files and kind unions are disjoint. `record_before_emit()` accepts exactly `{kind,semantic_receipt,publication,publication_sha256}`. For `causal_sequence`, semantic receipt and publication are both exactly `{causal_sequence_receipt,admission_checkpoint_receipt}` and the key is `causal_sequence:` plus `causal_sequence_receipt.receipt_id`. For `action_source`, semantic receipt is the exact `action_receipt`, publication is exactly `{action_candidate_sha256,action_receipt}`, and the key is `action_source:` plus `action_receipt.commit_receipt_id`. For `board_fate`, semantic receipt is the exact `board_fate_receipt`, publication is exactly `{board_candidate,board_fate_receipt}`, and the key is `board_fate:` plus `board_fate_receipt.receipt_id`. The ledger validates each exact kind-specific receipt/publication shape, nested receipt byte equality, key derivation, and `publication_sha256 == H(publication)`; the publishing participant must validate those bytes against its current committed owner state before calling it. Success is exactly `value={record,first_delivery},receipt={}`. A new record writes durably and returns true; byte-identical replay returns the retained record and false; an occupied key with changed receipt/publication/hash/kind returns `publication_record_conflict` without rewriting.

`DesktopCausalSequencePort`, `MinesweeperRoundCoordinator`, `MinesweeperShopPurchaseParticipant`, and `DesktopBoardFatePort` each expose exact `configure_publication_ledger(publication_ledger) -> Dictionary`. Bootstrap calls it with the same loaded ledger object before their ordinary configure seams and before input; first configuration succeeds as `value={configured:true,already_configured:false},receipt={}`, identical replay returns true/true, and replacement/missing capability fails. Their `publish()`/`publish_recovery_action()` methods validate current committed truth, call `record_before_emit()`, emit only when `first_delivery=true`, and return the original method-specific success for either delivery. A crash after ledger commit but before/after signal is the same intentional at-most-once observation boundary as Plan 01; transaction progress and canonical state never depend on receiving that signal. The two ledgers are constructed from the same storage root but are distinct identities/files, and neither accepts the other's kind.

For Schedule Done, the injected publication port exposes `publish_next(request) -> Dictionary`, where request is exactly `{publication_plan,publication_progress,admission_checkpoint_receipt}`. It validates the plan hash/cursor/admission ancestry, invokes only `callback_ids[next_callback_index]`, and returns exactly `value={callback_id,source_receipt,disposition,next_callback_index,complete}` with outer receipt byte-equal to `source_receipt`; `next_callback_index` is the old value plus one and `complete` is true exactly at list end. The action path uses the same private one-callback result contract while dispatching to its retained causal/source/optional-fate objects. The coordinator validates that result, asks `DesktopConsequenceState.prepare_recovery_advance()` for the one-prefix progress candidate, then passes both exact prepare outputs to `commit_consequence_checkpoint(checkpoint_candidate,checkpoint_receipt)` before attempting another callback. A crash after callback apply but before that progress checkpoint repeats the same callback/receipt and receives the original success; a crash after the checkpoint skips it. Only a durably complete cursor permits the terminal-cleanup checkpoint. Destination/notification dispatch is not another action callback and never extends or renumbers this prefix: only after terminal cleanup has durably made `pending_transaction=null` may Plan 03's retained outbox dispatcher offer an unpublished record to its designated consumer and use `prepare_outbox_publication()` in a separate recoverable checkpoint. A condition-driven departure keeps desktop mutation input disabled across that handoff; durable acceptance is not permission to resume source-day input.

`recovery_payload_sha256` is lowercase SHA-256 of canonical detached `recovery_payload` bytes. The discriminator must equal outer `source_kind`; unused/extra participant members reject. For `minesweeper_round|shop_purchase`, the payload is exactly:

```gdscript
{
	"schema_version": 1,
	"source_kind": "minesweeper_round" | "shop_purchase",
	"payload_phase": "source_checkpoint" | "admission_ready",
	"action_candidate": Dictionary,
	"action_candidate_sha256": String,
	"condition_candidate": Dictionary | null,
	"condition_candidate_sha256": String | null,
	"board_candidate": Dictionary | null,
	"board_candidate_sha256": String | null,
	"schedule_view_before": Dictionary | null,
	"schedule_view_before_sha256": String | null,
	"schedule_view_after": Dictionary | null,
	"schedule_view_after_sha256": String | null,
	"consequence_candidate": Dictionary | null,
	"consequence_candidate_sha256": String | null,
	"publication_plan": Array[Dictionary] | null,
	"publication_plan_sha256": String | null,
}
```

At `action_checkpointed`, `payload_phase` is exactly `source_checkpoint`: the condition, board, both ScheduleView, consequence, and publication member/hash pairs are all null, and `sequence_candidate` is null. Recovery revalidates the source candidate/checkpoint under the reacquired lease and may deterministically prepare downstream candidates again, but it cannot admit this provisional payload or change ordinal-0 checkpoint bytes. One atomic checkpoint operation installs ordinal-1 `action_prepared` with a different checkpoint ID/receipt, `payload_phase=admission_ready`, the nonnull sequence reservation, and the complete frozen payload while live state remains byte-equal. A crash before that operation restarts from the source-only bytes; a crash after it resumes only the frozen admission-ready bytes. `prepare_admission()` accepts exactly `stage=action_prepared`, `payload_phase=admission_ready`, and its matching payload hash.

For `payload_phase=admission_ready`, the condition and consequence candidates/hashes plus publication plan/hash are nonnull. The condition decision fixes the remaining optional pairs exactly: `decision=no_departure` requires the board candidate/hash and all four ScheduleView members/hashes to be null; every departure decision requires a nonnull board candidate/hash plus nonnull `schedule_view_before`, `schedule_view_before_sha256`, `schedule_view_after`, and `schedule_view_after_sha256`. A departure always carries the exact `DesktopBoardFatePort` candidate even when its receipt says `fate=none` because no board exists. The injected Plan-03-owned view port must prove that the before bytes are its exact current saved view and that the after bytes are its canonical departed/terminal view; Plan 02 treats both dictionaries as opaque primitive transport.

The action-only view participant is configured with the production condition policy by `configure_condition_departure_ports()` and has the exact surface `prepare_condition_departure(request)` and `commit_condition_departure(candidate)`. Plan 02 supplies only `FakeScheduleDepartureViewPort`; Plan 03's sole production `ScheduleDepartureViewPort` implements this surface against its one ScheduleView owner. Prepare accepts exactly `{condition_receipt:Dictionary,causal_sequence_receipt:Dictionary}` and returns exact `value={schedule_view_before:Dictionary,schedule_view_after:Dictionary}` with `receipt={}` without mutation. Commit accepts exactly `{condition_receipt:Dictionary,schedule_view_before:Dictionary,schedule_view_before_sha256:String,schedule_view_after:Dictionary,schedule_view_after_sha256:String}` and returns an outer receipt byte-equal to this exact value:

```gdscript
{
	"source_condition_receipt_id": String,
	"source_condition_receipt_provenance": Dictionary,
	"schedule_view_before_sha256": String,
	"schedule_view_after_sha256": String,
	"disposition": "condition_departure_view_committed",
}
```

The port verifies the condition receipt/provenance and both hashes under the retained `causal_transaction` lease. The Plan-03 ScheduleView owner—not `DesktopConsequenceState`—durably retains the exact receipt keyed by `source_condition_receipt_id` before returning success. An existing key with byte-identical source/hashes returns the original receipt even after pending-transaction cleanup or later view progression; changed bytes conflict. With no retained key, if live view equals the frozen before bytes the port atomically installs the frozen after bytes plus receipt; if live view already equals the frozen after bytes it durably adopts/returns that same deterministic receipt without replay; any third state returns `schedule_view_state_conflict`. The coordinator mirrors that receipt before advancing beyond `schedule_view_committed`, so a crash between view application and checkpoint persistence is an idempotent retry. No-departure never calls either view method and records no view receipt.

For `schedule_done`, the transport payload is exactly:

```gdscript
{
	"schema_version": 1,
	"source_kind": "schedule_done",
	"schedule_candidate": Dictionary,
	"schedule_candidate_sha256": String,
	"board_candidate": Dictionary,
	"board_candidate_sha256": String,
	"day_start_candidate": Dictionary,
	"day_start_candidate_sha256": String,
	"schedule_view_before": Dictionary,
	"schedule_view_before_sha256": String,
	"schedule_view_after": Dictionary,
	"schedule_view_after_sha256": String,
	"terminal_intent": Dictionary | null,
	"terminal_intent_sha256": String | null,
	"publication_plan": Array[Dictionary],
	"publication_plan_sha256": String,
}
```

Every member hash is computed from canonical detached bytes; null member/hash pairs must both be null. Plan 02 validates exact primitive transport, hash agreement, source-kind/stage compatibility, and detachment only. Plan 03 injects the authoritative Schedule, board-fate, day-start, ScheduleView, terminal-intent, and publication validators before accepting this payload. Every prepared/current checkpoint receipt binds `recovery_payload_sha256`; the immutable `admission_checkpoint_receipt` additionally remains the exact proof of the admission cut after later stage receipts rotate. Therefore startup after `sequence_committed` never reconstructs a candidate from mutable live state: it reacquires `causal_transaction`, revalidates the frozen payload through the injected validators, recognizes each already-recorded receipt, and forward-commits the next missing participant.

`publication_plan` is always an ordered `Array[Dictionary]` of non-self-referential recipes prepared before admission. No recipe may contain `admission_checkpoint_receipt`, the current `checkpoint_receipt`, a checkpoint candidate, `publication_plan_sha256`, or `recovery_payload_sha256`; those values do not exist yet or would make the payload hash circular. At publication, the coordinator reads the immutable admission receipt from the pending record, never from a recipe, and materializes the causal-sequence call as exactly `{causal_sequence_receipt,admission_checkpoint_receipt}`. The current forward-stage receipt is never a publication input.

For `minesweeper_round|shop_purchase`, the exact ordered recipes are causal sequence, action source, and—only for a departure decision—board fate:

```gdscript
[
	{
		"participant": "causal_sequence",
		"source_kind": "minesweeper_round" | "shop_purchase",
		"publication": {"causal_sequence_receipt": Dictionary},
	},
	{
		"participant": "action_source",
		"source_kind": "minesweeper_round" | "shop_purchase",
		"publication": {
			"action_candidate_sha256": String,
			"action_receipt": Dictionary,
		},
	},
	# Present exactly for a departure; absent for no_departure.
	{
		"participant": "board_fate",
		"source_kind": "minesweeper_round" | "shop_purchase",
		"publication": {
			"board_candidate": Dictionary,
			"board_fate_receipt": Dictionary,
		},
	},
]
```

For `schedule_done`, the exact four recipes are ordered `causal_sequence -> schedule_commit -> board_fate -> day_resolution_start`. Their `source_kind` is exactly `schedule_done`; the causal recipe is the one-key publication above, and the remaining `publication` values are exactly `{committed_schedule,schedule_commit_receipt}`, `{board_candidate,board_fate_receipt}`, and `{resolution_plan,day_resolution_start_receipt}` respectively. Plan 03's publication owner resumes the day-resolution coordinator only after those four recipe callbacks succeed. Every recipe and nested publication is deeply detached, rejects extra keys, and is covered by `publication_plan_sha256`; semantic participant receipts inside a recipe are allowed, but admission/current checkpoint receipts are not.

Every prepared, admission, later-stage, progress, or terminal-cleanup checkpoint receipt is exactly the following shape. Every non-cleanup receipt is stored in `pending_transaction.checkpoint_receipt`; the cleanup receipt exists only in the atomic checkpoint journal because its target candidate has `pending_transaction=null`:

```gdscript
{
	"receipt_id": String,
	"receipt_provenance": Dictionary,
	"transaction_id": String,
	"transaction_issuer_receipt": Dictionary,
	"checkpoint_id": String,
	"checkpoint_sha256": String,
	"recovery_payload_sha256": String,
	"pending_stage": String | null,
	"disposition": "prepared_unpromoted" | "admitted" | "forward_stage" |
		"publication_progress" | "terminal_cleanup",
}
```

Its child kind is `continuation_operation`; ordinal is the exact zero-based source-kind stage or appended publication-operation mapping frozen above. `prepared_unpromoted` exists only in the atomic checkpoint journal and is not a selectable bundle; an action may retain distinct immutable ordinals 0 and 1, while Schedule has only ordinal 0. `admitted` requires `pending_stage=sequence_committed` and is the first promoted selectable checkpoint. `forward_stage` requires a later valid stage-entry ordinal. `publication_progress` requires `pending_stage=publication_pending`, the appended ordinal for exactly `callback_ids[next_callback_index-1]`, and a cursor advanced by one. `terminal_cleanup` alone requires `pending_stage=null`, the source-kind cleanup ordinal, a complete prior cursor, and a complete target candidate whose pending transaction is null; every other disposition requires a nonnull stage. Checkpoint ID/hash are semantic storage locators, not alternative receipt identity; duplicate operation bytes return the same receipt and changed bytes at an occupied ordinal conflict. Tests mutate every stage/ordinal/callback/cleanup pair independently and reject off-by-one, cross-source, omitted-stage, cursor gaps, a nonnull cleanup stage, and renumbered mappings.

At and after admission, `admission_checkpoint_receipt` must validate against the same transaction root and recovery-payload hash as `checkpoint_receipt`, with exact `pending_stage=sequence_committed` and `disposition=admitted`. At `sequence_committed` both fields are byte-equal. At every later operation the admission field remains byte-equal to that original receipt while only `checkpoint_receipt` advances: stage-entry ordinals use `disposition=forward_stage`, and appended callback-prefix ordinals use `pending_stage=publication_pending,disposition=publication_progress`. Save capture, strict v4 schema validation, canonical serialization, restore preparation/application, continuation remap, and duplicate recovery preserve the admission field byte-for-byte; no migration synthesizes it and no publication-plan recipe embeds it.

Checkpoint hashing is non-self-referential and has one producer. Every operation first freezes an exact header `{transaction_id:String,transaction_issuer_receipt:Dictionary,source_kind:"minesweeper_round"|"shop_purchase"|"schedule_done",source_commit_receipt_id:String,recovery_payload_sha256:String,continuation_operation_ordinal:int}` from the validated current pending transaction. Terminal cleanup freezes it before projecting pending to null. `DesktopConsequenceState.checkpoint_content_preimage(checkpoint_header,stage_candidate)` accepts that header plus the complete detached target consequence candidate before its new receipt is attached and succeeds exactly as `value={checkpoint_content_preimage},receipt={}`, where the preimage is:

```gdscript
{
	"schema_version": 1,
	"transaction_id": String,
	"transaction_issuer_receipt": Dictionary,
	"source_kind": "minesweeper_round" | "shop_purchase" | "schedule_done",
	"source_commit_receipt_id": String,
	"recovery_payload_sha256": String,
	"continuation_operation_ordinal": int,
	"consequence_candidate": Dictionary,
}
```

Every header member is copied byte-for-byte into the preimage and, while target pending is nonnull, must match its corresponding pending member and the frozen ordinal table; no value is inferred from a receipt, outbox, candidate shape, or active app. `consequence_candidate` is the complete exact target `DesktopConsequenceState` value, including schema version, run revision, causal/issuer receipts, pending transaction, action receipts, and both outboxes—not a pending-only projection. For terminal cleanup, the validated frozen header remains the only source of transaction/source identity after that complete candidate's pending value becomes null. For a nonnull pending target, the projected complete candidate retains every semantic member, including `publication_progress`, but forces only its nested `checkpoint_receipt=null`. For its own `sequence_committed` admission target only, the nested projection omits `admission_checkpoint_receipt` entirely because that receipt is being produced; at every later target it includes the already-admitted receipt byte-for-byte. No checkpoint ID, checkpoint receipt, canonical hash, clock, storage locator, or post-write byte is another preimage member.

The sole producer order is: construct and strictly validate all target semantic bytes with no new receipt -> build the exact preimage -> canonicalize it -> compute lowercase `checkpoint_sha256` -> project the exact three strings `checkpoint_sha256`, `recovery_payload_sha256`, and `source_commit_receipt_id`, reject blank/duplicate values, lexically sort them, and pass that already-sorted array to `derive_child(child_kind=continuation_operation,ordinal=<frozen operation ordinal>)` -> construct the exact checkpoint receipt -> for admission attach that same receipt to both pending receipt fields; for an ordinary forward/progress operation preserve the admission field and attach the new receipt only as current; for terminal cleanup keep the complete target candidate's pending transaction null and retain the new receipt only in the checkpoint journal -> fully validate the resulting v4 candidate/receipt relation -> atomically persist candidate plus receipt. `checkpoint_id` is a storage locator, never canonical identity, and is derived before preimage construction exactly as `"desktop_consequence_checkpoint." + sha256("desktop_consequence_checkpoint_v1\n" + checkpoint_header.transaction_id + "\n" + str(checkpoint_header.continuation_operation_ordinal))`; it is included only in the produced receipt, not in `checkpoint_content_preimage`. The exact transaction/ordinal therefore reproduces the same locator after a process crash without retained memory, a clock, or another counter. Validation repeats the same locator derivation and preimage/hash/ordinal/source-ID projection from persisted bytes, then ledger-validates the child provenance. Hashing a candidate that already contains its own current/admission receipt, deriving before semantic bytes are complete, or accepting a caller-supplied digest/locator rejects.

The configured consequence checkpoint port exposes exactly `prepare_consequence_checkpoint(checkpoint_header,stage_candidate)` and `commit_consequence_checkpoint(checkpoint_candidate,checkpoint_receipt)`. Prepare validates the exact header through `checkpoint_content_preimage()`, is mutation-free and disposable, derives the frozen locator, and succeeds exactly as `value={checkpoint_candidate,checkpoint_receipt}` with outer receipt byte-equal to `checkpoint_receipt`; its candidate is the fully receipt-attached strict v4 consequence candidate for every non-cleanup operation and the complete pending-null candidate for cleanup. Commit requires both exact members returned by prepare, recomputes their relation without relying on a process-local prepared cache, atomically persists those exact candidate/receipt bytes, and succeeds exactly as `value={checkpoint_receipt}` with that same outer receipt. Identical semantic retry returns the same locator/candidate/receipt, while a changed/missing receipt or changed header/preimage at an occupied transaction/ordinal returns `consequence_checkpoint_conflict`. No coordinator or participant computes `checkpoint_sha256`, supplies a checkpoint locator, reconstructs a cleanup header, or constructs a continuation receipt itself.

`sequence_receipts` maps transaction ID to the exact frozen causal receipt. `action_receipts` maps action commit-receipt ID to the exact `DesktopActionReceipt`. Each outbox is keyed by its exact `intent_id`; map key/value disagreement, an extra member, a published intent without its accepted sequence receipt, or simultaneous destination and notification for one source rejects. One shared `ApplicationMutationGate` owner named exactly `causal_transaction` is acquired before the first prepare and retained through forward recovery/publication. `restore` and `new_run` remain the other legal exclusive owners. The gate serializes board/Schedule/economy mutation while the persisted causal owner remains `DesktopConsequenceState`; it never becomes a second sequence or receipt ledger.

The separate append-only issuer root maps canonical counter keys to exact receipts `{receipt_id,purpose,namespace,counter,token,numeric_value}`. `purpose` is one of `run_id|branch_id|desktop_timeline_generation|causal_day_instance|board_id|transaction_id|placement_nonce|debug_nonce|explosion_nonce|receipt_id`; `numeric_value` is nonnull only for `desktop_timeline_generation`, otherwise null. A string token is `purpose + "." + sha256(namespace + "\n" + str(counter) + "\n" + purpose)`. The issuer receipt's structural key is exactly `"issuer_receipt." + sha256("desktop_issuer_receipt_v1\n" + namespace + "\n" + str(counter) + "\n" + purpose + "\n" + token)`; it consumes no second counter and cannot be caller-supplied. The generation receipt additionally binds the required nonnegative integer value. Issuance atomically advances the monotonic root counter before returning any token. `issue()` returns exact `value={token,issuer_receipt}` and an outer receipt byte-equal to `issuer_receipt`. Every initiating request carries both its semantic token and full issuer receipt; ID-only lookup, syntax, or naming conventions never prove provenance. Identical replay of the same allocation transaction returns its recorded bundle; a different request at an occupied transaction identity conflicts. A new namespace is obtained only from the injected cryptographic namespace source, persisted before counter 1 is issued, and never reconstructed from a clock or global RNG.

`derive_child()` accepts exactly `{parent_receipt_id,child_kind,ordinal,source_ids}`. It ledger-verifies the parent receipt and requires `parent.purpose == "transaction_id"`, a registered child kind, nonnegative ordinal, and already sorted unique nonblank source IDs, then returns exact `value={child_id,provenance}` with an outer receipt byte-equal to provenance. The lowercase child ID is exactly `child_kind + "." + sha256("desktop_child_v1\n" + parent.namespace + "\n" + str(parent.counter) + "\n" + parent.receipt_id + "\n" + child_kind + "\n" + str(ordinal) + "\n" + CanonicalJsonWriter.stringify(source_ids))`; callers may not submit unsorted IDs for the issuer to repair. Provenance is exactly `{schema_version,parent_receipt_id,child_kind,ordinal,source_ids,child_id}`. `validate_child()` repeats the ledger lookup, purpose check, and byte derivation. The closed v1 child-kind union is `schedule_entry|schedule_commit|day7_schedule_provenance|empty_schedule_done|contact_source|hospital_resolution|hospital_miss|sylvia_hospital_witness|day_resolution_stage|board_command|board_start|shop_quote|desktop_action|causal_sequence|condition|board_fate|destination_intent|notification_intent|continuation_operation|warning|navigation|terminal_intent`. This is the only deterministic-ID exception to root counter issuance. Every authoritative child record stores its full provenance; a reference may carry only the child ID when the referenced authoritative record/provenance remains in the same validated snapshot or external issuer ledger and dangling references reject.

Plan 02 has one authoritative production derivation table. Let `H(value)` mean lowercase SHA-256 of `CanonicalJsonWriter.stringify()` over the exact detached primitive value. For every row the producer first ledger-verifies the named full parent receipt and its token, projects the exact source-value **set**, rejects blank or duplicate projected strings, sorts the resulting strings lexically by Unicode code point, and only then calls `derive_child()`; the semantic display order below is never treated as issuer input order.

| Child kind | Exact full parent/root | Ordinal | Exact source-value set |
|---|---|---:|---|
| `board_command` | the command request's purpose-`transaction_id` receipt | `0` | `{H({request_fingerprint,identity_fingerprint,command_kind,pre_revision,post_revision})}` using the exact retained command-receipt facts |
| `board_start` | the first-Reveal request's purpose-`transaction_id` receipt | `0` | `{H({identity,difficulty_id,first_cell,board_revision,rounds_before,rounds_after,motivation_before,motivation_after,layout_sha256,proof_sha256,checkpoint_id})}` |
| `shop_quote` | the quote allocation's purpose-`transaction_id` receipt | `0` | `{request_fingerprint}` from the exact immutable quote record |
| `desktop_action` | the prepared action's purpose-`transaction_id` receipt | `0` | `{action_kind,source_commit_receipt_id,H(action_candidate)}` |
| `causal_sequence` | `sequence_candidate.transaction_issuer_receipt` | `0` | `{source_commit_receipt_id,H({run_id,branch_id,desktop_timeline_generation,causal_day_instance,causal_sequence,run_revision})}` |
| `board_fate` | Schedule command root for `schedule_done`; validated action root for `condition_departure` | `0` | `{H({board_identity,board_revision,causal_day_instance,fate})}` plus `source_action_commit_receipt_id` exactly when nonnull |
| `continuation_operation` | `checkpoint_header.transaction_issuer_receipt` | exact stage/progress/cleanup ordinal frozen above | `{checkpoint_sha256,recovery_payload_sha256,source_commit_receipt_id}` |

A producer may not hash a candidate containing the child ID it is deriving, omit a listed field, add an unlisted semantic convention, reuse a root from another transaction, or choose another ordinal. `schedule_entry`, `schedule_commit`, `day7_schedule_provenance`, `empty_schedule_done`, `contact_source`, `hospital_resolution`, `hospital_miss`, `sylvia_hospital_witness`, `day_resolution_stage`, `condition`, `destination_intent`, `notification_intent`, `warning`, `navigation`, and `terminal_intent` are consumed from the exact Plan-01/Plan-03 owner contracts and have no Plan-02 production derivation call. In particular, Plan 02 validates condition/outbox transport and its contract fake may exercise supplied deterministic fixtures, but it does not mint their production children. Unit tests table-drive every Plan-02 row, permute the semantic source values before projection, mutate every parent/kind/ordinal/source member, and statically bind every production `derive_child` call to its row; deterministic evidence records this table and those source bindings.

### External continuation operation journal

`DesktopContinuationOperationJournal` stores one strict primitive `desktop-continuation-operations.json` outside Save slots, autosaves, profiles, and selectable restore participants. Its document is exactly `{schema_version:1,operations}`; `operations` is keyed by transaction ID and every value is exactly:

```gdscript
{
	"transaction_id": String,
	"transaction_issuer_receipt": Dictionary,
	"kind": "new_run" | "restore",
	"request_fingerprint": String,
	"source_locator": null | {
		"slot_id": String,
		"bundle_id": String,
		"checkpoint_id": String,
		"document_sha256": String,
	},
	"initial_context": Dictionary | null,
	"initial_context_sha256": String | null,
	"allocation_candidate_fingerprint": String,
	"stage": "intent_committed" | "identity_allocation_committed" |
		"participants_applying" | "participants_applied" |
		"completed" | "aborted",
	"allocation_receipt": Dictionary | null,
	"next_participant_index": int,
	"participant_receipts": {
		"run": Dictionary | null,
		"desktop_consequence": Dictionary | null,
		"desktop_board": Dictionary | null,
		"profile": Dictionary | null,
		"localization": Dictionary | null,
		"audio": Dictionary | null,
		"route": Dictionary | null,
		"narrative": Dictionary | null,
	},
	"failure": Dictionary | null,
}
```

The operations map key equals `transaction_id`; `transaction_issuer_receipt` is the full byte-exact purpose-`transaction_id` issuer receipt and its token equals that key. Both fingerprints and every document hash are lowercase 64-hex SHA-256 values. `failure` is null or exactly `{code:String,message:String,details:Dictionary}` with nonblank code/message and detached primitive details. New Run requires `source_locator=null` and exact detached `initial_context={route_id:"opening",dialogic_checkpoint:{},active_app_id:null,audio_context:{},content_version:int>=1}` with a matching canonical hash; restore requires both initial-context fields null. A restore locator's `slot_id` is exactly `slot:1` through `slot:7`, `quick`, or `autosave`; `bundle_id` is lowercase SHA-256 of the canonical selected `{checkpoint_kind,snapshot}` bundle; `checkpoint_id` is the nonblank ID inside that selected snapshot; and `document_sha256` hashes the complete source SaveDocument bytes. Reload must reproduce all four values, not merely find a compatible slot. The journal first commits `intent_committed`, then the issuer allocation may commit. `next_participant_index` is initially 0 and the exact live participant order is the eight keys above. Before each apply, all lower-index receipts must be nonnull and all current/higher receipts null; after an apply, its exact receipt is durably recorded and the index advances before the next participant. `participants_applied` requires index 8 and every receipt nonnull. This journal order excludes identity allocation because its dedicated `allocation_receipt`/stage precedes the live array.

New Run and selected Load acquire the one `ApplicationMutationGate` as owner `new_run` or `restore` respectively **before** issuing their transaction root or preparing an allocation candidate; they retain that lease through `completed`/pre-allocation `aborted`, and input stays disabled so no other initiating issuer consumer can interleave a counter advance. Startup lists nonterminal operations before input, reacquires the owner implied by `kind`, reloads/hash-verifies the exact restore locator or rehashes the retained New-Run initial context, and recomputes the deterministic allocation candidate. Before allocation, a proven missing/hash-changed restore source or mismatched New-Run context records `aborted` with typed failure and no live mutation. `identity_allocation_committed` is irreversible; recovery from there can only advance through `participants_applying`, `participants_applied`, and `completed`. If its required source/context can no longer be proven, startup persists the typed failure diagnostic without changing that forward stage, latches a fatal recovery failure, and leaves the retained operation/issuer high-water untouched; it never relabels an allocated operation aborted, guesses another source, enables input, or decrements the issuer.

### Materialized board

```gdscript
{
	"spec": Dictionary,
	"actual_mine_count": int,
	"effective_extra_mines": int,
	"first_cell": int,
	"forced_cell": int | null,
	"mine_indices": Array[int],
	"revealed_indices": Array[int],
	"flagged_indices": Array[int],
	"phase": "ACTIVE" | "CLEARED" | "EXPLODED",
	"exploded_index": int | null,
	"proof": Dictionary,
	"rng_states": {
		"placement": Dictionary,
		"debug": Dictionary | null,
		"explosion": Dictionary,
	},
	"hidden_explosion_classes": Dictionary,
	"action_history": Array[Dictionary],
	"paid_start_receipt": Dictionary,
}
```

All index arrays are sorted and unique. `actual_mine_count == mine_indices.size() == base_mine_count + effective_extra_mines`; the displayed mine count always comes from `actual_mine_count`. `proof` contains exact generator/verifier versions, candidate ordinal, operation count, proof-trace digest, and `certified_no_guess`; it contains no audience hint. `rng_states` stores detached post-adoption state for all three semantic streams; `debug` is null only when Debug was not used. `hidden_explosion_classes` is empty for desktop boards and, for a challenge BoardSpec, maps every mine's canonical unsigned-decimal index to exactly `hatred|upset|amused` using only `minesweeper_explosion_v1`. That auxiliary stream never changes placement, Debug search, or another RNG stream; the later relationship owner may consume the frozen map but cannot regenerate it.

### Shop capability registry

The versioned registry has exactly these records and no generic effect-string execution path:

| ID | Currency | Price | Cap | Effect |
|---|---|---:|---:|---|
| `lucky_charm` | `minesweeper_coin` | 1 | once per saved branch | future candidate gets `first_cell_zero` and floor-halved extras |
| `debug_key` | `minesweeper_coin` | 3 | once per saved branch | future candidate gets forced-cell deterministic no-guess certification |
| `supportz` | `money` | 45 | once per causal day; three per saved branch | future capacity floor decreases by one to minimum `-3` |

The baseline capability `first_cell_safe` is always present. Lucky and Debug compose; neither overrides the other.

## Interface Map

| Task | Consumes | Produces |
|---:|---|---|
| 1 (`dwm-p2r.16`) | Existing bootstrap/run vocabulary + accepted item law + green Plan-01 Task-2 Schedule registry | Sole DataCatalog projection integration, Shop registry, production root issuer/child verifier, external continuation journal, closed precursor evidence |
| 2 (`dwm-p2r.9` begins) | Closed `.16` + integrated Plan-01 `.13` v3 boundary | Closed desktop app registry, identity validator, host state, pure capability projection |
| 3 | Frozen `BoardSpec` | Fixed-width PRNG, board reducer, strict visible-deduction verifier |
| 4 | Tasks 2–3 | Shared pure generation kernel, pre-runtime certified fallbacks/benchmark, frozen budgets, and bounded runtime adapter with independent placement/Debug/explosion states |
| 5 | Tasks 1–4 + integrated Plan-01 `.13` GameState/v3 boundary + contract fakes only | Canonical board state and fake-checkpoint first-Reveal/routine-command coordinator |
| 6 | Task 5 + integrated Plan-01 v3 | Exact v4 `{board,consequence}` persistence, append-only identity-allocation plus two desktop restore participants, frozen stage/ordinal and provisional/full recovery transport, shared causal-sequence port, production first-Reveal checkpoint, remap, and Logout |
| 7 | Tasks 1–2 + Task-6 consequence state + GameState economy | Reversible Lucky/Debug/Supportz purchase participant and durable action outbox |
| 8 | Tasks 5–7 + shared causal-sequence port | Reversible prepared-discard/started-forfeit, source-to-admission action checkpoints, and generic action consequence/view recovery ports |
| 9 | Tasks 1–8 | Production owner injection, simulator-authority removal, contract evidence, full `.9` handoff gate |

## Task 1: Bind production identity, continuation recovery, and catalog projections (`dwm-p2r.16`)

**Requirements:** `req.desktop.registry`, `req.minesweeper.safety_capabilities`, `req.shop.capabilities`; amendment §§5, 6.6, 7.1–7.2, 8, 9.

**Hard path-ownership gate:** Plan-01 Task 2/`dwm-wks` must be closed and its exact `ScheduleActionRegistry` manifest/source tests green before this task touches DataCatalog. Require the recorded Task-2 commit SHA from Beads evidence metadata to be an ancestor of HEAD, then hash/verify `scripts/domain/schedule/ScheduleActionRegistry.gd` and its manifest. Plan 01's file map must omit DataCatalog. If the registry is absent, dirty, unrecorded, or DataCatalog still appears in another open task's file map, stop; do not create a temporary fallback table or generic provider.

**Files:**

- Create: `scripts/application/desktop/DesktopIdentityNonceIssuer.gd`
- Create: `scripts/application/run/CausalDayAdvanceIdentityPort.gd`
- Create: `scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd`
- Create: `scripts/infrastructure/identity/DesktopIssuerRootStore.gd`
- Create: `scripts/infrastructure/save/DesktopContinuationOperationJournal.gd`
- Create: `data/schemas/desktop-issuer-root.schema.json`
- Create: `data/schemas/desktop-continuation-operation-journal.schema.json`
- Create: `data/schemas/desktop-identity-issuer-boundary.schema.json`
- Create: `data/manifests/minesweeper_shop.v1.json`
- Create: `data/schemas/minesweeper-shop.schema.json`
- Create: `scripts/domain/shop/MinesweeperShopRegistry.gd`
- Create: `tests/support/FakeDesktopNamespaceSource.gd`
- Create: `tests/support/FakeDesktopIssuerRootStore.gd`
- Create: `tests/support/FakeDesktopContinuationJournalStorage.gd`
- Create: `tests/unit/test_desktop_identity_nonce_issuer.gd`
- Create: `tests/unit/test_desktop_issuer_root_store.gd`
- Create: `tests/unit/test_causal_day_advance_identity_port.gd`
- Create: `tests/unit/test_desktop_continuation_operation_journal.gd`
- Create: `tools/evidence/generate_desktop_identity_issuer_boundary.gd`
- Create: `tests/unit/tooling/test_desktop_identity_issuer_boundary.gd`
- Create generated after the code commit: `evidence/phase_2r/contracts/desktop_identity_issuer_boundary.json`
- Create generated after the code commit: `evidence/phase_2r/logs/p2r16-identity-catalog-green.log`
- Modify: `scripts/data/DataCatalog.gd`
- Modify: `tests/unit/test_shop_rules.gd`

**Interfaces:**

```gdscript
# DesktopIdentityNonceIssuer.gd
func configure(root_store: Object) -> Dictionary
func issue(purpose: StringName) -> Dictionary
func verify_issued(receipt: Dictionary, expected_purpose: StringName) -> Dictionary
func derive_child(request: Dictionary) -> Dictionary
func validate_child(provenance: Dictionary, expected_kind: StringName) -> Dictionary
func prepare_continuation_allocation(request: Dictionary) -> Dictionary
func commit_continuation_allocation(candidate: Dictionary) -> Dictionary
func prepare_causal_day_advance(request: Dictionary) -> Dictionary
func commit_causal_day_advance(candidate: Dictionary) -> Dictionary
func capture_root() -> Dictionary

# DesktopIssuerRootStore.gd
func configure(storage: Object, namespace_source: Object) -> Dictionary
func load_or_create() -> Dictionary
func issue(purpose: StringName) -> Dictionary
func verify_receipt(receipt: Dictionary, expected_purpose: StringName) -> Dictionary
func prepare_allocation(request: Dictionary) -> Dictionary
func commit_allocation(candidate: Dictionary) -> Dictionary
func prepare_causal_day_advance(request: Dictionary) -> Dictionary
func commit_causal_day_advance(candidate: Dictionary) -> Dictionary
func capture() -> Dictionary

# CausalDayAdvanceIdentityPort.gd
func configure(identity_issuer: Object) -> Dictionary
func prepare_advance(request: Dictionary) -> Dictionary
func commit_advance(candidate: Dictionary) -> Dictionary

# DesktopContinuationOperationJournal.gd
func configure(storage: Object, source_loader: Object) -> Dictionary
func prepare_intent(request: Dictionary) -> Dictionary
func commit_intent(candidate: Dictionary) -> Dictionary
func advance(request: Dictionary) -> Dictionary
func get_operation(transaction_id: String) -> Dictionary
func list_incomplete() -> Dictionary
func reconcile_startup(transaction_id: String, issuer: Object) -> Dictionary

# MinesweeperShopRegistry.gd
static func initialize(path: String = "res://data/manifests/minesweeper_shop.v1.json") -> Dictionary
static func get_record(item_id: String) -> Dictionary
static func get_ids() -> Array[String]
static func validate_all() -> Dictionary
```

`DesktopIdentityNonceIssuer.issue()` accepts the ordinary nonnumeric members of the frozen purpose union and delegates one append-only counter advance to the injected root store before returning exact `value={token,issuer_receipt}` with the same outer receipt. Direct `issue(&"desktop_timeline_generation")` returns `generation_allocation_required`; direct `issue(&"causal_day_instance")` returns `causal_day_advance_allocation_required`. The continuation allocator alone may mint the initial New-Run/restore causal-day receipt, and the shared day-advance allocator below alone may mint a later one. `verify_issued()` rejects an ID-only, structurally valid but absent, wrong-purpose, or byte-changed receipt. `derive_child()` and `validate_child()` implement the frozen anchored-child contract above against that same ledger. `prepare_continuation_allocation()` accepts exactly `{transaction_id,transaction_issuer_receipt,kind,existing_run_id,source_desktop_timeline_generation,remap_source_transaction_ids}` where `kind=new_run|restore`; New Run requires both nullable source fields null and an empty remap array, while restore requires a nonblank existing run, nonnegative source generation, and the already sorted unique complete set of rewindable source transaction IDs discovered by the validated source scanner. Prepare is mutation-free and returns the exact proposed New-Run run/branch/generation-zero/causal-day bundle or restore fresh-branch/source-plus-one-generation/causal-day bundle plus a fresh root transaction receipt for every remap source and one root candidate. `commit_continuation_allocation(candidate)` repeats root namespace/counter/request validation and atomically persists that exact bundle. A failed durable advance returns no token. Identical allocation transaction and request bytes return the original bundle; changed bytes conflict. The selectable run snapshot receives full current causal-day issuer provenance plus other required receipt IDs and can never lower, replace, or restore root state.

`CausalDayAdvanceIdentityPort` is the one shared allocator consumed by Plan 01's Schedule-Done `increment_day` stage and Plan 03's condition-Hospital `advance_day` stage. `configure()` retains the exact already-loaded issuer once; identical replay succeeds and replacement fails. `prepare_advance()` accepts exactly:

```gdscript
{
	"resolution_kind": "schedule_done" | "condition_hospital",
	"source_resolution_receipt": Dictionary,
	"run_id": String,
	"branch_id": String,
	"desktop_timeline_generation": int,
	"source_day": int,
	"source_causal_day_instance": String,
	"source_causal_day_instance_issuer_receipt": Dictionary,
}
```

`source_day` is `1..6` and the port derives `target_day = source_day + 1`; no caller supplies a target day, target identity, counter, key, or hash. Before calling the shared port, `DayResolutionCoordinator` must require the `schedule_done` source receipt to be byte-equal to the active `DayResolutionPlan.day_resolution_start_receipt`, while Plan 03's `ConditionHospitalDayAdvancePort` must require the `condition_hospital` source receipt to be byte-equal to the active `ConditionHospitalPlan.resolution_receipt`; each consumer also requires the request's run/branch/generation/source-day/source-identity/full-receipt tuple to be byte-equal to its current lifecycle context. The port itself has only its frozen `identity_issuer` dependency: it exact-key-validates the request, issuer-ledger-validates the registered resolution child kind/provenance and full source causal-day receipt, rejects cross-variant ancestry, and requires that receipt's purpose/token equal `causal_day_instance`/`source_causal_day_instance`. Neither the port nor its root store performs an unstated selectable-lifecycle lookup.

Prepare is mutation-free and succeeds exactly as `value={day_advance_identity_candidate,day_advance_identity_receipt}`, with outer receipt byte-equal to `day_advance_identity_receipt`. The candidate is exactly `{day_advance_identity_receipt}`. The receipt is exactly:

```gdscript
{
	"schema_version": 1,
	"allocation_key": String,
	"resolution_kind": "schedule_done" | "condition_hospital",
	"source_resolution_receipt_id": String,
	"source_resolution_receipt_provenance": Dictionary,
	"source_resolution_receipt_sha256": String,
	"run_id": String,
	"branch_id": String,
	"desktop_timeline_generation": int,
	"source_day": int,
	"target_day": int,
	"source_causal_day_instance": String,
	"source_causal_day_instance_receipt_id": String,
	"source_causal_day_instance_issuer_receipt": Dictionary,
	"target_causal_day_instance": String,
	"target_causal_day_instance_issuer_receipt": Dictionary,
	"request_sha256": String,
	"root_before_fingerprint": String,
	"counter_start": int,
	"counter_end": int,
	"disposition": "causal_day_advance_identity_allocated",
}
```

`allocation_key` is exactly `resolution_kind + ":" + source_resolution_receipt_id`; both SHA fields are lowercase SHA-256 over canonical exact bytes. The receipt's `source_causal_day_instance_receipt_id` is derived from the request's full receipt, and its embedded source receipt is byte-equal to both that request field and the external-root record. The target receipt is a normal existing issuer receipt with purpose `causal_day_instance`, token equal to `target_causal_day_instance`, and `counter_end == counter_start + 1`. `commit_advance()` delegates only to the issuer/root atomic commit and succeeds exactly as `value={day_advance_identity_receipt}`, with the same outer receipt. That one atomic root write adds the target issuer receipt, adds the exact allocation record, and advances `next_counter`; no target becomes durable separately from its key.

The root map key is unique, and the tuple `(run_id,branch_id,desktop_timeline_generation,source_causal_day_instance,source_day)` may belong to only one allocation key across both variants. An occupied key plus byte-identical request returns the original candidate/receipt even after later counter advances; changed request bytes or a second key for the tuple returns `causal_day_advance_identity_conflict`. For an absent key, commit requires the exact prepared root fingerprint/counter; an intervening allocation returns `causal_day_advance_identity_stale` and the caller must reprepare before exposing or checkpointing a target. Allocation is irreversible and never rolled back.

`DesktopContinuationOperationJournal.prepare_intent()` accepts exactly `{transaction_id,transaction_issuer_receipt,kind,request_fingerprint,source_locator,initial_context,initial_context_sha256,allocation_candidate_fingerprint}` and returns a mutation-free candidate. `commit_intent()` durably installs only that exact candidate. `advance()` accepts exactly `{transaction_id,request_fingerprint,expected_stage,expected_next_participant_index,next_stage,allocation_receipt,participant_name,participant_receipt,failure}`. Allocation fields are nonnull only for the transition to `identity_allocation_committed`; participant fields are nonnull only for the exact next ordered participant. A nonnull failure either accompanies pre-allocation `aborted`, or records an irreversible-recovery diagnostic while `next_stage == expected_stage` at/after `identity_allocation_committed` with all allocation/participant fields null; the latter never relabels the operation terminal or permits input. On a later process startup, that diagnostic may be cleared only after the original source/context proof succeeds byte-for-byte, then normal forward advancement resumes. Duplicate identical advancement returns the retained operation, while a skipped index, overwritten receipt, changed fingerprint, illegal stage, or different diagnostic conflicts before storage mutation.

Task 1 is the sole plan-suite owner of `scripts/data/DataCatalog.gd`. It removes `_SCHEDULE_ROWS` and the three duplicate Shop rows, delegates Schedule projection directly to the already-green Plan-01 `ScheduleActionRegistry`, and delegates only the three Shop item IDs to `MinesweeperShopRegistry`; every later task consumes those registries without reopening DataCatalog. Plan 01 MUST NOT edit DataCatalog, so this path has one boundary and no merge owner.

- [ ] **Step 1.1: Add parse-only skeletons, then write behavioral RED contract tests**

Create every new Task-1 GDScript with its declared class/interface, typed signatures, and a deterministic `not_implemented` failure envelope; create valid empty schema/manifest JSON. Use `DynamicScriptProbe` to assert every new script loads before adding behavioral assertions. A parser/load failure is a setup defect and MUST be fixed before recording RED; skeletons contain no successful behavior.

```gdscript
func test_issuer_advances_persisted_counter_before_returning_a_token() -> void:
	var issued := _issuer_with_namespace("11".repeat(32), 7).issue(&"debug_nonce")
	assert_true(issued["ok"])
	assert_eq(issued["receipt"]["counter"], 7)
	assert_eq(_issuer_root.capture()["value"]["next_counter"], 8)
	assert_eq(_issuer_root.last_committed_receipt, issued["receipt"])
```

Cover the full issuer purpose union across ordinary direct issuance plus the two atomic allocators, including direct generation/causal-day rejection, exact generation 0/source+1, initial causal-day/full-receipt allocation, full-receipt verification, every anchored child kind, forged/missing parent rejection, New-Run/restore bundle allocation, duplicate allocation equality, changed allocation conflict, namespace initialization, occupied-counter conflict, durable-write failure, proof that no API lowers the counter, and post-call mutation. Table-drive both day-advance variants, exact request/result/record shapes, derived target day, full source/target issuer receipts, identical key retry across restart, changed-key/request conflict, duplicate source-day tuple rejection, interleaving stale prepare/reprepare, atomic receipt/map/counter commit, and every crash cut before/after root commit. Independently assert the exact root-document key set, empty `day_advance_allocation_receipts` default, schema rejection for missing/extra/malformed entries, capture detachment, disjoint allocation-map key laws, persistence/reload, and rejection of deletion/replacement or a source/target receipt not byte-equal to `receipts`. Cover external-journal exact schema, intent-before-allocation, every legal/illegal stage edge, source locator/hash mismatch, duplicate equality, changed transaction conflict, incomplete listing, startup forward reconciliation, pre-allocation abort, and irreversible allocation retention. Assert exact Schedule/Shop registry-to-DataCatalog parity here.

- [ ] **Step 1.2: Run behavioral RED**

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r16_identity_catalog_red' -LogName 'p2r16-identity-catalog-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_identity_nonce_issuer.gd,res://tests/unit/test_desktop_issuer_root_store.gd,res://tests/unit/test_causal_day_advance_identity_port.gd,res://tests/unit/test_desktop_continuation_operation_journal.gd,res://tests/unit/tooling/test_desktop_identity_issuer_boundary.gd,res://tests/unit/test_shop_rules.gd','-gexit')
```

Expected: every script and fixture parses, then assertions fail only with typed `not_implemented`/wrong-behavior results. Any load error invalidates RED.

- [ ] **Step 1.3: Implement the catalog projections, issuer root, anchored-child verifier, and journal**

Use exact-key validation and detached returns. Issuer token/child construction uses only the frozen domain-separated preimages; production methods contain no time/global-RNG fallback. Initialize and validate both disjoint allocation maps in the root schema/default/capture path; `commit_causal_day_advance()` performs one atomic storage replacement containing the new target receipt, exact day-advance allocation record, and incremented counter. The journal uses injected atomic storage and source-loader contracts, never SaveManager's selectable snapshot document. DataCatalog contains no fallback/duplicate Schedule or capability fact.

- [ ] **Step 1.4: Run ordinary GREEN before the code commit**

Run the same focused files through the isolated wrapper's ordinary isolated log only, then scan. The permanent evidence log does not exist yet and MUST NOT be written into the code-boundary worktree:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r16_identity_catalog_green' -LogName 'p2r16-identity-catalog-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_identity_nonce_issuer.gd,res://tests/unit/test_desktop_issuer_root_store.gd,res://tests/unit/test_causal_day_advance_identity_port.gd,res://tests/unit/test_desktop_continuation_operation_journal.gd,res://tests/unit/tooling/test_desktop_identity_issuer_boundary.gd,res://tests/unit/test_shop_rules.gd','-gexit')
rg -n "Time\.|randi\(|RandomNumberGenerator|instance_id|_SCHEDULE_ROWS" scripts/application/desktop/DesktopIdentityNonceIssuer.gd scripts/infrastructure/identity scripts/infrastructure/save/DesktopContinuationOperationJournal.gd scripts/data/DataCatalog.gd
```

Expected: tests exit 0; scan has zero identity fallback or duplicate Schedule-table hits. `CryptoDesktopNamespaceSource` may use only its owned cryptographic source API and is reviewed directly.

- [ ] **Step 1.5: Proposed commit boundary**

Exact code-boundary paths: every Task-1 path above except both generated-after-code-commit paths—the boundary record and permanent focused log—leaving twenty-two non-UID paths. Optional-present UID paths: all created GDScript files with `.uid`. Proposed subject:

```text
feat(desktop): bind production identity issuance and catalog projections
```

Invoke `Invoke-ExactPathCommit.ps1` only after capturing the exact current HEAD and only if separate commit authority exists.

- [ ] **Step 1.6: Generate the non-self-referential boundary record**

Only after the authorized `.16` code commit exists, run the exact focused command below from that clean code subject so the permanent focused log is created beside the future record, then pass the exact code SHA and exact log path to `generate_desktop_identity_issuer_boundary.gd`:

```powershell
$boundaryCommit = (git rev-parse HEAD).Trim()
if ($boundaryCommit -cnotmatch '^[0-9a-f]{40}$') { throw 'invalid .16 code commit' }
if ((git log -1 --format=%s) -cne 'feat(desktop): bind production identity issuance and catalog projections') { throw '.16 code subject mismatch' }
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r16_identity_catalog_evidence' -LogName 'p2r16-identity-catalog-evidence.log' -EvidenceLogPath 'evidence/phase_2r/logs/p2r16-identity-catalog-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_identity_nonce_issuer.gd,res://tests/unit/test_desktop_issuer_root_store.gd,res://tests/unit/test_causal_day_advance_identity_port.gd,res://tests/unit/test_desktop_continuation_operation_journal.gd,res://tests/unit/tooling/test_desktop_identity_issuer_boundary.gd,res://tests/unit/test_shop_rules.gd','-gexit')
if ($LASTEXITCODE -ne 0) { throw '.16 permanent focused evidence failed' }
$commitArg = "--boundary-commit=$boundaryCommit"
$logArg = '--focused-log=res://evidence/phase_2r/logs/p2r16-identity-catalog-green.log'
$outputArg = '--output=res://evidence/phase_2r/contracts/desktop_identity_issuer_boundary.json'
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r16_identity_boundary_generate' -LogName 'p2r16-identity-boundary-generate.log' -GodotArgs @('-s','res://tools/evidence/generate_desktop_identity_issuer_boundary.gd','--',$commitArg,$logArg,$outputArg,'--write')
if ($LASTEXITCODE -ne 0) { throw '.16 boundary generation failed' }
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r16_identity_boundary_check' -LogName 'p2r16-identity-boundary-check.log' -GodotArgs @('-s','res://tools/evidence/generate_desktop_identity_issuer_boundary.gd','--',$commitArg,$logArg,$outputArg,'--check')
if ($LASTEXITCODE -ne 0) { throw '.16 boundary byte check failed' }
```

The generator accepts exactly `--boundary-commit`, `--focused-log`, `--output`, and one of `--write|--check`. It requires `schema_version=1`, `owner_beads_id="dwm-p2r.16"`, and the exact subject above, proves that commit is an ancestor of current HEAD, hashes every bound source from that commit tree and the focused log bytes, validates exact schema, and writes canonical `evidence/phase_2r/contracts/desktop_identity_issuer_boundary.json` with exactly `{schema_version,owner_beads_id,boundary_subject,boundary_commit,issuer_path,issuer_sha256,root_store_path,root_store_sha256,day_advance_identity_port_path,day_advance_identity_port_sha256,operation_journal_path,operation_journal_sha256,data_catalog_path,data_catalog_sha256,schedule_registry_path,schedule_registry_sha256,shop_registry_path,shop_registry_sha256,public_surface_sha256,root_store_public_surface_sha256,day_advance_identity_port_public_surface_sha256,focused_log_path,focused_log_sha256}`. `focused_log_path` is exactly `evidence/phase_2r/logs/p2r16-identity-catalog-green.log`; `day_advance_identity_port_path` is exactly `scripts/application/run/CausalDayAdvanceIdentityPort.gd`; all other source paths are exact repository-relative paths to `DesktopIdentityNonceIssuer.gd`, `DesktopIssuerRootStore.gd`, `DesktopContinuationOperationJournal.gd`, `DataCatalog.gd`, `ScheduleActionRegistry.gd`, and `MinesweeperShopRegistry.gd`, and the schema rejects another path. `public_surface_sha256` is the lowercase SHA-256 of this exact UTF-8/LF string, including its final newline: `configure(root_store)\nissue(purpose)\nverify_issued(receipt,expected_purpose)\nderive_child(request)\nvalidate_child(provenance,expected_kind)\nprepare_continuation_allocation(request)\ncommit_continuation_allocation(candidate)\nprepare_causal_day_advance(request)\ncommit_causal_day_advance(candidate)\ncapture_root()\n`. `root_store_public_surface_sha256` uses exact preimage `configure(storage,namespace_source)\nload_or_create()\nissue(purpose)\nverify_receipt(receipt,expected_purpose)\nprepare_allocation(request)\ncommit_allocation(candidate)\nprepare_causal_day_advance(request)\ncommit_causal_day_advance(candidate)\ncapture()\n`; `day_advance_identity_port_public_surface_sha256` uses exact preimage `configure(identity_issuer)\nprepare_advance(request)\ncommit_advance(candidate)\n`. Commit exactly the generated record plus its permanent focused log under separate authorization with subject `docs(phase2r): record desktop identity issuer boundary`; the evidence commit therefore contains both blobs Plan 03 later verifies with `git show`, and the record names the preceding code commit, never itself. Close `dwm-p2r.16` only after both commits and focused evidence are integrated. Plan-01 Task 3 cannot start until `.16` is closed, both commits are ancestors, and all recorded hashes match current files. That current-working-tree byte invariant remains mandatory only through the close of `dwm-p2r.9`; afterward the v1 record is immutable historical evidence of its named commit, and later plans validate its commit ancestry/recorded tree bytes rather than requiring legitimately evolved current files to equal v1 or refreshing v1 hashes.

`test_desktop_identity_issuer_boundary.gd` therefore has a permanent default mode that validates the immutable record, named commit/subject/ancestry, and recorded-tree bindings without comparing v1 digests to current working-tree files. Current-file comparison is an additional branch enabled only by exact environment value `DWM_REQUIRE_CURRENT_P2R16_BOUNDARY=1`; no default full-suite run sets it. Run that branch after record generation, at `.9` entry, and immediately before `.9` closure:

```powershell
$had_current_boundary = Test-Path Env:DWM_REQUIRE_CURRENT_P2R16_BOUNDARY
$previous_current_boundary = if ($had_current_boundary) { $env:DWM_REQUIRE_CURRENT_P2R16_BOUNDARY } else { $null }
try {
	$env:DWM_REQUIRE_CURRENT_P2R16_BOUNDARY = '1'
	& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r16_identity_boundary_current' -LogName 'p2r16-identity-boundary-current.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_desktop_identity_issuer_boundary.gd','-gexit')
	if ($LASTEXITCODE -ne 0) { throw 'desktop identity current-byte handoff failed' }
} finally {
	if ($had_current_boundary) { $env:DWM_REQUIRE_CURRENT_P2R16_BOUNDARY = $previous_current_boundary } else { Remove-Item Env:DWM_REQUIRE_CURRENT_P2R16_BOUNDARY -ErrorAction SilentlyContinue }
}
```

### `dwm-p2r.16` closure gate

- [ ] `dwm-wks` is closed and DataCatalog delegates Schedule/Shop facts with zero duplicate rows or fallback table.
- [ ] Issuer/root/child-kind/continuation-journal exact schemas, forged-provenance tests, crash-stage tests, and static time/global-RNG scan are green.
- [ ] The code boundary uses exact subject `feat(desktop): bind production identity issuance and catalog projections`; the generated boundary record names that commit and all digests revalidate.
- [ ] The separately authorized boundary-record commit is integrated, `.16` evidence metadata names both SHAs/logs, and `git diff --check` plus exact-path status are clean.
- [ ] Only then close `.16`; do not claim `.9` in this task or treat an in-progress `.16` as consumable authority.

## Task 2: Freeze desktop host/identity and project Lucky, Debug, and Supportz capabilities

**Requirements:** `req.desktop.registry`, `req.desktop.host`, `req.minesweeper.safety_capabilities`, `req.shop.capabilities`; amendment §§5, 7.1–7.2, 8, 9.

**`.9` entry gate:** do not claim `dwm-p2r.9` or edit a Task-2 path until `bd show dwm-p2r.16 dwm-p2r.13 --json` proves both closed, the `.16` issuer/DataCatalog boundary record validates byte-for-byte against current files, and `evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json` passes the exact ancestry/source/log checks in Task 6 Step 6.1. Record the two boundary SHAs in `.9` execution evidence. Re-run the `.16` current-byte validator at the final `.9` gate; this temporary handoff pin expires only when `.9` closes. After closure, consumers validate the immutable v1 record against its named commit tree plus ancestry, not against current working-tree bytes. An in-progress `.16`, a merely matching commit subject, or updating v1 hashes to follow later edits does not satisfy this gate.

Run the Task-6 Step-6.1 block unchanged, then run this exact `.16` half of the entry gate from repository root:

```powershell
$had_current_boundary = Test-Path Env:DWM_REQUIRE_CURRENT_P2R16_BOUNDARY
$previous_current_boundary = if ($had_current_boundary) { $env:DWM_REQUIRE_CURRENT_P2R16_BOUNDARY } else { $null }
try {
	$env:DWM_REQUIRE_CURRENT_P2R16_BOUNDARY = '1'
	& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_identity_boundary_gate' -LogName 'p2r9-identity-boundary-gate.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_desktop_identity_issuer_boundary.gd','-gexit')
	if ($LASTEXITCODE -ne 0) { throw 'desktop identity issuer boundary validator failed' }
} finally {
	if ($had_current_boundary) { $env:DWM_REQUIRE_CURRENT_P2R16_BOUNDARY = $previous_current_boundary } else { Remove-Item Env:DWM_REQUIRE_CURRENT_P2R16_BOUNDARY -ErrorAction SilentlyContinue }
}
$issuer_boundary = Get-Content -Raw 'evidence/phase_2r/contracts/desktop_identity_issuer_boundary.json' | ConvertFrom-Json
if ($issuer_boundary.schema_version -ne 1 -or $issuer_boundary.owner_beads_id -ne 'dwm-p2r.16' -or $issuer_boundary.boundary_subject -ne 'feat(desktop): bind production identity issuance and catalog projections') { throw 'invalid desktop identity boundary identity' }
if ($issuer_boundary.boundary_commit -cnotmatch '^[0-9a-f]{40}$') { throw 'invalid desktop identity boundary commit SHA' }
$issuer_subject = git show -s --format=%s $issuer_boundary.boundary_commit
if ($LASTEXITCODE -ne 0 -or $issuer_subject -cne $issuer_boundary.boundary_subject) { throw 'desktop identity boundary commit subject mismatch' }
git merge-base --is-ancestor $issuer_boundary.boundary_commit HEAD
if ($LASTEXITCODE -ne 0) { throw 'desktop identity boundary is not integrated' }
```

Expected: both source-bound validators and both ancestry checks exit 0 before the first Task-2 edit.

**Files:**

- Create: `scripts/domain/desktop/DesktopAppRegistry.gd`
- Create: `scripts/domain/desktop/DesktopIdentity.gd`
- Create: `scripts/domain/desktop/DesktopAppHostState.gd`
- Create: `scripts/domain/minesweeper/MinesweeperCapabilityRules.gd`
- Create: `tests/unit/test_desktop_contracts.gd`
- Create: `tests/unit/test_minesweeper_capabilities.gd`

**Interfaces:**

```gdscript
# DesktopAppRegistry.gd
static func get_ids() -> Array[StringName]
static func has_app(app_id: StringName) -> bool
static func get_record(app_id: StringName) -> Dictionary
static func validate_all() -> Dictionary

# DesktopIdentity.gd
static func validate(identity: Dictionary) -> Dictionary
static func fingerprint(identity: Dictionary) -> Dictionary
static func remap(identity: Dictionary, branch_id: String,
		timeline_generation: int, causal_day_instance: String) -> Dictionary

# DesktopAppHostState.gd
func reset(current_day: int) -> void
func open_app(app_id: StringName, current_day: int, board_phase: StringName) -> Dictionary
func go_home(current_day: int, board_phase: StringName) -> Dictionary
func change_day(new_day: int, board_phase: StringName) -> Dictionary
func get_state() -> Dictionary
func capture_persistent_state() -> Dictionary
func prepare_restore(active_app_id: Variant, current_day: int) -> Dictionary

# MinesweeperCapabilityRules.gd
static func resolve_owned(inventory: Dictionary) -> Dictionary
static func build_spec_inputs(owned: Dictionary, pressure: int,
		penalty_points_today: int) -> Dictionary
static func supportz_eligible(state: Dictionary) -> Dictionary
static func prepare_supportz_effect(state: Dictionary, causal_day_instance: String,
		transaction_id: String) -> Dictionary
```

`resolve_owned()` returns exact `value={capability_ids}` with sorted IDs: baseline `first_cell_safe`, then optional `first_cell_zero`, then optional `forced_no_guess`. `supportz_eligible()` counts exactly two terminal desktop completion receipts for base ordinals 1 and 2 in the current causal-day instance; it rejects challenge, forfeit, prepared, another-day, and ordinal 3–5 receipts.

Host success has exact `value={state,commands}`. Commands are ordered dictionaries with `kind=open_app|hide_app|suspend_board|resume_board|discard_candidate|forfeit_board`, registered `app_id` where applicable, and no costs/effects. The host may request a board action but cannot mutate board truth. `capture_persistent_state()` remains exactly `{"active_app_id": String|null}`; cached scene identities are runtime-only.

- [ ] **Step 2.1: Write RED parity and composition tests**

```gdscript
func test_registry_is_the_closed_seven_app_set() -> void:
	assert_eq(DesktopAppRegistry.get_ids(), [
		&"minesweeper", &"contacts", &"schedule", &"shop",
		&"backup", &"settings", &"logout",
	])

func test_home_suspends_a_started_board_without_eviction() -> void:
	var host := DesktopAppHostState.new()
	host.reset(3)
	host.open_app(&"minesweeper", 3, &"ACTIVE_VISIBLE")
	var result := host.go_home(3, &"ACTIVE_VISIBLE")
	assert_eq(result["value"]["commands"], [{"kind":"suspend_board"}, {"kind":"hide_app","app_id":"minesweeper"}])

func test_lucky_and_debug_compose_in_both_purchase_orders() -> void:
	var both_a := MinesweeperCapabilityRules.resolve_owned({"lucky_charm":1,"debug_key":1})
	var both_b := MinesweeperCapabilityRules.resolve_owned({"debug_key":1,"lucky_charm":1})
	assert_eq(both_a, both_b)
	assert_eq(both_a["value"]["capability_ids"], ["first_cell_safe","first_cell_zero","forced_no_guess"])

func test_supportz_requires_two_current_day_base_completions() -> void:
	# Feed exact ordinal-1 and ordinal-2 completion receipts; replace each in turn
	# with forfeit, challenge, stale-day, and ordinal-3 receipts and assert false.
```

Also cover unknown apps, invalid days, no-op duplicate open, Minesweeper resume, same-day switching, day-change discard/forfeit command choice, exact host/identity detachment, every malformed identity field, and proof that cached app objects never serialize. Assert exact prices/caps/effects through Task 1's immutable registry, Supportz floor `0..-3`, one daily purchase, three branch purchases, prospective-only projection, and odd raw extras floor-dividing under Lucky.

- [ ] **Step 2.2: Add parse-only skeletons and run behavioral RED**

Create all four Task-2 production scripts with the declared typed signatures and deterministic `not_implemented` results. Prove each loads with `DynamicScriptProbe` before running the suite.

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_host_capabilities_red' -LogName 'p2r9-host-capabilities-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_contracts.gd,res://tests/unit/test_minesweeper_capabilities.gd,res://tests/unit/test_shop_rules.gd','-gexit')
```

Expected: all scripts/manifests parse; capability assertions fail on typed unimplemented behavior while Task-1 registry/DataCatalog parity stays green.

- [ ] **Step 2.3: Revalidate the strict Task-1 manifest and schema**

The manifest contains `schema_version=1`, `registry_version="minesweeper_shop_v1"`, exactly the three records from the frozen table, and exact capability IDs. Reject extra members, duplicate IDs, unknown currency/effect/capability, wrong prices/caps, or another Supportz floor.

- [ ] **Step 2.4: Implement host/identity contracts and pure capability rules**

Use exact-key validation, detached returns, the seven app IDs in stated order, and host command derivation from supplied board phase. `open_app()` changes a visible started board to suspended only by returning `suspend_board`; it never blocks Contacts, Schedule, Shop, Backup, Settings, or Logout. Consume `MinesweeperShopRegistry` without caching or copying registry rows. Do not reopen DataCatalog or let `EffectResolver` interpret capability strings.

- [ ] **Step 2.5: Run GREEN**

Run Step 2.2. Expected: exit 0.

- [ ] **Step 2.6: Proposed commit boundary**

Exact paths: the six files in Task 2. Proposed subject:

```text
feat(desktop): freeze host and composable safety capabilities
```

## Task 3: Implement deterministic board truth and the visible-deduction verifier

**Requirements:** `req.minesweeper.safety_capabilities`, `req.minesweeper.rng_isolation`; amendment §§7.3–7.5, 7.7, 11.5.

**Files:**

- Create: `scripts/domain/minesweeper/DeterministicRng32.gd`
- Create: `scripts/domain/minesweeper/MinesweeperBoardSchema.gd`
- Create: `scripts/domain/minesweeper/MinesweeperBoardReducer.gd`
- Create: `scripts/domain/minesweeper/MinesweeperNoGuessVerifier.gd`
- Create: `tests/fixtures/minesweeper/rng_reference_vectors.v1.json`
- Create: `tests/fixtures/minesweeper/verifier_cases.v1.json`
- Create: `tests/unit/test_deterministic_rng32.gd`
- Create: `tests/unit/test_minesweeper_board_schema.gd`
- Create: `tests/unit/test_minesweeper_no_guess_verifier.gd`

**Interfaces:**

```gdscript
# DeterministicRng32.gd -- xorshift32-v1, unsigned state encoded as int 0..0xffffffff
func seed(stream_id: StringName, nonce: String) -> Dictionary
func next_u32() -> Dictionary
func sample_bounded(exclusive_max: int) -> Dictionary
func capture() -> Dictionary
func prepare_restore(state: Dictionary) -> Dictionary

# MinesweeperBoardSchema.gd
static func validate_spec(spec: Dictionary) -> Dictionary
static func validate_layout(layout: Dictionary, spec: Dictionary) -> Dictionary
static func validate_board(board: Dictionary) -> Dictionary

# MinesweeperBoardReducer.gd
static func first_reveal(layout: Dictionary, cell_index: int) -> Dictionary
static func reveal(board: Dictionary, cell_index: int, transaction_id: String) -> Dictionary
static func set_flag(board: Dictionary, cell_index: int, flagged: bool,
		transaction_id: String) -> Dictionary
static func chord(board: Dictionary, cell_index: int, transaction_id: String) -> Dictionary

# MinesweeperNoGuessVerifier.gd
static func verify(layout: Dictionary, forced_cell: int,
		operation_budget: int) -> Dictionary
```

The RNG is `xorshift32-v1`: initialize from the first eight lowercase SHA-256 hex digits of `sha256(stream_id + "\n" + nonce)`, replace zero with `0x6D2B79F5`, then apply `x ^= x << 13; x ^= x >> 17; x ^= x << 5`, masking to 32 bits after each operation. `sample_bounded(n)` uses rejection sampling with `limit=floor(2^32/n)*n`, rejects words `>= limit`, then returns `word % n`. It rejects `n < 1` and never uses `randi()`, `RandomNumberGenerator`, or global RNG. The instance's captured state is exactly `{algorithm,stream_id,nonce,state,draw_count}`; restore rejects a state under another stream ID even when the numeric state matches.

The verifier applies only: adjacent-zero, adjacent-full, direct subset difference with zero/full remainder, and the truthful global remaining-mine constraint. It sorts cells row-major and constraints by canonical serialized bytes before each fixpoint pass. It may inspect hidden layout only to validate deductions, never to mark a player fact. Success requires all safe cells deduced/revealed.

- [ ] **Step 3.1: Add parse-only skeletons, then write RED reference-vector and reducer tests**

Create the four new scripts with their declared typed signatures and deterministic `not_implemented` failures, and create schema-valid fixture containers. Prove every script loads through `DynamicScriptProbe`; only then add the behavioral vectors below. No parser/load failure counts as RED.

Include:

- the first 32 words for zero-normalized, ASCII, and Unicode nonces;
- a complete reduced 8-bit reference sampler whose accepted word domain maps each result equally often for bounds 3, 5, 7, and 10;
- every first cell safe, Lucky corner/edge/interior zero, flood reveal, flag/unflag, chord, explosion, clear, duplicate transaction, stale action, and exact round-trip case;
- positive verifier fixtures for each allowed rule and combinations to fixpoint;
- negative fixtures that require probability, speculative branches, contradiction search, or arbitrary solution enumeration;
- determinism under permuted input dictionary/constraint ordering.
- domain separation: equal nonce bytes under `minesweeper_placement_v1`, `minesweeper_debug_v1`, and `minesweeper_explosion_v1` produce distinct vectors, and advancing/restoring any one leaves exact captured bytes of the other two unchanged.

- [ ] **Step 3.2: Run RED**

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_board_truth_red' -LogName 'p2r9-board-truth-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_deterministic_rng32.gd,res://tests/unit/test_minesweeper_board_schema.gd,res://tests/unit/test_minesweeper_no_guess_verifier.gd','-gexit')
```

Expected: all scripts/fixtures parse; reference-vector, reducer, schema, and verifier assertions fail only on unimplemented behavior.

- [ ] **Step 3.3: Implement RNG, exact schemas, and reducer**

All coordinates serialize as row-major integer indices. Layout and board validation recomputes adjacency counts, phase truth, actual mine count, action sequence, revealed/flagged disjointness, and terminal state rather than trusting redundant caller fields.

- [ ] **Step 3.4: Implement the verifier as a deterministic fixpoint**

The verifier returns exact success `value={certified,operation_count,proof_trace,proof_trace_sha256}`. Each trace record names only an allowed rule, canonical source constraint IDs, and proven safe/mine indices. Budget exhaustion returns `generation_budget_exhausted` with no partial proof in `value`.

- [ ] **Step 3.5: Run GREEN and mutation checks**

Run Step 3.2. Then mutate one expected RNG word, admit one speculative fixture, and permute one proof trace in temporary test data; each mutation must fail the focused suite before the original bytes are restored.

- [ ] **Step 3.6: Proposed commit boundary**

Exact paths: the nine Task-3 files. Proposed subject:

```text
feat(minesweeper): add deterministic board truth and visible proof verifier
```

## Task 4: Build the bounded Default, Lucky, and Debug generator

**Requirements:** `req.minesweeper.safety_capabilities`, `req.minesweeper.rng_isolation`, `req.minesweeper.phase_boundary`; amendment §§6.2–6.5 and 7.3–7.7.

**Files:**

- Create: `data/manifests/minesweeper_difficulties.v1.json`
- Create: `data/schemas/minesweeper-difficulties.schema.json`
- Create generated: `data/manifests/minesweeper_generator_budget.v1.json`
- Create: `data/schemas/minesweeper-generator-budget.schema.json`
- Create generated: `data/manifests/minesweeper_certified_fallbacks.v1.json`
- Create: `data/schemas/minesweeper-certified-fallbacks.schema.json`
- Create: `scripts/domain/minesweeper/MinesweeperGeneratorKernel.gd`
- Create: `scripts/domain/minesweeper/MinesweeperBoardGenerator.gd`
- Create: `scripts/domain/minesweeper/MinesweeperPreparationState.gd`
- Create: `tools/minesweeper/MinesweeperGeneratorToolingLimits.gd`
- Create: `tools/minesweeper/BuildCertifiedFallbacks.gd`
- Create: `tools/minesweeper/BenchmarkMinesweeperGenerator.gd`
- Create: `tests/fixtures/minesweeper/generator_cases.v1.json`
- Create: `tests/unit/test_minesweeper_generator_kernel.gd`
- Create: `tests/unit/test_minesweeper_board_generator.gd`
- Create: `tests/unit/tooling/test_minesweeper_generator_artifacts.gd`

**Interfaces:**

```gdscript
# MinesweeperGeneratorKernel.gd -- the only candidate/search algorithm
static func begin(kernel_spec: Dictionary, forced_cell: int, mode: StringName,
		placement_rng_state: Dictionary, debug_rng_state: Dictionary,
		explosion_rng_state: Dictionary) -> Dictionary
static func advance(frontier: Dictionary, operation_limit: int) -> Dictionary

# MinesweeperBoardGenerator.gd
static func materialize_first_reveal(spec: Dictionary, first_cell: int) -> Dictionary
static func begin_debug(spec: Dictionary) -> Dictionary
static func run_debug_slice(preparation: Dictionary) -> Dictionary
static func validate_prepared(candidate: Dictionary, spec: Dictionary) -> Dictionary

# MinesweeperPreparationState.gd
static func make(kernel_spec: Dictionary, forced_cell: int, mode: StringName,
		placement_rng_state: Dictionary, debug_rng_state: Dictionary,
		explosion_rng_state: Dictionary) -> Dictionary
static func validate(state: Dictionary) -> Dictionary
static func advance(state: Dictionary, slice_result: Dictionary) -> Dictionary

# MinesweeperGeneratorToolingLimits.gd -- tooling-only, never imported by runtime
const TOOLING_SAFETY_OPERATION_CEILING := 16_777_216
```

`GeneratorKernelSpec` is the exact pure projection `{schema_version:1,board_kind,difficulty_id,width,height,base_mine_count,raw_extra_mines,requested_mine_count,capability_ids,placement_stream_id,placement_nonce,debug_stream_id,debug_nonce,explosion_stream_id,explosion_nonce,generator_version,verifier_version}` with the same field types/closed values as `BoardSpec`. It deliberately has no board token or issuer-receipt member. Production `MinesweeperBoardGenerator` first validates the complete trusted `BoardSpec` and all nonce receipts, then projects these exact fields without coercion. Tooling constructs the same projection only from the frozen difficulty/capability corpus and explicitly domain-separated tool nonces; it never fabricates an issuer receipt or calls the production issuer. The kernel accepts only this exact projection and cannot distinguish or authorize production identity.

The registered difficulty IDs and carried-forward board balance are exact `beginner=8x8/10`, `intermediate=16x16/40`, and `expert=22x22/99`. The manifest records only these existing values; changing one is a product-balance decision outside this plan.

Default/Lucky materialization removes the selected cell, removes its valid neighbors when `first_cell_zero` is present, rejection-samples a Fisher-Yates candidate order, reduces extras only when the requested total does not fit, adopts the exact layout, and performs the first reveal in one pure result.

Debug draws the forced cell exactly once from `minesweeper_debug_v1`. Its deterministic search-control choices also consume only the Debug stream. Mine permutations for each selected candidate consume only `minesweeper_placement_v1`; hidden H/U/A assignments consume only `minesweeper_explosion_v1` after adoption. Kernel search keeps the forced cell across every candidate and extra tier and tries full effective extras down to zero, but it never reads, selects, or invokes a certified fallback. `MinesweeperGeneratorKernel` is the one pure implementation of candidate/search transitions for runtime, fallback construction, and benchmarking. `begin()` requires exact mode `candidate_search|fallback_construction`: runtime and benchmark search use `candidate_search`; only `BuildCertifiedFallbacks.gd` may use `fallback_construction`. It accepts an explicit positive `operation_limit` on every `advance()` call and has no fallback input, manifest loader, file I/O, clock, environment read, default limit, or internal unbounded loop. A saved preparation frontier has exact keys `status`, `mode`, `spec`, `forced_cell`, `placement_rng_state`, `debug_rng_state`, `explosion_rng_state`, `extra_tier`, `candidate_ordinal`, `candidate_state`, `operations_used`, `slice_sequence`, `last_failure_code`. `status` is exactly `searching|certified|exhausted`: `begin()` returns `searching`, every incomplete bounded slice returns `searching`, a verifier-certified candidate returns `certified`, and complete search exhaustion returns `exhausted`; no other terminal/discriminator value is legal. Its `spec` is the exact detached `GeneratorKernelSpec`, and it contains no live RNG object or Callable. All three states validate their exact IDs/nonces against that frozen projection; no state may be derived from another.

The kernel is the one pure generation implementation for `desktop`, `solo_challenge`, and `pair_challenge` BoardSpecs; `MinesweeperBoardGenerator` is only its manifest-validating runtime adapter. For Default/Lucky challenge input the adapter returns a frozen spec with null layout until the chosen first Reveal; for Debug it requires the certified prepared candidate before the caller may commit story-attempt entry. It never spends a desktop round, motivation, relationship attempt, or story slot. After layout adoption the kernel uses the isolated explosion stream to assign every mine independently by `sample_bounded(3) -> hatred|upset|amused`; those exact assignments and final three-stream states persist with the layout. Any later special-mine recipe remains owned by the relationship challenge contract and is appended by that trusted adapter without changing the adopted mine layout or any RNG stream.

The generated fallback manifest is canonical JSON keyed by `{difficulty_id,forced_cell,first_cell_zero}` and stores a verifier-certified base-mine layout for every registered cell. Runtime never searches for a new fallback or trusts an uncertified entry. `BuildCertifiedFallbacks.gd` iterates difficulty order `beginner,intermediate,expert`, then `first_cell_zero=false,true`, then forced cell ascending. For each semantic stream, its tool-only nonce is `sha256("minesweeper_fallback_v1\n" + difficulty_id + "\n" + str(forced_cell) + "\n" + ("1" if first_cell_zero else "0") + "\n" + stream_id)`. It drives `mode=fallback_construction` directly, before any fallback or runtime budget exists, and adopts the first verifier-certified candidate in kernel order; that mode searches only from Task-3 primitives and cannot consume a fallback record. The tool refuses to write unless no request reaches the ceiling, the real verifier accepts every entry, base mine counts are unchanged, and Lucky's forced cell is zero. Runtime fallback selection lives only in `MinesweeperBoardGenerator`: after ordinary kernel search exhausts the frozen search budget, the adapter looks up the exact manifest key and spends only the reserved fallback-validation budget to revalidate/adopt those bytes; it never passes a fallback into the kernel.

Budget values are evidence-derived, never guessed or hand-edited. The initial budget manifest must be absent: an empty object, zero-valued provisional record, copied budget, runtime default, or use of the tooling ceiling as a runtime value rejects. After the fallback manifest exists, `BenchmarkMinesweeperGenerator.gd` drives the same pure kernel directly on the declared lowest-target Windows device for 256 fixed nonces per difficulty/capability combination and separately measures Task-3 verifier revalidation for every fallback entry, then emits exactly:

```gdscript
{
  "schema_version": 1,
  "benchmark_corpus_sha256": String,
  "device_evidence": {
    "declaration": "lowest_target_windows_v1",
    "os_version": String,
    "cpu_model": String,
    "logical_processor_count": int,
    "godot_version": "4.6.3.stable.mono"
  },
  "source_sha256": {
    "difficulty_manifest": String,
    "rng": String,
    "reducer": String,
    "kernel": String,
    "verifier": String,
    "tooling_limits": String,
    "fallback_builder": String,
    "fallback_manifest": String,
    "benchmark_tool": String,
    "budget_schema": String
  },
  "rows": Array[Dictionary],
  "slice_operation_budget": int,     # next_power_of_two(max(1024, ceil(p99_candidate_operations / 8)))
  "search_operation_budget": int,    # next_power_of_two(2 * maximum_observed_search_operations)
  "reserved_fallback_operation_budget": int, # next_power_of_two(maximum_fallback_validation_operations + 1)
  "hard_operation_budget": int,      # search_operation_budget + reserved_fallback_operation_budget
}
```

Every row is exact `{kind:"search"|"fallback",case_id:String,difficulty_id:String,capability_ids:Array[String],nonce_ordinal:int|null,forced_cell:int,first_cell_zero:bool,candidate_operations:int,search_operations:int,fallback_validation_operations:int}` with sorted capability IDs and nonnegative operation counts. A search row records the maximum single-candidate operation count and cumulative pre-fallback search operations for one request, with `fallback_validation_operations=0`; a fallback row has both search counts zero and records one verifier revalidation cost. `nonce_ordinal` is `0..255` only for `kind=search` and null for `kind=fallback`.

The corpus and row order are closed. Difficulty order is `beginner, intermediate, expert`. Capability order is exactly `(default) ["first_cell_safe"]`, `(lucky) ["first_cell_safe","first_cell_zero"]`, `(debug) ["first_cell_safe","forced_no_guess"]`, `(lucky_debug) ["first_cell_safe","first_cell_zero","forced_no_guess"]`. Search rows are difficulty major, then that capability order, then `nonce_ordinal` ascending, so there are exactly 3,072 search rows. For each semantic stream ID, its tool-only lowercase-hex nonce is `sha256("minesweeper_benchmark_nonce_v1\n" + difficulty_id + "\n" + CanonicalJsonWriter.stringify(capability_ids) + "\n" + str(nonce_ordinal) + "\n" + stream_id)`; no production identity API consumes it. Default/Lucky uses `forced_cell = nonce_ordinal % cell_count`; Debug/Lucky-Debug records the forced cell drawn by the Debug stream. Search `case_id` is `search:<difficulty_id>:<default|lucky|debug|lucky_debug>:<three-digit-zero-padded-ordinal>`.

Fallback rows follow all search rows in difficulty order, then `first_cell_zero=false,true`, then `forced_cell` ascending. Their capability arrays are `["first_cell_safe","forced_no_guess"]` or `["first_cell_safe","first_cell_zero","forced_no_guess"]`, and `case_id` is `fallback:<difficulty_id>:<safe|zero>:<unsigned-forced-cell>`. `benchmark_corpus_sha256` hashes canonical UTF-8/LF JSON bytes for the ordered projection of every row's seven input fields through `first_cell_zero`, before measured operation fields are added. The validator regenerates that projection/nonces/order independently and rejects an omitted, duplicate, reordered, or invented row.

For budget math, sort the 3,072 search-row `candidate_operations` integers ascending; nearest-rank p99 uses one-based rank `(99 * 3072 + 99) / 100` with integer division and therefore selects zero-based element `rank - 1`. `maximum_observed_search_operations` is the maximum search-row `search_operations`; `maximum_fallback_validation_operations` is the maximum fallback-row value. Integer `ceil(p99 / 8)` is `(p99 + 7) / 8`. `next_power_of_two(x)` is the least positive `2^n >= x`; nonpositive input or signed-64 overflow rejects. The validator recomputes the four formula values exactly, checks every listed source hash, and rejects an extra member or a ceiling-hit row. The runtime wrapper is intentionally absent from `source_sha256`: it is implemented only after this manifest freezes, delegates to the hashed kernel, and is bound separately by Task-9 evidence. If `DWM_LOWEST_TARGET_WINDOWS_DEVICE=1` is absent, benchmark write/check stops before generation and cannot write or freeze budgets.

`MinesweeperGeneratorToolingLimits.TOOLING_SAFETY_OPERATION_CEILING == 16_777_216` is a fail-stop bound per generated request, not product balance and not a candidate runtime budget. Both tools loop the kernel only while cumulative operations are below that ceiling; reaching it is `tooling_safety_ceiling_reached` and produces no candidate artifact. Static tests prove `MinesweeperBoardGenerator.gd` neither imports the tooling-limits script nor contains `16_777_216`, and that missing/invalid/unfrozen budget data returns `generator_budget_unavailable` before a runtime draw.

Each tool accepts exactly one mutually exclusive mode argument: `--write=<res://path>` or `--check=<res://path>`. Write mode validates the complete in-memory candidate, then writes canonical UTF-8/LF bytes to that exact path. Check mode regenerates and validates the same candidate in memory, reads the exact target as raw bytes, requires byte equality, and exits nonzero for a missing/different file; it must not open any file for write, create a temporary file, rename/delete a path, or change target timestamps. No bare no-argument mode and no `--verify` alias is legal.

- [ ] **Step 4.1: Add parse-only skeletons, then write RED kernel, tooling, and runtime tests**

Create the kernel, runtime generator, preparation-state, tooling-limits, build tool, and benchmark tool with their declared typed signatures and deterministic `not_implemented` results. Create the difficulty manifest/schema, all three generated-artifact schemas, and the fixture, but leave both generated manifest paths absent. Use `DynamicScriptProbe` on every script before behavioral tests; a script-load error is not RED. Assert an absent budget produces `generator_budget_unavailable` before any runtime RNG draw and never falls back to the tooling ceiling.

Kernel tests cover every first cell for every difficulty, all four owned-item combinations, odd extras, insufficient-extra capacity, base-count impossibility, same-seed byte equality, unrelated RNG draw isolation, three-stream state byte equality across retry/restore, forced-cell persistence across failed candidates/slices/restore, and full-to-zero extra priority under caller-supplied positive limits. Runtime tests cover fallback use, frozen slice/search/fallback/hard-budget enforcement, and exhaustion with no partial state mutation only after the generated manifests exist.

For all three `board_kind` values, also prove identical placement inputs yield identical mine layouts; advancing the Debug stream changes no placement draw, advancing placement changes no forced-cell/search draw, and challenge-only explosion assignments are deterministic, independently distributed across the fixed corpus, and cannot perturb layout/forced-cell output. Prove Default/Lucky challenge layout is null before Reveal and Debug challenge entry rejects an uncertified preparation. Reject an unknown/missing mode or extra `GeneratorKernelSpec` member, prove production projection first validates every issuer receipt, prove tool projections contain no token/receipt and call no issuer, prove `candidate_search` never consumes fallback input, and prove `fallback_construction` succeeds from Task-3 primitives while both generated manifests are absent. Tooling tests reject zero/negative limits, assert every kernel call is bounded, prove neither tool calls `MinesweeperBoardGenerator`, prove the runtime script never imports tooling limits, and exercise exact mutually exclusive `--write=<path>`/`--check=<path>` parsing with check-mode write APIs forbidden.

```gdscript
func test_debug_forced_cell_never_changes_across_slices_or_extra_reduction() -> void:
	var started := MinesweeperBoardGenerator.begin_debug(_spec("expert", ["first_cell_safe","forced_no_guess"]))
	assert_eq(started["value"]["preparation"]["status"], "searching")
	var forced: int = started["value"]["preparation"]["forced_cell"]
	var state: Dictionary = started["value"]["preparation"]
	var slice_count := 0
	while state["status"] == "searching":
		var step := MinesweeperBoardGenerator.run_debug_slice(state)
		state = step["value"]["preparation"]
		slice_count += 1
		assert_eq(state["forced_cell"], forced)
		assert_lt(slice_count, 100_000, "bounded corpus must terminate")
	assert_gt(slice_count, 0, "the RED must execute at least one real slice")
	assert_eq(state["status"], "certified")
```

- [ ] **Step 4.2: Run RED**

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_generator_red' -LogName 'p2r9-generator-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_minesweeper_generator_kernel.gd,res://tests/unit/test_minesweeper_board_generator.gd,res://tests/unit/tooling/test_minesweeper_generator_artifacts.gd','-gexit')
```

Expected: every script/schema parses; kernel/runtime/tool assertions fail only on typed unimplemented or intentionally absent generated-artifact behavior.

- [ ] **Step 4.3: Implement the shared pure kernel before any artifact or runtime budget**

Use only Task-3 RNG/reducer/verifier. Every input, including the exact mode, is validated before the first draw. `advance()` performs at most its caller-supplied positive limit and returns one detached stable frontier. Candidate failure advances deterministic state; technical/invariant failure returns a typed failure without substituting a guessing board. Neither mode accepts or loads a fallback or budget manifest. Run only `test_minesweeper_generator_kernel.gd`; expected exit 0—including fallback construction with both artifacts absent—while the runtime/artifact tests remain RED for the intended absent-manifest boundary.

- [ ] **Step 4.4: Generate and byte-check fallbacks through the kernel**

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_fallback_build' -LogName 'p2r9-fallback-build.log' -GodotArgs @('-s','res://tools/minesweeper/BuildCertifiedFallbacks.gd','--','--write=res://data/manifests/minesweeper_certified_fallbacks.v1.json')
if ($LASTEXITCODE -ne 0) { throw 'fallback generation failed' }
$fallback_artifact = Get-Item -LiteralPath 'data/manifests/minesweeper_certified_fallbacks.v1.json'
$fallback_length_before = $fallback_artifact.Length
$fallback_write_before = $fallback_artifact.LastWriteTimeUtc.Ticks
$fallback_hash_before = (Get-FileHash -Algorithm SHA256 -LiteralPath $fallback_artifact.FullName).Hash
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_fallback_check' -LogName 'p2r9-fallback-check.log' -GodotArgs @('-s','res://tools/minesweeper/BuildCertifiedFallbacks.gd','--','--check=res://data/manifests/minesweeper_certified_fallbacks.v1.json')
if ($LASTEXITCODE -ne 0) { throw 'fallback byte check failed' }
$fallback_artifact = Get-Item -LiteralPath $fallback_artifact.FullName
if ($fallback_artifact.Length -ne $fallback_length_before -or $fallback_artifact.LastWriteTimeUtc.Ticks -ne $fallback_write_before -or ((Get-FileHash -Algorithm SHA256 -LiteralPath $fallback_artifact.FullName).Hash -cne $fallback_hash_before)) { throw 'fallback check mode wrote its target' }
```

Expected: both exit 0; exactly one certified record per registered `(difficulty, cell, zero-capability)` tuple; check mode reports byte equality and leaves the file length, raw SHA-256, and last-write timestamp unchanged. Mutate one byte in an isolated fixture copy and prove `--check=<copy>` fails without repairing it.

- [ ] **Step 4.5: Benchmark the kernel on the declared lowest target and freeze budgets**

```powershell
if (-not ($env:DWM_LOWEST_TARGET_WINDOWS_DEVICE -ceq '1')) { throw 'Run this step on the declared lowest-target Windows device.' }
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_generator_benchmark' -LogName 'p2r9-generator-benchmark.log' -GodotArgs @('-s','res://tools/minesweeper/BenchmarkMinesweeperGenerator.gd','--','--write=res://data/manifests/minesweeper_generator_budget.v1.json')
if ($LASTEXITCODE -ne 0) { throw 'generator benchmark failed' }
$budget_artifact = Get-Item -LiteralPath 'data/manifests/minesweeper_generator_budget.v1.json'
$budget_length_before = $budget_artifact.Length
$budget_write_before = $budget_artifact.LastWriteTimeUtc.Ticks
$budget_hash_before = (Get-FileHash -Algorithm SHA256 -LiteralPath $budget_artifact.FullName).Hash
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_generator_budget_check' -LogName 'p2r9-generator-budget-check.log' -GodotArgs @('-s','res://tools/minesweeper/BenchmarkMinesweeperGenerator.gd','--','--check=res://data/manifests/minesweeper_generator_budget.v1.json')
if ($LASTEXITCODE -ne 0) { throw 'generator budget byte check failed' }
$budget_artifact = Get-Item -LiteralPath $budget_artifact.FullName
if ($budget_artifact.Length -ne $budget_length_before -or $budget_artifact.LastWriteTimeUtc.Ticks -ne $budget_write_before -or ((Get-FileHash -Algorithm SHA256 -LiteralPath $budget_artifact.FullName).Hash -cne $budget_hash_before)) { throw 'budget check mode wrote its target' }
```

Expected: both exit 0, no request reaches the tooling safety ceiling, no measured request exceeds the recomputed hard bound, and the fallback reservation is sufficient for every forced cell. The generated manifest records the exact measured device, raw rows, corpus, kernel, verifier, fallback, benchmark-tool, and schema hashes. Check mode leaves its file length, raw SHA-256, and last-write timestamp unchanged; a one-byte-mutated isolated copy fails without repair.

- [ ] **Step 4.6: Implement the runtime slice adapter from the frozen budget**

Only now implement `MinesweeperBoardGenerator` and `MinesweeperPreparationState` over `MinesweeperGeneratorKernel` mode `candidate_search`. Load and exact-schema/hash-validate the frozen budget and fallback manifests before the first draw. Pass only `slice_operation_budget` to each runtime kernel call; enforce cumulative `search_operation_budget`, then outside the kernel select the exact certified fallback and reserve `reserved_fallback_operation_budget` exclusively for its verifier revalidation/adoption. Reject any path beyond the exact sum `hard_operation_budget`. Runtime may not call `fallback_construction`, read the benchmark rows as control input, import the tooling-limits script, or substitute a constant/default if either manifest is absent or invalid.

- [ ] **Step 4.7: Run GREEN and exact non-writing byte-equality gates**

Run Step 4.2 and expect exit 0. Then rerun the two exact `--check=<path>` commands from Steps 4.4–4.5 and require byte equality plus unchanged length/SHA/timestamp for both checked-in manifests. Run a static dependency scan proving both tools preload the shared kernel, the runtime generator preloads the shared kernel but not the tooling-limits script, and neither tool preloads/calls the runtime generator.

- [ ] **Step 4.8: Proposed commit boundary**

Exact paths: the sixteen Task-4 files. Proposed subject:

```text
feat(minesweeper): add bounded certified board generation
```

## Task 5: Define canonical board transactions against contract fakes

**Requirements:** `req.minesweeper.board_lifecycle`, `req.minesweeper.round_contract`, `req.desktop.cross_app_actions`; amendment §§6.1–6.4, 6.6, 11.3, 12.2–12.4.

**Hard GameState ownership gate:** before a Task-5 edit, validate the same recorded Plan-01 v3 boundary consumed by Task 6 and require its commit to be an ancestor. Plan-01's GameState/Schedule cutover must be clean and closed; no Plan-01 worktree may still own `autoload/GameState.gd` or `tests/unit/test_game_state.gd`. Task 5 consumes that exact surface and never merges parallel GameState edits.

**Files:**

- Create: `scripts/domain/minesweeper/DesktopBoardState.gd`
- Create: `scripts/application/minesweeper/MinesweeperRoundCoordinator.gd`
- Create: `scripts/application/minesweeper/GameStateMinesweeperPort.gd`
- Create: `tests/support/FakeMinesweeperGenerationPort.gd`
- Create: `tests/support/FakeMinesweeperStatePort.gd`
- Create: `tests/support/FakeMinesweeperCheckpointPort.gd`
- Create: `tests/unit/test_desktop_board_state.gd`
- Create: `tests/unit/test_minesweeper_round_coordinator.gd`
- Create: `tests/integration/test_minesweeper_first_reveal_contract.gd`
- Modify: `autoload/GameState.gd`
- Modify: `tests/unit/test_game_state.gd`
- Modify: `tests/unit/test_minesweeper_rewards.gd`
- Modify: `evidence/phase_2r/runtime/game_state_required_surface.json`

**Interfaces:**

```gdscript
# DesktopBoardState.gd
func reset() -> void
func capture() -> Dictionary
func prepare_restore(snapshot: Dictionary) -> Dictionary
func prepare_debug_candidate(input: Dictionary, generation: Dictionary) -> Dictionary
func prepare_debug_slice(input: Dictionary, generation: Dictionary) -> Dictionary
func prepare_first_reveal(input: Dictionary, materialized: Dictionary,
		paid_start_receipt: Dictionary) -> Dictionary
func prepare_board_command(input: Dictionary, reduced_board: Dictionary) -> Dictionary
func prepare_visibility(input: Dictionary, visible: bool) -> Dictionary
func prepare_settlement(input: Dictionary, settlement: Dictionary) -> Dictionary
func commit(candidate: Dictionary) -> Dictionary

# MinesweeperRoundCoordinator.gd
func configure(state_port: Object, checkpoint_port: Object,
		generation_port: Object, identity_issuer: Object) -> Dictionary
func get_entry_context(difficulty_id: String) -> Dictionary
func begin_debug_preparation(request: Dictionary) -> Dictionary
func run_debug_preparation_slice(request: Dictionary) -> Dictionary
func reveal(request: Dictionary) -> Dictionary
func set_flag(request: Dictionary) -> Dictionary
func chord(request: Dictionary) -> Dictionary
func suspend(request: Dictionary) -> Dictionary
func resume(request: Dictionary) -> Dictionary
func get_state() -> Dictionary

# GameStateMinesweeperPort.gd
func guard_external(operation_id: StringName) -> Dictionary
func capture() -> Dictionary
func prepare_spec(difficulty_id: String, transaction_id: String,
		transaction_issuer_receipt: Dictionary) -> Dictionary
func prepare_first_reveal(board_candidate: Dictionary, transaction_id: String,
		transaction_issuer_receipt: Dictionary,
		expected_checkpoint_id: String) -> Dictionary
func prepare_board_only(board_candidate: Dictionary, transaction_id: String,
		transaction_issuer_receipt: Dictionary) -> Dictionary
func commit(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
func publish(publication: Dictionary) -> Dictionary

# FakeMinesweeperCheckpointPort.gd -- contract fake, never production wiring
func capture() -> Dictionary
func preview_checkpoint_id(run_id: String) -> Dictionary
func prepare_checkpoint(snapshot_input: Dictionary, checkpoint_kind: StringName,
		disk_write: Dictionary) -> Dictionary
func commit_checkpoint(candidate: Dictionary) -> Dictionary
func seal_checkpoint(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
```

`get_entry_context()` is a pure view query returning exact `value={identity,revision,difficulty_id,eligible}` for the next unpaid ordinal while phase is `NONE`; it creates no candidate and freezes nothing. First Reveal has exact request `{transaction_id,transaction_issuer_receipt,expected_identity,expected_revision,difficulty_id,cell_index}`. Debug preparation has `{transaction_id,transaction_issuer_receipt,expected_identity,expected_revision,difficulty_id}`. Every later semantic request has exact `transaction_id`, `transaction_issuer_receipt`, `expected_identity`, `expected_revision`, plus only `cell_index` or `flagged` where applicable. The issuer must ledger-verify the full receipt for purpose `transaction_id` and `transaction_id == transaction_issuer_receipt.token`; a receipt ID, syntactically plausible caller string, or structurally valid forgery rejects. A public request cannot supply dimensions, mine count, capabilities, effects, costs, layout, proof, nonce, identity, or rewards.

`prepare_spec()` obtains its attempt identity components, board token, and all three nonces from the issuer seam; it cannot call a clock or RNG. `prepare_first_reveal()` validates available capacity and motivation, decrements the signed numerator once, charges exactly one motivation, increments starts-today once, and returns one detached combined GameState/board candidate. Its receipt has exact keys `receipt_id`, `receipt_provenance`, `transaction_id`, `transaction_issuer_receipt`, `identity`, `difficulty_id`, `first_cell`, `board_revision`, `rounds_before`, `rounds_after`, `motivation_before`, `motivation_after`, `layout_sha256`, `proof_sha256`, `checkpoint_id`; the receipt uses child kind `board_start` anchored to the transaction. No other board command changes those costs.

Task 5 intentionally proves coordinator semantics only against `FakeMinesweeperCheckpointPort`. Its in-memory `commit_checkpoint()` is explicitly provisional and remains exactly reversible through `rollback(backup)` until `seal_checkpoint(candidate)` marks the joint fake-checkpoint plus GameState/board transaction committed; only publication follows that seal. It supports duplicate publication within one process but claims no restart recovery. It MUST NOT create `SaveManagerMinesweeperPort`, configure ApplicationBootstrap, write a canonical save, claim crash durability, or call a production persistence path. Task 6 deliberately replaces this fake-only reversible/seal seam with durable checkpoint-candidate/forward-recovery semantics before production wiring.

- [ ] **Step 5.1: Add parse-only skeletons, then write RED state-machine tests**

Create each new Task-5 script/fake with the declared typed surface and deterministic `not_implemented` results. Prove all preloads with `DynamicScriptProbe`, then write behavior tests. No production behavior or persistence wiring belongs in a skeleton, and no parser/load error counts as RED.

Exercise every legal edge and every illegal cross-edge, exact phase invariants, duplicate request equality, changed-payload conflict, stale revision, mutation-after-call/return detachment, and command serialization. Explicitly prove Default/Lucky remain `NONE` until Reveal and Debug is cost-free through `PREPARED_UNSTARTED`.

- [ ] **Step 5.2: Write RED fake-checkpoint first-Reveal contract tests**

Inject failure before/after generation, fake checkpoint prepare, reversible fake checkpoint commit, GameState commit, fake checkpoint seal, and publication. Any failure before seal rolls back both participants in reverse and leaves board/cost/counter/fake-checkpoint bytes unchanged. After seal, publication failure returns `FIRST_REVEAL_COMMITTED_UNPUBLISHED`; the exact retry publishes the existing receipt and never charges again. Rollback failure projects through the existing `FatalDiagnosticProjector` and one shared gate. Assert the fake reports `is_production=false` and that no SaveManager/storage method is called.

- [ ] **Step 5.3: Run RED**

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_first_reveal_contract_red' -LogName 'p2r9-first-reveal-contract-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_board_state.gd,res://tests/unit/test_minesweeper_round_coordinator.gd,res://tests/integration/test_minesweeper_first_reveal_contract.gd','-gexit')
```

Expected: every new state/coordinator/fake parses; assertions fail only on typed unimplemented state-machine behavior.

- [ ] **Step 5.4: Implement state and coordinator without production persistence**

Order the contract exactly: guard -> duplicate/conflict lookup -> current-state and request validation -> issuer-backed trusted spec -> materialize/adopt -> pure reveal -> preview the fake checkpoint ID without consuming it -> prepare the combined GameState candidate/receipt with that expected ID -> prepare a fake checkpoint that must return the same ID -> capture both backups -> provisionally commit fake checkpoint -> commit GameState/board -> seal that exact fake checkpoint candidate -> publish. A failed preview/prepare does not consume a sequence; any failure through seal rolls back every applied participant in reverse. Only a successful seal makes publication failure committed-unpublished. The coordinator knows only the injected contract; no SaveManager lifetime board lock or direct storage call exists.

Routine reveal/flag/chord and visibility commands use the same identity/revision/receipt rules but commit only a new stable in-memory command revision. Presentation failure cannot roll back canonical truth.

- [ ] **Step 5.5: Retire legacy mutation paths**

Replace `start_minesweeper_app_round()`, `finish_minesweeper_app_round()`, `clear_unfinished_minesweeper_round()`, and scalar `get_minesweeper_safety_level()` with the typed coordinator/port seams. Run:

```powershell
rg -n "start_minesweeper_app_round|finish_minesweeper_app_round|clear_unfinished_minesweeper_round|get_minesweeper_safety_level" autoload scripts tests --glob '*.gd'
```

Expected: zero production callers and only explicit retired-API negative assertions, if retained. App reward calculation remains a typed completion participant; tests no longer manufacture an unfinished result bag.

- [ ] **Step 5.6: Update the required public surface**

Classify every new GameState board facade method and prove no raw state setter, arbitrary delta, caller-supplied capability/layout/identity/nonce, or production checkpoint registration is public.

- [ ] **Step 5.7: Run GREEN and prove the production boundary is absent**

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_first_reveal_contract_green' -LogName 'p2r9-first-reveal-contract-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_board_state.gd,res://tests/unit/test_minesweeper_round_coordinator.gd,res://tests/unit/test_game_state.gd,res://tests/unit/test_minesweeper_rewards.gd,res://tests/integration/test_minesweeper_first_reveal_contract.gd,res://tests/unit/tooling/test_public_surface_inventory.gd','-gexit')
rg -n "SaveManagerMinesweeperPort|configure.*MinesweeperRoundCoordinator" autoload scripts/application tests/integration/test_minesweeper_first_reveal_contract.gd
```

Expected: test command exit 0; the scan finds no production checkpoint adapter or bootstrap configuration in Task-5-owned paths.

- [ ] **Step 5.8: Proposed commit boundary**

Exact paths: the thirteen Task-5 paths. Proposed subject:

```text
feat(minesweeper): define first reveal transaction contracts
```

## Task 6: Install v4 durability before production first Reveal

**Requirements:** `req.save.desktop_board_continuity`, `req.desktop.cross_app_actions`, `req.desktop.logout`, `req.minesweeper.board_lifecycle`, `req.minesweeper.round_contract`, `req.minesweeper.causal_departure`; amendment §§5.2, 6.3–6.6, 9.1–9.4, 11, 12.2–12.4.

**Files:**

- Create: `scripts/domain/desktop/DesktopConsequenceState.gd`
- Create: `scripts/domain/desktop/DesktopContinuationRemapper.gd`
- Create: `scripts/application/desktop/DesktopCausalSequencePort.gd`
- Create: `scripts/infrastructure/save/DesktopPublicationLedger.gd`
- Create: `schemas/save/desktop-publication-ledger.schema.json`
- Create: `scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd`
- Create: `scripts/application/minesweeper/SaveManagerMinesweeperPort.gd`
- Create: `scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd`
- Create: `scripts/application/restore/DesktopConsequenceRestoreParticipant.gd`
- Create: `scripts/application/restore/DesktopBoardRestoreParticipant.gd`
- Create: `scripts/application/desktop/LogoutCoordinator.gd`
- Create: `tests/unit/test_desktop_consequence_state.gd`
- Create: `tests/unit/test_desktop_outbox_publication_transition.gd`
- Create: `tests/unit/test_desktop_causal_sequence_port.gd`
- Create: `tests/unit/test_desktop_publication_ledger.gd`
- Create: `tests/unit/test_desktop_identity_allocation_restore_participant.gd`
- Create: `tests/unit/test_desktop_continuation_remapper.gd`
- Create: `tests/unit/test_desktop_first_reveal_snapshot_composer.gd`
- Create: `tests/unit/test_logout_coordinator.gd`
- Create: `tests/integration/test_minesweeper_first_reveal_transaction.gd`
- Create: `tests/integration/test_desktop_board_persistence.gd`
- Create: `tests/fixtures/saves/v4_desktop_none.json`
- Create: `tests/fixtures/saves/v4_desktop_preparing.json`
- Create: `tests/fixtures/saves/v4_desktop_prepared.json`
- Create: `tests/fixtures/saves/v4_desktop_active.json`
- Create: `tests/fixtures/saves/v4_desktop_settling.json`
- Create: `tests/fixtures/saves/v4_desktop_pending_consequence.json`
- Create: `tests/fixtures/saves/v3_pre_desktop.json`
- Modify: `scripts/domain/run/RunLifecycle.gd`
- Modify: `scripts/domain/run/RunSnapshotSchema.gd`
- Modify: `scripts/infrastructure/save/SaveDocumentSchema.gd`
- Modify: `scripts/infrastructure/save/SaveMigrations.gd`
- Modify: `autoload/SaveManager.gd`
- Modify: `scripts/application/run/SaveManagerCheckpointPort.gd`
- Modify: `scripts/application/restore/RunRestoreParticipant.gd`
- Modify: `scripts/application/minesweeper/MinesweeperRoundCoordinator.gd`
- Modify: `scripts/application/minesweeper/GameStateMinesweeperPort.gd`
- Modify: `scripts/application/transaction/ApplicationMutationGate.gd`
- Modify: `scripts/ui/MenuScene.gd`
- Modify: `tests/unit/test_run_lifecycle.gd`
- Modify: `tests/unit/test_run_snapshot_schema.gd`
- Modify: `tests/unit/test_save_document_schema.gd`
- Modify: `tests/unit/test_save_migrations.gd`
- Modify: `tests/unit/test_minesweeper_round_coordinator.gd`
- Modify: `tests/unit/test_save_manager_checkpoint_port.gd`
- Modify: `tests/unit/test_application_mutation_gate.gd`
- Modify: `tests/integration/test_save_capability.gd`
- Modify: `tests/integration/test_restore_transaction.gd`
- Modify: `tests/integration/test_new_run_transaction.gd`

**Hard integration gate:** before writing a Task-6 test, derive the sole evidence commit as the last commit touching `evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json`; require exact subject `chore(evidence): bind committed Schedule v3 boundary`, exactly one parent, and no later/current drift of either the record or its focused log. Parse the record blob from that evidence commit, require its sole parent equals the record's `boundary_commit`, then invoke the generator's historical `--check` form against that exact evidence commit. Require `owner_beads_id="dwm-p2r.13"`, code subject `feat(save): persist canonical committed Schedule`, exact source/log hashes, and a clean recorded code commit SHA; run `git merge-base --is-ancestor` for both commits and require exit 0. Then prove `RunSnapshotSchema.SCHEMA_VERSION == 3`, `SaveDocumentSchema.DOCUMENT_VERSION == 3`, the canonical top-level field is exactly `committed_schedule`, and the recorded focused Plan-01 snapshot/document/migration logs are green. A subject search alone is not identity and cannot satisfy this gate. If any condition fails, stop. Tasks 1–5 do not waive this gate.

**Schema choice:** set `RunSnapshotSchema.SCHEMA_VERSION = 4` and `SaveDocumentSchema.DOCUMENT_VERSION = 4` only after that gate. SaveDocument dispatch must require an exact v4 Run snapshot in every current bundle/checkpoint member; document version, embedded snapshot version, journal checkpoint version, and canonical hash must agree. V4 preserves Plan 01's `committed_schedule` byte-for-byte and adds exactly one top-level `desktop` member with exact keys `{board,consequence}` as frozen above. Its strict pending-transaction union includes separate `publication_progress`, immutable `admission_checkpoint_receipt`, and rotating `checkpoint_receipt` exactly as frozen above; missing any key, progress outside `publication_pending`, a bad prefix/receipt ledger, a nonnull admission receipt before `sequence_committed`, a changed/null admission receipt afterward, or a publication recipe containing either receipt rejects. Inside the already-existing `lifecycle` object—not as additional top-level aliases—it adds exact members `branch_id`, `desktop_timeline_generation`, `causal_day_instance`, `causal_day_instance_issuer_receipt`, and nullable `restore_provenance`. The full receipt must ledger-verify as purpose `causal_day_instance`, its token must equal the adjacent identity, and it is the sole legal `source_causal_day_instance_issuer_receipt` for a day-advance request:

```gdscript
"restore_provenance": null | {
	"source_branch_id": String,
	"source_desktop_timeline_generation": int,
	"source_causal_day_instance": String,
	"source_issuer_observed_counter": int,
	"restore_transaction_id": String,
	"identity_allocation_receipt_id": String,
	"transaction_remap_sha256": String,
	"remap_receipt_id": String,
	"remap_receipt_provenance": Dictionary,
}
```

Plan 03 alone may advance to v5, add top-level `schedule_view`, and extend the existing lifecycle with nullable `active_condition_hospital_plan` beside `active_resolution_plan` plus append-only `condition_hospital_history`. The active variants are mutually exclusive. Each history key is a completed condition-Hospital resolution receipt ID and its exact value is `{completed_plan,retirement_receipt}`; only a cursor-6/all-stages-complete plan plus issuer-valid `P03.condition_hospital.retirement` receipt is legal. `ConditionHospitalState` is only a typed facade over the active member/history transition, `RunRestoreParticipant` remains their sole selectable owner, and no sixth restore participant is introduced. This task MUST NOT add those members, ScheduleView, or warning receipts. V1/V2 migration helpers remain testable historical transforms, and Plan 01 owns v2->v3 Schedule handling. Production migration to v4 rejects every desktop-less v1/v2/v3 source with `unsupported_pre_amendment_desktop_schema`, leaves source bytes unchanged, and never invents identity, issuer provenance, layout, capability, cost, receipt, sequence, recovery, or outbox state. A New Run constructs v4 directly from a durably committed issuer allocation and valid empty factories; it is not a migration exception.

**Interfaces:**

```gdscript
# DesktopConsequenceState.gd
static func make_empty(issuer_provenance: Dictionary) -> Dictionary
static func validate(state: Dictionary) -> Dictionary
static func validate_recovery_payload(source_kind: StringName,
		payload: Dictionary, expected_sha256: String) -> Dictionary
func capture() -> Dictionary
func prepare_restore(state: Dictionary) -> Dictionary
func prepare_sequence_reservation(request: Dictionary,
		causal_sequence_receipt: Dictionary) -> Dictionary
func prepare_action_handoff(action_receipt: Dictionary,
		expected_run_revision: int, recovery_payload: Dictionary) -> Dictionary
func prepare_schedule_recovery_transport(header: Dictionary,
		recovery_payload: Dictionary) -> Dictionary
func prepare_outbox_publication(request: Dictionary) -> Dictionary
func prepare_recovery_advance(transaction_id: String,
		expected_stage: StringName, next_stage: Variant,
		participant_receipts: Dictionary,
		destination_intent: Variant, notification_intent: Variant,
		publication_progress: Variant) -> Dictionary
func commit(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
static func checkpoint_content_preimage(checkpoint_header: Dictionary,
		stage_candidate: Dictionary) -> Dictionary

# DesktopCausalSequencePort.gd
func configure_publication_ledger(publication_ledger: Object) -> Dictionary
func configure(state: Object, mutation_gate: ApplicationMutationGate,
		admission_checkpoint_port: Object) -> Dictionary
func prepare_reservation(request: Dictionary) -> Dictionary
func prepare_admission(sequence_candidate: Dictionary,
		admission_checkpoint_candidate: Dictionary,
		recovery_payload_sha256: String) -> Dictionary
func capture() -> Dictionary
func commit(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
func publish(publication: Dictionary) -> Dictionary

# DesktopPublicationLedger.gd
const FIXED_PATH := "desktop-publications.json"
func configure(storage: Object) -> Dictionary
func load() -> Dictionary
func record_before_emit(request: Dictionary) -> Dictionary

# SaveManagerCheckpointPort.gd additions; Task-8 fake mirrors this subset
func prepare_consequence_checkpoint(checkpoint_header: Dictionary,
		stage_candidate: Dictionary) -> Dictionary
func commit_consequence_checkpoint(checkpoint_candidate: Dictionary,
		checkpoint_receipt: Dictionary) -> Dictionary

# ApplicationMutationGate.gd retained signatures
func acquire(owner_id: StringName) -> Dictionary
func release(owner_id: StringName, token: String) -> Dictionary
func guard_external(operation_id: StringName) -> Dictionary
func is_internal_owner_active(owner_id: StringName) -> bool

# DesktopContinuationRemapper.gd
static func collect_rewindable_transaction_ids(snapshot: Dictionary) -> Dictionary
static func prepare(snapshot: Dictionary, restore_transaction_id: String,
		identity_allocation_bundle: Dictionary) -> Dictionary
static func validate_remap(source: Dictionary, candidate: Dictionary) -> Dictionary

# DesktopFirstRevealSnapshotComposer.gd
static func compose(base_snapshot_input: Dictionary,
		game_state_candidate: Dictionary, board_candidate: Dictionary,
		consequence_candidate: Dictionary) -> Dictionary

# GameStateMinesweeperPort.gd additions
func prepare_first_reveal_consequence(board_candidate: Dictionary,
		transaction_id: String, transaction_issuer_receipt: Dictionary,
		expected_checkpoint_id: String) -> Dictionary
func validate_first_reveal_candidates(game_state_candidate: Dictionary,
		board_candidate: Dictionary, consequence_candidate: Dictionary) -> Dictionary

# MinesweeperRoundCoordinator.gd addition
func configure_publication_ledger(publication_ledger: Object) -> Dictionary
func configure_durable_checkpoint(checkpoint_port: Object,
		snapshot_composer: Script, consequence_state_port: Object) -> Dictionary

# DesktopConsequenceRestoreParticipant.gd / DesktopBoardRestoreParticipant.gd
func prepare(input: Dictionary) -> Dictionary
func capture() -> Dictionary
func apply_silent(plan: Dictionary) -> Dictionary
func rollback_silent(backup: Dictionary) -> Dictionary
func finalize() -> Dictionary

# DesktopIdentityAllocationRestoreParticipant.gd
func prepare(input: Dictionary) -> Dictionary
func capture() -> Dictionary
func apply_silent(plan: Dictionary) -> Dictionary
func rollback_silent(backup: Dictionary) -> Dictionary
func finalize() -> Dictionary

# SaveManagerMinesweeperPort.gd
func capture() -> Dictionary
func preview_checkpoint_id(run_id: String) -> Dictionary
func prepare_checkpoint(post_commit_snapshot_input: Dictionary,
		checkpoint_kind: StringName,
		disk_write: Dictionary) -> Dictionary
func commit_checkpoint(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary

# LogoutCoordinator.gd
func configure(save_manager: Object, route_port: Object,
		stable_board_port: Object) -> Dictionary
func request_logout(request: Dictionary) -> Dictionary
func retry_logout(transaction_id: String) -> Dictionary
func cancel_logout(transaction_id: String) -> Dictionary

# SaveManager.gd changed public boundaries
func start_new_run(initial_context: Dictionary) -> Dictionary
func commit_prepared_restore(prepared: Dictionary) -> Dictionary

# RunLifecycle.gd additions/changes
func reset(run_id: String, branch_id: String,
		desktop_timeline_generation: int,
		causal_day_instance: String,
		identity_allocation_receipt: Dictionary) -> void
func prepare_continuation_remap(restore_transaction_id: String,
		identity_allocation_bundle: Dictionary) -> Dictionary
func commit_continuation_remap(candidate: Dictionary) -> Dictionary
func get_desktop_identity_context() -> Dictionary
```

`reset()` extracts the exact `causal_day_instance_issuer_receipt` from the committed allocation bundle and rejects ID-only or mismatched provenance. `get_desktop_identity_context()` returns exactly `{run_id,branch_id,desktop_timeline_generation,causal_day_instance,causal_day_instance_issuer_receipt}` as detached primitives. Restore remap and each successful day advance replace the token and full receipt together; no intermediate snapshot may contain one without the other.

`prepare_recovery_advance()` never accepts or constructs a checkpoint receipt. `next_stage` is an exact `StringName|null`: ordinary graph advance names the next valid stage, one-callback progress uses `expected_stage=next_stage=&"publication_pending"`, and terminal cleanup alone uses `expected_stage=&"publication_pending",next_stage=null`. It validates the current immutable admission receipt, exact transition/operation ordinal, participant-receipt delta, intent delta, and optional publication-progress prefix, then succeeds exactly as `value={checkpoint_header,stage_candidate},receipt={}`. `checkpoint_header` is the exact six-key header frozen above; `stage_candidate` is the complete next semantic `DesktopConsequenceState` candidate with its new `checkpoint_receipt` still null and, only for admission, its not-yet-produced admission receipt absent from the preimage projection. The only legal consumer is the configured checkpoint port. For terminal cleanup, this method requires a complete publication cursor, freezes the current pending header before projection, and returns a semantic candidate whose pending transaction is null; no downstream owner reconstructs that header. `prepare_outbox_publication()` is deliberately outside this continuation graph: it cannot run until that cleanup is durable, cannot change `run_revision`, causal sequence, action/sequence receipts, payloads, or either outbox except one `published` bit, and creates no continuation-operation ordinal.

Task 6 changes the gate's exact owner allowlist from `restore|new_run` to `restore|new_run|causal_transaction` and changes no signature or token rule. `acquire()` remains one-argument; the returned opaque token plus active-owner identity proves the lease. Transaction/source identity belongs in the coordinator, issuer receipt, pending record, and checkpoint—not in a second gate argument or gate ledger.

`start_new_run()` accepts only the exact New-Run initial context frozen in the external journal; neither `MenuScene` nor another caller supplies a run/branch/generation/causal-day/transaction identity. While holding `new_run`, SaveManager issues the transaction root, prepares and commits the journal intent/allocation, then returns the allocated run ID only in the successful result. `commit_prepared_restore()` accepts only the opaque value returned by the existing `prepare_restore_slot|quick|autosave` methods; while holding `restore`, it reloads that value's semantic locator and document hash before issuing/recording the restore transaction. The deprecated `load_slot|quick_load|load_autosave` wrappers remain thin prepare-then-commit delegates and expose no identity or mapping input. A caller-authored prepared dictionary, locator/hash change, or input containing any issuer/allocation/remap field rejects before durable allocation.

The causal reservation request is exactly:

```gdscript
{
	"transaction_id": String,
	"transaction_issuer_receipt": Dictionary,
	"run_id": String,
	"branch_id": String,
	"desktop_timeline_generation": int,
	"causal_day_instance": String,
	"source_kind": "minesweeper_round" | "shop_purchase" | "schedule_done",
	"source_commit_receipt_id": String,
	"source_commit_receipt_provenance": Dictionary,
	"expected_last_sequence": int,
	"expected_run_revision": int,
}
```

Prepare success is exactly `value={sequence_candidate,causal_sequence_receipt}` and its outer receipt is an exact detached copy of `causal_sequence_receipt`:

```gdscript
{
	"receipt_id": String,
	"receipt_provenance": Dictionary,
	"transaction_id": String,
	"transaction_issuer_receipt": Dictionary,
	"run_id": String,
	"branch_id": String,
	"desktop_timeline_generation": int,
	"causal_day_instance": String,
	"source_kind": "minesweeper_round" | "shop_purchase" | "schedule_done",
	"source_commit_receipt_id": String,
	"source_commit_receipt_provenance": Dictionary,
	"causal_sequence": int,
	"run_revision": int,
}
```

The initial last sequence is zero. `prepare_reservation()` proposes `causal_sequence=expected_last_sequence+1` and `run_revision=expected_run_revision+1`. After the coordinator freezes every participant in `recovery_payload`, it first persists the full unpromoted source checkpoint (`action_prepared` for action sources, already-`prepared_checkpointed` for Schedule). `prepare_admission()` accepts only that full checkpoint/payload phase, then binds the sequence candidate, payload hash, and one checkpoint candidate whose persisted pending stage will be `sequence_committed`. Neither sequence nor revision is allocated yet. `commit(candidate)` requires the same active `causal_transaction` lease, repeats exact identity/source/last-sequence/run-revision/payload validation, commits the atomic admission checkpoint first, and only then forward-applies the same sequence receipt to live `DesktopConsequenceState`. That live adoption sets both pending receipt fields atomically: `admission_checkpoint_receipt` receives the committed admitted receipt and `checkpoint_receipt` is initially byte-equal to it; every later `prepare_recovery_advance()` preserves the former internally and replaces only the latter with the next forward receipt. A failed checkpoint commits no live mutation; disk success followed by live failure returns a typed committed-pending-recovery result, and startup adopts the checkpoint before input. This checkpoint promotion is the final compare-and-swap/admission point shared by every source kind.

An identical retry returns the original candidate/receipt; the same transaction or source receipt with changed bytes returns `causal_sequence_conflict`. Minesweeper completion, Shop purchase, condition departure, and Plan-03 Schedule Done inject this one port; no other sequence, revision, admission checkpoint, or gate owner is legal.

`capture()` succeeds with exact `value={backup}` and empty outer receipt. `commit(candidate)` succeeds with exact `value={causal_sequence_receipt,admission_checkpoint_receipt}` and an outer receipt exactly `{causal_sequence_receipt,admission_checkpoint_receipt}`. `rollback(backup)` succeeds with exact `value={restored:true}` only before admission checkpoint commit; after admission it returns `causal_admission_irreversible` and recovery must advance forward. `publish()` accepts exactly `{causal_sequence_receipt,admission_checkpoint_receipt}` and succeeds with exact `value={published:true}` plus the same exact outer receipt. Every failure uses the master failure envelope. Plan 03 consumes these exact shapes and may not invent a parallel adapter contract.

Task 1's `DesktopIssuerRootStore` writes one strict primitive `desktop-issuer-root.json` through injected atomic storage. Its exact append-only document is `{schema_version:1,namespace,next_counter,receipts,allocation_receipts,day_advance_allocation_receipts}` and is not a Save slot, autosave, run snapshot, profile-reset member, or selectable restore participant. `day_advance_allocation_receipts` defaults to `{}`, is required by the schema/validator/capture result, and is keyed by the exact allocation key; it is disjoint from transaction-ID-keyed `allocation_receipts` and stores the exact receipt frozen above. Each referenced source/target issuer receipt must exist byte-identically in `receipts`. Preparing a missing key is pure. Committing it atomically adds its target issuer receipt, map record, and one counter increment; same-key identical replay is a no-op success, and deletion/replacement is forbidden. On first use, `CryptoDesktopNamespaceSource` creates 32 bytes with an owned `Crypto` instance, the store atomically commits lowercase hex and counter 1, and only then may the issuer issue. No API accepts a replacement namespace, lower counter, receipt deletion, or arbitrary token. Task 6 consumes these bytes unchanged. The Task-6 edit to `MenuScene.gd` is limited to deleting `Time.get_ticks_usec()/randi()` ID construction and calling the new SaveManager signature; it changes no copy, layout, scene ownership, or visible flow.

There is no bootstrap identity cycle: after `load_or_create()` has durably established the root, `DesktopIdentityNonceIssuer.issue(&"transaction_id")` needs only the purpose and current root counter, not a caller transaction ID. SaveManager asks the issuer for a mutation-free allocation candidate, then commits Task 1's external continuation-journal `intent_committed` record containing that candidate fingerprint before it calls `commit_continuation_allocation()`. A crash before journal intent merely burns the already durable transaction token. A crash after intent reloads the exact restore locator/hash or New-Run context/hash and retries the same candidate; after allocation, recovery advances only forward. Neither path can reuse an abandoned counter or accept a caller-authored fallback.

The continuation allocation bundle is exact:

```gdscript
{
	"allocation_receipt_id": String,
	"transaction_id": String,
	"transaction_issuer_receipt": Dictionary,
	"kind": "new_run" | "restore",
	"namespace": String,
	"counter_start": int,
	"counter_end": int,
	"run_id": String,
	"branch_id": String,
	"desktop_timeline_generation": int,
	"causal_day_instance": String,
	"causal_day_instance_issuer_receipt": Dictionary,
	"receipt_ids": {
		"run_id": String,
		"branch_id": String,
		"desktop_timeline_generation": String,
		"causal_day_instance": String,
	},
	"transaction_remap": Dictionary, # source transaction ID -> exact record below
}
```

The root store's `allocation_receipts` map key equals `transaction_id`; the bundle's full `transaction_issuer_receipt` is byte-equal to the journaled purpose-`transaction_id` receipt and its token equals that map key. `causal_day_instance_issuer_receipt` is byte-equal to the purpose-`causal_day_instance` root record whose token equals the adjacent field and whose receipt ID equals `receipt_ids.causal_day_instance`. Each restore `transaction_remap` value is exactly `{source_transaction_id,new_transaction_id,new_transaction_issuer_receipt}`; map key equals `source_transaction_id`, the new receipt is purpose `transaction_id`, and its token equals `new_transaction_id`. New Run requires `{}`. For restore, `run_id` and its receipt ID are validated source provenance rather than newly allocated; every other lifecycle/remap identity is fresh. `counter_end` is the exclusive next counter and must equal the root's post-commit `next_counter`. Run, consequence, board remap, checkpoint, and restore journal all bind the same allocation receipt ID and canonical transaction-remap hash.

Selected Load prepares `DesktopIdentityAllocationRestoreParticipant` before any live participant. Its input is exactly `{restore_transaction_id,transaction_issuer_receipt,source_locator,existing_run_id,source_desktop_timeline_generation,remap_source_transaction_ids,allocation_candidate_fingerprint}`. Mutation-free `prepare()` reloads and hash-verifies `source_locator`, reruns `collect_rewindable_transaction_ids()` and requires byte-equality with the supplied sorted set, asks the issuer for the exact candidate containing a fresh branch token, numeric `source+1` generation allocation, causal-day token/full issuer receipt, and transaction remap, and matches the frozen fingerprint; Run/consequence/board prepare functions build against that exact proposed bundle. `apply_silent()` repeats root and external-journal validation, durably commits the append-only candidate, and advances the journal to `identity_allocation_committed` before `RunRestoreParticipant.apply_silent()`; duplicate restore transaction/request bytes reuse the exact bundle. `rollback_silent()` returns exact `value={retained_allocation:true}` and never decrements the counter or deletes receipts—failed restore may burn identities but can never reuse them. Run lifecycle candidates store the full current causal-day issuer receipt plus the other required allocation receipt IDs; consequence/board/checkpoint candidates bind the adjacent identity and allocation ancestry. A snapshot's `observed_counter` is validation evidence only and cannot advance or rewind the root.

Logout request is exactly `{transaction_id,transaction_issuer_receipt,confirmed}` and the full transaction receipt must ledger-verify. `confirmed=false` is a no-op. Yes awaits only an executing bounded board/preparation slice, calls `SaveManager.save_for_logout()`, proves the committed logout/autosave receipt, then routes to title. A disk failure keeps the run, board, consequence state, and issuer high-water byte-equal and returns exact `logout_save_failed`; retry reuses the same transaction identity/receipt. Numbered slots are never called.

The selected Load consumes only that committed allocation bundle; no scene or run snapshot can author a branch, generation, causal-day, or remap value. The closed v4 remap allowlist is board identity fields; every board-local command/idempotency dictionary key and embedded transaction ID/full issuer receipt; current-causal-day base-completion and Supportz records; consequence sequence/action receipt keys and embedded transaction/provenance records; pending recovery payload keys/references; publication-plan semantic receipts; publication-progress callback receipts; immutable admission/current checkpoint receipts plus their explicit preimage-header ancestry; unpublished outbox keys/references; and their identity fingerprints. The remapper first replaces every allowlisted root transaction through `transaction_remap`, then re-derives every allowlisted child ID/provenance from the mapped parent using its unchanged kind/ordinal and recursively mapped/sorted source IDs, then recomputes dictionary keys, preimage hashes, plan/progress bindings, and fingerprints from semantic values. It emits one `continuation_operation` child remap receipt anchored to the restore transaction and binding the canonical source->target mapping hash. Missing, extra, multiply mapped, dangling, old-parent, unsorted-set, or string-edited identities reject.

This preserves processed meaning while changing rewindable namespaces. It cannot touch permanent Gallery/Observer/attempt/deck/visited-line/profile ledgers, import abandoned-future receipts, perturb any of the three RNG frontiers/layout, lower the issuer root counter, or alter v3 `committed_schedule`. Plan 03 extends the same scanner/remapper for v5 ScheduleView warning/navigation identities and the mutually exclusive lifecycle `active_condition_hospital_plan` variant's exact root/child IDs and full provenance—never a second remapper or restore participant. Completed `condition_hospital_history` entries are validated append-only, remain non-rewindable semantic evidence, and are never made active or added to `remap_source_transaction_ids`; v4->v5 migration and New Run initialize that map to `{}` and never infer history from an outbox/Contacts row. Every New-Run/restore startup calls `DesktopContinuationOperationJournal.list_incomplete()` before run input. Reconciliation reloads the named restore source by locator/hash or revalidates the journaled New-Run initial context, recomputes plans, reuses the recorded allocation, resumes participant apply, records `participants_applied`, finalizes publication, and only then marks `completed`; it never relies on SaveManager's process-memory restore journal.

**Production first-Reveal candidate law:** `GameStateMinesweeperPort.prepare_first_reveal_consequence()` returns three separately detached candidates bound to the same ledger-verified transaction receipt: the narrow GameState cost/counter candidate, `DesktopBoardState` adoption candidate, and `DesktopConsequenceState` first-Reveal checkpoint marker at one expected run revision. `validate_first_reveal_candidates()` recomputes their identity, transaction, pre/post revision, paid-start receipt, checkpoint ID, and board proof/hash parity. `DesktopFirstRevealSnapshotComposer` accepts only that validated tuple plus a base v4 capture. `MinesweeperRoundCoordinator.configure_durable_checkpoint()` replaces the Task-5 fake seam only after v4 is green and retains the same issuer/generator/state owner identities; it cannot install a second coordinator or silently adapt a fake candidate.

- [ ] **Step 6.1: Prove the Plan-01/v3 integration gate**

Run this exact read-only boundary guard from repository root before any Task-6 edit:

```powershell
$boundaryPath = 'evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json'
$evidenceCommit = (git log -1 --format=%H -- $boundaryPath).Trim()
if ($LASTEXITCODE -ne 0 -or $evidenceCommit -cnotmatch '^[0-9a-f]{40}$') { throw 'Plan-01 v3 evidence commit missing' }
$evidenceSubject = (git show -s --format=%s $evidenceCommit).Trim()
if ($evidenceSubject -cne 'chore(evidence): bind committed Schedule v3 boundary') { throw 'Plan-01 v3 evidence subject mismatch' }
$parents = @(((git show -s --format=%P $evidenceCommit).Trim() -split ' ') | Where-Object { $_ })
if ($parents.Count -ne 1) { throw 'Plan-01 v3 evidence commit must have one parent' }
$recordedBoundaryBlob = (git rev-parse "${evidenceCommit}:$boundaryPath").Trim()
$currentBoundaryBlob = (git hash-object -- $boundaryPath).Trim()
if ($LASTEXITCODE -ne 0 -or $recordedBoundaryBlob -cne $currentBoundaryBlob) { throw 'Plan-01 v3 boundary record drift' }
$boundary = ((git show "${evidenceCommit}:$boundaryPath") -join "`n") | ConvertFrom-Json
$expected_keys = @('boundary_commit','boundary_subject','focused_log_path','focused_log_sha256','migration_path','migration_sha256','owner_beads_id','run_snapshot_schema_path','run_snapshot_schema_sha256','save_document_schema_path','save_document_schema_sha256','schema_version') | Sort-Object
$actual_keys = @($boundary.PSObject.Properties.Name) | Sort-Object
if (Compare-Object $expected_keys $actual_keys) { throw 'invalid Plan-01 boundary field set' }
if ($boundary.schema_version -ne 1 -or $boundary.owner_beads_id -ne 'dwm-p2r.13' -or $boundary.boundary_subject -ne 'feat(save): persist canonical committed Schedule') { throw 'invalid Plan-01 boundary identity' }
if ($boundary.run_snapshot_schema_path -ne 'scripts/domain/run/RunSnapshotSchema.gd' -or $boundary.save_document_schema_path -ne 'scripts/infrastructure/save/SaveDocumentSchema.gd' -or $boundary.migration_path -ne 'scripts/infrastructure/save/SaveMigrations.gd') { throw 'invalid Plan-01 bound source path' }
if ($boundary.boundary_commit -cnotmatch '^[0-9a-f]{40}$') { throw 'invalid Plan-01 boundary commit SHA' }
$focusedLogPath = [string]$boundary.focused_log_path
if ($focusedLogPath -cne 'evidence/phase_2r/logs/p2r13-schedule-v3-green.log') { throw 'invalid Plan-01 focused-log path' }
$recordedLogBlob = (git rev-parse "${evidenceCommit}:$focusedLogPath").Trim()
$currentLogBlob = (git hash-object -- $focusedLogPath).Trim()
if ($LASTEXITCODE -ne 0 -or $recordedLogBlob -cne $currentLogBlob) { throw 'Plan-01 v3 focused-log drift' }
if ($parents[0] -cne $boundary.boundary_commit) { throw 'Plan-01 evidence/code parent mismatch' }
$recorded_subject = git show -s --format=%s $boundary.boundary_commit
if ($LASTEXITCODE -ne 0 -or $recorded_subject -cne $boundary.boundary_subject) { throw 'Plan-01 boundary commit subject mismatch' }
git merge-base --is-ancestor $boundary.boundary_commit HEAD
if ($LASTEXITCODE -ne 0) { throw 'Plan-01 v3 boundary is not integrated' }
git merge-base --is-ancestor $evidenceCommit HEAD
if ($LASTEXITCODE -ne 0) { throw 'Plan-01 v3 evidence is not integrated' }
foreach ($digest in @($boundary.run_snapshot_schema_sha256,$boundary.save_document_schema_sha256,$boundary.migration_sha256,$boundary.focused_log_sha256)) {
	if ($digest -cnotmatch '^[0-9a-f]{64}$') { throw 'invalid Plan-01 boundary digest' }
}
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_v3_boundary_check' -LogName 'p2r9-v3-boundary-check.log' -GodotArgs @('-s','res://tools/schedule/generate_schedule_v3_boundary.gd','--','--check',"--evidence-commit=$evidenceCommit",'--record=res://evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json')
if ($LASTEXITCODE -ne 0) { throw 'Plan-01 v3 historical boundary check failed' }
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_v3_boundary_gate' -LogName 'p2r9-v3-boundary-gate.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_schedule_v3_boundary.gd','-gexit')
if ($LASTEXITCODE -ne 0) { throw 'Plan-01 v3 boundary schema/source validator failed' }
if ((Get-FileHash $boundary.run_snapshot_schema_path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $boundary.run_snapshot_schema_sha256) { throw 'RunSnapshotSchema drift' }
if ((Get-FileHash $boundary.save_document_schema_path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $boundary.save_document_schema_sha256) { throw 'SaveDocumentSchema drift' }
if ((Get-FileHash $boundary.migration_path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $boundary.migration_sha256) { throw 'SaveMigrations drift' }
if ((Get-FileHash $focusedLogPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $boundary.focused_log_sha256) { throw 'Plan-01 focused-log digest drift' }
```

Then rerun the focused schema/document/migration tests named by that evidence and assert by source scan that `SCHEMA_VERSION == 3`, `DOCUMENT_VERSION == 3`, `committed_schedule` is present, and no `desktop` or `schedule_view` top-level member exists. Expected: all checks pass before the first Task-6 edit.

- [ ] **Step 6.2: Add parse-only skeletons, then write RED exact-v4, consequence-state, and causal-sequence tests**

Create every new Task-6 script with its declared typed API and deterministic `not_implemented` failures, plus schema-valid v4 fixture containers. Prove each script/fixture loads before behavioral assertions. Task-1 issuer/root/journal tests must remain green throughout; no missing preload or parse error counts as RED.

Assert the exact `{board,consequence}` aggregate, valid empty factories, every malformed/extra consequence member, both discriminated recovery-payload unions, the source-only versus admission-ready action phases/presence laws, every member/aggregate SHA mutation, all source-kind stages and exact zero-based stage/progress/cleanup ordinals, exact outbox/receipt maps, snapshot-only issuer provenance, append-only root initialization/high-water/allocation rules, the shared causal request/result contract, identical retry, changed-payload conflict, stale sequence, stale run revision, and final-CAS race. The lifecycle exact-key tests require the full `causal_day_instance_issuer_receipt`, verify its external-root membership/purpose/token, require New Run/restore allocation bundles to carry the byte-equal receipt, and reject ID-only, adjacent-token drift, or remap of only one member. Mutate each stage/ordinal/payload-phase combination and prove rejection. Independently delete, add, null, replace, or rotate `admission_checkpoint_receipt`; assert null before admission, equality with the admitted current receipt at `sequence_committed`, byte-identity while later current receipts rotate, and rejection when any publication recipe embeds an admission/current checkpoint receipt or self-hash. Table-drive every exact publication callback list, cursor/prefix receipt ledger, omitted optional callback, and plan-hash binding. Strictly test the desktop publication-ledger empty document, three exact key/record/publication unions, canonical hash, record-before-emit first/replay/conflict results, atomic re-read, malformed startup failure, exact storage-root capability, same-object replay, replacement rejection, and disjointness from Plan 01's ledger. Table-drive `checkpoint_content_preimage()` for every stage/progress/cleanup operation; prove its explicit header is mandatory at cleanup, the current receipt is nulled, the admission receipt is omitted only from its own preimage, every later preimage retains it, source-ID values are lexically sorted after set projection, and any caller-authored hash/circular receipt/header mismatch rejects. Prove cleanup alone produces `pending_stage=null,disposition=terminal_cleanup`, stores that receipt only in the journal beside a pending-null candidate, and rejects every receipt/disposition/ordinal permutation. Independently prove `prepare_outbox_publication()` rejects nonnull pending state, Day-7 destination, wrong outbox kind/key/payload hash/provenance/consumer/status, a notification receipt not identical to its intent, a Hospital receipt not validating as the same-root `hospital_resolution` bound to its exact destination/condition/source set, and any attempted change beyond one false-to-true bit; prove byte-identical accepted replay returns the same candidate/receipt and allocates no root, new child kind, stage, callback, or continuation ordinal. Destroy/recreate the checkpoint port between prepare and commit/retry and prove the exact transaction/ordinal locator formula reproduces byte-identical output; mutate or supply a locator and reject. Prove an older selectable snapshot cannot lower or replace the issuer root. Assert v3 input rejects unchanged and New Run durably allocates identities before preparing a complete v4 directly.

- [ ] **Step 6.3: Run the first RED**

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_v4_contract_red' -LogName 'p2r9-v4-contract-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_consequence_state.gd,res://tests/unit/test_desktop_causal_sequence_port.gd,res://tests/unit/test_desktop_publication_ledger.gd,res://tests/unit/test_desktop_issuer_root_store.gd,res://tests/unit/test_causal_day_advance_identity_port.gd,res://tests/unit/test_desktop_continuation_operation_journal.gd,res://tests/unit/test_save_manager_checkpoint_port.gd,res://tests/unit/test_run_lifecycle.gd,res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_document_schema.gd,res://tests/unit/test_save_migrations.gd,res://tests/integration/test_new_run_transaction.gd','-gexit')
```

Expected: all scripts and fixtures parse; Task-1 issuer/journal tests remain green, while v4/consequence/causal/schema behavioral assertions fail on typed unimplemented behavior. No production first-Reveal test exists yet.

- [ ] **Step 6.4: Implement v4 and its state owners before any board checkpoint adapter**

Implement exact RunSnapshot/SaveDocument v4 dispatch, `DesktopConsequenceState`, direct-v4 New Run over Task-1 issuer/journal seams, the `causal_transaction` gate owner, the distinct root-scoped `DesktopPublicationLedger`, and the shared causal port with fail-closed ledger configuration. `RunLifecycle`, `RunSnapshotSchema`, `SaveDocumentSchema`, SaveManager capture, `RunRestoreParticipant`, `DesktopConsequenceRestoreParticipant`, `DesktopContinuationRemapper`, and every v4 fixture bind the literal current causal-day token plus full issuer receipt as one inseparable pair; New Run/restore installs it only from the committed allocation bundle. Those same owners bind `publication_progress`, `admission_checkpoint_receipt`, and `checkpoint_receipt`; `SaveMigrations` has no default/synthesis branch for any of them and neither external ledger is a snapshot/remap member. Validate every candidate twice and use a single compare-and-swap owner for sequence plus run revision. Add static ownership assertions that only the continuation allocator or shared day-advance port can replace the causal-day pair, only causal admission sets the immutable field, only consequence-stage/progress advance replaces the current field, only `DesktopConsequenceState` builds checkpoint preimages, progress never mutates the frozen recovery payload, and each Plan-02 publisher calls only the configured ledger's record-before-emit seam. At the end of this step, `SaveManagerMinesweeperPort.gd` and production first-Reveal wiring still contain only their parse-only skeletons and cannot be configured.

- [ ] **Step 6.5: Run v4 GREEN**

Run Step 6.3. Expected: exit 0. Also scan `SaveManagerMinesweeperPort.gd`, `MinesweeperRoundCoordinator.gd`, and `ApplicationBootstrap.gd`; the adapter remains a typed `not_implemented` skeleton, no production coordinator configuration exists, and no first-Reveal persistence path is callable at this boundary.

- [ ] **Step 6.6: Write RED restore, remap, action-matrix, and Logout tests**

For `NONE`, multiple `PREPARING` slices, `PREPARED_UNSTARTED`, both active visibility states, `SETTLING`, every source-kind pending consequence stage including both action pre-admission stages, completed, discarded, and forfeited truth, validate canonical JSON round-trip and exact restore. Corrupt each identity/layout/RNG/revision/cost/proof/receipt/journal/outbox/provenance/recovery-payload/publication-progress member and assert fail closed before live mutation. Restore `action_checkpointed` and prove only source bytes are consumed to repeat pure preparation; restore `action_prepared` and prove no candidate is recomputed. At every admitted action/Schedule stage and publication prefix, prove save/document/schema/restore/remap preserve the immutable admission receipt, callback prefix/receipts, explicit checkpoint header ancestry, and rotating current receipt byte-for-byte. For a synthetic schema-exact `schedule_done` transport, crash after sequence CAS at every later stage and after each callback apply/progress checkpoint; prove only the exact persisted candidate/hash/cursor is returned to injected fakes—never recomputed from changed live state—and apply-before-progress retries the same receipt without a second effect. Cover Save, quick Save, same-day Home/switch, Logout, selected Load, delete-another-slot, and New Run for every applicable phase. Crash before external intent, after `intent_committed`, after durable allocation, and before/after each live apply; restart with empty process memory and assert the external journal reloads the exact restore locator/hash or New-Run context/hash, resumes from its durable stage, duplicate restore reuses the bundle, live state rolls back before participant apply or advances forward after it, and the root counter never decrements.

- [ ] **Step 6.7: Run restore RED**

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_persistence_red' -LogName 'p2r9-persistence-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_identity_allocation_restore_participant.gd,res://tests/unit/test_desktop_continuation_remapper.gd,res://tests/unit/test_logout_coordinator.gd,res://tests/unit/test_run_lifecycle.gd,res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_migrations.gd,res://tests/integration/test_save_capability.gd,res://tests/integration/test_restore_transaction.gd,res://tests/integration/test_desktop_board_persistence.gd','-gexit')
```

Expected: participant/remap/logout assertions fail while Step-6.5 v4 tests remain green.

- [ ] **Step 6.8: Implement remap, identity allocation plus two desktop restore participants, lock removal, and Logout**

Extend `RunLifecycle` as holder—but never minter—of issuer-provided run/branch/generation/causal-day values. Remove `minesweeper_board` from SaveManager's lock-owner allowlist and capability cases; `acquire_save_lock(&"minesweeper_board")` rejects as unknown. Every participant `prepare()` remains mutation-free: identity prepare proposes the exact bundle, the external journal durably freezes locator/hash/candidate fingerprint, then Run/consequence/board prepare their candidates from that proposal before any apply. Exact forward order is `identity_allocation -> run -> desktop_consequence -> desktop_board -> profile -> localization -> audio -> route -> narrative`. The first apply repeats root/journal validation, durably commits the allocation, and records `identity_allocation_committed`; Run then applies the already prepared candidate bound to that same receipt. Before any live apply, later failure rolls ordinary candidates back in reverse. After the first live participant applies, recovery owns forward completion and never uses a broad pre-operation snapshot to undo over concurrent state. A failure after allocation but before Run apply retries the same restore transaction and receives the same allocation bundle. Both desktop state participants remain silent until the sole aggregate restore publication. Applying consequence before board lets a restored `SETTLING` board validate its pending journal owner. Failure at every intent/allocation/apply/publication position proves idempotent reconciliation, byte-exact no-mutation before apply, forward completion after apply, or one fatal latch when recovery cannot be proven. Logout uses only the normal logout/autosave document.

- [ ] **Step 6.9: Run restore GREEN**

Run Step 6.7. Expected: exit 0, production persistence access count 0 under the isolated wrapper.

- [ ] **Step 6.10: Write RED production first-Reveal durability tests**

Only now fill `test_minesweeper_first_reveal_transaction.gd` behavior. Configure the real `SaveManagerMinesweeperPort` over an isolated store and v4 providers, and configure the existing Task-5 `MinesweeperRoundCoordinator`/`GameStateMinesweeperPort` through the new durable seam. Assert the adapter rejects schema 3, a mismatched SaveDocument version, a missing desktop member, an extra desktop key, a board-only desktop value, or candidates whose GameState/board/consequence revisions disagree. Prove `DesktopFirstRevealSnapshotComposer` builds the checkpoint input from the exact detached **post-commit** GameState candidate, board candidate, and same-revision consequence candidate—not by capturing pre-commit live state. At checkpoint commit, the disk document must already contain the decremented round, charged motivation, paid-start receipt, materialized/revealed board, and matching consequence revision. Crash-inject checkpoint intent/write/replace, then the gap before each live commit and publication; restart through real restore and prove forward adoption of that disk truth, exactly one paid first Reveal, and no second charge.

- [ ] **Step 6.11: Run the production RED**

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_first_reveal_durable_red' -LogName 'p2r9-first-reveal-durable-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_first_reveal_snapshot_composer.gd,res://tests/integration/test_minesweeper_first_reveal_transaction.gd,res://tests/integration/test_desktop_board_persistence.gd','-gexit')
```

Expected: every production adapter/coordinator script parses; assertions fail because durable configuration/candidate parity/forward recovery is still typed unimplemented, while all v4 schema tests remain green.

- [ ] **Step 6.12: Implement the production checkpoint adapter and rerun through disk**

Implement the existing parse-only `SaveManagerMinesweeperPort` at this step. It accepts only a composer-produced detached post-commit v4 snapshot, rejects every other document/schema/shape/revision before preview or disk intent, and uses the existing atomic checkpoint journal. Configure the real Task-5 coordinator only in the isolated integration harness; Task 9 owns application bootstrap. The exact production first-Reveal order is guard -> verify issuer receipt -> validate current state/request -> purely materialize -> prepare GameState cost candidate -> prepare board adoption candidate -> prepare same-revision consequence candidate -> validate the candidate triple -> compose and fully validate the post-commit v4 SaveDocument -> prepare checkpoint -> commit checkpoint -> forward-commit GameState/consequence/board live candidates -> publish. Nothing is adopted live before checkpoint commit. The checkpoint journal records the exact candidate/receipt fingerprints needed to forward-adopt committed disk truth after a crash before live commit; recovery never re-executes cost deltas. No v3 checkpoint, pre-commit snapshot, or board-only durable state can be produced.

- [ ] **Step 6.13: Run production GREEN and static identity audit**

Run Step 6.11 and the Step-6.3/6.7 suites. Then run:

```powershell
rg -n "Time\.|randi\(|RandomNumberGenerator|instance_id" autoload/GameState.gd scripts/ui/MenuScene.gd scripts/application/desktop scripts/application/minesweeper scripts/domain/desktop scripts/domain/minesweeper
```

Expected: exit 0 for all tests; the scan has no canonical identity/nonce fallback. Test-only isolated-directory randomness is outside this production scan.

- [ ] **Step 6.14: Proposed commit boundary**

Exact paths: the forty-eight Task-6 paths. Proposed subject:

```text
feat(persistence): install exact desktop durability and causal state
```

## Task 7: Implement prospective, exactly-once capability purchases

**Requirements:** `req.shop.capabilities`, `req.desktop.cross_app_actions`, `req.minesweeper.safety_capabilities`; amendment §§8 and 12.6.

**Files:**

- Create: `scripts/domain/desktop/DesktopActionReceipt.gd`
- Create: `scripts/application/shop/MinesweeperShopPurchaseParticipant.gd`
- Create: `scripts/application/shop/GameStateMinesweeperShopPort.gd`
- Create: `tests/support/FakeMinesweeperShopStatePort.gd`
- Create: `tests/unit/test_desktop_action_receipt.gd`
- Create: `tests/unit/test_minesweeper_shop_purchase_participant.gd`
- Create: `tests/integration/test_minesweeper_shop_transaction.gd`
- Modify: `autoload/GameState.gd`
- Modify: `tests/unit/test_shop_rules.gd`
- Modify: `tests/unit/test_game_state.gd`
- Modify: `evidence/phase_2r/runtime/game_state_required_surface.json`

**Interfaces:**

```gdscript
# DesktopActionReceipt.gd
static func validate(receipt: Dictionary) -> Dictionary
static func fingerprint(receipt: Dictionary) -> Dictionary

# MinesweeperShopPurchaseParticipant.gd
func configure_publication_ledger(publication_ledger: Object) -> Dictionary
func configure(state_port: Object, consequence_state_port: Object,
		checkpoint_port: Object, registry: Script,
		identity_issuer: Object, mutation_gate: ApplicationMutationGate) -> Dictionary
func quote(item_id: String, transaction_id: String,
		transaction_issuer_receipt: Dictionary) -> Dictionary
func prepare_purchase(request: Dictionary) -> Dictionary
func capture() -> Dictionary
func commit(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
func publish(publication: Dictionary) -> Dictionary

# GameStateMinesweeperShopPort.gd
func guard_external(operation_id: StringName) -> Dictionary
func capture() -> Dictionary
func prepare_purchase(item: Dictionary, quote: Dictionary,
		transaction_id: String, transaction_issuer_receipt: Dictionary) -> Dictionary
func commit(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
func publish(publication: Dictionary) -> Dictionary
```

Purchase request has exactly `transaction_id`, `transaction_issuer_receipt`, `item_id`, `quote_id`, `expected_run_revision`, and `expected_causal_day_instance`. The participant ledger-verifies the full transaction receipt, reloads the immutable item, revalidates quote, funds, branch/day identity, purchase counts, daily Supportz receipt, base completion receipts, and idempotency at prepare and commit. Caller-supplied price, effect, capability, count, or currency is rejected as an extra key.

`quote()` is pure apart from retaining idempotency truth in the participant candidate. Success value/outer receipt are the same exact record `{quote_id,quote_id_provenance,transaction_id,transaction_issuer_receipt,item_id,currency,price,registry_version,request_fingerprint}`; `quote_id` is child kind `shop_quote` anchored to the full transaction receipt. Purchase prepare requires its retained byte-exact quote record; a caller-provided quote ID without that record, a changed registry record, or a second item under the same transaction conflicts.

Every successfully prepared purchase produces the exact action shape consumed by Task 8 and Plan 03; it becomes committed only after causal admission:

```gdscript
{
	"schema_version": 1,
	"action_id": String,
	"action_id_provenance": Dictionary,
	"action_kind": "minesweeper_round" | "shop_purchase",
	"run_id": String,
	"branch_id": String,
	"desktop_timeline_generation": int,
	"causal_day_instance": String,
	"day": int,
	"transaction_id": String,
	"transaction_issuer_receipt": Dictionary,
	"source_commit_receipt_id": String,
	"source_commit_receipt_provenance": Dictionary,
	"condition_before": {"health":int,"pressure":int,"carried_sequela":bool},
	"condition_after": {"health":int,"pressure":int,"carried_sequela":bool},
	"unlock_receipt_ids": Array[String],
	"commit_receipt_id": String,
	"commit_receipt_provenance": Dictionary,
}
```

`unlock_receipt_ids` is sorted and unique. Lucky, Debug, and Supportz do not directly change the condition triple, so before and after are byte-equal for these three purchases. Task 7 prepares the typed economy/capability candidate and derived action receipt, acquires/retains the shared `causal_transaction` lease, and durably records the source-only unpromoted `action_checkpointed` candidate while live economy, board, sequence, and outboxes remain byte-equal. Its public result is pending, never audience success. Task 8 alone freezes downstream participants in the distinct immutable `action_prepared` checkpoint, repeats the final sequence/run-revision CAS, promotes `sequence_committed`, and then forward-commits the purchase and receipt. `commit(candidate)` rejects unless the same gate lease is active and the matching pending transaction is already `sequence_committed`. This prevents a charged purchase from losing the causal CAS or a durable purchase from lacking its exact action handoff.

- [ ] **Step 7.1: Add parse-only skeletons, then write RED purchase tests**

Create each new Task-7 script/fake with its declared typed surface and deterministic `not_implemented` failures. Prove every preload through `DynamicScriptProbe` before behavior assertions; a parser/load error is not RED.

Cover affordability, exact quote, wrong currency, once-per-branch Lucky/Debug, Supportz two-base-completion eligibility, once-per-causal-day and three-per-branch caps, floor sequence `0,-1,-2,-3`, full issuer-receipt validation, duplicate equality, changed-payload conflict, rapid input, rollback, mutation detachment, mandatory same-object desktop-publication-ledger configuration/replay/replacement rejection, durable `action_checkpointed` with byte-equal live state, commit rejection before `sequence_committed`, crash/restart from the exact pending action receipt, record-before-emit retry with no second signal, and release only after publication/abandonment.

Assert a purchase while `PREPARING`, `PREPARED_UNSTARTED`, `ACTIVE_VISIBLE`, or `ACTIVE_SUSPENDED` leaves the existing candidate/board's frozen spec and capability IDs byte-identical. A later candidate observes the new capability.

- [ ] **Step 7.2: Run RED**

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_shop_transaction_red' -LogName 'p2r9-shop-transaction-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_action_receipt.gd,res://tests/unit/test_desktop_consequence_state.gd,res://tests/unit/test_minesweeper_shop_purchase_participant.gd,res://tests/unit/test_shop_rules.gd,res://tests/integration/test_minesweeper_shop_transaction.gd','-gexit')
```

Expected: all scripts parse; purchase/action-receipt assertions fail only on typed unimplemented behavior.

- [ ] **Step 7.3: Implement prepare/commit/rollback/publish**

The port prepares typed currency/inventory/capacity deltas against current live state and an exact pending-consequence candidate; it never saves or restores a whole pre-purchase snapshot over unrelated changes. It checkpoints that source candidate at `action_checkpointed` while live truth is unchanged and hands it to Task 8; it does not invent downstream condition/consequence bytes. Task 8 writes `action_prepared` only after every downstream candidate is frozen. Before causal admission, abandonment marks the latest unpromoted checkpoint and releases the lease. After `sequence_committed`, crash recovery forward-adopts typed fields and advances the source-kind stage; it never reapplies currency/capacity deltas or rolls sequence backward. Publication is exactly once and never describes hidden capability mechanics.

- [ ] **Step 7.4: Run GREEN**

Run Step 7.2 plus `test_game_state.gd`. Expected: exit 0.

- [ ] **Step 7.5: Proposed commit boundary**

Exact paths: the eleven Task-7 files. Proposed subject:

```text
feat(shop): transact prospective Minesweeper capabilities exactly once
```

## Task 8: Expose board fate and prepared-action causal consequence ports

**Requirements:** `req.minesweeper.causal_departure`, `req.shop.capabilities`, `req.desktop.cross_app_actions`, `req.minesweeper.round_contract`; amendment §§6.7–6.8, 9.4, 12.2, 12.5–12.7.

**Files:**

- Create: `scripts/application/minesweeper/DesktopBoardFatePort.gd`
- Create: `scripts/application/desktop/DesktopConsequenceCoordinator.gd`
- Create: `tests/support/FakeDesktopConditionPolicyPort.gd`
- Create: `tests/support/FakeScheduleDepartureViewPort.gd`
- Create: `tests/support/FakeDesktopConsequenceCheckpointPort.gd`
- Create: `tests/unit/test_desktop_board_fate_port.gd`
- Create: `tests/unit/test_desktop_consequence_coordinator.gd`
- Create: `tests/integration/test_desktop_completion_transaction.gd`
- Create: `tests/integration/test_shop_condition_contract_departure.gd`
- Modify: `scripts/application/minesweeper/MinesweeperRoundCoordinator.gd`
- Modify: `scripts/application/shop/MinesweeperShopPurchaseParticipant.gd`
- Modify: `scripts/application/minesweeper/GameStateMinesweeperPort.gd`
- Modify: `tests/unit/test_minesweeper_round_coordinator.gd`
- Modify: `tests/unit/test_minesweeper_shop_purchase_participant.gd`

**Interfaces:**

**Frozen board-fate interface:**

```gdscript
# DesktopBoardFatePort.gd
func configure_publication_ledger(publication_ledger: Object) -> Dictionary
func prepare_causal_departure(request: Dictionary) -> Dictionary
func prepare_projected_causal_departure(request: Dictionary) -> Dictionary
func capture() -> Dictionary
func commit(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
func publish(publication: Dictionary) -> Dictionary
```

Plan 03 calls it with exactly:

```gdscript
{
	"command_id": String,
	"command_issuer_receipt": Dictionary,
	"run_id": String,
	"branch_id": String,
	"causal_day_instance": String,
	"reason": "schedule_done",
	"expected_board_identity": Dictionary | null,
	"expected_board_revision": int,
}
```

`prepare_causal_departure()` accepts only that exact `reason="schedule_done"` request and derives fate from the current canonical board. A condition-driven action MUST instead use the coordinator-only projected seam with exactly:

```gdscript
{
	"command_id": String,
	"command_issuer_receipt": Dictionary,
	"run_id": String,
	"branch_id": String,
	"causal_day_instance": String,
	"reason": "condition_departure",
	"expected_board_identity": Dictionary | null,
	"expected_board_revision": int,
	"source_action_receipt": Dictionary,
	"projected_board_candidate": Dictionary,
	"projected_board_candidate_sha256": String,
}
```

`DesktopConsequenceCoordinator` alone constructs this request from the already validated, still-uncommitted source action candidate while it holds `causal_transaction`; no public/UI caller can supply a projection. The port requires the action receipt's transaction/run/branch/day identity to match the request, canonical-hashes the detached projected candidate, and proves its pre-state identity/revision against the current board. A `minesweeper_round` source must carry the exact post-completion board candidate produced by the source participant: phase `NONE`, the terminal completion/result retained in the action candidate/receipt, and no playable board. A `shop_purchase` projection must initially be byte-equal to the current board. Missing, stale, caller-shaped, or action-mismatched projections reject before mutation. No other reason or projected source kind is legal.

Both methods return success value exactly `{"board_candidate":Dictionary,"board_fate_receipt":Dictionary}` and the outer receipt is an exact detached copy of `board_fate_receipt`:

```gdscript
{
	"receipt_id": String,
	"receipt_provenance": Dictionary,
	"command_id": String,
	"command_issuer_receipt": Dictionary,
	"board_identity": Dictionary | null,
	"board_revision": int, # -1 exactly when board_identity is null
	"causal_day_instance": String,
	"source_action_commit_receipt_id": String | null,
	"source_action_commit_receipt_provenance": Dictionary | null,
	"fate": "none" | "discarded_unstarted" | "forfeited_started",
}
```

For Schedule Done, both source-action members are null. For a projected condition departure, both are the exact nonnull commit ID/provenance from `source_action_receipt`. `PREPARING`/`PREPARED_UNSTARTED` yields `discarded_unstarted` with no cost/result/reward/forfeit. `ACTIVE_VISIBLE`/`ACTIVE_SUSPENDED` yields `forfeited_started`, retains paid round/motivation, and grants no result, money, coin, task, relationship/contact/group effect, unlock, or notification. `NONE` yields `none`. Critically, a terminal completion's validated projected candidate is already `NONE`, so its condition departure yields `none` and keeps the completed result/reward instead of forfeiting the pre-action ACTIVE board. Duplicate delivery returns the same candidate/receipt; changed identity/reason/action/projection conflicts. `SETTLING` rejects unless the matching journal transaction is being resumed.

The reversible participant operations are exact. `capture()` succeeds with `value={backup}` and `receipt={}`, where `backup` is a deeply detached exact `DesktopBoardState.capture()` value. `commit(candidate)` accepts the bare exact `board_candidate` previously returned by one prepare call—no wrapper or extra key—and revalidates its retained candidate hash, board-fate receipt, source ancestry, and current pre-state under `causal_transaction`. Success is exactly `value={board_candidate}` with outer receipt byte-equal to the matching `board_fate_receipt`. The port adopts that candidate once through the sole board owner; an already-equal committed state returns the original result, while the same receipt/candidate identity with changed bytes or a third live state returns `board_fate_conflict` without mutation.

`rollback(backup)` accepts only the exact detached backup returned by `capture()` for the same in-memory preparation and succeeds exactly as `value={restored:true},receipt={}` when no admission checkpoint has committed. An identical retry is a no-op success. It rejects an unknown/changed backup, any live third state, or an admitted transaction with `board_fate_rollback_forbidden`; forward recovery, never rollback, owns every admitted cut. `publish(publication)` accepts exactly `{board_candidate,board_fate_receipt}`, proves the current state equals the committed candidate and the receipt is the retained exact match, then emits the sole board-fate publication once. Success is exactly `value={published:true}` with outer receipt byte-equal to `board_fate_receipt`. An identical retry returns the original result without a second signal; changed candidate/receipt bytes return `board_fate_conflict`. Prepare and commit are silent. These laws apply equally to `fate=none`, discard, and forfeit, including after process restart from the persisted candidate/receipt.

**Frozen prepared-action interface:**

```gdscript
# DesktopConsequenceCoordinator.gd
func configure(state_port: Object, causal_sequence_port: Object,
		board_fate_port: Object, checkpoint_port: Object,
		mutation_gate: ApplicationMutationGate) -> Dictionary
func configure_action_source_ports(minesweeper_round_source_port: Object,
		shop_purchase_source_port: Object) -> Dictionary
func configure_condition_departure_ports(condition_policy_port: Object,
		schedule_view_port: Object) -> Dictionary
func accept_prepared_action(request: Dictionary) -> Dictionary
func resume_pending() -> Dictionary

# MinesweeperRoundCoordinator.gd addition
func configure_consequence_port(port: Object,
		mutation_gate: ApplicationMutationGate) -> Dictionary
func complete_round(request: Dictionary) -> Dictionary
func validate_recovery_action(action_candidate: Dictionary,
		action_receipt: Dictionary) -> Dictionary
func commit_recovery_action(action_candidate: Dictionary,
		action_receipt: Dictionary) -> Dictionary
func publish_recovery_action(publication: Dictionary) -> Dictionary

# MinesweeperShopPurchaseParticipant.gd additions; retains Task-7 ledger configuration
func validate_recovery_action(action_candidate: Dictionary,
		action_receipt: Dictionary) -> Dictionary
func commit_recovery_action(action_candidate: Dictionary,
		action_receipt: Dictionary) -> Dictionary
func publish_recovery_action(publication: Dictionary) -> Dictionary

# FakeDesktopConditionPolicyPort.gd -- exact Plan-03 production surface
func configure(context_port: Object) -> Dictionary
func evaluate(request: Dictionary) -> Dictionary

# FakeScheduleDepartureViewPort.gd -- exact action subset of Plan-03 production surface
func prepare_condition_departure(request: Dictionary) -> Dictionary
func commit_condition_departure(candidate: Dictionary) -> Dictionary
```

`configure_action_source_ports()` is mandatory before either condition/departure configure seam or `resume_pending()`. It retains exactly the existing production `MinesweeperRoundCoordinator` for `source_kind=minesweeper_round` and the existing production `MinesweeperShopPurchaseParticipant` for `source_kind=shop_purchase`. The first call validates all three recovery methods on both objects and succeeds exactly as `value={configured:true,already_configured:false},receipt={}`; identical same-role replay succeeds with `already_configured:true`; swapped roles, partial configuration, replacement, a missing capability, or an Object that claims both roles rejects before input. No service locator, source reconstruction, or fallback object is legal.

Both retained source objects implement the same exact restart surface. `validate_recovery_action(action_candidate,action_receipt)` is mutation-free, requires the candidate hash/receipt/source kind and canonical owner-specific semantics to match, and succeeds exactly as `value={publication},receipt={}`, where publication is exactly `{action_candidate_sha256:String,action_receipt:Dictionary}`. `commit_recovery_action(...)` accepts the same bare frozen pair, performs the source's sole live commit, and succeeds exactly as `value={action_receipt}` with outer receipt byte-equal to it. `publish_recovery_action(publication)` accepts only that exact two-key publication and succeeds exactly as `value={published:true}` with outer receipt byte-equal to its action receipt. Each method returns the original success on a byte-identical retry and `action_receipt_conflict` for the same action/transaction identity with changed candidate, hash, receipt, or source kind. Prepare/validate and commit are silent; publish is the source's sole audience boundary.

`accept_prepared_action()` and `resume_pending()` dispatch only by the validated frozen `pending_transaction.source_kind`; they never infer a source from candidate shape, current board, receipt naming, or whichever app is active. Before writing `action_prepared`, the coordinator calls the retained source's validator and freezes its returned exact publication into the action-source recipe. After admission it calls that same retained object to commit the persisted candidate/receipt at `action_committed`; at `publication_pending` it calls that object to publish the persisted recipe. On an empty-process restart, `resume_pending()` uses only restored source kind, action candidate/hash, action receipt, publication recipe, and the retained production object. It may not require the initiating scene/controller or any process-local prepared-candidate cache.

Plan 03 owns the production paths `scripts/application/desktop/DesktopConditionPolicyPort.gd` and `scripts/application/schedule/ScheduleDepartureViewPort.gd`; this plan MUST NOT create either production port or ScheduleView state. The Task-8 fakes match only their exact consumed APIs. Both production dependencies are configured together exactly once; missing either returns `condition_departure_ports_unconfigured` before policy evaluation, view preparation, admission, or any live mutation. `evaluate()` receives exactly `{action_receipt:Dictionary,causal_sequence_receipt:Dictionary}`. Success value is exactly `{condition_receipt:Dictionary,destination_intent:Dictionary|null,notification_intent:Dictionary|null}`, and the outer receipt is an exact detached copy of `condition_receipt`:

```gdscript
{
	"receipt_id": String,
	"receipt_provenance": Dictionary,
	"action_commit_receipt_id": String,
	"action_commit_receipt_provenance": Dictionary,
	"causal_sequence_receipt_id": String,
	"causal_sequence_receipt_provenance": Dictionary,
	"causal_sequence": int,
	"day": int,
	"causal_day_instance": String,
	"condition_after": Dictionary,
	"danger": bool,
	"trigger": bool,
	"decision": "no_departure" | "hospital_day" | "day7_sylvia_special" |
		"day7_hospital_alone" | "day7_dark_alone",
	"source_receipt_ids": Array[String],
	"sylvia_read_receipt_id": String | null,
}
```

Destination is null or exactly `{intent_id,intent_id_provenance,kind,day,causal_day_instance,source_condition_receipt_id,source_condition_receipt_provenance,accepted_unfulfilled_sources,terminal_cause,terminal_provenance,prerequisite_receipt_ids}`. `kind` is `hospital_day|day7_terminal`; Hospital has null cause/provenance, while the Day-7 cause is `sylvia_special|hospital_alone|dark_mode_alone` and terminal provenance is null at this condition-driven boundary. Notification is null or exactly `{intent_id,intent_id_provenance,action_kind,action_commit_receipt_id,action_commit_receipt_provenance,source_condition_receipt_id,source_condition_receipt_provenance}`, where action kind is `minesweeper_round|shop_purchase`. The fake uses explicit contract fixtures only; it never reads production GameState or proves those decisions. Plan 03's read-only context adapter and production port alone own the predicates and receipt ancestry.

Request is exactly:

```gdscript
{
	"action_receipt": Dictionary,
	"action_candidate": Dictionary,
	"prepared_checkpoint_receipt": Dictionary,
	"expected_run_revision": int,
	"expected_board_identity": Dictionary | null,
	"expected_board_revision": int,
}
```

`action_receipt` is the Task-7 exact schema with `action_kind=minesweeper_round|shop_purchase`; `action_candidate` is its still-uncommitted typed GameState/economy delta, and `prepared_checkpoint_receipt` proves stage `action_checkpointed`. Success outer value and receipt are frozen for Plan 03:

```gdscript
# value
{
	"causal_sequence": int,
	"condition_receipt": Dictionary,
	"board_fate_receipt": Dictionary | null,
	"schedule_view_commit_receipt": Dictionary | null,
	"destination_intent": Dictionary | null,
	"notification_intent": Dictionary | null,
}
# receipt
{
	"receipt_id": String,
	"receipt_provenance": Dictionary,
	"action_commit_receipt_id": String,
	"action_commit_receipt_provenance": Dictionary,
	"causal_sequence": int,
	"disposition": "no_departure" | "departure_committed",
}
```

`complete_round()` accepts exactly `{transaction_id,transaction_issuer_receipt,expected_identity,expected_revision,expected_run_revision}` and derives result/reward inputs from the terminal canonical board; callers cannot supply an outcome, reward, counter delta, effect, unlock, identity, nonce, or sequence. Before reading/preparing the terminal action it acquires `causal_transaction` from the same injected gate retained by `DesktopConsequenceCoordinator`, prepares and durably checkpoints the completion candidate without changing live reward/board truth, then delegates that candidate to `accept_prepared_action()` under the still-active lease. The Shop participant follows the same rule. The injected pure condition policy owns the exact Days 1–6/Day-7 destination law later, and the paired injected ScheduleView port alone owns the departure view before/after semantics. This plan supplies only their two contract fakes and uses issuer-anchored contract intent IDs. Production bootstrap in this plan leaves both condition-departure slots unconfigured/fail-closed, so `.9` cannot claim a real Hospital, Day-7 route, or ScheduleView mutation.

The coordinator does not own a counter. For action sources, it requires the source participant to have acquired the one `causal_transaction` lease before that source candidate was read/prepared; `accept_prepared_action()` verifies the exact same injected gate identity/active owner and retains the lease through publication or startup recovery. After validating the issuer-anchored action receipt/candidate and its ordinal-0 source checkpoint, it reads `last_causal_sequence` from the one consequence-state capture and calls the injected `DesktopCausalSequencePort.prepare_reservation()` with that exact expected value, `source_kind=minesweeper_round|shop_purchase`, the source commit receipt/provenance, and the caller's expected run revision. It prepares pure policy and, only for a departure, calls `prepare_projected_causal_departure()` with the exact post-action board projection before preparing the paired ScheduleView before/after dictionaries, consequence/outbox, and detached post-admission candidates against that proposed receipt while live truth remains byte-equal. A no-departure result has no board-fate candidate. It then atomically records ordinal-1 `action_prepared` with `payload_phase=admission_ready`; only that checkpoint/hash can be passed to `prepare_admission()`.

At final admission it repeats the shared last-sequence/run-revision CAS while still holding the gate and atomically promotes one checkpoint whose pending stage is `sequence_committed`. CAS loss abandons only the unpromoted prepared checkpoint and returns `causal_sequence_conflict`; it commits no reward, purchase, board fate, ScheduleView, sequence, or outbox. After promotion, recovery is forward-only in the frozen source-kind order: commit action candidate -> condition receipt -> board fate -> condition-departure ScheduleView (or validated no-op) -> consequence checkpoint -> publication. Each transition writes its exact receipt/stage before the next live step and an identical restart resumes without replay; the view port's byte-identical receipt closes the apply-before-checkpoint crash window. A no-departure result may enqueue one contract notification intent and never calls the view port. A fake-policy departure commits the fake view exactly once, enqueues one contract destination intent, suppresses notification, and exercises recovery without representing production view or destination law. An identical action-receipt duplicate returns the identical full result; the same action/transaction identity with changed bytes returns `action_receipt_conflict` before any port mutation.

Plan 03 MUST first configure this same `DesktopConsequenceCoordinator` object's condition policy and sole production `ScheduleDepartureViewPort` through `configure_condition_departure_ports()`, then extend that object with the public Schedule-departure composition. The identical ScheduleView port object is passed to `configure_schedule_departure_ports()`; replacement or a second view owner rejects. Plan 03 may not create `ScheduleDoneCoordinator`, another mutation gate, another checkpoint journal, or another sequence owner. Its Schedule command facade forwards only the raw issuer-authenticated expectation request frozen below; the coordinator itself prepares every participant under the lease and enters the frozen `schedule_done` stage graph. The same coordinator acquires `causal_transaction`, promotes `sequence_committed` before Schedule/board/day mutation, and owns forward recovery through departure publication.

The Plan-03 extension signatures are frozen here so recovery transport cannot drift:

```gdscript
func configure_schedule_departure_ports(schedule_port: Object,
		day_start_port: Object, schedule_view_port: Object,
		terminal_intent_port: Object, publication_port: Object) -> Dictionary
func request_schedule_departure(request: Dictionary) -> Dictionary
```

The public request is exactly `{command_id,command_issuer_receipt,request_fingerprint,expected_schedule_view_fingerprint,expected_last_sequence,expected_run_revision,expected_board_identity,expected_board_revision}`. It contains no Schedule candidate, receipt, route plan, payload, day-start candidate, intent, or publication. The coordinator ledger-verifies the full command receipt, requires `command_id == command_issuer_receipt.token`, recomputes the canonical fingerprint from the other seven exact fields, and rejects a caller-authored mismatch. `DesktopConsequenceCoordinator.request_schedule_departure()` is the first preparation boundary: it acquires `causal_transaction`, revalidates the unchanged ScheduleView through the injected view/Schedule ports, prepares Schedule, calls `prepare_reservation()` from that exact Schedule receipt without mutating sequence, then prepares board fate, day start, optional terminal intent, view-after, and publication candidates against the proposed causal receipt while holding the lease. It builds/hashes the exact recovery payload through `DesktopConsequenceState.prepare_schedule_recovery_transport()` and durably writes `prepared_checkpointed` with that same reservation candidate. A private coordinator admission step then binds/promotes the sequence CAS and resumes the frozen stages. The thin Plan-03 `ScheduleDoneCommandPort` may perform warning decisions, but after a no-warning/confirmed decision it only forwards this raw request; it never prepares a participant or payload outside the gate. Missing configuration returns `schedule_departure_ports_unconfigured` before gate acquisition or checkpoint intent.

- [ ] **Step 8.1: Add parse-only skeletons, then write RED fate tests**

Create every new Task-8 script/fake with its declared typed surface and deterministic `not_implemented` failures. Prove each preload with `DynamicScriptProbe` before behavior assertions; no missing interface or parser error counts as RED.

Test every phase, visible/suspended equivalence, exact retained costs, forbidden fabricated consequences, duplicate/conflict, stale board revision, the exact capture/commit/rollback/publish shapes, each failure, silent-commit versus sole-publication counts, and SETTLING resume. Configure the same desktop-ledger identity used by the other Plan-02 publishers; reject missing/replaced configuration. Reject a wrapped candidate, changed/unknown backup, third live state, rollback after admission, changed publication, and duplicate audience emission; prove `fate=none`, discard, and forfeit all retry byte-identically after a reconstructed port plus reconstructed participant is configured over restored board truth and the loaded ledger returns the retained record. Separately RED-test the projected seam: a validated terminal-completion projection yields `none` while retaining completion/result/reward truth; a Shop projection applies ordinary current-board fate; a stale pre-state, changed action receipt, changed projected bytes/hash, public caller attempt, or nonterminal minesweeper projection rejects without mutation.

- [ ] **Step 8.2: Write RED consequence-race tests**

Test terminal completion winning the shared-port CAS before Shop/contract-condition departure (completion stays complete), departure winning before a stale completion (started board is forfeited), and presentation/signal order having no effect. The completion test must prove the coordinator derives the projected request from the exact uncommitted source candidate, not the current ACTIVE board, and that the persisted board candidate/receipt ancestry remain byte-identical through recovery. Configure one exact desktop-publication-ledger object into causal/Round/Shop/board-fate, then configure the exact Round/Shop source pair; reject missing/swapped/replaced ledger or source roles and allow only identical replay. Prove each action source acquires the same gate before its first state read/prepare; both unpromoted checkpoints leave live truth byte-equal; crash at `action_checkpointed` and prove downstream pure preparation safely repeats, then crash at `action_prepared` and prove only frozen payload bytes resume. Reject admission from ordinal 0, overwrite of ordinal 0, a provisional/full presence mismatch, and every mutated stage/ordinal pair. Inject CAS loss and assert no participant committed; then crash-inject every action source-kind stage after admission and prove forward recovery yields exactly one purchase/reward/contract-intent/notification/fate and, for departure only, one ScheduleView commit. At `publication_pending`, crash before each callback, after its ledger record but before/after signal and before its progress checkpoint, after each progress checkpoint, and after the complete cursor but before cleanup; prove every participant publication/resume returns the original semantic receipt, emits no second signal, progress advances exactly one prefix, payload hash never changes, and cleanup cannot run early. For both source kinds, destroy all process-local objects, restore v4, reload the ledger, construct/configure fresh coordinator/source objects, and prove `resume_pending()` selects only the persisted `source_kind`, passes the frozen candidate/receipt to the retained matching source, and performs exactly one source commit/publication. Mutate source kind, candidate/hash, action receipt, source recipe/order, progress cursor/receipt, desktop-ledger record, admission receipt, checkpoint header/preimage, or retained role identity and require fail-closed recovery. Crash after view apply but before the `schedule_view_committed` checkpoint and prove retry returns the byte-identical view receipt without replay; mutate any before/after byte, hash, receipt ancestry, or live third-state view and require fail-closed recovery. Prove no-departure carries four null view payload members, records a null view receipt through its no-op stage, and never calls the fake port. Feed the exact synthetic `schedule_done` payload through the transport validator, mutate live Schedule/board/day/view fakes after persistence, and prove resume returns only the frozen candidate bytes to injected validators. Assert both action kinds call the same causal object identity and `causal_transaction` gate object identity, and that no coordinator member named `_causal_sequence`, `_next_sequence`, or equivalent duplicate sequence owner exists.

- [ ] **Step 8.3: Write RED current-live-state merge tests**

Start a board, then commit Contact, Schedule-draft, Shop, and Settings changes through fakes. Completion applies only typed board deltas to that current state and never restores a broad pre-board snapshot. Frozen topology/result inputs remain unchanged.

- [ ] **Step 8.4: Run RED**

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_consequence_red' -LogName 'p2r9-consequence-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_board_fate_port.gd,res://tests/unit/test_desktop_consequence_coordinator.gd,res://tests/unit/test_minesweeper_round_coordinator.gd,res://tests/unit/test_minesweeper_shop_purchase_participant.gd,res://tests/integration/test_desktop_completion_transaction.gd,res://tests/integration/test_shop_condition_contract_departure.gd','-gexit')
```

Expected: all fate/consequence scripts parse; assertions fail only on typed unimplemented behavior.

- [ ] **Step 8.5: Implement board fate as a reversible participant**

The prepared terminal action candidate includes its terminal receipt and exact post-action `NONE` board projection before any live board changes. Condition-departure fate is prepared from that projection, never from the still-live ACTIVE board. Implement the exact board-fate capture/commit/rollback/publish contract above with one retained candidate/receipt relation and idempotency ledger. If a durable transaction is interrupted, phase `SETTLING` and its exact stage restore; it cannot expose a playable terminal/forfeited board or downgrade a completed result into a forfeit.

- [ ] **Step 8.6: Implement completion and consequence recovery**

Extend `MinesweeperRoundCoordinator` with `complete_round(request)` only for a validated terminal board and the three exact recovery-source methods above; add the same three methods to the existing Shop participant. Configure those exact existing objects into `DesktopConsequenceCoordinator` before any condition port. Round completion builds the same exact `DesktopActionReceipt` with `action_kind=minesweeper_round`, checkpoints only the uncommitted typed source result at `action_checkpointed`, and hands candidate plus receipt to `accept_prepared_action()`. `DesktopConsequenceCoordinator` consumes Task 6's causal port and mutation gate unchanged, validates/freezes the exact action-source publication recipe, writes the complete `action_prepared` checkpoint, promotes `sequence_committed` before any live participant, then dispatches source commit/publication by persisted source kind while resuming forward through the condition-driven ScheduleView stage. It may persist a fake view transition and contract intent in tests but cannot install a production ScheduleView or destination adapter. View, notification, or destination-intent transport truth is never a UI-side signal guess.

- [ ] **Step 8.7: Run GREEN**

Run Step 8.4. Expected: exit 0.

- [ ] **Step 8.8: Proposed commit boundary**

Exact paths: the fourteen Task-8 files. Proposed subject:

```text
feat(desktop): compose board fate with committed action consequences
```

## Task 9: Wire one production graph and seal the Phase-2R handoff

**Requirements:** `req.minesweeper.phase_boundary`, `req.test.desktop_amendment_gate`, plus every requirement named by Tasks 1–8.

**Files:**

- Create: `data/schemas/desktop-contract.schema.json`
- Create: `data/schemas/minesweeper-contract.schema.json`
- Create generated: `evidence/phase_2r/contracts/desktop_contract.json`
- Create generated: `evidence/phase_2r/contracts/minesweeper_contract.json`
- Create: `tools/evidence/DesktopContractEvidence.gd`
- Create: `tools/evidence/MinesweeperContractEvidence.gd`
- Create: `tools/evidence/generate_desktop_amendment_evidence.gd`
- Create: `tests/unit/tooling/test_desktop_amendment_evidence.gd`
- Create: `tests/unit/test_desktop_accessibility_contract.gd`
- Create: `tests/integration/test_desktop_action_matrix.gd`
- Create: `tests/integration/test_desktop_bootstrap_wiring.gd`
- Create: `tests/integration/test_desktop_crash_recovery.gd`
- Create: `tests/integration/test_desktop_simulator_authority.gd`
- Modify: `autoload/ApplicationBootstrap.gd`
- Modify: `autoload/SaveManager.gd`
- Modify: `scripts/application/run/SaveManagerCheckpointPort.gd`
- Modify: `scripts/application/restore/RouteRestoreParticipant.gd`
- Modify: `tools/evidence/EvidenceValidator.gd`
- Modify: `tests/unit/test_application_bootstrap_profile_stage.gd`
- Modify: `tests/unit/tooling/test_evidence_contract.gd`

**Interfaces:**

```gdscript
# DesktopContractEvidence.gd
static func build(repository_root: String, subject_commit: String) -> Dictionary
static func validate(document: Dictionary, repository_root: String) -> Dictionary
static func write_canonical(path: String, document: Dictionary) -> Dictionary

# MinesweeperContractEvidence.gd
static func build(repository_root: String, subject_commit: String) -> Dictionary
static func validate(document: Dictionary, repository_root: String) -> Dictionary
static func write_canonical(path: String, document: Dictionary) -> Dictionary

# ApplicationBootstrap.gd retained identity probes used by evidence
func get_startup_state() -> Dictionary
func get_desktop_contract_state() -> Dictionary
```

`get_desktop_contract_state()` returns detached primitive IDs/hashes only: one issuer-root/issuer identity, the already configured Phase-2R `ContactCommandPort` consumer identity, one external continuation-journal identity, one desktop-publication-ledger identity, one existing mutation-gate identity, one host instance ID, one board-state instance ID, one consequence-state instance ID, one causal-sequence-port identity, each other configured consumer identity, restore/reconciliation order, snapshot/document schema versions, registry versions, `desktop_contract_ready`, and `destination_composition_ready`. At `.9` close, its closed verification subset has the exact fields `restore_order:Array[StringName]`, `restore_participant_instance_ids:Dictionary`, `schedule_port_instance_id:int`, `provenance_owner_instance_id:int`, `day_resolution_start_port_instance_id:int`, `desktop_publication_ledger_instance_id:int`, `causal_sequence_port_instance_id:int`, `admission_checkpoint_port_instance_id:int`, `board_fate_port_instance_id:int`, `minesweeper_round_source_port_instance_id:int`, `shop_purchase_source_port_instance_id:int`, `consequence_coordinator_instance_id:int`, and `snapshot_provider_instance_id:int`. `restore_order` is exactly `identity_allocation,run,desktop_consequence,desktop_board,profile,localization,audio,route,narrative`; the participant-ID Dictionary has exactly those nine keys and integer `get_instance_id()` values. Within that process, every ID is nonzero, each role equals the exact retained production object, all four Plan-02 publication consumers retain the exact one desktop-ledger identity, the Round source ID equals the already-retained `MinesweeperRoundCoordinator` identity, the Shop source ID equals the already-retained `MinesweeperShopPurchaseParticipant` identity, those two roles are distinct, all other required owner-role relations hold, and `snapshot_provider_instance_id == GameState.get_instance_id()`. It exposes no mutable owner or live Node/RefCounted reference. Contract readiness is true and destination-composition readiness is false by design. Task-9 live tests bind every subset key, role order, ledger/source role equality/distinctness, and same-boot equality/distinctness relation. Deterministic evidence records the field/role set, owner class/source/signature bindings, relation verdicts, and exact test-log hashes; it never serializes a numeric instance ID.

**Bootstrap ownership:** `ApplicationBootstrap` reuses the exact monotonic `DesktopIssuerRootStore` and `DesktopIdentityNonceIssuer` instances that Plan 01 Task 3 already constructed from the closed `.16` boundary for authenticated Contacts commands; it verifies their object identities and configuration before adding any desktop consumer and MUST NOT construct or load a second root/issuer. It also preserves within the same boot the exact `GameStateScheduleCommitPort`, `DayResolutionStartPort`, `GameStateDayResolutionPort`, `DayResolutionCoordinator`, configured `Day7ScheduleProvenance`, and Plan-01 Schedule-foundation publication ledger identities already constructed/retained by Plan 01 Task 6; it never reconstructs, replaces, or reconfigures them. Through the same retained root-scoped storage adapter it constructs/configures/loads exactly one distinct `DesktopPublicationLedger`, then constructs/configures exactly one `.16` `DesktopContinuationOperationJournal` plus one `DesktopAppHostState`, one `DesktopBoardState`, one `DesktopConsequenceState`, one `DesktopCausalSequencePort`, one `MinesweeperRoundCoordinator`, one `MinesweeperShopPurchaseParticipant`, one `DesktopBoardFatePort`, and one `DesktopConsequenceCoordinator`, while reusing the already-single `ApplicationMutationGate` and the existing `/root/GameState` as the exact raw snapshot-provider object. It injects the exact loaded desktop ledger into causal, Round, Shop, and board-fate objects before their ordinary configuration; it injects the exact retained Round and Shop objects into `configure_action_source_ports(round,shop)` before any condition/departure configuration and never constructs recovery-only substitutes. It injects the same host identity into the stable active-app provider and route restore participant; the same board into save capture/restore, board fate, and Minesweeper ports; the same consequence owner into save capture/restore, causal sequence, Shop pending-action, and consequence ports; the same gate into causal sequence, purchase, round completion, restore, and New Run; the same external journal into New Run/Load/startup recovery; and the same issuer into Contacts, Schedule foundation, New Run, Load allocation, board/spec, transaction, nonce, receipt, and child-provenance consumers. Replacement is rejected. Startup registers exact live restore order `identity_allocation -> run -> desktop_consequence -> desktop_board -> profile -> localization -> audio -> route -> narrative`, then reconciles the external operation journal through those configured participants before enabling any run mutation; it never connects a second day-change/sequence/issuer/gate/journal/publication-ledger owner or a UI scene as state authority.

Final startup order extends the existing sequence after narrative/ending and day-resolution foundations: open/create the monotonic issuer root and external journal -> configure/load the distinct desktop publication ledger through the same root-scoped storage adapter -> construct the issuer plus host/board/consequence owners and exact Round/Shop action sources -> inject that ledger into causal/Round/Shop/board-fate before ordinary configuration -> configure exact v4 capture, source loader, and all restore participants in the frozen order -> reacquire each journaled operation's `new_run|restore` lease and reconcile it -> configure generation, first-Reveal, board-fate, Shop-pending, and shared causal ports -> configure the consequence coordinator's exact Round/Shop recovery-source pair -> construct but leave both production condition-departure slots fail-closed -> under disabled input reconcile any committed first-Reveal checkpoint and call `DesktopConsequenceCoordinator.resume_pending()` for the restored v4 pending transaction -> configure Logout -> validate evidence-bound registries -> emit `application_ready`. Both publication ledgers load before any publish/recovery call. External continuation recovery finishes before run-local causal recovery, and both finish before readiness. An admitted action can therefore always reach its original retained source after an empty-process restart; missing source/ledger configuration is a startup fatal, not permission to skip `action_committed` or publication. Until Plan 03 injects its real condition policy and sole ScheduleView/route composition, a merely pre-admission `accept_prepared_action()` returns `condition_departure_ports_unconfigured` before causal admission, marks only the already-durable unpromoted source checkpoint abandoned through the injected checkpoint port, releases `causal_transaction`, and commits no live participant; it never creates or promotes a consequence checkpoint. Contract fakes are never bootstrap dependencies. Any earlier failure latches one startup fatal and leaves input disabled.

The evidence documents contain exact `subject_commit` and `subject_commit_subject`, requirement IDs, state phases, public signatures, commit-tree source SHA-256 hashes, manifest/schema/fixture hashes, exact RunSnapshot/SaveDocument v4 aggregate including the immutable admission/current receipt law and independent publication-progress prefix ledger, live restore order, external issuer-root/continuation-journal/desktop-publication-ledger contracts and distinct fixed paths, startup reconciliation order, three RNG stream contracts, causal-port shapes, both source-kind stage graphs and zero-based stage/progress/cleanup ordinal tables including action `action_prepared`/`schedule_view_committed`, the provisional-versus-admission payload law, non-self-referential publication-recipe schemas, exact callback receipt/deduplication/record-before-emit rules, the named checkpoint preimage/header/source-ID producer and cleanup receipt law, the complete Plan-02 production child-derivation table plus static call-site bindings, exact action-source recovery APIs/dispatch, the exact conditional view-payload/receipt law, `causal_transaction` gate-owner allowlist, CAS-before-live-mutation evidence, migration rejection code, removed board-lock proof, generator/kernel/verifier versions and budgets, the bootstrap probe field/role set plus stable class/source/signature and equality/distinctness attestations/test-log hashes, explicit `schedule_view_owner=dwm-oyo.3`, explicit `destination_composition_owner=dwm-oyo.3`, action-matrix records, and RED/GREEN command records. No numeric Object instance ID is emitted. `subject_commit` is the exact preceding Task-9 code commit with subject `feat(phase2r): seal desktop board and shop handoff contracts`; builders require it to be a 40-hex ancestor and hash bound paths from `git show <subject_commit>:<path>`, never from current HEAD or working-tree bytes. The schemas reject unknown keys. Fresh regeneration against the recorded subject commit must be byte-equal even after the evidence commit exists.

- [ ] **Step 9.1: Add parse-only skeletons, then write RED wiring and evidence tests**

Create every new Task-9 schema, tool, test, and generated-document container in a parse/schema-valid skeleton form. New evidence builders return typed `not_implemented` until GREEN. Prove all new scripts load through `DynamicScriptProbe`; a load/schema-parser failure is setup, never RED.

Assert one object identity per issuer/root/external-journal/desktop-publication-ledger/gate/host/board/consequence/causal owner within one running bootstrap, prove the retained Phase-2R `ContactCommandPort` and every new consumer share that exact issuer rather than reconfiguration/reconstruction, and prove all consumers retain their exact dependencies. Assert the exact final probe subset, including the three pre-existing Schedule foundation identities, desktop-ledger ID, both action-source IDs, exact ledger equality across causal/Round/Shop/board-fate, exact source equality to the Round/Shop production objects passed into `configure_action_source_ports()`, source mutual distinctness, ledger distinction from the Plan-01 ledger, and `snapshot_provider_instance_id == GameState.get_instance_id()` in that process; changing or reconstructing any pre-existing/source/ledger identity fails. Evidence captures only the stable relation verdicts and their source/test bindings, never the numeric IDs. Startup loads both ledgers before external operations/run-local recovery and before input; an empty-process restart at every admitted action stage reaches exactly the retained source-kind owner and completes source commit/publication once; apply-before-progress replay returns the original desktop-ledger record without a second signal. V4 provider bytes agree across narrative/day/board checkpoints; production first-Reveal checkpoints contain post-commit candidate truth; issuer root, continuation journal, and both publication ledgers are outside selectable snapshots; the SaveManager board lock is absent; and no UI script or scene is in the source-authority set. Instantiate the existing simulator adapter and prove bootstrap never registers its state, RNG, receipts, or callbacks as canonical authority. Mutate every bound source path/hash/signature/requirement ID/restore-order/stage-graph/gate-owner/action-source/ledger relation and prove evidence validation fails.

- [ ] **Step 9.2: Write RED accessibility contract tests**

Without editing UI, freeze the semantic obligations consumed by Phase 3: Debug exposes exactly one enabled forced-cell command and focus target in `PREPARED_UNSTARTED`; all other cells reject; Supportz registry exposes one neutral blank-card button name and no effect description; pointer/touch, Enter/Space, and standard gamepad confirm map to the same purchase command shape. These are domain/presentation-adapter contracts, not a claim that final UI exists.

- [ ] **Step 9.3: Run RED**

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_handoff_red' -LogName 'p2r9-handoff-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_desktop_amendment_evidence.gd,res://tests/unit/test_desktop_accessibility_contract.gd,res://tests/integration/test_desktop_action_matrix.gd,res://tests/integration/test_desktop_bootstrap_wiring.gd,res://tests/integration/test_desktop_crash_recovery.gd,res://tests/integration/test_desktop_simulator_authority.gd','-gexit')
```

Expected: all wiring/evidence scripts and schemas parse; behavioral/source-binding assertions fail only on typed unimplemented or empty generated evidence.

- [ ] **Step 9.4: Wire the production graph**

Retain existing stable narrative checkpoint adapter and provider Callables; preserve the exact retained Schedule commit, day-resolution start, state-port/coordinator, and Day-7 provenance identities from Plan 01 Task 6; assign the desktop host/board/consequence owners behind their owned seams without replacement. Configure SaveManager's identity-allocation, consequence, and board restore participants plus exact post-commit v4 capture, and bind the probe's raw `snapshot_provider_instance_id` to the retained `/root/GameState` object whose `capture_run_snapshot_input()` supplies that capture. Inject the one causal port into board completion and Shop consequence handoffs. Construct the consequence coordinator but leave its production condition-policy and ScheduleView dependencies explicitly unconfigured until Plan 03 configures both together. Emit the exact closed probe subset and prove every pre-existing Schedule identity is unchanged. Register no UI scene, ScheduleView owner, real destination adapter, or Schedule warning/Done coordinator; the player-facing simulator remains a non-authoritative adapter for `dwm-oyo.3` to replace.

- [ ] **Step 9.5: Commit the tested code subject, then generate evidence against it**

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_code_boundary' -LogName 'p2r9-code-boundary.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_accessibility_contract.gd,res://tests/integration/test_desktop_action_matrix.gd,res://tests/integration/test_desktop_bootstrap_wiring.gd,res://tests/integration/test_desktop_crash_recovery.gd,res://tests/integration/test_desktop_simulator_authority.gd','-gexit')
if ($LASTEXITCODE -ne 0) { throw 'Task-9 code boundary tests failed' }

# Under separate DWM_COMMIT_AUTHORIZED=1 authority, invoke the exact-path helper
# for the eighteen Task-9 paths other than the two generated evidence JSON files.
# The required subject is exact; no generated evidence path enters this commit.
$codeSubject = 'feat(phase2r): seal desktop board and shop handoff contracts'
$codeCommit = (git rev-parse HEAD).Trim()
if ((git log -1 --pretty=%s) -cne $codeSubject) { throw 'Task-9 code subject mismatch' }
if ($codeCommit -cnotmatch '^[0-9a-f]{40}$') { throw 'Task-9 code commit is not 40-hex' }

$subjectArg = "--subject-commit=$codeCommit"
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_evidence_generate' -LogName 'p2r9-evidence-generate.log' -GodotArgs @('-s','res://tools/evidence/generate_desktop_amendment_evidence.gd','--',$subjectArg,'--write')
if ($LASTEXITCODE -ne 0) { throw 'Task-9 evidence generation failed' }
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_evidence_check' -LogName 'p2r9-evidence-check.log' -GodotArgs @('-s','res://tools/evidence/generate_desktop_amendment_evidence.gd','--',$subjectArg,'--check')
if ($LASTEXITCODE -ne 0) { throw 'Task-9 evidence byte check failed' }
```

The code commit contains exactly the eighteen non-generated Task-9 paths and is allowed to precede its evidence by only this bounded generation/verification sequence. Generation reads every bound source from that named commit tree, not the dirty working tree. Expected: both commands exit 0 and exactly the two generated JSON files exist; check mode is byte-equal and non-writing.

- [ ] **Step 9.6: Run the focused amendment gate**

```powershell
$had_current_boundary = Test-Path Env:DWM_REQUIRE_CURRENT_P2R16_BOUNDARY
$previous_current_boundary = if ($had_current_boundary) { $env:DWM_REQUIRE_CURRENT_P2R16_BOUNDARY } else { $null }
try {
	$env:DWM_REQUIRE_CURRENT_P2R16_BOUNDARY = '1'
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_desktop_amendment_gate' -LogName 'p2r9-desktop-amendment-gate.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_contracts.gd,res://tests/unit/test_desktop_identity_nonce_issuer.gd,res://tests/unit/test_desktop_issuer_root_store.gd,res://tests/unit/test_causal_day_advance_identity_port.gd,res://tests/unit/test_desktop_continuation_operation_journal.gd,res://tests/unit/test_desktop_publication_ledger.gd,res://tests/unit/tooling/test_desktop_identity_issuer_boundary.gd,res://tests/unit/test_minesweeper_capabilities.gd,res://tests/unit/test_deterministic_rng32.gd,res://tests/unit/test_minesweeper_board_schema.gd,res://tests/unit/test_minesweeper_no_guess_verifier.gd,res://tests/unit/test_minesweeper_generator_kernel.gd,res://tests/unit/test_minesweeper_board_generator.gd,res://tests/unit/test_desktop_board_state.gd,res://tests/unit/test_minesweeper_round_coordinator.gd,res://tests/unit/test_desktop_consequence_state.gd,res://tests/unit/test_desktop_causal_sequence_port.gd,res://tests/unit/test_application_mutation_gate.gd,res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_document_schema.gd,res://tests/unit/test_save_migrations.gd,res://tests/unit/test_desktop_identity_allocation_restore_participant.gd,res://tests/unit/test_desktop_continuation_remapper.gd,res://tests/unit/test_desktop_first_reveal_snapshot_composer.gd,res://tests/unit/test_logout_coordinator.gd,res://tests/unit/test_desktop_action_receipt.gd,res://tests/unit/test_minesweeper_shop_purchase_participant.gd,res://tests/unit/test_desktop_board_fate_port.gd,res://tests/unit/test_desktop_consequence_coordinator.gd,res://tests/unit/test_desktop_accessibility_contract.gd,res://tests/unit/tooling/test_minesweeper_generator_artifacts.gd,res://tests/unit/tooling/test_desktop_amendment_evidence.gd,res://tests/integration/test_minesweeper_first_reveal_transaction.gd,res://tests/integration/test_desktop_board_persistence.gd,res://tests/integration/test_minesweeper_shop_transaction.gd,res://tests/integration/test_desktop_completion_transaction.gd,res://tests/integration/test_shop_condition_contract_departure.gd,res://tests/integration/test_desktop_action_matrix.gd,res://tests/integration/test_desktop_bootstrap_wiring.gd,res://tests/integration/test_desktop_crash_recovery.gd,res://tests/integration/test_desktop_simulator_authority.gd','-gexit')
	if ($LASTEXITCODE -ne 0) { throw 'desktop amendment focused gate failed' }
} finally {
	if ($had_current_boundary) { $env:DWM_REQUIRE_CURRENT_P2R16_BOUNDARY = $previous_current_boundary } else { Remove-Item Env:DWM_REQUIRE_CURRENT_P2R16_BOUNDARY -ErrorAction SilentlyContinue }
}
```

Expected: exit 0, zero pending in this closed subject set, production persistence paths reached 0.

- [ ] **Step 9.7: Run the full isolated suite and documentation gate**

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_full' -LogName 'p2r9-full.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gdir=res://tests','-ginclude_subdirs','-gexit')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_docs' -LogName 'p2r9-docs.log' -GodotArgs @('--headless','--script','res://tools/docs/validate_docs.gd','--','--check-links','--beads-json=res://.godot/beads/phase2r-all.json')
```

Expected: both exit 0; no project-owned orphan/unfreed/retained-resource diagnostics; no requirement or evidence drift.

- [ ] **Step 9.8: Fresh-regeneration and forbidden-surface audit**

```powershell
$desktop_evidence = Get-Content -Raw -LiteralPath 'evidence/phase_2r/contracts/desktop_contract.json' | ConvertFrom-Json
$minesweeper_evidence = Get-Content -Raw -LiteralPath 'evidence/phase_2r/contracts/minesweeper_contract.json' | ConvertFrom-Json
if ($desktop_evidence.subject_commit -cne $minesweeper_evidence.subject_commit) { throw 'evidence subject commit drift' }
$subjectCommit = [string]$desktop_evidence.subject_commit
if ($subjectCommit -cnotmatch '^[0-9a-f]{40}$') { throw 'invalid evidence subject commit' }
if ((git log -1 --format=%s $subjectCommit) -cne 'feat(phase2r): seal desktop board and shop handoff contracts') { throw 'evidence subject mismatch' }
$subjectArg = "--subject-commit=$subjectCommit"
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'p2r9_evidence_recheck' -LogName 'p2r9-evidence-recheck.log' -GodotArgs @('-s','res://tools/evidence/generate_desktop_amendment_evidence.gd','--',$subjectArg,'--check')
if ($LASTEXITCODE -ne 0) { throw 'fresh evidence regeneration check failed' }
rg -n "minesweeper_board|abort_round|clear_unfinished_minesweeper_round|get_minesweeper_safety_level" autoload scripts tests data evidence --glob '!docs/**'
rg -n "ScheduleViewState|ScheduleViewController|warning_state_fingerprint|request_schedule_done" scripts/application/desktop scripts/application/minesweeper scripts/application/shop tests/integration/test_desktop_* tests/unit/test_desktop_* --glob '*.gd'
if (Test-Path 'scripts/application/schedule/ScheduleDepartureViewPort.gd') { throw 'Plan 03 production ScheduleView port landed inside Plan 02' }
rg -n "Time\.|randi\(|RandomNumberGenerator|instance_id" autoload/GameState.gd scripts/ui/MenuScene.gd scripts/application/desktop scripts/application/minesweeper scripts/domain/desktop scripts/domain/minesweeper
rg -n "ComputerDesktop|MinesweeperApp|ShopApp" autoload/ApplicationBootstrap.gd autoload/SaveManager.gd scripts/application scripts/domain
git diff --check
git status --short
```

Expected: no lifetime-lock/legacy-abort/scalar-safety or canonical time/global-RNG identity path; no UI simulator registered from an authority path; no ScheduleView state/controller, warning/final-Done, production view port, or real destination implementation in this plan. The exact opaque `schedule_view_before|after` recovery members, stage, coordinator seam, and contract fake remain required. There are no whitespace errors and only declared task paths plus separately owned dirty files.

- [ ] **Step 9.9: Commit the immutable evidence boundary**

Under separate commit authority, commit exactly `evidence/phase_2r/contracts/desktop_contract.json` and `evidence/phase_2r/contracts/minesweeper_contract.json` as the direct child of the Task-9 code commit. Proposed subject:

```text
docs(phase2r): record desktop amendment evidence
```

After that evidence commit, repeat Step 9.8's `--check` call using the recorded `subject_commit`; it must remain byte-equal even though current HEAD is now the evidence commit. `.9` closure evidence records both SHAs. Any one-commit substitution, current-HEAD hashing, working-tree hashing, or regeneration that changes `subject_commit` is a hard failure.

## Beads-ready `dwm-p2r.9` scope/acceptance correction

This is the exact metadata correction the plan author applies to Beads under separate Beads-write authority; it does not add implementation authority or another file to this plan.

**Replacement scope:** After `dwm-p2r.16` and `dwm-p2r.13` close and their recorded boundary commits are integrated ancestors, deliver the reusable seven-app desktop host, canonical board/generation/verifier contracts, exact RunSnapshot/SaveDocument v4 persistence and restore, external continuation-operation recovery, Shop-capability transaction, Logout/forfeit, board-fate, shared causal-sequence admission, action-consequence transport, and one production bootstrap graph. Remove the simulator as a canonical state/RNG/receipt/callback authority while retaining the current player-facing simulator as a non-authoritative adapter for `dwm-oyo.3` to replace.

**Replacement acceptance criteria:**

- The closed `.16` issuer/DataCatalog boundary and closed `.13` Schedule-v3 boundary both pass their exact source-hash, log-hash, subject, and `git merge-base --is-ancestor` gates before `.9` work begins.
- One bootstrap graph owns the issuer/root, external continuation journal, mutation gate, host, board, consequence state, causal-sequence port, round coordinator, Shop participant, board-fate port, and action-consequence coordinator; the exact Round/Shop objects are the coordinator's retained restart sources and every consumer retains those same object identities.
- RunSnapshot/SaveDocument v4 is exactly `desktop={board,consequence}`, preserves the v3 `committed_schedule`, preserves one immutable admitted checkpoint receipt beside the rotating current-stage receipt, rejects pre-amendment desktop saves with the frozen migration code, and restores identity allocation, consequence, then board in the frozen forward order.
- New Run, selected Load, paid first Reveal, Shop purchase, and terminal-round action use the frozen durable checkpoints, full issuer receipts, source-kind stage graphs, one `causal_transaction` lease, and CAS-before-live-mutation laws; restart resumes the next missing stage exactly once.
- Lucky, Debug, and Supportz obey the exact registry, quote, price, eligibility, cap, hidden-extra, forced-cell, and certified-generation contracts, with byte-identical generated evidence and a green focused/full/docs gate.
- Production bootstrap leaves the paired condition-policy/ScheduleView and destination composition slots explicitly unconfigured and fail-closed. Only fake ports exercise Hospital/Day-7-shaped intent plus opaque view transport in contract tests; `.9` does **not** claim production ScheduleView mutation, Hospital, Days-1–6, or Day-7 destination routes, final Schedule-Done composition, or ending-plan ownership.
- The current player-facing simulator may remain present, but bootstrap never registers its state, RNG, receipts, or callbacks as canonical authority. Removing or replacing that adapter and delivering the player-facing desktop belong to `dwm-oyo.3`.

**Dependency/follow-on metadata:** `.9` depends on closed `dwm-p2r.16` and closed/integrated `dwm-p2r.13`. `dwm-oyo.3` consumes the closed `.9` handoff for real destination composition and player-facing simulator replacement; no reverse dependency is introduced.

## Final `dwm-p2r.9` Acceptance Gate

- [ ] Every requirement named by this plan has implementation and fresh verification evidence in Beads metadata; `req.test.desktop_amendment_gate` names the subject commit and immutable logs.
- [ ] The live `.9` Beads wording has been separately corrected so `.9` owns reusable board/consequence/causal contracts and simulator-authority removal, while `dwm-oyo.3` owns real destination composition and player-facing simulator replacement.
- [ ] The `.16` v1 boundary binds the issuer, root store, shared `CausalDayAdvanceIdentityPort`, both disjoint allocation maps, and all three exact public surfaces; it has passed its last current-working-tree byte check immediately before `.9` closure, remains immutable afterward, and later consumers check its named commit-tree bytes plus ancestry instead of pinning evolved current files.
- [ ] The seven-app registry is exact; host navigation suspends/resumes instead of blocking or aborting.
- [ ] All six board phases, legal edges, illegal edges, duplicate/revision behavior, and exact save/restore paths are covered.
- [ ] First Reveal is the only desktop cost boundary and is exactly once under every injected failure; its disk checkpoint already contains the exact post-commit paid GameState, revealed board, and same-revision consequence candidates before live adoption.
- [ ] Lucky/Debug compose, hidden extras use floor law, forced cell never changes, no-guess proof admits only the four approved deduction rules, and one shared pure kernel builds fallbacks/benchmarks before the frozen budget is consumed by the bounded runtime adapter; both exact `--check=<path>` modes are non-writing and byte-equal.
- [ ] Placement, Debug forced-cell/search, and explosion RNG IDs/nonces/states are pairwise distinct, deterministic, and isolated from identity, pair, presentation, and unrelated draws.
- [ ] Manual Save, quick Save, switching, and Logout preserve the exact latest stable candidate/board; no lifetime board lock remains.
- [ ] RunSnapshot/SaveDocument v4 is exactly `desktop={board,consequence}` with a lifecycle current causal-day token/full issuer-receipt pair, valid empty consequence defaults, durable run revision, shared sequence, source-kind pending recovery, independent callback-prefix `publication_progress`, immutable `admission_checkpoint_receipt`, rotating stage/progress `checkpoint_receipt`, non-circular complete-candidate checkpoint preimages, journal-only `terminal_cleanup` receipts beside pending-null candidates, action receipts, and destination/notification outboxes.
- [ ] An outbox `published` bit means durable downstream acceptance only. The sole pending-null `prepare_outbox_publication()` transition validates the closed notification-intent or same-root condition-Hospital-resolution acceptance variant, changes only one false-to-true bit through ordinary capture/commit plus Plan 03's ack checkpoint, and adds no callback/stage ordinal or unregistered child kind.
- [ ] The issuer namespace/counter, transaction-keyed allocation receipts, resolution-keyed `day_advance_allocation_receipts`, and continuation operation journal live only in their append-only external stores outside selectable snapshots. New Run and Load persist intent before allocation and allocation before live apply; later day advance atomically persists target receipt/key/counter before lifecycle checkpoint; startup revalidates the exact request/source receipts, duplicate retry reuses its allocation, raw causal-day issue rejects, and rollback never decrements it.
- [ ] Restore forward order begins `identity_allocation -> run -> desktop_consequence -> desktop_board`; ordinary participants roll back in reverse while the allocation finalizes retained/burned. Load remaps only the v4 allowlist and never rerolls or imports abandoned-future truth.
- [ ] Lucky, Debug, and Supportz purchases are quote-checked, exactly once, capped, prospective, checkpointed without live mutation, admitted by causal CAS, and durable through forward condition recovery.
- [ ] `DesktopBoardFatePort` exactly matches the Plan-03 consumer seam, including bare-candidate capture/commit/rollback/publish shapes and restart-safe idempotence, and has no Schedule composition of its own.
- [ ] `DesktopCausalSequencePort` exactly matches the Plan-03 request/value/receipt/capture/commit/rollback/publish contract; round completion, Shop consequence, and later Schedule Done share its one CAS owner and one `causal_transaction` mutation-gate lease.
- [ ] `DesktopConsequenceCoordinator.accept_prepared_action()` exactly matches the Plan-03 action/result contract, uses the injected gate/causal port rather than private owners, admits sequence before action mutation, and is fail-closed unless Plan 03 has configured both its production condition policy and sole ScheduleView port.
- [ ] `DesktopConsequenceCoordinator` retains the exact production Round/Shop source pair before condition configuration; every admitted restart dispatches the frozen candidate/receipt/publication recipe by persisted `source_kind` and completes the original source exactly once without a scene or process-local cache.
- [ ] Action recovery persists source-only `action_checkpointed` and complete `action_prepared` as distinct immutable pre-admission checkpoints; only the latter can enter CAS, and both source-kind stage-to-receipt ordinal tables match the frozen zero-based values.
- [ ] Every action/Schedule `publication_plan` is the frozen ordered `Array[Dictionary]` recipe union, contains no admission/current checkpoint receipt or self-hash, and materializes the causal publication only from the immutable pending admission receipt at `publication_pending`.
- [ ] The distinct root-scoped desktop publication ledger has the exact three-kind record union, is loaded before recovery, is shared by causal/Round/Shop/board-fate only, and makes every apply-before-progress retry return the original semantic success without a second signal; Schedule/day-start remain on Plan 01's distinct ledger and resolution resume remains on the persisted plan cursor.
- [ ] Condition-driven action recovery crosses `schedule_view_committed` after board fate and before consequence checkpointing; departure freezes and idempotently commits exact before/after view bytes through Plan 03's sole production view port, while no-departure carries null view pairs and never calls that port.
- [ ] V4 preserves v3 `committed_schedule`; it has no canonical top-level ScheduleView or warning state. A pending action may contain only the frozen opaque `schedule_view_before`/`schedule_view_after` recovery pairs governed above, never a second live view owner.
- [ ] `ComputerDesktop`, Minesweeper, Shop, Schedule, art, audio, and narrative presentation files are untouched and remain non-authoritative. `MenuScene.gd` changes only to remove canonical time/`randi()` New-Run IDs; `dwm-oyo.3` still owns player-facing simulator replacement.
- [ ] Evidence regenerates byte-identically and the full isolated suite, docs gate, public-surface gate, and source-binding mutations all pass.

Only after every box is supported by fresh evidence and the separately owned Beads acceptance wording matches this boundary may `dwm-p2r.9` close. Closing `.9` proves reusable contracts and removal of simulator authority; it does not claim real Hospital/Day-7 destination composition, player-facing simulator replacement, Plan 03 composition, Plan 04 closeout, UI work, or any commit/push not separately approved.
