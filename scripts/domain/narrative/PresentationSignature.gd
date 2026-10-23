class_name PresentationSignature
extends RefCounted

## Presentation identity excludes run IDs, physical locators and receipt provenance.
## The closed role fields are versioned separately from Profile and prose content.
const MANIFEST_PATH := "res://data/manifests/dialogic_entries.json"
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SOLO := {"tier":"string", "tone":"string", "attitude":"string", "echo_ids":"strings"}
const ENDING_SOLO := {"tier":"string", "tone":"string", "attitude":"string", "echo_ids":"strings", "miss_reasons":"strings", "ending_role":"string", "ending_form":"string", "residue":"bool"}
const ENDING_PAIR := {"pair_form":"string", "ending_role":"string", "ending_form":"string", "residue":"bool"}
const ENDING_ALONE := {"ending_role":"string", "ending_form":"string"}
static var _entries: Dictionary = {}

static func semantic_ending_id(ending_id: String) -> String:
	# Two persisted legacy IDs name the same accepted Observer identities.
	if ending_id in ["ending.priscilla.observation", "ending.lavinia.observation"]:
		return ending_id.trim_suffix(".observation") + ".observer"
	return ending_id

static func schema_for_role(role: String) -> Dictionary:
	var fields: Dictionary
	match role:
		"solo_ending_step": fields = ENDING_SOLO.duplicate(true)
		"pair_ending_step": fields = ENDING_PAIR.duplicate(true)
		"alone_step": fields = ENDING_ALONE.duplicate(true)
		"pair_pre_challenge_scene", "group_contact_offer":
			fields = {"pair_mode":"string", "pair_form":"string"}
		"pair_post_challenge_scene":
			fields = {"pair_mode":"string", "pair_form":"string", "board_result":"string", "perfect_reasons":"strings"}
		"hospital": fields = {"miss_reason":"string"}
		"echo_fallback": fields = {"echo_ids":"strings"}
		"solo_post_challenge":
			fields = SOLO.duplicate(true)
			fields.merge({"board_result":"string", "relationship_outcome":"string", "perfect_reasons":"strings", "special_mine_phase":"string", "promotion_result":"string"})
		"consequence_followup":
			fields = SOLO.duplicate(true)
			fields["miss_reason"] = "string"
		"ordinary_message", "solo_invitation_offer", "solo_pre_challenge", "ending_invitation_offer":
			fields = SOLO.duplicate(true)
		_: return {}
	return {"schema_version": 1, "fields": fields}

static func from_dating_pre_challenge(record: Dictionary, fields: Dictionary) -> Dictionary:
	if record.get("phase") != "pre_challenge": return _fail("dating_presentation_phase_unavailable")
	return _dating_signature(record, fields, false)

static func from_dating_post_challenge(record: Dictionary, fields: Dictionary) -> Dictionary:
	if record.get("phase") not in ["post_challenge", "completed"]:
		return _fail("dating_presentation_phase_unavailable")
	return _dating_signature(record, fields, true)

static func _dating_signature(record: Dictionary, fields: Dictionary, post: bool) -> Dictionary:
	var context: Variant = record.get("context")
	if not context is Dictionary or not context.get("participants") is Array \
			or typeof(context.get("day")) != TYPE_INT:
		return _fail("invalid_dating_presentation_context")
	var kind: String = str(context.get("kind", ""))
	var base: String
	var projected: Dictionary = {}
	if kind == "solo":
		if record.get("host") != "canonical_solo" or context.participants.size() != 1 \
				or context.participants[0] not in ["priscilla", "lavinia", "sylvia"]:
			return _fail("invalid_dating_presentation_context")
		base = "dating.solo.%s.day%d" % [context.participants[0], context.day]
		for key: String in SOLO:
			if not fields.has(key): return _fail("invalid_presentation_fields")
			projected[key] = fields[key]
	elif kind in ["group", "twofriends_if_deferred"]:
		if record.get("host") != "canonical_pair" or context.participants != ["priscilla", "lavinia"]:
			return _fail("invalid_dating_presentation_context")
		base = "dating.%s.priscilla_lavinia.day%d" % ["group" if kind == "group" else "twofriends", context.day]
		projected = {"pair_mode": kind, "pair_form": record.get("pair_form")}
		if fields.get("pair_mode", kind) != kind or fields.get("pair_form", record.get("pair_form")) != record.get("pair_form"):
			return _fail("invalid_presentation_fields")
	else:
		return _fail("invalid_dating_presentation_context")
	if post:
		var outcome: Variant = record.get("outcome")
		var reasons: Variant = record.get("perfect_reasons")
		if outcome not in ["exploded", "cleared", "perfect"] or not reasons is Array:
			return _fail("invalid_dating_presentation_result")
		var ordered: Array = reasons.duplicate()
		ordered.sort()
		if ordered != reasons or (outcome == "perfect") != (not reasons.is_empty()) \
				or (reasons.has("efficiency_gt_100") and reasons.has("efficiency_gte_100")):
			return _fail("invalid_dating_presentation_result")
		var previous := ""
		for reason: Variant in reasons:
			if reason not in ["efficiency_gt_100", "efficiency_gte_100", "no_flag"] or reason == previous:
				return _fail("invalid_dating_presentation_result")
			previous = reason
		projected["board_result"] = outcome
		projected["perfect_reasons"] = reasons.duplicate()
		if kind == "solo":
			var relationship: Variant = record.get("relationship_outcome")
			if relationship not in ["hatred", "upset", "amused", "loved", "foresight", "dark"]:
				return _fail("invalid_dating_presentation_result")
			if outcome == "exploded" and relationship not in ["hatred", "upset", "amused"]:
				return _fail("invalid_dating_presentation_result")
			if outcome != "exploded" and relationship not in ["dark", "foresight" if outcome == "perfect" else "loved"]:
				return _fail("invalid_dating_presentation_result")
			if record.get("schema_version") == 3 and outcome == "perfect" and relationship != "foresight":
				return _fail("invalid_dating_presentation_result")
			projected["relationship_outcome"] = relationship
			# The retained terminal choice proves whether the post-clear mine was used.
			projected["special_mine_phase"] = "not_reached" if outcome == "exploded" or (record.get("schema_version") == 3 and outcome == "perfect") else ("detonated" if relationship == "dark" else "declined")
			projected["promotion_result"] = fields.get("promotion_result", "none")
			if projected.promotion_result not in ["none", "friend", "ambiguous", "love"]:
				return _fail("invalid_presentation_fields")
		elif record.get("relationship_outcome") != null:
			return _fail("invalid_dating_presentation_result")
	return validate({"entry_id": base + (".post_challenge" if post else ".pre_challenge"),
		"schema_version": 1, "fields": projected})

