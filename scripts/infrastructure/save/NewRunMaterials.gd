class_name NewRunMaterials
extends RefCounted

## Strict validator for the complete detached material retained by a New Run decision.
## It owns no I/O: the continuation journal stores these bytes and SaveManager later proves each
## target independently.

const PROFILE_SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const SAVE_DOCUMENT_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const MATERIAL_KEYS: Array[String] = ["allocation_candidate", "autosave", "profile"]
const AUTOSAVE_KEYS: Array[String] = ["outgoing_hash", "outgoing_text", "source_revision"]
const PROFILE_KEYS: Array[String] = [
	"before", "candidate", "captured_dark", "outgoing_hash", "outgoing_text",
	"profile_revision", "source_revision",
]
const ALLOCATION_CANDIDATE_KEYS: Array[String] = [
	"branch_id", "branch_id_issuer_receipt", "causal_day_instance",
	"causal_day_instance_issuer_receipt", "desktop_timeline_generation",
	"desktop_timeline_generation_issuer_receipt", "kind",
	"remap_transaction_issuer_receipts", "request", "root_namespace",
	"root_next_counter", "run_id", "run_id_issuer_receipt", "schema_version",
	"transaction_remap",
]
const ALLOCATION_REQUEST_KEYS: Array[String] = [
	"existing_run_id", "kind", "remap_source_transaction_ids",
	"source_desktop_timeline_generation", "transaction_id",
	"transaction_issuer_receipt",
]
const EMPTY_AUDIO_CONTEXT := {
	"ambience_context": {},
	"ambience_context_id": "",
	"music_context": {},
	"music_context_id": "",
}
const RECEIPT_KEYS: Array[String] = [
	"counter", "namespace", "numeric_value", "purpose", "receipt_id", "token",
]
const SCENE_INITIAL_KEYS: Array[String] = [
	"active_app_id", "audio_context", "content_version", "dialogic_checkpoint", "route_id",
]


static func validate(materials: Variant, initial_context: Dictionary, transaction_id: String,
		allocation_fingerprint: String) -> Dictionary:
	if typeof(materials) != TYPE_DICTIONARY:
		return _fail(&"new_run_materials_invalid", "materials must be an object")
	var detached: Dictionary = (materials as Dictionary).duplicate(true)
	if not _has_exact_keys(detached, MATERIAL_KEYS):
		return _fail(&"new_run_materials_invalid", "materials have unexpected members")
	if transaction_id.strip_edges().is_empty() or not _is_sha256(allocation_fingerprint):
		return _fail(&"new_run_materials_invalid", "transaction identity is malformed")
	if initial_context.get("route_id") == "scene":
		return _validate_scene(detached, initial_context, transaction_id, allocation_fingerprint)
	if typeof(initial_context.get("dark_mode")) != TYPE_BOOL:
		return _fail(&"new_run_materials_invalid", "initial context has no captured Dark Boolean")

	var allocation := _validate_allocation(detached.get("allocation_candidate"), transaction_id,
		allocation_fingerprint)
	if not allocation.get("ok", false):
		return allocation
	var profile := _validate_profile(detached.get("profile"), bool(initial_context["dark_mode"]))
	if not profile.get("ok", false):
		return profile
	var autosave := _validate_autosave(detached.get("autosave"), initial_context,
		allocation["value"], bool(profile["value"]["captured_dark"]))
	if not autosave.get("ok", false):
		return autosave
	return {"ok": true, "code": &"ok", "value": {"materials": detached}}


