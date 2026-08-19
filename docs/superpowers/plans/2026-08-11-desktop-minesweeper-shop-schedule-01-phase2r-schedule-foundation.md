# Phase-2R Registry-Backed Schedule Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Use `superpowers:test-driven-development` for every behavior change and `superpowers:verification-before-completion` before each commit or Beads closure. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the provisional Schedule transport with one immutable action registry, exact invitation-source receipts, a strict committed-Schedule schema, one reversible GameState commit port, real ordered end-of-day resolution input, and receipt-driven Hospital/Dating presentation adapters for that committed-Schedule flow.

**Architecture:** `ScheduleActionRegistry` owns immutable action facts; `ScheduleRules` is a pure validator and route projector; `ContactInvitationState` owns exact date-source ancestry; and `GameStateScheduleCommitPort` prepares one detached, motivation-charging candidate without mutating live state. Run snapshots v3 persist only the canonical top-level `committed_schedule`; a separate root-scoped append-only publication ledger makes Schedule/day-start observations at-most-once across restart without becoming selectable run state. `DayResolutionCoordinator` freezes that exact committed order and delegates resumable stages to existing domain owners. Hospital and Dating nodes become presentation adapters around application ports and never mutate the run directly.

**Tech Stack:** Godot 4.6.3, GDScript, GUT, strict/canonical JSON, JSON Schema, SHA-256, the existing `CommandResult`, `StrictJson`, `CanonicalJsonWriter`, `ApplicationMutationGate`, SaveManager journals/restore participants, Beads, and the GUID-isolated PowerShell test wrapper.

**Plan status:** `approved`

**Owning Beads execution chain:** `dwm-p2r.12 -> dwm-wks -> dwm-p2r.16 -> dwm-p2r.13 -> dwm-p2r.9 -> dwm-p2r.14 -> dwm-p2r.15 -> dwm-p2r.7`. This plan owns `.12`, `wks`, `.13`, `.14`, `.15`, and `.7`; Plan 02 owns the interleaved `.16` and `.9` boundaries.

**Implementation authorization:** `false`. This document is an executable procedure only after `dwm-0hi` closes, the roadmap and all child plans are hash-bound, the first Beads issue is ready, and the user separately grants runtime implementation authority.

## Global constraints

- The accepted authority is `docs/design/2026-08-11-desktop-minesweeper-shop-schedule-amendment.md`; approved executable law is in `prompt_docs/requirements/schedule.md`, `runtime_ownership.md`, `persistence.md`, `run_lifecycle.md`, `dating_endings.md`, `contacts_invitations.md`, and `verification.md`, plus `prompt_docs/decisions/schedule_commit_model.md`. Stop on conflict; do not preserve obsolete behavior merely because it exists.
- This plan owns every `req.schedule.*` foundation needed by `.7`, while `dwm-oyo.3` alone owns `req.schedule.warning_queue`, `req.schedule.done_board_fate`, the saved `ScheduleView`, warning presentation, and final cross-owner Done composition. This plan produces the Schedule participant that `.3` consumes; it does not build the final Done UI.
- This plan implements `req.runtime.schedule_ownership`, `req.save.schedule_state` only for canonical `committed_schedule`, `req.save.schedule_migration` for the v2 -> v3 canonical boundary, every `req.run.*` prerequisite touched by actual committed order, the Schedule-Done/end-of-day branch of `req.flow.hospital_order`, and `req.test.schedule_foundation_gate`. It never claims the distinct pre-Done condition-Hospital branch or the post-composition `req.test.schedule_gate`.
- Do not merge or cherry-pick `feat/p2r7-strict-schedule-validation`. Its merge base is `49947e5`, its quarantined tip is `5e9ab64`, and it is evidence only. Reimplement accepted invariants selectively against the new schemas.
- Do not edit historical July/August plans, rewrite historical commits, or import that branch's Plan-04 edits. Do not modify the accepted amendment or requirement frontmatter in this execution plan.
- Every public command returns the master union. Success is exactly `{ok, code, value, receipt}`; failure is exactly `{ok, code, message, details}`. Predicates may be private; no public boolean/bare-shape compatibility command remains.
- Every dictionary is exact-key, detached primitive JSON. Reject extra keys, integral floats where an `int` is required, blank IDs, unsorted or duplicate identity arrays where order is not semantic, caller-supplied registry facts, and unknown enum members. A failure returns no candidate or receipt and changes no owner.
- Draft add/remove/move reserves and spends no motivation. A successful Schedule commit charges exactly one motivation for every entry, including dates, and charges zero for empty Done. Failure and conflicting duplicate delivery preserve motivation and canonical state byte-for-byte.
- Days 1–6 accept zero through seven entries at unique `slot_index` values in `0..6`, with at most two `solo|group` dates. Empty slots are legal; canonical execution sorts occupied slots ascending. Day 7 accepts zero entries or exactly one eligible `solo` at slot zero. There is no Day-4 Priscilla placement rule.
- Training, Working, and Rest may repeat through distinct `draft_entry_id` values. Date actions are non-repeatable. The P–L group is the exact ordered pair `["priscilla","lavinia"]`, supersedes both corresponding solo offers, and cannot coexist with either same-window solo.
- Route, effects, motivation cost, allowed day/window, kind, participants, repeatability, and source-receipt class come only from the exact registry fingerprint. Drafts, saves, scenes, action-ID parsing, and naming conventions cannot supply or override them.
- Tasks 1–2 first land the pure Schedule rules and immutable Schedule registry through `dwm-wks`. Plan 02 Task 1 / `dwm-p2r.16` then consumes that registry, lands the production `DesktopIdentityNonceIssuer` and external root store, and becomes the sole DataCatalog integration boundary. Tasks 3–6 MUST stop unless `.16` is closed, its recorded boundary is an ancestor, and its issuer/DataCatalog evidence is green. After `.13` closes, Tasks 7–9 additionally wait for the integrated closed `.9` desktop/board-fate boundary selected by the roadmap.
- Root command and resolution tokens come only from `DesktopIdentityNonceIssuer.issue(&"transaction_id")`. Plan 01 uses only the issuer's closed child kinds `contact_source`, `schedule_entry`, `schedule_commit`, `empty_schedule_done`, `day7_schedule_provenance`, `hospital_resolution`, `hospital_miss`, `sylvia_hospital_witness`, and `day_resolution_stage`. Every production child consumes exactly one stable row of the canonical Plan-01 child-derivation matrix below, is anchored to that row's ledger-verified root, and persists full provenance. Standalone hashes, local ordinal/source rules, unregistered child-kind strings, and caller-authored fallback IDs are forbidden.
- A logical-day change never calls raw `issue(&"causal_day_instance")`. Plan 02 Task 1 owns the single root-atomic `CausalDayAdvanceIdentityPort`; Task 7 configures one retained instance from the already-retained issuer and uses it inside Schedule-Done `increment_day`. Plan 03 later consumes that same object for condition-Hospital advancement. Neither mode may wrap it, allocate in a selectable snapshot, or adopt a target identity before the keyed root allocation is durable.
- Day-7 normal provenance is exact `eligible offer -> read/acceptance source receipt -> Schedule commit receipt -> typed terminal-provenance handoff`; `dwm-oyo.6` alone extends that chain into a final ending plan. `date_completed`, a planned bar state, a desktop/dating board, or a caller-authored friend ID is not proof. Empty committed Done carries the `empty_done` cause without selecting Alone inside this plan.
- Sylvia Special remains separate from Schedule Done under the approved final law, but Plan 01 does not evaluate its faint/Dark-mode precedence or construct Special -> Dark. It preserves the exact invitation-source seam; `dwm-oyo.3` owns the terminal intent and `dwm-oyo.6` owns the final ordered plan. Hospital-skip counters are neither provenance nor a Plan-01 trigger.
- On the Schedule-Done/end-of-day branch only, Days 1–6 execute committed ordinary action effects first, then resolve condition truth, then Hospital if required, then any surviving dates, then deferred P–L presentation. That branch's Hospital supersedes every affected committed date before any dating board and records each committed-date hospital miss once.
- The separate Days 1–6 condition check immediately after a committed desktop Minesweeper round or Shop purchase may depart before Done. Plan 03 owns that condition-Hospital resolution from issuer-validated accepted/read, unfulfilled invitation sources. It MUST NOT call `GameStateScheduleCommitPort`, synthesize an empty Done, call `DayResolutionStartPort.prepare_from_committed_schedule()`, construct a `DayResolutionPlan`, or derive any `P01.*` Hospital/presentation row. This plan's Schedule-Done receipts, stages, ports, and presentation requests are not a compatibility route for that flow.
- Hospital and Dating scenes accept presentation commands and return physical completion receipts. They do not apply effects, choose relationship outcomes, close invitations, advance the day, select endings, clear schedules, or directly mutate `GameState`.
- Use a clean isolated worktree. Never stage unrelated work. `.gd.uid` files are optional-present companions; never fabricate UID bytes. Each commit boundary below still requires the repository's explicit commit authorization.
- Every behavioral step is RED -> inspect the intended assertion -> minimal GREEN -> focused regression -> fresh-context review -> exact-path commit. Parse errors, missing fixtures, unrelated failures, tests that were already green, unconditional passes, and production `user://` access are invalid evidence.

## Beads and commit protocol

At every issue transition:

1. Run `bd prime`, `bd show dwm-p2r.9 dwm-p2r.12 dwm-wks dwm-p2r.16 dwm-p2r.13 dwm-p2r.14 dwm-p2r.15 dwm-p2r.7 --json`, `bd dep tree dwm-p2r.7 --json`, `bd ready --json`, and `bd blocked --json` read-only. Select `.12`, then `wks`. After `wks` closes, stop Plan 01 until Plan-02 Task 1 closes `.16` and integrates its issuer/DataCatalog boundary; then execute `.13` through its recorded v3 boundary. Stop again while the active selector executes and closes `.9`; only afterward resume `.14`, `.15`, and `.7`. If live dependency state disagrees, stop for plan-author review.
2. Claim exactly one ready issue. Never claim a successor early and never change dependency order from this plan without plan-author review.
3. Record the clean base commit, branch/worktree path, Godot version, focused baseline, and log path in the active issue.
4. After GREEN and review, use `tools/git/Invoke-ExactPathCommit.ps1` with the task's explicit allowlist only when `DWM_COMMIT_AUTHORIZED=1` is separately present.
5. Attach the real commit ID and fresh command/count evidence, then close only that task's stated issue. Query readiness again before claiming the successor.

`dwm-p2r.7` closes last. Closing `.12`, `wks`, `.13`, `.14`, or `.15` never implies `.7` is complete.

## Frozen data contracts

### Consumed production identity issuer

Plan 02 Task 1 / `dwm-p2r.16` creates `scripts/application/desktop/DesktopIdentityNonceIssuer.gd` and its external `DesktopIssuerRootStore`. Plan 01 MUST consume that exact injected instance; it creates no wrapper issuer, counter, fallback, or parallel ledger. The consumed API is:

```gdscript
func issue(purpose: StringName) -> Dictionary
func verify_issued(receipt: Dictionary, expected_purpose: StringName) -> Dictionary
func derive_child(request: Dictionary) -> Dictionary
func validate_child(provenance: Dictionary, expected_kind: StringName) -> Dictionary
```

`issue(&"transaction_id")` succeeds with exact `value={token:String,issuer_receipt:Dictionary}` and an outer receipt byte-equal to `issuer_receipt`. That exact root receipt is `{receipt_id:String,purpose:"transaction_id",namespace:String,counter:int,token:String,numeric_value:null}`. Every initiating request persists the full receipt beside its semantic token; ID-only validation is forbidden.

`derive_child()` accepts exactly `{parent_receipt_id:String,child_kind:StringName,ordinal:int,source_ids:Array[String]}` after the issuer has ledger-resolved the parent root receipt. Its success is `value={child_id:String,provenance:Dictionary}` with an outer receipt byte-equal to provenance. Provenance is exactly `{schema_version:1,parent_receipt_id:String,child_kind:String,ordinal:int,source_ids:Array[String],child_id:String}`. Source IDs are sorted, unique, and nonblank; ordinal is nonnegative; the child kind is closed. `validate_child()` ledger-verifies the parent and recomputes every byte. All Plan-01 persisted `*_provenance` values use this shape.

<!-- PLAN01_CHILD_DERIVATION_MATRIX_V1_BEGIN -->
#### Canonical Plan-01 child-derivation matrix

This matrix is the sole Plan-01 authority for every production `derive_child()` request. A producer MUST select exactly one row, construct exactly that row's request, and persist the returned provenance; it may not locally add, omit, rename, sort, hash, or reinterpret a source field. All parents below are the named full issuer receipt after `verify_issued(...,&"transaction_id")` succeeds and the semantic token equals that receipt's `token`.

The projection notation is exact:

- `J(value)` is `CanonicalJsonWriter.stringify(value)` over a detached, strict primitive-JSON value. `StringName` is converted to `String` first. Array order remains the authority-owned semantic order; `null` remains JSON `null`.
- `H(value)` is lowercase SHA-256 of the UTF-8 bytes of `J(value)`, with no BOM or trailing newline.
- `P(path,value)` is the nonblank String `path + "=" + J(value)`. Every `path` named in one row is unique.
- `S(...)` is exactly the listed `P(...)` tokens sorted into strict ascending non-locale `String` order (`a < b`). The producer passes those already-sorted bytes to the issuer. A duplicate, missing, extra, blank, or differently ordered token is invalid; the issuer never repairs it.
- `L(id...)` is an Array containing exactly the named already-nonblank ID Strings, unique and sorted by the same strict non-locale order. `L()` is `[]`. `P()` then serializes that Array as one source token; `L()` never wraps its members in `P()`.
- The ID/provenance being derived never appears in its own projection. An array named `*_receipt_ids` is already validated, nonblank, unique, and in the semantic order named by its row before `P()` serializes it. A `*_sha256` projection uses `H()` over the exact preimage named by the path, never over a caller-selected substitute.

| Stable row ID / production child | Exact verified parent `receipt_id` | Exact `child_kind` | Exact zero-based `ordinal` law | Exact `source_ids` before `S(...)` |
|---|---|---|---|---|
| `P01.contact_source.solo` / accepted solo read | `command_issuer_receipt.receipt_id` | `contact_source` | `0` (one source child for the command root) | `P("role","contact_source.solo")`, `P("command_id",command_id)`, `P("kind","solo_read_acceptance")`, `P("action_id",action_id)`, `P("day",day)`, `P("participants",participants)`, `P("previous_receipt_id",previous_receipt_id)` |
| `P01.contact_source.group` / accepted canonical-pair reply | `command_issuer_receipt.receipt_id` | `contact_source` | `0` (one source child for the command root) | `P("role","contact_source.group")`, `P("command_id",command_id)`, `P("kind","group_reply_acceptance")`, `P("action_id",action_id)`, `P("day",day)`, `P("participants",participants)`, `P("previous_receipt_id",previous_receipt_id)` |
| `P01.schedule.entry` / committed Schedule entry | `transaction_issuer_receipt.receipt_id` | `schedule_entry` | Index in `draft_entries` after the validated entries are sorted by `slot_index` ascending; first entry is `0` | `P("role","schedule.entry")`, `P("transaction_id",transaction_id)`, `P("view_fingerprint",expected_view_fingerprint)`, `P("causal_day_instance",causal_day_instance)`, `P("registry_fingerprint",registry_fingerprint)`, `P("draft_entry_id",entry.draft_entry_id)`, `P("day",entry.day)`, `P("slot_index",entry.slot_index)`, `P("action_id",entry.action_id)`, `P("action_kind",entry.action_kind)`, `P("participants",entry.participants)`, `P("source_receipt_id",entry.source_receipt_id)` |
| `P01.schedule.commit` / nonempty aggregate receipt | `transaction_issuer_receipt.receipt_id` | `schedule_commit` | `0` (one aggregate child after all entry children) | `P("role","schedule.commit")`, `P("transaction_id",transaction_id)`, `P("view_fingerprint",expected_view_fingerprint)`, `P("day",day)`, `P("causal_day_instance",causal_day_instance)`, `P("registry_fingerprint",registry_fingerprint)`, `P("draft_entries_sha256",H(validated_slot_order_draft_entries))`, `P("schedule_entry_ids",schedule_entry_ids)`, `P("source_receipt_ids",source_receipt_ids)`, `P("motivation_charged",motivation_charged)` |
| `P01.schedule.empty_done` / receipt-backed empty aggregate | `transaction_issuer_receipt.receipt_id` | `empty_schedule_done` | `0` (one aggregate child; no entry child exists) | `P("role","schedule.empty_done")`, `P("transaction_id",transaction_id)`, `P("view_fingerprint",expected_view_fingerprint)`, `P("day",day)`, `P("causal_day_instance",causal_day_instance)`, `P("registry_fingerprint",registry_fingerprint)`, `P("draft_entries_sha256",H([]))`, `P("schedule_entry_ids",[])`, `P("source_receipt_ids",[])`, `P("motivation_charged",0)` |
| `P01.schedule.day7_provenance` / Day-7 handoff | The Schedule commit's `transaction_issuer_receipt.receipt_id` | `day7_schedule_provenance` | `0` (one handoff child for the commit root) | `P("role","schedule.day7_provenance")`, `P("transaction_id",transaction_id)`, `P("causal_day_instance",causal_day_instance)`, `P("day",7)`, `P("cause",cause)`, `P("registry_fingerprint",registry_fingerprint)`, `P("schedule_commit_receipt_id",schedule_commit_receipt_id)`, `P("schedule_entry_id",schedule_entry_id)`, `P("action_id",action_id)`, `P("source_receipt_id",source_receipt_id)` |
| `P01.day_resolution.start` / reversible start receipt | `resolution_issuer_receipt.receipt_id` | `day_resolution_stage` | `0` (reserved start ordinal for the resolution root) | `P("role","day_resolution.start")`, `P("resolution_id",resolution_id)`, `P("causal_day_instance",causal_day_instance)`, `P("source_day",committed_schedule.day)`, `P("registry_fingerprint",committed_schedule.registry_fingerprint)`, `P("schedule_commit_receipt_id",committed_schedule.commit_receipt.receipt_id)`, `P("board_fate_receipt_id",board_fate_receipt.receipt_id)`, `P("schedule_entry_ids",committed_schedule.commit_receipt.schedule_entry_ids)`, `P("committed_schedule_sha256",H(committed_schedule))`, `P("route_plan_sha256",H(route_plan))`, `P("board_fate_receipt_sha256",H(board_fate_receipt))` |
| `P01.day_resolution.stage` / one top-level stage or entry substage | `resolution_issuer_receipt.receipt_id` | `day_resolution_stage` | Top-level: zero-based index in the exact D1-6 or D7 stage array. Entry substage: zero-based index in that stage's canonical filtered committed-`slot_index` order | `P("role",role)`, `P("resolution_id",resolution_id)`, `P("causal_day_instance",causal_day_instance)`, `P("source_day",source_day)`, `P("day_resolution_start_receipt_id",day_resolution_start_receipt_id)`, `P("stage_name",stage_name)`, `P("stage_index",stage_index)`, `P("substage_kind",substage_kind)`, `P("substage_index",substage_index)`, `P("schedule_entry_id",schedule_entry_id)`, `P("input_receipt_ids",input_receipt_ids)` |
| `P01.hospital.resolution` / Hospital aggregate outcome | `resolution_issuer_receipt.receipt_id` | `hospital_resolution` | `0` (at most one Hospital aggregate for the resolution root) | `P("role","hospital.resolution")`, `P("resolution_id",resolution_id)`, `P("causal_day_instance",causal_day_instance)`, `P("source_day",source_day)`, `P("day_resolution_start_receipt_id",day_resolution_start_receipt_id)`, `P("schedule_commit_receipt_id",schedule_commit_receipt_id)`, `P("condition_receipt_id",condition_receipt_id)`, `P("date_schedule_entry_ids",date_schedule_entry_ids)`, `P("required",required)` |
| `P01.hospital.miss` / one Hospital-superseded date | `resolution_issuer_receipt.receipt_id` | `hospital_miss` | Index among all Hospital-superseded committed date entries in committed `slot_index` order; first miss is `0` | `P("role","hospital.miss")`, `P("resolution_id",resolution_id)`, `P("causal_day_instance",causal_day_instance)`, `P("source_day",source_day)`, `P("hospital_resolution_id",hospital_resolution_id)`, `P("schedule_entry_id",schedule_entry_id)`, `P("action_id",action_id)`, `P("source_receipt_id",source_receipt_id)`, `P("reason","prevented_by_fainting")` |
| `P01.hospital.sylvia_witness` / optional Schedule-Done Sylvia witness | `resolution_issuer_receipt.receipt_id` | `sylvia_hospital_witness` | `0` (zero or one witness for the resolution root) | `P("role","hospital.sylvia_witness")`, `P("kind","sylvia_hospital_witness")`, `P("resolution_kind","schedule_done")`, `P("resolution_id",resolution_id)`, `P("causal_day_instance",causal_day_instance)`, `P("source_day",source_day)`, `P("action_id",action_id)`, `P("schedule_entry_id",schedule_entry_id)`, `P("source_receipt_id",source_receipt_id)`, `P("hospital_miss_receipt_id",hospital_miss_receipt_id)`, `P("care_followup_day",care_followup_day)`, `P("care_followup_entry_id",care_followup_entry_id)`, `P("affection_delta",2)`, `P("dark_delta",1)`, `P("attitude","fixated")`, `P("tier_transition","advance_one_or_stay_love")` |
| `P01.presentation.intent` / Hospital, surviving date, or deferred-pair intent | `resolution_issuer_receipt.receipt_id` | `day_resolution_stage` | Hospital: `0`; surviving solo/group: index among surviving committed dates in `slot_index` order; deferred pair: `0` | `P("role","presentation.intent")`, `P("resolution_id",resolution_id)`, `P("causal_day_instance",causal_day_instance)`, `P("source_day",source_day)`, `P("day_resolution_start_receipt_id",day_resolution_start_receipt_id)`, `P("stage_name",stage_name)`, `P("stage_index",stage_index)`, `P("presentation_kind",presentation_kind)`, `P("schedule_entry_id",schedule_entry_id)`, `P("route_id",route_id)`, `P("timeline_id",timeline_id)`, `P("context_sha256",H(context))`, `P("input_receipt_ids",input_receipt_ids)` |
| `P01.presentation.completion` / physical-completion transaction | `resolution_issuer_receipt.receipt_id` | `day_resolution_stage` | The same zero-based within-stage presentation ordinal used by its `P01.presentation.intent` | `P("role","presentation.completion")`, `P("resolution_id",resolution_id)`, `P("stage_id",stage_id)`, `P("substage_id",substage_id)`, `P("route_id",route_id)`, `P("timeline_id",timeline_id)`, `P("context_sha256",H(context))` |

