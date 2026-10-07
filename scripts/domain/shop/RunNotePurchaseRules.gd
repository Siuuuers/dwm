extends RefCounted
## Pure preparation only: the caller owns durable commit and publication.
## Counts are a bounded input map, not a definition of the persisted save schema.

const ITEM_IDS: Array[String] = [
	"crystal_stutters",
	"inked_silk_string",
	"letter_with_wax_seal",
]
const COST: int = 45
const PURCHASE_CAP: int = 3


static func prepare(
	item_id: Variant,
	quantity: Variant,
	money: Variant,
	counts: Variant,
	catalogue: Variant
) -> Dictionary:
	if typeof(item_id) != TYPE_STRING and typeof(item_id) != TYPE_STRING_NAME:
		return _refuse("invalid_item_id")
	var normalized_id: String = String(item_id)
	if not ITEM_IDS.has(normalized_id):
		return _refuse("invalid_item_id")
	if typeof(quantity) != TYPE_INT or quantity != 1:
		return _refuse("invalid_quantity")
	if typeof(money) != TYPE_INT or money < 0:
		return _refuse("invalid_money")
	var validation: Dictionary = validate_counts_and_catalogue(counts, catalogue)
	if not validation["ok"]:
		return validation
	var validated: Dictionary = validation["value"]
	var candidate_counts: Dictionary = validated["shop_purchase_counts"]
	var owned_count: int = candidate_counts.get(normalized_id, 0)
	if owned_count >= PURCHASE_CAP:
		return _refuse("purchase_cap_reached")
	if money < COST:
		return _refuse("insufficient_funds")
	var registered_catalogue: Dictionary = validated["catalogue"]
	var registered_notes: Array = registered_catalogue[normalized_id]
	var unlocked_notes: Array = registered_notes.slice(0, owned_count + 1).duplicate(true)
	var next_note: Dictionary = registered_notes[owned_count].duplicate(true)
	candidate_counts[normalized_id] = owned_count + 1
	return _accept({
		"candidate": {
			"money": money - COST,
			"shop_purchase_counts": candidate_counts,
		},
		"item_id": normalized_id,
		"note": next_note,
		"notes": unlocked_notes,
	})


## The one validation seam shared by purchasing and Notes projection.
## Missing counts remain absent and mean zero. Unrelated valid counts survive.
## Catalogue registration is explicit; no production or placeholder text is supplied.
static func validate_counts_and_catalogue(counts: Variant, catalogue: Variant) -> Dictionary:
	if typeof(counts) != TYPE_DICTIONARY:
		return _refuse("invalid_counts")
	var supplied_counts: Dictionary = counts
	var detached_counts: Dictionary = {}
	for key: Variant in supplied_counts:
		if typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME:
			return _refuse("invalid_counts")
		var normalized_key: String = String(key)
		if detached_counts.has(normalized_key):
			return _refuse("invalid_counts")
		var count: Variant = supplied_counts[key]
		if typeof(count) != TYPE_INT or count < 0:
			return _refuse("invalid_counts")
		if ITEM_IDS.has(normalized_key) and count > PURCHASE_CAP:
			return _refuse("invalid_counts")
		detached_counts[normalized_key] = count
	if typeof(catalogue) != TYPE_DICTIONARY:
		return _refuse("invalid_catalogue")
	var supplied_catalogue: Dictionary = catalogue
	for item: String in ITEM_IDS:
		if not supplied_catalogue.has(item):
			return _refuse("missing_note_content")
	if supplied_catalogue.size() != ITEM_IDS.size():
		return _refuse("invalid_catalogue")
	for key: Variant in supplied_catalogue:
		if typeof(key) != TYPE_STRING or not ITEM_IDS.has(key):
			return _refuse("invalid_catalogue")
	var detached_catalogue: Dictionary = {}
	var seen_note_ids: Dictionary = {}
	for item: String in ITEM_IDS:
		var raw_notes: Variant = supplied_catalogue[item]
		if typeof(raw_notes) != TYPE_ARRAY:
			return _refuse("invalid_catalogue")
		var supplied_notes: Array = raw_notes
		if supplied_notes.size() < PURCHASE_CAP:
			return _refuse("missing_note_content")
		if supplied_notes.size() != PURCHASE_CAP:
			return _refuse("invalid_catalogue")
		var detached_notes: Array = []
		for raw_note: Variant in supplied_notes:
			if typeof(raw_note) != TYPE_DICTIONARY:
				return _refuse("invalid_catalogue")
			var supplied_note: Dictionary = raw_note
			if not supplied_note.has("id") or not supplied_note.has("text"):
				return _refuse("missing_note_content")
			if supplied_note.size() != 2:
				return _refuse("invalid_catalogue")
			var note_id: Variant = supplied_note["id"]
			var note_text: Variant = supplied_note["text"]
			if typeof(note_id) != TYPE_STRING or typeof(note_text) != TYPE_STRING:
				return _refuse("invalid_catalogue")
			if String(note_id).strip_edges().is_empty() or String(note_text).strip_edges().is_empty():
				return _refuse("missing_note_content")
			if seen_note_ids.has(note_id):
				return _refuse("invalid_catalogue")
			seen_note_ids[note_id] = true
			detached_notes.append({"id": note_id, "text": note_text})
		detached_catalogue[item] = detached_notes
	return _accept({
		"shop_purchase_counts": detached_counts,
		"catalogue": detached_catalogue,
	})


static func _accept(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": "", "value": value}


static func _refuse(code: String) -> Dictionary:
	return {"ok": false, "code": code, "value": {}}
