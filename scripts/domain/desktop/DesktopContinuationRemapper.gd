class_name DesktopContinuationRemapper
extends RefCounted

## Selected-Load snapshot identity remapper (Plan 02 Task 6, dwm-p2r.32, req.desktop
## .cross_app_actions), amendment plan lines 287-291.
##
## TABLE-DRIVEN SCOPE, resolving the brief's "current-causal-day base-completion and Supportz
## records" clause (controller ruling, bead addendum 9). Amendment SS8.3 places them in Task 7 -- a
## per-branch Supportz purchase count, a per-causal-day purchase flag, and base-completion receipts
## that MinesweeperCapabilityRules.supportz_eligible() consumes -- and Task 7 has since landed them
## on DesktopConsequenceState as the single `shop_ledger` member (see that file's own class doc).
## _REMAP_TABLE's `shop_ledger` row is `handled: true`: none of its three members is a transaction id
## or an anchored child provenance (a purchase count and opaque historical causal_day_instance
## tokens), so _remap_consequence()'s existing duplicate(true) already carries it forward correctly.
##
## Every row this remapper actually HANDLES operates on a member RunSnapshotSchema v4 already
## declares (DesktopBoardState._CAPTURE_KEYS / DesktopConsequenceState's own _STATE_KEYS/
## _PENDING_KEYS/outbox union). Two categories are explicitly DEFERRED rather than guessed at, each
## with its row's own `reason`:
##  - admission_checkpoint_receipt/checkpoint_receipt are content-hash-immutable records anchored to
##    a historical `SaveManagerCheckpointPort.commit_consequence_checkpoint()` preimage; remapping
##    their bytes would require rewriting the on-disk consequence-checkpoint document they describe,
##    which is outside a pure in-memory snapshot remap.
##  - destination_intent/notification_intent/outbox provenance-consumer members have no frozen
##    internal shape anywhere in this codebase today, so this remapper does not guess at their
##    contents; it leaves them exactly as captured, except the now-composed pending
##    day7_terminal record below. Published records remain historical evidence.
##
## AMENDMENT PLAN 03 TASK 4 (dwm-oyo.3) STEP 4. The twelve v5 rows at the end of _REMAP_TABLE are
## all implemented. What is remapped: `snapshot.schedule_view` (its causal_day_instance, the pending
## warning activation with its stored preimage/fingerprint/child, its attempt receipts, the consumed
## terminal index, and the append-only condition-departure ledger), the two admission-ready
## `schedule_view_before`/`schedule_view_after` members of the consequence recovery payload, and
## `snapshot.lifecycle` (its own identity quadruple, the active condition-Hospital plan, the
## immutable condition-Hospital history, and the terminal intent handoff).
##
## WRITING `lifecycle` BYTES IS NOT A SECOND LIFECYCLE REMAPPER. RunRestoreParticipant still installs
## the remapped lifecycle THROUGH RunLifecycle.prepare_restore(), and RunLifecycle remains the only
## owner that validates and installs it; this file only rewrites the identity references inside the
## bytes that participant carries. The lifecycle's own branch_id/desktop_timeline_generation/
## causal_day_instance/causal_day_instance_issuer_receipt move to the bundle's because
## RunLifecycle._validate_condition_lifecycle requires an UNSPLIT active plan's identity to equal the
## lifecycle's own, and that plan's still-live source identity is remapped here: either both move or
## neither can.
##
## TWO DELIBERATELY HISTORICAL REGIONS. (1) A consumed warning receipt keeps its `activation_id` and
## `activation_id_provenance` byte-for-byte: after consumption `pending_warning` is null and the
## activation's opening issuer receipt is gone from the document, so that child is not re-derivable.
## The consumed record is therefore deliberately mixed -- historical activation identity, recomputed
## fingerprint, recomputed index key, terminal receipt re-derived under the mapped terminal root.
## (2) `condition_hospital_history` is duplicated and VALIDATED, never remapped: past the retirement
## checkpoint the record is immutable and its roots never enter the census.
##
## THE LEDGER IS EXCLUDED FROM THE OPTIMISTIC FINGERPRINT. ScheduleViewState.fingerprint() hashes six
## view members plus the expected registry fingerprint and deliberately omits
## `condition_departure_receipts`, so rekeying that append-only recovery ledger here can never
## fabricate a different optimistic view expectation for the restored run.
##
## PURITY. No live issuer/root object is called: `derive_child()`'s preimage law (plan line 537,
## mirrored from DesktopIdentityNonceIssuer._child_id -- that file's frozen public surface forbids
## adding a shared static, so the pure formula is duplicated here rather than imported) only needs
## the NEW parent receipt's namespace/counter/receipt_id, which `identity_allocation_bundle` already
## carries. Every remap here is therefore a deterministic function of its two inputs.

const _IDENTITY := preload("res://scripts/domain/desktop/DesktopIdentity.gd")
const _CONSEQUENCE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const _ACTION_RECEIPT := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const CHILD_SCHEMA_VERSION := 1
const _PROVENANCE_KEYS: Array[String] = ["child_id", "child_kind", "ordinal", "parent_receipt_id", "schema_version", "source_ids"]

## Duplicated from DesktopIdentityNonceIssuer.CHILD_KINDS (plan line 537) for the SAME reason
## `_child_id()` below duplicates that file's preimage formula rather than importing it: this is
## domain layer and must not depend on the application-layer issuer. Kept byte-for-byte identical
## by `test_the_remappers_duplicated_child_kinds_equal_the_real_issuers_child_kinds_exactly` in
## tests/unit/test_desktop_continuation_remapper.gd, which loads the REAL issuer and compares this
## list against its own CHILD_KINDS member-for-member, in order.
const _CHILD_KINDS: Array[String] = [
	"schedule_entry", "schedule_commit", "day7_schedule_provenance", "empty_schedule_done",
	"contact_source", "hospital_resolution", "condition_hospital_stage", "condition_hospital_retirement",
	"hospital_miss", "sylvia_hospital_witness",
	"day_resolution_stage", "board_command", "board_start", "shop_quote", "desktop_action",
	"causal_sequence", "condition", "board_fate", "destination_intent", "notification_intent",
	"continuation_operation", "warning", "navigation", "terminal_intent", "action_consequence",
]

## Registration seam (bead addendum 9). `handled=true` rows are implemented in `_remap_board()`/
## `_remap_consequence()` below; `handled=false` rows are deliberately deferred, with `reason`
## explaining why, per the scoping above.
const _REMAP_TABLE: Array[Dictionary] = [
	{"path": "desktop.board.identity", "handled": true},
	{"path": "desktop.board.command_receipts", "handled": true},
	{"path": "desktop.board.terminal_receipts", "handled": true},
	{"path": "desktop.consequence.causal_day_instance+receipt", "handled": true},
	{"path": "desktop.consequence.pending.transaction_id+receipt", "handled": true},
	{"path": "desktop.consequence.pending.source_commit_receipt_id+provenance", "handled": true},
	{"path": "desktop.consequence.pending.recovery_payload", "handled": true},
	{"path": "desktop.consequence.pending.admission_checkpoint_receipt", "handled": false,
		"reason": "content-hash-immutable; remapping requires rewriting the on-disk consequence checkpoint document"},
	{"path": "desktop.consequence.pending.checkpoint_receipt", "handled": false,
		"reason": "see admission_checkpoint_receipt"},
	{"path": "desktop.consequence.pending.destination_intent", "handled": false,
		"reason": "no frozen member shape exists yet"},
	{"path": "desktop.consequence.pending.notification_intent", "handled": false,
		"reason": "no frozen member shape exists yet"},
	{"path": "desktop.consequence.outbox.*.provenance/consumer", "handled": false,
		"reason": "no frozen member shape exists yet"},
	{"path": "desktop.consequence.shop_ledger", "handled": true},
	# Amendment Plan 03 Task 4 (dwm-oyo.3) Step 4: the twelve v5 regions this remapper is
	# responsible for, every one of them implemented below. The walkers are `_remap_schedule_view()`
	# (the first six rows plus the recovery-payload row) and `_remap_lifecycle()` (the last five).
	# `lifecycle.condition_hospital_history` is `handled: true` because its handling IS byte
	# identity: `_validate_condition_hospital_history()` duplicates the region and checks each
	# record (nonblank key, exact member set, issuer token, completed-plan digest, retirement
	# resolution id) instead of rewriting a single byte of it -- an immutable region that is proved
	# unmutated is handled, not deferred, and a `reason` here would claim a gap that does not exist.
	{"path": "schedule_view.causal_day_instance", "handled": true},
	{"path": "schedule_view.pending_warning.opened_by_transaction_id+receipt", "handled": true},
	{"path": "schedule_view.pending_warning.activation_id+provenance", "handled": true},
	{"path": "schedule_view.pending_warning.attempt_receipts", "handled": true},
	{"path": "schedule_view.consumed_warning_receipts", "handled": true},
	{"path": "schedule_view.condition_departure_receipts", "handled": true},
	{"path": "lifecycle.active_condition_hospital_plan.transaction_id+receipt", "handled": true},
	{"path": "lifecycle.active_condition_hospital_plan.stages.*.stage_key+identity+receipt", "handled": true},
	{"path": "lifecycle.active_condition_hospital_plan.destination_record", "handled": true},
	{"path": "lifecycle.condition_hospital_history", "handled": true},
	{"path": "lifecycle.terminal_intent_handoff", "handled": true},
	{"path": "desktop.consequence.pending.recovery_payload.schedule_view_before+after", "handled": true},
]


## A selected Load replaces the live causal pair, but an in-flight Schedule scene retains its
## frozen plan/start/command ancestry. Derive only the future allocator source from the persisted
## restore proof. This pure helper returns an issuer REQUEST; it never invents an accepted receipt.
## The application caller supplies an authoritative captured root and uses the retained real issuer.
static func schedule_day_advance_source(lifecycle: Dictionary, root_document: Dictionary) -> Dictionary:
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if not plan is Dictionary or not plan.get("day_resolution_start_receipt") is Dictionary:
		return _fail(&"day_advance_source_unavailable", "a persisted Schedule start is required", {})
	var validated: Dictionary = preload("res://scripts/domain/run/DayResolutionPlan.gd").from_dict(plan)
	if not validated.get("ok", false): return validated
	var day := int(lifecycle.get("day", 0))
	var start: Dictionary = plan.day_resolution_start_receipt
	if day < 1 or day > 6 or int(plan.source_day) != day or int(start.get("source_day", 0)) != day:
		return _fail(&"day_advance_source_conflict", "the pending increment owns the current source day", {})
	var receipts: Dictionary = root_document.get("receipts", {})
	var original_root: Dictionary = plan.resolution_issuer_receipt
	if receipts.get(str(original_root.get("receipt_id", ""))) != original_root:
		return _fail(&"day_advance_source_unverified", "the original resolution root is not durable", {})
	var start_provenance: Dictionary = start.receipt_provenance
	var original_child := _verified_schedule_start_child(original_root, start_provenance)
	if not original_child.get("ok", false): return original_child
	if str(start.get("receipt_id", "")) != str(start_provenance.child_id):
		return _fail(&"day_advance_source_unverified", "the original start identity disagrees", {})
	var bound_fields := {"role": "day_resolution.start", "resolution_id": str(plan.resolution_id),
		"source_day": int(plan.source_day), "causal_day_instance": str(start.causal_day_instance),
		"schedule_commit_receipt_id": start.get("schedule_commit_receipt_id"),
		"board_fate_receipt_id": start.get("board_fate_receipt_id"),
		"schedule_entry_ids": start.get("schedule_entry_ids")}
	for key: String in bound_fields:
		var encoded: Dictionary = _CANONICAL_JSON.stringify(bound_fields[key])
		if not encoded.get("ok", false) or not (key + "=" + str(encoded.value)) in start_provenance.source_ids:
			return _fail(&"day_advance_source_unverified", "the original start does not bind " + key, {})
	var current_receipt: Dictionary = lifecycle.get("causal_day_instance_issuer_receipt", {})
	if receipts.get(str(current_receipt.get("receipt_id", ""))) != current_receipt \
			or str(current_receipt.get("token", "")) != str(lifecycle.get("causal_day_instance", "")) \
			or str(current_receipt.get("purpose", "")) != "causal_day_instance":
		return _fail(&"day_advance_source_unverified", "the current causal pair is not durable", {})
	if str(start.causal_day_instance) == str(lifecycle.causal_day_instance):
		return {"ok": true, "value": {"source_resolution_receipt": {
			"receipt_id": str(start.receipt_id), "provenance": start_provenance.duplicate(true)}}}
	var proof: Variant = lifecycle.get("restore_provenance")
	if not proof is Dictionary:
		return _fail(&"day_advance_source_conflict", "changed causal identity requires its restore proof", {})
	var allocation: Variant = root_document.get("allocation_receipts", {}).get(str(proof.get("restore_transaction_id", "")))
	if not allocation is Dictionary or str(allocation.get("kind", "")) != "restore":
		return _fail(&"day_advance_restore_unverified", "the restore allocation is not durable", {})
	for key: String in ["run_id", "branch_id", "desktop_timeline_generation", \
			"causal_day_instance", "causal_day_instance_issuer_receipt"]:
		if allocation.get(key) != lifecycle.get(key):
			return _fail(&"day_advance_restore_unverified", "the restore allocation does not own " + key, {})
	var restore_request: Dictionary = allocation.request
	var restore_root: Dictionary = restore_request.transaction_issuer_receipt
	if receipts.get(str(restore_root.get("receipt_id", ""))) != restore_root \
			or str(restore_root.get("token", "")) != str(proof.get("restore_transaction_id", "")) \
			or str(proof.get("identity_allocation_receipt_id", "")) != str(restore_root.get("receipt_id", "")) \
			or restore_request.get("source_desktop_timeline_generation") != proof.get("source_desktop_timeline_generation") \
			or str(proof.get("transaction_remap_sha256", "")) != _canonical_sha256(allocation.transaction_remap):
		return _fail(&"day_advance_restore_unverified", "restore provenance is not the committed allocation", {})
	var source_found := false
	for receipt: Dictionary in receipts.values():
		if str(receipt.get("purpose", "")) == "causal_day_instance" \
				and str(receipt.get("token", "")) == str(proof.get("source_causal_day_instance", "")) \
				and int(receipt.get("counter", -1)) == int(proof.get("source_issuer_observed_counter", -2)):
			source_found = true
			break
	if not source_found:
		return _fail(&"day_advance_restore_unverified", "restore source causal receipt is not durable", {})
	var remap_sources: Array = allocation.transaction_remap.keys()
	remap_sources.sort()
	var remap_child := _child_id(restore_root, "continuation_operation", 0, remap_sources)
	if not remap_child.get("ok", false): return remap_child
	var expected_proof := {"schema_version": CHILD_SCHEMA_VERSION,
		"parent_receipt_id": str(restore_root.receipt_id), "child_kind": "continuation_operation",
		"ordinal": 0, "source_ids": remap_sources, "child_id": str(remap_child.value)}
	if proof.get("remap_receipt_provenance") != expected_proof \
			or str(proof.get("remap_receipt_id", "")) != str(remap_child.value):
		return _fail(&"day_advance_restore_unverified", "restore remap child is not reproducible", {})
	var source := {}
	for key: String in ["run_id", "branch_id", "desktop_timeline_generation", "day", \
			"causal_day_instance", "causal_day_instance_issuer_receipt"]:
		source[key] = lifecycle[key]
	var source_ids: Array = ["role=day_resolution.advance_continuation",
		"original_start_sha256=" + _canonical_sha256(start),
		"restore_provenance_sha256=" + _canonical_sha256(proof),
		"source_identity_sha256=" + _canonical_sha256(source)]
	source_ids.sort()
	return {"ok": true, "value": {"derivation_request": {
		"parent_receipt_id": str(original_root.receipt_id), "child_kind": "day_resolution_stage",
		"ordinal": 0, "source_ids": source_ids}}}