For `P01.day_resolution.stage`, a top-level row has exact `role="day_resolution.stage"`, `substage_kind=null`, `substage_index=null`, and `schedule_entry_id=null`. Every top-level stage except `increment_day` has `input_receipt_ids=L()`. `increment_day` is derived only after the shared root allocation commits and has exact `input_receipt_ids=L(day_advance_identity_receipt.target_causal_day_instance_issuer_receipt.receipt_id)`; its allocation receipt is stored in the completed-stage output and the input ID cannot be caller-authored. The only entry-substage kinds are `ordinary_action` under `execute_schedule_actions` and `surviving_date` under `execute_schedule_dates`; each uses `role="day_resolution.entry_substage"`, all three nullable fields are then nonnull, and the ordinal equals `substage_index`. An `ordinary_action` has exact `input_receipt_ids=L(schedule_entry_id)`; a `surviving_date` has exact `input_receipt_ids=L(schedule_entry_id,source_receipt_id)`, where the nonnull source ID is read from that validated committed entry. For `P01.presentation.intent`, the exact `(presentation_kind,stage_name,route_id,schedule_entry_id,input_receipt_ids)` variants are `("hospital","hospital_if_triggered","hospital",null,L([condition_receipt_id] + hospital_miss_receipt_ids))`, `("solo"|"group","execute_schedule_dates","dating",schedule_entry_id,L(schedule_entry_id,source_receipt_id))`, and `("twofriends_if_deferred","twofriends_if_deferred","dating",schedule_entry_id,L(schedule_entry_id,source_receipt_id))`. `hospital_miss_receipt_ids` is the exact array of persisted `P01.hospital.miss` child IDs in miss-ordinal order; `L([condition_receipt_id] + hospital_miss_receipt_ids)` flattens that concatenated String array before applying the unique lexical sort, so the Hospital set contains the condition ID even when there are no misses. `date_schedule_entry_ids` is the exact array of committed date entry IDs in validated `slot_index` order, including `[]` when none exist. `stage_index` is the corresponding zero-based index in the frozen D1-6 stage array. Every named input record and `context` must be fully validated before derivation. In the matching `P01.presentation.completion`, `stage_id` is the exact top-level `P01.day_resolution.stage` child ID and `substage_id` is the exact persisted `P01.presentation.intent` child ID, so the completion projection binds its prerequisite without including itself.

The required derivation order is also closed: Schedule entry rows precede the nonempty aggregate row; the Hospital aggregate row precedes its miss rows, the optional witness row, and all Hospital/deferred presentation-intent rows; each presentation-intent row precedes its matching completion row. Recovery replays these same bytes and validates the stored child; it never renumbers surviving elements, recomputes an ordinal from completion order, or substitutes a newer mutable record.
<!-- PLAN01_CHILD_DERIVATION_MATRIX_V1_END -->

### Shared crash-idempotent logical-day identity

Plan 01 consumes, without widening, the Plan-02 `.16` `CausalDayAdvanceIdentityPort` surface:

```gdscript
func configure(identity_issuer: Object) -> Dictionary
func prepare_advance(request: Dictionary) -> Dictionary
func commit_advance(candidate: Dictionary) -> Dictionary
```

For Schedule-Done `increment_day`, only `DayResolutionCoordinator` constructs this exact request from the current validated `DayResolutionPlan` and v4 lifecycle context:

```gdscript
{
	"resolution_kind": "schedule_done",
	"source_resolution_receipt": day_resolution_start_receipt,
	"run_id": String,
	"branch_id": String,
	"desktop_timeline_generation": int,
	"source_day": int,
	"source_causal_day_instance": String,
	"source_causal_day_instance_issuer_receipt": Dictionary,
}
```

`source_resolution_receipt` is byte-equal to the active plan's stored full `day_resolution_start_receipt`; the source day/identity/full issuer receipt are byte-equal to that plan's source facts and current lifecycle context. The port derives `target_day=source_day+1`, key `"schedule_done:" + day_resolution_start_receipt.receipt_id`, and the exact Plan-02 `day_advance_identity_candidate`/`day_advance_identity_receipt`. A caller target, ID-only source receipt, changed start receipt, condition-Hospital receipt, Day 7 source, or second key for the same run/branch/generation/source-day tuple rejects before allocation.

The stage order is exact: prepare allocation -> atomically commit the keyed external-root allocation -> derive the `increment_day` stage child using the target issuer-receipt ID -> prepare one complete checkpoint candidate containing the completed stage output and the target numeric day/causal identity/full issuer receipt -> commit disk -> adopt that byte-equal live candidate. The completed `increment_day` output is exactly:

```gdscript
{
	"source_day": int,
	"target_day": int,
	"source_causal_day_instance": String,
	"target_causal_day_instance": String,
	"target_causal_day_instance_issuer_receipt": Dictionary,
	"day_advance_identity_receipt": Dictionary,
}
```

The allocation receipt's embedded source receipt must be byte-equal to the lifecycle source receipt, and its target token/full receipt must be byte-equal to all target fields. While that checkpoint is incomplete, the active plan and mutation gate keep source-day input disabled. A crash before root commit leaves no allocation; a crash after root commit but before the stage checkpoint re-prepares the same key and receives the same bytes; a crash after disk commit but before live adoption restores/adopts the stored target pair and never allocates again. Root allocation is irreversible: checkpoint failure retains the keyed allocation, source-day live state, active plan, and input block so retry can only move forward. `reset_day_scope`, autosave, plan retirement, and input unlock remain later existing stages and cannot mint or replace the identity.

### Versioned Schedule action registry

`scripts/domain/schedule/ScheduleActionRegistry.gd` loads only `data/manifests/schedule_actions.v1.json`. The manifest top level is exactly:

```json
{
  "schema_version": 1,
  "kind": "schedule_actions",
  "registry_version": 1,
  "records": []
}
```

Every record has exactly:

```gdscript
{
	"action_id": String,
	"allowed_days": Array[int],
	"action_kind": "ordinary" | "solo" | "group",
	"participants": Array[String],
	"repeatable": bool,
	"motivation_cost": 1,
	"route_id": String | null,
	"effect_ids": Array[String],
	"source_receipt_kind": "solo_read_acceptance" | "group_reply_acceptance" | null,
}
```

The exact 20-record v1 registry is:

| `action_id` | Days | Kind / participants | Repeatable | Route | Effects | Source kind |
|---|---|---|---:|---|---|---|
| `training` | 1–6 | ordinary / `[]` | yes | null | `pressure:+1`, `health:+2` | null |
| `working` | 1–6 | ordinary / `[]` | yes | null | `pressure:+2`, `health:-2`, `money:+30` | null |
| `rest` | 1–6 | ordinary / `[]` | yes | null | `pressure:-2`, `health:+1` | null |
| `solo:priscilla:day1` | 1 | solo / `[priscilla]` | no | `dating` | `[]` | solo read |
| `solo:priscilla:day2` | 2 | solo / `[priscilla]` | no | `dating` | `[]` | solo read |
| `solo:priscilla:day4` | 4 | solo / `[priscilla]` | no | `dating` | `[]` | solo read |
| `solo:priscilla:day6` | 6 | solo / `[priscilla]` | no | `dating` | `[]` | solo read |
| `solo:priscilla:day7` | 7 | solo / `[priscilla]` | no | null | `[]` | solo read |
| `solo:lavinia:day2` | 2 | solo / `[lavinia]` | no | `dating` | `[]` | solo read |
| `solo:lavinia:day3` | 3 | solo / `[lavinia]` | no | `dating` | `[]` | solo read |
| `solo:lavinia:day5` | 5 | solo / `[lavinia]` | no | `dating` | `[]` | solo read |
| `solo:lavinia:day6` | 6 | solo / `[lavinia]` | no | `dating` | `[]` | solo read |
| `solo:lavinia:day7` | 7 | solo / `[lavinia]` | no | null | `[]` | solo read |
| `solo:sylvia:day1` | 1 | solo / `[sylvia]` | no | `dating` | `[]` | solo read |
| `solo:sylvia:day3` | 3 | solo / `[sylvia]` | no | `dating` | `[]` | solo read |
| `solo:sylvia:day4` | 4 | solo / `[sylvia]` | no | `dating` | `[]` | solo read |
| `solo:sylvia:day5` | 5 | solo / `[sylvia]` | no | `dating` | `[]` | solo read |
| `solo:sylvia:day7` | 7 | solo / `[sylvia]` | no | null | `[]` | solo read |
| `group:priscilla_lavinia:day2` | 2 | group / `[priscilla,lavinia]` | no | `dating` | `[]` | group reply |
| `group:priscilla_lavinia:day6` | 6 | group / `[priscilla,lavinia]` | no | `dating` | `[]` | group reply |

The JSON stores full values (`[1,2,3,4,5,6]`, exact source-kind strings); shorthand in this table is explanatory only. Records are lexicographically ordered by `action_id`, day arrays are ascending unique, participants/effects preserve their canonical semantic order, and the registry fingerprint is lowercase SHA-256 of canonical UTF-8 JSON. A future semantic change uses a retained new registry version or new action ID; it never edits v1 in place after release.

Exact API:

```gdscript
static func load_current() -> Dictionary
func fingerprint() -> Dictionary
func snapshot(expected_fingerprint: String) -> Dictionary
func lookup(action_id: String, expected_fingerprint: String) -> Dictionary
```

`load_current().value` is exactly `{registry, registry_fingerprint}`. `registry` is a new immutable registry object with no mutator and a private detached manifest snapshot. `fingerprint().value` is exactly `{registry_fingerprint}`. `snapshot().value` is exactly `{manifest, registry_fingerprint}`. `lookup().value` is exactly `{record}`. Manifest and record values are deeply detached; all calls are pure and issue no receipt. A missing, malformed, changed, unknown, or stale registry fails closed before Schedule validation.

### Draft, committed, and source-receipt schemas

Plan 03 owns the saved Schedule view. Plan 01 accepts each draft entry only in this exact seven-key form:

```gdscript
{
	"draft_entry_id": String,
	"day": int,
	"slot_index": int,
	"action_id": String,
	"action_kind": "ordinary" | "solo" | "group",
	"participants": Array[String],
	"source_receipt_id": String | null,
}
```

The registry must exactly reproduce `action_kind` and `participants`; the duplicated draft fields are a tamper check and rendering projection, not authority. Ordinary entries require null source; dates require a source receipt. No route, effects, cost, state, commit ID, friend alias, unlock ID, or warning field is legal.

`contacts.schedule_source_receipts` is a separate exact receipt index. It does not widen the effect/variable `command_receipts` ledger. Every source receipt has exactly:

```gdscript
{
	"receipt_id": String,
	"receipt_provenance": Dictionary,
	"kind": "solo_read_acceptance" | "group_reply_acceptance",
	"action_id": String,
	"day": int,
	"participants": Array[String],
	"previous_receipt_id": String,
}
```

Opening a solo offer performs the scripted acceptance and writes one `solo_read_acceptance` receipt whose predecessor is that exact offer receipt. The initiating request carries exact `{command_id,command_issuer_receipt}`; the issuer verifies purpose `transaction_id`, byte-equal ledger membership, and `command_id == command_issuer_receipt.token`. It then derives exactly row `P01.contact_source.solo`; `receipt_id` and `receipt_provenance` are that result and MUST NOT equal or masquerade as the root command token. There is no solo reply. The group remains the sole reply exception; its accepted reply uses the same issued-command pair and derives exactly row `P01.contact_source.group` bound to exact group-offer ancestry. Identical transaction replay returns the same source receipt; conflicting reuse fails without changing Contacts.

### Schedule-Done Sylvia Hospital witness/care handoff

On the Days 1–6 Schedule-Done/end-of-day branch, `HospitalRules` creates one immutable witness/care receipt only when Hospital supersedes an actually committed Sylvia solo whose exact `solo_read_acceptance` source receipt is still valid. The receipt has exactly:

```gdscript
{
	"receipt_id": String,
	"receipt_provenance": Dictionary,
	"kind": "sylvia_hospital_witness",
	"resolution_kind": "schedule_done",
	"resolution_id": String,
	"causal_day_instance": String,
	"source_day": int,
	"action_id": String,
	"schedule_entry_id": String,
	"source_receipt_id": String,
	"hospital_miss_receipt_id": String,
	"care_followup_day": int,
	"care_followup_entry_id": String,
	"affection_delta": 2,
	"dark_delta": 1,
	"attitude": "fixated",
	"tier_transition": "advance_one_or_stay_love",
}
```

`source_day` is exactly `1|3|4|5`; `action_id` is the matching `solo:sylvia:dayN`; `source_receipt_id` resolves to that action's exact accepted/read receipt; `care_followup_day == source_day + 1`; and `care_followup_entry_id == "contact.hospital_care.sylvia.day%d" % care_followup_day`. `resolution_kind` is the literal `schedule_done`; `receipt_id` and `receipt_provenance` are returned by exact row `P01.hospital.sylvia_witness`, anchored to the verified resolution transaction and the already-derived exact miss ID. No caller supplies any consequence, identity, ordinal, source projection, or follow-up field.

The `hospital_if_triggered` coordinator completion envelope is exactly:

```gdscript
{
	"owner_id": "hospital_rules",
	"kind": "hospital_resolution",
	"value": {
		"required": bool,
		"condition_receipt_id": String,
		"hospital_presentation_intent_id": String | null,
		"hospital_miss_receipt_ids": Array[String],
		"sylvia_hospital_witness_receipt": Dictionary | null,
		"deferred_pair_intent_id": String | null,
	},
}
```

The normalized persisted `DayResolutionPlan` stage receipt retains that exact `value`; therefore the witness is always at `hospital_if_triggered.receipt.value.sylvia_hospital_witness_receipt`. Miss IDs follow committed slot order and are unique. When `required == false`, both intent IDs are null, the miss array is empty, and the witness is null. A qualifying Sylvia date has exactly one matching miss ID and the exact non-null witness; every other case has a null witness.

The same exact receipt is also appended under `contacts.sylvia_hospital_witness_receipts[receipt_id]`. That exact-key dictionary is the durable cross-day handoff ledger: its key must equal the embedded `receipt_id`; values are never deleted or rewritten by invitation rollover, `reset_day_scope`, completed-plan retirement, Save/Logout, or restore. Replaying byte-equal provenance returns the existing record; reusing an occupied receipt ID with changed bytes fails before Contacts or lifecycle mutation. The stage copy and ledger copy must be byte-identical. Plan 01 never adds an `applied` flag because application truth belongs to `dwm-oyo.4`'s separate relationship receipt ledger.

The final `dwm-oyo.4` consumer sees one closed union in that same index. Plan 01 writes only the `resolution_kind="schedule_done"` variant above. Plan 03 may extend the strict Contacts validator and append only this separate pre-Done variant after its condition-Hospital resolution has derived the exact miss from the same accepted Sylvia source:

```gdscript
{
	"receipt_id": String,
	"receipt_provenance": Dictionary,
	"kind": "sylvia_hospital_witness",
	"resolution_kind": "condition_hospital",
	"resolution_receipt_id": String,
	"causal_day_instance": String,
	"source_day": int,
	"action_id": String,
	"source_receipt_id": String,
	"hospital_miss_receipt_id": String,
	"care_followup_day": int,
	"care_followup_entry_id": String,
	"affection_delta": 2,
	"dark_delta": 1,
	"attitude": "fixated",
	"tier_transition": "advance_one_or_stay_love",
}
```

That variant deliberately has no `schedule_entry_id` and cannot be stored in, substituted for, or derived from any Plan-01 stage row. Plan 03 derives it at ordinal `0` under the verified source-action root with the already registered child kind `sylvia_hospital_witness`; its source projection binds the literal condition-Hospital role/discriminator, the exact `hospital_resolution` receipt, causal day/source day, action/source/miss IDs, care fields, and fixed consequence. Across both variants the index admits at most one witness for the same `(causal_day_instance,source_receipt_id)`; a second receipt ID or changed variant for that source conflicts before mutation. Thus `dwm-oyo.4` dispatches only on `resolution_kind`, validates the matching exact provenance/schema, and consumes one semantic source exactly once without a new child kind or forged committed-Schedule ancestry.

This plan records only witnessed provenance and the fixed future consequence. It does **not** mutate affection, dark, attitude, durable tier, Contacts caring history, board/challenge truth, or mastery, and the presence of this receipt is not an application receipt. The original seven-day Phase 03 owner in `dwm-oyo.4` must later validate and consume `receipt_id` exactly once through `RelationshipRules`, then create the caring presentation/history transaction. Neither amendment Plan 03 (`dwm-oyo.3`) nor any Plan-01 stage may claim those effects already applied.

Canonical top-level `committed_schedule` is exactly:

```gdscript
{
	"schema_version": 1,
	"day": int,
	"registry_fingerprint": String | null,
	"entries": Array[Dictionary],
	"commit_receipt": Dictionary | null,
}
```

Each committed entry has exactly:

```gdscript
{
	"schedule_entry_id": String,
	"schedule_entry_provenance": Dictionary,
	"day": int,
	"slot_index": int,
	"action_id": String,
	"action_kind": "ordinary" | "solo" | "group",
	"participants": Array[String],
	"source_receipt_id": String | null,
	"commit_transaction_id": String,
	"state": "committed",
}
```

A fresh logical day may hold an empty, uncommitted aggregate with the current registry fingerprint. `registry_fingerprint == null` is legal only for a migrated empty aggregate with `entries == []` and `commit_receipt == null`. Any nonempty aggregate has a current retained fingerprint and embeds its exact commit receipt byte-for-byte.

### Durable Schedule-foundation publication ledger

