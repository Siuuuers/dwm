class_name FrozenRunContext
extends RefCounted

## Pure saved-document validation. RunSnapshotSchema calls this after the owning
## structural schemas, before any restore participant installs the candidate.
## No cache is repaired and no value is sampled from a live Run or Profile.
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const CONTACTS := preload("res://scripts/narrative/ContactsFrozenContext.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const HOSPITAL := preload("res://scripts/narrative/HospitalFrozenContext.gd")
const ENDING := preload("res://scripts/narrative/EndingFrozenContext.gd")
const DATING_KEY := "dating_frozen_contexts_v1"
const HOSPITAL_KEY := "hospital_frozen_contexts_v1"
const ENDING_KEY := "ending_frozen_contexts_v1"

static func validate(snapshot: Dictionary, require_complete: bool = false) -> Dictionary:
	if not snapshot.get("lifecycle") is Dictionary or not snapshot.get("gameplay") is Dictionary \
			or not snapshot.get("contacts") is Dictionary \
			or (snapshot.gameplay.has("route_context") and not snapshot.gameplay.route_context is Dictionary):
		return _fail(&"frozen_run_snapshot_invalid")
	var route: Dictionary = snapshot.gameplay.get("route_context", {})
	var lifecycle: Dictionary = snapshot.lifecycle
	var sources := _contact_sources(snapshot.contacts, route.has(CONTACTS.CACHE_KEY) or require_complete)
	if not sources.ok: return sources
	var dating := _dating(route, lifecycle, snapshot.contacts, require_complete)
	if not dating.ok: return dating
	var hospital := _hospital(route, lifecycle, snapshot.contacts, snapshot.gameplay, require_complete)
	if not hospital.ok: return hospital
	var ending := _ending(route, lifecycle, require_complete)
	if not ending.ok: return ending
	if route.has(CONTACTS.CACHE_KEY) or require_complete:
		var missed: Variant = snapshot.gameplay.get("missed_invitations", [])
		if not missed is Array: return _fail(&"contacts_frozen_hospital_miss_source_invalid")
		var misses := _hospital_misses(missed, lifecycle, route, snapshot.contacts)
		if not misses.ok: return misses
		var contacts := CONTACTS.validate_cache(route.get(CONTACTS.CACHE_KEY, CONTACTS.empty_cache()),
			snapshot.contacts, require_complete, missed, int(lifecycle.get("day", 0)))
		if not contacts.ok: return contacts
	return _narrative_checkpoint(snapshot.get("narrative_checkpoint", {}), route, lifecycle, require_complete)

static func _dating(route: Dictionary, lifecycle: Dictionary, contacts: Dictionary, required: bool) -> Dictionary:
	var record: Variant = route.get("active_dating_challenge", {})
	if not route.has(DATING_KEY):
		return _fail(&"frozen_context_snapshot_required") if required and record is Dictionary and not record.is_empty() else _ok()
	var cache: Variant = route[DATING_KEY]
	if not cache is Dictionary or not _exact(cache, ["schema_version", "board_token", "entries"]) \
			or typeof(cache.schema_version) != TYPE_INT or cache.schema_version != 1 \
			or not FROZEN._field(cache.board_token, "id") or not cache.entries is Dictionary or cache.entries.is_empty():
		return _fail(&"frozen_context_cache_invalid")
	if not record is Dictionary or not record.get("context") is Dictionary or not record.get("spec") is Dictionary \
			or not record.get("applied_result") is Dictionary or not record.context.get("participants") is Array \
			or record.spec.get("board_token") != cache.board_token:
		return _fail(&"frozen_context_attempt_mismatch")
	var context: Dictionary = record.context
	var solo: bool = record.get("host") == "canonical_solo"
	if typeof(context.get("day")) != TYPE_INT or context.day not in range(1, 8) \
			or record.get("phase") not in ["pre_challenge", "preparing", "challenge", "cleared_awaiting_terminal_choice", "settlement_retry", "post_challenge", "completed"] \
			or (solo and (context.get("kind") != "solo" or context.participants.size() != 1)) \
			or (not solo and (record.get("host") != "canonical_pair" or context.get("kind") not in ["group", "twofriends_if_deferred"] \
				or context.participants != ["priscilla", "lavinia"])):
		return _fail(&"frozen_context_attempt_mismatch")
	for entry_id: Variant in cache.entries:
		if not entry_id is String: return _fail(&"frozen_context_cache_invalid")
		var checked := FROZEN.validate(entry_id, cache.entries[entry_id])
		if not checked.ok: return checked
		var fields: Dictionary = checked.value.fields
		var phase := str(fields.get("phase", ""))
		if phase not in ["pre_challenge", "post_challenge"] or fields.get("run_id") != lifecycle.get("run_id") \
				or fields.get("day") != context.get("day"):
			return _fail(&"frozen_context_attempt_mismatch")
		# A pair's previously reached group/deferred label remains in the same board
		# cache when its trusted command changes presentation mode after Restore.
		var allowed: Array = [_dating_entry(context, phase)]
		if not solo:
			var other := context.duplicate(true)
			other.kind = "twofriends_if_deferred" if context.kind == "group" else "group"
			allowed.append(_dating_entry(other, phase))
		if entry_id not in allowed: return _fail(&"frozen_context_attempt_mismatch")
		if not solo:
			if fields.stable_deck_state.form != record.get("pair_form"):
				return _fail(&"frozen_context_attempt_mismatch")
			if fields.pair_count_receipt == null and not _has_pair_rollover_source(lifecycle, contacts, int(context.day)):
				return _fail(&"frozen_context_pair_receipt_required")
			if fields.pair_count_receipt != null:
				var count: Dictionary = fields.pair_count_receipt
				var source: Variant = contacts.get("transaction_receipts", {}).get(count.transaction_id)
				var expected := count.duplicate(true)
				expected.erase("transaction_id")
				var window: Dictionary = _dictionary(source.get("pl_window")) if source is Dictionary else {}
				if not source is Dictionary or source.get("kind") != "resolve_day_end" or source.get("day") != context.day \
						or {"outcome": window.get("outcome"), "counts": window.get("counts"), "visible": window.get("visible")} != expected:
					return _fail(&"frozen_context_pair_receipt_required")
		if phase == "post_challenge":
			if record.get("phase") not in ["post_challenge", "completed"] or fields.attempt_id != cache.board_token \
					or fields.board_result != record.get("outcome") or fields.perfect_reasons != record.get("perfect_reasons"):
				return _fail(&"frozen_context_result_mismatch")
			if solo:
				var effect: Variant = record.applied_result.get("receipt")
				if not effect is Dictionary or not effect.get("terminal_fact") is Dictionary \
						or fields.relationship_outcome != record.get("relationship_outcome") \
						or fields.effect_receipt_id != effect.terminal_fact.get("transaction_id"):
					return _fail(&"frozen_context_effect_receipt_required")
				if fields.has("progression_window_result") and fields.progression_window_result != {
					"evaluated": effect.get("progression_evaluated"), "promotion_applied": effect.get("promotion_applied", false),
					"relationship_state": effect.get("relationship_state")}:
					return _fail(&"frozen_context_effect_receipt_required")
	if not cache.entries.has(_dating_entry(context, "pre_challenge")) \
			or (record.get("phase") in ["post_challenge", "completed"] and not cache.entries.has(_dating_entry(context, "post_challenge"))):
		return _fail(&"frozen_context_snapshot_required")
	return _ok()

static func _has_pair_rollover_source(lifecycle: Dictionary, contacts: Dictionary, day: int) -> bool:
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if plan is Dictionary and plan.get("source_day") == day \
			and _stage(plan, "invitation_rollover").get("state") in ["pending", "active"]:
		return true
	# The original presentation stays pending after its later rollover commits.
	for receipt: Dictionary in contacts.get("transaction_receipts", {}).values():
		if receipt.get("kind") == "resolve_day_end" and receipt.get("day") == day and receipt.get("pl_window") is Dictionary:
			return true
	return false

static func _dating_entry(context: Dictionary, phase: String) -> String:
	if context.kind == "solo": return "dating.solo.%s.day%d.%s" % [context.participants[0], int(context.day), phase]
	return "dating.%s.priscilla_lavinia.day%d.%s" % ["group" if context.kind == "group" else "twofriends", int(context.day), phase]

static func _hospital(route: Dictionary, lifecycle: Dictionary, contacts: Dictionary, gameplay: Dictionary, required: bool) -> Dictionary:
	var requests := {}
	if route.has(HOSPITAL_KEY):
		var cache: Variant = route[HOSPITAL_KEY]
		if not cache is Dictionary or not _exact(cache, ["schema_version", "requests"]) \
				or typeof(cache.schema_version) != TYPE_INT or cache.schema_version != 1 or not cache.requests is Dictionary:
			return _fail(&"hospital_frozen_context_invalid")
		requests = cache.requests
		for key: Variant in requests:
			var checked := HOSPITAL.validate_request(requests[key])
			if not checked.ok: return checked
			if not key is String or checked.value.resolution_id != key \
					or checked.value.context.presentation.fields.qualifying_cause != "schedule_done":
				return _fail(&"hospital_frozen_request_mismatch")
			var sources := _hospital_sources(checked.value.context, contacts)
			if not sources.ok: return sources
	var plan: Variant = lifecycle.get("active_resolution_plan")
	if plan is Dictionary:
		var stage := _stage(plan, "hospital_if_triggered")
		var request: Variant = requests.get(plan.get("resolution_id"))
		if request != null:
			if request.context.day != plan.get("source_day") or request.resolution_issuer_receipt != plan.get("resolution_issuer_receipt") \
					or request.stage_id != stage.get("transaction_id"):
				return _fail(&"hospital_frozen_request_mismatch")
			var accepted: Array = []
			var schedule_ids: Array = []
			for entry: Dictionary in plan.get("committed_schedule", {}).get("entries", []):
				if entry.get("action_kind") not in ["solo", "group"]: continue
				var source := CONTACT_STATE.get_schedule_source_receipt(contacts, str(entry.get("source_receipt_id", "")))
				if not source.get("ok", false): return source
				if source.value.receipt.get("action_id") != entry.get("action_id") \
						or source.value.receipt.get("participants") != entry.get("participants"):
					return _fail(&"hospital_frozen_source_mismatch")
				schedule_ids.append(entry.get("schedule_entry_id"))
				if entry.get("source_receipt_id") not in accepted: accepted.append(entry.get("source_receipt_id"))
			schedule_ids.sort()
			accepted.sort()
			if request.context.source_entry_ids != schedule_ids or request.context.presentation.fields.accepted_record_ids != accepted:
				return _fail(&"hospital_frozen_source_mismatch")
		elif required and ((stage.get("state") == "active" and gameplay.get("pending_hospital", false)) \
				or _dictionary(_dictionary(stage.get("receipt")).get("value")).get("required", false)):
			return _fail(&"hospital_frozen_context_required")
	var condition: Variant = lifecycle.get("active_condition_hospital_plan")
	if condition is Dictionary:
		var checked := _condition_hospital(condition, contacts, required)
		if not checked.ok: return checked
		checked = _condition_candidates(condition, lifecycle, contacts, required)
		if not checked.ok: return checked
	for history: Dictionary in lifecycle.get("condition_hospital_history", {}).values():
		if not history.get("completed_plan") is Dictionary: return _fail(&"hospital_frozen_request_mismatch")
		var checked := _condition_hospital(history.completed_plan, contacts, required)
		if not checked.ok: return checked
		checked = _condition_candidates(history.completed_plan, lifecycle, contacts, required)
		if not checked.ok: return checked
	return _ok()

static func _condition_candidates(plan: Dictionary, lifecycle: Dictionary, contacts: Dictionary, required: bool) -> Dictionary:
	for stage: Dictionary in plan.get("stages", []):
		var prepared := _dictionary(stage.get("prepared"))
		var owner := _dictionary(prepared.get("owner_candidate"))
		if not owner.get("gameplay") is Dictionary: continue
		var gameplay: Dictionary = owner.gameplay
		if gameplay.has("route_context") and not gameplay.route_context is Dictionary: return _fail(&"frozen_run_snapshot_invalid")
		var route: Dictionary = gameplay.get("route_context", {})
		if owner.has("contacts"):
			if not owner.contacts is Dictionary: return _fail(&"frozen_run_snapshot_invalid")
			var shaped := CONTACT_STATE.validate_state(owner.contacts)
			if not shaped.get("ok", false): return shaped
		var candidate_contacts: Dictionary = owner.get("contacts", contacts)
		var sources := _contact_sources(candidate_contacts, route.has(CONTACTS.CACHE_KEY) or required)
		if not sources.ok: return sources
		# A historical prepared bag may precede its pair rollover; the Run's later
		# append-only receipt proves that old pending snapshot without rewriting it.
		var dating_contacts := {"transaction_receipts": contacts.get("transaction_receipts", {}).duplicate()}
		for key: String in candidate_contacts.get("transaction_receipts", {}):
			var receipt: Dictionary = candidate_contacts.transaction_receipts[key]
			if dating_contacts.transaction_receipts.has(key) and dating_contacts.transaction_receipts[key] != receipt:
				return _fail(&"frozen_context_pair_receipt_required")
			dating_contacts.transaction_receipts[key] = receipt
		var dating := _dating(route, lifecycle, dating_contacts, required)
		if not dating.ok: return dating
		var ending := _ending(route, lifecycle, false)
		if not ending.ok: return ending
		# These prepared gameplay bags belong to earlier stage boundaries. Validate
		# their own cache bytes, without recursing through the enclosing plan again.
		var saved_lifecycle := {"run_id": lifecycle.get("run_id"), "day": plan.get("source_day"),
			"state": "PLAYING", "active_resolution_plan": null, "active_condition_hospital_plan": null,
			"condition_hospital_history": {}}
		var hospital := _hospital(route, saved_lifecycle, candidate_contacts, gameplay, false)
		if not hospital.ok: return hospital
		if route.has(CONTACTS.CACHE_KEY) or required:
			var missed: Variant = gameplay.get("missed_invitations", [])
			if not missed is Array: return _fail(&"contacts_frozen_hospital_miss_source_invalid")
			var misses := _hospital_misses(missed, lifecycle, route, candidate_contacts, plan)
			if not misses.ok: return misses
			var checked := CONTACTS.validate_cache(route.get(CONTACTS.CACHE_KEY, CONTACTS.empty_cache()), candidate_contacts,
				required, missed, int(plan.get("source_day", 0)) + (1 if stage.get("stage_id") == "advance_day" else 0))
			if not checked.ok: return checked
	return _ok()

static func _hospital_misses(missed: Array, lifecycle: Dictionary, route: Dictionary, contacts: Dictionary,
		prepared_plan: Dictionary = {}) -> Dictionary:
	var outputs: Array = []
	var plans: Array = []
	if lifecycle.get("active_condition_hospital_plan") is Dictionary: plans.append(lifecycle.active_condition_hospital_plan)
	for history: Dictionary in lifecycle.get("condition_hospital_history", {}).values():
		if history.get("completed_plan") is Dictionary: plans.append(history.completed_plan)
	for plan: Dictionary in plans:
		var stage := _stage(plan, "close_invitation_sources")
		if stage.get("state") == "completed":
			outputs.append(_dictionary(_dictionary(stage.get("receipt")).get("output")))
	if not prepared_plan.is_empty():
		outputs.append(_dictionary(_dictionary(_stage(prepared_plan, "close_invitation_sources").get("prepared")).get("output")))
	for record: Variant in missed:
		if not record is Dictionary or record.get("missed_reason") != "hospital": continue
		var keys: Array = ["friend_id", "source", "day", "missed_reason", "source_receipt_id", "hospital_miss_receipt_id"]
		if record.has("schedule_hospital_resolution_id"):
			keys.append("schedule_hospital_resolution_id")
			if not _exact(record, keys): return _fail(&"contacts_frozen_hospital_miss_source_invalid")
			var request: Variant = route.get(HOSPITAL_KEY, {}).get("requests", {}).get(record.schedule_hospital_resolution_id)
			if not request is Dictionary or record.day != request.context.day \
					or record.source_receipt_id not in request.context.presentation.fields.accepted_record_ids \
					or record.source_receipt_id not in request.context.presentation.fields.unfulfilled_record_ids \
					or record.hospital_miss_receipt_id not in request.context.miss_receipt_ids:
				return _fail(&"contacts_frozen_hospital_miss_source_invalid")
			var source := CONTACT_STATE.get_schedule_source_receipt(contacts, str(record.source_receipt_id))
			if not source.get("ok", false): return source
			var participants: Array = source.value.receipt.get("participants", [])
			if record.friend_id not in participants or record.source != ("group" if participants.size() > 1 else "solo"):
				return _fail(&"contacts_frozen_hospital_miss_source_invalid")
			continue
		if not _exact(record, keys): return _fail(&"contacts_frozen_hospital_miss_source_invalid")
		var found := false
		for output: Dictionary in outputs:
			if not output.get("misses", []) is Array: return _fail(&"contacts_frozen_hospital_miss_source_invalid")
			for miss: Variant in output.get("misses", []):
				if not miss is Dictionary: return _fail(&"contacts_frozen_hospital_miss_source_invalid")
				if record.get("hospital_miss_receipt_id") == miss.get("receipt_id") \
						and record.get("source_receipt_id") == miss.get("source_receipt_id") \
						and record.get("day") == miss.get("day") and record.get("friend_id") in miss.get("participants", []) \
						and record.get("source") == ("group" if miss.get("participants", []).size() > 1 else "solo"):
					found = true
		if not found: return _fail(&"contacts_frozen_hospital_miss_source_invalid")
	return _ok()

static func _narrative_checkpoint(checkpoint: Variant, route: Dictionary, lifecycle: Dictionary, required: bool) -> Dictionary:
	if not checkpoint is Dictionary:
		return _ok() # The owning Run schema checks the transport container.
	if not checkpoint.has("entry_id") and not checkpoint.has("frozen_context"):
		return _ok() # Generic physical-owner restart keeps its existing transport.
	if not checkpoint.has("entry_id") or not checkpoint.has("frozen_context"):
		return _fail(&"frozen_run_narrative_context_invalid") if required else _ok()
	var context: Variant = checkpoint.frozen_context
	if not context is Dictionary: return _fail(&"frozen_run_narrative_context_invalid")
	if context.get("execution_mode", "canonical") != "canonical": return _fail(&"frozen_run_narrative_context_invalid")
	if not context.has("presentation"):
		return _fail(&"frozen_context_snapshot_required") if required else _ok()
	if not checkpoint.entry_id is String: return _fail(&"frozen_run_narrative_context_invalid")
	var checked := FROZEN.validate(checkpoint.entry_id, context.presentation)
	if not checked.ok: return checked
	var fields: Dictionary = checked.value.fields
	var retained: Variant = null
	var has_cache := false
	match str(fields.entry_role):
		"solo_pre_challenge", "solo_post_challenge", "pair_pre_challenge_scene", "pair_post_challenge_scene":
			has_cache = route.has(DATING_KEY)
			retained = route.get(DATING_KEY, {}).get("entries", {}).get(checkpoint.entry_id)
		"solo_ending_step", "pair_ending_step", "alone_step":
			has_cache = route.has(ENDING_KEY)
			retained = _dictionary(route.get(ENDING_KEY, {}).get("presentations", {}).get(fields.step_token)).get("presentation")
		"hospital":
			has_cache = route.has(HOSPITAL_KEY)
			for request: Dictionary in route.get(HOSPITAL_KEY, {}).get("requests", {}).values():
				if request.context.presentation.fields.entry_id == checkpoint.entry_id: retained = request.context.presentation
			var plans: Array = []
			if lifecycle.get("active_condition_hospital_plan") is Dictionary: plans.append(lifecycle.active_condition_hospital_plan)
			for history: Dictionary in lifecycle.get("condition_hospital_history", {}).values():
				if history.get("completed_plan") is Dictionary: plans.append(history.completed_plan)
			for plan: Dictionary in plans:
				var request := _dictionary(_dictionary(_stage(plan, "present_hospital").get("prepared")).get("presentation_request"))
				var presentation: Variant = _dictionary(request.get("context")).get("presentation")
				if presentation is Dictionary and presentation.get("fields", {}).get("entry_id") == checkpoint.entry_id:
					has_cache = true
					retained = presentation
		_:
			if fields.entry_role not in CONTACTS.ROLES: return _fail(&"frozen_run_narrative_context_invalid")
			has_cache = route.has(CONTACTS.CACHE_KEY)
			retained = route.get(CONTACTS.CACHE_KEY, {}).get("entries", {}).get(CONTACTS.key_for(checked.value))
	if (has_cache or required) and retained != checked.value: return _fail(&"frozen_run_narrative_context_mismatch")
	return _ok()

static func _hospital_sources(context: Dictionary, contacts: Dictionary) -> Dictionary:
	var fields: Dictionary = context.presentation.fields
	var sylvia: Array = []
	for id: String in fields.accepted_record_ids:
		var source := CONTACT_STATE.get_schedule_source_receipt(contacts, id)
		if not source.get("ok", false): return source
		if source.value.receipt.get("day") != context.day: return _fail(&"hospital_frozen_source_mismatch")
		if source.value.receipt.get("participants") == ["sylvia"]: sylvia.append(id)
	if fields.unfulfilled_record_ids != fields.accepted_record_ids or fields.sylvia_eligible != (not sylvia.is_empty()):
		return _fail(&"hospital_frozen_source_mismatch")
	var id: Variant = fields.sylvia_witness_receipt_id
	if id != null:
		var witness: Variant = contacts.get("sylvia_hospital_witness_receipts", {}).get(id)
		if not witness is Dictionary or witness.get("resolution_kind") != fields.qualifying_cause \
				or witness.get("source_receipt_id") not in sylvia or witness.get("care_followup_day") != context.day + 1:
			return _fail(&"hospital_frozen_witness_mismatch")
		if fields.qualifying_cause == "schedule_done" and witness.get("schedule_entry_id") not in context.source_entry_ids:
			return _fail(&"hospital_frozen_witness_mismatch")
	return _ok()

static func _condition_hospital(plan: Dictionary, contacts: Dictionary, required: bool) -> Dictionary:
	var stage := _stage(plan, "present_hospital")
	var prepared: Variant = stage.get("prepared")
	var request: Variant = prepared.get("presentation_request") if prepared is Dictionary else null
	var context: Variant = request.get("context") if request is Dictionary else null
	if not context is Dictionary or not context.has("presentation"):
		return _fail(&"hospital_frozen_context_required") if required and stage.get("state") in ["active", "completed"] else _ok()
	var checked := HOSPITAL.validate_request(request)
	if not checked.ok: return checked
	var closure_stage := _stage(plan, "close_invitation_sources")
	var closure: Variant = _dictionary(closure_stage.get("receipt")).get("output")
	if not closure is Dictionary or context.day != plan.get("source_day") \
			or context.presentation.fields.qualifying_cause != "condition_hospital" \
			or context.source_entry_ids != closure.get("source_receipt_ids") or context.miss_receipt_ids != closure.get("miss_receipt_ids"):
		return _fail(&"hospital_frozen_source_mismatch")
	# Load remaps the active plan's live identities, but preserves this prepared
	# request and its committed closure output. Bind to that saved causal receipt.
	if request.resolution_id != _dictionary(closure.get("closure_receipt")).get("transaction_id") \
			or request.stage_id != str(request.resolution_id) + ":present_hospital":
		return _fail(&"hospital_frozen_request_mismatch")
	var witness: Variant = closure.get("sylvia_witness")
	var witness_id: Variant = witness.get("receipt_id") if witness is Dictionary else null
	if context.presentation.fields.sylvia_witness_receipt_id != witness_id \
			or (witness_id != null and contacts.get("sylvia_hospital_witness_receipts", {}).get(witness_id) != witness):
		return _fail(&"hospital_frozen_witness_mismatch")
	return _hospital_sources(context, contacts)

static func _ending(route: Dictionary, lifecycle: Dictionary, required: bool) -> Dictionary:
	if not route.has(ENDING_KEY):
		return _fail(&"ending_frozen_seed_required") if required and lifecycle.get("state") in ["ENDING", "COMPLETED"] else _ok()
	var checked := ENDING.validate_cache(route[ENDING_KEY], lifecycle)
	if not checked.ok: return checked
	var seed: Dictionary = checked.value.seed
	var provisional: Variant = route.get("provisional_ending_plan")
	var eligibility: Variant = provisional.get("eligibility_snapshot") if provisional is Dictionary else null
	if not eligibility is Dictionary or seed.presentation_by_scope != eligibility.get("presentation_by_scope") \
			or typeof(eligibility.get("hospital_required")) != TYPE_BOOL \
			or seed.alone_cause != ("hospital_faint" if eligibility.hospital_required else "empty_done"):
		return _fail(&"ending_frozen_seed_mismatch")
	for step: Dictionary in lifecycle.ending_plan.steps:
		if step.get("role") == "pair_coda" and step.get("pair_form") != seed.presentation_by_scope.pair_form:
			return _fail(&"ending_frozen_seed_mismatch")
	return _ok()

static func _stage(plan: Dictionary, id: String) -> Dictionary:
	for stage: Dictionary in plan.get("stages", []):
		if stage.get("stage_id") == id: return stage
	return {}

static func _contact_sources(contacts: Dictionary, full: bool) -> Dictionary:
	# The outer Run schema proves primitive purity, not Contacts' member types.
	# Guard source indexes used by every producer before typed iteration. A new
	# Contacts cache additionally requires the existing Contacts owner schema;
	# all causal generation candidates already satisfy that same contract.
	for key: String in ["transaction_receipts", "schedule_source_receipts", "sylvia_hospital_witness_receipts"]:
		var index: Variant = contacts.get(key, {})
		if not index is Dictionary: return _fail(&"frozen_run_contact_sources_invalid")
		for row: Variant in index.values():
			if not row is Dictionary: return _fail(&"frozen_run_contact_sources_invalid")
	return CONTACT_STATE.validate_state(contacts) if full else _ok()

static func _exact(value: Dictionary, keys: Array) -> bool:
	return FROZEN._exact(value, keys)

static func _dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

static func _ok() -> Dictionary:
	return {"ok": true, "value": {}}

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": str(code), "details": {}}
