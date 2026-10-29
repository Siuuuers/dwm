class_name ArtManifest
extends RefCounted
## Optional artwork is explicit presentation data; it never changes gameplay or saved facts.
const PLACEMENTS_PATH := "res://data/manifests/art_placements.json"
const IMAGE_EXTENSIONS := ["png", "svg", "webp", "jpg", "jpeg"]
static var _placements: Dictionary = {}
static var _placements_loaded := false
static var _overlay_records: Dictionary = {}

static func reload_placements(path: String = PLACEMENTS_PATH) -> bool:
	_placements = {}
	_placements_loaded = true
	_overlay_records.clear()
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema_version") != 1:
		return false
	if not parsed.get("assets") is Dictionary or not parsed.get("scenes") is Dictionary:
		return false
	_placements = parsed
	return true

static func _catalog() -> Dictionary:
	if not _placements_loaded:
		reload_placements()
	return _placements

static func _asset(asset_id: String) -> Dictionary:
	var catalog := _catalog()
	var value: Variant = _overlay_records.get(asset_id, catalog.get("assets", {}).get(asset_id, {}))
	return value if value is Dictionary else {}

static func _key(category: String, asset_id: String) -> String:
	return asset_id if category.is_empty() else category + "." + asset_id

static func get_asset_path(asset_id: String) -> String:
	return str(_asset(asset_id).get("path", ""))

# Compatibility for the older instance API; preloaded scripts also have Resource.get_path().
static func get_path(category: String, asset_id: String) -> String:
	return get_asset_path(_key(category, asset_id))

static func get_texture(asset_id: String, expected_size: Vector2i = Vector2i.ZERO) -> Texture2D:
	var path := str(_asset(asset_id).get("path", ""))
	if not path.begins_with("res://") or not IMAGE_EXTENSIONS.has(path.get_extension().to_lower()):
		return null
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var texture := load(path) as Texture2D
	if texture == null or (expected_size != Vector2i.ZERO and texture.get_size() != Vector2(expected_size)):
		return null
	return texture

static func uses_split_panels(entry_id: String) -> bool:
	var placement: Variant = _catalog().get("scenes", {}).get(entry_id, {})
	return placement is Dictionary and placement.get("split_panels", false) == true

static func get_scene_art(entry_id: String) -> Dictionary:
	var value: Variant = _catalog().get("scenes", {}).get(entry_id, {})
	if not value is Dictionary:
		return {"background": "", "portraits": [], "cg": ""}
	var portraits: Array[String] = []
	var raw: Variant = value.get("portraits", [])
	if raw is Array:
		for portrait: Variant in raw:
			if portrait is String and portraits.size() < 2:
				portraits.append(portrait)
	return {"background": str(value.get("background", "")), "portraits": portraits,
		"cg": str(value.get("cg", ""))}

## Explicit entry-label bindings; absent entries do not imply checkpoint arrival.
static func get_presentation_commands(entry_id: String) -> Dictionary:
	var entries: Variant = _catalog().get("presentation_entries", {})
	if entries is Dictionary:
		var commands: Variant = entries.get(entry_id, [])
		if commands is Array:
			var valid := true
			for command: Variant in commands:
				if not command is Dictionary or command.get("kind") not in ["checkpoint", "show", "remove"] \
						or not command.get("id") is String or command.id.is_empty():
					valid = false
					break
			if valid: return {"ok": true, "value": commands.duplicate(true)}
	return {"ok": false, "code": &"reading_content_error",
		"message": "Invalid presentation commands at entry: " + entry_id,
		"details": {"entry_id": entry_id}}

## Apply one authored arrival to detached live state. Load calls resolution only.
static func apply_entry_presentation(entry_id: String, previous: Dictionary) -> Dictionary:
	var commands := get_presentation_commands(entry_id)
	if not commands.ok: return commands
	var state := previous.duplicate(true)
	var autosave := false
	for command: Dictionary in commands.value:
		match command.get("kind", ""):
			"checkpoint":
				state = {"checkpoint_id": command.id, "overlays": []}
				autosave = true
			"show", "remove":
				if state.is_empty():
					return {"ok": false, "code": &"presentation_checkpoint_required", "reference": entry_id}
				if command.kind == "show":
					if not state.overlays.has(command.id): state.overlays.append(command.id)
				else:
					state.overlays.erase(command.id)
			_:
				return {"ok": false, "code": &"presentation_command_invalid", "reference": entry_id}
	if not state.is_empty():
		var resolved := resolve_saved_presentation(state)
		if not resolved.ok: return resolved
	return {"ok": true, "value": {"state": state, "autosave": autosave}}