## Nonwired scene successor. `root_document` is the authoritative captured issuer root;
## `bundle` is trusted registration. `durable_source.document_text` MUST be confirmed
## save-owner readback, not caller-authored JSON. This pure helper proves content binding,
## never disk origin, save-schema admission, native custody or an executed checkpoint.
## The existing Save8 validator is intentionally not widened by this domain helper.
static func scene_day_advance_source(lifecycle: Dictionary, command_receipts: Dictionary,
		bundle: Dictionary, root_document: Dictionary, durable_source: Dictionary) -> Dictionary:
	var event := preload("res://scripts/domain/narrative/SceneEventContract.gd")
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if typeof(lifecycle.get("state")) != TYPE_STRING or lifecycle.state != "PLAYING" \
			or not _scene_source_plan_valid(plan):
		return _scene_source_failure("an admitted outstanding scene advance is required")
	var current := _scene_source_identity(lifecycle)
	var original: Dictionary = plan.source.identity
	if not _scene_identity_valid(current, root_document) or not _scene_identity_valid(original, root_document):
		return _scene_source_failure("source identities must have durable causal receipts")
	var command_id: String = plan.source.event_command_id
	var accepted: Variant = command_receipts.get(command_id)
	if not accepted is Dictionary or not accepted.get("scene_event") is Dictionary:
		return _scene_source_failure("the canonical command map must retain original acceptance")
	var saved: Dictionary = accepted.scene_event
	if not saved.get("semantic") is Dictionary or not saved.get("reading_anchor") is Dictionary \
			or not saved.get("result") is Dictionary:
		return _scene_source_failure("original acceptance shape")
	var envelope: Dictionary = saved.semantic.duplicate(true)
	if envelope.has("playback_token"):
		return _scene_source_failure("saved semantic includes live authority")
	envelope["playback_token"] = "scene.source.validation"
	var original_request: Dictionary = event.scene_completion_request(envelope, saved.reading_anchor, bundle)
	if not original_request.get("ok", false): return original_request
	var rebuilt: Dictionary = event.make_scene_receipt(envelope, saved.reading_anchor, saved.result, bundle)
	if not rebuilt.get("ok", false): return rebuilt
	if not _scene_exact_equal(accepted, rebuilt.value) or envelope.command_id != command_id:
		return _scene_source_failure("original completion is not reproducible")
	var event_root: Dictionary = envelope.issuer_receipt
	if not _scene_root_receipt(event_root, "transaction_id", root_document) or event_root.token != command_id:
		return _scene_source_failure("original event root is not durable")
	for key: String in ["run_id", "branch_id", "causal_day_instance"]:
		if envelope.source[key] != original[key]:
			return _scene_source_failure("original event does not own " + key)
	var readback := _scene_source_readback(durable_source, plan, command_receipts)
	if not readback.get("ok", false): return readback
	var selected: Dictionary = readback.value.identity
	if not _scene_identity_valid(selected, root_document):
		return _scene_source_failure("saved source identity is not durable")
	var completion: Dictionary = saved.result.resolution_receipt
	if _scene_exact_equal(current, original):
		if not _scene_exact_equal(selected, current):
			return _scene_source_failure("original source checkpoint identity differs")
		return {"ok": true, "value": {"source_resolution_receipt": completion.duplicate(true)}}
	if _scene_exact_equal(selected, current) and not _scene_exact_equal(
			readback.value.restore_provenance, lifecycle.get("restore_provenance")):
		return _scene_source_failure("saved continuation provenance differs")
	var restored := _scene_restore_source(lifecycle, current, selected, root_document)
	if not restored.get("ok", false): return restored
	var projections := {
		"original_completion_sha256": _canonical_sha256(completion),
		"restore_provenance_sha256": _canonical_sha256(lifecycle.restore_provenance),
		"role": "scene_day.advance_continuation",
		"source_identity_sha256": _canonical_sha256(current),
	}
	var source_ids: Array = []
	for key: String in projections: source_ids.append(_p(key, projections[key]))
	source_ids.sort()
	return {"ok": true, "value": {"derivation_request": {
		"parent_receipt_id": event_root.receipt_id, "child_kind": "scene_day_completion",
		"ordinal": 1, "source_ids": source_ids}}}


static func _scene_source_plan_valid(plan: Variant) -> bool:
	var event := preload("res://scripts/domain/narrative/SceneEventContract.gd")
	if not event._json_data(plan) or not event._keys(plan, ["kind", "schema_version", "source", "stages"]): return false
	if plan.kind != "scene_transition" or typeof(plan.schema_version) != TYPE_INT or plan.schema_version != 1:
		return false
	if not event._keys(plan.source, ["event_command_id", "identity"]) \
			or not event._id(plan.source.event_command_id) or not plan.source.identity is Dictionary:
		return false
	if not plan.stages is Array or plan.stages.size() != 3: return false
	var stage_ids := ["checkpoint_outcomes", "advance_day", "enter_scene"]
	var transactions := {}
	for index in range(3):
		var stage: Variant = plan.stages[index]
		if not event._keys(stage, ["stage_id", "transaction_id", "state", "receipt"]): return false
		if stage.stage_id != stage_ids[index] or not event._id(stage.transaction_id) \
				or transactions.has(stage.transaction_id): return false
		transactions[stage.transaction_id] = true
		if index == 0:
			if stage.state != "completed" or not event._keys(stage.receipt, ["stage_id", "result"]): return false
			if stage.receipt.stage_id != stage.stage_id \
					or not event._keys(stage.receipt.result, ["checkpoint_id"]) \
					or not event._id(stage.receipt.result.checkpoint_id): return false
		else:
			if stage.receipt != null or typeof(stage.state) != TYPE_STRING: return false
			if index == 1 and stage.state not in ["pending", "active"]: return false
			if index == 2 and stage.state != "pending": return false
	return true


static func _scene_source_identity(lifecycle: Dictionary) -> Dictionary:
	var identity := {}
	for key: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance",
			"causal_day_instance_issuer_receipt"]:
		if not lifecycle.has(key): return {}
		identity[key] = lifecycle[key]
	return identity


static func _scene_identity_valid(identity: Dictionary, root: Dictionary) -> bool:
	var event := preload("res://scripts/domain/narrative/SceneEventContract.gd")
	if not event._json_data(identity) or not event._keys(identity, ["run_id", "branch_id", "desktop_timeline_generation",
			"causal_day_instance", "causal_day_instance_issuer_receipt"]): return false
	for key: String in ["run_id", "branch_id", "causal_day_instance"]:
		if not event._id(identity[key]): return false
	if typeof(identity.desktop_timeline_generation) != TYPE_INT or identity.desktop_timeline_generation < 0:
		return false
	return _scene_root_receipt(identity.causal_day_instance_issuer_receipt, "causal_day_instance", root) \
		and identity.causal_day_instance_issuer_receipt.token == identity.causal_day_instance


static func _scene_root_receipt(receipt: Variant, purpose: String, root: Dictionary) -> bool:
	var event := preload("res://scripts/domain/narrative/SceneEventContract.gd")
	if not event._json_data(receipt) or not event._keys(receipt, ["counter", "namespace", "numeric_value", "purpose", "receipt_id", "token"]): return false
	if typeof(receipt.counter) != TYPE_INT or receipt.counter < 1 or receipt.purpose != purpose \
			or typeof(receipt.namespace) != TYPE_STRING or receipt.namespace != root.get("namespace") \
			or not event._id(receipt.receipt_id) or not event._id(receipt.token): return false
	if purpose in ["transaction_id", "causal_day_instance"] and receipt.numeric_value != null: return false
	var receipts: Variant = root.get("receipts")
	return receipts is Dictionary and _scene_exact_equal(receipts.get(receipt.receipt_id), receipt)


static func _scene_source_readback(durable: Dictionary, plan: Dictionary, commands: Dictionary) -> Dictionary:
	var event := preload("res://scripts/domain/narrative/SceneEventContract.gd")
	if not event._keys(durable, ["document_text", "locator"]) or typeof(durable.document_text) != TYPE_STRING:
		return _scene_source_failure("confirmed checkpoint readback bytes are required")
	var locator: Variant = durable.locator
	if not event._keys(locator, ["slot_id", "bundle_id", "checkpoint_id", "document_sha256"]):
		return _scene_source_failure("checkpoint locator shape")
	for key: String in locator:
		if typeof(locator[key]) != TYPE_STRING or locator[key].is_empty():
			return _scene_source_failure("checkpoint locator types")
	if locator.slot_id not in ["autosave", "quick"] and not locator.slot_id.begins_with("slot:"):
		return _scene_source_failure("checkpoint locator slot")
	var parsed: Dictionary = preload("res://scripts/validation/StrictJson.gd").parse_object(durable.document_text)
	if not parsed.get("ok", false): return parsed
	var document: Dictionary = parsed.value
	var keys := ["schema_version", "kind", "slot_id", "save_reason", "current_snapshot", "recovery_journal"]
	if document.has("saved_time"): keys.append("saved_time")
	if not event._keys(document, keys) or typeof(document.schema_version) != TYPE_INT \
			or not document.recovery_journal is Array:
		return _scene_source_failure("checkpoint document envelope")
	if typeof(document.kind) != TYPE_STRING or document.kind not in ["autosave", "quick", "slot"]:
		return _scene_source_failure("checkpoint document kind")
	if document.kind == "slot":
		if typeof(document.slot_id) != TYPE_INT or document.slot_id < 1 or document.slot_id > 7:
			return _scene_source_failure("checkpoint save slot")
	elif document.slot_id != null:
		return _scene_source_failure("automatic/quick save slot must be null")
	if typeof(document.save_reason) != TYPE_STRING:
		return _scene_source_failure("checkpoint save reason type")
	if (document.kind == "slot" and document.save_reason != "manual") \
			or (document.kind == "quick" and document.save_reason != "quick") \
			or (document.kind == "autosave" and document.save_reason not in [
				"automatic", "day_start", "ending", "pre_board", "logout"]):
		return _scene_source_failure("checkpoint save reason")
	var expected_slot: String = "slot:" + str(document.slot_id) if document.kind == "slot" else str(document.kind)
	if expected_slot != locator.slot_id: return _scene_source_failure("checkpoint document locator mismatch")
	var candidates: Array = [document.current_snapshot]
	candidates.append_array(document.recovery_journal)
	var selected := {}
	for candidate: Variant in candidates:
		if not event._keys(candidate, ["checkpoint_kind", "snapshot"]) or not candidate.snapshot is Dictionary:
			return _scene_source_failure("checkpoint bundle shape")
		if candidate.snapshot.get("checkpoint_id") == locator.checkpoint_id:
			if not selected.is_empty(): return _scene_source_failure("ambiguous checkpoint locator")
			selected = candidate
	if selected.is_empty() or selected.checkpoint_kind != "day_resolution_stage" \
			or _canonical_sha256(selected) != locator.bundle_id \
			or _canonical_sha256(selected.snapshot) != locator.document_sha256:
		return _scene_source_failure("checkpoint content binding")
	var snapshot: Dictionary = selected.snapshot
	if not snapshot.get("lifecycle") is Dictionary or not snapshot.get("command_receipts") is Dictionary:
		return _scene_source_failure("checkpoint source owners missing")
	if snapshot.lifecycle.get("state") != "PLAYING":
		return _scene_source_failure("checkpoint source is not playing")
	var saved_plan: Variant = snapshot.lifecycle.get("active_resolution_plan")
	if not _scene_source_plan_valid(saved_plan) or not _scene_exact_equal(snapshot.command_receipts, commands):
		return _scene_source_failure("checkpoint source owners differ")
	var comparable: Dictionary = saved_plan.duplicate(true)
	# Advancing an already-durable source may mark the stage active before retry.
	# No semantic field or other stage may differ from the committed source.
	if comparable.stages[1].state == "active" and plan.stages[1].state == "pending":
		return _scene_source_failure("checkpoint advance state cannot rewind")
	comparable.stages[1].state = plan.stages[1].state
	if not _scene_exact_equal(comparable, plan) \
			or plan.stages[0].receipt.result.checkpoint_id != locator.checkpoint_id:
		return _scene_source_failure("checkpoint does not prove completed outcomes")
	return {"ok": true, "value": {"identity": _scene_source_identity(snapshot.lifecycle),
		"restore_provenance": snapshot.lifecycle.get("restore_provenance")}}


static func _scene_restore_source(lifecycle: Dictionary, current: Dictionary,
		selected: Dictionary, root: Dictionary) -> Dictionary:
	var event := preload("res://scripts/domain/narrative/SceneEventContract.gd")
	var proof: Variant = lifecycle.get("restore_provenance")
	if not event._json_data(proof) or not event._keys(proof, ["identity_allocation_receipt_id", "remap_receipt_id", "remap_receipt_provenance",
			"restore_transaction_id", "source_branch_id", "source_causal_day_instance",
			"source_desktop_timeline_generation", "source_issuer_observed_counter", "transaction_remap_sha256"]):
		return _scene_source_failure("changed identity requires exact committed restore provenance")
	for key: String in proof:
		if key == "remap_receipt_provenance": continue
		if key in ["source_desktop_timeline_generation", "source_issuer_observed_counter"]:
			if typeof(proof[key]) != TYPE_INT or proof[key] < 0: return _scene_source_failure("restore provenance integer")
		elif typeof(proof[key]) != TYPE_STRING or proof[key].is_empty():
			return _scene_source_failure("restore provenance text")
	var allocations: Variant = root.get("allocation_receipts")
	if not allocations is Dictionary: return _scene_source_failure("restore allocation map missing")
	var allocation: Variant = allocations.get(proof.restore_transaction_id)
	if not allocation is Dictionary or allocation.get("kind") != "restore" \
			or not allocation.get("request") is Dictionary or not allocation.get("transaction_remap") is Dictionary:
		return _scene_source_failure("restore allocation missing")
	for key: String in current:
		if not _scene_exact_equal(current[key], allocation.get(key)):
			return _scene_source_failure("restore allocation does not own " + key)
	var request: Dictionary = allocation.request
	if request.get("kind") != "restore" or request.get("existing_run_id") != current.run_id:
		return _scene_source_failure("restore request does not own the current Run")
	var restore_root: Variant = request.get("transaction_issuer_receipt")
	if not _scene_root_receipt(restore_root, "transaction_id", root) \
			or restore_root.token != proof.restore_transaction_id \
			or request.get("transaction_id") != proof.restore_transaction_id \
			or proof.identity_allocation_receipt_id != restore_root.receipt_id \
			or not _scene_exact_equal(request.get("source_desktop_timeline_generation"), proof.source_desktop_timeline_generation) \
			or proof.transaction_remap_sha256 != _canonical_sha256(allocation.transaction_remap):
		return _scene_source_failure("restore request/provenance binding")
	var source_found := false
	for receipt: Variant in root.receipts.values():
		if _scene_root_receipt(receipt, "causal_day_instance", root) \
				and receipt.token == proof.source_causal_day_instance and receipt.counter == proof.source_issuer_observed_counter:
			source_found = true
			break
	if not source_found: return _scene_source_failure("restore source receipt is not durable")
	# Readback may be the selected source or a checkpoint made after the restore.
	# The selected source can itself be a continuation; never compare it to I0.
	if not _scene_exact_equal(selected, current):
		if selected.run_id != current.run_id or selected.branch_id != proof.source_branch_id \
				or selected.desktop_timeline_generation != proof.source_desktop_timeline_generation \
				or selected.causal_day_instance != proof.source_causal_day_instance \
				or selected.causal_day_instance_issuer_receipt.counter != proof.source_issuer_observed_counter:
			return _scene_source_failure("checkpoint is not this restore's selected source")
	var source_ids: Array = allocation.transaction_remap.keys()
	for source: Variant in source_ids:
		if typeof(source) != TYPE_STRING or source.is_empty(): return _scene_source_failure("remap source identity")
	source_ids.sort()
	var child := _child_id(restore_root, "continuation_operation", 0, source_ids)
	if not child.get("ok", false): return child
	var expected := {"schema_version": CHILD_SCHEMA_VERSION, "parent_receipt_id": restore_root.receipt_id,
		"child_kind": "continuation_operation", "ordinal": 0, "source_ids": source_ids, "child_id": child.value}
	if not _scene_exact_equal(proof.remap_receipt_provenance, expected) or proof.remap_receipt_id != child.value:
		return _scene_source_failure("restore remap proof is not reproducible")
	return {"ok": true}


static func _scene_exact_equal(actual: Variant, expected: Variant) -> bool:
	var event := preload("res://scripts/domain/narrative/SceneEventContract.gd")
	return event._same_types(actual, expected) and actual == expected


static func _scene_source_failure(message: String) -> Dictionary:
	return _fail(&"scene_day_advance_source_invalid", message, {})


static func _verified_schedule_start_child(parent: Dictionary, provenance: Dictionary) -> Dictionary:
	var keys: Array = provenance.keys()
	keys.sort()
	var expected: Array = _PROVENANCE_KEYS.duplicate()
	expected.sort()
	if keys != expected or int(provenance.get("schema_version", 0)) != CHILD_SCHEMA_VERSION \
			or str(provenance.get("child_kind", "")) != "day_resolution_stage" \
			or str(provenance.get("parent_receipt_id", "")) != str(parent.get("receipt_id", "")):
		return _fail(&"day_advance_source_unverified", "original start provenance shape", {})
	var sources: Dictionary = _validate_sorted_unique_nonblank(provenance.source_ids)
	if not sources.get("ok", false): return sources
	var child := _child_id(parent, "day_resolution_stage", int(provenance.ordinal), provenance.source_ids)
	if not child.get("ok", false): return child
	if str(child.value) != str(provenance.child_id):
		return _fail(&"day_advance_source_unverified", "original start child is not reproducible", {})
	return {"ok": true}

