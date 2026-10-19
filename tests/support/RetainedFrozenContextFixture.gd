extends RefCounted

## Historical test dependency only: never selects or changes live story registration.
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
var _previous_schemas: Dictionary
var _previous_ids: Dictionary
var _installed := false

func install(entry_ids: Array) -> Dictionary:
	if _installed: return {"ok": false, "message": "retained fixture already installed"}
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string(FROZEN.REGISTRY_PATH))
	var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(FROZEN.ENTRIES_PATH))
	var ids: Variant = JSON.parse_string(FileAccess.get_file_as_string(FROZEN.IDS_PATH))
	if not registry is Dictionary or registry.get("schema_version") != 1 \
			or registry.get("kind") != "dialogic_frozen_context_registry" \
			or not registry.get("schemas") is Array or not entries is Dictionary \
			or not entries.get("entries") is Array or not ids is Dictionary:
		return {"ok": false, "message": "invalid retained registry documents"}
	var selected := {}
	for entry_id: String in entry_ids:
		var rows: Array = registry.schemas.filter(func(row: Variant) -> bool:
			return row is Dictionary and row.get("entry_id") == entry_id)
		var declarations: Array = entries.entries.filter(func(entry: Variant) -> bool:
			return entry is Dictionary and entry.get("entry_id") == entry_id)
		if rows.size() != 1 or declarations.size() != 1 or selected.has(entry_id):
			return {"ok": false, "message": "missing or duplicate retained entry: " + entry_id}
		var row: Dictionary = rows[0]
		var entry: Dictionary = declarations[0]
		if not FROZEN._exact(row, ["schema_id", "schema_version", "entry_id", "fields"]) \
				or row.get("schema_version") != 1 or not row.get("fields") is Dictionary \
				or not row.get("schema_id") is String or not entry.get("role") is String \
				or row.schema_id != entry.get("context_schema_id") \
				or row.fields.get("entry_id") != {"const": entry_id} \
				or row.fields.get("entry_role") != {"const": entry.role}:
			return {"ok": false, "message": "invalid retained schema binding: " + entry_id}
		selected[entry_id] = row.duplicate(true)
	if selected.is_empty():
		return {"ok": false, "message": "retained fixture needs explicit entries"}
	# Retain references, not copies: teardown reinstates the exact prior cache objects.
	_previous_schemas = FROZEN._schemas
	_previous_ids = FROZEN._ids
	FROZEN._schemas = selected
	FROZEN._ids = ids.duplicate(true)
	_installed = true
	return {"ok": true}

func restore() -> void:
	if not _installed: return
	FROZEN._schemas = _previous_schemas
	FROZEN._ids = _previous_ids
	_installed = false