## Inline story commands resolve once into the Run-owned visible state.
static func validate_presentation_commands(commands: Array) -> Dictionary:
	for command: Dictionary in commands:
		if command.kind == "background" and _asset(command.id).is_empty():
			return _presentation_reference_error("background", command.id)
		if command.kind == "show":
			var preset: Dictionary = _catalog().get("overlay_labels", {}).get(command.id, {})
			if preset.is_empty() or _asset(str(preset.get("asset_id", ""))).is_empty() \
					or not preset.get("rect") is Array or preset.rect.size() != 4:
				return _presentation_reference_error("overlay", command.id)
			for component: Variant in preset.rect:
				if typeof(component) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)):
					return _presentation_reference_error("overlay rectangle", command.id)
			if preset.rect[2] <= 0 or preset.rect[3] <= 0:
				return _presentation_reference_error("overlay rectangle", command.id)
	return {"ok": true}

static func make_scene_presentation(entry_id: String) -> Dictionary:
	var state := get_scene_art(entry_id)
	state.merge({"checkpoint_id": "", "scene_entry_id": entry_id, "split_panels": uses_split_panels(entry_id),
		"audio_plan_id": "", "overlays": []})
	return state

static func apply_presentation_commands(commands: Array, previous: Dictionary) -> Dictionary:
	if commands.is_empty(): return {"ok": true, "value": {"state": previous.duplicate(true), "autosave": false}}
	var state: Dictionary
	if previous.is_empty():
		state = {"checkpoint_id": "", "scene_entry_id": "", "background": "", "portraits": [],
			"cg": "", "split_panels": false, "audio_plan_id": "", "overlays": []}
	elif previous.has("background"):
		state = previous.duplicate(true)
	else:
		var resolved := resolve_saved_presentation(previous)
		if not resolved.ok: return resolved
		state = resolved.value.duplicate(true)
		for overlay: Dictionary in state.overlays:
			if not overlay.has("slot"): overlay["slot"] = overlay.label
	var autosave := false
	for command: Dictionary in commands:
		match command.kind:
			"background": state.background = command.id
			"checkpoint":
				state.checkpoint_id = command.id
				autosave = true
			"show":
				var preset: Dictionary = _catalog().get("overlay_labels", {}).get(command.id, {})
				if preset.is_empty(): return _presentation_reference_error("overlay", command.id)
				var overlay := {"slot": command.slot, "label": command.id,
					"asset_id": preset.asset_id, "rect": preset.rect.duplicate()}
				var position := -1
				for index: int in state.overlays.size():
					if state.overlays[index].slot == command.slot: position = index
				if position < 0: state.overlays.append(overlay)
				else: state.overlays[position] = overlay
			"hide":
				for index: int in range(state.overlays.size() - 1, -1, -1):
					if state.overlays[index].slot == command.slot: state.overlays.remove_at(index)
	return {"ok": true, "value": {"state": state, "autosave": autosave}}

## Load resolves the saved visible selection directly, never executing commands.
static func resolve_saved_presentation(state: Dictionary) -> Dictionary:
	if state.is_empty(): return {"ok": true, "value": {}}
	if not state.has("background"):
		if state.size() != 2 or not state.get("checkpoint_id") is String or not state.get("overlays") is Array:
			return _presentation_reference_error("saved presentation", "shape")
		return resolve_presentation(state.checkpoint_id, state.overlays)
	if state.size() != 8 or not state.get("checkpoint_id") is String or not state.get("scene_entry_id") is String \
			or not state.get("background") is String or not state.get("portraits") is Array \
			or not state.get("cg") is String or not state.get("split_panels") is bool \
			or not state.get("audio_plan_id") is String or not state.get("overlays") is Array:
		return _presentation_reference_error("saved presentation", "shape")
	var slots := {}
	for overlay: Variant in state.overlays:
		if not overlay is Dictionary or overlay.size() != 4 or not overlay.get("slot") is String \
				or not overlay.get("label") is String or not overlay.get("asset_id") is String \
				or not overlay.get("rect") is Array or overlay.rect.size() != 4 or slots.has(overlay.slot):
			return _presentation_reference_error("saved overlay", "shape")
		for component: Variant in overlay.rect:
			if typeof(component) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)):
				return _presentation_reference_error("saved overlay", "rectangle")
		if overlay.rect[2] <= 0 or overlay.rect[3] <= 0:
			return _presentation_reference_error("saved overlay", "rectangle")
		slots[overlay.slot] = true
	for portrait: Variant in state.portraits:
		if not portrait is String: return _presentation_reference_error("saved portrait", "shape")
	return {"ok": true, "value": state.duplicate(true)}

