class_name SaveMigrations
extends RefCounted

## Explicit, declarative save migrations
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).
## Migrations fill only declared schema defaults; they never read the current
## run, profile, route, locale, audio, or journal.

const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const DATING_ENDING_RULES := preload("res://scripts/domain/ending/DatingEndingRules.gd")

const ENDING_ID_MAP := {
	"alone": "ending.alone",
	"priscilla.sweet": "ending.priscilla.sweet",
	"priscilla.dark": "ending.priscilla.dark",
	"priscilla.true": "ending.priscilla.true",
	"lavinia.sweet": "ending.lavinia.sweet",
	"lavinia.dark": "ending.lavinia.dark",
	"lavinia.true": "ending.lavinia.true",
	"sylvia.sweet": "ending.sylvia.sweet",
	"sylvia.dark": "ending.sylvia.dark",
	"sylvia.true": "ending.sylvia.true",
	"sylvia.special": "ending.sylvia.special",
	"priscilla_lavinia": "ending.priscilla_lavinia",
	"lavinia_priscilla": "ending.priscilla_lavinia",
}

# ---- Ending-id and pair-token migration ----

static func migrate_ending_id(ending_id: String) -> Dictionary:
	if DATING_ENDING_RULES.is_canonical_ending(ending_id):
		return {"ok": true, "code": &"ok", "value": {"ending_id": ending_id}}
	if ENDING_ID_MAP.has(ending_id):
		return {"ok": true, "code": &"ok", "value": {"ending_id": str(ENDING_ID_MAP[ending_id])}}
	return {"ok": false, "code": &"unknown_ending_id", "message": ending_id}

static func migrate_pair_token(token: String) -> Dictionary:
	if token == "lavinia_priscilla":
		return {"ok": true, "code": &"ok", "value": {"token": "priscilla_lavinia"}}
	if token == "priscilla_lavinia":
		return {"ok": true, "code": &"ok", "value": {"token": "priscilla_lavinia"}}
	return {"ok": false, "code": &"unknown_pair_token", "message": token}

# ---- Snapshot v1 -> v2 ----

static func migrate_snapshot_v1_to_v2(snapshot: Dictionary) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return _fail(&"invalid_snapshot", "snapshot must be an object")
	var v2 := RUN_SNAPSHOT_SCHEMA._normalize_integral_floats(snapshot.duplicate(true)) as Dictionary

	# Move legacy top-level lifecycle members into `lifecycle`.
	var lifecycle: Dictionary = v2.get("lifecycle", {}) if typeof(v2.get("lifecycle")) == TYPE_DICTIONARY else {}
	if v2.has("active_day_resolution_plan"):
		lifecycle["active_resolution_plan"] = v2["active_day_resolution_plan"]
		v2.erase("active_day_resolution_plan")
	elif not lifecycle.has("active_resolution_plan"):
		lifecycle["active_resolution_plan"] = null
	if v2.has("ending_plan") and not lifecycle.has("ending_plan"):
		lifecycle["ending_plan"] = v2["ending_plan"]
		v2.erase("ending_plan")
	elif not lifecycle.has("ending_plan"):
		lifecycle["ending_plan"] = null
	v2["lifecycle"] = lifecycle

	# Rename applied_transaction_ids -> applied_effect_transaction_ids; add variable ledger.
	if v2.has("applied_transaction_ids"):
		v2["applied_effect_transaction_ids"] = v2["applied_transaction_ids"]
		v2.erase("applied_transaction_ids")
	elif not v2.has("applied_effect_transaction_ids"):
		v2["applied_effect_transaction_ids"] = []
	if not v2.has("applied_variable_transaction_ids"):
		v2["applied_variable_transaction_ids"] = []

	# Declared v2 defaults.
	if not v2.has("active_app_id"):
		v2["active_app_id"] = null
	var gameplay: Dictionary = v2.get("gameplay", {}) if typeof(v2.get("gameplay")) == TYPE_DICTIONARY else {}
	if not gameplay.has("narrative_variables"):
		gameplay["narrative_variables"] = {}
	v2["gameplay"] = gameplay
	v2["schema_version"] = RUN_SNAPSHOT_SCHEMA.SCHEMA_VERSION

	var validated: Dictionary = RUN_SNAPSHOT_SCHEMA.validate(v2)
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": {"snapshot": validated["value"]["candidate"]}}

# ---- Legacy Day-8 reconstruction ----

