class_name FrozenPresentationContext
extends RefCounted

## Exact, per-entry presentation schemas. Context never owns gameplay authority.
## The explicit registry is independent of transport tokens and historical signatures.
const REGISTRY_PATH := "res://data/manifests/dialogic_contexts.json"
const ENTRIES_PATH := "res://data/manifests/dialogic_entries.json"
const IDS_PATH := "res://data/manifests/dialogic_ids.json"
const DECK := preload("res://scripts/domain/relationship/PairDeckDraw.gd")
const PARTICIPANTS := ["priscilla", "lavinia"]
const ENUMS := {
	"friend": ["priscilla", "lavinia", "sylvia"],
	"tier": ["friend", "ambiguous", "love"], "tone": ["sweet", "dark"],
	"attitude": ["", "hostile", "upset", "amused", "affectionate", "seen", "fixated"],
	"ordinary_phase": ["awaiting_reply", "after_selection"],
	"group_state": ["INACTIVE", "AVAILABLE_UNOPENED", "REPLY_REQUIRED", "ACCEPTED", "RESOLVED_ATTENDED", "RESOLVED_MISSED", "RESOLVED_UNANSWERED", "RESOLVED_RUN_END"],
	"closure_state": ["RESOLVED_ATTENDED", "RESOLVED_MISSED", "RESOLVED_UNANSWERED", "RESOLVED_RUN_END", "hospital_care"],
	"miss_reason": ["nevermind", "missed_question", "busy", "judge", "prevented_by_fainting", "hospital_care"],
	"board_result": ["exploded", "cleared", "perfect"],
	"relationship_outcome": ["hatred", "upset", "amused", "loved", "foresight", "dark"],
	"hospital_cause": ["condition_hospital", "schedule_done"],
	"observation_form": ["full", "truncated"],
	"pair_count_status": ["pending_rollover", "committed"],
	"pair_form": ["ambiguous_sweet", "ambiguous_dark", "love_sweet", "love_dark"],
	"ending_role": ["primary", "epilogue", "special_prefix", "core", "pair_coda", "observer_coda"],
	"playback_mode": ["full", "residue"], "residue_variant": ["full", "residue"],
	"alone_cause": ["empty_done", "hospital_faint"],
}
static var _schemas: Dictionary = {}
static var _ids: Dictionary = {}

static func schema_for_entry(entry_id: String) -> Dictionary:
	var loaded := _load_registry()
	if not loaded.ok: return loaded
	if not _schemas.has(entry_id): return _fail("frozen_context_unknown_entry", entry_id)
	return _ok(_schemas[entry_id].duplicate(true))

static func build(entry_id: String, fields: Dictionary) -> Dictionary:
	var schema := schema_for_entry(entry_id)
	if not schema.ok: return schema
	return validate(entry_id, {"schema_id": schema.value.schema_id, "schema_version": 1,
		"fields": fields.duplicate(true)})

static func validate(entry_id: String, presentation: Variant) -> Dictionary:
	var schema := schema_for_entry(entry_id)
	if not schema.ok: return schema
	if not presentation is Dictionary or not _exact(presentation, ["fields", "schema_id", "schema_version"]) \
			or presentation.get("schema_id") != schema.value.schema_id \
			or typeof(presentation.get("schema_version")) != TYPE_INT or presentation.schema_version != 1 \
			or not presentation.get("fields") is Dictionary:
		return _fail("frozen_context_schema_mismatch", entry_id)
	var fields: Dictionary = presentation.fields
	if not _primitive(fields) or not _exact(fields, schema.value.fields.keys()):
		return _fail("frozen_context_field_set", entry_id)
	for key: String in fields:
		if not _field(fields[key], schema.value.fields[key]):
			return _fail("frozen_context_field_invalid", entry_id + ":" + key)
	var bound := _bindings(entry_id, fields)
	if not bound.ok: return bound
	return _ok(presentation.duplicate(true))

## Only this recursively detached projection is installed in Dialogic's variable tree.
static func immutable_fields(presentation: Dictionary) -> Dictionary:
	var detached: Dictionary = presentation.fields.duplicate(true)
	_freeze(detached)
	return detached