## Every root transaction id this snapshot's rewindable (board command/terminal ledger, the one live
## consequence pending transaction, and the v5 ScheduleView/lifecycle roots C1-C5) structures
## currently reference. Sorted, unique.
static func collect_rewindable_transaction_ids(snapshot: Dictionary) -> Dictionary:
	var desktop_check := _require_desktop(snapshot)
	if not desktop_check.get("ok", false):
		return desktop_check
	var desktop: Dictionary = desktop_check["value"]
	var board: Dictionary = desktop["board"]
	var consequence: Dictionary = desktop["consequence"]
	var ids: Dictionary = {}
	for key: String in ["command_receipts", "terminal_receipts"]:
		var receipts: Variant = board.get(key, {})
		if typeof(receipts) == TYPE_DICTIONARY:
			for transaction_id: Variant in (receipts as Dictionary).keys():
				ids[str(transaction_id)] = true
	var pending: Variant = consequence.get("pending")
	if typeof(pending) == TYPE_DICTIONARY:
		var transaction_id: Variant = (pending as Dictionary).get("transaction_id")
		if typeof(transaction_id) == TYPE_STRING and not str(transaction_id).strip_edges().is_empty():
			ids[str(transaction_id)] = true
	var day7: Dictionary = _pending_day7_terminal(consequence)
	if not day7.get("ok", false): return day7
	if not day7.value.is_empty(): ids[str(day7.value.action_receipt.transaction_id)] = true
	var view: Variant = snapshot.get("schedule_view")
	if typeof(view) == TYPE_DICTIONARY:
		var view_census := _collect_view_roots(view as Dictionary, ids)
		if not view_census.get("ok", false):
			return view_census
	var lifecycle: Variant = snapshot.get("lifecycle")
	if typeof(lifecycle) == TYPE_DICTIONARY:
		_collect_lifecycle_roots(lifecycle as Dictionary, ids)
	var sorted_ids: Array = ids.keys()
	sorted_ids.sort()
	return {"ok": true, "code": &"ok", "value": {"transaction_ids": sorted_ids}, "receipt": {}}


## `identity_allocation_bundle` here is the RAW continuation-allocation bundle (brief lines
## 259-283: transaction_id/transaction_issuer_receipt/branch_id/desktop_timeline_generation/
## causal_day_instance/causal_day_instance_issuer_receipt/transaction_remap), NOT yet enriched with
## the remap_receipt_id/remap_receipt_provenance this method itself produces --
## DesktopIdentityAllocationRestoreParticipant merges this method's receipt onto that bundle before
## handing the ENRICHED bundle to RunLifecycle.prepare_continuation_remap() and the consequence/
## board participants.
##
## Composition order is load-bearing: the consequence walk (which remaps the two admission-ready
## recovery-payload views) runs BEFORE the ScheduleView walk (whose condition-departure ledger is
## checked against those remapped views), which runs BEFORE the lifecycle walk (whose
## condition-Hospital destination record is compared against the already-remapped live outbox).
static func prepare(snapshot: Dictionary, restore_transaction_id: String,
		identity_allocation_bundle: Dictionary) -> Dictionary:
	if restore_transaction_id.strip_edges().is_empty():
		return _fail(&"invalid_restore_transaction_id", "restore_transaction_id must be nonblank", {})
	var bundle_check := _require_bundle_keys(identity_allocation_bundle)
	if not bundle_check.get("ok", false):
		return bundle_check
	var desktop_check := _require_desktop(snapshot)
	if not desktop_check.get("ok", false):
		return desktop_check
	var desktop: Dictionary = desktop_check["value"]

	var transaction_remap: Dictionary = identity_allocation_bundle["transaction_remap"]
	var remap_check := _validate_transaction_remap_matches_snapshot(snapshot, transaction_remap)
	if not remap_check.get("ok", false):
		return remap_check

	var owners := _source_identity_owners(desktop, snapshot)
	var board_result := _remap_board(desktop["board"], identity_allocation_bundle, transaction_remap)
	if not board_result.get("ok", false):
		return board_result
	var consequence_result := _remap_consequence(desktop["consequence"], identity_allocation_bundle,
		transaction_remap, owners)
	if not consequence_result.get("ok", false):
		return consequence_result
	var day7: Dictionary = _pending_day7_terminal(desktop["consequence"])
	if not day7.get("ok", false): return day7
	if not day7.value.is_empty():
		var terminal: Dictionary = _remap_day7_terminal(day7.value, desktop["consequence"],
			snapshot.get("lifecycle", {}), identity_allocation_bundle, transaction_remap)
		if not terminal.get("ok", false): return terminal
		consequence_result.value["outbox"]["hospital"] = terminal.value

	var remapped_snapshot: Dictionary = snapshot.duplicate(true)
	var remapped_desktop: Dictionary = desktop.duplicate(true)
	remapped_desktop["board"] = board_result["value"]
	remapped_desktop["consequence"] = consequence_result["value"]
	remapped_snapshot["desktop"] = remapped_desktop

	if snapshot.has("schedule_view"):
		var source_view: Variant = snapshot["schedule_view"]
		if typeof(source_view) != TYPE_DICTIONARY:
			return _fail(&"remap_schedule_view_invalid", "schedule_view must be an object when present", {})
		var view_context := _view_context(desktop, remapped_desktop, transaction_remap, owners)
		var view_result := _remap_schedule_view(source_view as Dictionary,
			identity_allocation_bundle, transaction_remap, view_context)
		if not view_result.get("ok", false):
			return view_result
		remapped_snapshot["schedule_view"] = view_result["value"]

	var source_lifecycle: Variant = snapshot.get("lifecycle")
	if typeof(source_lifecycle) == TYPE_DICTIONARY and not (source_lifecycle as Dictionary).is_empty():
		var live_outbox: Dictionary = {}
		var outbox_value: Variant = (remapped_desktop["consequence"] as Dictionary).get("outbox")
		if typeof(outbox_value) == TYPE_DICTIONARY:
			live_outbox = outbox_value
		var lifecycle_result := _remap_lifecycle(source_lifecycle as Dictionary,
			identity_allocation_bundle, transaction_remap, live_outbox)
		if not lifecycle_result.get("ok", false):
			return lifecycle_result
		remapped_snapshot["lifecycle"] = lifecycle_result["value"]

	var source_ids: Array = transaction_remap.keys()
	source_ids.sort()
	var parent_receipt: Dictionary = identity_allocation_bundle["transaction_issuer_receipt"]
	var remap_receipt_id_check := _child_id(parent_receipt, "continuation_operation", 0, source_ids)
	if not remap_receipt_id_check.get("ok", false):
		return remap_receipt_id_check
	var remap_receipt_id: String = remap_receipt_id_check["value"]
	var remap_receipt_provenance := {
		"schema_version": CHILD_SCHEMA_VERSION,
		"parent_receipt_id": str(parent_receipt.get("receipt_id", "")),
		"child_kind": "continuation_operation",
		"ordinal": 0,
		"source_ids": source_ids,
		"child_id": remap_receipt_id,
	}
	return {"ok": true, "code": &"ok", "value": {
		"snapshot": remapped_snapshot,
		"remap_receipt_id": remap_receipt_id,
		"remap_receipt_provenance": remap_receipt_provenance,
	}, "receipt": remap_receipt_provenance.duplicate(true)}


## Independent second opinion: re-derives the implied transaction map purely by diffing `source`
## against `candidate` (board command/terminal receipt key correspondence by insertion order, the
## consequence pending transaction_id, and the v5 C1-C5 roots by structural position), requires that
## implied map to be internally consistent (no missing/extra/multiply-mapped/dangling/unsorted-set
## entries), checks the candidate's own warning index-key laws, then rebuilds an equivalent raw
## bundle from those facts and requires `prepare()` against it to reproduce `candidate`
## byte-for-byte.
static func validate_remap(source: Dictionary, candidate: Dictionary) -> Dictionary:
	var source_desktop_check := _require_desktop(source)
	if not source_desktop_check.get("ok", false):
		return source_desktop_check
	var candidate_desktop_check := _require_desktop(candidate)
	if not candidate_desktop_check.get("ok", false):
		return candidate_desktop_check
	var source_desktop: Dictionary = source_desktop_check["value"]
	var candidate_desktop: Dictionary = candidate_desktop_check["value"]

	var derived := _derive_transaction_map(source, candidate, source_desktop, candidate_desktop)
	if not derived.get("ok", false):
		return derived
	var transaction_remap: Dictionary = derived["value"]

	var source_identity: Variant = (source_desktop["board"] as Dictionary).get("identity", {})
	var candidate_identity: Variant = (candidate_desktop["board"] as Dictionary).get("identity", {})
	var pending_day7: Dictionary = _pending_day7_terminal(source_desktop["consequence"])
	if not pending_day7.get("ok", false): return pending_day7
	if not pending_day7.value.is_empty():
		if not source_identity is Dictionary or source_identity.is_empty():
			source_identity = source.get("lifecycle", {})
		if not candidate_identity is Dictionary or candidate_identity.is_empty():
			candidate_identity = candidate.get("lifecycle", {})
	if typeof(source_identity) != TYPE_DICTIONARY or typeof(candidate_identity) != TYPE_DICTIONARY:
		return _fail(&"remap_identity_missing", "both source and candidate must carry a board identity to validate a remap", {})

	var key_laws := _candidate_warning_key_error(candidate)
	if not key_laws.get("ok", false):
		return key_laws

	var candidate_consequence: Dictionary = candidate_desktop["consequence"]
	var pending: Variant = candidate_consequence.get("pending")
	var receipt_source: Dictionary = {}
	if typeof(pending) == TYPE_DICTIONARY and typeof((pending as Dictionary).get("transaction_issuer_receipt")) == TYPE_DICTIONARY:
		receipt_source = (pending as Dictionary)["transaction_issuer_receipt"]
	var rebuilt_bundle := {
		"transaction_id": str(receipt_source.get("token", "")),
		"transaction_issuer_receipt": receipt_source,
		"branch_id": str(candidate_identity.get("branch_id", "")),
		"desktop_timeline_generation": int(candidate_identity.get("desktop_timeline_generation", 0)),
		"causal_day_instance": str(candidate_consequence.get("causal_day_instance", "")),
		"causal_day_instance_issuer_receipt": candidate_consequence.get("causal_day_instance_issuer_receipt", {}),
		"transaction_remap": transaction_remap,
	}
	if receipt_source.is_empty():
		# No pending transaction survived into the candidate to anchor the remap receipt against
		# (e.g. the whole remap happened while nothing was mid-flight): fall back to any one of the
		# remapped board receipts as the anchor, matching the same "restore transaction" identity.
		for entry: Variant in transaction_remap.values():
			rebuilt_bundle["transaction_issuer_receipt"] = (entry as Dictionary).get("new_transaction_issuer_receipt", {})
			rebuilt_bundle["transaction_id"] = str((entry as Dictionary).get("new_transaction_id", ""))
			break
	var restore_transaction_id := str(rebuilt_bundle["transaction_id"])
	if restore_transaction_id.is_empty():
		return _fail(&"remap_unverifiable", "no transaction receipt is available to re-anchor the remap for validation", {})
	var reproduced := prepare(source, restore_transaction_id, rebuilt_bundle)
	if not reproduced.get("ok", false):
		return reproduced
	if (reproduced["value"] as Dictionary)["snapshot"] != candidate:
		return _fail(&"remap_not_reproducible", "the candidate is not a lawful remap of the source", {})
	return {"ok": true, "code": &"ok", "value": {"transaction_remap": transaction_remap}, "receipt": {}}


## A cleaned, pending Day 7 result is still live work. Published ending evidence is historical.
## Only this exact consumer joins the existing transaction census and pure remap proof.
static func _pending_day7_terminal(consequence: Dictionary) -> Dictionary:
	var outbox: Variant = consequence.get("outbox", {})
	if not outbox is Dictionary: return _fail(&"remap_day7_source_invalid", "outbox is malformed", {})
	var raw: Variant = outbox.get("hospital")
	if not raw is Dictionary or raw.get("consumer") != "day7_terminal" or raw.get("status") != "pending":
		return {"ok": true, "value": {}}
	var valid: Dictionary = _CONSEQUENCE.validate(consequence)
	if not valid.get("ok", false): return valid
	if consequence.get("pending") != null or raw.size() != 9:
		return _fail(&"remap_day7_source_invalid", "terminal source must be a complete cleaned outbox record", {})
	valid = _ACTION_RECEIPT.validate(raw.action_receipt)
	if not valid.get("ok", false): return valid
	return {"ok": true, "value": raw.duplicate(true)}


static func _remap_day7_terminal(record: Dictionary, consequence: Dictionary, lifecycle: Dictionary,
		bundle: Dictionary, transaction_remap: Dictionary) -> Dictionary:
	var action: Dictionary = record.action_receipt
	if lifecycle.get("state") != "PLAYING" or lifecycle.get("day") != 7:
		return _fail(&"remap_day7_source_invalid", "a pending Day 7 source requires PLAYING Day 7", {})
	for key: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance", "day"]:
		if action[key] != lifecycle.get(key):
			return _fail(&"remap_day7_source_invalid", "the terminal action names another " + key, {})
	if consequence.causal_day_instance != action.causal_day_instance or record.causal_sequence != consequence.causal_sequence:
		return _fail(&"remap_day7_source_invalid", "terminal action is not the completed causal sequence", {})
	var condition_keys: Array = record.condition_receipt.keys()
	condition_keys.sort()
	var destination_keys: Array = record.payload.keys()
	destination_keys.sort()
	if condition_keys != ["action_commit_receipt_id", "action_commit_receipt_provenance", "causal_day_instance",
		"causal_sequence", "causal_sequence_receipt_id", "causal_sequence_receipt_provenance", "condition_after",
		"danger", "day", "decision", "receipt_id", "receipt_provenance", "source_receipt_ids", "sylvia_read_receipt_id", "trigger"] \
			or destination_keys != ["accepted_unfulfilled_sources", "causal_day_instance", "day", "intent_id",
			"intent_id_provenance", "kind", "prerequisite_receipt_ids", "source_condition_receipt_id",
			"source_condition_receipt_provenance", "terminal_cause", "terminal_provenance"]:
		return _fail(&"remap_day7_source_invalid", "condition or destination has an unknown shape", {})
	if action.transaction_issuer_receipt.get("token") != action.transaction_id \
			or record.condition_receipt.condition_after != action.condition_after \
			or record.condition_receipt.danger != true or record.condition_receipt.trigger != true \
			or not action.condition_after.carried_sequela \
			or (action.condition_after.pressure < 10 and action.condition_after.health > 0) \
			or record.payload.kind != "day7_terminal" or record.payload.terminal_provenance != null \
			or record.payload.accepted_unfulfilled_sources != []:
		return _fail(&"remap_day7_source_invalid", "condition terminal facts differ from the source action", {})
	var decision := "day7_dark_alone" if bool(lifecycle.get("dark_mode", false)) else (
		"day7_sylvia_special" if record.condition_receipt.sylvia_read_receipt_id != null else "day7_hospital_alone")
	var causes := {"day7_dark_alone": "dark_mode_alone", "day7_sylvia_special": "sylvia_special", "day7_hospital_alone": "hospital_alone"}
	if record.condition_receipt.decision != decision or record.payload.terminal_cause != causes[decision]:
		return _fail(&"remap_day7_source_invalid", "terminal decision contradicts captured mode or receipted Sylvia read", {})
	var original: Dictionary = _rebuild_day7_terminal_record(record, action.transaction_issuer_receipt, lifecycle, consequence)
	if not original.get("ok", false): return original
	if original.value != record:
		return _fail(&"remap_day7_source_invalid", "source identities or prerequisite projections do not reproduce", {})
	var mapping: Variant = transaction_remap.get(action.transaction_id)
	if not mapping is Dictionary:
		return _fail(&"remap_dangling_transaction", action.transaction_id, {})
	return _rebuild_day7_terminal_record(record, mapping.new_transaction_issuer_receipt, bundle, consequence)


