class_name EndingFrozenContext
extends RefCounted

## Ordered endings retain admission facts before any step plays. A current step
## adds only its existing playback token and already-completed prerequisite receipts.
const CONTEXT := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
const FRIENDS := ["priscilla", "lavinia", "sylvia"]
const SCOPES := ["priscilla", "lavinia", "sylvia", "priscilla_lavinia"]

static func make_seed(inputs: Dictionary, evidence: Dictionary, pair_counts: Array, alone_cause: String) -> Dictionary:
	var seed := {"schema_version": 1, "presentation_by_scope": inputs.duplicate(true),
		"evidence_receipt_ids_by_scope": evidence.duplicate(true),
		"pair_count_receipt_ids": pair_counts.duplicate(), "alone_cause": alone_cause}
	return validate_seed(seed)

static func validate_seed(seed: Variant) -> Dictionary:
	if not seed is Dictionary or not _exact(seed, ["schema_version", "presentation_by_scope", "evidence_receipt_ids_by_scope", "pair_count_receipt_ids", "alone_cause"]) \
			or typeof(seed.schema_version) != TYPE_INT or seed.schema_version != 1 \
			or not seed.presentation_by_scope is Dictionary or not seed.evidence_receipt_ids_by_scope is Dictionary \
			or not CONTEXT._field(seed.pair_count_receipt_ids, "ids") or not CONTEXT._field(seed.alone_cause, "alone_cause"):
		return _fail(&"ending_frozen_seed_invalid")
	var inputs: Dictionary = seed.presentation_by_scope
	if not _exact(inputs, ["priscilla", "lavinia", "sylvia", "dark_mode", "pair_form", "special_variant"]) \
			or not _exact(seed.evidence_receipt_ids_by_scope, SCOPES) \
			or typeof(inputs.dark_mode) != TYPE_BOOL or not inputs.pair_form is String \
			or inputs.pair_form not in ["", "ambiguous_sweet", "ambiguous_dark", "love_sweet", "love_dark"] \
			or inputs.special_variant not in ["full", "residue"]:
		return _fail(&"ending_frozen_seed_invalid")
	for scope: String in SCOPES:
		if not CONTEXT._field(seed.evidence_receipt_ids_by_scope[scope], "ids"): return _fail(&"ending_frozen_seed_invalid")
	for friend: String in FRIENDS:
		var value: Variant = inputs[friend]
		if not value is Dictionary or not _exact(value, ["tier", "tone", "attitude", "echo_ids", "miss_reasons"]) \
				or not CONTEXT._field(value.tier, "tier") or not CONTEXT._field(value.tone, "tone") \
				or not CONTEXT._field(value.attitude, "attitude") or value.echo_ids != [] \
				or not CONTEXT._field(value.miss_reasons, "ids"):
			return _fail(&"ending_frozen_seed_invalid")
		for reason: String in value.miss_reasons:
			if reason not in ["nevermind", "missed_question", "busy", "judge"]: return _fail(&"ending_frozen_seed_invalid")
	return _ok(seed.duplicate(true))

static func playback_ending_id(step: Dictionary) -> String:
	var ending_id := str(step.get("ending_id", ""))
	if step.get("role") == "observer_coda":
		ending_id = ending_id.trim_suffix(".observation") + ".observer" if ending_id.ends_with(".observation") else ending_id
		ending_id += "." + str(step.get("presentation_variant", ""))
	return ending_id

static func signature_for_step(plan: Dictionary, index: int, seed: Dictionary) -> Dictionary:
	var checked := validate_seed(seed)
	if not checked.ok: return checked
	if not plan.get("steps") is Array or index < 0 or index >= plan.steps.size(): return _fail(&"ending_frozen_step_invalid")
	var step: Dictionary = plan.steps[index]
	var ending_id := playback_ending_id(step)
	var inputs: Dictionary = seed.presentation_by_scope
	var role := str(step.get("role", ""))
	var entry_id := ending_id
	var form := ""
	var fields := {}
	if ending_id == "ending.alone":
		entry_id += ".dark_mode" if inputs.dark_mode else ".normal"
		form = "alone_dark_mode" if inputs.dark_mode else "alone_normal"
		fields = {"ending_role": role, "ending_form": form}
	else:
		if ending_id == "ending.sylvia.special":
			entry_id += "." + str(inputs.special_variant)
			form = "special_" + str(inputs.special_variant)
		elif ".observer." in ending_id:
			form = "observer_" + ending_id.get_slice(".", 3)
		elif ending_id.begins_with("ending.priscilla_lavinia"):
			if not CONTEXT._field(inputs.pair_form, "pair_form"): return _fail(&"ending_frozen_pair_form_missing")
			form = "deck_dark" if inputs.pair_form.ends_with("_dark") else "deck_sweet"
			if ending_id == "ending.priscilla_lavinia": entry_id += ".dark" if inputs.pair_form.ends_with("_dark") else ".sweet"
		else:
			form = "derived_dark" if ending_id.ends_with(".dark") else "derived_sweet"
			if ending_id == "ending.sylvia.dark" and plan.steps[0].get("role") == "special_prefix": form = "special_forced_dark"
		if ending_id.begins_with("ending.priscilla_lavinia"):
			fields = {"pair_form": inputs.pair_form, "ending_role": role, "ending_form": form, "residue": form.ends_with("_residue")}
		else:
			var friend := ending_id.get_slice(".", 1)
			if friend not in FRIENDS: return _fail(&"ending_frozen_step_invalid")
			fields = inputs[friend].duplicate(true)
			fields.merge({"ending_role": role, "ending_form": form, "residue": form.ends_with("_residue")})
	var validated := SIGNATURE.validate({"entry_id": entry_id, "schema_version": 1, "fields": fields})
	return _ok(validated.value.signature) if validated.ok else validated