Plan 01 creates one `scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd` over the same root-scoped `StorageAdapter` family as the issuer root, but at the distinct fixed relative path `schedule-foundation-publications.json`. This append-only file is outside selectable Save slots, profiles, autosaves, and RunSnapshot/SaveDocument restore participants: selected Load, New Run, profile reset, ordinary rollback, and recovery-journal rewind never delete, replace, or lower it. Its strict schema is `schemas/save/schedule-foundation-publication-ledger.schema.json`; the document is exactly `{schema_version:1,records:Dictionary}`. Each dictionary key is exactly `kind + ":" + semantic_receipt.receipt_id`, and each value is exactly:

```gdscript
{
	"key": String,
	"kind": "schedule_commit" | "day_resolution_start",
	"semantic_receipt": Dictionary,
	"publication": Dictionary,
	"publication_sha256": String,
}
```

The ledger exposes exactly:

```gdscript
const FIXED_PATH := "schedule-foundation-publications.json"

func configure(storage: Object) -> Dictionary
func load() -> Dictionary
func record_before_emit(request: Dictionary) -> Dictionary
```

For `kind="schedule_commit"`, `semantic_receipt` is exactly one validated Schedule commit receipt and `publication` is exactly `{committed_schedule,schedule_commit_receipt}` with `schedule_commit_receipt` byte-equal to it. For `kind="day_resolution_start"`, `semantic_receipt` is exactly one validated day-resolution-start receipt and `publication` is exactly `{resolution_plan,day_resolution_start_receipt}` with `day_resolution_start_receipt` byte-equal to it. No other publication keys or receipt shape are legal.

`configure()` accepts one exact `StorageAdapter` capability with callable `read_text(relative_path)`, `write_atomic(relative_path,text,validator,keep_backup)`, `reconcile(relative_path,validator)`, `exists(relative_path)`, and `describe_root()`; the described root must be the already-approved root-scoped application storage, never `user://` chosen by this class. Configuration is idempotent for that exact object identity and rejects replacement. `load()` branches only on `exists(FIXED_PATH)`: an existing file is first reconciled through the strict document validator and then read; a missing file is initialized by writing the exact UTF-8 bytes of `J({"schema_version":1,"records":{}}) + "\n"` with `keep_backup=true`. Both branches re-read, strict-parse, schema/key/value-validate, byte-compare expected initialization when applicable, and deeply detach the document; malformed, unreadable, or key/value-disagreeing storage fails startup before desktop/run input. `record_before_emit()` accepts exactly `{kind:"schedule_commit"|"day_resolution_start",semantic_receipt:Dictionary,publication:Dictionary,publication_sha256:String}`; it derives `key`, requires `publication_sha256 == H(publication)` under the matrix's exact canonical UTF-8/no-newline law, requires the nested semantic receipt to be byte-equal to the receipt in that kind's publication, and writes canonical document JSON plus one LF with `write_atomic(FIXED_PATH,text,validator,true)`, then re-reads and byte/schema-compares the exact candidate before success. Its success is exactly `value={record:Dictionary,first_delivery:bool}`, `receipt={}`. A new key returns `first_delivery=true`; a byte-identical existing record returns `first_delivery=false`; an occupied key with any changed semantic receipt, publication byte, kind, or hash returns `publication_record_conflict` without rewriting storage. A write/re-read/schema failure returns failure and no signal may emit.

`ApplicationBootstrap` loads exactly one ledger through the exact root-scoped `StorageAdapter` object it retained while constructing the issuer root in Task 3, before constructing the Schedule/day-start ports, then passes that same ledger object as the fourth direct constructor dependency to `GameStateScheduleCommitPort._init(game_state,action_registry,identity_issuer,publication_ledger)` and `DayResolutionStartPort._init(state_port,action_registry,identity_issuer,publication_ledger)`. The constructors validate exact capabilities and retain references privately; no service locator, public getter, fallback in-memory ledger, second storage adapter, or second ledger instance is legal. The ledger records **before** signal emission. Therefore a process loss after durable record but before/after the signal is an intentional at-most-once observation boundary: restart/retry returns the original semantic success and emits no second signal. Transaction progress never depends on receiving that observation—Plan 03 owns the receipt-validating publication-resume adapter around Plan 01's ordinary checkpoint-driven `DayResolutionCoordinator.resume()`—so the authoritative committed state/receipt remains recoverable even if the process died in the pre-emission gap.

### Schedule commit port

`scripts/application/schedule/GameStateScheduleCommitPort.gd` exposes exactly:

```gdscript
func prepare_commit(request: Dictionary) -> Dictionary
func capture() -> Dictionary
func commit(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
func publish(publication: Dictionary) -> Dictionary
```

`prepare_commit()` accepts exactly:

```gdscript
{
	"transaction_id": String,
	"transaction_issuer_receipt": Dictionary,
	"expected_view_fingerprint": String,
	"day": int,
	"causal_day_instance": String,
	"draft_entries": Array[Dictionary],
	"registry_fingerprint": String,
}
```

It treats `expected_view_fingerprint` as the opaque fingerprint issued by Plan 03's view owner; it validates exact type/nonemptiness and binds it into idempotency, but does not reconstruct warning/view-owned fields. Its success value is exactly:

```gdscript
{
	"game_state_candidate": Dictionary,
	"committed_schedule": Dictionary,
	"route_plan": Array[Dictionary],
	"schedule_commit_receipt": Dictionary,
}
```

The receipt is exactly:

```gdscript
{
	"receipt_id": String,
	"receipt_provenance": Dictionary,
	"transaction_id": String,
	"transaction_issuer_receipt": Dictionary,
	"day": int,
	"causal_day_instance": String,
	"registry_fingerprint": String,
	"view_fingerprint": String,
	"schedule_entry_ids": Array[String],
	"source_receipt_ids": Array[String | null],
	"motivation_charged": int,
}
```

The port first requires `verify_issued(transaction_issuer_receipt,&"transaction_id")` and exact `transaction_id == transaction_issuer_receipt.token`. It derives every `P01.schedule.entry` in validated `slot_index` order, then derives exactly `P01.schedule.empty_done` for zero entries or `P01.schedule.commit` otherwise; those rows alone define the ordinals and source projections. `receipt_id` and every `schedule_entry_id` MUST equal the issuer results, and the full returned provenances are persisted in `receipt_provenance` and `schedule_entry_provenance`. Every entry's `commit_transaction_id == transaction_id`. The two ordered ID arrays align with committed slot order. `motivation_charged == entries.size()`. A same issued transaction plus byte-equal canonical request returns the original receipt/candidate; changed bytes are `command_conflict`. Insufficient motivation, stale registry, invalid source ancestry, bad capacity, issuer failure, or stale owner state yields no candidate.

The outer `prepare_commit().receipt` is an exact detached copy of `schedule_commit_receipt`. The internal `game_state_candidate` is exactly `{before_fingerprint,motivation,committed_schedule}`. `capture()` succeeds with exactly `value={backup}` and `receipt={}`; `backup` contains exactly `{motivation,committed_schedule}`. `commit()` compares `before_fingerprint`, silently installs the candidate, and succeeds with exactly `value={committed_schedule}` plus the exact Schedule receipt. `rollback()` restores only the backup fields, emits nothing, and succeeds with exactly `value={restored:true}`, `receipt={}`. `publish()` accepts exactly `{committed_schedule,schedule_commit_receipt}`, verifies byte-equality with current state, and calls the configured ledger with kind `schedule_commit`, that exact receipt/publication, and its recomputed canonical hash. Only `first_delivery=true` emits the one declared committed-Schedule signal; either delivery returns the byte-identical success `{ok:true,code:&"ok",value:{published:true},receipt:schedule_commit_receipt}`, where the result's receipt value is byte-equal to the request field. An occupied receipt key with changed publication bytes returns `schedule_publication_conflict` without a signal. This makes apply-before-caller-progress crash retry byte-idempotent and the port safe as one participant in Plan 03's larger transaction.

### Registry-derived route projection

`ScheduleRules.build_route_plan()` returns, in committed `slot_index` order, only:

```gdscript
{
	"schedule_entry_id": String,
	"slot_index": int,
	"action_id": String,
	"action_kind": "ordinary" | "solo" | "group",
	"participants": Array[String],
	"route_id": String | null,
	"effect_ids": Array[String],
}
```

This projection is transient. Ordinary actions have null route and registered effects. Days 1–6 dates route to `dating`. Day-7 solo destinations have null route and emit no physical route descriptor; their only output is the provenance handoff below. The projection is recomputed from saved committed IDs plus their saved fingerprint; it is never persisted as a second authority.

### Day-7 Schedule provenance handoff

Plan 01 creates `scripts/domain/schedule/Day7ScheduleProvenance.gd` as one configured, mutation-free domain service. It has exactly:

```gdscript
func configure(action_registry: Object, identity_issuer: Object) -> Dictionary
func validate_handoff(request: Dictionary) -> Dictionary
```

`configure()` accepts only the exact retained Schedule registry and Plan-02 production issuer capabilities, is idempotent for that same pair, and rejects replacement. `validate_handoff()` performs no canonical mutation, but it must resolve the saved fingerprint through that configured registry, ledger-verify the request's full transaction issuer receipt, and derive/validate exact row `P01.schedule.day7_provenance` through that configured issuer; it may not reach a global service locator, load a mutable current registry as replacement truth, or preload an issuer.

The request is exactly:

```gdscript
{
	"transaction_id": String,
	"transaction_issuer_receipt": Dictionary,
	"causal_day_instance": String,
	"committed_schedule": Dictionary,
	"source_receipt_index": Dictionary,
}
```

It accepts only a receipt-backed Day-7 empty commit or exactly one registry-valid solo at slot zero whose `source_receipt_id` resolves to the exact accepted/read receipt in `source_receipt_index`. Success `value` is exactly `{terminal_provenance}` and the outer receipt is an exact detached copy of `terminal_provenance`, which has exactly:

```gdscript
{
	"receipt_id": String,
	"receipt_provenance": Dictionary,
	"kind": "day7_schedule_provenance",
	"causal_day_instance": String,
	"day": 7,
	"cause": "empty_done" | "scheduled_solo",
	"registry_fingerprint": String,
	"schedule_commit_receipt_id": String,
	"schedule_entry_id": String | null,
	"action_id": String | null,
	"source_receipt_id": String | null,
}
```

All three trailing identity fields are null for `empty_done` and non-null for `scheduled_solo`. The request carries the same verified transaction root persisted by its Schedule commit. The issuer derives exactly row `P01.schedule.day7_provenance`, and the full returned provenance is stored in `receipt_provenance`; no standalone digest or local ordinal/source projection may mint the receipt. It contains no friend alias, relationship tier/tone, Dark-mode flag, faint condition, ending ID, ordered ending step, presentation form, or playback state.

This is the only Day-7 output Plan 01 may create. Amendment Plan 03 (`dwm-oyo.3`) later persists selection/condition terminal intents carrying this ancestry; the approved original Seven-Day Plan 05 (`dwm-oyo.6`) alone creates `DaySevenRules`, the 13-ID `EndingPlanSchema`, final Sylvia Special -> Sylvia Dark ordering, Dark-mode precedence/forms, and the frozen ending plan. Plan 01 leaves the completed 11-ID interim ending foundation unchanged and never calls its fixed single-primary resolver as final production composition.

### Reversible day-resolution start contract

Plan 01 produces `scripts/application/run/DayResolutionStartPort.gd` with exactly:

```gdscript
func prepare_from_committed_schedule(request: Dictionary) -> Dictionary
func capture() -> Dictionary
func commit(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
func publish(publication: Dictionary) -> Dictionary
```

The request is exactly:

```gdscript
{
	"resolution_id": String,
	"resolution_issuer_receipt": Dictionary,
	"causal_day_instance": String,
	"committed_schedule": Dictionary,
	"route_plan": Array[Dictionary],
	"board_fate_receipt": Dictionary,
}
```

`board_fate_receipt` follows Plan 02's exact `{receipt_id,receipt_provenance,command_id,command_issuer_receipt,board_identity,board_revision,causal_day_instance,fate,source_action_commit_receipt_id,source_action_commit_receipt_provenance}` schema. On this Schedule-Done consumer path, both `source_action_commit_receipt_id` and `source_action_commit_receipt_provenance` are exactly `null`; non-null action ancestry belongs only to Plan 02's condition-driven projected-fate path. Plan 01 ledger-validates the full command root and child provenance and binds its ID and causal day, but does not reinterpret board law. Tests use a schema-exact fixture until Plan 02 exists. Prepare rejects a missing Schedule commit receipt (including synthetic empty `[]`), mismatched day/causal identity/fingerprint/order/IDs, a stale route projection, an uncommitted entry, forged or ID-only provenance, a non-null source-action field, or a board-fate receipt from another causal day. A receipt-backed empty Done is valid.

Prepare success has exactly:

```gdscript
{
	"day_resolution_candidate": {
		"before_fingerprint": String,
		"lifecycle_candidate": Dictionary,
		"resolution_plan": Dictionary,
	},
	"resolution_plan": Dictionary,
	"day_resolution_start_receipt": {
		"receipt_id": String,
		"receipt_provenance": Dictionary,
		"resolution_id": String,
		"causal_day_instance": String,
		"source_day": int,
		"registry_fingerprint": String,
		"schedule_commit_receipt_id": String,
		"board_fate_receipt_id": String,
		"schedule_entry_ids": Array[String],
	},
}
```

The port verifies `resolution_issuer_receipt` as purpose `transaction_id`, requires `resolution_id == resolution_issuer_receipt.token`, and derives exactly row `P01.day_resolution.start`. The outer receipt is an exact detached copy of `day_resolution_start_receipt`; `receipt_id` and `receipt_provenance` are the issuer result. `capture()` succeeds with exactly `value={backup}`, where backup is exactly `{active_resolution_plan}` and receipt is `{}`. `commit()` compares `before_fingerprint`, installs only the prepared active plan silently, and succeeds with exactly `value={resolution_plan}` plus the start receipt. `rollback()` restores exactly the prior active plan and returns `value={restored:true}`, `receipt={}`. `publish()` accepts exactly `{resolution_plan,day_resolution_start_receipt}`, verifies byte-equality with the current active plan and its stored start receipt, and calls the configured publication ledger with kind `day_resolution_start`, that exact receipt/publication, and its recomputed canonical hash. Only `first_delivery=true` emits the committed-start signal; either delivery returns the byte-identical success `{ok:true,code:&"ok",value:{published:true},receipt:day_resolution_start_receipt}`, where the result's receipt value is byte-equal to the request field. An occupied receipt key with changed publication bytes returns `day_resolution_start_publication_conflict` without a signal.

Prepare and commit execute no resolution stage. Plan 03 gives this port to the shared `DesktopConsequenceCoordinator`, which prepares Schedule, causal admission, board fate, and day start, durably checkpoints the combined intent, wins the causal compare-and-swap before any other live adoption, and then forward-recovers every participant before publication/resume. This Plan-01 port remains individually reversible before causal admission and idempotently adoptable afterward; it never owns cross-participant order.

Plan 01 retains the coordinator's no-argument `resume()` as the sole stage engine. It operates only on the current validated checkpointed plan; an identical call while waiting at the same asynchronous boundary or after a completed-but-still-current boundary returns/replays that boundary without a duplicate stage mutation or publication, while a later call continues only the next unfinished checkpoint. It never accepts a caller receipt or resolution ID. Plan 03 alone owns the receipt-validating `resume_publication(day_resolution_start_receipt)` adapter and its normalized result contract; that adapter may call this ordinary `resume()` only after validating the exact current Plan-01 start receipt. Plan 01 must not add a competing `resume_from_publication`/`resume_publication` method.

## Requirement and task map

| Task | Bead | Requirement IDs | Deliverable |
|---:|---|---|---|
| 0 | preflight | all named packets | Clean authority/quarantine/baseline record |
| 1 | `dwm-p2r.12` | `req.schedule.state_models`, `req.schedule.validation`, `req.test.schedule_foundation_gate` | Strict pure rules on accepted schemas |
| 2 | `dwm-wks` | `req.schedule.action_registry`, `req.runtime.schedule_ownership`, `req.test.schedule_foundation_gate` | Exact registry, loader, parity gate |
| 3 | `dwm-p2r.13` | `req.invitation.solo`, `req.invitation.group_resolution`, `req.schedule.day7_provenance`, `req.runtime.commands_signals` | One issuer-authenticated Contacts command port and durable source-receipt ancestry; live desktop hosting remains Plan-03-owned |
| 4 | `dwm-p2r.13` | `req.schedule.done_commit`, `req.runtime.schedule_ownership`, `req.runtime.game_state_facade` | Atomic Schedule participant |
| 5 | `dwm-p2r.13` | `req.save.schedule_state`, `req.save.schedule_migration`, `req.save.restore_atomic`, `req.save.migration` | RunSnapshot/SaveDocument v3 and restore |
| 6 | `dwm-p2r.13` | `req.run.day_range`, `req.run.lifecycle_states`, `req.run.day_resolution_plan` | Reversible start from actual committed input; no synthetic plan |
| 7 | `dwm-p2r.14` | `req.run.day_resolution_plan`, `req.flow.hospital_order` | Causal Days 1–6 stage order |
| 8 | `dwm-p2r.14` | prerequisites for `req.run.day7_terminal_intent` and `req.run.no_day8`; `req.flow.hospital_order`, `req.schedule.day7_provenance` | Presentation adapters and typed terminal-provenance handoff |
| 9 | `dwm-p2r.15`, then `.7` | `req.test.schedule_foundation_gate` and all above | One clean Phase-2R subject and evidence |

## Task 0: Verify authority, quarantine, and baseline

**Files:** None. Read-only task.

- [ ] Confirm the roadmap and this plan are exact hash-bound members of the accepted plan suite, `implementation_authorized` has been separately granted, `dwm-0hi` is closed, and `dwm-p2r.12` is the first ready Schedule issue. Stop if any condition is false. The issuer boundary is deliberately not required for pure Tasks 1–2.
- [ ] Record `git rev-parse HEAD`, `git status --short`, `git worktree list --porcelain`, `git branch --show-current`, and `godot --version` (or the repository's configured Godot command). Do not clean a dirty tree; create a new approved isolated worktree if needed.
- [ ] Record strict-branch evidence without integrating it:

```powershell
git merge-base HEAD feat/p2r7-strict-schedule-validation
git rev-parse feat/p2r7-strict-schedule-validation
git log --oneline 49947e5..5e9ab64
git diff --stat 49947e5..5e9ab64 -- scripts/domain/schedule tests/unit
```

Expected evidence: merge base `49947e5`, quarantined tip `5e9ab64`; no merge/rebase/cherry-pick command is run.

- [ ] Run and record the focused pre-change Schedule/Contacts/Run baseline:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'phase2r_schedule_baseline' -LogName 'phase2r-schedule-baseline.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_rules_phase2r.gd,res://tests/unit/test_schedule_strict_validation.gd,res://tests/unit/test_schedule_route_plan.gd,res://tests/unit/test_contact_invitation_state.gd,res://tests/unit/test_day_resolution_plan.gd,res://tests/unit/test_day_resolution_coordinator.gd,res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_migrations.gd','-gexit')"
```

This baseline may contain already-declared pending tests. Record exact pass/pending/assertion counts; do not call a pending target RED.

## Task 1: Selectively reimplement strict Schedule rules (`dwm-p2r.12`)

**Requirements:** `req.schedule.state_models`, `req.schedule.validation`, `req.test.schedule_foundation_gate`; decision `decision.schedule_commit_model`.

**Files:**

- Modify: `scripts/domain/schedule/ScheduleRules.gd`
- Create: `tests/support/ScheduleRegistryFixtures.gd`
- Modify: `tests/unit/test_schedule_strict_validation.gd`
- Modify: `tests/unit/test_schedule_rules_phase2r.gd`
- Modify: `tests/unit/test_schedule_route_plan.gd`

**Interfaces:**

```gdscript
static func validate_draft_candidate(day: int, existing: Array, candidate: Dictionary,
		registry: Object, expected_fingerprint: String, source_receipts: Dictionary) -> Dictionary
static func validate_draft(day: int, entries: Array, registry: Object,
		expected_fingerprint: String, source_receipts: Dictionary) -> Dictionary