static func _validate_scene(materials: Dictionary, initial_context: Dictionary,
		transaction_id: String, allocation_fingerprint: String) -> Dictionary:
	if not _has_exact_keys(initial_context, SCENE_INITIAL_KEYS) \
			or initial_context.active_app_id != null \
			or typeof(initial_context.content_version) != TYPE_INT or initial_context.content_version < 1 \
			or not initial_context.audio_context is Dictionary \
			or not initial_context.dialogic_checkpoint is Dictionary \
			or initial_context.dialogic_checkpoint.is_empty() \
			or not initial_context.dialogic_checkpoint.get("reading_session") is Dictionary \
			or typeof(initial_context.dialogic_checkpoint.reading_session.get("schema_version")) != TYPE_INT \
			or initial_context.dialogic_checkpoint.reading_session.schema_version != 5:
		return _fail(&"new_run_materials_invalid", "scene initial context must carry its actual reading checkpoint")
	var allocation := _validate_allocation(materials.allocation_candidate, transaction_id, allocation_fingerprint)
	if not allocation.get("ok", false): return allocation
	if not materials.profile is Dictionary:
		return _fail(&"new_run_profile_invalid", "scene profile material must be an object")
	# The existing Profile owner owns the exact G7 material and assignment-chain law.
	# Load here to avoid introducing an eager autoload dependency into historical validation.
	var profile_owner: Script = load("res://autoload/ProfileManager.gd")
	var profile: Dictionary = profile_owner.validate_scene_new_run_material(materials.profile)
	if not profile.get("ok", false): return profile
	var assignment: Dictionary = materials.profile.scene_assignment
	if assignment.run_id != allocation.value.run_id \
			or assignment.receipt.creation_transaction_id != transaction_id:
		return _fail(&"new_run_profile_invalid", "scene assignment does not bind this allocated creation")
	var autosave := _validate_autosave(materials.autosave, initial_context, allocation.value,
		false, assignment.receipt)
	if not autosave.get("ok", false): return autosave
	return {"ok": true, "code": &"ok", "value": {"materials": materials.duplicate(true)}}


static func _validate_allocation(value: Variant, transaction_id: String,
		allocation_fingerprint: String) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _fail(&"new_run_allocation_invalid", "allocation candidate must be an object")
	var candidate: Dictionary = value
	if not _has_exact_keys(candidate, ALLOCATION_CANDIDATE_KEYS):
		return _fail(&"new_run_allocation_invalid", "allocation candidate has unexpected members")
	if _canonical_sha256(candidate) != allocation_fingerprint:
		return _fail(&"new_run_allocation_invalid", "allocation fingerprint does not match candidate bytes")
	if typeof(candidate.get("schema_version")) != TYPE_INT or int(candidate["schema_version"]) != 1 \
			or candidate.get("kind") != "new_run":
		return _fail(&"new_run_allocation_invalid", "allocation discriminator is invalid")
	if typeof(candidate.get("root_namespace")) != TYPE_STRING \
			or not _is_sha256(candidate["root_namespace"]) \
			or typeof(candidate.get("root_next_counter")) != TYPE_INT \
			or int(candidate["root_next_counter"]) < 1:
		return _fail(&"new_run_allocation_invalid", "allocation root identity is malformed")
	if typeof(candidate.get("request")) != TYPE_DICTIONARY \
			or not _has_exact_keys(candidate["request"] as Dictionary, ALLOCATION_REQUEST_KEYS):
		return _fail(&"new_run_allocation_invalid", "allocation request is malformed")
	var request: Dictionary = candidate["request"]
	if request.get("kind") != "new_run" or request.get("existing_run_id") != null \
			or request.get("source_desktop_timeline_generation") != null \
			or typeof(request.get("remap_source_transaction_ids")) != TYPE_ARRAY \
			or not (request["remap_source_transaction_ids"] as Array).is_empty() \
			or request.get("transaction_id") != transaction_id:
		return _fail(&"new_run_allocation_invalid", "allocation request is not this New Run")
	if typeof(candidate.get("remap_transaction_issuer_receipts")) != TYPE_DICTIONARY \
			or not (candidate["remap_transaction_issuer_receipts"] as Dictionary).is_empty() \
			or typeof(candidate.get("transaction_remap")) != TYPE_DICTIONARY \
			or not (candidate["transaction_remap"] as Dictionary).is_empty():
		return _fail(&"new_run_allocation_invalid", "new-run remap collections must be empty")
	if typeof(candidate.get("run_id")) != TYPE_STRING or str(candidate["run_id"]).is_empty() \
			or typeof(candidate.get("branch_id")) != TYPE_STRING or str(candidate["branch_id"]).is_empty() \
			or typeof(candidate.get("causal_day_instance")) != TYPE_STRING \
			or str(candidate["causal_day_instance"]).is_empty() \
			or typeof(candidate.get("desktop_timeline_generation")) != TYPE_INT \
			or int(candidate["desktop_timeline_generation"]) != 0:
		return _fail(&"new_run_allocation_invalid", "new-run identity values are malformed")
	var namespace_value := str(candidate["root_namespace"])
	for receipt_field: String in [
			"run_id_issuer_receipt", "branch_id_issuer_receipt",
			"desktop_timeline_generation_issuer_receipt", "causal_day_instance_issuer_receipt"]:
		if typeof(candidate.get(receipt_field)) != TYPE_DICTIONARY:
			return _fail(&"new_run_allocation_invalid", receipt_field + " must be an issuer receipt")
	if typeof(request.get("transaction_issuer_receipt")) != TYPE_DICTIONARY:
		return _fail(&"new_run_allocation_invalid", "transaction receipt must be an issuer receipt")
	var generation_receipt: Dictionary = candidate["desktop_timeline_generation_issuer_receipt"]
	var receipts := [
		[candidate.get("run_id_issuer_receipt"), "run_id", candidate["run_id"], null],
		[candidate.get("branch_id_issuer_receipt"), "branch_id", candidate["branch_id"], null],
		[candidate.get("desktop_timeline_generation_issuer_receipt"),
			"desktop_timeline_generation",
			generation_receipt.get("token"), 0],
		[candidate.get("causal_day_instance_issuer_receipt"), "causal_day_instance",
			candidate["causal_day_instance"], null],
		[request.get("transaction_issuer_receipt"), "transaction_id", transaction_id, null],
	]
	for row: Array in receipts:
		var receipt_ok := _validate_receipt(row[0], namespace_value, str(row[1]), row[2], row[3])
		if not receipt_ok.get("ok", false):
			return receipt_ok
	return {"ok": true, "code": &"ok", "value": candidate.duplicate(true)}


