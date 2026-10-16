extends RefCounted
## Offline authoring only; never selects registration, routes, or mutates a live Run.
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")

## bindings[entry_id] = {target_id: existing scene target, next_marker_id: ordinary marker}.
## The last entry's marker is deliberately not changed: terminal/branch policy stays authored.
static func build(order: Array, source: Dictionary, bindings: Dictionary) -> Dictionary:
	if order.is_empty(): return _fail("sequence_empty", "At least one scene is required")
	var seen := {}
	for id: Variant in order:
		if not id is String or id.is_empty() or seen.has(id):
			return _fail("sequence_invalid", "Scene IDs must be unique nonempty strings")
		seen[id] = true
	var admitted: Dictionary = MANIFEST.validate_scene_registration(source)
	if not admitted.get("ok", false):
		return _fail("sequence_source_invalid", "Referenced content/registration refused: " + str(admitted))
	var bundle: Dictionary = source.duplicate(true)
	var entries := {}
	var programmes := {}
	var targets := {}
	for row: Dictionary in bundle.entry_manifest.entries: entries[row.entry_id] = row
	for row: Dictionary in bundle.scene_programme.entries: programmes[row.entry_id] = row
	for row: Dictionary in bundle.targets: targets[row.target_id] = row.target
	for id: String in order:
		if not entries.has(id): return _fail("sequence_entry_missing", id)
		var binding: Variant = bindings.get(id)
		if not binding is Dictionary or binding.size() != 2 \
				or not binding.get("target_id") is String or not binding.get("next_marker_id") is String:
			return _fail("sequence_binding_invalid", id)
		var target: Variant = targets.get(binding.target_id)
		if not target is Dictionary or target.kind != "scene" or target.entry_id != id:
			return _fail("sequence_target_invalid", id)
	if not bindings[order.back()].next_marker_id.is_empty():
		return _fail("sequence_terminal_required", "Final scene must have an explicitly authored terminal binding")
	for index in range(order.size() - 1):
		var id: String = order[index]
		var marker_id: String = bindings[id].next_marker_id
		var found := false
		for marker: Dictionary in programmes[id].markers:
			if marker.marker_id != marker_id: continue
			if marker.kind != "scene.transition":
				return _fail("sequence_marker_invalid", id + ": " + marker_id)
			marker.payload = {"target_id": bindings[order[index + 1]].target_id}
			found = true
		if not found: return _fail("sequence_marker_missing", id + ": " + marker_id)
	# Recompile through the retained owner; do not derive hashes from this helper's data.
	# Payload-only relinking may leave native program hashes unchanged.
	for id: String in entries:
		var programme: Dictionary = programmes[id]
		var compiled: Dictionary = ADAPTER.compile_scene_programme(
			entries[id].locators.en.path, id, entries.keys(), programme.markers)
		if not compiled.get("ok", false):
			return _fail("sequence_compile_failed", id + ": " + str(compiled))
		programme.content_sha256 = compiled.value.content_sha256
		programme.program_sha256 = compiled.value.program_sha256
	for target: Dictionary in targets.values():
		target.program_sha256 = programmes[target.entry_id].program_sha256
	var validated: Dictionary = MANIFEST.validate_scene_registration(bundle)
	if not validated.get("ok", false):
		return _fail("sequence_output_invalid", str(validated))
	return {"ok": true, "value": {"registration": bundle,
		"first_target_id": bindings[order[0]].target_id}}

static func _fail(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