## Named checkpoints reuse the existing scene art and audio plan identities. This
## resolves saved presentation directly; it never enters a checkpoint or saves.
static func resolve_presentation(checkpoint_id: String, overlay_labels: Array) -> Dictionary:
	var catalog := _catalog()
	var checkpoints: Variant = catalog.get("presentation_checkpoints", {})
	if not checkpoints is Dictionary: return _presentation_reference_error("checkpoint", checkpoint_id)
	var checkpoint: Variant = checkpoints.get(checkpoint_id)
	if not checkpoint is Dictionary or not checkpoint.get("scene_entry_id") is String \
			or not checkpoint.get("audio_plan_id") is String:
		return _presentation_reference_error("checkpoint", checkpoint_id)
	var entry_id: String = checkpoint.scene_entry_id
	if not catalog.scenes.has(entry_id):
		return _presentation_reference_error("scene", entry_id)
	var overlays: Array = []
	var seen := {}
	for label: Variant in overlay_labels:
		if not label is String or seen.has(label):
			return {"ok": false, "code": &"presentation_overlay_invalid", "reference": str(label)}
		var labels: Variant = catalog.get("overlay_labels", {})
		if not labels is Dictionary: return _presentation_reference_error("overlay", label)
		var overlay: Variant = labels.get(label)
		if not overlay is Dictionary or not overlay.get("asset_id") is String \
				or not overlay.get("rect") is Array or overlay.rect.size() != 4:
			return _presentation_reference_error("overlay", label)
		for component: Variant in overlay.rect:
			if typeof(component) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)):
				return {"ok": false, "code": &"presentation_overlay_invalid", "reference": label}
		if overlay.rect[2] <= 0 or overlay.rect[3] <= 0:
			return {"ok": false, "code": &"presentation_overlay_invalid", "reference": label}
		seen[label] = true
		overlays.append({"label": label, "asset_id": overlay.asset_id, "rect": overlay.rect.duplicate()})
	var presentation := get_scene_art(entry_id)
	presentation.merge({"checkpoint_id": checkpoint_id, "scene_entry_id": entry_id,
		"split_panels": uses_split_panels(entry_id), "audio_plan_id": checkpoint.audio_plan_id,
		"overlays": overlays})
	return {"ok": true, "value": presentation}

static func _presentation_reference_error(kind: String, reference: String) -> Dictionary:
	return {"ok": false, "code": &"reading_content_error", "reference": reference,
		"message": "Required presentation %s is missing: %s" % [kind, reference],
		"details": {"reference_kind": kind, "reference_id": reference}}

static func get_expected_art_paths() -> Dictionary:
	var result: Dictionary = {}
	var assets: Dictionary = _catalog().get("assets", {}).duplicate(true)
	assets.merge(_overlay_records, true)
	for asset_id: String in assets:
		result[asset_id] = str(_asset(asset_id).get("path", ""))
	return result

static func get_expected_size(path: String) -> Vector2i:
	for asset_id: String in get_expected_art_paths():
		var record := _asset(asset_id)
		if str(record.get("path", "")) != path:
			continue
		var dimensions: Variant = record.get("size", [])
		if dimensions is Array and dimensions.size() == 2:
			return Vector2i(int(dimensions[0]), int(dimensions[1]))
	return Vector2i.ZERO

static func get_daily_main_scene_paths(day: int) -> Dictionary:
	var result: Dictionary = {}
	var scenes: Dictionary = _catalog().get("scenes", {})
	for entry_id: String in scenes:
		var record: Variant = scenes[entry_id]
		if record is Dictionary and record.get("day") == day:
			result[entry_id] = get_asset_path(str(record.get("background", "")))
	return result