static func build(plan: Dictionary, index: int, seed: Dictionary, playback_id: String) -> Dictionary:
	var signature := signature_for_step(plan, index, seed)
	if not signature.ok: return signature
	var projected: Dictionary = signature.value
	var schema := CONTEXT.schema_for_entry(projected.entry_id)
	if not schema.ok: return schema
	var prerequisites: Array = []
	for previous: int in range(index):
		var receipt: Variant = plan.get("playback_receipts", {}).get("step:%d" % previous, {}).get("value")
		if not receipt is Dictionary or receipt.get("outcome") != "completed" \
				or not CONTEXT._field(receipt.get("timeline_completion_receipt_id"), "id"):
			return _fail(&"ending_frozen_prerequisite_missing")
		prerequisites.append(receipt.timeline_completion_receipt_id)
	var form: String = projected.fields.ending_form
	var fields := {"entry_id": projected.entry_id, "entry_role": schema.value.fields.entry_role["const"],
		"ending_id": schema.value.fields.ending_id["const"], "ending_role": projected.fields.ending_role,
		"ending_form": form, "playback_mode": "residue" if form.ends_with("_residue") else "full",
		"prerequisite_receipt_ids": prerequisites, "step_token": playback_id}
	match str(fields.entry_role):
		"solo_ending_step":
			var friend: String = schema.value.fields.friend_id["const"]
			fields.merge({"friend_id": friend, "tier": projected.fields.tier, "stored_tone": projected.fields.tone,
				"attitude": projected.fields.attitude, "evidence_receipt_ids": seed.evidence_receipt_ids_by_scope[friend].duplicate(),
				"due_echoes": [], "residue_variant": fields.playback_mode})
		"pair_ending_step":
			fields.merge({"pair_id": "priscilla_lavinia", "pair_count_receipt_ids": seed.pair_count_receipt_ids.duplicate(),
				"deck_tone": "dark" if projected.fields.pair_form.ends_with("_dark") else "sweet",
				"stable_combination": projected.fields.pair_form, "residue_variant": fields.playback_mode})
		"alone_step": fields["alone_cause"] = seed.alone_cause
		_: return _fail(&"ending_frozen_step_invalid")
	var frozen := CONTEXT.build(projected.entry_id, fields)
	if not frozen.ok: return frozen
	return _ok({"signature": projected, "presentation": frozen.value})

static func validate_cache(cache: Variant, lifecycle: Dictionary) -> Dictionary:
	if not cache is Dictionary or not _exact(cache, ["schema_version", "seed", "presentations"]) \
			or typeof(cache.schema_version) != TYPE_INT or cache.schema_version != 1 or not cache.presentations is Dictionary:
		return _fail(&"ending_frozen_cache_invalid")
	var checked := validate_seed(cache.seed)
	if not checked.ok: return checked
	var plan: Variant = lifecycle.get("ending_plan")
	if not plan is Dictionary or not plan.get("steps") is Array: return _fail(&"ending_frozen_plan_required")
	for index: int in range(plan.steps.size()):
		var signature := signature_for_step(plan, index, cache.seed)
		if not signature.ok: return signature
		if index < int(plan.get("next_step_index", 0)) \
				and not cache.presentations.has("%s:ending:%d" % [str(lifecycle.get("run_id", "")), index]):
			return _fail(&"ending_frozen_snapshot_required")
	for key: Variant in cache.presentations:
		if not key is String: return _fail(&"ending_frozen_cache_invalid")
		var found := false
		for index: int in range(mini(int(plan.get("next_step_index", 0)) + 1, plan.steps.size())):
			if key != "%s:ending:%d" % [str(lifecycle.get("run_id", "")), index]: continue
			var expected := build(plan, index, cache.seed, key)
			if not expected.ok: return expected
			if cache.presentations[key] != expected.value: return _fail(&"ending_frozen_cache_conflict")
			found = true
		if not found: return _fail(&"ending_frozen_step_invalid")
	return _ok(cache.duplicate(true))

static func _exact(value: Dictionary, expected: Array) -> bool:
	var keys := value.keys()
	keys.sort()
	var other := expected.duplicate()
	other.sort()
	return keys == other

static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "value": value}

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
