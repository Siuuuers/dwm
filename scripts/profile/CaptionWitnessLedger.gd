class_name CaptionWitnessLedger
extends RefCounted
## Profile membership for exact registered caption variants. Occurrence, run and
## playback identities belong to the caller's custody proof, never this ledger.

const REGISTRY := preload("res://scripts/narrative/NarrativeCaptionRegistry.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

static func describe(beat: Dictionary) -> Dictionary:
	if not REGISTRY.valid_beat(beat): return _fail(&"invalid_caption_witness")
	var encoded := WRITER.stringify(beat)
	if not encoded.ok: return _fail(&"invalid_caption_witness")
	return {"ok": true, "value": {"witness_id": str(encoded.value).sha256_text(),
		"canonical_text": encoded.value, "beat": beat.duplicate(true)}}


## Registry shape and exact membership are necessary here. The presentation
## owner must additionally prove that this row is the accepted visible occurrence.
static func admit(beat: Dictionary, registry: Dictionary) -> Dictionary:
	var described := describe(beat)
	if not described.ok: return described
	var entries: Array = []
	var rows: Variant = registry.get("beats")
	if not rows is Array: return _fail(&"invalid_caption_witness_registry")
	for row: Variant in rows:
		if not REGISTRY.valid_beat(row): return _fail(&"invalid_caption_witness_registry")
		if not entries.has(row.owning_entry_id): entries.append(row.owning_entry_id)
	var checked := REGISTRY.validate_document(registry, entries)
	if not checked.ok: return _fail(&"invalid_caption_witness_registry")
	for row: Dictionary in checked.value.beats:
		var registered := describe(row)
		if not registered.ok: return _fail(&"invalid_caption_witness_registry")
		if registered.value.canonical_text == described.value.canonical_text:
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
	return {"ok": true, "value": value.duplicate(true)}


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