static func _rebuild_day7_terminal_record(record: Dictionary, root: Dictionary, identity: Dictionary,
		consequence: Dictionary) -> Dictionary:
	var mapped: Dictionary = record.duplicate(true)
	var action: Dictionary = mapped.action_receipt
	var action_sources: Variant = action.action_id_provenance.get("source_ids")
	if not action_sources is Array or action_sources.size() != 3 \
			or not action_sources.has(action.action_kind) or not action_sources.has(action.source_commit_receipt_id):
		return _fail(&"remap_day7_source_invalid", "the action's historical source ancestry is incomplete", {})
	var source_check: Dictionary = _validate_sorted_unique_nonblank(action_sources)
	if not source_check.get("ok", false): return source_check
	action.transaction_id = str(root.get("token", ""))
	action.transaction_issuer_receipt = root.duplicate(true)
	for key: String in ["branch_id", "desktop_timeline_generation", "causal_day_instance"]:
		action[key] = identity[key]
	var child: Dictionary = _mint_child(root, "desktop_action", 0, action_sources)
	if not child.get("ok", false): return child
	action.action_id = child.value.child_id
	action.action_id_provenance = child.value.provenance
	action.commit_receipt_id = child.value.child_id
	action.commit_receipt_provenance = child.value.provenance.duplicate(true)
	# The paid board/quote source is already committed history; it is not re-executed on Load.
	# The terminal action's opaque candidate digest is retained, exactly as other Tier A children.
	var sequence := {"transaction_id": action.transaction_id, "transaction_issuer_receipt": action.transaction_issuer_receipt,
		"run_id": action.run_id, "branch_id": action.branch_id, "desktop_timeline_generation": action.desktop_timeline_generation,
		"causal_day_instance": action.causal_day_instance, "source_kind": action.action_kind,
		"source_commit_receipt_id": action.commit_receipt_id, "source_commit_receipt_provenance": action.commit_receipt_provenance,
		"causal_sequence": consequence.causal_sequence, "run_revision": consequence.run_revision}
	var condition: Dictionary = mapped.condition_receipt
	condition.action_commit_receipt_id = action.commit_receipt_id
	condition.action_commit_receipt_provenance = action.commit_receipt_provenance.duplicate(true)
	condition.causal_day_instance = action.causal_day_instance
	condition.day = 7
	condition.causal_sequence = consequence.causal_sequence
	condition.causal_sequence_receipt_id = "causal_sequence_receipt." + _canonical_sha256(sequence)
	condition.causal_sequence_receipt_provenance = {"kind": "causal_sequence", "transaction_id": action.transaction_id,
		"causal_sequence": consequence.causal_sequence, "run_revision": consequence.run_revision}
	var sources: Array = [_p("action_commit_receipt_id", action.commit_receipt_id),
		_p("causal_sequence_receipt_id", condition.causal_sequence_receipt_id)]
	sources.sort()
	child = _mint_child(root, "condition", 0, sources)
	if not child.get("ok", false): return child
	condition.receipt_id = child.value.child_id
	condition.receipt_provenance = child.value.provenance
	var destination: Dictionary = mapped.payload
	destination.day = 7
	destination.causal_day_instance = action.causal_day_instance
	destination.source_condition_receipt_id = condition.receipt_id
	destination.source_condition_receipt_provenance = condition.receipt_provenance.duplicate(true)
	var prerequisites: Array = [action.commit_receipt_id, condition.receipt_id]
	prerequisites.sort()
	destination.prerequisite_receipt_ids = prerequisites
	sources = [_p("condition_receipt_id", condition.receipt_id), _p("action_commit_receipt_id", action.commit_receipt_id)]
	sources.sort()
	child = _mint_child(root, "destination_intent", 0, sources)
	if not child.get("ok", false): return child
	destination.intent_id = child.value.child_id
	destination.intent_id_provenance = child.value.provenance
	mapped.key = destination.intent_id
	mapped.provenance = destination.intent_id_provenance.duplicate(true)
	mapped.payload_hash = _canonical_sha256(destination)
	return {"ok": true, "value": mapped}


# -------------------------------------------------------------------------------------------------
# Board
# -------------------------------------------------------------------------------------------------

static func _remap_board(board: Dictionary, bundle: Dictionary, transaction_remap: Dictionary) -> Dictionary:
	var remapped: Dictionary = board.duplicate(true)
	var identity: Variant = board.get("identity")
	var new_identity: Dictionary = {}
	if typeof(identity) == TYPE_DICTIONARY and not (identity as Dictionary).is_empty():
		var remapped_identity := _IDENTITY.remap(identity, str(bundle["branch_id"]),
			int(bundle["desktop_timeline_generation"]), str(bundle["causal_day_instance"]))
		if not remapped_identity.get("ok", false):
			return remapped_identity
		new_identity = (remapped_identity["value"] as Dictionary)["identity"]
		remapped["identity"] = new_identity
	for key: String in ["command_receipts", "terminal_receipts"]:
		var receipts: Variant = board.get(key, {})
		if typeof(receipts) != TYPE_DICTIONARY:
			continue
		var rekeyed: Dictionary = {}
		for old_id: Variant in (receipts as Dictionary).keys():
			var record: Dictionary = (receipts[old_id] as Dictionary).duplicate(true)
			var mapping: Variant = transaction_remap.get(str(old_id))
			var new_id := str(old_id)
			if typeof(mapping) == TYPE_DICTIONARY:
				new_id = str((mapping as Dictionary)["new_transaction_id"])
			if record.has("identity_fingerprint") and not new_identity.is_empty():
				var fp := _IDENTITY.fingerprint(new_identity)
				if fp.get("ok", false):
					record["identity_fingerprint"] = str((fp["value"] as Dictionary)["fingerprint"])
			rekeyed[new_id] = record
		remapped[key] = rekeyed
	return {"ok": true, "code": &"ok", "value": remapped}


# -------------------------------------------------------------------------------------------------
# Consequence
# -------------------------------------------------------------------------------------------------

static func _remap_consequence(consequence: Dictionary, bundle: Dictionary,
		transaction_remap: Dictionary, owners: Dictionary) -> Dictionary:
	var remapped: Dictionary = consequence.duplicate(true)
	remapped["causal_day_instance"] = str(bundle["causal_day_instance"])
	remapped["causal_day_instance_issuer_receipt"] = (bundle["causal_day_instance_issuer_receipt"] as Dictionary).duplicate(true)
	var pending: Variant = consequence.get("pending")
	if typeof(pending) == TYPE_DICTIONARY:
		var remapped_pending := _remap_pending(pending as Dictionary, bundle, transaction_remap, owners)
		if not remapped_pending.get("ok", false):
			return remapped_pending
		remapped["pending"] = remapped_pending["value"]
	# Task 7 (dwm-p2r.32.7) registration seam filled in: shop_ledger's three members are a plain
	# purchase count and opaque HISTORICAL causal_day_instance tokens (the branch's running Supportz
	# count and completion log; none is a transaction id or an anchored child provenance), so no
	# rewrite is needed beyond the duplicate() above -- unlike board/pending's rewindable transaction
	# references, remapping a NEW branch identity never changes what already happened on past days.
	return {"ok": true, "code": &"ok", "value": remapped}


static func _remap_pending(pending: Dictionary, bundle: Dictionary, transaction_remap: Dictionary,
		owners: Dictionary) -> Dictionary:
	var remapped: Dictionary = pending.duplicate(true)
	var old_transaction_id := str(pending.get("transaction_id", ""))
	var mapping: Variant = transaction_remap.get(old_transaction_id)
	if typeof(mapping) != TYPE_DICTIONARY:
		return _fail(&"remap_dangling_transaction", "pending.transaction_id has no remap entry: " + old_transaction_id, {})
	var new_receipt: Dictionary = (mapping as Dictionary)["new_transaction_issuer_receipt"]
	remapped["transaction_id"] = str((mapping as Dictionary)["new_transaction_id"])
	remapped["transaction_issuer_receipt"] = (new_receipt as Dictionary).duplicate(true)

	var provenance: Variant = pending.get("source_commit_receipt_provenance")
	if typeof(provenance) == TYPE_DICTIONARY:
		var rederived := _rederive_anchored_child(provenance as Dictionary, new_receipt, transaction_remap)
		if not rederived.get("ok", false):
			return rederived
		remapped["source_commit_receipt_id"] = (rederived["value"] as Dictionary)["child_id"]
		remapped["source_commit_receipt_provenance"] = (rederived["value"] as Dictionary)["provenance"]

	var payload: Variant = pending.get("recovery_payload")
	if typeof(payload) == TYPE_DICTIONARY:
		# The nested payload views carry the same warning/ledger regions as the live view, anchored
		# to the same live pending root, but no payload of their own -- so they get the key and
		# provenance treatment with an EMPTY ledger-hash law (there is no inner recovery payload to
		# hash the inner ledger's two view digests against).
		var source_parent_receipt_id := ""
		var source_receipt: Variant = pending.get("transaction_issuer_receipt")
		if typeof(source_receipt) == TYPE_DICTIONARY:
			source_parent_receipt_id = str((source_receipt as Dictionary).get("receipt_id", ""))
		var nested_context: Dictionary = {
			"owners": owners,
			"source_parent_receipt_id": source_parent_receipt_id,
			"mapped_parent_receipt": new_receipt,
			"ledger_payload": {},
		}
		var remapped_payload := _remap_recovery_payload(payload as Dictionary, bundle,
			transaction_remap, nested_context)
		if not remapped_payload.get("ok", false):
			return remapped_payload
		remapped["recovery_payload"] = remapped_payload["value"]
		var hash := _canonical_sha256(remapped_payload["value"])
		if hash.is_empty():
			return _fail(&"remap_payload_not_canonicalizable", "the remapped recovery_payload is not canonically representable", {})
		remapped["recovery_payload_sha256"] = hash
	# admission_checkpoint_receipt / checkpoint_receipt: deliberately untouched (see _REMAP_TABLE).
	return {"ok": true, "code": &"ok", "value": remapped}


static func _remap_recovery_payload(payload: Dictionary, bundle: Dictionary,
		transaction_remap: Dictionary, view_context: Dictionary) -> Dictionary:
	var remapped: Dictionary = payload.duplicate(true)
	for embedded_key: String in ["action_receipt", "schedule_header"]:
		var embedded: Variant = payload.get(embedded_key)
		if typeof(embedded) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = (embedded as Dictionary).duplicate(true)
		var old_id := str(record.get("transaction_id", ""))
		var mapping: Variant = transaction_remap.get(old_id)
		if typeof(mapping) != TYPE_DICTIONARY:
			return _fail(&"remap_dangling_transaction",
				"recovery_payload.%s.transaction_id has no remap entry: %s" % [embedded_key, old_id], {})
		var new_receipt: Dictionary = (mapping as Dictionary)["new_transaction_issuer_receipt"]
		record["transaction_id"] = str((mapping as Dictionary)["new_transaction_id"])
		record["transaction_issuer_receipt"] = (new_receipt as Dictionary).duplicate(true)
		var provenance: Variant = record.get("source_commit_receipt_provenance")
		if typeof(provenance) == TYPE_DICTIONARY:
			var rederived := _rederive_anchored_child(provenance as Dictionary, new_receipt, transaction_remap)
			if not rederived.get("ok", false):
				return rederived
			record["source_commit_receipt_id"] = (rederived["value"] as Dictionary)["child_id"]
			record["source_commit_receipt_provenance"] = (rederived["value"] as Dictionary)["provenance"]
		remapped[embedded_key] = record
	# The two admission-ready frozen views (Amendment Plan 03 Task 4 Step 4): each is remapped by
	# the same walker the live view uses, and its own digest member is recomputed from the remapped
	# bytes. The enclosing recovery_payload_sha256 is recomputed by _remap_pending() afterwards, so
	# neither digest can go stale.
	for view_key: String in ["schedule_view_before", "schedule_view_after"]:
		var embedded_view: Variant = payload.get(view_key)
		if typeof(embedded_view) != TYPE_DICTIONARY:
			continue
		var walked_view := _remap_schedule_view(embedded_view as Dictionary, bundle,
			transaction_remap, view_context)
		if not walked_view.get("ok", false):
			return walked_view
		var remapped_view: Dictionary = walked_view["value"]
		remapped[view_key] = remapped_view
		var view_digest := _canonical_sha256(remapped_view)
		if view_digest.is_empty():
			return _fail(&"remap_payload_not_canonicalizable",
				"the remapped recovery_payload." + view_key + " is not canonically representable", {})
		remapped[view_key + "_sha256"] = view_digest
	return {"ok": true, "code": &"ok", "value": remapped}


## Re-derives an anchored-child id/provenance (plan line 537) under a NEW parent receipt, keeping
## the child's own kind/ordinal unchanged. Any source_ids member that is itself a real rewindable
## transaction ID is recursively remapped through `transaction_remap` (brief line 291: "recursively
## mapped/sorted source IDs") -- this branch's own GameStateDesktopBoardPort anchors its board_start
## children with source_ids=[transaction_id], a REAL transaction id, not an opaque hash, so passing
## every source_id through unchanged (the prior behavior here) silently staled that id past a
## restore. A source_id absent from transaction_remap is genuinely opaque (a content-derived hash
## with no remap entry) and passes through unchanged. The result is lexically re-sorted and
## revalidated non-blank/unique/sorted, matching derive_child()'s own precondition that source IDs
## arrive already sorted rather than being repaired by the issuer; a malformed historical record
## (unsorted, blank, or duplicated) rejects rather than being silently renormalized.
##
## This is TIER A, and the v5 walkers below reuse it unchanged for every child whose stored
## source_ids carry no remapped identity (the condition-departure receipt, the condition-Hospital
## condition/resolution receipts and stage identities). TIER B -- the warning family alone -- never
## substitutes inside a stored projection string: it REBUILDS `source_ids` from the already-remapped
## facts through `_mint_child()` and `_p()`.
static func _rederive_anchored_child(provenance: Dictionary, new_parent_receipt: Dictionary,
		transaction_remap: Dictionary) -> Dictionary:
	var keys: Array = provenance.keys()
	keys.sort()
	var expected := _PROVENANCE_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return _fail(&"remap_provenance_invalid", "unexpected provenance keys: " + str(keys), {})
	var child_kind := str(provenance["child_kind"])
	if not _CHILD_KINDS.has(child_kind):
		return _fail(&"remap_child_kind_unregistered", child_kind, {})
	var ordinal := int(provenance["ordinal"])
	var source_ids_check := _validate_sorted_unique_nonblank(provenance["source_ids"])
	if not source_ids_check.get("ok", false):
		return source_ids_check
	var source_ids: Array = source_ids_check["value"]

	var mapped_source_ids: Array = []
	for source_id: Variant in source_ids:
		var key := str(source_id)
		var mapping: Variant = transaction_remap.get(key)
		if typeof(mapping) == TYPE_DICTIONARY:
			mapped_source_ids.append(str((mapping as Dictionary)["new_transaction_id"]))
		else:
			mapped_source_ids.append(key)
	mapped_source_ids.sort()
	var mapped_check := _validate_sorted_unique_nonblank(mapped_source_ids)
	if not mapped_check.get("ok", false):
		return mapped_check

	var new_child_id_check := _child_id(new_parent_receipt, child_kind, ordinal, mapped_source_ids)
	if not new_child_id_check.get("ok", false):
		return new_child_id_check
	var new_child_id: String = new_child_id_check["value"]
	var new_provenance := {
		"schema_version": CHILD_SCHEMA_VERSION,
		"parent_receipt_id": str(new_parent_receipt.get("receipt_id", "")),
		"child_kind": child_kind,
		"ordinal": ordinal,
		"source_ids": mapped_source_ids,
		"child_id": new_child_id,
	}
	return {"ok": true, "code": &"ok", "value": {"child_id": new_child_id, "provenance": new_provenance}}


## Shared precondition/postcondition check mirroring derive_child()'s own law (plan line 487):
## source IDs must already be sorted, unique, and nonblank -- callers (and, here, historical
## persisted records) may not submit an unsorted or duplicated set for silent repair.
static func _validate_sorted_unique_nonblank(source_ids: Variant) -> Dictionary:
	if typeof(source_ids) != TYPE_ARRAY:
		return _fail(&"remap_source_ids_invalid", "source_ids must be an array", {})
	var ids: Array = (source_ids as Array).duplicate(true)
	var seen: Dictionary = {}
	var previous := ""
	for index: int in range(ids.size()):
		var value := str(ids[index])
		if value.strip_edges().is_empty():
			return _fail(&"remap_source_ids_invalid", "source_ids must be nonblank", {})
		if seen.has(value):
			return _fail(&"remap_source_ids_invalid", "source_ids must be unique", {"duplicate": value})
		seen[value] = true
		if index > 0 and value < previous:
			return _fail(&"remap_source_ids_invalid", "source_ids must already be lexically sorted", {})
		previous = value
	return {"ok": true, "value": ids}


# -------------------------------------------------------------------------------------------------
# ScheduleView (v5): the seven-key view, the warning family, and the condition-departure ledger
# -------------------------------------------------------------------------------------------------