static func validate_committed(committed_schedule: Dictionary, registry: Object,
		source_receipts: Dictionary) -> Dictionary
static func build_route_plan(committed_schedule: Dictionary, registry: Object) -> Dictionary
```

Validation success value is exactly `{candidate}` for draft/candidate/committed validators and `{route_plan}` for projection. Outputs are deeply detached. Existing-state failure wins before candidate failure, and candidate success is implemented by validating the prospective whole draft, not by a second divergent rule set.

- [ ] **Step 1.1: Write RED exact-schema tests.** Require exact seven-key drafts and ten-key committed entries (including issuer child provenance); strict `int` day/slot; nonempty String IDs/elements; unique draft/schedule IDs; unique D1–6 slots within `0..6` while allowing gaps; registry parity for kind/participants; null ordinary source; exact date source; and rejection of caller route/effects/cost/unlock fields. The first RED must name one absent accepted interface or accepted invariant.
- [ ] **Step 1.2: Write RED law matrices.** Cover zero through seven D1–6 entries, eighth rejection, zero/one/two dates, third-date rejection, Day-7 empty, Day-7 one solo slot zero, and rejection of action/group/second/wrong-slot D7 entries. Cover repeat Training/Working/Rest with different draft IDs; reject repeated nonrepeatable dates. Cover P–L canonical order, reversed/tampered pair rejection, group/solo coexistence rejection, and superseded source rejection. Explicitly prove Priscilla may occupy any legal Day-4 slot.
- [ ] **Step 1.3: Write RED projection tests.** Assert exact projection keys, committed slot order, registry-derived route/effects, detached output, stale fingerprint rejection, no persisted/transmitted caller facts, and an empty physical route plan for either legal Day-7 committed aggregate.
- [ ] **Step 1.4: Run RED.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'schedule_rules_red' -LogName 'schedule-rules-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_strict_validation.gd,res://tests/unit/test_schedule_route_plan.gd','-gexit')"
```

Expected RED: assertions fail because the new accepted-schema interface/behavior is absent. A load/parse failure is invalid.

- [ ] **Step 1.5: Implement the smallest pure rule core.** Use the injected registry fixture; do not read `DataCatalog`, live GameState, Contacts, scenes, or files from `ScheduleRules`. Keep the provisional `validate_date_candidate` byte-compatible and isolated during Tasks 1–4 because the still-live legacy GameState facade calls it and the Task-1 GREEN characterization suite exercises that caller. Do not route any new accepted-schema path through it. Task 5 removes the method, its last caller, and its obsolete characterization tests together in the atomic v3 cutover after `rg` proves no caller remains.
- [ ] **Step 1.6: Apply the selective-port disposition.** Reimplement master envelopes, exact types, existing-first/prospective validation, duplicate identity/slot checks, Day-7 structure, and detached outputs. Explicitly do not port the old nine-key caller route/effects shape, global duplicate action IDs, add-time motivation, Day-4 placement, unlock/eligibility dictionaries, or `date_completed` proof.
- [ ] **Step 1.7: Run GREEN and the complete focused Schedule cluster.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'schedule_rules_green' -LogName 'schedule-rules-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_strict_validation.gd,res://tests/unit/test_schedule_rules_phase2r.gd,res://tests/unit/test_schedule_route_plan.gd,res://tests/unit/test_schedule_characterization.gd,res://tests/unit/test_schedule_rules.gd','-gexit')"
```

Expected GREEN: exit 0; every accepted behavior active, no unconditional pass, and every pending item explicitly outside this task.

- [ ] **Step 1.8: Review and commit only the listed paths.** Fresh review must check duplicate-rule masking, nested detachment, registry-only facts, same-type/cross-type pair law, no Day-4 rule, and no mutation/file I/O. Commit subject:

```text
refactor(schedule): validate accepted draft and committed schemas
```

- [ ] Attach evidence and close `dwm-p2r.12`. Query `dwm-wks` readiness before proceeding.

## Task 2: Build the immutable action registry and parity gate (`dwm-wks`)

**Requirements:** `req.schedule.action_registry`, `req.runtime.schedule_ownership`, `req.schedule.validation`, `req.test.schedule_foundation_gate`.

**Files:**

- Create: `data/manifests/schedule_actions.v1.json`
- Create: `schemas/manifests/schedule-actions.schema.json`
- Create: `scripts/domain/schedule/ScheduleActionRegistry.gd`
- Create: `tools/schedule/ScheduleActionManifestValidator.gd`
- Create: `tools/schedule/validate_schedule_actions.gd`
- Create: `tests/unit/test_schedule_action_registry.gd`
- Create: `tests/unit/tooling/test_schedule_action_manifest.gd`
- Modify: `autoload/GameState.gd`
- Modify: `tests/unit/test_game_state.gd`
- Modify: `tests/support/ScheduleRegistryFixtures.gd`

- [ ] **Step 2.1: Claim only `dwm-wks`, then write RED manifest tests.** Require the exact top level, exact record keys/types, the 20 records/table above, sorted IDs/days, canonical P–L order, legal route/effect/source enums, cost exactly one, uniqueness, and byte-stable fingerprint. Mutate each field and assert a specific failure code.
- [ ] **Step 2.2: Write RED registry tests.** Require the exact API and CommandResult values, current fingerprint enforcement, lookup failure on unknown/stale IDs, deeply detached snapshot/record values, and no receipt.
- [ ] **Step 2.3: Write RED runtime-authority tests.** Remove GameState's `_SCHEDULE_ACTION_EFFECTS`; while its legacy Schedule facade exists temporarily, effect execution must look up the exact registry record/fingerprint rather than retain a second table. The test names the old GameState duplicate source instead of ignoring it. `DataCatalog` is read-only in this plan: the immediately following Plan-02 Task-1 / `.16` boundary alone removes `_SCHEDULE_ROWS`, delegates its projection to this registry, and proves cross-catalog parity.
- [ ] **Step 2.4: Run RED.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'schedule_registry_red' -LogName 'schedule-registry-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_action_registry.gd,res://tests/unit/tooling/test_schedule_action_manifest.gd,res://tests/unit/test_game_state.gd','-gexit')"
```

Expected RED: missing manifest/registry/validator or an exact parity assertion, never a parser crash.

- [ ] **Step 2.5: Implement canonical load and validation.** Parse strict JSON, validate the schema and semantic cross-record laws, canonicalize once, compute lowercase SHA-256, retain an immutable detached internal snapshot, and reject a changed file after initialization. Do not parse action IDs for facts. Replace the temporary GameState effect-table lookup with this registry without otherwise changing legacy add/remove behavior in this task.
- [ ] **Step 2.6: Replace the fixture with a registry-backed fixture.** Tests may inject a validated in-memory manifest, but it must run the same semantic validator and fingerprint path; a fake cannot simply claim a record is trusted.
- [ ] **Step 2.7: Run GREEN, standalone validator, and Schedule regression.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'schedule_registry_green' -LogName 'schedule-registry-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_action_registry.gd,res://tests/unit/tooling/test_schedule_action_manifest.gd,res://tests/unit/test_schedule_strict_validation.gd,res://tests/unit/test_schedule_route_plan.gd,res://tests/unit/test_game_state.gd,res://tests/unit/test_schedule_characterization.gd,res://tests/unit/test_schedule_rules.gd','-gexit')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'schedule_registry_cli' -LogName 'schedule-registry-cli.log' -GodotArgs @('-s','res://tools/schedule/validate_schedule_actions.gd','--','--manifest','res://data/manifests/schedule_actions.v1.json','--schema','res://schemas/manifests/schedule-actions.schema.json')"
```

Expected GREEN: exit 0 and identical reported registry fingerprint in both commands.

- [ ] **Step 2.8: Review and commit.** Review canonical serialization, schema/semantic layering, cached-file tamper behavior, current vs retained-version policy, GameState duplicate-table removal, and the explicit DataCatalog handoff. Commit subject:

```text
feat(schedule): register immutable action contracts
```

- [ ] Attach evidence and close `dwm-wks`, then stop this plan. Plan 02 Task 1 must claim/close `.16` and integrate its source-bound issuer/DataCatalog record. Claim `.13` only after `.16` is closed, the recorded commits are ancestors, and every bound digest matches.

## Task 3: Issue exact invitation source receipts (`dwm-p2r.13`)

**Requirements:** `req.invitation.solo`, `req.invitation.group_resolution`, `req.invitation.run_end`, `req.schedule.day7_provenance`, `req.runtime.commands_signals`.

**Issuer boundary:** Before RED, require `dwm-p2r.16` closed, then parse `evidence/phase_2r/contracts/desktop_identity_issuer_boundary.json` with the strict repository reader. Require its exact schema, `owner_beads_id == "dwm-p2r.16"`, and subject `feat(desktop): bind production identity issuance and catalog projections`; run `git merge-base --is-ancestor <boundary_commit> HEAD`; and validate every recorded issuer, root-store, `CausalDayAdvanceIdentityPort`, continuation-journal, DataCatalog, Schedule-registry, Shop-registry, issuer/root/advance-port public-surface, and focused-log digest from the named commit/evidence trees. The record's exact advance-port path is `scripts/application/run/CausalDayAdvanceIdentityPort.gd`; missing either atomic issuer/root method or the port's exact `configure/prepare_advance/commit_advance` surface is boundary drift. Tasks 3–6 additionally run `test_desktop_identity_issuer_boundary.gd` with exact environment value `DWM_REQUIRE_CURRENT_P2R16_BOUNDARY=1` and require current bytes to match while the `.16` handoff is still active. Plan 02 repeats that temporary current-byte gate at `.9` entry and immediately before `.9` closure. After `.9` closes, Tasks 7–9 consume the same injected instances but validate only immutable v1 record bytes, subjects, ancestry, and recorded commit-tree/log bindings plus the integrated `.9` gate; legitimate current evolution no longer refreshes or compares against v1. Any missing record, dirty required boundary, non-ancestor, subject mismatch, historical digest mismatch, or applicable-mode mismatch is a hard stop; never infer a boundary by subject search.

**Files:**

- Modify: `scripts/domain/contact/ContactInvitationState.gd`
- Modify: `autoload/GameState.gd`
- Modify: `autoload/ApplicationBootstrap.gd`
- Create: `scripts/application/contact/ContactCommandPort.gd`
- Modify: `scripts/ui/ContactListApp.gd`
- Modify: `tests/unit/test_contact_invitation_state.gd`
- Modify: `tests/unit/test_game_state.gd`
- Modify: `tests/unit/test_application_bootstrap_profile_stage.gd`
- Modify: `tests/unit/tooling/test_public_surface_inventory.gd`
- Regenerate: `evidence/phase_2r/runtime/game_state_required_surface.json`
- Create: `tests/unit/test_contact_command_port.gd`
- Create: `tests/scene/test_contact_list_app.gd`
- Create: `tests/unit/test_schedule_source_receipts.gd`
- Inspect only: `scripts/ui/MainGameScene.gd`
- Inspect only: `scripts/ui/ComputerDesktop.gd`

**Interfaces:**

```gdscript
static func get_schedule_source_receipt(state: Dictionary, receipt_id: String) -> Dictionary
static func validate_schedule_source_receipt(state: Dictionary, receipt_id: String,
		action_record: Dictionary, expected_day: int) -> Dictionary

# ContactCommandPort application entry points
func configure(game_state: Object, identity_issuer: Object) -> Dictionary
func request_open_contact(friend_id: String) -> Dictionary
func request_reply_invitation(friend_id: String) -> Dictionary

# GameState authenticated mutation seams; application code never invents these fields
func configure_identity_issuer(identity_issuer: Object) -> Dictionary
func open_contact(friend_id: String, command_id: String,
		command_issuer_receipt: Dictionary) -> Dictionary
func reply_invitation(friend_id: String, command_id: String,
		command_issuer_receipt: Dictionary) -> Dictionary

# ContactListApp presentation seam
func configure_command_port(command_port: Object) -> Dictionary
func open_friend(friend_id: String) -> Dictionary
func reply_to_group(friend_id: String) -> Dictionary
```

The two source-receipt methods are pure CommandResult queries; validation success value is exactly `{receipt}` and issues no new receipt.

- [ ] **Step 3.1: Write RED solo tests.** Opening a visible solo offer marks its watermark, changes `AVAILABLE -> ACCEPTED`, removes the separate solo-reply transition, and writes one exact `solo_read_acceptance` source receipt. Require byte-exact `P01.contact_source.solo` parent/kind/ordinal/projected `source_ids`, a ledger-verified full issuer receipt, token equality, exact persisted issuer bytes, and rejection of ID-only, forged, wrong-purpose, or mismatched receipts. Delete/change each row projection, supply the group role/kind, change ordinal, reverse two source tokens, add an extra token, or pass an unsorted list and require failure before Contacts mutation. Replay returns identical Contacts candidate/receipt; same transaction with another offer fails. Unopened expires to one nevermind; accepted-but-uncommitted produces one missed question; Hospital uses its distinct miss reason.
- [ ] **Step 3.2: Write RED group tests.** Group open still assigns `inviter_id` and requires a reply. The first valid issued reply through either participant writes exactly one canonical-pair source receipt using byte-exact row `P01.contact_source.group`; mutate every projected field, substitute the solo row, alter ordinal/order/membership, and require rejection. A second identical delivery replays, a conflicting participant/transaction fails, and superseded solo offers expose no usable source receipt.
- [ ] **Step 3.3: Write RED Day-7 ancestry tests.** Priscilla/Lavinia/Sylvia source receipts bind friend, day, action, predecessor, and exact registry source kind. An offer receipt, read watermark, accepted state, stale-day receipt, wrong participant list, or caller-authored ID alone is insufficient. Sylvia read receipt is queryable for the separate pre-Done Special rule.
- [ ] **Step 3.4: Run RED.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'schedule_sources_red' -LogName 'schedule-sources-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_source_receipts.gd,res://tests/unit/test_contact_invitation_state.gd','-gexit')"
```

- [ ] **Step 3.5: Implement the separate source index and transitions.** Add `schedule_source_receipts` and an initially empty `sylvia_hospital_witness_receipts` exact dictionary to Contacts defaults/validation. This task does not populate the latter; it reserves the strict persisted cross-day handoff location that Task 7 alone may append. Source receipt IDs consume only `P01.contact_source.solo` or `P01.contact_source.group` and persist exact child provenance; `previous_receipt_id` points to existing exact offer/group ancestry, never a reconstructed guess. Keep the issuer root ledger, Contacts source index, and effect/variable command receipts disjoint.
- [ ] **Step 3.6: Install one issuer-authenticated Contacts command port.** Add the final-mode bootstrap stage `construct_identity_issuer_and_contact_commands` immediately after `construct_and_inject_mutation_gate`. It constructs and privately retains exactly one approved root-scoped `StorageAdapter` object outside selectable saves, constructs/configures/loads exactly one production `DesktopIssuerRootStore` through that object, constructs/configures exactly one `.16` `DesktopIdentityNonceIssuer`, injects that exact issuer into `GameState.configure_identity_issuer()`, constructs one `ContactCommandPort`, and configures it with the same GameState/issuer identities. Identical configuration replays; replacement or identity mismatch fails startup. The bootstrap retains the storage adapter plus all three domain/application objects for later Plan-01 and Plan-02/Plan-03 consumers but exposes no public storage/issuer getter, fallback factory, or second root owner. Task 6 must reuse that exact storage object for the distinct fixed publication-ledger path. `ContactCommandPort.request_open_contact(friend_id)` and `request_reply_invitation(friend_id)` accept semantic input only, issue one `purpose=transaction_id` root, require the exact full returned receipt and token equality, and immediately delegate to the matching authenticated GameState seam. GameState independently ledger-verifies that same receipt/token before reading or mutating Contacts. Issuance/configuration failure returns before GameState is called; the port never derives an ID from day/friend text, reads `/root`, owns Contacts state, or exposes the issuer to a scene. Remove `choose_contact_option()` and every other legacy reply-ID author. Group reply remains group-only and solo reply fails `solo_reply_not_required`. Emit `contact_open_committed` and `invitation_reply_committed` only after the first successful commit, never on failure or replay; no Schedule draft is created by Contacts.
- [ ] **Step 3.7: Make the presentation seam explicit and fail-closed.** `ContactListApp.configure_command_port(port)` accepts the typed port exactly once; `open_friend(friend_id)` and `reply_to_group(friend_id)` delegate only to the matching semantic port method. The scene contains no `/root/GameState` or `/root/ApplicationBootstrap` lookup, fallback command ID, issuer call, direct authenticated-GameState call, day-derived identity, clock, or RNG. Input before injection returns/records `contact_command_port_unconfigured` without mutation. Task 3 does not instantiate, register, cache, route, or host `ContactListApp` and does not modify `ComputerDesktop` or `MainGameScene`: Plan 03's real desktop composition consumes the exact bootstrap-retained port and injects it into the off-tree Contact scene before `add_child()`/input. Tests configure the real port explicitly, prove the one issuer object identity across root store/GameState/port, prove issuance failure never calls GameState, and statically reject `open:`, `reply:`, `day%d`, `/root`, `Time`, `randi`, and scene-authored command IDs in the presentation path.
- [ ] **Step 3.8: Run GREEN and Contacts/registry regression.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'schedule_sources_green' -LogName 'schedule-sources-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_source_receipts.gd,res://tests/unit/test_contact_invitation_state.gd,res://tests/unit/test_contact_command_port.gd,res://tests/unit/test_game_state.gd,res://tests/unit/test_schedule_action_registry.gd,res://tests/unit/test_application_bootstrap_profile_stage.gd,res://tests/unit/tooling/test_public_surface_inventory.gd,res://tests/scene/test_contact_list_app.gd','-gexit')"
```

- [ ] **Step 3.9: Review and commit.** Check append-only history, one transition owner, exact ancestry, group supersession, replay/conflict, nested detachment, no service locator/fallback identity, and no invented migration receipt. Commit subject:

```text
feat(contacts): issue exact Schedule source receipts
```

Do not close `.13`; Tasks 4–6 share it.

## Task 4: Build the committed-Schedule state and reversible GameState port (`dwm-p2r.13`)

**Requirements:** `req.schedule.state_models`, `req.schedule.validation`, `req.schedule.done_commit`, `req.schedule.day7_provenance`, `req.runtime.game_state_facade`, `req.runtime.commands_signals`, `req.runtime.schedule_ownership`.

**Files:**

- Create: `scripts/domain/schedule/ScheduleStateSchema.gd`
- Create: `scripts/application/schedule/GameStateScheduleCommitPort.gd`
- Create: `scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd`
- Create: `schemas/save/schedule-foundation-publication-ledger.schema.json`
- Modify: `autoload/GameState.gd`
- Create: `tests/unit/test_schedule_state_schema.gd`
- Create: `tests/unit/test_game_state_schedule_commit_port.gd`
- Create: `tests/unit/test_schedule_foundation_publication_ledger.gd`
- Modify: `tests/unit/test_game_state_facade_contract.gd`
- Modify: `tests/unit/tooling/test_public_surface_inventory.gd`

**Narrow GameState seams used by the port:**

```gdscript
func capture_schedule_commit_state() -> Dictionary
func prepare_schedule_commit_candidate(committed: Dictionary,
		motivation_charged: int) -> Dictionary
