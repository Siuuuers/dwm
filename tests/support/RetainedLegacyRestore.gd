extends RefCounted
## Retained adapter/transaction fixtures bypass player format admission explicitly.
## This is not a player Load entry point or current-format acceptance evidence.
const READER := preload("res://scripts/validation/StrictJson.gd")
const MIGRATIONS := preload("res://scripts/infrastructure/save/SaveMigrations.gd")

static func prepare(manager: Node, kind: StringName, slot_id: int = -1) -> Dictionary:
	var locator: Dictionary = manager._resolve_locator(kind, slot_id)
	var read: Dictionary = manager._storage.inspect_revision(locator.relative_path)
	if not read.get("ok", false): return read
	var parsed: Dictionary = READER.parse_object(str(read.value.text))
	if not parsed.get("ok", false): return parsed
	var admitted: Dictionary = MIGRATIONS.migrate_document(parsed.value,
		{"kind": locator.kind, "slot_id": locator.slot_id})
	if not admitted.get("ok", false): return admitted
	return manager._prepare_restore_document(locator, admitted.value.document, admitted.value)