## `view_context` carries what a view cannot see from inside itself: the source snapshot's identity
## owners (for the stored warning contexts), the SOURCE pending issuer receipt id and its MAPPED
## replacement (for the one live condition-departure entry), and the recovery payload's own two view
## digests before/after the remap (empty when the payload carries neither view, or when the view
## being walked IS one of those payload views).
static func _remap_schedule_view(view: Dictionary, bundle: Dictionary,
		transaction_remap: Dictionary, view_context: Dictionary) -> Dictionary:
	var expected_keys: Array = ["causal_day_instance", "condition_departure_receipts",
		"consumed_warning_receipts", "date_entry_seen", "day", "entries", "pending_warning"]
	var keys: Array = view.keys()
	keys.sort()
	if keys != expected_keys:
		return _fail(&"remap_schedule_view_invalid",
			"a schedule_view carries exactly the seven ScheduleViewState.VIEW_KEYS", {"keys": keys})
	var remapped: Dictionary = view.duplicate(true)
	remapped["causal_day_instance"] = str(bundle["causal_day_instance"])
	# `entries`, `date_entry_seen` and `day` carry no identity and stay byte-identical.
	var pending: Variant = view.get("pending_warning")
	if typeof(pending) == TYPE_DICTIONARY:
		var walked_pending := _remap_pending_warning(pending as Dictionary, bundle,
			transaction_remap, view_context)
		if not walked_pending.get("ok", false):
			return walked_pending
		remapped["pending_warning"] = walked_pending["value"]
	var consumed: Variant = view.get("consumed_warning_receipts")
	if typeof(consumed) == TYPE_DICTIONARY:
		var walked_consumed := _remap_consumed_warning_receipts(consumed as Dictionary, bundle,
			transaction_remap, view_context)
		if not walked_consumed.get("ok", false):
			return walked_consumed
		remapped["consumed_warning_receipts"] = walked_consumed["value"]
	var ledger: Variant = view.get("condition_departure_receipts")
	if typeof(ledger) == TYPE_DICTIONARY:
		var walked_ledger := _remap_condition_departure_ledger(ledger as Dictionary,
			transaction_remap, view_context)
		if not walked_ledger.get("ok", false):
			return walked_ledger
		remapped["condition_departure_receipts"] = walked_ledger["value"]
	return {"ok": true, "code": &"ok", "value": remapped}


## The live activation. Its three source pre-conditions run before any rewrite, in the order the
## ruling fixes: the stored context against the SOURCE snapshot's owners, the stored preimage
## against its own stored digest, then the stored six-key provenance against the provenance rebuilt
## from its own stored facts (comparing only `child_id` would not catch an edited source_ids member).
static func _remap_pending_warning(record: Dictionary, bundle: Dictionary,
		transaction_remap: Dictionary, view_context: Dictionary) -> Dictionary:
	var kind := str(record.get("warning_kind", ""))
	var stored_digest := str(record.get("warning_state_fingerprint", ""))
	var stored_preimage: Variant = record.get("warning_fingerprint_preimage")
	if typeof(stored_preimage) != TYPE_DICTIONARY:
		return _fail(&"remap_warning_fingerprint_mismatch",
			"pending_warning.warning_fingerprint_preimage must be an object", {})
	var preconditions := _warning_source_preconditions(stored_preimage as Dictionary, stored_digest,
		view_context)
	if not preconditions.get("ok", false):
		return preconditions
	var opened_receipt: Variant = record.get("opened_by_transaction_issuer_receipt")
	if typeof(opened_receipt) != TYPE_DICTIONARY:
		return _fail(&"remap_child_id_mismatch",
			"pending_warning.opened_by_transaction_issuer_receipt must be an object", {})
	var stored_child := _mint_child(opened_receipt as Dictionary, "warning", 0,
		_activation_source_ids(kind, stored_digest))
	if not stored_child.get("ok", false):
		return stored_child
	if (stored_child["value"] as Dictionary)["provenance"] != record.get("activation_id_provenance"):
		return _fail(&"remap_child_id_mismatch",
			"the stored activation provenance does not rebuild from its own stored facts", {})

	var remapped_preimage := _remap_warning_preimage(stored_preimage as Dictionary, bundle)
	if not remapped_preimage.get("ok", false):
		return remapped_preimage
	var preimage: Dictionary = remapped_preimage["value"]
	var new_digest := _canonical_sha256(preimage)
	if new_digest.is_empty():
		return _fail(&"remap_payload_not_canonicalizable",
			"the remapped warning preimage is not canonically representable", {})
	var old_transaction_id := str(record.get("opened_by_transaction_id", ""))
	var mapping: Variant = transaction_remap.get(old_transaction_id)
	if typeof(mapping) != TYPE_DICTIONARY:
		return _fail(&"remap_dangling_transaction",
			"pending_warning.opened_by_transaction_id has no remap entry: " + old_transaction_id, {})
	var new_receipt: Dictionary = (mapping as Dictionary)["new_transaction_issuer_receipt"]
	var activation := _mint_child(new_receipt, "warning", 0,
		_activation_source_ids(kind, new_digest))
	if not activation.get("ok", false):
		return activation
	var activation_value: Dictionary = activation["value"]
	var new_activation: Dictionary = {
		"activation_id": str(activation_value["child_id"]),
		"activation_id_provenance": activation_value["provenance"],
	}

	var remapped: Dictionary = record.duplicate(true)
	remapped["warning_fingerprint_preimage"] = preimage
	remapped["warning_state_fingerprint"] = new_digest
	remapped["activation_id"] = str(activation_value["child_id"])
	remapped["activation_id_provenance"] = (activation_value["provenance"] as Dictionary).duplicate(true)
	remapped["opened_by_transaction_id"] = str((mapping as Dictionary)["new_transaction_id"])
	remapped["opened_by_transaction_issuer_receipt"] = new_receipt.duplicate(true)
	# `state` and `warning_kind` are semantic and stay byte-identical.
	var attempts: Variant = record.get("attempt_receipts")
	if typeof(attempts) == TYPE_DICTIONARY:
		var rekeyed: Dictionary = {}
		for key: Variant in (attempts as Dictionary).keys():
			var attempt: Variant = (attempts as Dictionary)[key]
			if typeof(attempt) != TYPE_DICTIONARY:
				return _fail(&"remap_warning_key_stale",
					"attempt_receipts[" + str(key) + "] must be an object", {})
			var walked_attempt := _remap_terminal_receipt(attempt as Dictionary, bundle,
				transaction_remap, view_context, new_activation)
			if not walked_attempt.get("ok", false):
				return walked_attempt
			var new_attempt: Dictionary = walked_attempt["value"]
			var new_key := str(new_attempt["transaction_id"])
			if rekeyed.has(new_key):
				return _fail(&"remap_warning_key_stale",
					"two attempt receipts collide on the remapped key: " + new_key, {})
			rekeyed[new_key] = new_attempt
		remapped["attempt_receipts"] = rekeyed
	return {"ok": true, "code": &"ok", "value": remapped}


## The consumed index. Its key is `warning_state_fingerprint + "|" + warning_kind` -- exactly what
## ScheduleWarningPolicy.next_warning() looks up -- so a key that already disagreed with its own
## record on the SOURCE side is a stale index that would silently suppress (or re-raise) a warning
## after the restore, and refuses rather than being repaired.
static func _remap_consumed_warning_receipts(consumed: Dictionary, bundle: Dictionary,
		transaction_remap: Dictionary, view_context: Dictionary) -> Dictionary:
	var rekeyed: Dictionary = {}
	for key: Variant in consumed.keys():
		var record: Variant = consumed[key]
		if typeof(record) != TYPE_DICTIONARY:
			return _fail(&"remap_warning_key_stale",
				"consumed_warning_receipts[" + str(key) + "] must be an object", {})
		var stored: Dictionary = record
		var stored_key := str(stored.get("warning_state_fingerprint", "")) + "|" \
			+ str(stored.get("warning_kind", ""))
		if stored_key != str(key):
			return _fail(&"remap_warning_key_stale",
				"a consumed key does not equal its record's fingerprint|kind: " + str(key), {})
		var walked := _remap_terminal_receipt(stored, bundle, transaction_remap, view_context, {})
		if not walked.get("ok", false):
			return walked
		var new_record: Dictionary = walked["value"]
		var new_key := str(new_record["warning_state_fingerprint"]) + "|" \
			+ str(new_record["warning_kind"])
		if rekeyed.has(new_key):
			return _fail(&"remap_warning_key_stale",
				"two consumed receipts collide on the remapped key: " + new_key, {})
		rekeyed[new_key] = new_record
	return {"ok": true, "code": &"ok", "value": rekeyed}


## One terminal warning receipt, attempt or consumed. `new_activation` is empty for a CONSUMED
## record -- whose activation identity is intentionally historical and survives byte-for-byte -- and
## carries the live pending activation's freshly derived id/provenance for an ATTEMPT record, which
## mirrors that activation while it is still open.
static func _remap_terminal_receipt(record: Dictionary, bundle: Dictionary,
		transaction_remap: Dictionary, view_context: Dictionary,
		new_activation: Dictionary) -> Dictionary:
	var kind := str(record.get("warning_kind", ""))
	var terminal_result := str(record.get("terminal_result", ""))
	var stored_digest := str(record.get("warning_state_fingerprint", ""))
	var stored_activation_id := str(record.get("activation_id", ""))
	var stored_preimage: Variant = record.get("warning_fingerprint_preimage")
	if typeof(stored_preimage) != TYPE_DICTIONARY:
		return _fail(&"remap_warning_fingerprint_mismatch",
			"a terminal warning receipt carries no warning_fingerprint_preimage object", {})
	var preconditions := _warning_source_preconditions(stored_preimage as Dictionary, stored_digest,
		view_context)
	if not preconditions.get("ok", false):
		return preconditions
	var stored_receipt: Variant = record.get("transaction_issuer_receipt")
	if typeof(stored_receipt) != TYPE_DICTIONARY:
		return _fail(&"remap_child_id_mismatch",
			"a terminal warning receipt carries no transaction_issuer_receipt object", {})
	var stored_provenance: Variant = record.get("receipt_provenance")
	if typeof(stored_provenance) != TYPE_DICTIONARY:
		return _fail(&"remap_child_id_mismatch",
			"a terminal warning receipt carries no receipt_provenance object", {})
	# The intent is never decoded: a navigation terminal's own stored provenance already carries the
	# `_p("intent", ...)` projection, and it is reused verbatim on both sides of the remap.
	var intent := _stored_intent_projection(stored_provenance as Dictionary)
	var child_kind := "navigation"
	if terminal_result == "dismissed":
		child_kind = "warning"
	elif intent.is_empty():
		return _fail(&"remap_child_id_mismatch",
			"a navigation terminal receipt's stored provenance carries no intent projection", {})
	var stored_child := _mint_child(stored_receipt as Dictionary, child_kind, 0,
		_terminal_source_ids(stored_activation_id, kind, stored_digest, terminal_result, intent))
	if not stored_child.get("ok", false):
		return stored_child
	if (stored_child["value"] as Dictionary)["provenance"] != stored_provenance:
		return _fail(&"remap_child_id_mismatch",
			"a stored terminal provenance does not rebuild from its own stored facts", {})

	var remapped_preimage := _remap_warning_preimage(stored_preimage as Dictionary, bundle)
	if not remapped_preimage.get("ok", false):
		return remapped_preimage
	var preimage: Dictionary = remapped_preimage["value"]
	var new_digest := _canonical_sha256(preimage)
	if new_digest.is_empty():
		return _fail(&"remap_payload_not_canonicalizable",
			"a remapped terminal warning preimage is not canonically representable", {})
	var old_transaction_id := str(record.get("transaction_id", ""))
	var mapping: Variant = transaction_remap.get(old_transaction_id)
	if typeof(mapping) != TYPE_DICTIONARY:
		return _fail(&"remap_dangling_transaction",
			"a terminal warning receipt's transaction_id has no remap entry: " + old_transaction_id, {})
	var new_receipt: Dictionary = (mapping as Dictionary)["new_transaction_issuer_receipt"]
	var target_activation_id := stored_activation_id
	if not new_activation.is_empty():
		target_activation_id = str(new_activation["activation_id"])
	var minted := _mint_child(new_receipt, child_kind, 0,
		_terminal_source_ids(target_activation_id, kind, new_digest, terminal_result, intent))
	if not minted.get("ok", false):
		return minted
	var minted_value: Dictionary = minted["value"]

	var remapped: Dictionary = record.duplicate(true)
	remapped["warning_fingerprint_preimage"] = preimage
	remapped["warning_state_fingerprint"] = new_digest
	remapped["transaction_id"] = str((mapping as Dictionary)["new_transaction_id"])
	remapped["transaction_issuer_receipt"] = new_receipt.duplicate(true)
	remapped["receipt_id"] = str(minted_value["child_id"])
	remapped["receipt_provenance"] = (minted_value["provenance"] as Dictionary).duplicate(true)
	if not new_activation.is_empty():
		remapped["activation_id"] = target_activation_id
		remapped["activation_id_provenance"] = (new_activation["activation_id_provenance"] as Dictionary).duplicate(true)
	# `failure_code`, `terminal_result` and `warning_kind` are semantic and stay byte-identical.
	return {"ok": true, "code": &"ok", "value": remapped}


## W1: exactly five identity members of the STORED preimage move. `run_id`, `motivation`,
## `board_phase`, both id arrays, the base ordinal/opportunity flags, `unfinished_base_board` and
## the projection's `day`/`entries`/`date_entry_seen` are not identity and stay byte-identical --
## and the live view/context is never substituted for the stored bytes.
static func _remap_warning_preimage(preimage: Dictionary, bundle: Dictionary) -> Dictionary:
	var remapped: Dictionary = preimage.duplicate(true)
	var projection: Variant = remapped.get("view_projection")
	if typeof(projection) == TYPE_DICTIONARY:
		var view_projection: Dictionary = projection
		view_projection["causal_day_instance"] = str(bundle["causal_day_instance"])
	var context: Variant = remapped.get("context")
	if typeof(context) == TYPE_DICTIONARY:
		var data: Dictionary = context
		data["branch_id"] = str(bundle["branch_id"])
		data["desktop_timeline_generation"] = int(bundle["desktop_timeline_generation"])
		data["causal_day_instance"] = str(bundle["causal_day_instance"])
		var identity: Variant = data.get("board_identity")
		if typeof(identity) == TYPE_DICTIONARY:
			var remapped_identity := _IDENTITY.remap(identity as Dictionary, str(bundle["branch_id"]),
				int(bundle["desktop_timeline_generation"]), str(bundle["causal_day_instance"]))
			if not remapped_identity.get("ok", false):
				return remapped_identity
			data["board_identity"] = (remapped_identity["value"] as Dictionary)["identity"]
	return {"ok": true, "code": &"ok", "value": remapped}


## The context is read on the SOURCE side against the SOURCE owners: after W1 every context agrees
## with the bundle trivially, so a context describing a branch this snapshot never had could only be
## caught here.
static func _warning_source_preconditions(preimage: Dictionary, stored_digest: String,
		view_context: Dictionary) -> Dictionary:
	var context: Variant = preimage.get("context")
	if typeof(context) != TYPE_DICTIONARY:
		return _fail(&"remap_warning_context_mismatch",
			"a stored warning preimage carries no context object", {})
	var owners: Dictionary = view_context.get("owners", {})
	var owner_error := _warning_owner_error(context as Dictionary, owners)
	if not owner_error.is_empty():
		return _fail(&"remap_warning_context_mismatch", owner_error, {})
	if _canonical_sha256(preimage) != stored_digest:
		return _fail(&"remap_warning_fingerprint_mismatch",
			"a stored warning preimage does not hash to its own stored warning_state_fingerprint", {})
	return {"ok": true}


static func _warning_owner_error(context: Dictionary, owners: Dictionary) -> String:
	if owners.is_empty():
		return ""
	if str(context.get("branch_id", "")) != str(owners["branch_id"]):
		return "the stored warning context's branch_id is not the source snapshot's own"
	if int(context.get("desktop_timeline_generation", -1)) != int(owners["desktop_timeline_generation"]):
		return "the stored warning context's desktop_timeline_generation is not the source snapshot's own"
	if str(context.get("causal_day_instance", "")) != str(owners["causal_day_instance"]):
		return "the stored warning context's causal_day_instance is not the source snapshot's own"
	var identity: Variant = context.get("board_identity")
	if typeof(identity) != TYPE_DICTIONARY:
		return ""
	var board_identity: Dictionary = identity
	if str(board_identity.get("branch_id", "")) != str(owners["branch_id"]):
		return "the stored warning context's board_identity.branch_id is not the source snapshot's own"
	if int(board_identity.get("desktop_timeline_generation", -1)) != int(owners["desktop_timeline_generation"]):
		return "the stored warning context's board_identity.desktop_timeline_generation is not the source snapshot's own"
	if str(board_identity.get("causal_day_instance", "")) != str(owners["causal_day_instance"]):
		return "the stored warning context's board_identity.causal_day_instance is not the source snapshot's own"
	return ""