func commit_schedule_commit_candidate(candidate: Dictionary) -> Dictionary
func rollback_schedule_commit_state(backup: Dictionary) -> Dictionary
func publish_schedule_commit(publication: Dictionary) -> Dictionary
```

These are facade delegation seams, not a second validator. They cover only current motivation, canonical `committed_schedule`, and the narrow precondition fingerprint. `GameStateScheduleCommitPort` owns the public transaction interface frozen above.

- [ ] **Step 4.1: Write RED schema tests.** Cover fresh current-fingerprint empty state, migrated null-fingerprint empty state, receipt-backed empty Done, nonempty committed state, exact entry/receipt equality, illegal null fingerprint, order/ID/source mismatch, caller route/effect/cost, and nested alias attempts. Independently require the exact publication-ledger document/record union, key equality, strict primitive detachment, lowercase canonical hash, missing-file empty initialization, and rejection of an extra/missing/type-changed member.
- [ ] **Step 4.2: Write RED port tests.** Use the production issuer, registry, Contacts source receipts, and a real isolated `ScheduleFoundationPublicationLedger`. Cover zero/one/seven entries, two dates, repeated ordinary entries, insufficient motivation, stale registry, source tamper, D7 empty/solo, verified child identities/provenances, same-transaction replay, conflicting reuse, forged/ID-only issuer inputs, stale-before-fingerprint, and caller mutation after prepare. Assert every committed entry consumes exact `P01.schedule.entry`, its ordinal is the zero-based validated slot-order index rather than raw slot number/input order, and the aggregate consumes exactly `P01.schedule.commit` or `P01.schedule.empty_done` after entry derivation. For all three rows, mutate each projection, `H()` preimage, source membership/order, parent, kind, or ordinal and require rejection before a candidate is returned. Assert `prepare_commit` and `capture` do not mutate or signal.
- [ ] **Step 4.3: Write RED atomic participant and publication-restart tests.** Prove `commit` silently changes only motivation and `committed_schedule`; `rollback` restores exactly those fields and never overwrites a concurrent unrelated Contacts/Settings change; `publish` rejects a publication not equal to current state. A first exact publish durably records before one signal and returns the frozen success. Reconstruct both ledger and port over the same isolated storage, retry the same semantic receipt/publication after an injected crash immediately after ledger replace/re-read but before caller progress, and require the byte-identical success with zero second signal. Mutate any publication/receipt byte at that key and require `schedule_publication_conflict`; inject write/read/schema failure and require no signal/record success. Selected-save restore, New Run, profile reset, and an ordinary candidate rollback cannot erase or lower the external record.
- [ ] **Step 4.4: Run RED.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'schedule_commit_red' -LogName 'schedule-commit-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_state_schema.gd,res://tests/unit/test_schedule_foundation_publication_ledger.gd,res://tests/unit/test_game_state_schedule_commit_port.gd','-gexit')"
```

- [ ] **Step 4.5: Implement schema, publication ledger, and port.** Resolve every registry record and date source before producing IDs or costs. Compute the canonical request fingerprint once. Prepare the committed aggregate, exact route plan, narrow GameState candidate, and receipt without touching live state. Implement the strict root-scoped ledger and inject it directly in tests; `publish()` records/re-reads before its one optional observation signal and never treats an in-memory flag as restart proof. Do not begin day resolution here; Plan 03 owns composition.
- [ ] **Step 4.6: Isolate the new port from the legacy owner.** The v2 save path and legacy Schedule facade remain loadable only until Task 5 performs the atomic schema cutover; do not make the new port read, write, delegate to, or synchronize `schedule_entries`. `_SCHEDULE_ACTION_EFFECTS` is already gone from Task 2. Add a test proving the new candidate/commit/rollback bytes are independent from every legacy field. No new production caller may be added to the legacy API.
- [ ] **Step 4.7: Do not build the Schedule view.** No draft array, warning latch, pending warning, UI add/remove/move, warning decision, or desktop-board fate is persisted or owned here. Plan 03 supplies `draft_entries` and its authoritative opaque fingerprint later.
- [ ] **Step 4.8: Run GREEN, facade, and static ownership gates.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'schedule_commit_green' -LogName 'schedule-commit-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_state_schema.gd,res://tests/unit/test_schedule_foundation_publication_ledger.gd,res://tests/unit/test_game_state_schedule_commit_port.gd,res://tests/unit/test_game_state_facade_contract.gd,res://tests/unit/test_schedule_strict_validation.gd,res://tests/unit/test_schedule_source_receipts.gd,res://tests/unit/tooling/test_public_surface_inventory.gd','-gexit')"
rg -n "schedule_entries|validate_date_candidate|clear_schedule_with_refund|clear_schedule_without_refund|add_schedule_action|add_schedule_date_entry|remove_schedule_entry" scripts/application/schedule/GameStateScheduleCommitPort.gd scripts/domain/schedule/ScheduleStateSchema.gd
```

Expected static output: zero hits in the new accepted modules. The temporary legacy facade is removed atomically with v3 in Task 5, not hidden in this result.

- [ ] **Step 4.9: Review and commit.** Review port candidate purity, narrow rollback, deterministic identity, source alignment, zero-entry receipt, motivation exactness, ledger atomic write/re-read and conflict law, cold-restart at-most-once signal behavior, nonselectable storage isolation, and absence of view/board authority. Commit subject:

```text
feat(schedule): prepare atomic committed Schedule candidates
```

## Task 5: Persist canonical Schedule in RunSnapshot/SaveDocument v3 (`dwm-p2r.13`)

**Requirements:** `req.save.snapshot`, `req.save.schedule_state`, `req.save.schedule_migration`, `req.save.restore_atomic`, `req.save.migration`, `req.save.test_isolation`, `req.schedule.state_models`, `req.schedule.action_registry`.

**Files:**

- Modify: `scripts/domain/run/RunSnapshotSchema.gd`
- Modify: `scripts/infrastructure/save/SaveDocumentSchema.gd`
- Modify: `scripts/infrastructure/save/SaveMigrations.gd`
- Modify: `scripts/application/restore/RunRestoreParticipant.gd`
- Modify: `autoload/GameState.gd`
- Modify: `autoload/SceneRouter.gd` only to remove its legacy direct Schedule-clear call; add no new routing law
- Modify: `autoload/SaveManager.gd` only where version dispatch/provider keys require it
- Modify: `tests/unit/test_run_snapshot_schema.gd`
- Modify: `tests/unit/test_save_document_schema.gd`
- Modify: `tests/unit/test_save_migrations.gd`
- Modify: `tests/unit/test_restore_participants.gd`
- Modify: `tests/unit/test_schedule_foundation_publication_ledger.gd`
- Delete: `tests/unit/test_schedule_characterization.gd`
- Delete: `tests/unit/test_schedule_rules.gd`
- Modify: `tests/integration/test_restore_transaction.gd`
- Create: `tests/integration/test_schedule_publication_restart.gd`
- Create: `tests/fixtures/snapshots/v2_empty_legacy_schedule.json`
- Create: `tests/fixtures/snapshots/v2_nonempty_top_level_schedule.json`
- Create: `tests/fixtures/snapshots/v2_nonempty_gameplay_schedule_entries.json`
- Create: `tests/fixtures/snapshots/v3_committed_schedule.json`
- Create: `schemas/evidence/phase2r-schedule-v3-boundary.schema.json`
- Create: `tools/schedule/generate_schedule_v3_boundary.gd`
- Create: `tests/unit/tooling/test_schedule_v3_boundary.gd`
- Create after the v3 code commit: `evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json`
- Create after the v3 code commit: `evidence/phase_2r/logs/p2r13-schedule-v3-green.log`

**Version law:** `RunSnapshotSchema.SCHEMA_VERSION == 3` and `SaveDocumentSchema.DOCUMENT_VERSION == 3`. Top-level `schedule` is replaced by top-level `committed_schedule`; `gameplay.schedule_entries` is removed. Plan 02 consumes v3 unchanged and creates v4; Plan 03 consumes v4 and creates v5 with top-level `schedule_view`.

- [ ] **Step 5.1: Write RED v3 schema/round-trip tests.** Require the exact aggregate and current/retained registry validation, no top-level legacy `schedule`, no gameplay legacy field, byte-equal commit receipt, nested detachment, journal/checkpoint round trip, and restore through the production Run participant without signals until finalize. Assert `schedule-foundation-publications.json` is not a RunSnapshot, SaveDocument, recovery-journal, profile, or selectable-slot member and its strict v1 bytes survive a complete document round trip unchanged outside that document.
- [ ] **Step 5.2: Write RED migration tests.** v1 -> v2 must set literal schema 2 before v2 -> v3; never substitute the current constant into the old step. Let `saved_day` be the already-validated v2 active-run day. A v2 document with both legacy Schedule representations missing/empty migrates to `{schema_version:1,day:saved_day,registry_fingerprint:null,entries:[],commit_receipt:null}`. A compatible empty Contacts state gains only empty `schedule_source_receipts` and `sylvia_hospital_witness_receipts` indexes. Nonempty or malformed top-level `schedule`, nonempty/malformed `gameplay.schedule_entries`, or an accepted legacy invitation that would require invented source ancestry fails `unmigratable_legacy_schedule`; migration never invents a source or witness receipt. No migration creates, imports, clears, rewrites, or version-tags the external publication ledger. Rejected source and fixture bytes remain identical.
- [ ] **Step 5.3: Prove no current-registry adoption.** Migration cannot call `ScheduleActionRegistry.load_current()` to stamp an old save. Only a later new logical-day initialization may replace the null empty aggregate with a current-fingerprint empty aggregate.
- [ ] **Step 5.4: Run RED.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'schedule_restore_red' -LogName 'schedule-restore-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_document_schema.gd,res://tests/unit/test_save_migrations.gd,res://tests/unit/test_restore_participants.gd,res://tests/unit/test_schedule_foundation_publication_ledger.gd,res://tests/integration/test_schedule_publication_restart.gd,res://tests/integration/test_restore_transaction.gd','-gexit')"
```

- [ ] **Step 5.5: Implement v3 validation, capture, and the atomic legacy cutover.** `RunSnapshotSchema` delegates committed-Schedule validation to `ScheduleStateSchema` plus retained registry lookup. Run capture emits only canonical state. Remove `schedule_entries`, add-time spend/refund, `validate_date_candidate`, direct execute/clear/queue helpers, their GameState save whitelist member, SceneRouter's direct clear, and obsolete characterization expectations in this same boundary. SaveDocument/journal validation sees one v3 meaning; it does not accept v2 under a v3 tag.
- [ ] **Step 5.6: Implement explicit migration and atomic restore.** Normalize on a detached copy, return no partial candidate on failure, prepare every participant before mutation, apply Run silently, roll back narrow state on later failure, and publish only at finalization. Schedule restore revalidates saved IDs against the saved/retained fingerprint; it never uses a caller's current registry record as replacement truth. Never register the external publication ledger as a selectable restore participant: selected Load/New Run/rollback leave every existing record byte-identical. The integration harness directly reconstructs/configures/loads the Task-4 ledger over the same isolated storage, requires corruption to fail that load, writes a real record, performs those selectable operations, and proves identical lookup/retry while changed bytes conflict. Production bootstrap loading/fatal readiness remains Task 6's `ApplicationBootstrap` file-map responsibility.
- [ ] **Step 5.7: Update fixtures mechanically and inspect every diff.** Current v2 fixtures that represent empty Schedule become exact v3 fixtures. Preserve dedicated v2 migration inputs. Do not handwave a fixture with arbitrary registry hashes or receipts; build valid v3 values through test support using the production canonicalizer.
- [ ] **Step 5.8: Run GREEN, isolation, and journal regression.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'schedule_restore_green' -LogName 'schedule-restore-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_document_schema.gd,res://tests/unit/test_save_migrations.gd,res://tests/unit/test_restore_participants.gd,res://tests/unit/test_checkpoint_journal.gd,res://tests/unit/test_save_manager.gd,res://tests/unit/test_schedule_foundation_publication_ledger.gd,res://tests/integration/test_schedule_publication_restart.gd,res://tests/integration/test_restore_transaction.gd,res://tests/integration/test_save_manager_journal.gd','-gexit')"
rg -n "schedule_entries|_SCHEDULE_ACTION_EFFECTS|validate_date_candidate|clear_schedule_with_refund|clear_schedule_without_refund|add_schedule_action|add_schedule_date_entry|remove_schedule_entry" autoload/GameState.gd autoload/SceneRouter.gd scripts/domain/schedule scripts/domain/run/RunSnapshotSchema.gd scripts/application/restore/RunRestoreParticipant.gd scripts/infrastructure/save
```

Expected GREEN: exit 0, GUID-isolated storage only, migration rejection fixtures unchanged, and no hits in the v3 cutover-owned paths except exact quoted legacy migration-key strings inside migration code. Task 6 still owns the separately listed lifecycle/coordinator transport paths; this task must not claim their old `schedule_entries` names are gone before editing them. There is no fallback for semantic corruption unless existing SaveManager law explicitly permits an earlier compatible checkpoint.

- [ ] **Step 5.9: Review and commit the v3 code boundary.** Review schema dispatch, no `CURRENT_VERSION` leakage into old migration steps, exact null-fingerprint boundary, source immutability, restore apply/rollback/publish order, and no ScheduleView field. Commit every Task-5 runtime, test, migration-fixture, and deletion path except the five post-code evidence paths `schemas/evidence/phase2r-schedule-v3-boundary.schema.json`, `tools/schedule/generate_schedule_v3_boundary.gd`, `tests/unit/tooling/test_schedule_v3_boundary.gd`, `evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json`, and `evidence/phase_2r/logs/p2r13-schedule-v3-green.log`. Require that exact exclusion set and no unrelated staged path, then commit the code boundary with subject:

```text
feat(save): persist canonical committed Schedule
```

- [ ] **Step 5.10: Bind the non-self-referential v3 boundary.** After the code commit exists, require both generated evidence outputs absent before the run; a pre-existing record/log hard-stops rather than being overwritten. Set `$boundaryCommit = (git rev-parse HEAD).Trim()`, require its exact subject `feat(save): persist canonical committed Schedule`, and rerun the exact Step-5.8 GREEN command with `-EvidenceLogPath 'evidence/phase_2r/logs/p2r13-schedule-v3-green.log'` so the permanent log is produced only after the code boundary. `generate_schedule_v3_boundary.gd` has exactly two closed CLI forms: write is `--write --boundary-commit=<40hex> --focused-log=res://evidence/phase_2r/logs/p2r13-schedule-v3-green.log --output=res://evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json`; check is `--check --evidence-commit=<40hex> --record=res://evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json`; missing, extra, duplicate, or mixed flags fail. The write form refuses an existing output, hashes the three production blobs from `$boundaryCommit`, hashes the current permanent log, and writes canonical JSON atomically. The record is exactly `{schema_version:1,owner_beads_id:"dwm-p2r.13",boundary_subject:"feat(save): persist canonical committed Schedule",boundary_commit:String,run_snapshot_schema_path:String,run_snapshot_schema_sha256:String,save_document_schema_path:String,save_document_schema_sha256:String,migration_path:String,migration_sha256:String,focused_log_path:String,focused_log_sha256:String}`. Require the three exact production paths, the exact focused-log path, a 40-hex ancestor code commit with the exact subject, lowercase 64-hex digests, and byte equality. Test every flag, source/log/subject/ancestry/path/hash tamper. Commit exactly the schema, generator, test, record, and permanent log with subject `chore(evidence): bind committed Schedule v3 boundary`; then require the evidence commit's sole parent equals `$boundaryCommit`, set `$evidenceCommit = (git rev-parse HEAD).Trim()`, and run the exact check form. Check reads the one record and log blobs from `$evidenceCommit`, production blobs from the recorded `$boundaryCommit`, validates both exact subjects and direct ancestry, and never substitutes current working-tree bytes. Plan 02 Task 6 consumes this record; never infer either boundary by searching subjects.

```powershell
$boundaryCommit = (git rev-parse HEAD).Trim()
$boundarySubject = (git show -s --format=%s $boundaryCommit).Trim()
if ($boundarySubject -cne 'feat(save): persist canonical committed Schedule') { throw 'P2R13_V3_BOUNDARY_SUBJECT_MISMATCH' }
if (Test-Path -LiteralPath 'evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json') { throw 'P2R13_V3_BOUNDARY_RECORD_ALREADY_EXISTS' }
if (Test-Path -LiteralPath 'evidence/phase_2r/logs/p2r13-schedule-v3-green.log') { throw 'P2R13_V3_BOUNDARY_LOG_ALREADY_EXISTS' }
& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'schedule_restore_boundary_green' -LogName 'schedule-restore-boundary-green.log' -EvidenceLogPath 'evidence/phase_2r/logs/p2r13-schedule-v3-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_document_schema.gd,res://tests/unit/test_save_migrations.gd,res://tests/unit/test_restore_participants.gd,res://tests/unit/test_checkpoint_journal.gd,res://tests/unit/test_save_manager.gd,res://tests/integration/test_restore_transaction.gd,res://tests/integration/test_save_manager_journal.gd','-gexit')
if ($LASTEXITCODE -ne 0) { throw 'P2R13_V3_BOUNDARY_GREEN_FAILED' }
& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'schedule_v3_boundary_write' -LogName 'schedule-v3-boundary-write.log' -GodotArgs @('-s','res://tools/schedule/generate_schedule_v3_boundary.gd','--','--write',"--boundary-commit=$boundaryCommit",'--focused-log=res://evidence/phase_2r/logs/p2r13-schedule-v3-green.log','--output=res://evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json')
if ($LASTEXITCODE -ne 0) { throw 'P2R13_V3_BOUNDARY_WRITE_FAILED' }
& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'schedule_v3_boundary_test' -LogName 'schedule-v3-boundary-test.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_schedule_v3_boundary.gd','-gexit')
if ($LASTEXITCODE -ne 0) { throw 'P2R13_V3_BOUNDARY_TEST_FAILED' }
```

After the exact evidence commit, run the historical-blob check:

```powershell
$evidenceCommit = (git rev-parse HEAD).Trim()
$evidenceSubject = (git show -s --format=%s $evidenceCommit).Trim()
if ($evidenceSubject -cne 'chore(evidence): bind committed Schedule v3 boundary') { throw 'P2R13_V3_EVIDENCE_SUBJECT_MISMATCH' }
$evidenceParents = @(((git show -s --format=%P $evidenceCommit).Trim() -split ' ') | Where-Object { $_ })
if ($evidenceParents.Count -ne 1 -or $evidenceParents[0] -cne $boundaryCommit) { throw 'P2R13_V3_EVIDENCE_PARENT_MISMATCH' }
& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'schedule_v3_boundary_check' -LogName 'schedule-v3-boundary-check.log' -GodotArgs @('-s','res://tools/schedule/generate_schedule_v3_boundary.gd','--','--check',"--evidence-commit=$evidenceCommit",'--record=res://evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json')
if ($LASTEXITCODE -ne 0) { throw 'P2R13_V3_BOUNDARY_CHECK_FAILED' }
```

## Task 6: Begin day resolution only from the committed receipt (`dwm-p2r.13`)

**Requirements:** `req.run.day_range`, `req.run.lifecycle_states`, `req.run.day_resolution_plan`, `req.schedule.done_commit`, `req.schedule.day7_provenance`, `req.test.schedule_foundation_gate`.

**Files:**

- Create: `scripts/domain/schedule/Day7ScheduleProvenance.gd`
- Modify: `scripts/domain/run/DayResolutionPlan.gd`
- Modify: `scripts/domain/run/RunLifecycle.gd`
- Create: `scripts/application/run/DayResolutionStartPort.gd`
- Inspect/consume: `scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd`
- Inspect/consume: `schemas/save/schedule-foundation-publication-ledger.schema.json`
- Inspect/consume: `scripts/application/run/CausalDayAdvanceIdentityPort.gd`
- Inspect/consume: `scripts/application/desktop/DesktopIdentityNonceIssuer.gd`
- Inspect/consume: `scripts/infrastructure/identity/DesktopIssuerRootStore.gd`
- Inspect/consume: `data/schemas/desktop-issuer-root.schema.json`
- Modify: `scripts/application/run/DayResolutionCoordinator.gd`
- Modify: `scripts/application/run/GameStateDayResolutionPort.gd`
- Modify: `autoload/GameState.gd`
- Modify: `autoload/ApplicationBootstrap.gd`
- Modify: `tests/support/FakeDayResolutionStatePort.gd`
- Modify: `tests/support/DayResolutionReceiptFixtures.gd`
- Create: `tests/unit/test_day7_schedule_provenance.gd`
- Modify: `tests/unit/test_day_resolution_plan.gd`
- Modify: `tests/unit/test_run_lifecycle.gd`
- Create: `tests/unit/test_day_resolution_start_port.gd`
- Modify: `tests/unit/test_day_resolution_coordinator.gd`
- Modify: `tests/unit/test_day_resolution_snapshot_production.gd`
- Modify: `tests/unit/test_game_state_facade_contract.gd`
- Modify: `tests/unit/test_application_bootstrap_profile_stage.gd`
- Create: `tests/integration/test_committed_schedule_day_resolution.gd`
- Create: `tests/integration/test_schedule_foundation_bootstrap_wiring.gd`
- Modify: `tests/integration/test_schedule_publication_restart.gd`

