class_name DatingRehearsalAdmission
extends RefCounted

const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")

## Reached means this exact presentation, never another outcome of the same date.
static func prepare(request: Dictionary, records: Array, completed_ending: bool) -> Dictionary:
	if not completed_ending: return _fail("rehearsal_milestone_required")
	if request.size() != 2 or not request.get("signature_id") is String or not request.get("signature") is Dictionary:
		return _fail("invalid_rehearsal_source")
	var checked: Dictionary = SIGNATURE.validate(request.signature)
	if not checked.ok or checked.value.signature_id != request.signature_id:
		return _fail("invalid_rehearsal_source")
	var found := false
	for row: Variant in records:
		if row is Dictionary and row.get("signature_id") == request.signature_id:
			if row.get("signature") != request.signature: return _fail("invalid_rehearsal_source")
			found = true
	if not found: return _fail("presentation_not_reached")
	var entry: Dictionary = SIGNATURE.entry_record(request.signature.entry_id).value
	if entry.role not in ["solo_pre_challenge", "pair_pre_challenge_scene"]:
		return _fail("rehearsal_requires_pre_challenge")
	var parts: PackedStringArray = str(entry.entry_id).split(".")
	if parts.size() != 5 or parts[0] != "dating": return _fail("invalid_rehearsal_source")
	var kind: String = "twofriends_if_deferred" if parts[1] == "twofriends" else parts[1]
	var participants: Array = [parts[2]] if kind == "solo" else ["priscilla", "lavinia"]
	if kind not in ["solo", "group", "twofriends_if_deferred"]:
		return _fail("invalid_rehearsal_source")
	if kind != "solo" and request.signature.fields.pair_mode != kind:
		return _fail("invalid_rehearsal_source")
	return {"ok": true, "value": {"signature": request.signature.duplicate(true),
		"signature_id": request.signature_id,
		"context": {"kind": kind, "participants": participants, "day": int(entry.day)}}}

static func _fail(code: String) -> Dictionary:
	return {"ok": false, "code": StringName(code), "message": ""}