static func get_missing_art_report() -> Dictionary:
	var result: Dictionary = {}
	for asset_id: String in get_expected_art_paths():
		if get_texture(asset_id) == null:
			result[asset_id] = get_asset_path(asset_id)
	return result

## Temporary presentation overrides support art previews without writing the catalog or saves.
static func set_overlay_info(category: String, asset_id: String, path: String,
		expected_size: Vector2i, status: String) -> void:
	_catalog()
	_overlay_records[_key(category, asset_id)] = {"path": path,
		"size": [expected_size.x, expected_size.y], "status": status}

# ---- Semantic visual identity (Phase 01 Task 6, DEVIATION-11 Ruling C) ----
# Required narrative visual records retain their original validation contract.
# Optional placements above are separate from required playback dependencies.

## The record's EXACT closed field set, sorted. Plan Task 6 fixes these five and no others.
const VISUAL_RECORD_FIELDS := ["fallback_visual_id", "required", "resource_path", "resource_type", "visual_id"]

## Closed allowlist. The plan's record shape names Texture2D literally; a second type is added only
## when a verified asset of that type exists.
const VISUAL_RESOURCE_TYPES := ["Texture2D"]

## No art is a required playback dependency in the initial optional-art build.
const VISUAL_RECORDS: Array = []

const ART_MANIFEST_RECORD_SHAPE := &"ART_MANIFEST_RECORD_SHAPE"
const ART_MANIFEST_VISUAL_ID_INVALID := &"ART_MANIFEST_VISUAL_ID_INVALID"
const ART_MANIFEST_RESOURCE_PATH_INVALID := &"ART_MANIFEST_RESOURCE_PATH_INVALID"
const ART_MANIFEST_RESOURCE_TYPE_UNKNOWN := &"ART_MANIFEST_RESOURCE_TYPE_UNKNOWN"
const ART_MANIFEST_REQUIRED_INVALID := &"ART_MANIFEST_REQUIRED_INVALID"
const ART_MANIFEST_FALLBACK_INVALID := &"ART_MANIFEST_FALLBACK_INVALID"
const ART_MANIFEST_DUPLICATE_VISUAL_ID := &"ART_MANIFEST_DUPLICATE_VISUAL_ID"
const ART_MANIFEST_FALLBACK_UNDECLARED := &"ART_MANIFEST_FALLBACK_UNDECLARED"
const ART_MANIFEST_FALLBACK_CHAIN := &"ART_MANIFEST_FALLBACK_CHAIN"
const ART_MANIFEST_REQUIRED_VISUAL_MISSING := &"ART_MANIFEST_REQUIRED_VISUAL_MISSING"
const ART_MANIFEST_VISUAL_UNREGISTERED := &"ART_MANIFEST_VISUAL_UNREGISTERED"
const ART_MANIFEST_REQUIRED_NOT_ELIGIBLE := &"ART_MANIFEST_REQUIRED_NOT_ELIGIBLE"
const ART_MANIFEST_REQUIRED_SUBSTITUTION_FORBIDDEN := &"ART_MANIFEST_REQUIRED_SUBSTITUTION_FORBIDDEN"

static func visual_records() -> Array:
	return VISUAL_RECORDS.duplicate(true)

