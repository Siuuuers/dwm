class_name CaptionWitnessLedger
extends RefCounted

const REGISTRY := preload("res://scripts/narrative/NarrativeCaptionRegistry.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

static func describe(beat: Dictionary) -> Dictionary:
	if not REGISTRY.valid_beat(beat): return _fail(&"invalid_caption_witness")
	var encoded := WRITER.stringify(beat)
	if not encoded.ok: return _fail(&"invalid_caption_witness")
	return {"ok": true, "value": {"witness_id": str(encoded.value).sha256_text(),
		"canonical_text": encoded.value}}


static func admit(beat: Dictionary, registry: Dictionary) -> Dictionary:
	var described := describe(beat)
	if not described.ok: return described
	var checked := REGISTRY.check_document(registry)
	if not checked.ok: return _fail(&"invalid_caption_witness_registry")
	for row: Dictionary in registry.beats:
		var encoded := WRITER.stringify(row)
		if not encoded.ok: return _fail(&"invalid_caption_witness_registry")
		if encoded.value == described.value.canonical_text:
			described.value.beat = beat.duplicate(true)
			return described
	return _fail(&"unregistered_caption_variant")


static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary: return _fail(&"invalid_caption_witness_ledger")
	for key: Variant in value:
		if not key is String or not value[key] is Dictionary:
			return _fail(&"invalid_caption_witness_ledger")
		var described := describe(value[key])
		if not described.ok or described.value.witness_id != key:
			return _fail(&"invalid_caption_witness_ledger")
	return {"ok": true}


static func contains(ledger: Dictionary, beat: Dictionary) -> bool:
	var described := describe(beat)
	return described.ok and ledger.has(described.value.witness_id) \
		and ledger[described.value.witness_id] == beat


static func preserves(before: Dictionary, after: Dictionary) -> bool:
	for key: String in before:
		if not after.has(key) or after[key] != before[key]: return false
	return true


static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "path": "witnessed_caption_variants"}