static func entry_record(entry_id: String) -> Dictionary:
	if _entries.is_empty():
		var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		if file == null: return _fail("presentation_manifest_unavailable")
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary or not parsed.get("entries") is Array:
			return _fail("presentation_manifest_unavailable")
		for row: Variant in parsed.entries:
			if not row is Dictionary or not row.get("entry_id") is String:
				return _fail("presentation_manifest_unavailable")
			_entries[row.entry_id] = row.duplicate(true)
	if not _entries.has(entry_id): return _fail("unknown_presentation_entry")
	return _ok(_entries[entry_id].duplicate(true))

static func validate(signature: Dictionary) -> Dictionary:
	if not _exact(signature, ["entry_id", "fields", "schema_version"]) \
			or not signature.entry_id is String or not signature.fields is Dictionary \
			or typeof(signature.schema_version) != TYPE_INT or signature.schema_version != 1:
		return _fail("invalid_presentation_signature")
	var located := entry_record(signature.entry_id)
	if not located.ok: return located
	var row: Dictionary = located.value
	var schema := schema_for_role(str(row.role))
	var declared: Variant = row.get("presentation_signature_schema")
	if schema.is_empty() or not declared is Dictionary or not _exact(declared, ["fields", "schema_version"]) \
			or typeof(declared.schema_version) not in [TYPE_INT, TYPE_FLOAT] \
			or float(declared.schema_version) != 1.0 or declared.fields != schema.fields:
		return _fail("presentation_schema_unavailable")
	var fields: Dictionary = signature.fields
	if not _exact(fields, schema.fields.keys()): return _fail("invalid_presentation_fields")
	for field: String in fields:
		match str(schema.fields[field]):
			"string":
				if not fields[field] is String: return _fail("invalid_presentation_fields")
			"bool":
				if typeof(fields[field]) != TYPE_BOOL: return _fail("invalid_presentation_fields")
			"strings":
				if not fields[field] is Array: return _fail("invalid_presentation_fields")
				for value: Variant in fields[field]:
					if not value is String or value.is_empty(): return _fail("invalid_presentation_fields")
	if fields.has("tier") and fields.tier not in ["friend", "ambiguous", "love"]: return _fail("invalid_presentation_fields")
	if fields.has("tone") and fields.tone not in ["sweet", "dark"]: return _fail("invalid_presentation_fields")
	if fields.has("pair_form") and fields.pair_form not in ["ambiguous_sweet", "ambiguous_dark", "love_sweet", "love_dark"]:
		return _fail("invalid_presentation_fields")
	if fields.has("ending_role"):
		var roles: Array = ["core", "primary"] if row.role == "alone_step" else (
			["pair_coda", "epilogue", "observer_coda"] if row.role == "pair_ending_step" else ["core", "primary", "special_prefix", "observer_coda"])
		if fields.ending_role not in roles: return _fail("invalid_presentation_fields")
	if fields.has("ending_form") and fields.ending_form not in row.allowed_ending_forms:
		return _fail("invalid_presentation_form")
	if fields.has("residue") and fields.residue != str(fields.ending_form).ends_with("_residue"):
		return _fail("invalid_presentation_form")
	var encoded := JSON_WRITER.stringify(signature)
	if not encoded.ok: return _fail("invalid_presentation_signature")
	return _ok({"signature": signature.duplicate(true), "signature_id": str(encoded.value).sha256_text()})

static func validate_ledger(records: Dictionary) -> Dictionary:
	for identity: Variant in records:
		if not identity is String or not records[identity] is Dictionary: return _fail("invalid_reached_presentations")
		var checked := validate(records[identity])
		if not checked.ok or checked.value.signature_id != identity: return _fail("invalid_reached_presentations")
	return _ok(records.duplicate(true))

static func _exact(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key: Variant in keys:
		if not value.has(key): return false
	return true

static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}

static func _fail(code: String) -> Dictionary:
	return {"ok": false, "code": StringName(code), "value": null}