`DayResolutionPlan` persists detached `committed_schedule`, `route_plan`, `schedule_commit_receipt_id`, `board_fate_receipt_id`, and its existing exact stage cursors/receipts. It does not persist a caller-authored route/effect duplicate.

- [ ] **Step 6.1: Write RED entry, provenance, and composition-contract tests.** Use `GameStateScheduleCommitPort` to produce a real empty and nonempty commit, then call `DayResolutionStartPort.prepare_from_committed_schedule`. Require exact `P01.day_resolution.start` parent/kind/reserved ordinal/projections; mutate each scalar/array/hash projection, parent, kind, ordinal, source membership, and source order. Reject a bare/synthetic array, receiptless empty, mismatched order, swapped route entry, stale fingerprint, altered source, wrong causal-day board-fate receipt, and a Day-8 source. Assert the exact real schedule survives serialize/restore. Create the pure `Day7ScheduleProvenance` service here, configure it with the exact retained registry/issuer pair, and prove both causes consume byte-exact `P01.schedule.day7_provenance`; mutate every nullable/nonnullable projection, parent, ordinal, membership, and order plus every forged source/receipt/fingerprint failure. RED the production composition until bootstrap retains one real Schedule commit port, day-resolution start port, state port, coordinator, and provenance service with exact shared dependency identities.
- [ ] **Step 6.2: Write RED reversible-port and publication-restart tests.** Require exact request/result/receipt keys, issuer-verified resolution roots and byte-exact `P01.day_resolution.start` provenance, deterministic replay, nested detachment, pure prepare/capture, stale-before conflict, silent narrow commit, exact rollback, publication as the only start signal, and zero calls to `DayResolutionCoordinator.resume()` before publication. First exact day-start publish must atomically record/re-read then signal once. Reconstruct the ledger/start port over the same storage and retry after injected apply-before-Plan02-progress crash; require the byte-identical `{published:true}` success and no second signal. Mutated receipt/resolution-plan bytes at that semantic key return `day_resolution_start_publication_conflict`; storage failure emits nothing. Inject failure before and after this port's own silent commit and prove rollback leaves no changed active plan or executed stage. Cross-participant Schedule/causal/board-fate ordering belongs only to the later shared consequence coordinator.
- [ ] **Step 6.3: Write RED succession/idempotency and no-synthetic tests.** A same-resolution replay returns the existing plan. A different resolution conflicts while the prior plan is incomplete. A completed prior plan is replaced only by a fully validated candidate. Instrument the real `GameStateDayResolutionPort`; production preparation must receive IDs/order from `committed_schedule` and must never call `RunLifecycle.begin_day_resolution(..., [])` as a substitute. The no-argument `DayResolutionCoordinator.resume()` replays/waits at an already checkpointed boundary without a second effect/publication and continues only the next unfinished boundary; assert no Plan-01 `resume_from_publication` or `resume_publication` surface exists so Plan 03 can own its receipt-validating adapter. Six completed D1–6 resolutions advance into Day 7; a receipt-backed Day-7 resolution start is admitted, the configured pure service returns its exact `P01.schedule.day7_provenance` handoff, no Day 8 is created, and no deferred final ending plan is frozen. Task 7 later freezes the exact Day-7 stage shape, and Task 8 alone proves that stage reaches/checkpoints the already-configured provenance service.
- [ ] **Step 6.4: Run RED.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'committed_resolution_red' -LogName 'committed-resolution-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/integration/test_committed_schedule_day_resolution.gd,res://tests/integration/test_schedule_foundation_bootstrap_wiring.gd,res://tests/integration/test_schedule_publication_restart.gd,res://tests/unit/test_day7_schedule_provenance.gd,res://tests/unit/test_day_resolution_start_port.gd,res://tests/unit/test_day_resolution_plan.gd,res://tests/unit/test_run_lifecycle.gd,res://tests/unit/test_day_resolution_coordinator.gd','-gexit')"
```

- [ ] **Step 6.5: Implement the exact reversible start participant and one bootstrap ownership handoff.** Revalidate committed state and route projection against the saved fingerprint. Freeze exact slot order and receipt IDs into a detached lifecycle candidate. Bind, but do not reinterpret, Plan 02's board-fate receipt. Empty Done is accepted only through its real receipt. Add pure prepare plus narrow active-plan capture/commit/rollback seams to `RunLifecycle`/the configured state port; remove the old live-begin call from public composition. `DayResolutionCoordinator.configure(state_port, checkpoint_port, mutation_gate)` becomes the sole three-owner configuration seam and returns the master envelope; identical replay is idempotent and a changed owner returns the exact `day_resolution_coordinator_already_configured` failure before mutation. Keep ordinary no-argument `resume()` checkpoint-idempotent and do not add a Plan-03-owned receipt adapter. Replace bootstrap's private bag read of `_day_resolution_coordinator`: `ApplicationBootstrap` constructs and retains exactly one `GameStateDayResolutionPort` against `/root/GameState`, exactly one coordinator configured through that seam, then passes those four live Objects as direct arguments to the private `GameState._install_day_resolution_runtime(state_port, coordinator, checkpoint_port, mutation_gate)` seam. Before installation, GameState calls `coordinator.verify_configuration(state_port, checkpoint_port, mutation_gate)`, whose exact success is the primitive master envelope `{ok:true,code:&"ok",value:{configured:true},receipt:{}}`; it compares the supplied references internally and never returns one. Remove or privatize `DayResolutionCoordinator.get_state_port()` and require zero public callers/surface hits. The install seam verifies exact capabilities, installs once, and returns only `{ok:true,code:&"ok",value:{installed:true},receipt:{}}`; no Dictionary ever carries an Object reference. `_configure_day_resolution_providers` accepts the retained `state_port` directly. Bootstrap then loads one validated registry, reuses the exact `.16` issuer and the exact Task-3 root-scoped storage object, constructs/configures/loads exactly one `ScheduleFoundationPublicationLedger` on that storage's distinct fixed path, constructs/retains one `GameStateScheduleCommitPort` with direct constructor dependencies `/root/GameState`, registry, issuer, and that ledger, constructs/retains one `DayResolutionStartPort` with direct constructor dependencies retained state port, registry, issuer, and the same ledger, constructs/configures one `Day7ScheduleProvenance` with the same registry/issuer, and injects it into the retained state port. Ledger corruption or missing capability fails startup before either port/input; identical startup replay is idempotent; replacement, a second storage/ledger/port construction, private reflection, `ObjectDB.instance_from_id`, a public owner getter, fallback memory ledger, or a service locator fails. No presentation port is configured yet.
- [ ] **Step 6.6: Replace provisional arrays and receipts.** `GameStateDayResolutionPort` must not seed `[]`, synthesize entry receipts, or accept an action ID as a route ID. Fakes model the same schemas and may observe calls, but cannot be the production success source in the integration test.
- [ ] **Step 6.7: Run GREEN, restore, and disk-durability regression.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'committed_resolution_green' -LogName 'committed-resolution-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/integration/test_committed_schedule_day_resolution.gd,res://tests/integration/test_schedule_foundation_bootstrap_wiring.gd,res://tests/integration/test_schedule_publication_restart.gd,res://tests/unit/test_day7_schedule_provenance.gd,res://tests/unit/test_day_resolution_start_port.gd,res://tests/unit/test_day_resolution_plan.gd,res://tests/unit/test_run_lifecycle.gd,res://tests/unit/test_day_resolution_coordinator.gd,res://tests/unit/test_day_resolution_snapshot_production.gd,res://tests/unit/test_game_state_facade_contract.gd,res://tests/unit/test_application_bootstrap_profile_stage.gd,res://tests/integration/test_day_resolution_disk_durability.gd','-gexit')"
rg -n "schedule_entries|begin_day_resolution\([^\r\n]*\[\]|get_state_port" scripts/domain/run/DayResolutionPlan.gd scripts/domain/run/RunLifecycle.gd scripts/application/run/DayResolutionCoordinator.gd scripts/application/run/GameStateDayResolutionPort.gd
```

Expected static output: zero hits. The accepted transport names `committed_schedule` explicitly, and no real or fake production path may seed a synthetic empty array.

- [ ] **Step 6.8: Review and commit.** Check exact order, real reversible port usage, exact `P01.day_resolution.start` and `P01.schedule.day7_provenance` consumption, one shared durable publication-ledger identity, cold-restart publish replay/no second signal, ordinary-resume wrapper compatibility with no Plan-03 method theft, one retained bootstrap identity for every foundation port/service, no private bag access, no pre-commit stage execution, rollback from every participant boundary, completed-plan succession, empty receipt proof, active-plan snapshot detachment, crash resume, and no Day 8. Commit subject:

```text
feat(flow): prepare resolution from committed Schedule
```

- [ ] Attach all `.13` commit IDs and the exact three required commands `Invoke-IsolatedGodot.ps1:schedule_commit_gate`, `Invoke-IsolatedGodot.ps1:schedule_restore_gate`, and `Invoke-IsolatedGodot.ps1:committed_resolution_green`, including the final command's inspected counts/log hash and Task-6 subject commit. Close `dwm-p2r.13` only after all three are green; then stop this plan. The selector next claims/executes Plan 02's `.9`. Claim `.14` only after `.9` is closed, its boundary/gate is integrated on the current ancestry, and live readiness is green.

## Task 7: Resolve ordinary effects, Hospital, and dates in causal order (`dwm-p2r.14`)

**Requirements:** `req.run.day_resolution_plan`, `req.flow.hospital_order`, `req.invitation.run_end`, `req.runtime.schedule_ownership`.

**Files:**

- Create: `scripts/domain/hospital/HospitalRules.gd`
- Modify: `scripts/domain/run/DayResolutionPlan.gd`
- Modify: `scripts/domain/contact/ContactInvitationState.gd`
- Modify: `scripts/application/run/DayResolutionCoordinator.gd`
- Modify: `scripts/application/run/GameStateDayResolutionPort.gd`
- Inspect/consume: `scripts/application/run/CausalDayAdvanceIdentityPort.gd`
- Modify: `autoload/ApplicationBootstrap.gd`
- Modify: `tests/support/FakeDayResolutionStatePort.gd`
- Modify: `tests/support/DayResolutionReceiptFixtures.gd`
- Create: `tests/unit/test_hospital_rules.gd`
- Modify: `tests/unit/test_day_resolution_plan.gd`
- Modify: `tests/unit/test_day_resolution_coordinator.gd`
- Modify: `tests/scenario/test_hospital_twofriends_order.gd`
- Create: `tests/scenario/test_hospital_invitation_closures.gd`
- Create: `tests/integration/test_committed_schedule_effect_order.gd`
- Create: `tests/integration/test_causal_day_advance_identity_recovery.gd`
- Modify: `tests/integration/test_schedule_foundation_bootstrap_wiring.gd`

**Frozen stages:** Days 1–6 use exactly:

```text
lock_day
validate_schedule
execute_schedule_actions
commit_outcomes
hospital_if_triggered
execute_schedule_dates
twofriends_if_deferred
invitation_rollover
increment_day
reset_day_scope
new_day_autosave
unlock_day
```

Day 7 uses exactly:

```text
lock_day
validate_schedule
close_invitations_run_end
validate_day7_provenance
checkpoint_day7_provenance
```

Task 7 adds only this dependency seam; it does not change `DayResolutionCoordinator.configure(state_port,checkpoint_port,mutation_gate)` or any stage ordinal:

```gdscript
func configure_day_advance_identity_port(
		day_advance_identity_port: Object) -> Dictionary
```

It requires the exact `CausalDayAdvanceIdentityPort` capability, retains one object, and succeeds as `value={configured:true,already_configured:false},receipt={}`; byte-identical replay returns `already_configured:true`, while a missing/replaced object returns `day_advance_identity_port_conflict` before stage mutation. `resume()` fails `day_advance_identity_port_unconfigured` before entering `increment_day`, but earlier stages remain recoverable. Bootstrap alone owns initial configuration and retains the object for Plan 03 composition.

**Desktop boundary:** Before RED, require `dwm-p2r.9` closed and its committed desktop-amendment gate green on the current ancestor chain. Replace Task-6's schema-exact board-fate fixture with the integrated `DesktopBoardFatePort` contract test and require byte parity for request, receipt, provenance, capture/commit/rollback/publication, and failure codes. This check imports no board policy into Plan 01; it proves the handoff did not drift before Hospital/date stages are finalized.

- [ ] **Step 7.1: Write RED stage-shape and day-identity tests.** Require the exact arrays, only the registered resumable stages/substages, and strict stage receipts whose child IDs/provenances consume byte-exact `P01.day_resolution.stage`. Top-level ordinals equal the zero-based exact D1-6/D7 stage index; ordinary/date substage ordinals independently equal their zero-based canonical filtered committed-slot index and never the raw slot number, completion order, or top-level index. Every top-level input set is empty except `increment_day`, whose sole input is the exact target causal-day issuer-receipt ID from its stored allocation receipt. Mutate each nullable discriminator, projected input receipt, row field, parent, kind, ordinal, source membership/order, stage-array position, and filtered-entry order and require precise rejection. D1–6 ordinary substages preserve their relative slot order; date substages preserve their relative slot order after Hospital. `reset_day_scope` retains the completed source Schedule inside the resolution plan while replacing GameState's canonical field with an empty uncommitted aggregate for the new day/current registry. D7 has neither ordinary/date-board, reset, increment, ending-selection, playback, nor Day-8 stage; it retains its committed aggregate and ends at the checkpointed provenance handoff for `dwm-oyo.3`/`dwm-oyo.6`.
- [ ] **Step 7.2: Write RED effect tests.** For each ordinary entry, look up registered effects and commit them exactly once through the existing effect transaction owner using that entry's exact `P01.day_resolution.stage` `ordinary_action` substage child. Two repeated Rest/Training/Working entries apply twice through distinct validated `P01.schedule.entry` IDs and distinct zero-based filtered substage ordinals. Duplicate stage delivery replays receipts; a caller-altered effect, matrix row, ordinal, source projection, or provenance fails before mutation.
- [ ] **Step 7.3: Write RED Hospital matrices.** Cause Hospital after one/multiple ordinary effects, with one/two solos, P–L group, Sylvia on every eligible D1–6 day, and no dates. Require the exact derivation sequence and bytes `P01.hospital.resolution -> P01.hospital.miss[] -> optional P01.hospital.sylvia_witness -> applicable P01.presentation.intent[]`; miss ordinals follow the zero-based committed-slot-order filtered date list, while the aggregate and optional witness ordinals stay zero. Delete/change every projection, substitute a neighboring row, renumber after a replay/resume, reverse/add/remove a source token, or derive a dependent row before its prerequisite and require failure before mutation. Hospital marks every committed date `prevented_by_fainting` exactly once before any dating board, records distinct hospital miss receipts, completes recovery, then permits deferred pair presentation, invitation rollover, and day advance. A qualifying accepted/committed Sylvia solo creates the exact persisted `sylvia_hospital_witness` receipt, writes a byte-identical record into `contacts.sylvia_hospital_witness_receipts`, suppresses Sylvia's missed-question request, and names the exact next-day caring entry; unread, uncommitted, wrong-day, stale-source, replay, and other-friend cases cannot create one. Assert that plan completion/retirement, day reset, Save/Logout, and restore retain the index; Plan 01 changes no affection, dark, attitude, tier, caring-message history, board/challenge result, or mastery; and duplicate resume returns the same receipt. If Hospital is not triggered, dates run in their committed relative order.
- [ ] **Step 7.3a: Write RED allocator ownership and crash-cut tests.** Bootstrap constructs/configures exactly one `CausalDayAdvanceIdentityPort` from the retained `.16` issuer and calls `DayResolutionCoordinator.configure_day_advance_identity_port(port)` once; identical replay succeeds, replacement/missing capability fails, and `get_desktop_contract_state().causal_day_advance_identity_port_instance_id` identifies that retained object only within the current process. Assert the exact Schedule-Done request and completed-stage output above, full source/start/target receipt validation, derived target day/key, and no raw causal-day issue. Inject crashes before prepare, before/after root commit, before stage derivation, before/after disk checkpoint, and before live adoption; destroy/recreate process owners and prove one target token/receipt, one root-map record/counter increment, one stage child, one numeric day advance, and no input unlock. Changed start receipt/request/full source receipt, a condition-Hospital variant, duplicate tuple under another key, stale prepare, ID-only recovery, or target drift fails closed. Assert six successive allocations yield Days 2..7 and no Day-8 allocation.
- [ ] **Step 7.4: Run RED.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'hospital_order_red' -LogName 'hospital-order-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/integration/test_committed_schedule_effect_order.gd,res://tests/integration/test_causal_day_advance_identity_recovery.gd,res://tests/integration/test_schedule_foundation_bootstrap_wiring.gd,res://tests/scenario/test_hospital_twofriends_order.gd,res://tests/scenario/test_hospital_invitation_closures.gd,res://tests/unit/test_causal_day_advance_identity_port.gd,res://tests/unit/test_hospital_rules.gd,res://tests/unit/test_day_resolution_plan.gd','-gexit')"
```

- [ ] **Step 7.5: Split the provisional execute stage and advance only through the shared identity boundary.** Remove `execute_schedule_entries`. The port consumes only the frozen registry projection and committed entry IDs; it never reads caller route/effect fields. Every Hospital resolution request carries exact `{resolution_id,resolution_issuer_receipt}` and verifies token/ledger equality before consuming, in the matrix's required order, `P01.hospital.resolution`, `P01.hospital.miss`, optional `P01.hospital.sylvia_witness`, and applicable `P01.presentation.intent` rows. No producer owns a local ordinal/source builder. `HospitalRules` owns the exact Hospital completion envelope and immutable witness/care receipt, but emits no relationship or caring-message application command. Commit the byte-identical witness into the append-only Contacts handoff index in the same Hospital transaction; rollback restores both plan stage and Contacts index. Hospital outcome writes cancellation/miss facts without deleting or rewriting the historical committed aggregate. `ApplicationBootstrap` constructs/configures one shared advance-identity port from the retained issuer after `.9`, injects it through the separate coordinator seam without changing the frozen three-owner configure signature, and retains it for Plan 03. At `increment_day`, the coordinator executes the exact prepare -> root commit -> stage derivation -> complete checkpoint -> live adoption order above; the checkpoint atomically installs target numeric day, target causal token/full receipt, and the exact completed-stage output while the plan retains immutable source facts. On Days 1–6 only, resolve `current_registry_fingerprint: String` from `ScheduleActionRegistry.load_current().value.registry_fingerprint` after that checkpoint, then `reset_day_scope` creates `{schema_version:1,day:source_day+1,registry_fingerprint:current_registry_fingerprint,entries:[],commit_receipt:null}`; it never clears the Contacts witness ledger. The active plan retains source facts for crash recovery, while the Contacts index remains after plan retirement for the later `dwm-oyo.4` consumer. Day 7 never allocates or clears its provenance aggregate.
- [ ] **Step 7.6: Use one registered Dating route for deferred pair presentation.** Remove the provisional `twofriends` route ID. `twofriends_if_deferred` is a stage/context kind under the existing `dating` presentation route, preserving the P–L outcome without creating a second route authority.
- [ ] **Step 7.7: Run GREEN and scenario regression.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'hospital_order_green' -LogName 'hospital-order-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/integration/test_committed_schedule_effect_order.gd,res://tests/integration/test_causal_day_advance_identity_recovery.gd,res://tests/integration/test_schedule_foundation_bootstrap_wiring.gd,res://tests/scenario/test_hospital_twofriends_order.gd,res://tests/scenario/test_hospital_invitation_closures.gd,res://tests/unit/test_causal_day_advance_identity_port.gd,res://tests/unit/test_hospital_rules.gd,res://tests/unit/test_day_resolution_plan.gd,res://tests/unit/test_day_resolution_coordinator.gd,res://tests/unit/test_effect_transactions.gd,res://tests/unit/test_contact_invitation_state.gd','-gexit')"
```