## The append-only condition-departure ledger. Exactly the entries anchored to the LIVE pending root
## are re-derived and rekeyed (the key-equals-id law of ScheduleViewState makes a stale key an
## immediate schema failure downstream); every completed historical entry survives == against its
## source bytes. The `source_ids` of a condition child carry no remapped identity in this branch, so
## the existing Tier-A re-derivation is the whole law.
static func _remap_condition_departure_ledger(ledger: Dictionary, transaction_remap: Dictionary,
		view_context: Dictionary) -> Dictionary:
	var parent_receipt_id := str(view_context.get("source_parent_receipt_id", ""))
	var mapped_receipt: Dictionary = view_context.get("mapped_parent_receipt", {})
	var payload_hashes: Dictionary = view_context.get("ledger_payload", {})
	var rekeyed: Dictionary = {}
	for key: Variant in ledger.keys():
		var value: Variant = ledger[key]
		if typeof(value) != TYPE_DICTIONARY:
			return _fail(&"remap_ledger_entry_invalid",
				"condition_departure_receipts[" + str(key) + "] must be an object", {})
		var entry: Dictionary = value
		var provenance: Variant = entry.get("source_condition_receipt_provenance")
		var is_live := typeof(provenance) == TYPE_DICTIONARY and not parent_receipt_id.is_empty() \
			and str((provenance as Dictionary).get("parent_receipt_id", "")) == parent_receipt_id
		if not is_live:
			rekeyed[str(key)] = entry.duplicate(true)
			continue
		if mapped_receipt.is_empty():
			return _fail(&"remap_dangling_transaction",
				"the live condition-departure entry has no mapped pending receipt to re-anchor against", {})
		var rederived := _rederive_anchored_child(provenance as Dictionary, mapped_receipt,
			transaction_remap)
		if not rederived.get("ok", false):
			return rederived
		var rederived_value: Dictionary = rederived["value"]
		var child_id := str(rederived_value["child_id"])
		var remapped_entry: Dictionary = entry.duplicate(true)
		remapped_entry["source_condition_receipt_id"] = child_id
		remapped_entry["source_condition_receipt_provenance"] = rederived_value["provenance"]
		# `disposition` stays exactly the frozen literal it already carries.
		if not payload_hashes.is_empty():
			if str(entry.get("schedule_view_before_sha256", "")) != str(payload_hashes["before_source"]) \
					or str(entry.get("schedule_view_after_sha256", "")) != str(payload_hashes["after_source"]):
				return _fail(&"remap_ledger_payload_mismatch",
					"the ledger entry's two view hashes do not equal the recovery payload's own two views", {})
			remapped_entry["schedule_view_before_sha256"] = str(payload_hashes["before_new"])
			remapped_entry["schedule_view_after_sha256"] = str(payload_hashes["after_new"])
		if rekeyed.has(child_id):
			return _fail(&"remap_ledger_entry_invalid",
				"two condition-departure entries collide on the remapped key: " + child_id, {})
		rekeyed[child_id] = remapped_entry
	return {"ok": true, "code": &"ok", "value": rekeyed}


# -------------------------------------------------------------------------------------------------
# Lifecycle (v5): the identity quadruple, the active condition-Hospital plan, history, handoff
# -------------------------------------------------------------------------------------------------

static func _remap_lifecycle(lifecycle: Dictionary, bundle: Dictionary,
		transaction_remap: Dictionary, live_outbox: Dictionary) -> Dictionary:
	var remapped: Dictionary = lifecycle.duplicate(true)
	if lifecycle.has("branch_id") and lifecycle.has("desktop_timeline_generation") \
			and lifecycle.has("causal_day_instance") \
			and lifecycle.has("causal_day_instance_issuer_receipt"):
		remapped["branch_id"] = str(bundle["branch_id"])
		remapped["desktop_timeline_generation"] = int(bundle["desktop_timeline_generation"])
		remapped["causal_day_instance"] = str(bundle["causal_day_instance"])
		remapped["causal_day_instance_issuer_receipt"] = (bundle["causal_day_instance_issuer_receipt"] as Dictionary).duplicate(true)
	# `run_id`, `day`, `state`, `active_resolution_plan`, `ending_plan` and `restore_provenance` are
	# byte-identical: none of them is an identity this restore reallocates.
	var history: Variant = lifecycle.get("condition_hospital_history")
	if typeof(history) == TYPE_DICTIONARY:
		var validated := _validate_condition_hospital_history(history as Dictionary)
		if not validated.get("ok", false):
			return validated
	var plan: Variant = lifecycle.get("active_condition_hospital_plan")
	if typeof(plan) == TYPE_DICTIONARY:
		var walked_plan := _remap_condition_hospital_plan(plan as Dictionary, lifecycle, bundle,
			transaction_remap, live_outbox)
		if not walked_plan.get("ok", false):
			return walked_plan
		remapped["active_condition_hospital_plan"] = walked_plan["value"]
	var handoff: Variant = lifecycle.get("terminal_intent_handoff")
	if typeof(handoff) == TYPE_DICTIONARY:
		var walked_handoff := _remap_terminal_intent_handoff(handoff as Dictionary, transaction_remap)
		if not walked_handoff.get("ok", false):
			return walked_handoff
		remapped["terminal_intent_handoff"] = walked_handoff["value"]
	return {"ok": true, "code": &"ok", "value": remapped}


## The cursor-aware matrix, in the one order the laws are separable: structure, cursor prefix,
## abandoned future receipts, the nullability partition, the mixed source/target receipt, the stale
## dependent hash, the identity split (mirroring RunLifecycle._validate_condition_lifecycle, because
## RunRestoreParticipant installs this output THROUGH RunLifecycle.prepare_restore), the roots and
## their children, and finally the live outbox.
static func _remap_condition_hospital_plan(plan: Dictionary, lifecycle: Dictionary,
		bundle: Dictionary, transaction_remap: Dictionary, live_outbox: Dictionary) -> Dictionary:
	var structure := _validate_condition_hospital_structure(plan)
	if not structure.get("ok", false):
		return structure
	var stages: Array = plan["stages"]
	var cursor := int(plan["cursor"])
	for index: int in range(stages.size()):
		var stage: Dictionary = stages[index]
		var state := str(stage.get("state", ""))
		if index < cursor and state != "completed":
			return _fail(&"remap_condition_hospital_cursor_mismatch",
				"every stage before the cursor is completed", {"stage_index": index})
		if index == cursor and state != "active" and state != "pending":
			return _fail(&"remap_condition_hospital_cursor_mismatch",
				"the stage at the cursor is active or pending", {"stage_index": index})
		if index > cursor and state != "pending":
			return _fail(&"remap_condition_hospital_cursor_mismatch",
				"every stage after the cursor is pending", {"stage_index": index})
	for index: int in range(stages.size()):
		var stage: Dictionary = stages[index]
		if stage.get("receipt") == null:
			continue
		if index > cursor or str(stage.get("state", "")) == "pending":
			return _fail(&"remap_abandoned_future_receipt",
				"a receipt survives on a stage the cursor has not reached", {"stage_index": index})
	for index: int in range(stages.size()):
		var stage: Dictionary = stages[index]
		var state := str(stage.get("state", ""))
		var identity_null := stage.get("stage_identity") == null
		var prepared_null := stage.get("prepared") == null
		var receipt_null := stage.get("receipt") == null
		if state == "pending" and not (identity_null and prepared_null and receipt_null):
			return _fail(&"remap_condition_hospital_plan_invalid",
				"a pending stage carries a null identity, prepared and receipt", {"stage_index": index})
		if state == "active" and (identity_null or prepared_null or not receipt_null):
			return _fail(&"remap_condition_hospital_plan_invalid",
				"an active stage carries an identity and a prepared payload but no receipt", {"stage_index": index})
		if state == "completed" and (identity_null or prepared_null or receipt_null):
			return _fail(&"remap_condition_hospital_plan_invalid",
				"a completed stage carries an identity, a prepared payload and a receipt", {"stage_index": index})

	var plan_receipt: Dictionary = plan["transaction_issuer_receipt"]
	if str(plan_receipt.get("token", "")) != str(plan["transaction_id"]):
		return _fail(&"remap_condition_hospital_identity_split_invalid",
			"the plan's issuer receipt token must equal its own transaction_id", {})
	var action_receipt: Dictionary = plan["action_receipt"]
	var action_issuer: Variant = action_receipt.get("transaction_issuer_receipt")
	if typeof(action_issuer) != TYPE_DICTIONARY \
			or str((action_issuer as Dictionary).get("token", "")) != str(action_receipt.get("transaction_id", "")):
		return _fail(&"remap_condition_hospital_identity_split_invalid",
			"the action receipt's issuer receipt token must equal its own transaction_id", {})
	var destination: Dictionary = plan["destination_record"]
	if destination.has("payload") \
			and str(destination.get("payload_hash", "")) != _canonical_sha256(destination["payload"]):
		return _fail(&"remap_condition_hospital_plan_invalid",
			"destination_record.payload_hash is stale against its own payload", {})

	# Item 15's "either both move or neither can", stated as ONE guard instead of two: the plan's
	# quadruple moves only when the lifecycle's own can move with it, so an active plan beside a
	# lifecycle missing any of the four identity members refuses here rather than splitting the two
	# apart into a document RunLifecycle._validate_condition_lifecycle would then reject.
	for member: String in ["branch_id", "desktop_timeline_generation", "causal_day_instance",
			"causal_day_instance_issuer_receipt"]:
		if not lifecycle.has(member):
			return _fail(&"remap_condition_hospital_plan_invalid",
				"an active condition-Hospital plan requires a lifecycle carrying " + member, {})

	var advance: Dictionary = stages[4]
	var advance_state := str(advance.get("state", ""))
	var split_allowed := advance_state == "active" or cursor >= 5
	if not split_allowed:
		for member: String in ["branch_id", "causal_day_instance", "run_id"]:
			if str(plan.get(member, "")) != str(lifecycle.get(member, "")):
				return _fail(&"remap_condition_hospital_identity_split_invalid",
					"active_condition_hospital_plan " + member + " must equal the lifecycle's own", {})
		if int(plan.get("desktop_timeline_generation", 0)) != int(lifecycle.get("desktop_timeline_generation", 0)):
			return _fail(&"remap_condition_hospital_identity_split_invalid",
				"active_condition_hospital_plan desktop_timeline_generation must equal the lifecycle's own", {})
		# The fifth member RunLifecycle._validate_condition_lifecycle compares (:648-651): without
		# it a source plan whose issuer receipt disagreed with the lifecycle's would be silently
		# normalised by the quadruple move below instead of being named.
		if _canonical_sha256(plan["causal_day_instance_issuer_receipt"]) \
				!= _canonical_sha256(lifecycle["causal_day_instance_issuer_receipt"]):
			return _fail(&"remap_condition_hospital_identity_split_invalid",
				"active_condition_hospital_plan causal_day_instance_issuer_receipt must equal the lifecycle's own", {})
	var prepared_advance: Variant = advance.get("prepared")
	if advance_state != "pending" and typeof(prepared_advance) == TYPE_DICTIONARY \
			and str((prepared_advance as Dictionary).get("target_causal_day_instance", "")) == str(plan.get("causal_day_instance", "")):
		return _fail(&"remap_condition_hospital_identity_split_invalid",
			"one allocation is never both this plan's source and its advance_day target", {})

	var remapped: Dictionary = plan.duplicate(true)
	if not split_allowed:
		# The still-live source identity is mapped exactly once. Past an active advance_day the
		# plan's own quadruple is historical ancestry and is never rewritten (rows R30/R32a/R33a).
		remapped["branch_id"] = str(bundle["branch_id"])
		remapped["desktop_timeline_generation"] = int(bundle["desktop_timeline_generation"])
		remapped["causal_day_instance"] = str(bundle["causal_day_instance"])
		remapped["causal_day_instance_issuer_receipt"] = (bundle["causal_day_instance_issuer_receipt"] as Dictionary).duplicate(true)

	var plan_mapping: Variant = transaction_remap.get(str(plan["transaction_id"]))
	if typeof(plan_mapping) != TYPE_DICTIONARY:
		return _fail(&"remap_dangling_transaction",
			"active_condition_hospital_plan.transaction_id has no remap entry: " + str(plan["transaction_id"]), {})
	var mapped_plan_receipt: Dictionary = (plan_mapping as Dictionary)["new_transaction_issuer_receipt"]
	remapped["transaction_id"] = str((plan_mapping as Dictionary)["new_transaction_id"])
	remapped["transaction_issuer_receipt"] = mapped_plan_receipt.duplicate(true)
	var action_mapping: Variant = transaction_remap.get(str(action_receipt.get("transaction_id", "")))
	if typeof(action_mapping) != TYPE_DICTIONARY:
		return _fail(&"remap_dangling_transaction",
			"active_condition_hospital_plan.action_receipt.transaction_id has no remap entry: "
				+ str(action_receipt.get("transaction_id", "")), {})
	var mapped_action_receipt: Dictionary = (action_mapping as Dictionary)["new_transaction_issuer_receipt"]
	var remapped_action: Dictionary = remapped["action_receipt"]
	remapped_action["transaction_id"] = str((action_mapping as Dictionary)["new_transaction_id"])
	remapped_action["transaction_issuer_receipt"] = mapped_action_receipt.duplicate(true)

	var parents: Dictionary = {
		"plan_receipt_id": str(plan_receipt.get("receipt_id", "")),
		"plan_receipt": mapped_plan_receipt,
		"action_receipt_id": str((action_issuer as Dictionary).get("receipt_id", "")),
		"action_receipt": mapped_action_receipt,
	}
	var condition: Dictionary = remapped["condition_receipt"]
	var condition_child := _rederive_plan_child(condition.get("receipt_provenance"), parents,
		transaction_remap)
	if not condition_child.get("ok", false):
		return condition_child
	var condition_value: Dictionary = condition_child["value"]
	condition["receipt_id"] = str(condition_value["child_id"])
	condition["receipt_provenance"] = condition_value["provenance"]
	# `decision` is the plan's own semantic verdict and never moves.

	var resolution: Dictionary = remapped["resolution_receipt"]
	var resolution_child := _rederive_plan_child(resolution.get("receipt_provenance"), parents,
		transaction_remap)
	if not resolution_child.get("ok", false):
		return resolution_child
	var resolution_value: Dictionary = resolution_child["value"]
	var new_resolution_id := str(resolution_value["child_id"])
	resolution["receipt_id"] = new_resolution_id
	resolution["receipt_provenance"] = resolution_value["provenance"]

	var remapped_stages: Array = remapped["stages"]
	for index: int in range(remapped_stages.size()):
		var stage: Dictionary = remapped_stages[index]
		stage["stage_key"] = new_resolution_id + ":" + str(stage.get("stage_id", ""))
		if index == 4 and str(stage.get("state", "")) != "pending":
			# The advance_day target IS the live identity this restore reallocates.
			var prepared: Variant = stage.get("prepared")
			if typeof(prepared) == TYPE_DICTIONARY:
				var target: Dictionary = prepared
				if target.has("target_causal_day_instance"):
					target["target_causal_day_instance"] = str(bundle["causal_day_instance"])
					target["target_causal_day_instance_issuer_receipt"] = (bundle["causal_day_instance_issuer_receipt"] as Dictionary).duplicate(true)
		var identity: Variant = stage.get("stage_identity")
		if typeof(identity) != TYPE_DICTIONARY:
			continue
		# The producer's three-key envelope (ConditionHospitalState.prepare_stage_identity), not a
		# bare provenance: the anchored child lives under `provenance`, and
		# ConditionHospitalPlan._stage_member_error requires the completed receipt's `receipt_id` /
		# `receipt_provenance` to equal this envelope's `child_id` / `provenance` -- so the two are
		# written from the one re-derivation. `input_receipt_ids` is carried byte-identical: no
		# producer projects a remapped child id into it yet.
		var envelope: Dictionary = identity
		var stored_stage_provenance: Variant = envelope.get("provenance")
		if typeof(stored_stage_provenance) != TYPE_DICTIONARY:
			return _fail(&"remap_condition_hospital_plan_invalid",
				"a stage_identity carries its anchored child under a Dictionary provenance member",
				{"stage_index": index})
		var stage_child := _rederive_plan_child(stored_stage_provenance, parents, transaction_remap)
		if not stage_child.get("ok", false):
			return stage_child
		var stage_value: Dictionary = stage_child["value"]
		var new_stage_child_id := str(stage_value["child_id"])
		var new_stage_provenance: Dictionary = stage_value["provenance"]
		stage["stage_identity"] = {
			"child_id": new_stage_child_id,
			"input_receipt_ids": envelope.get("input_receipt_ids", []),
			"provenance": new_stage_provenance,
		}
		var receipt: Variant = stage.get("receipt")
		if typeof(receipt) == TYPE_DICTIONARY:
			var stage_receipt: Dictionary = receipt
			stage_receipt["receipt_id"] = new_stage_child_id
			stage_receipt["receipt_provenance"] = new_stage_provenance.duplicate(true)
			stage_receipt["resolution_receipt_id"] = new_resolution_id
	# `accepted_sources` is NEVER re-sorted: the hospital_miss ordinal derives from that frozen
	# creation order, so re-sorting it would silently renumber every miss child.

	var remapped_destination: Dictionary = remapped["destination_record"]
	var destination_payload: Variant = remapped_destination.get("payload")
	if typeof(destination_payload) == TYPE_DICTIONARY:
		var payload_digest := _canonical_sha256(destination_payload)
		if payload_digest.is_empty():
			return _fail(&"remap_payload_not_canonicalizable",
				"the destination record's payload is not canonically representable", {})
		remapped_destination["payload_hash"] = payload_digest
	var outbox_check := _condition_hospital_outbox_error(remapped_destination, live_outbox)
	if not outbox_check.get("ok", false):
		return outbox_check
	return {"ok": true, "code": &"ok", "value": remapped}