## `record` is Variant, not Dictionary, so the not-an-object law is reachable from a fixture, which
## is the shape DialogicEntryManifest.validate_ids_document uses for the same reason. The missing
## key check runs BEFORE the size check so the message can name the field that is absent.
static func validate_visual_record(record: Variant) -> Dictionary:
	if not (record is Dictionary):
		return _visual_fail(ART_MANIFEST_RECORD_SHAPE, "a visual record must be an object")
	var fields: Dictionary = record
	for field: String in VISUAL_RECORD_FIELDS:
		if not fields.has(field):
			return _visual_fail(ART_MANIFEST_RECORD_SHAPE, "a visual record declares no %s" % field)
	if fields.size() != VISUAL_RECORD_FIELDS.size():
		return _visual_fail(ART_MANIFEST_RECORD_SHAPE,
			"a visual record carries unknown fields: %s" % str(fields.keys()))
	var visual_id: Variant = fields["visual_id"]
	if typeof(visual_id) != TYPE_STRING or (visual_id as String).is_empty():
		return _visual_fail(ART_MANIFEST_VISUAL_ID_INVALID, "visual_id must be a nonempty string")
	var resource_path: Variant = fields["resource_path"]
	if typeof(resource_path) != TYPE_STRING or (resource_path as String).is_empty():
		return _visual_fail(ART_MANIFEST_RESOURCE_PATH_INVALID,
			"%s: resource_path must be a nonempty string" % str(visual_id))
	if not VISUAL_RESOURCE_TYPES.has(fields["resource_type"]):
		return _visual_fail(ART_MANIFEST_RESOURCE_TYPE_UNKNOWN,
			"%s: %s is not a declared resource type" % [str(visual_id), str(fields["resource_type"])])
	if typeof(fields["required"]) != TYPE_BOOL:
		return _visual_fail(ART_MANIFEST_REQUIRED_INVALID,
			"%s: required is a consent flag and must be a boolean" % str(visual_id))
	var fallback: Variant = fields["fallback_visual_id"]
	if fallback != null and (typeof(fallback) != TYPE_STRING or (fallback as String).is_empty()):
		return _visual_fail(ART_MANIFEST_FALLBACK_INVALID,
			"%s: fallback_visual_id must be null or a nonempty visual id" % str(visual_id))
	return {"ok": true, "value": fields.duplicate(true)}

## Every record valid, every id unique, and every declared fallback itself a DECLARED and TERMINAL
## record. Terminality is the cycle guard: without it, following a fallback could loop.
static func validate_visual_registry(records: Array) -> Dictionary:
	var declared: Dictionary = {}
	for record: Variant in records:
		var validated := validate_visual_record(record)
		if not validated.get("ok", false):
			return validated
		var visual_id: String = str((validated["value"] as Dictionary)["visual_id"])
		if declared.has(visual_id):
			return _visual_fail(ART_MANIFEST_DUPLICATE_VISUAL_ID,
				"%s is registered more than once" % visual_id)
		declared[visual_id] = validated["value"]
	for visual_id: String in declared:
		var fallback: Variant = (declared[visual_id] as Dictionary)["fallback_visual_id"]
		if fallback == null:
			continue
		if not declared.has(str(fallback)):
			return _visual_fail(ART_MANIFEST_FALLBACK_UNDECLARED,
				"%s: %s is not a declared visual" % [visual_id, str(fallback)])
		if (declared[str(fallback)] as Dictionary)["fallback_visual_id"] != null:
			return _visual_fail(ART_MANIFEST_FALLBACK_CHAIN,
				"%s: a fallback is terminal and %s declares one of its own" % [visual_id, str(fallback)])
	return {"ok": true, "value": declared.keys()}

## Requiredness is a property of the (entry, visual) EDGE, carried by visual_ids.required on the
## entry record, so it arrives as a PARAMETER. The record's own `required` is only a consent flag:
## it declares whether this visual is ELIGIBLE to be required, and never makes one required.
## The registry's own named code is propagated verbatim rather than re-wrapped, so the caller sees
## the validator that owns the defect.
static func resolve_visual(records: Array, visual_id: String, required: bool) -> Dictionary:
	var validated := validate_visual_registry(records)
	if not validated.get("ok", false):
		return validated
	for record: Variant in records:
		var fields: Dictionary = record
		if str(fields["visual_id"]) != visual_id:
			continue
		if required and not fields["required"]:
			return _visual_fail(ART_MANIFEST_REQUIRED_NOT_ELIGIBLE,
				"%s: the record declares no consent to being required" % visual_id)
		if required and fields["fallback_visual_id"] != null:
			return _visual_fail(ART_MANIFEST_REQUIRED_SUBSTITUTION_FORBIDDEN,
				"%s: a required visual may not be substituted by a fallback" % visual_id)
		return {"ok": true, "value": fields.duplicate(true)}
	if required:
		return _visual_fail(ART_MANIFEST_REQUIRED_VISUAL_MISSING,
			"%s: a required visual has no record and must reject before playback" % visual_id)
	return _visual_fail(ART_MANIFEST_VISUAL_UNREGISTERED, "%s is not a registered visual" % visual_id)

static func _visual_fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}

