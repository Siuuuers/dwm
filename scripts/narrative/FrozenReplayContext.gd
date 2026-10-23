class_name FrozenReplayContext
extends RefCounted

## Replay has the exact historical signature as its sole fact source. This is a
## separate schema from a canonical run projection: absent historical selectors
## and inapplicable run receipts are both omitted, never reconstructed from Run.
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")

static func build(signature: Dictionary, mode: String = "gallery_replay") -> Dictionary:
	if mode not in ["gallery_replay", "date_rehearsal"]: return _fail(&"frozen_replay_mode_invalid")
	var checked := SIGNATURE.validate(signature)
	if not checked.ok: return checked
	var entry: Dictionary = SIGNATURE.entry_record(signature.entry_id).value
	if mode == "date_rehearsal" and entry.role not in ["solo_pre_challenge", "solo_post_challenge", "pair_pre_challenge_scene", "pair_post_challenge_scene"]:
		return _fail(&"frozen_replay_mode_invalid")
	var fields: Dictionary = signature.fields.duplicate(true)
	fields.merge({"entry_id": signature.entry_id, "entry_role": entry.role,
		"context_source": "reached_signature", "execution_mode": mode})
	if entry.day != null: fields["day"] = int(entry.day)
	if entry.ending_id != null: fields["ending_id"] = entry.ending_id
	# Aliases carry the same saved facts under canonical prose names. They never
	# turn a legacy signature into a complete canonical context.
	if entry.role == "solo_ending_step": fields["stored_tone"] = fields.tone
	if entry.role in ["solo_ending_step", "pair_ending_step", "alone_step"]:
		fields["playback_mode"] = "residue" if str(fields.ending_form).ends_with("_residue") else "full"
	if entry.role == "pair_ending_step":
		fields["stable_combination"] = fields.pair_form
		fields["deck_tone"] = "dark" if str(fields.pair_form).ends_with("_dark") else "sweet"
	return {"ok": true, "value": {"schema_id": "replay_signature." + str(signature.entry_id) + ".v1",
		"schema_version": 1, "fields": fields}}

static func validate(presentation: Variant, signature: Dictionary, mode: String = "gallery_replay") -> Dictionary:
	var expected := build(signature, mode)
	if not expected.ok: return expected
	if not presentation is Dictionary or not FROZEN._primitive(presentation) \
			or typeof(presentation.get("schema_version")) != TYPE_INT or presentation != expected.value:
		return _fail(&"frozen_replay_signature_mismatch")
	return expected

static func immutable_fields(signature: Dictionary, mode: String = "gallery_replay") -> Dictionary:
	var built := build(signature, mode)
	if not built.ok: return built
	return {"ok": true, "value": FROZEN.immutable_fields(built.value)}

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}