## A condition-Hospital child anchors to one of exactly two roots this plan carries: its own
## transaction root, or its action receipt's. Anything else names a parent this document cannot
## produce, and re-deriving under a guessed parent would mint an id the real issuer never would.
static func _rederive_plan_child(provenance: Variant, parents: Dictionary,
		transaction_remap: Dictionary) -> Dictionary:
	if typeof(provenance) != TYPE_DICTIONARY:
		return _fail(&"remap_provenance_invalid",
			"a condition-Hospital child provenance must be an object", {})
	var parent_receipt_id := str((provenance as Dictionary).get("parent_receipt_id", ""))
	var new_parent: Dictionary = {}
	if parent_receipt_id == str(parents["plan_receipt_id"]):
		new_parent = parents["plan_receipt"]
	elif parent_receipt_id == str(parents["action_receipt_id"]):
		new_parent = parents["action_receipt"]
	else:
		return _fail(&"remap_provenance_invalid",
			"a condition-Hospital child names a parent receipt that is neither the plan root nor the "
				+ "action receipt: " + parent_receipt_id, {})
	return _rederive_anchored_child(provenance as Dictionary, new_parent, transaction_remap)


static func _condition_hospital_outbox_error(record: Dictionary, live_outbox: Dictionary) -> Dictionary:
	var live: Variant = live_outbox.get(str(record.get("key", "")))
	if typeof(live) != TYPE_DICTIONARY:
		return {"ok": true}
	var entry: Dictionary = live
	for member: String in ["key", "payload_hash", "provenance", "consumer"]:
		if entry.get(member) != record.get(member):
			return _fail(&"remap_outbox_mismatch",
				"the live outbox entry disagrees with the remapped destination record on " + member, {})
	var record_status := str(record.get("status", ""))
	var live_status := str(entry.get("status", ""))
	if record_status == live_status:
		return {"ok": true}
	if record_status == "pending" and live_status == "published":
		# The publication bit differs, and only the remapped delivery-ledger acceptance record could
		# prove that transition. Task 4 defines no shape for one (its Files list does not reach the
		# delivery ledger), so the transition refuses until the acceptance shape lands with Task 7.
		return _fail(&"remap_acceptance_missing",
			"a published live outbox entry over an unpublished destination record needs the remapped "
				+ "delivery-ledger acceptance record, which Task 4 does not yet have a shape for", {})
	return _fail(&"remap_outbox_mismatch",
		"the live outbox status and the remapped destination record's status are not a lawful pair", {})


## Past the retirement checkpoint a plan is immutable history: it is duplicated with the rest of the
## lifecycle and only VALIDATED here, so a mutated record is detectable in-document (its own issuer
## token, its retirement receipt's digest of it, and the map key that receipt names) instead of
## being quietly re-derived under a new root.
static func _validate_condition_hospital_history(history: Dictionary) -> Dictionary:
	for key: Variant in history.keys():
		if typeof(key) != TYPE_STRING or str(key).strip_edges().is_empty():
			return _fail(&"remap_history_mutated",
				"condition_hospital_history keys must be nonblank Strings", {})
		var value: Variant = history[key]
		if typeof(value) != TYPE_DICTIONARY:
			return _fail(&"remap_history_mutated",
				"condition_hospital_history[" + str(key) + "] must be an object", {})
		var record: Dictionary = value
		var record_keys: Array = record.keys()
		record_keys.sort()
		if record_keys != ["completed_plan", "retirement_receipt"]:
			return _fail(&"remap_history_mutated",
				"a history record carries exactly completed_plan and retirement_receipt", {"key": str(key)})
		var completed: Variant = record["completed_plan"]
		var retirement: Variant = record["retirement_receipt"]
		if typeof(completed) != TYPE_DICTIONARY or typeof(retirement) != TYPE_DICTIONARY:
			return _fail(&"remap_history_mutated",
				"a history record's completed_plan and retirement_receipt must both be objects",
				{"key": str(key)})
		var plan: Dictionary = completed
		var receipt: Dictionary = retirement
		var issuer: Variant = plan.get("transaction_issuer_receipt")
		if typeof(issuer) != TYPE_DICTIONARY \
				or str((issuer as Dictionary).get("token", "")) != str(plan.get("transaction_id", "")):
			return _fail(&"remap_history_mutated",
				"a completed plan's issuer receipt token must equal its own transaction_id",
				{"key": str(key)})
		if str(receipt.get("completed_plan_sha256", "")) != _canonical_sha256(plan):
			return _fail(&"remap_history_mutated",
				"a retirement receipt's completed_plan_sha256 is stale against the plan it retires",
				{"key": str(key)})
		if str(receipt.get("resolution_receipt_id", "")) != str(key):
			return _fail(&"remap_history_mutated",
				"a retirement receipt's resolution_receipt_id must equal its own map key",
				{"key": str(key)})
	return {"ok": true}


## The receipt-free TERMINAL_PENDING handoff: root, intent and outbox record move together, and the
## record's payload must stay byte-equal to the intent it delivers (that equality is the only thing
## binding the two, since the record carries no receipt or receipt-derived id).
static func _remap_terminal_intent_handoff(handoff: Dictionary,
		transaction_remap: Dictionary) -> Dictionary:
	var old_transaction_id := str(handoff.get("source_transaction_id", ""))
	var mapping: Variant = transaction_remap.get(old_transaction_id)
	if typeof(mapping) != TYPE_DICTIONARY:
		return _fail(&"remap_dangling_transaction",
			"terminal_intent_handoff.source_transaction_id has no remap entry: " + old_transaction_id, {})
	var remapped: Dictionary = handoff.duplicate(true)
	remapped["source_transaction_id"] = str((mapping as Dictionary)["new_transaction_id"])
	remapped["source_transaction_issuer_receipt"] = ((mapping as Dictionary)["new_transaction_issuer_receipt"] as Dictionary).duplicate(true)
	var record: Variant = remapped.get("destination_outbox_record")
	if typeof(record) != TYPE_DICTIONARY:
		return _fail(&"remap_terminal_handoff_invalid",
			"terminal_intent_handoff.destination_outbox_record must be an object", {})
	var outbox_record: Dictionary = record
	var intent: Variant = remapped.get("terminal_intent")
	if outbox_record.get("payload") != intent:
		return _fail(&"remap_terminal_handoff_invalid",
			"the destination outbox record's payload must stay byte-equal to the terminal intent", {})
	var digest := _canonical_sha256(intent)
	if digest.is_empty():
		return _fail(&"remap_payload_not_canonicalizable",
			"the terminal intent is not canonically representable", {})
	outbox_record["payload_hash"] = digest
	# `terminal_intent`, `status`, `schema_version` and `source_kind` stay byte-identical.
	return {"ok": true, "code": &"ok", "value": remapped}


# -------------------------------------------------------------------------------------------------
# Shared helpers
# -------------------------------------------------------------------------------------------------

## C1-C3: the ScheduleView roots. An attempt key that disagrees with its own record's transaction_id
## is refused HERE rather than silently unioned -- the census is what the bundle's key set is
## compared against, so a stale index key would otherwise become an invented rewindable root.
static func _collect_view_roots(view: Dictionary, ids: Dictionary) -> Dictionary:
	var pending: Variant = view.get("pending_warning")
	if typeof(pending) == TYPE_DICTIONARY:
		var record: Dictionary = pending
		_add_root(ids, record.get("opened_by_transaction_id"))
		var attempts: Variant = record.get("attempt_receipts")
		if typeof(attempts) == TYPE_DICTIONARY:
			for key: Variant in (attempts as Dictionary).keys():
				var attempt: Variant = (attempts as Dictionary)[key]
				if typeof(attempt) != TYPE_DICTIONARY:
					return _fail(&"remap_warning_key_stale",
						"attempt_receipts[" + str(key) + "] must be an object", {})
				if str((attempt as Dictionary).get("transaction_id", "")) != str(key):
					return _fail(&"remap_warning_key_stale",
						"an attempt_receipts key does not equal its record's transaction_id: " + str(key), {})
				_add_root(ids, key)
	var consumed: Variant = view.get("consumed_warning_receipts")
	if typeof(consumed) == TYPE_DICTIONARY:
		for key: Variant in (consumed as Dictionary).keys():
			var terminal: Variant = (consumed as Dictionary)[key]
			if typeof(terminal) == TYPE_DICTIONARY:
				_add_root(ids, (terminal as Dictionary).get("transaction_id"))
	return {"ok": true}


## C4-C5. A consumed record's opening root, a history plan's root and a condition-departure entry's
## own key are deliberately absent: the first two are intentionally historical, and the third is a
## condition CHILD id whose live root already arrives from the consequence pending.
static func _collect_lifecycle_roots(lifecycle: Dictionary, ids: Dictionary) -> void:
	var plan: Variant = lifecycle.get("active_condition_hospital_plan")
	if typeof(plan) == TYPE_DICTIONARY:
		_add_root(ids, (plan as Dictionary).get("transaction_id"))
	var handoff: Variant = lifecycle.get("terminal_intent_handoff")
	if typeof(handoff) == TYPE_DICTIONARY:
		_add_root(ids, (handoff as Dictionary).get("source_transaction_id"))


static func _add_root(ids: Dictionary, value: Variant) -> void:
	if typeof(value) == TYPE_STRING and not str(value).strip_edges().is_empty():
		ids[str(value)] = true


## The SOURCE snapshot's own identity owners: the board identity when it carries one, else the
## lifecycle's. Used only to read a stored warning context on the source side.
static func _source_identity_owners(desktop: Dictionary, snapshot: Dictionary) -> Dictionary:
	var identity: Variant = (desktop["board"] as Dictionary).get("identity")
	if typeof(identity) == TYPE_DICTIONARY and not (identity as Dictionary).is_empty():
		var board_identity: Dictionary = identity
		return {
			"branch_id": str(board_identity.get("branch_id", "")),
			"desktop_timeline_generation": int(board_identity.get("desktop_timeline_generation", 0)),
			"causal_day_instance": str(board_identity.get("causal_day_instance", "")),
		}
	var lifecycle: Variant = snapshot.get("lifecycle")
	if typeof(lifecycle) == TYPE_DICTIONARY:
		var data: Dictionary = lifecycle
		if data.has("branch_id") and data.has("desktop_timeline_generation") \
				and data.has("causal_day_instance"):
			return {
				"branch_id": str(data["branch_id"]),
				"desktop_timeline_generation": int(data["desktop_timeline_generation"]),
				"causal_day_instance": str(data["causal_day_instance"]),
			}
	return {}


static func _view_context(source_desktop: Dictionary, remapped_desktop: Dictionary,
		transaction_remap: Dictionary, owners: Dictionary) -> Dictionary:
	var context: Dictionary = {"owners": owners, "source_parent_receipt_id": "",
		"mapped_parent_receipt": {}, "ledger_payload": {}}
	var source_pending: Variant = (source_desktop["consequence"] as Dictionary).get("pending")
	if typeof(source_pending) != TYPE_DICTIONARY:
		return context
	var pending: Dictionary = source_pending
	var receipt: Variant = pending.get("transaction_issuer_receipt")
	if typeof(receipt) == TYPE_DICTIONARY:
		context["source_parent_receipt_id"] = str((receipt as Dictionary).get("receipt_id", ""))
	var mapping: Variant = transaction_remap.get(str(pending.get("transaction_id", "")))
	if typeof(mapping) == TYPE_DICTIONARY:
		var mapped: Variant = (mapping as Dictionary).get("new_transaction_issuer_receipt")
		if typeof(mapped) == TYPE_DICTIONARY:
			context["mapped_parent_receipt"] = mapped
	var source_payload: Variant = pending.get("recovery_payload")
	var remapped_pending: Variant = (remapped_desktop["consequence"] as Dictionary).get("pending")
	if typeof(source_payload) != TYPE_DICTIONARY or typeof(remapped_pending) != TYPE_DICTIONARY:
		return context
	var remapped_payload: Variant = (remapped_pending as Dictionary).get("recovery_payload")
	if typeof(remapped_payload) != TYPE_DICTIONARY:
		return context
	var source_views: Dictionary = source_payload
	var new_views: Dictionary = remapped_payload
	if typeof(source_views.get("schedule_view_before")) != TYPE_DICTIONARY \
			or typeof(source_views.get("schedule_view_after")) != TYPE_DICTIONARY:
		return context
	context["ledger_payload"] = {
		"before_source": _canonical_sha256(source_views["schedule_view_before"]),
		"after_source": _canonical_sha256(source_views["schedule_view_after"]),
		"before_new": _canonical_sha256(new_views.get("schedule_view_before", {})),
		"after_new": _canonical_sha256(new_views.get("schedule_view_after", {})),
	}
	return context


## The two frozen warning projection recipes (plan lines 107-109), rebuilt from facts and sorted --
## never decoded, never edited in place.
static func _activation_source_ids(warning_kind: String, digest: String) -> Array:
	var sources: Array = [_p("warning_kind", warning_kind),
		_p("warning_state_fingerprint", digest)]
	sources.sort()
	return sources


static func _terminal_source_ids(activation_id: String, warning_kind: String, digest: String,
		terminal_result: String, intent_projection: String) -> Array:
	var sources: Array = []
	if terminal_result == "dismissed":
		sources = [_p("activation_id", activation_id), _p("warning_state_fingerprint", digest),
			_p("warning_kind", warning_kind), _p("outcome", "dismissed")]
	else:
		sources = [_p("activation_id", activation_id), _p("warning_kind", warning_kind),
			intent_projection]
	sources.sort()
	return sources


static func _stored_intent_projection(provenance: Dictionary) -> String:
	var source_ids: Variant = provenance.get("source_ids")
	if typeof(source_ids) != TYPE_ARRAY:
		return ""
	for value: Variant in (source_ids as Array):
		if str(value).begins_with("intent="):
			return str(value)
	return ""


## Tier B's mint: kind and ordinal unchanged, `source_ids` already rebuilt and sorted by the caller,
## and the six-key provenance emitted in the same frozen insertion order Tier A uses.
static func _mint_child(parent_receipt: Dictionary, child_kind: String, ordinal: int,
		source_ids: Array) -> Dictionary:
	var minted := _child_id(parent_receipt, child_kind, ordinal, source_ids)
	if not minted.get("ok", false):
		return minted
	var child := str(minted["value"])
	return {"ok": true, "code": &"ok", "value": {"child_id": child, "provenance": {
		"schema_version": CHILD_SCHEMA_VERSION,
		"parent_receipt_id": str(parent_receipt.get("receipt_id", "")),
		"child_kind": child_kind,
		"ordinal": ordinal,
		"source_ids": source_ids.duplicate(true),
		"child_id": child,
	}}}