- [ ] **Step 7.8: Review and commit.** Check effect exactly-once behavior, hospital predicate timing, all-date supersession, no dating board before Hospital, pair order, invitation receipts, exact witness/care schema and persistence, zero premature relationship/caring mutation, one retained advance-identity port, no raw causal-day issuance, root-allocation-before-stage checkpoint ordering, all allocator/checkpoint crash cuts, and resume from every stage boundary. Commit subject:

```text
refactor(flow): resolve committed Schedule in causal order
```

## Task 8: Install Hospital/Dating adapters and hand off Day-7 provenance (`dwm-p2r.14`)

**Requirements:** `req.flow.hospital_order`, `req.schedule.day7_provenance`, prerequisites for `req.run.day7_terminal_intent` and `req.run.no_day8`, `req.runtime.schedule_ownership`.

**Files:**

- Create: `scripts/application/run/HospitalPresentationPort.gd`
- Create: `scripts/application/run/DatingPresentationPort.gd`
- Create: `scripts/application/narrative/DialogicPresentationOwnerAdapter.gd`
- Inspect/consume: `scripts/domain/schedule/Day7ScheduleProvenance.gd`
- Modify: `autoload/DialogicBridge.gd`
- Modify: `scripts/domain/contact/ContactInvitationState.gd`
- Modify: `scripts/application/run/DayResolutionCoordinator.gd`
- Modify: `scripts/application/run/GameStateDayResolutionPort.gd`
- Modify: `scripts/ui/HospitalScene.gd`
- Modify: `scripts/ui/DatingScene.gd`
- Modify: `autoload/ApplicationBootstrap.gd`
- Modify: `autoload/SceneRouter.gd`
- Create: `tests/unit/test_hospital_presentation_port.gd`
- Create: `tests/unit/test_dating_presentation_port.gd`
- Create: `tests/unit/test_dialogic_presentation_owner_adapter.gd`
- Create: `tests/support/FakeDatingPresentationOwner.gd`
- Inspect/consume: `tests/unit/test_day7_schedule_provenance.gd`
- Create: `tests/scene/test_hospital_scene.gd`
- Create: `tests/scene/test_dating_scene.gd`
- Create: `tests/integration/test_schedule_presentation_bootstrap_wiring.gd`
- Modify: `tests/integration/test_desktop_bootstrap_wiring.gd`
- Modify: `tests/integration/test_dialogic_bridge_contract.gd`
- Create: `tests/scenario/test_day7_schedule_provenance.gd`
- Modify: `tests/scenario/test_hospital_twofriends_order.gd`

**Frozen Schedule-Done presentation-port contract:** Both ports expose only:

```gdscript
signal completion_ready(completion_result: Dictionary)
signal completion_failed(failure: Dictionary)

func configure(identity_issuer: Object, physical_owner: Object) -> Dictionary
func begin(request: Dictionary) -> Dictionary
func complete(request: Dictionary) -> Dictionary

# Exact physical-owner surface used by DialogicPresentationOwnerAdapter and
# the schema-exact FakeDatingPresentationOwner; dwm-oyo.4 supplies the real
# dating-challenge implementation without changing this surface.
signal physical_completion_ready(receipt: Dictionary)
signal physical_completion_failed(failure: Dictionary)

func begin_physical(command: Dictionary) -> Dictionary
func validate_physical_completion(request: Dictionary) -> Dictionary
```

`configure()` retains the exact `.16` issuer and one owner object, connects that exact owner's two physical-completion signals once, and rejects a signal source whose object identity differs. Identical replay is idempotent and replacement rejects. The issuer ledger-verifies the resolution root receipt and every child provenance. The Hospital port accepts only `DialogicPresentationOwnerAdapter`, which itself retains the existing `DialogicBridge`; the Dating port accepts only an owner declaring `owner_kind="dating_challenge"`. A missing dependency returns `presentation_port_unconfigured` before routing or physical start. This exact port accepts only a prior committed-Schedule `P01.presentation.intent` under a valid `P01.day_resolution.start`; Plan 03's pre-Done condition-Hospital consumer must use its own typed resolution/presentation ancestry even if bootstrap shares the same physical Dialogic owner.

`begin()` accepts exactly:

```gdscript
{
	"resolution_id": String,
	"resolution_issuer_receipt": Dictionary,
	"stage_id": String,
	"substage_id": String,
	"route_id": "hospital" | "dating",
	"timeline_id": String,
	"context": Dictionary,
	"completion_transaction_id": String,
	"completion_transaction_provenance": Dictionary,
}
```

The Hospital context is exactly `{kind:"hospital",day:int,source_entry_ids:Array[String],miss_receipt_ids:Array[String]}`. The Dating context is exactly `{kind:"solo"|"group"|"twofriends_if_deferred",day:int,schedule_entry_id:String|null,participants:Array[String]}`. Arrays are sorted/unique where semantic order is not owned; the P–L group/pair participant order remains exactly `priscilla,lavinia`. Route must match the port, timeline must be registered in `DialogicTimelineCatalog`, and `completion_transaction_id`/`completion_transaction_provenance` must be exactly the child returned by `P01.presentation.completion` for the matching previously persisted `P01.presentation.intent`; those two matrix rows alone own parent, child kind, ordinal, and source projection. Extra keys, caller coercion, a locally derived completion ID, an unregistered locator, or mismatched root/child provenance reject.

The canonical command is the exact request plus `command_sha256` (lowercase SHA-256 of canonical request bytes) and the owner's nonblank opaque `physical_token`. `begin_physical()` accepts the exact request plus `command_sha256` and returns success exactly `value={physical_token:String,command_sha256:String},receipt={}`. Port success is exactly `{ok:true,code:&"ok",value:{presentation_command:Dictionary},receipt:{}}`. Same completion transaction plus byte-identical request returns the identical command/token; changed bytes return `presentation_command_conflict`.

`complete()` accepts exactly `{presentation_command:Dictionary,physical_completion_receipt:Dictionary}`. The port calls `validate_physical_completion()` with those exact bytes. A valid owner receipt is exactly `{owner_kind:"narrative"|"dating_challenge",physical_token:String,command_sha256:String,completion_transaction_id:String,status:"completed",result:Dictionary}`. The port returns success `value={completion_receipt:Dictionary}` with an outer receipt byte-equal to this exact record:

```gdscript
{
	"receipt_id": String, # exactly completion_transaction_id
	"receipt_provenance": Dictionary, # exactly completion_transaction_provenance
	"resolution_id": String,
	"stage_id": String,
	"substage_id": String,
	"route_id": "hospital" | "dating",
	"timeline_id": String,
	"command_sha256": String,
	"physical_owner_kind": "narrative" | "dating_challenge",
	"physical_token": String,
	"physical_completion_receipt": Dictionary,
}
```

Only the configured owner can validate the physical receipt; token, command hash, completion ID, owner kind, status, result, or emitting-object drift returns `physical_completion_untrusted` before a domain stage mutation. When the exact owner emits `physical_completion_ready`, the port requires one byte-identical in-flight/restored command, runs the same `complete()` validation path, and emits the full success CommandResult once through `completion_ready`; a validation/owner failure emits the full failure once through `completion_failed`. `DayResolutionCoordinator` connects those exact port signals before `begin()`, accepts completion only from the configured port identity, checkpoints the returned receipt, and advances the stage only after that checkpoint succeeds. Exact duplicate owner emission/completion returns the byte-identical receipt without a second coordinator publication; reuse of the completion ID with changed bytes returns `physical_completion_conflict`. These adapters hold only an ephemeral projection of the coordinator-owned pending command—not a second canonical gameplay ledger—and expose no mutation method to a scene: the physical owner owns presentation/token truth, while `DayResolutionPlan` owns the pending command and checkpointed completion receipt. On restore, an unfinished byte-identical command is replayed through the owner and reconstructs the same ephemeral projection; a checkpointed completion is never physically restarted.

`DialogicPresentationOwnerAdapter` implements that owner surface by calling only `DialogicBridge.start_timeline_id()` and accepting completion only from the matching `timeline_finished` event/context; it derives a deterministic token from the completion ID plus command hash, so an unfinished restore reuses the same token. Task 8 changes `DialogicBridge._on_runtime_timeline_ended()` so its non-Ending branch finalizes the retained generic timeline/context and emits exactly one trusted `timeline_finished`; the existing Ending token/completion branch remains unchanged. The otherwise caller-forgeable public `finish_current_timeline()` is removed or made private and has zero production/test callers after the integration test update. The adapter converts only that trusted bridge signal into `physical_completion_ready`; it cannot accept a scene-authored result or start a Dating challenge. `FakeDatingPresentationOwner` proves the future owner contract only. Phase 2R intentionally has no canonical relationship-board/challenge owner: `DatingPresentationPort` remains production-unconfigured and returns `dating_physical_owner_unconfigured` before a Dating route until `dwm-oyo.4` configures it through `ApplicationBootstrap`. This is a deliberate handoff, not a claimed playable Dating board.

**Composition seams:** `DayResolutionCoordinator.configure_presentation_ports(hospital_port, dating_port)`, `GameStateDayResolutionPort.configure_day7_provenance(service)`, and `SceneRouter.configure_schedule_presentation_ports(hospital_port, dating_port)` accept their exact production instances once; identical replay is idempotent and replacement rejects. No public bootstrap/issuer/registry getter is added.

- [ ] **Step 8.1: Write RED scene ownership and retained-foundation tests.** Instrument GameState, Contacts, Schedule state, and lifecycle. `_ready`, button input, timeline completion, and challenge completion in Hospital/Dating scenes may call only their presentation port; direct stat/effect/invitation/day/Schedule/ending mutations fail the test. For Hospital, each surviving date, and the deferred pair, require byte-exact `P01.presentation.intent` followed by its matching byte-exact `P01.presentation.completion`; mutate every variant discriminator, parent, ordinal, `H(context)` preimage, projected field, source member/order, or intent-before-completion relation and require rejection before physical start/stage mutation. Prove exact owner/port signal connection identity, one async trusted completion, rejection of direct/foreign signals or scene-authored receipts, and no stage advance before the coordinator checkpoints `completion_ready`. Within one bootstrap process, capture `get_desktop_contract_state()` before presentation configuration and require every foundation instance ID—including `schedule_port_instance_id`, `provenance_owner_instance_id`, `day_resolution_start_port_instance_id`, and `causal_day_advance_identity_port_instance_id`—to remain equal afterward; missing, swapped, reconstructed, fake, or changed same-boot identities fail before readiness. Never compare those process-local numbers to a prior run or committed evidence file.
- [ ] **Step 8.2: Write RED resume tests.** Crash before presentation-intent derivation, after the exact intent, after route command, after physical completion signal, after exact completion derivation, after port validation, after domain receipt, and after stage checkpoint. Restore must replay the same matrix row/ordinal/source bytes, resume the one unfinished boundary, reconnect signals exactly once, never renumber a surviving presentation, never replay a committed recovery/date effect, and never skip a missing physical receipt. A duplicate runtime-end signal and identical restored owner emission return the one stored receipt/publication; changed bytes fail closed.
- [ ] **Step 8.3: Write RED Day-7 provenance tests.** Receipt-backed empty Done returns the exact `empty_done` provenance; one eligible committed solo plus exact source and commit receipt returns `scheduled_solo`; both must consume exact `P01.schedule.day7_provenance`. Mutate each cause-specific nullable projection, source member/order, parent, kind, or ordinal. Reject planned/draft-only state, offer-only/read-watermark-only proof, wrong source, wrong commit, `date_completed`, a board receipt, group destination, caller friend/tier/tone/ending fields, and Day 8. No case starts a dating board or returns an ending ID.
- [ ] **Step 8.4: Write RED cross-phase ownership tests.** The Day-7 stages stop after the provenance checkpoint. A pre-Done faint, Sylvia-read receipt, Dark-mode flag, relationship state, or Hospital-skip counter is rejected as an extra input to `Day7ScheduleProvenance`; none can select Special, Dark, Alone, a presentation form, or an ordered plan here. Assert production Plan-01 composition never calls `DatingEndingRules` to freeze a final plan and leaves the completed 11-ID interim foundation byte-for-byte unchanged.
- [ ] **Step 8.5: Run RED.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'presentation_day7_red' -LogName 'presentation-day7-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_hospital_presentation_port.gd,res://tests/unit/test_dating_presentation_port.gd,res://tests/unit/test_dialogic_presentation_owner_adapter.gd,res://tests/unit/test_day7_schedule_provenance.gd,res://tests/scene/test_hospital_scene.gd,res://tests/scene/test_dating_scene.gd,res://tests/integration/test_dialogic_bridge_contract.gd,res://tests/integration/test_desktop_bootstrap_wiring.gd,res://tests/scenario/test_day7_schedule_provenance.gd','-gexit')"
```

- [ ] **Step 8.6: Implement and compose the application presentation ports.** Ports translate coordinator commands to scene-safe projections and return exact completion results. Domain effects occur in the coordinator/owning state port only after its exact async `completion_ready` result is checkpointed, never inside the scene. `ApplicationBootstrap` constructs/configures/retains exactly one `DialogicPresentationOwnerAdapter` against the existing `DialogicBridge` and exact issuer, configures one Hospital port with it, connects the coordinator to that exact port's completion/failure signals once, and constructs one Dating port without pretending a relationship-board owner exists. It injects those exact Hospital/Dating port identities into the coordinator and SceneRouter; SceneRouter injects the exact retained port into each off-tree Hospital/Dating scene before `add_child()` or input. Hospital readiness is true; Dating physical-owner readiness is deliberately false/fail-closed and is exposed as such in bootstrap evidence until `dwm-oyo.4` modifies the composition root to configure the retained Dating port with its sole owner. Contract/scenario tests configure that same port type with `FakeDatingPresentationOwner`; they do not make the fake a bootstrap dependency. Missing configuration fails before routing; identical configuration/signal hookup replays and replacement/duplicate hookup rejects. SceneRouter routes only from committed D1–6 presentation intents whose exact port is ready and no longer clears or advances Schedule state; it cannot route an unconfigured Dating presentation or a Day-7 ending from Plan-01 provenance.
- [ ] **Step 8.7: Consume the retained provenance handoff, not an ending plan.** Preserve the exact registry, issuer, `GameStateScheduleCommitPort`, `DayResolutionStartPort`, `GameStateDayResolutionPort`, coordinator, and configured `Day7ScheduleProvenance` identities already composed in Task 6 and source-bound by Plan 02. Configure only the newly retained Hospital/Dating presentation ports on that exact coordinator; do not reconstruct a foundation object or change any existing probe ID. The state port fails `day7_provenance_unconfigured` before mutation in isolated negative tests, while the production graph already holds the one configured service. The service revalidates the full transaction issuer receipt, exact committed aggregate, retained registry fingerprint, source receipt, and commit ancestry, derives/validates exact row `P01.schedule.day7_provenance` through that instance, and returns only the frozen handoff receipt; Task 8 now drives and checkpoints that handoff through the exact Day-7 `P01.day_resolution.stage`. Tests prove object identity across bootstrap and restore with no private reflection, preload singleton, service locator, public owner getter, or contract fake. Remove `date_completed`, planned UI state, synthetic empty arrays, and hospital-skipped counters from Plan-01 Day-7 proof. Do not edit `DatingEndingRules`, the fixed single-primary `ENDING_PLAN_KEYS`, the 11-ID interim manifest, playback, Gallery, or ending queue; `dwm-oyo.6` owns the final 13-ID ordered plan and forms.
- [ ] **Step 8.8: Run GREEN, provenance, and disk-resume regression.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'presentation_day7_green' -LogName 'presentation-day7-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_hospital_presentation_port.gd,res://tests/unit/test_dating_presentation_port.gd,res://tests/unit/test_dialogic_presentation_owner_adapter.gd,res://tests/unit/test_day7_schedule_provenance.gd,res://tests/scene/test_hospital_scene.gd,res://tests/scene/test_dating_scene.gd,res://tests/integration/test_dialogic_bridge_contract.gd,res://tests/integration/test_schedule_presentation_bootstrap_wiring.gd,res://tests/integration/test_desktop_bootstrap_wiring.gd,res://tests/scenario/test_day7_schedule_provenance.gd,res://tests/scenario/test_hospital_twofriends_order.gd,res://tests/integration/test_day_resolution_disk_durability.gd','-gexit')"
```

- [ ] **Step 8.9: Review and commit.** Review node ownership, physical-receipt enforcement, restore cursors, exact Day-7 source ancestry, no board/date route, no Day 8, no ending-plan construction, unchanged interim ending foundation, and no hidden-mechanic explanation. Commit subject:

```text
feat(flow): checkpoint Day 7 Schedule provenance
```

