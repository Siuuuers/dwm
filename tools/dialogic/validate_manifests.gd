extends SceneTree
## Generates and validates every Dialogic manifest + API evidence (dwm-p2r.8, Plan-05 Task 1).
## Run: godot --headless -s res://tools/dialogic/validate_manifests.gd
## Writing here is the manifest GENERATION step; the same pass validates the written bytes.

const BUILDER := preload("res://tools/dialogic/TimelineManifestBuilder.gd")
const AUDIT := preload("res://tools/dialogic/DialogicApiAudit.gd")
const VALIDATOR := preload("res://tools/dialogic/TimelineManifestValidator.gd")
const CANONICAL := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const DATING_ENDING_RULES := preload("res://scripts/domain/ending/DatingEndingRules.gd")
const EFFECT_RESOLVER := preload("res://autoload/EffectResolver.gd")
const SCENE_ROUTER := preload("res://autoload/SceneRouter.gd")

const MANIFEST_DIR := "res://data/manifests"
const EVIDENCE_DIR := "res://evidence/phase_2r/dialogic"


func _init() -> void:
	quit(_run())


func _run() -> int:
	var built := BUILDER.build()
	if not built.get("ok", false):
		return _fail("timelines build", built)
	var timelines: Dictionary = built["value"]
	var inventory := BUILDER.build_inventory(timelines)

	var endings := _build_endings(timelines)
	if not endings.get("ok", false):
		return _fail("endings build", endings)
	var effects := _build_effects()
	var routes := _build_routes()
	var narrative := {"schema_version": 1, "variables": []}

	var audited := AUDIT.audit()
	if not audited.get("ok", false):
		return _fail("api audit", audited)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE_DIR))
	var writes := {
		MANIFEST_DIR + "/timelines.json": timelines,
		MANIFEST_DIR + "/endings.json": endings["value"],
		MANIFEST_DIR + "/effects.json": effects,
		MANIFEST_DIR + "/routes.json": routes,
		MANIFEST_DIR + "/narrative_variables.json": narrative,
		EVIDENCE_DIR + "/addon_api.json": audited["value"],
		EVIDENCE_DIR + "/timeline_inventory.json": inventory,
	}
	for path in writes:
		var written := _write_canonical(path, writes[path])
		if not written.get("ok", false):
			return _fail("write " + path, written)

	var vt := VALIDATOR.validate_timelines(timelines)
	if not vt.get("ok", false):
		return _fail("validate timelines", vt)
	var ve := VALIDATOR.validate_endings(endings["value"], timelines)
	if not ve.get("ok", false):
		return _fail("validate endings", ve)
	var vef := VALIDATOR.validate_effects(effects)
	if not vef.get("ok", false):
		return _fail("validate effects", vef)
	var vr := VALIDATOR.validate_routes(routes)
	if not vr.get("ok", false):
		return _fail("validate routes", vr)

	print("MANIFEST_VALIDATION: PASS timelines=%d placeholder=%d draft=%d endings=%d effects=%d routes=%d" % [
		vt["value"]["count"], vt["value"]["placeholder"], vt["value"]["draft"],
		ve["value"]["count"], vef["value"]["count"], vr["value"]["count"]])
	return 0


func _build_endings(timelines: Dictionary) -> Dictionary:
	var role_of := {}
	for id in DATING_ENDING_RULES.VALID_PRIMARY_IDS:
		role_of[str(id)] = "primary"
	for id in DATING_ENDING_RULES.POSTSCRIPT_IDS:
		role_of[str(id)] = "postscript"
	role_of["ending.priscilla_lavinia"] = "epilogue"
	var locator := {}
	for record in timelines["records"]:
		for eid in record.get("ending_ids", []):
			locator[str(eid)] = {"timeline_id": str(record["id"]), "label": str(eid)}
	var records: Array = []
	for eid in DATING_ENDING_RULES.CANONICAL_ENDING_IDS:
		var id := str(eid)
		if not role_of.has(id):
			return {"ok": false, "code": &"unroled_ending", "message": id}
		if not locator.has(id):
			return {"ok": false, "code": &"unlocated_ending", "message": id}
		records.append({
			"ending_id": id, "role": role_of[id],
			"timeline_id": locator[id]["timeline_id"], "label": locator[id]["label"],
		})
	records.sort_custom(func(a, b): return str(a["ending_id"]) < str(b["ending_id"]))
	return {"ok": true, "value": {"schema_version": 1, "records": records}}


func _build_effects() -> Dictionary:
	var resolver: Node = EFFECT_RESOLVER.new()
	resolver._build_fixed_effects()
	var ids := {}
	for key in resolver._fixed_effects.keys():
		ids[str(key)] = true
	resolver.free()
	for item in EFFECT_RESOLVER._INVENTORY_ITEMS:
		ids["inventory:add:%s" % item] = true
	for friend in EFFECT_RESOLVER._FRIEND_IDS:
		ids["affection:%s:+1" % friend] = true
		ids["affection:%s:+2" % friend] = true
		ids["affection:%s:-1" % friend] = true
		for attitude in EFFECT_RESOLVER._ATTITUDES:
			ids["friend_attitude:%s:%s" % [friend, attitude]] = true
	ids["inter_friend_affection:priscilla:lavinia:+1"] = true
	ids["inter_friend_affection:priscilla:lavinia:-1"] = true
	ids["inter_friend_affection:lavinia:priscilla:+1"] = true
	ids["inter_friend_affection:lavinia:priscilla:-1"] = true
	ids["minesweeper:round_floor:-1"] = true
	ids["minesweeper:max_rounds:+1"] = true
	var sorted_ids: Array = ids.keys()
	sorted_ids.sort()
	return {"schema_version": 1, "kind": "effects", "ids": sorted_ids}


func _build_routes() -> Dictionary:
	var ids: Array = []
	for key in SCENE_ROUTER._SCENE_PATHS.keys():
		ids.append(str(key))
	ids.sort()
	return {"schema_version": 1, "kind": "routes", "ids": ids}


func _write_canonical(path: String, value: Variant) -> Dictionary:
	var emitted := CANONICAL.stringify(value)
	if not emitted.get("ok", false):
		return emitted
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "code": &"open_failed", "message": path}
	file.store_string(emitted["value"] + "\n")
	file.close()
	return {"ok": true}


func _fail(stage: String, result: Dictionary) -> int:
	printerr("MANIFEST_VALIDATION: FAIL at %s -> %s" % [stage, str(result)])
	return 1