static func _validate_receipt(value: Variant, namespace_value: String, purpose: String,
		token: Variant, numeric_value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _has_exact_keys(value as Dictionary, RECEIPT_KEYS):
		return _fail(&"new_run_allocation_invalid", "issuer receipt is malformed")
	var receipt: Dictionary = value
	if receipt.get("namespace") != namespace_value or receipt.get("purpose") != purpose \
			or receipt.get("token") != token or receipt.get("numeric_value") != numeric_value \
			or typeof(receipt.get("counter")) != TYPE_INT or int(receipt["counter"]) < 0:
		return _fail(&"new_run_allocation_invalid", "issuer receipt does not match identity")
	var expected_token := "%s.%s" % [purpose,
		_sha256_text("%s\n%d\n%s" % [namespace_value, int(receipt["counter"]), purpose])]
	if str(receipt["token"]) != expected_token:
		return _fail(&"new_run_allocation_invalid", "issuer token is not reproducible")
	var expected_receipt_id := "issuer_receipt." + _sha256_text(
		"desktop_issuer_receipt_v1\n%s\n%d\n%s\n%s" % [
			namespace_value, int(receipt["counter"]), purpose, expected_token,
		])
	if receipt.get("receipt_id") != expected_receipt_id:
		return _fail(&"new_run_allocation_invalid", "issuer receipt ID is not reproducible")
	return {"ok": true, "code": &"ok"}


static func _validate_profile(value: Variant, captured_dark: bool) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _has_exact_keys(value as Dictionary, PROFILE_KEYS):
		return _fail(&"new_run_profile_invalid", "profile material has unexpected members")
	var profile: Dictionary = value
	if typeof(profile.get("before")) != TYPE_DICTIONARY \
			or typeof(profile.get("candidate")) != TYPE_DICTIONARY \
			or typeof(profile.get("captured_dark")) != TYPE_BOOL \
			or typeof(profile.get("profile_revision")) != TYPE_INT \
			or int(profile["profile_revision"]) < 1:
		return _fail(&"new_run_profile_invalid", "profile material types are malformed")
	if bool(profile["captured_dark"]) != captured_dark:
		return _fail(&"new_run_profile_invalid", "captured Dark disagrees with initial context")
	if not _is_sha256(profile.get("source_revision")) \
			or not _is_sha256(profile.get("outgoing_hash")) \
			or typeof(profile.get("outgoing_text")) != TYPE_STRING:
		return _fail(&"new_run_profile_invalid", "profile revisions are malformed")
	var before_valid: Dictionary = PROFILE_SCHEMA.validate(profile["before"] as Dictionary)
	var candidate_valid: Dictionary = PROFILE_SCHEMA.validate(profile["candidate"] as Dictionary)
	if not before_valid.get("ok", false) or not candidate_valid.get("ok", false):
		return _fail(&"new_run_profile_invalid", "profile documents do not satisfy the current schema")
	var before: Dictionary = before_valid["value"]
	var candidate: Dictionary = candidate_valid["value"]
	# Legacy material whose validation reports migrated is admitted as normalized: ProfileSchema
	# admits default leaves the stored bytes predate, so only unmigrated drift is denormalized.
	if (not bool(before_valid.get("migrated", false)) and before != profile["before"]) \
			or (not bool(candidate_valid.get("migrated", false)) and candidate != profile["candidate"]):
		return _fail(&"new_run_profile_invalid", "profile material is not normalized")
	var before_dark_group: Dictionary = (before.get("preferences", {}) as Dictionary).get("dark_mode", {})
	var before_dark: Variant = before_dark_group.get("next_run_enabled")
	if typeof(before_dark) != TYPE_BOOL or bool(before_dark) != captured_dark:
		return _fail(&"new_run_profile_invalid", "source profile does not carry captured Dark")
	if captured_dark and not bool(before_dark_group.get("available", false)):
		return _fail(&"new_run_profile_invalid", "unavailable Dark cannot be captured for New Run")
	var expected_candidate := (profile["before"] as Dictionary).duplicate(true)
	var expected_preferences: Dictionary = expected_candidate["preferences"]
	var expected_dark: Dictionary = expected_preferences["dark_mode"]
	expected_dark["next_run_enabled"] = false
	expected_preferences["dark_mode"] = expected_dark
	expected_candidate["preferences"] = expected_preferences
	if profile["candidate"] != expected_candidate:
		return _fail(&"new_run_profile_invalid", "consumption may change only the pending Dark selector")
	var candidate_text: String = _canonical_text(profile["candidate"])
	if candidate_text.is_empty():
		return _fail(&"new_run_profile_invalid", "candidate profile is not canonically serializable")
	if str(profile["outgoing_text"]) != candidate_text \
			or _sha256_text(str(profile["outgoing_text"])) != str(profile["outgoing_hash"]):
		return _fail(&"new_run_profile_invalid", "outgoing profile bytes are not canonical")
	return {"ok": true, "code": &"ok", "value": profile.duplicate(true)}


static func _validate_autosave(value: Variant, initial_context: Dictionary,
		allocation: Dictionary, captured_dark: bool, scene_assignment: Dictionary = {}) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or not _has_exact_keys(value as Dictionary, AUTOSAVE_KEYS):
		return _fail(&"new_run_autosave_invalid", "Autosave material has unexpected members")
	var autosave: Dictionary = value
	if not _is_revision(autosave.get("source_revision")) \
			or not _is_sha256(autosave.get("outgoing_hash")) \
			or typeof(autosave.get("outgoing_text")) != TYPE_STRING:
		return _fail(&"new_run_autosave_invalid", "Autosave revisions are malformed")
	var outgoing_text := str(autosave["outgoing_text"])
	if _sha256_text(outgoing_text) != str(autosave["outgoing_hash"]):
		return _fail(&"new_run_autosave_invalid", "Autosave outgoing hash does not match bytes")
	var parsed: Dictionary = STRICT_JSON.parse_object(outgoing_text)
	if not parsed.get("ok", false):
		return _fail(&"new_run_autosave_invalid", "Autosave bytes are not strict JSON")
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"] as Dictionary)
	if not validated.get("ok", false):
		return _fail(&"new_run_autosave_invalid", "Autosave bytes do not satisfy the current schema")
	var document: Dictionary = validated["value"]["candidate"]
	var canonical := _canonical_text(document)
	if canonical.is_empty() or outgoing_text != canonical + "\n":
		return _fail(&"new_run_autosave_invalid", "Autosave bytes are not canonical with one final newline")
	if document.get("kind") != "autosave" or document.get("slot_id") != null \
			or document.get("save_reason") != "day_start" or not document.has("saved_time") \
			or typeof(document.get("recovery_journal")) != TYPE_ARRAY \
			or not (document["recovery_journal"] as Array).is_empty():
		return _fail(&"new_run_autosave_invalid", "initial Autosave discriminator/history is invalid")
	var bundle: Dictionary = document["current_snapshot"]
	var snapshot: Dictionary = bundle["snapshot"]
	var lifecycle: Dictionary = snapshot["lifecycle"]
	if bundle.get("checkpoint_kind") != "day_start" \
			or int(snapshot.get("checkpoint_sequence", 0)) != 1 \
			or snapshot.get("checkpoint_id") != str(allocation["run_id"]) + ":1" \
			or snapshot.get("run_id") != allocation["run_id"] \
			or lifecycle.get("run_id") != allocation["run_id"] \
			or lifecycle.get("branch_id") != allocation["branch_id"] \
			or lifecycle.get("desktop_timeline_generation") != allocation["desktop_timeline_generation"] \
			or lifecycle.get("causal_day_instance") != allocation["causal_day_instance"] \
			or lifecycle.get("causal_day_instance_issuer_receipt") != allocation["causal_day_instance_issuer_receipt"]:
		return _fail(&"new_run_autosave_invalid", "Autosave snapshot does not bind allocated identity")
	if not scene_assignment.is_empty():
		if document.get("schema_version") != 9 or snapshot.get("schema_version") != 9 \
				or lifecycle.get("state") != "PLAYING" or lifecycle.get("restore_provenance") != null \
				or lifecycle.get("scene_assignment") != scene_assignment \
				or snapshot.get("route_id") != "scene" or initial_context.get("route_id") != "scene" \
				or snapshot.get("active_app_id") != null or initial_context.get("active_app_id") != null \
				or snapshot.get("content_version") != initial_context.get("content_version") \
				or snapshot.get("narrative_checkpoint") != initial_context.get("dialogic_checkpoint") \
				or snapshot.get("audio_context") != initial_context.get("audio_context"):
			return _fail(&"new_run_autosave_invalid", "scene Autosave differs from its allocated assignment or initial context")
		return {"ok": true, "code": &"ok", "value": autosave.duplicate(true)}
	if lifecycle.get("day") != 1 or lifecycle.get("state") != "PLAYING" \
			or lifecycle.get("dark_mode") != captured_dark \
			or initial_context.get("dark_mode") != captured_dark \
			or snapshot.get("route_id") != "main" or initial_context.get("route_id") != "main" \
			or snapshot.get("active_app_id") != null or initial_context.get("active_app_id") != null \
			or snapshot.get("content_version") != initial_context.get("content_version") \
			or snapshot.get("narrative_checkpoint") != initial_context.get("dialogic_checkpoint") \
			or initial_context.get("audio_context") != {} \
			or snapshot.get("audio_context") != EMPTY_AUDIO_CONTEXT:
		return _fail(&"new_run_autosave_invalid", "Autosave snapshot is not the captured Day-1 main context")
	return {"ok": true, "code": &"ok", "value": autosave.duplicate(true)}


static func _canonical_text(value: Variant) -> String:
	var emitted: Dictionary = CANONICAL_WRITER.stringify(value)
	return str(emitted.get("value", "")) if emitted.get("ok", false) else ""


static func _canonical_sha256(value: Variant) -> String:
	var text := _canonical_text(value)
	return _sha256_text(text) if not text.is_empty() else ""


static func _sha256_text(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


static func _is_revision(value: Variant) -> bool:
	return value == "absent" or _is_sha256(value)


static func _is_sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or (value as String).length() != 64:
		return false
	for codepoint: int in (value as String).to_ascii_buffer():
		if not (codepoint >= 0x30 and codepoint <= 0x39) \
				and not (codepoint >= 0x61 and codepoint <= 0x66):
			return false
	return true


static func _has_exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for key: String in expected:
		if not value.has(key):
			return false
	return true


static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}