static func migrate_legacy_day8(snapshot: Dictionary, compatible_day7_bundles: Array) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY or typeof(snapshot.get("lifecycle")) != TYPE_DICTIONARY:
		return _fail(&"invalid_snapshot", "snapshot.lifecycle is required")
	var lifecycle: Dictionary = snapshot["lifecycle"]
	if int(lifecycle.get("day", 0)) != 8:
		return _fail(&"not_legacy_day8", "migrate_legacy_day8 expects a Day-8 sentinel")
	var state := str(lifecycle.get("state", ""))
	var ending_plan: Variant = lifecycle.get("ending_plan")

	# Row 1/2: a resolvable ENDING/COMPLETED sentinel with an ending plan.
	if state in ["ENDING", "COMPLETED"] and typeof(ending_plan) == TYPE_DICTIONARY:
		var primary := str((ending_plan as Dictionary).get("ending_id", ""))
		var synchronized: Variant = snapshot.get("synchronized_day7_inputs")
		if primary == "ending.priscilla_lavinia" and typeof(synchronized) == TYPE_DICTIONARY:
			# Row 1: recompute a non-group primary with the group ending as epilogue.
			var recomputed := DATING_ENDING_RULES.recompute_synchronized_primary(synchronized)
			if not recomputed.get("ok", false):
				return recomputed
			return _rebuild_terminal(snapshot, recomputed["value"]["ending_id"],
				recomputed["value"]["epilogue_ending_id"])
		if primary != "ending.priscilla_lavinia" and DATING_ENDING_RULES.is_canonical_ending(primary):
			# Row 2: preserve a valid non-group terminal, pinned to Day 7.
			return _rebuild_terminal(snapshot, primary,
				str((ending_plan as Dictionary).get("epilogue_ending_id", "")))

	# Rows 3/4: fall back to the greatest compatible Day-7 whole bundle.
	var best := _greatest_compatible_bundle(compatible_day7_bundles)
	if not best.is_empty():
		return {"ok": true, "code": &"ok", "value": {
			"resolution": "day7_bundle_fallback",
			"bundle": best,
		}}

	# Row 5: nothing valid and no fallback.
	return _fail(&"no_day8_reconstruction", "no valid terminal and no compatible Day-7 bundle")

static func _rebuild_terminal(snapshot: Dictionary, ending_id: String, epilogue_ending_id: String) -> Dictionary:
	var rebuilt := snapshot.duplicate(true)
	rebuilt.erase("synchronized_day7_inputs")
	var lifecycle: Dictionary = rebuilt["lifecycle"]
	lifecycle["day"] = 7
	lifecycle["state"] = "ENDING"
	lifecycle["active_resolution_plan"] = null
	lifecycle["ending_plan"] = {
		"ending_id": ending_id,
		"epilogue_ending_id": epilogue_ending_id,
		"source_day": 7,
		"playback_stage": "PRIMARY_PENDING",
		"playback_receipts": {},
	}
	rebuilt["lifecycle"] = lifecycle
	return {"ok": true, "code": &"ok", "value": {
		"resolution": "terminal_recomputed",
		"snapshot": rebuilt,
		"ending_id": ending_id,
		"epilogue_ending_id": epilogue_ending_id,
	}}