## P(name,value): the single nonblank String name + "=" + canonical JSON (plan line 103). Duplicated
## from the application-layer ScheduleViewController._p(), which is private and which this domain
## file must not import, for exactly the reason `_child_id()` duplicates the issuer's preimage;
## `test_the_remappers_projection_helper_equals_the_real_controllers_p` compares the two.
static func _p(name: String, value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	return name + "=" + str(emitted.get("value", ""))


static func _validate_condition_hospital_structure(plan: Dictionary) -> Dictionary:
	for key: String in ["accepted_sources", "action_receipt", "branch_id", "causal_day_instance",
			"causal_day_instance_issuer_receipt", "condition_receipt", "cursor",
			"desktop_timeline_generation", "destination_record", "resolution_kind",
			"resolution_receipt", "run_id", "schema_version", "source_day", "stages",
			"transaction_id", "transaction_issuer_receipt"]:
		if not plan.has(key):
			return _fail(&"remap_condition_hospital_plan_invalid",
				"active_condition_hospital_plan is missing " + key, {})
	for key: String in ["action_receipt", "condition_receipt", "destination_record",
			"resolution_receipt", "transaction_issuer_receipt"]:
		if typeof(plan[key]) != TYPE_DICTIONARY:
			return _fail(&"remap_condition_hospital_plan_invalid",
				"active_condition_hospital_plan." + key + " must be an object", {})
	if typeof(plan["cursor"]) != TYPE_INT or int(plan["cursor"]) < 0 or int(plan["cursor"]) > 6:
		return _fail(&"remap_condition_hospital_plan_invalid", "cursor must be an int in 0..6", {})
	if typeof(plan["stages"]) != TYPE_ARRAY or (plan["stages"] as Array).size() != 6:
		return _fail(&"remap_condition_hospital_plan_invalid",
			"stages must be an array of exactly six stage records", {})
	for stage: Variant in (plan["stages"] as Array):
		if typeof(stage) != TYPE_DICTIONARY:
			return _fail(&"remap_condition_hospital_plan_invalid", "every stage must be an object", {})
		var stage_keys: Array = (stage as Dictionary).keys()
		stage_keys.sort()
		if stage_keys != ["prepared", "receipt", "stage_id", "stage_identity", "stage_key", "state"]:
			return _fail(&"remap_condition_hospital_plan_invalid",
				"a stage carries exactly the six frozen stage keys", {"keys": stage_keys})
	return {"ok": true}


static func _require_desktop(snapshot: Dictionary) -> Dictionary:
	if typeof(snapshot.get("desktop")) != TYPE_DICTIONARY:
		return _fail(&"remap_snapshot_invalid", "snapshot.desktop is required", {})
	var desktop: Dictionary = snapshot["desktop"]
	if typeof(desktop.get("board")) != TYPE_DICTIONARY or typeof(desktop.get("consequence")) != TYPE_DICTIONARY:
		return _fail(&"remap_snapshot_invalid", "snapshot.desktop.board and .consequence are required", {})
	return {"ok": true, "value": desktop}


static func _require_bundle_keys(bundle: Dictionary) -> Dictionary:
	for key: String in ["transaction_id", "transaction_issuer_receipt", "branch_id",
			"desktop_timeline_generation", "causal_day_instance", "causal_day_instance_issuer_receipt",
			"transaction_remap"]:
		if not bundle.has(key):
			return _fail(&"invalid_identity_allocation_bundle", "identity_allocation_bundle missing " + key, {})
	if typeof(bundle["transaction_remap"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_identity_allocation_bundle", "transaction_remap must be an object", {})
	if typeof(bundle["transaction_issuer_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_identity_allocation_bundle", "transaction_issuer_receipt must be an object", {})
	return {"ok": true}


## Missing/extra/multiply-mapped/dangling/unsorted-set/string-edited identities all reject (brief
## line 291): the rewindable set collected fresh from `snapshot` must equal EXACTLY the
## `transaction_remap` key set, and every remap record must be internally self-consistent.
static func _validate_transaction_remap_matches_snapshot(snapshot: Dictionary, transaction_remap: Dictionary) -> Dictionary:
	var collected := collect_rewindable_transaction_ids(snapshot)
	if not collected.get("ok", false):
		return collected
	var rewindable: Array = (collected["value"] as Dictionary)["transaction_ids"]
	var mapped_keys: Array = transaction_remap.keys()
	mapped_keys.sort()
	if rewindable != mapped_keys:
		return _fail(&"remap_source_set_mismatch",
			"transaction_remap's key set does not exactly equal the snapshot's rewindable transactions",
			{"expected": rewindable, "actual": mapped_keys})
	var seen_targets: Dictionary = {}
	for source_id: Variant in transaction_remap.keys():
		var record: Variant = transaction_remap[source_id]
		if typeof(record) != TYPE_DICTIONARY:
			return _fail(&"remap_record_invalid", "transaction_remap record must be an object: " + str(source_id), {})
		var value: Dictionary = record
		if str(value.get("source_transaction_id", "")) != str(source_id):
			return _fail(&"remap_record_invalid", "source_transaction_id must equal the map key: " + str(source_id), {})
		var new_id := str(value.get("new_transaction_id", ""))
		if new_id.is_empty():
			return _fail(&"remap_record_invalid", "new_transaction_id must be nonblank: " + str(source_id), {})
		if typeof(value.get("new_transaction_issuer_receipt")) != TYPE_DICTIONARY:
			return _fail(&"remap_record_invalid", "new_transaction_issuer_receipt must be an object: " + str(source_id), {})
		if seen_targets.has(new_id):
			return _fail(&"remap_target_multiply_mapped", new_id, {})
		seen_targets[new_id] = true
	return {"ok": true}


## validate_remap()'s independent re-derivation: pairs source/candidate board command/terminal
## receipt keys by POSITION (both dictionaries preserve insertion order, and prepare() inserts
## remapped entries in the same order it iterated the source), the one live consequence pending
## transaction_id if present, and the v5 C1-C5 roots by their own structural position. Every pair's
## new issuer receipt is HARVESTED from the candidate, because a v5 child id depends on its parent
## receipt's namespace/counter/receipt_id and an empty receipt would reproduce a different id on a
## lawful candidate. Any positional mismatch, size mismatch, or a target reused across sources fails
## closed rather than guessing at a correspondence.
static func _derive_transaction_map(source: Dictionary, candidate: Dictionary,
		source_desktop: Dictionary, candidate_desktop: Dictionary) -> Dictionary:
	var map: Dictionary = {}
	var receipts: Dictionary = {}
	var source_board: Dictionary = source_desktop["board"]
	var candidate_board: Dictionary = candidate_desktop["board"]
	for key: String in ["command_receipts", "terminal_receipts"]:
		var source_receipts: Variant = source_board.get(key, {})
		var candidate_receipts: Variant = candidate_board.get(key, {})
		if typeof(source_receipts) != TYPE_DICTIONARY or typeof(candidate_receipts) != TYPE_DICTIONARY:
			return _fail(&"remap_unverifiable", key + " must be an object on both source and candidate", {})
		var source_keys: Array = (source_receipts as Dictionary).keys()
		var candidate_keys: Array = (candidate_receipts as Dictionary).keys()
		if source_keys.size() != candidate_keys.size():
			return _fail(&"remap_unverifiable", key + " cardinality differs between source and candidate", {})
		for index: int in range(source_keys.size()):
			var paired := _pair_transaction(map, receipts, str(source_keys[index]),
				str(candidate_keys[index]), null)
			if not paired.get("ok", false):
				return paired
	var source_pending: Variant = (source_desktop["consequence"] as Dictionary).get("pending")
	var candidate_pending: Variant = (candidate_desktop["consequence"] as Dictionary).get("pending")
	if typeof(source_pending) == TYPE_DICTIONARY and typeof(candidate_pending) == TYPE_DICTIONARY:
		var old_id := str((source_pending as Dictionary).get("transaction_id", ""))
		if not old_id.is_empty():
			var paired_pending := _pair_transaction(map, receipts, old_id,
				str((candidate_pending as Dictionary).get("transaction_id", "")),
				(candidate_pending as Dictionary).get("transaction_issuer_receipt"))
			if not paired_pending.get("ok", false):
				return paired_pending
	var source_day7: Dictionary = _pending_day7_terminal(source_desktop["consequence"])
	var candidate_day7: Dictionary = _pending_day7_terminal(candidate_desktop["consequence"])
	if not source_day7.get("ok", false): return source_day7
	if not candidate_day7.get("ok", false): return candidate_day7
	if source_day7.value.is_empty() != candidate_day7.value.is_empty():
		return _fail(&"remap_unverifiable", "pending Day 7 source cardinality differs", {})
	if not source_day7.value.is_empty():
		var old_action: Dictionary = source_day7.value.action_receipt
		var new_action: Dictionary = candidate_day7.value.action_receipt
		var paired_day7: Dictionary = _pair_transaction(map, receipts, str(old_action.transaction_id),
			str(new_action.transaction_id), new_action.transaction_issuer_receipt)
		if not paired_day7.get("ok", false): return paired_day7
	var v5_pairs := _pair_v5_roots(source, candidate, map, receipts)
	if not v5_pairs.get("ok", false):
		return v5_pairs
	var transaction_remap: Dictionary = {}
	for old_id: Variant in map.keys():
		var receipt: Variant = receipts.get(str(old_id), {})
		var harvested: Dictionary = {}
		if typeof(receipt) == TYPE_DICTIONARY:
			harvested = receipt
		transaction_remap[str(old_id)] = {
			"source_transaction_id": str(old_id), "new_transaction_id": str(map[old_id]),
			"new_transaction_issuer_receipt": harvested,
		}
	return {"ok": true, "value": transaction_remap}


static func _pair_transaction(map: Dictionary, receipts: Dictionary, old_id: String,
		new_id: String, receipt: Variant) -> Dictionary:
	if map.has(old_id) and str(map[old_id]) != new_id:
		return _fail(&"remap_target_conflict", old_id, {})
	map[old_id] = new_id
	if typeof(receipt) == TYPE_DICTIONARY:
		receipts[old_id] = receipt
	return {"ok": true}


static func _pair_v5_roots(source: Dictionary, candidate: Dictionary, map: Dictionary,
		receipts: Dictionary) -> Dictionary:
	var source_view: Variant = source.get("schedule_view")
	var candidate_view: Variant = candidate.get("schedule_view")
	if (typeof(source_view) == TYPE_DICTIONARY) != (typeof(candidate_view) == TYPE_DICTIONARY):
		return _fail(&"remap_unverifiable",
			"schedule_view cardinality differs between source and candidate", {})
	if typeof(source_view) == TYPE_DICTIONARY:
		var source_pending: Variant = (source_view as Dictionary).get("pending_warning")
		var candidate_pending: Variant = (candidate_view as Dictionary).get("pending_warning")
		if (typeof(source_pending) == TYPE_DICTIONARY) != (typeof(candidate_pending) == TYPE_DICTIONARY):
			return _fail(&"remap_unverifiable",
				"pending_warning cardinality differs between source and candidate", {})
		if typeof(source_pending) == TYPE_DICTIONARY:
			var opened := _pair_transaction(map, receipts,
				str((source_pending as Dictionary).get("opened_by_transaction_id", "")),
				str((candidate_pending as Dictionary).get("opened_by_transaction_id", "")),
				(candidate_pending as Dictionary).get("opened_by_transaction_issuer_receipt"))
			if not opened.get("ok", false):
				return opened
			var attempts := _pair_terminal_family(
				(source_pending as Dictionary).get("attempt_receipts"),
				(candidate_pending as Dictionary).get("attempt_receipts"),
				"attempt_receipts", map, receipts)
			if not attempts.get("ok", false):
				return attempts
		var consumed := _pair_terminal_family((source_view as Dictionary).get("consumed_warning_receipts"),
			(candidate_view as Dictionary).get("consumed_warning_receipts"),
			"consumed_warning_receipts", map, receipts)
		if not consumed.get("ok", false):
			return consumed
	var source_lifecycle: Variant = source.get("lifecycle")
	var candidate_lifecycle: Variant = candidate.get("lifecycle")
	if typeof(source_lifecycle) != TYPE_DICTIONARY or typeof(candidate_lifecycle) != TYPE_DICTIONARY:
		return {"ok": true}
	var source_plan: Variant = (source_lifecycle as Dictionary).get("active_condition_hospital_plan")
	var candidate_plan: Variant = (candidate_lifecycle as Dictionary).get("active_condition_hospital_plan")
	if (typeof(source_plan) == TYPE_DICTIONARY) != (typeof(candidate_plan) == TYPE_DICTIONARY):
		return _fail(&"remap_unverifiable",
			"active_condition_hospital_plan cardinality differs between source and candidate", {})
	if typeof(source_plan) == TYPE_DICTIONARY:
		var paired_plan := _pair_transaction(map, receipts,
			str((source_plan as Dictionary).get("transaction_id", "")),
			str((candidate_plan as Dictionary).get("transaction_id", "")),
			(candidate_plan as Dictionary).get("transaction_issuer_receipt"))
		if not paired_plan.get("ok", false):
			return paired_plan
	var source_handoff: Variant = (source_lifecycle as Dictionary).get("terminal_intent_handoff")
	var candidate_handoff: Variant = (candidate_lifecycle as Dictionary).get("terminal_intent_handoff")
	if (typeof(source_handoff) == TYPE_DICTIONARY) != (typeof(candidate_handoff) == TYPE_DICTIONARY):
		return _fail(&"remap_unverifiable",
			"terminal_intent_handoff cardinality differs between source and candidate", {})
	if typeof(source_handoff) == TYPE_DICTIONARY:
		var paired_handoff := _pair_transaction(map, receipts,
			str((source_handoff as Dictionary).get("source_transaction_id", "")),
			str((candidate_handoff as Dictionary).get("source_transaction_id", "")),
			(candidate_handoff as Dictionary).get("source_transaction_issuer_receipt"))
		if not paired_handoff.get("ok", false):
			return paired_handoff
	return {"ok": true}


## Attempt and consumed maps pair by insertion order: the attempt map is keyed by its own record's
## transaction id, the consumed map by a digest that the remap recomputes, so neither key can be
## matched by value across the two documents.
static func _pair_terminal_family(source_family: Variant, candidate_family: Variant, label: String,
		map: Dictionary, receipts: Dictionary) -> Dictionary:
	var source_records: Dictionary = {}
	var candidate_records: Dictionary = {}
	if typeof(source_family) == TYPE_DICTIONARY:
		source_records = source_family
	if typeof(candidate_family) == TYPE_DICTIONARY:
		candidate_records = candidate_family
	if source_records.size() != candidate_records.size():
		return _fail(&"remap_unverifiable",
			label + " cardinality differs between source and candidate", {})
	var source_keys: Array = source_records.keys()
	var candidate_keys: Array = candidate_records.keys()
	for index: int in range(source_keys.size()):
		var source_record: Variant = source_records[source_keys[index]]
		var candidate_record: Variant = candidate_records[candidate_keys[index]]
		if typeof(source_record) != TYPE_DICTIONARY or typeof(candidate_record) != TYPE_DICTIONARY:
			return _fail(&"remap_unverifiable", label + " records must be objects on both sides", {})
		var paired := _pair_transaction(map, receipts,
			str((source_record as Dictionary).get("transaction_id", "")),
			str((candidate_record as Dictionary).get("transaction_id", "")),
			(candidate_record as Dictionary).get("transaction_issuer_receipt"))
		if not paired.get("ok", false):
			return paired
	return {"ok": true}


## The candidate's own warning index keys, checked BEFORE the reproduction compare so a stale key
## names itself instead of arriving as an anonymous byte difference. The digest-versus-preimage law
## is deliberately NOT checked here: a hand-edited fingerprint is exactly what the reproduction is
## for.
static func _candidate_warning_key_error(candidate: Dictionary) -> Dictionary:
	var view: Variant = candidate.get("schedule_view")
	if typeof(view) != TYPE_DICTIONARY:
		return {"ok": true}
	var consumed: Variant = (view as Dictionary).get("consumed_warning_receipts")
	if typeof(consumed) == TYPE_DICTIONARY:
		for key: Variant in (consumed as Dictionary).keys():
			var record: Variant = (consumed as Dictionary)[key]
			if typeof(record) != TYPE_DICTIONARY:
				return _fail(&"remap_warning_key_stale",
					"consumed_warning_receipts[" + str(key) + "] must be an object", {})
			var expected := str((record as Dictionary).get("warning_state_fingerprint", "")) + "|" \
				+ str((record as Dictionary).get("warning_kind", ""))
			if expected != str(key):
				return _fail(&"remap_warning_key_stale",
					"a candidate consumed key does not equal its record's fingerprint|kind: " + str(key), {})
	var pending: Variant = (view as Dictionary).get("pending_warning")
	if typeof(pending) != TYPE_DICTIONARY:
		return {"ok": true}
	var attempts: Variant = (pending as Dictionary).get("attempt_receipts")
	if typeof(attempts) == TYPE_DICTIONARY:
		for key: Variant in (attempts as Dictionary).keys():
			var attempt: Variant = (attempts as Dictionary)[key]
			if typeof(attempt) != TYPE_DICTIONARY:
				return _fail(&"remap_warning_key_stale",
					"attempt_receipts[" + str(key) + "] must be an object", {})
			if str((attempt as Dictionary).get("transaction_id", "")) != str(key):
				return _fail(&"remap_warning_key_stale",
					"a candidate attempt key does not equal its record's transaction_id: " + str(key), {})
	return {"ok": true}


## Mirrors DesktopIdentityNonceIssuer._child_id()'s frozen preimage (plan line 537) exactly,
## INCLUDING its fail-closed behavior on a non-canonicalizable `source_ids`: the issuer's own
## `_child_id()` returns `child_source_ids_malformed` rather than guessing, so this duplicate
## fails closed too instead of silently substituting a placeholder "[]" for an uncanonicalizable
## value. That file's own header forbids adding a shared static to its frozen public surface, so
## the pure, domain-separated formula is duplicated here rather than imported -- it needs only the
## (already remapped) parent receipt's namespace/counter/receipt_id, never a live root/issuer
## object.
static func _child_id(parent_receipt: Dictionary, child_kind: String, ordinal: int, source_ids: Array) -> Dictionary:
	var canonical: Dictionary = _CANONICAL_JSON.stringify(source_ids)
	if not canonical.get("ok", false):
		return _fail(&"remap_child_source_ids_malformed",
			str(canonical.get("message", "source IDs are not canonically representable")), {})
	var canonical_ids := str(canonical["value"])
	return {"ok": true, "value": "%s.%s" % [child_kind, _sha256_hex("desktop_child_v1\n%s\n%d\n%s\n%s\n%d\n%s" % [
		str(parent_receipt.get("namespace", "")),
		int(parent_receipt.get("counter", 0)),
		str(parent_receipt.get("receipt_id", "")),
		child_kind, ordinal, canonical_ids,
	])]}


static func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()


static func _sha256_hex(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
