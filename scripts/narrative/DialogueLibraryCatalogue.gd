extends RefCounted
## A read-only authored index. Production remains empty until checkpoint placement
## is approved. Registration validates bindings once; browsing never runs story code.
## Entries are in reading order; each thought follows its paired caption.

const WITNESSES := preload("res://scripts/profile/CaptionWitnessLedger.gd")

static var _passages: Array[Dictionary] = []
static var _witnesses_by_checkpoint: Dictionary = {}
static var _conditions: Dictionary = {}


static func configure(passages: Array, registered_beats: Array, checkpoints: Dictionary,
		condition_labels: Dictionary = {}) -> Dictionary:
	var registered := {}
	for beat: Variant in registered_beats:
		if not beat is Dictionary: return {"ok": false, "code": &"library_beat_invalid"}
		var described := WITNESSES.describe(beat)
		if not described.ok: return described
		registered[described.value.witness_id] = true
	for label: Variant in condition_labels:
		if not label is String or not _localized(condition_labels[label]):
			return {"ok": false, "code": &"library_condition_invalid"}
	var prepared: Array[Dictionary] = []
	var index := {}
	for passage: Variant in passages:
		if not passage is Dictionary or not passage.get("id") is String \
				or not checkpoints.has(passage.id) or index.has(passage.id) \
				or not _localized(passage.get("title")) or not passage.get("entries") is Array:
			return {"ok": false, "code": &"library_checkpoint_invalid"}
		var membership := {}
		var entries: Array[Dictionary] = []
		var caption_entry := ""
		for entry: Variant in passage.entries:
			if not entry is Dictionary or not entry.get("beat") is Dictionary \
					or entry.get("kind") not in ["caption", "thought"] \
					or not _localized(entry.get("text")) \
					or not _condition_valid(entry.get("requirements", {}), condition_labels):
				return {"ok": false, "code": &"library_entry_invalid"}
			var described := WITNESSES.describe(entry.beat)
			if not described.ok: return described
			var id: String = described.value.witness_id
			if not registered.has(id) or membership.has(id):
				return {"ok": false, "code": &"library_beat_unregistered"}
			if entry.kind == "caption":
				caption_entry = entry.beat.owning_entry_id
			elif caption_entry.is_empty() or caption_entry != entry.beat.owning_entry_id:
				return {"ok": false, "code": &"library_thought_unpaired"}
			membership[id] = true
			entries.append({"witness_id": id, "kind": entry.kind,
				"text": entry.text.duplicate(true), "requirements": entry.get("requirements", {}).duplicate(true)})
		index[passage.id] = membership
		prepared.append({"id": passage.id, "title": passage.title.duplicate(true), "entries": entries})
	_passages = prepared
	_witnesses_by_checkpoint = index
	_conditions = condition_labels.duplicate(true)
	return {"ok": true, "code": &"ok"}


## The caller supplies the actual currently presented checkpoint. Old read history
## and satisfied conditions cannot establish either arrival or exact reading.
static func discovery_for_beat(beat: Dictionary, checkpoint_id: String) -> Dictionary:
	if not _witnesses_by_checkpoint.has(checkpoint_id): return {}
	var described := WITNESSES.describe(beat)
	var witness_id := ""
	if described.ok and _witnesses_by_checkpoint[checkpoint_id].has(described.value.witness_id):
		witness_id = described.value.witness_id
	return {"checkpoint_id": checkpoint_id, "witness_id": witness_id}


static func reached_passages(discovery: Dictionary, locale: String = "en") -> Array[Dictionary]:
	var reached: Array = discovery.get("checkpoints", [])
	var witnessed: Dictionary = discovery.get("witnesses", {})
	var result: Array[Dictionary] = []
	for passage: Dictionary in _passages:
		if passage.id not in reached: continue
		var entries: Array[Dictionary] = []
		for entry: Dictionary in passage.entries:
			var read: bool = witnessed.has(entry.witness_id)
			entries.append({"read": read, "kind": entry.kind,
				"text": _text(entry.text, locale) if read else "",
				"requirements": _condition_text(entry.requirements, locale)})
		result.append({"id": passage.id, "title": _text(passage.title, locale), "entries": entries})
	return result


static func _localized(value: Variant) -> bool:
	if not value is Dictionary or not value.get("en") is String or value.en.is_empty(): return false
	for locale: Variant in value:
		if not locale is String or not value[locale] is String: return false
	return true


static func _condition_valid(value: Variant, labels: Dictionary) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if value.size() != 1: return false
	if value.has("label"): return value.label is String and labels.has(value.label)
	var key := "all" if value.has("all") else "any"
	if not value.get(key) is Array or value[key].is_empty(): return false
	for child: Variant in value[key]:
		if not _condition_valid(child, labels) or child.is_empty(): return false
	return true


static func _text(value: Dictionary, locale: String) -> String:
	return str(value.get(locale, value.en))


static func _condition_text(value: Dictionary, locale: String) -> String:
	if value.is_empty(): return ""
	if value.has("label"): return _text(_conditions[value.label], locale)
	var all_required: bool = value.has("all")
	var joiners := {"en": [" AND ", " OR "], "zh_HK": [" 且 ", " 或 "],
		"zh_CN": [" 且 ", " 或 "], "ja": [" かつ ", " または "], "ko": [" 그리고 ", " 또는 "]}
	var words: Array = joiners.get(locale, joiners.en)
	var pieces: PackedStringArray = []
	for child: Dictionary in value["all" if all_required else "any"]:
		pieces.append(_condition_text(child, locale))
	return "(" + str(words[0 if all_required else 1]).join(pieces) + ")"