static func _field(value: Variant, descriptor: Variant) -> bool:
	if descriptor is Dictionary:
		if descriptor.has("const"):
			return value == descriptor["const"] and (typeof(value) == TYPE_INT if descriptor["const"] is float else typeof(value) == typeof(descriptor["const"]))
		return descriptor.has("enum") and value is String and value in descriptor["enum"]
	if not descriptor is String: return false
	if ENUMS.has(descriptor): return value is String and value in ENUMS[descriptor]
	match descriptor:
		"id": return value is String and not value.strip_edges().is_empty()
		"bool": return typeof(value) == TYPE_BOOL
		"no_residue": return value == null # No prior-attempt presentation is registered yet.
		"nullable_id": return value == null or _field(value, "id")
		"nullable_pair_friend": return value == null or (value is String and value in PARTICIPANTS)
		"ids":
			if not value is Array: return false
			var seen := {}
			for item: Variant in value:
				if not _field(item, "id") or seen.has(item): return false
				seen[item] = true
			return true
		"participants": return value is Array and value in [[], ["priscilla"], ["lavinia"], PARTICIPANTS]
		"contact_variation":
			return value is String and value in ["normal", "judgmental", "offer", "first_open_priscilla", "first_open_lavinia", "second_open_priscilla", "second_open_lavinia", "need_reply_priscilla_first", "need_reply_lavinia_first"]
		"perfect_reasons":
			return value is Array and value in [[], ["efficiency_gt_100"], ["efficiency_gte_100"], ["no_flag"], ["efficiency_gt_100", "no_flag"], ["efficiency_gte_100", "no_flag"]]
		"echoes":
			if not value is Array: return false
			var seen := {}
			for item: Variant in value:
				if not item is Dictionary or not _exact(item, ["echo_id", "presentation_atom_id"]) \
						or not _field(item.echo_id, "id") or not _field(item.presentation_atom_id, "id") \
						or seen.has(item.echo_id): return false
				seen[item.echo_id] = true
			return true
		"deck": return DECK.validate(value).get("ok", false)
		"nullable_pair_count": return value == null or _field(value, "pair_count")
		"pair_count":
			return value is Dictionary and _exact(value, ["transaction_id", "outcome", "counts", "visible"]) \
				and _field(value.transaction_id, "id") and value.outcome in ["prevented", "private_offscreen", "private_visible", "group", "missed"] \
				and typeof(value.counts) == TYPE_BOOL and typeof(value.visible) == TYPE_BOOL
		"progression":
			return value is Dictionary and _exact(value, ["evaluated", "promotion_applied", "relationship_state"]) \
				and typeof(value.evaluated) == TYPE_BOOL and typeof(value.promotion_applied) == TYPE_BOOL \
				and _field(value.relationship_state, "tier")
		"nullable_group_variation":
			if value == null: return true
			return value is Dictionary and _exact(value, ["action_state", "inviter_id", "opened_ids", "replied_ids", "contact_variation"]) \
				and _field(value.action_state, "group_state") and _field(value.inviter_id, "nullable_pair_friend") \
				and _field(value.opened_ids, "participants") and _field(value.replied_ids, "participants") \
				and (value.contact_variation == null or _field(value.contact_variation, "contact_variation"))
	return false