static func _greatest_compatible_bundle(bundles: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_sequence := -1
	for bundle: Variant in bundles:
		if typeof(bundle) != TYPE_DICTIONARY or typeof((bundle as Dictionary).get("snapshot")) != TYPE_DICTIONARY:
			continue
		var validated: Dictionary = RUN_SNAPSHOT_SCHEMA.validate(bundle["snapshot"])
		if not validated.get("ok", false):
			continue
		var candidate: Dictionary = validated["value"]["candidate"]
		if int(candidate["lifecycle"]["day"]) < 1 or int(candidate["lifecycle"]["day"]) > 7:
			continue
		var sequence := int(candidate["checkpoint_sequence"])
		if sequence > best_sequence:
			best_sequence = sequence
			best = {"checkpoint_kind": str((bundle as Dictionary).get("checkpoint_kind", "")), "snapshot": candidate}
	return best

# ---- Whole-document migration ----

static func migrate_document(raw: Dictionary, expected_locator: Dictionary) -> Dictionary:
	var locator_error := _validate_expected_locator(expected_locator)
	if locator_error != "":
		return _fail(&"invalid_expected_locator", locator_error)
	if typeof(raw.get("current_snapshot")) != TYPE_DICTIONARY \
			or typeof((raw["current_snapshot"] as Dictionary).get("snapshot")) != TYPE_DICTIONARY:
		return _fail(&"invalid_document", "document lacks current_snapshot.snapshot")

	var migration_receipts: Array[Dictionary] = []
	var legacy_run_state := {}
	var legacy_input_mappings := {}

	var migrated_current := _migrate_bundle_snapshot(
		raw["current_snapshot"], migration_receipts, legacy_run_state, legacy_input_mappings)
	if not migrated_current.get("ok", false):
		return migrated_current

	var migrated_journal: Array = []
	for entry: Variant in raw.get("recovery_journal", []):
		if typeof(entry) != TYPE_DICTIONARY:
			return _fail(&"invalid_document", "recovery_journal entries must be objects")
		var migrated_entry := _migrate_bundle_snapshot(entry, migration_receipts, {}, {})
		if not migrated_entry.get("ok", false):
			return migrated_entry
		migrated_journal.append(migrated_entry["value"]["bundle"])

	var document := {
		"schema_version": 2,
		"kind": str(expected_locator["kind"]),
		"slot_id": expected_locator["slot_id"],
		"save_reason": str(raw.get("save_reason", "")),
		"current_snapshot": migrated_current["value"]["bundle"],
		"recovery_journal": migrated_journal,
	}
	return {"ok": true, "code": &"ok", "value": {
		"document": document,
		"legacy_profile_patch_input": {
			"legacy_run_state": legacy_run_state,
			"legacy_input_mappings": legacy_input_mappings,
		},
		"migration_receipts": migration_receipts,
	}}

static func _migrate_bundle_snapshot(
		bundle: Dictionary,
		receipts: Array[Dictionary],
		legacy_run_state: Dictionary,
		legacy_input_mappings: Dictionary
) -> Dictionary:
	var snapshot: Variant = bundle.get("snapshot")
	if typeof(snapshot) != TYPE_DICTIONARY:
		return _fail(&"invalid_bundle", "bundle.snapshot must be an object")
	var version_dispatch := _dispatch_schema(snapshot)
	if not version_dispatch.get("ok", false):
		return version_dispatch
	# Strip legacy profile-owned members into the profile patch input.
	var working := (snapshot as Dictionary).duplicate(true)
	for legacy_key: String in ["settings", "audio_state", "seen_endings"]:
		if working.has(legacy_key):
			legacy_run_state[legacy_key] = working[legacy_key]
			working.erase(legacy_key)
			receipts.append({"migration": "strip_legacy_profile_member", "member": legacy_key})
	if working.has("visited_lines"):
		legacy_run_state["visited_lines"] = working["visited_lines"]
		working.erase("visited_lines")
		receipts.append({"migration": "strip_legacy_profile_member", "member": "visited_lines"})
	if working.has("input_mappings"):
		var mappings: Variant = working["input_mappings"]
		if typeof(mappings) == TYPE_DICTIONARY:
			for action: Variant in (mappings as Dictionary):
				legacy_input_mappings[str(action)] = (mappings as Dictionary)[action]
		working.erase("input_mappings")
		receipts.append({"migration": "strip_legacy_input_mappings"})

	var result: Dictionary
	if int(version_dispatch["value"]["schema_version"]) < 2:
		result = migrate_snapshot_v1_to_v2(working)
		if result.get("ok", false):
			receipts.append({"migration": "snapshot_v1_to_v2"})
	else:
		result = RUN_SNAPSHOT_SCHEMA.validate(working)
	if not result.get("ok", false):
		return result
	var migrated_snapshot: Dictionary = result["value"].get("snapshot", result["value"].get("candidate"))
	return {"ok": true, "code": &"ok", "value": {"bundle": {
		"checkpoint_kind": str(bundle.get("checkpoint_kind", "")),
		"snapshot": migrated_snapshot,
	}}}

static func _dispatch_schema(snapshot: Dictionary) -> Dictionary:
	if not snapshot.has("schema_version"):
		return {"ok": true, "code": &"ok", "value": {"schema_version": 1}}
	var raw_version: Variant = snapshot["schema_version"]
	if typeof(raw_version) == TYPE_FLOAT:
		if not is_finite(raw_version) or raw_version != floorf(raw_version):
			return _fail(&"invalid_schema_version", "schema_version must be integral")
		raw_version = int(raw_version)
	if typeof(raw_version) != TYPE_INT:
		return _fail(&"invalid_schema_version", "schema_version must be a number")
	var version := int(raw_version)
	if version < 1:
		return _fail(&"unsupported_legacy_schema", str(version))
	if version > 2:
		return _fail(&"unsupported_future_schema", str(version))
	return {"ok": true, "code": &"ok", "value": {"schema_version": version}}

static func _validate_expected_locator(locator: Dictionary) -> String:
	var keys: Array = locator.keys()
	keys.sort()
	if keys != ["kind", "slot_id"]:
		return "expected_locator must have exactly kind and slot_id"
	match str(locator["kind"]):
		"slot":
			if typeof(locator["slot_id"]) != TYPE_INT or int(locator["slot_id"]) < 1 or int(locator["slot_id"]) > 7:
				return "slot expected_locator needs slot_id 1..7"
		"quick", "autosave":
			if locator["slot_id"] != null:
				return str(locator["kind"]) + " expected_locator needs a null slot_id"
		_:
			return "unknown expected_locator kind: " + str(locator["kind"])
	return ""

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