- [ ] **Step 8.10: Run `hospital_dating_adapter_gate`, the bead's own acceptance gate.** `dwm-p2r.14`'s `phase2r.verification_commands` names `Invoke-IsolatedGodot.ps1:hospital_dating_adapter_gate`; the suite list behind that name is defined from the bead's acceptance criteria — the valid, stale, duplicate, conflicting, interrupted, Hospital, pair and Day-7 paths over the real committed schedule, plus the negative half — and recorded with its per-suite coverage survey and mutation evidence in `docs/superpowers/notes/2026-08-19-p2r14-hospital-dating-adapter-gate.md`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'hospital_dating_adapter_gate' -LogName 'hospital-dating-adapter-gate.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_hospital_presentation_port.gd,res://tests/unit/test_dating_presentation_port.gd,res://tests/unit/test_dialogic_presentation_owner_adapter.gd,res://tests/unit/test_day_resolution_coordinator.gd,res://tests/unit/test_day7_schedule_provenance.gd,res://tests/scene/test_hospital_scene.gd,res://tests/scene/test_dating_scene.gd,res://tests/integration/test_committed_schedule_day_resolution.gd,res://tests/integration/test_committed_schedule_effect_order.gd,res://tests/integration/test_committed_schedule_presentation_matrix.gd,res://tests/integration/test_committed_schedule_presentation_resume.gd,res://tests/integration/test_hospital_dating_adapter_negative_contract.gd,res://tests/integration/test_day_resolution_disk_durability.gd,res://tests/integration/test_dialogic_bridge_contract.gd,res://tests/integration/test_schedule_presentation_bootstrap_wiring.gd,res://tests/scenario/test_day7_schedule_provenance.gd,res://tests/scenario/test_hospital_invitation_closures.gd,res://tests/scenario/test_hospital_twofriends_order.gd','-gexit')"
```

- [ ] Attach both `.14` commits and fresh scenario evidence, then close `dwm-p2r.14`. Claim `.15` only after readiness is green.

## Task 9: Seal the Phase-2R Schedule gate and close `.7` tails (`dwm-p2r.15`, then `.7`)

**Requirements:** `req.test.schedule_foundation_gate`; implementation/verification evidence for every requirement mapped above.

**Files:**

- Inspect/consume: `docs/superpowers/plans/2026-08-11-desktop-minesweeper-shop-schedule-01-phase2r-schedule-foundation.md`
- Inspect/consume: `scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd`
- Inspect/consume: `schemas/save/schedule-foundation-publication-ledger.schema.json`
- Modify: `evidence/phase_2r/runtime/game_state_required_surface.json`
- Regenerate: `evidence/phase_2r/runtime/game_state_surface.json`
- Create: `evidence/phase_2r/schedule/gate.json` under the existing `prompt_docs/schemas/evidence_report.v1.json` schema
- Create: `tools/evidence/generate_phase2r_schedule_gate.gd`
- Create: `tests/unit/tooling/test_phase2r_schedule_gate.gd`

This task adds no gameplay behavior. A functional failure returns to its owning earlier task/issue; it is not patched in evidence code. If a RED proves the accepted evidence schema or an unlisted validator cannot represent a required record, stop for a plan-author amendment; do not widen this file map or weaken unrelated preserved-file/P0 integrity gates during execution.

- [ ] **Step 9.1: Write/enable the full gate assertions.** `game_state_required_surface.json` remains a single-script GameState inventory: it classifies only GameState's exact narrow Schedule/day-resolution seams and retired GameState symbols, and the existing `generate_public_surface_inventory.gd --script=res://autoload/GameState.gd` command must not be given non-GameState or duplicate bare method names. `test_phase2r_schedule_gate.gd` and `gate.json` instead own path-qualified source-signature records for the registry API, ScheduleRules API, exact `Day7ScheduleProvenance` API, exact four-dependency constructors plus transaction methods of `GameStateScheduleCommitPort`/`DayResolutionStartPort`, `ScheduleFoundationPublicationLedger.configure/load/record_before_emit`, `CausalDayAdvanceIdentityPort.configure/prepare_advance/commit_advance`, `DayResolutionCoordinator.configure/configure_day_advance_identity_port/verify_configuration/resume`, and the absence/private classification of `DayResolutionCoordinator.get_state_port` plus absence of Plan-03-owned `resume_from_publication|resume_publication`, plus the `completion_ready/completion_failed` signals and `HospitalPresentationPort.configure/begin/complete`, the same Dating surface, and the physical signals plus `DialogicPresentationOwnerAdapter.begin_physical/validate_physical_completion`. They also bind all 13 stable `P01.*` row IDs, including the sole target-issuer-receipt input exception for `increment_day`, each row's exact parent/kind/ordinal/projection law, the required derivation order, and one GREEN observed provenance vector per row. They bind the day-advance request/result/root-record shapes, allocation-before-checkpoint order and crash vectors, the exact external-ledger schema/path/record union, atomic write/re-read-before-emit order, both publish request/result/outer-receipt shapes, first-delivery versus cold-restart replay signal counts, conflict codes, nonselectable restore law, the final bootstrap-probe field set including `causal_day_advance_identity_port_instance_id`, owner class/source/signature records, same-boot equality/distinctness verdicts, and the exact test-command/log hashes proving each live ID maps to the retained production object and `snapshot_provider_instance_id == GameState.get_instance_id()` in that process. Numeric instance-ID values are never serialized into deterministic evidence or compared across Godot processes. Those assertions parse each exact source path, classify public `DialogicBridge.finish_current_timeline` as absent/private, and prove generic runtime completion comes only from the bridge runtime-end handler while Ending completion remains unchanged. They record the Dating production owner as reserved to `dwm-oyo.4`, assert current bootstrap readiness is false/fail-closed, and reject any Phase-2R fake/scene/raw `challenge_finished` signal registered as authority. They also classify every retired legacy Schedule symbol, direct live-begin composition, raw runtime causal-day issuance, any production `derive_child()` call not attributed to exactly one matrix row, any fallback/in-memory/second publication ledger, and Plan-01 final-ending-plan call site as absent and fail on dynamic call sites. The test independently changes every matrix row field and `P/H/S/L/J` result, deletes/adds/renames a row, swaps two source tokens, substitutes a neighboring row, changes ordinal/order, mutates every allocator/ledger/schema/publication field and first/replay verdict, and requires a precise rejection before evidence acceptance; it also mutates every other bound path/signature, bootstrap key/relation attestation, requirement ID, schema/fixture hash, migration code, command record, subject commit, Sylvia witness/care receipt field, and Day-7 provenance field. It parses every checked-in snapshot/Save fixture structurally and proves each `committed_schedule.entries` record has only the exact committed-entry keys and no caller-supplied `route_id`, `effect_ids`, or `motivation_cost`; separate registry parity tests prove those fields remain legal only in authoritative registry records. This structural assertion replaces raw repository text matching, which would falsely reject unrelated route/audio/timeline manifests.
- [ ] **Step 9.2: Commit the gate implementation, then generate deterministic source-bound evidence.** Implement the required-surface classification, generator, and mutation test first. Under separate `DWM_COMMIT_AUTHORIZED=1` authority, commit exactly `evidence/phase_2r/runtime/game_state_required_surface.json`, `tools/evidence/generate_phase2r_schedule_gate.gd`, and `tests/unit/tooling/test_phase2r_schedule_gate.gd` with subject `test(schedule): define the Phase-2R committed Schedule gate`; neither generated output enters that commit. Capture its exact 40-hex SHA as `subject_commit` and require the exact subject/ancestry before generation.

  `generate_phase2r_schedule_gate.gd` accepts exactly `--output`, `--beads-snapshot`, and `--subject-commit`, rejects extra/missing flags, derives every other field from that committed tree and fresh logs, and supports `--check` to compare computed canonical bytes without writing. Record requirement IDs, exact source paths/signatures, manifest/schema/fixture hashes, registry fingerprint, the source-bound v3 Schedule boundary commit/digests, the integrated v4 snapshot/document versions that preserve `committed_schedule` byte-for-byte, migration rejection code, strict-branch disposition, witness/care deferred-consumer boundary, Day-7 provenance handoff boundary, all 13 ordered child-derivation row records and observed vectors, publication-ledger source/schema/storage-path hashes and both publish replay/conflict vectors, the final bootstrap-probe key set, stable owner class/source/signature bindings, same-boot equality/distinctness verdicts, RED/GREEN commands/logs, Beads chain, `subject_commit`, and its exact subject. The matrix binding is `plan01_child_derivation_matrix_sha256`: read this plan from `git show <subject_commit>:docs/superpowers/plans/2026-08-11-desktop-minesweeper-shop-schedule-01-phase2r-schedule-foundation.md`; construct each delimiter as the UTF-8 bytes `"<!-- " + marker_payload + " -->"`, with exact payloads `PLAN01_CHILD_DERIVATION_MATRIX_V1_BEGIN` and `PLAN01_CHILD_DERIVATION_MATRIX_V1_END`; require each constructed delimiter occurs exactly once and BEGIN precedes END; select the exact blob bytes strictly after the LF ending the constructed BEGIN delimiter through the LF immediately before the constructed END delimiter; and hash those bytes without decoding, newline normalization, BOM insertion, or caller input. Do not record a process-local numeric instance ID. Validate every bound Task-9 source with `git show <subject_commit>:<path>`; never hash current HEAD or working-tree bytes. Validate v3 facts from the recorded boundary commit instead of pretending the post-`.9` current tree is still schema v3. It may not accept any semantic fact as caller-supplied data.

  After the code commit, regenerate `game_state_surface.json`, then generate `gate.json` against that exact subject commit and fresh Beads snapshot. These are the only two generated evidence paths and remain uncommitted until Steps 9.3–9.6 pass.

```powershell
$gate_subject_commit = (git rev-parse HEAD).Trim()
if ($gate_subject_commit -cnotmatch '^[0-9a-f]{40}$') { throw 'invalid Schedule-gate code commit' }
if ((git log -1 --format=%s) -cne 'test(schedule): define the Phase-2R committed Schedule gate') { throw 'Schedule-gate code subject mismatch' }
.\tools\beads\Export-BeadsSnapshot.ps1 -OutputPath '.godot/beads/phase2r-all.json'
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'p2r7_surface_generate' -LogName 'p2r7-surface-generate.log' -GodotArgs @('-s','res://tools/runtime/generate_public_surface_inventory.gd','--','--script=res://autoload/GameState.gd','--required=res://evidence/phase_2r/runtime/game_state_required_surface.json','--output=res://evidence/phase_2r/runtime/game_state_surface.json','--search-root=res://autoload','--search-root=res://scripts','--search-root=res://scenes','--search-root=res://tests')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'p2r7_evidence_generate' -LogName 'p2r7-evidence-generate.log' -GodotArgs @('-s','res://tools/evidence/generate_phase2r_schedule_gate.gd','--','--output=res://evidence/phase_2r/schedule/gate.json','--beads-snapshot=res://.godot/beads/phase2r-all.json','--subject-commit=$gate_subject_commit')"
```
- [ ] **Step 9.3: Run the focused Phase-2R Schedule gate.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'phase2r_schedule_gate' -LogName 'phase2r-schedule-gate.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_schedule_action_registry.gd,res://tests/unit/tooling/test_schedule_action_manifest.gd,res://tests/unit/test_schedule_strict_validation.gd,res://tests/unit/test_schedule_source_receipts.gd,res://tests/unit/test_schedule_state_schema.gd,res://tests/unit/test_schedule_foundation_publication_ledger.gd,res://tests/unit/test_game_state_schedule_commit_port.gd,res://tests/unit/test_day_resolution_start_port.gd,res://tests/unit/test_day7_schedule_provenance.gd,res://tests/unit/test_hospital_rules.gd,res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_migrations.gd,res://tests/integration/test_schedule_publication_restart.gd,res://tests/integration/test_schedule_foundation_bootstrap_wiring.gd,res://tests/integration/test_committed_schedule_day_resolution.gd,res://tests/integration/test_committed_schedule_effect_order.gd,res://tests/scenario/test_hospital_invitation_closures.gd,res://tests/scenario/test_hospital_twofriends_order.gd,res://tests/scenario/test_day7_schedule_provenance.gd,res://tests/unit/tooling/test_public_surface_inventory.gd,res://tests/unit/tooling/test_phase2r_schedule_gate.gd','-gexit')"
```

- [ ] **Step 9.4: Run full isolated GUT, import, documentation, manifest, surface/evidence, and Beads structural gates.**

```powershell
.\tools\beads\Export-BeadsSnapshot.ps1 -OutputPath '.godot/beads/phase2r-all.json'
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'p2r7_import' -LogName 'p2r7-import.log' -GodotArgs @('--editor','--quit-after','1')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'p2r7_full' -LogName 'p2r7-full.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gdir=res://tests','-ginclude_subdirs','-gexit')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'p2r7_dialogic' -LogName 'p2r7-dialogic.log' -GodotArgs @('-s','res://tools/dialogic/validate_manifests.gd')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'p2r7_config' -LogName 'p2r7-config.log' -GodotArgs @('-s','res://tools/config/validate_project_config.gd')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'p2r7_surface' -LogName 'p2r7-surface.log' -GodotArgs @('-s','res://tools/runtime/generate_public_surface_inventory.gd','--','--script=res://autoload/GameState.gd','--required=res://evidence/phase_2r/runtime/game_state_required_surface.json','--output=res://evidence/phase_2r/runtime/game_state_surface.json','--search-root=res://autoload','--search-root=res://scripts','--search-root=res://scenes','--search-root=res://tests')"
$gate_subject_commit = (Get-Content -Raw -LiteralPath 'evidence/phase_2r/schedule/gate.json' | ConvertFrom-Json).subject_commit
if ([string]$gate_subject_commit -cnotmatch '^[0-9a-f]{40}$') { throw 'invalid Schedule-gate subject commit' }
if ((git log -1 --format=%s $gate_subject_commit) -cne 'test(schedule): define the Phase-2R committed Schedule gate') { throw 'Schedule-gate subject mismatch' }
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'p2r7_evidence_generate' -LogName 'p2r7-evidence-generate.log' -GodotArgs @('-s','res://tools/evidence/generate_phase2r_schedule_gate.gd','--','--output=res://evidence/phase_2r/schedule/gate.json','--beads-snapshot=res://.godot/beads/phase2r-all.json','--subject-commit=$gate_subject_commit')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'p2r7_evidence_check' -LogName 'p2r7-evidence-check.log' -GodotArgs @('-s','res://tools/evidence/generate_phase2r_schedule_gate.gd','--','--output=res://evidence/phase_2r/schedule/gate.json','--beads-snapshot=res://.godot/beads/phase2r-all.json','--subject-commit=$gate_subject_commit','--check')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'p2r7_evidence' -LogName 'p2r7-evidence.log' -GodotArgs @('-s','res://tools/evidence/validate_evidence.gd','--','--evidence=res://evidence/phase_2r/schedule/gate.json','--schema=res://prompt_docs/schemas/evidence_report.v1.json')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '.\tools\testing\Invoke-IsolatedGodot.ps1' -SuiteId 'p2r7_docs' -LogName 'p2r7-docs.log' -GodotArgs @('-s','res://tools/docs/validate_docs.gd','--','--beads-snapshot=res://.godot/beads/phase2r-all.json')"
bd lint dwm-p2r.7 dwm-p2r.9 dwm-p2r.12 dwm-wks dwm-p2r.16 dwm-p2r.13 dwm-p2r.14 dwm-p2r.15 --status all --json --readonly
bd dep cycles --json --readonly
bd orphans --json --readonly
bd show dwm-p2r.7 --json --readonly
git diff --check
```

Expected: every command exits 0; the second surface generation and second evidence generation/validation are byte-equal; `bd dep cycles` and `bd orphans` report no relevant defect; the full-suite log accounts for every pending/skipped test.
- [ ] **Step 9.5: Run static ownership searches.** These patterns must have no production authority hits beyond explicit legacy migration-key constants or comments in evidence:

```powershell
rg -n "schedule_entries|validate_date_candidate|_SCHEDULE_ACTION_EFFECTS|clear_schedule_with_refund|clear_schedule_without_refund" autoload scripts
rg -n "unlock_receipt_id|date_completed" autoload/GameState.gd scripts/domain/schedule scripts/application/schedule scripts/application/run
rg -n '"route_id"\s*:\s*"twofriends"|route_id[^\r\n]*twofriends' autoload/GameState.gd scripts/domain/contact scripts/domain/schedule scripts/application/run
```

The first search may match exact quoted legacy migration-key constants/comments only and must have no executable production call or field. The second search deliberately excludes the unchanged interim `DatingEndingRules`, whose old Day-7 resolver remains historical compatibility until `dwm-oyo.6`; Plan 01 must introduce no new proof dependency on those tokens. The third forbids the retired route value while allowing registered Dialogic/audio IDs and the `twofriends_if_deferred` stage/context name. Fixture entry-key ownership is enforced structurally by Step 9.1, not by a text search that confuses unrelated manifests with Schedule state.

- [ ] **Step 9.6: Fresh-context review.** Require zero P0/P1 findings across registry authority, schema exactness, migration immutability, idempotency, rollback, Hospital/date order, exact unapplied Sylvia witness/care persistence, Day-7 ancestry handoff, no Plan-01 final ending plan, save isolation, source/evidence binding, and absence of Plan-03/Plan-02 ownership leakage.
- [ ] **Step 9.7: Commit the immutable generated evidence boundary.** Under separate commit authority, commit exactly `evidence/phase_2r/runtime/game_state_surface.json` and `evidence/phase_2r/schedule/gate.json` as the direct child of the Step-9.2 code commit. Commit subject:

```text
test(schedule): seal the Phase-2R committed Schedule gate
```

After the evidence commit, repeat the generator `--check` and surface byte-equality checks using `gate.json.subject_commit`; both must remain byte-identical although current HEAD is now the evidence commit. Record both SHAs in `.15` evidence. A one-commit substitution, current-HEAD hash, working-tree hash, empty evidence commit, or subject-commit refresh is a hard failure.

- [ ] Attach the exact subject commit, command lines, counts, log paths, registry fingerprint, schema versions, and review disposition; close `dwm-p2r.15` only when every gate is green.
- [ ] Query `bd show dwm-p2r.7 --json` and its full dependency tree. Close `.7` only if all its own acceptance criteria and every child are actually complete; otherwise leave it open and report the remaining tail exactly. Never close a parent epic from this plan.

## Completion checklist

- [ ] `ScheduleRules` validates the exact draft/committed schemas and derives route/effects only through the saved registry fingerprint.
- [ ] The 20-record v1 registry is the only Schedule action-fact authority; GameState contains no duplicate effect table, and the integrated Plan-02 Task-1 boundary proves DataCatalog is only a projection before Plan-01 Task 3 begins.
- [ ] Solo read and group reply produce exact durable source receipts; superseded or stale proof fails closed.
- [ ] Every production child consumes exactly one of the 13 canonical `P01.*` rows with the frozen parent, child kind, zero-based ordinal, sorted projection, and prerequisite order; mutation/evidence gates reject every local or drifted derivation.
- [ ] Drafting spends nothing; the reversible Schedule port charges exactly one per committed entry only on commit, replays duplicates, and rejects conflicts without mutation.
- [ ] Schedule-commit and day-resolution-start publication records are atomically durable before their observation signals; cold-restart identical retry returns the original semantic success with no second signal, changed bytes conflict, and selectable restore cannot roll the root-scoped ledger back.
- [ ] Top-level `committed_schedule` persists in v3; no `schedule_view` exists until Plan 03; empty-only migration invents no registry or ancestry facts.
- [ ] Schedule-Done day resolution begins from the real committed receipt and exact ordered entries; production never supplies synthetic `[]`.
- [ ] On the Schedule-Done/end-of-day branch, Days 1–6 resolve ordinary effects, condition/Hospital, surviving dates, pair presentation, rollover, and day advance in the frozen order.
- [ ] Every Schedule-Done day change uses the one retained root-atomic `CausalDayAdvanceIdentityPort`; keyed allocation commits before the complete stage/day checkpoint, every crash retries the same target, the lifecycle token/full issuer receipt move together, and raw causal-day issuance or Day-8 allocation is impossible.
- [ ] A pre-Done action-triggered Hospital never enters the Plan-01 start/stage/receipt matrix or this plan's presentation-port request; Plan 03 consumes its issuer-anchored accepted/unfulfilled sources through a separate recoverable resolution.
- [ ] A Schedule-Done Hospital-superseded accepted/committed Sylvia solo persists exactly one `resolution_kind="schedule_done"` witness/care receipt in both its stage and the append-only Contacts handoff index and creates no Sylvia missed question. The index reserves the exact disjoint Plan-03 `resolution_kind="condition_hospital"` source-level variant, rejects a second variant for the same causal-day source, and exposes only this closed union to `dwm-oyo.4`; neither producer applies relationship/caring consequences.
- [ ] Day 7 produces only exact `empty_done` or one receipt-backed `scheduled_solo` provenance, never a dating board, ending ID, ordered plan, or Day 8; `dwm-oyo.3` owns terminal intents and `dwm-oyo.6` owns final Alone/Sylvia/ordered-plan law.
- [ ] Hospital/Dating nodes are presentation-only and all crash boundaries resume exactly once.
- [ ] `req.test.schedule_foundation_gate` is green at one clean commit, `.15` is closed with fresh evidence, and `.7` closes only if its complete live tail is satisfied. No evidence record claims `req.test.schedule_gate`, saved warnings, or the four-participant Done composition.
- [ ] No task in this plan implemented ScheduleView, warnings, desktop board fate, final Done composition, visible prose, art, audio, animation, balancing, or Observer opportunity presentation.

## Handoff to later plans

Plan 02 consumes snapshot v3 and leaves `committed_schedule` byte-for-byte while creating v4 desktop/lifecycle identity; its callback-progress checkpoints do not replace or roll back Plan 01's root-scoped publication ledger. Its `.16` boundary also supplies the one root-atomic `CausalDayAdvanceIdentityPort`; Plan 01 configures/retains that exact object, uses it for Schedule-Done advancement, and hands the same object to Plan 03—never its issuer, root, or a parallel allocator. Amendment Plan 03 consumes the exact registry seam, `GameStateScheduleCommitPort`, canonical `committed_schedule`, `DayResolutionStartPort`, ordinary checkpoint-idempotent `DayResolutionCoordinator.resume()`, Schedule-Done Hospital/Dating adapters, and Day-7 provenance handoff. It alone owns the receipt-validating `resume_publication(day_resolution_start_receipt)` adapter, adds v5 `schedule_view`, warning state, the mutually exclusive lifecycle `active_condition_hospital_plan` variant, board-fate composition, atomic Done, typed Day-7 selection/condition terminal intents, and the separate pre-Done condition-Hospital resolution/dispatch path. That path consumes the `hospital_day` outbox intent and its exact accepted/unfulfilled source receipts; it never manufactures a Schedule commit, Plan-01 start/stage receipt, or Plan-01 presentation intent. Its `ConditionHospitalDayAdvancePort` must call the retained shared allocator with `resolution_kind="condition_hospital"`, the active plan's exact resolution receipt, and the current full causal-day issuer receipt, then preserve the same root-commit-before-lifecycle-checkpoint law. It may append only the exact `resolution_kind="condition_hospital"` Sylvia witness variant above and does not apply either witness variant or freeze an ending plan. The original seven-day Phase 03 owner `dwm-oyo.4` later consumes the closed Contacts witness union through `RelationshipRules` exactly once per semantic source and owns its caring-history presentation transaction. The original Phase 05 owner `dwm-oyo.6` consumes the terminal intents and alone freezes the final ordered ending plan/forms.

Completing, committing, or closing this plan does not authorize Plan 02, Plan 03, Plan 04, a merge, push, release, or runtime work outside the explicit authority that was granted.