static func _bindings(entry_id: String, fields: Dictionary) -> Dictionary:
	if fields.has("pair_count_status") and (fields.pair_count_receipt == null) != (fields.pair_count_status == "pending_rollover"):
		return _fail("frozen_context_pair_count_mismatch", entry_id)
	if fields.has("board_result"):
		if (fields.board_result == "perfect") != not fields.perfect_reasons.is_empty(): return _fail("frozen_context_result_mismatch", entry_id)
		if fields.has("observation_form") and (fields.observation_form != ("truncated" if fields.board_result == "exploded" else "full") \
				or fields.combination_witness_capability != (fields.board_result != "exploded")):
			return _fail("frozen_context_result_mismatch", entry_id)
		if fields.has("relationship_outcome"):
			var expected: Array = ["hatred", "upset", "amused"] if fields.board_result == "exploded" else ["dark", "foresight" if fields.board_result == "perfect" else "loved"]
			if fields.relationship_outcome not in expected: return _fail("frozen_context_result_mismatch", entry_id)
	for echo: Dictionary in fields.get("due_echoes", []):
		var found := false
		for atom: Dictionary in _ids.get("atoms", []):
			if atom.get("atom_id") == echo.presentation_atom_id and atom.get("echo_id") == echo.echo_id \
					and entry_id in atom.get("presented_in_entry_ids", []): found = true
		if not found: return _fail("frozen_context_echo_mismatch", entry_id)
	if fields.get("entry_role") == "ordinary_message":
		if fields.phase == "awaiting_reply":
			if fields.selected_reply_id != null or fields.witnessed_line_id != null: return _fail("frozen_context_reply_mismatch", entry_id)
		else:
			var reply_found := false
			var line_found := false
			for row: Dictionary in _ids.get("reply_ids", []):
				if row.owning_entry_id == entry_id and row.reply_id == fields.selected_reply_id: reply_found = true
			for row: Dictionary in _ids.get("reply_lines", []):
				if row.owning_entry_id == entry_id and row.line_id == fields.witnessed_line_id: line_found = true
			if not reply_found or not line_found or str(fields.selected_reply_id).get_slice(".", 4) != str(fields.witnessed_line_id).get_slice(".", 6):
				return _fail("frozen_context_reply_mismatch", entry_id)
	return _ok({})

static func _load_registry() -> Dictionary:
	if not _schemas.is_empty(): return _ok({})
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
	var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENTRIES_PATH))
	var ids: Variant = JSON.parse_string(FileAccess.get_file_as_string(IDS_PATH))
	if not registry is Dictionary or registry.get("schema_version") != 1 \
			or registry.get("kind") != "dialogic_frozen_context_registry" or not registry.get("schemas") is Array \
			or not entries is Dictionary or not entries.get("entries") is Array or not ids is Dictionary:
		return _fail("frozen_context_registry_invalid", REGISTRY_PATH)
	var compiled := {}
	for row: Variant in registry.schemas:
		if not row is Dictionary or not _exact(row, ["schema_id", "schema_version", "entry_id", "fields"]) \
				or not row.get("entry_id") is String or compiled.has(row.entry_id) \
				or not row.get("fields") is Dictionary or row.schema_version != 1:
			return _fail("frozen_context_registry_invalid", REGISTRY_PATH)
		compiled[row.entry_id] = row
	if compiled.size() != entries.entries.size(): return _fail("frozen_context_registry_invalid", "entry coverage")
	for entry: Dictionary in entries.entries:
		var row: Dictionary = compiled.get(entry.entry_id, {})
		if row.get("schema_id") != entry.context_schema_id \
				or row.get("fields", {}).get("entry_id") != {"const": entry.entry_id} \
				or row.get("fields", {}).get("entry_role") != {"const": entry.role}:
			return _fail("frozen_context_registry_invalid", entry.entry_id)
	_schemas = compiled
	_ids = ids
	return _ok({})

static func _primitive(value: Variant, depth: int = 0) -> bool:
	if depth > 32: return false
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not _primitive(value[key], depth + 1): return false
		return true
	if value is Array:
		for child: Variant in value:
			if not _primitive(child, depth + 1): return false
		return true
	return typeof(value) in [TYPE_NIL, TYPE_STRING, TYPE_INT, TYPE_BOOL]

static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for child: Variant in value.values(): _freeze(child)
		value.make_read_only()
	elif value is Array:
		for child: Variant in value: _freeze(child)
		value.make_read_only()

static func _exact(value: Dictionary, expected: Array) -> bool:
	var keys := value.keys()
	keys.sort()
	var other := expected.duplicate()
	other.sort()
	return keys == other

static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "value": value}

static func _fail(code: String, detail: String) -> Dictionary:
	return {"ok": false, "code": StringName(code), "message": detail}
