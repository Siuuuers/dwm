class_name RunSnapshotSchema
extends RefCounted

## Frozen v2 run-snapshot schema
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 4).

const SCHEMA_VERSION := 2
const RECOVERY_LINE_HISTORY_LIMIT := 32

const DAY_RESOLUTION_PLAN := preload("res://scripts/domain/run/DayResolutionPlan.gd")
const DATING_ENDING_RULES := preload("res://scripts/domain/ending/DatingEndingRules.gd")
const NARRATIVE_VARIABLE_REGISTRY_PATH := "res://data/manifests/narrative_variables.json"

const TOP_KEYS: Array[String] = [
	"active_app_id", "applied_effect_transaction_ids", "applied_variable_transaction_ids",
	"audio_context", "checkpoint_id", "checkpoint_sequence", "command_receipts", "contacts", "content_version",
	"dating", "gameplay", "lifecycle", "narrative_checkpoint", "route_id", "run_id",
	"schedule", "schema_version",
]
const LIFECYCLE_KEYS: Array[String] = [
	"active_resolution_plan", "day", "ending_plan", "run_id", "state",
]
const LIFECYCLE_STATES: Array[String] = ["PLAYING", "ENDING", "COMPLETED"]
const PLAYBACK_SEQUENCE: Array[String] = ["PRIMARY_PENDING", "PRIMARY_PLAYED", "EPILOGUE_PLAYED", "GALLERY_RECORDED"]
const ENDING_PLAN_KEYS: Array[String] = [
	"ending_id", "epilogue_ending_id", "playback_receipts", "playback_stage", "source_day",
]

## Contracted non-narrative gameplay fields, frozen by the Task 1 GameState
## inventory (the legacy save whitelist minus `day`, which lives in lifecycle).
const GAMEPLAY_FIELDS: Array[String] = [
	"affection", "chat_state", "coins", "condition_effects_today", "condition_resolved_day",
	"condition_streak_days", "contact_choice_state", "contact_message_unlocks",
	"daily_group_invitation_generated", "daily_group_invitation_pair", "daily_opened_contacts",
	"date_unlocks", "dating_route_state", "friend_attitude", "friends",
	"hospital_skipped_sylvia_solo_count", "inter_friend_affection", "inter_friend_route_state",
	"inventory", "last_condition_day", "minesweeper_app_rounds_finished_today",
	"minesweeper_money_earned_today", "minesweeper_rng_seed", "minesweeper_round_floor",
	"minesweeper_rounds_left", "minesweeper_selected_difficulty", "minesweeper_task_rewards_claimed",
	"missed_group_date_counts", "missed_invitations", "money", "opening_seen",
	"penalty_points_today", "penalty_points_total", "pending_date_advance_day_after_finish",
	"pending_date_entries", "pending_date_entry_index", "pending_date_friend_id",
	"pending_group_date_friend_ids", "pending_group_date_inviter_id", "pending_hospital",
	"post_ending_queue", "route_context", "schedule_entries", "shop_purchase_counts",
	"stats", "story_flags", "tutorial_seen",
]

static func build(
		snapshot_input: Dictionary,
		dialogic_checkpoint: Dictionary,
		route_id: String,
		active_app_id: Variant,
		audio_context: Dictionary,
		content_version: int,
		checkpoint_sequence: int
) -> Dictionary:
	for member: String in ["lifecycle", "gameplay", "contacts", "schedule", "dating",
			"applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		if not snapshot_input.has(member):
			return _fail(&"invalid_snapshot_input", "missing member: " + member)
	if typeof(snapshot_input["lifecycle"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_snapshot_input", "lifecycle must be an object")
	var run_id := str((snapshot_input["lifecycle"] as Dictionary).get("run_id", ""))
	var gameplay: Dictionary = snapshot_input["gameplay"].duplicate(true) \
		if typeof(snapshot_input["gameplay"]) == TYPE_DICTIONARY else {}
	if not gameplay.has("narrative_variables"):
		gameplay["narrative_variables"] = {}
	var snapshot := {
		"schema_version": SCHEMA_VERSION,
		"content_version": content_version,
		"run_id": run_id,
		"checkpoint_id": "%s:%d" % [run_id, checkpoint_sequence],
		"checkpoint_sequence": checkpoint_sequence,
		"lifecycle": (snapshot_input["lifecycle"] as Dictionary).duplicate(true),
		"route_id": route_id,
		"active_app_id": active_app_id,
		"narrative_checkpoint": dialogic_checkpoint.duplicate(true),
		"gameplay": gameplay,
		"contacts": _detached(snapshot_input["contacts"]),
		"schedule": _detached(snapshot_input["schedule"]),
		"dating": _detached(snapshot_input["dating"]),
		"applied_effect_transaction_ids": _sorted_ids(snapshot_input["applied_effect_transaction_ids"]),
		"applied_variable_transaction_ids": _sorted_ids(snapshot_input["applied_variable_transaction_ids"]),
		# Mandatory schema-v2 effect/variable command ledger (dwm-p2r.8, Plan-05 Task 3). A legacy
		# input without it defaults to {}; it is disjoint from the ending-gallery ledger.
		"command_receipts": _detached(snapshot_input.get("command_receipts", {})),
		"audio_context": audio_context.duplicate(true),
	}
	var validated := validate(snapshot)
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": {"snapshot": validated["value"]["candidate"]}}

static func validate(snapshot: Dictionary) -> Dictionary:
	var normalized: Variant = _normalize_integral_floats(snapshot.duplicate(true))
	var candidate := normalized as Dictionary
	var keys: Array = candidate.keys()
	keys.sort()
	var expected := TOP_KEYS.duplicate()
	expected.sort()
	if keys != Array(expected):
		return _fail(&"invalid_snapshot_shape", "unexpected top-level keys: " + str(keys))
	if typeof(candidate["schema_version"]) != TYPE_INT:
		return _fail(&"invalid_snapshot_shape", "schema_version must be an integer")
	if int(candidate["schema_version"]) > SCHEMA_VERSION:
		return _fail(&"unsupported_schema_version", str(candidate["schema_version"]))
	if int(candidate["schema_version"]) != SCHEMA_VERSION:
		return _fail(&"invalid_snapshot_shape", "schema_version must be %d" % SCHEMA_VERSION)
	if typeof(candidate["content_version"]) != TYPE_INT or int(candidate["content_version"]) < 1:
		return _fail(&"invalid_snapshot_shape", "content_version must be a positive integer")
	if typeof(candidate["run_id"]) != TYPE_STRING or str(candidate["run_id"]).is_empty():
		return _fail(&"invalid_snapshot_shape", "run_id must be a nonempty String")
	if typeof(candidate["checkpoint_sequence"]) != TYPE_INT or int(candidate["checkpoint_sequence"]) < 0:
		return _fail(&"invalid_snapshot_shape", "checkpoint_sequence must be a non-negative integer")
	var expected_checkpoint := "%s:%d" % [str(candidate["run_id"]), int(candidate["checkpoint_sequence"])]
	if str(candidate["checkpoint_id"]) != expected_checkpoint:
		return _fail(&"invalid_snapshot_shape", "checkpoint_id must be run_id:sequence")
	var lifecycle_error := _validate_lifecycle(candidate)
	if lifecycle_error != "":
		return _fail(&"invalid_lifecycle", lifecycle_error)
	if typeof(candidate["route_id"]) != TYPE_STRING or str(candidate["route_id"]).is_empty():
		return _fail(&"invalid_snapshot_shape", "route_id must be a nonempty String")
	if candidate["active_app_id"] != null \
			and (typeof(candidate["active_app_id"]) != TYPE_STRING or str(candidate["active_app_id"]).is_empty()):
		return _fail(&"invalid_snapshot_shape", "active_app_id must be null or a nonempty String")
	for member: String in ["narrative_checkpoint", "contacts", "dating", "audio_context"]:
		if typeof(candidate[member]) != TYPE_DICTIONARY:
			return _fail(&"invalid_snapshot_shape", member + " must be an object")
		var member_check := validate_primitive_tree(candidate[member], "$." + member)
		if not member_check.get("ok", false):
			return member_check
	if typeof(candidate["schedule"]) != TYPE_ARRAY:
		return _fail(&"invalid_snapshot_shape", "schedule must be an array")
	var schedule_check := validate_primitive_tree(candidate["schedule"], "$.schedule")
	if not schedule_check.get("ok", false):
		return schedule_check
	var gameplay_error := _validate_gameplay(candidate["gameplay"])
	if gameplay_error != "":
		return _fail(&"invalid_gameplay", gameplay_error)
	for member: String in ["applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		var ids_error := _validate_transaction_ids(candidate[member], member)
		if ids_error != "":
			return _fail(&"invalid_transaction_ids", ids_error)
	var receipts_error := _validate_command_receipts(candidate["command_receipts"],
		candidate["applied_effect_transaction_ids"], candidate["applied_variable_transaction_ids"])
	if receipts_error != "":
		return _fail(&"invalid_command_receipts", receipts_error)
	return {"ok": true, "code": &"ok", "value": {"candidate": candidate}}

## Effect/variable command ledger only (dwm-p2r.8, Plan-05 Task 3). Ending/gallery receipt
## variants are rejected outright: that ledger belongs to ProfileManager and .7.
const COMMAND_RECEIPT_KEYS: Array[String] = ["kind", "request_fingerprint", "source_id", "transaction_id"]
const COMMAND_RECEIPT_KINDS: Array[String] = ["effect_transaction", "variable_transaction"]

static func _validate_command_receipts(receipts: Variant, applied_effects: Variant, applied_variables: Variant) -> String:
	if typeof(receipts) != TYPE_DICTIONARY:
		return "command_receipts must be an object"
	for key: Variant in (receipts as Dictionary):
		if typeof(key) != TYPE_STRING or str(key).is_empty():
			return "command_receipts keys must be nonempty strings"
		var receipt: Variant = (receipts as Dictionary)[key]
		if typeof(receipt) != TYPE_DICTIONARY:
			return "command receipt must be an object: " + str(key)
		var receipt_keys: Array = (receipt as Dictionary).keys()
		receipt_keys.sort()
		if receipt_keys != Array(COMMAND_RECEIPT_KEYS):
			return "command receipt keys must be exactly " + str(COMMAND_RECEIPT_KEYS)
		if str((receipt as Dictionary)["transaction_id"]) != str(key):
			return "command receipt key must equal its transaction_id: " + str(key)
		if str((receipt as Dictionary)["kind"]) not in COMMAND_RECEIPT_KINDS:
			return "unregistered command receipt kind: " + str((receipt as Dictionary)["kind"])
		var fingerprint := str((receipt as Dictionary)["request_fingerprint"])
		if fingerprint.length() != 64 or not fingerprint.is_valid_hex_number():
			return "command receipt fingerprint must be lowercase sha256 hex: " + str(key)
	# Partition equality: the receipt map and the two applied-ID sets describe exactly the same
	# transactions, split by kind. A ledger entry without its applied ID (or an applied ID without
	# its receipt) would let a legacy transaction be applied twice, so both directions are checked.
	return _validate_receipt_partition(receipts as Dictionary, applied_effects, applied_variables)

static func _validate_receipt_partition(receipts: Dictionary, applied_effects: Variant, applied_variables: Variant) -> String:
	if typeof(applied_effects) != TYPE_ARRAY or typeof(applied_variables) != TYPE_ARRAY:
		return "applied transaction id sets must be arrays"
	var expected := {"effect_transaction": {}, "variable_transaction": {}}
	for id: Variant in (applied_effects as Array):
		expected["effect_transaction"][str(id)] = true
	for id: Variant in (applied_variables as Array):
		expected["variable_transaction"][str(id)] = true
	var seen := {"effect_transaction": {}, "variable_transaction": {}}
	for key: Variant in receipts:
		var kind := str((receipts[key] as Dictionary)["kind"])
		if not (expected[kind] as Dictionary).has(str(key)):
			return "command receipt is not present in its applied %s id set: %s" % [kind, str(key)]
		seen[kind][str(key)] = true
	for kind: String in expected:
		if (expected[kind] as Dictionary).size() != (seen[kind] as Dictionary).size():
			return "applied %s id without a command receipt" % kind
	return ""

static func validate_primitive_tree(value: Variant, path: String = "$") -> Dictionary:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return {"ok": true, "code": &"ok"}
		TYPE_FLOAT:
			if is_finite(value):
				return {"ok": true, "code": &"ok"}
			return _fail(&"invalid_primitive", "non-finite number at " + path)
		TYPE_ARRAY:
			for index: int in range((value as Array).size()):
				var element := validate_primitive_tree(value[index], "%s[%d]" % [path, index])
				if not element.get("ok", false):
					return element
			return {"ok": true, "code": &"ok"}
		TYPE_DICTIONARY:
			for key: Variant in (value as Dictionary):
				if typeof(key) != TYPE_STRING:
					return _fail(&"invalid_primitive", "non-string key at " + path)
				var child := validate_primitive_tree(value[key], path + "." + str(key))
				if not child.get("ok", false):
					return child
			return {"ok": true, "code": &"ok"}
	return _fail(&"invalid_primitive", "unsupported type at " + path)

static func prepare_candidate(snapshot: Dictionary) -> Dictionary:
	return validate(snapshot)

static func is_compatible_bundle(bundle: Dictionary, compatibility: Dictionary) -> bool:
	if typeof(bundle.get("snapshot")) != TYPE_DICTIONARY:
		return false
	var validated := validate(bundle["snapshot"])
	if not validated.get("ok", false):
		return false
	var snapshot: Dictionary = validated["value"]["candidate"]
	if compatibility.has("content_version") \
			and int(snapshot["content_version"]) != int(compatibility["content_version"]):
		return false
	return true

static func derive_route_restore_context(snapshot: Dictionary) -> Dictionary:
	var validated := validate(snapshot)
	if not validated.get("ok", false):
		return validated
	var candidate: Dictionary = validated["value"]["candidate"]
	var lifecycle: Dictionary = candidate["lifecycle"]
	return {"ok": true, "code": &"ok", "value": {
		"run_id": str(candidate["run_id"]),
		"day": int(lifecycle["day"]),
		"lifecycle_state": str(lifecycle["state"]),
		"active_app_id": candidate["active_app_id"],
		"ending_plan": (lifecycle["ending_plan"] as Dictionary).duplicate(true) \
			if lifecycle["ending_plan"] != null else null,
		"contacts": (candidate["contacts"] as Dictionary).duplicate(true),
		"schedule": (candidate["schedule"] as Array).duplicate(true),
		"dating": (candidate["dating"] as Dictionary).duplicate(true),
	}}

static func _validate_lifecycle(candidate: Dictionary) -> String:
	if typeof(candidate["lifecycle"]) != TYPE_DICTIONARY:
		return "lifecycle must be an object"
	var lifecycle: Dictionary = candidate["lifecycle"]
	var keys: Array = lifecycle.keys()
	keys.sort()
	var expected := LIFECYCLE_KEYS.duplicate()
	expected.sort()
	if keys != Array(expected):
		return "unexpected lifecycle keys: " + str(keys)
	if str(lifecycle["run_id"]) != str(candidate["run_id"]):
		return "lifecycle run_id must match the snapshot run_id"
	if typeof(lifecycle["day"]) != TYPE_INT or int(lifecycle["day"]) < 1 or int(lifecycle["day"]) > 7:
		return "day must be an integer 1..7: " + str(lifecycle["day"])
	var state := str(lifecycle["state"])
	if state not in LIFECYCLE_STATES:
		return "unknown lifecycle state: " + state
	if lifecycle["active_resolution_plan"] != null:
		if typeof(lifecycle["active_resolution_plan"]) != TYPE_DICTIONARY:
			return "active_resolution_plan must be null or an object"
		var plan := DAY_RESOLUTION_PLAN.from_dict(lifecycle["active_resolution_plan"])
		if not plan.get("ok", false):
			return "invalid active_resolution_plan: " + str(plan.get("message", plan.get("code", "")))
		# One authority for the active-plan day window (dwm-7e6): DayResolutionPlan. RunLifecycle
		# defers to the same rule, so a snapshot that can be written can always be restored.
		var window_error := DAY_RESOLUTION_PLAN.active_source_day_error(
			int((plan["value"]["plan"] as RefCounted).get_source_day()), int(lifecycle["day"]),
			lifecycle["active_resolution_plan"] as Dictionary)
		if window_error != "":
			return window_error
	if lifecycle["ending_plan"] == null:
		if state != "PLAYING":
			return state + " requires an ending plan"
	else:
		if state == "PLAYING":
			return "PLAYING requires a null ending plan"
		if int(lifecycle["day"]) != 7:
			return "an ending plan requires day 7"
		var ending_error := _validate_ending_plan(lifecycle["ending_plan"])
		if ending_error != "":
			return ending_error
	return ""

static func _validate_ending_plan(plan: Variant) -> String:
	if typeof(plan) != TYPE_DICTIONARY:
		return "ending_plan must be null or an object"
	var keys: Array = (plan as Dictionary).keys()
	keys.sort()
	var expected := ENDING_PLAN_KEYS.duplicate()
	expected.sort()
	if keys != Array(expected):
		return "unexpected ending-plan keys: " + str(keys)
	if str(plan["ending_id"]).is_empty():
		return "ending_id must be nonempty"
	if typeof(plan["epilogue_ending_id"]) != TYPE_STRING:
		return "epilogue_ending_id must be a String"
	if typeof(plan["source_day"]) != TYPE_INT or int(plan["source_day"]) != 7:
		return "ending-plan source_day must be 7"
	if str(plan["playback_stage"]) not in PLAYBACK_SEQUENCE:
		return "unknown playback_stage: " + str(plan["playback_stage"])
	if typeof(plan["playback_receipts"]) != TYPE_DICTIONARY:
		return "playback_receipts must be a Dictionary"
	# Semantic authority: a structurally valid plan must still name a canonical primary and a valid
	# epilogue. Adapt the persisted shape (ending_id/epilogue_ending_id) to the DatingEndingRules
	# plan shape (primary_id/epilogue_id) and defer -- a tampered save cannot resume otherwise.
	var epilogue_raw := str((plan as Dictionary)["epilogue_ending_id"])
	var semantic: Dictionary = DATING_ENDING_RULES.validate_ending_plan({
		"primary_id": str((plan as Dictionary)["ending_id"]),
		"epilogue_id": null if epilogue_raw.is_empty() else epilogue_raw,
		"playback_stage": str((plan as Dictionary)["playback_stage"]),
	})
	if not semantic.get("ok", false):
		return str(semantic.get("message", semantic.get("code", "invalid ending plan")))
	return ""

static func _validate_gameplay(gameplay: Variant) -> String:
	if typeof(gameplay) != TYPE_DICTIONARY:
		return "gameplay must be an object"
	if not (gameplay as Dictionary).has("narrative_variables"):
		return "gameplay.narrative_variables is mandatory"
	if typeof(gameplay["narrative_variables"]) != TYPE_DICTIONARY:
		return "narrative_variables must be an object"
	var registered := _registered_narrative_variables()
	for variable_id: Variant in (gameplay["narrative_variables"] as Dictionary):
		if typeof(variable_id) != TYPE_STRING or str(variable_id) not in registered:
			return "unregistered narrative variable: " + str(variable_id)
	for key: Variant in (gameplay as Dictionary):
		if typeof(key) != TYPE_STRING:
			return "non-string gameplay key"
		if str(key) == "narrative_variables":
			continue
		if str(key) not in GAMEPLAY_FIELDS:
			return "unregistered gameplay key: " + str(key)
	var primitive := validate_primitive_tree(gameplay, "$.gameplay")
	if not primitive.get("ok", false):
		return str(primitive.get("message", "gameplay must be primitive"))
	return ""

static func _validate_transaction_ids(value: Variant, member: String) -> String:
	if typeof(value) != TYPE_ARRAY:
		return member + " must be an array"
	var previous := ""
	for element: Variant in (value as Array):
		if typeof(element) != TYPE_STRING or str(element).is_empty():
			return member + " must contain nonempty Strings"
		if str(element) <= previous and previous != "":
			return member + " must be sorted and unique"
		previous = str(element)
	return ""

static func _registered_narrative_variables() -> Array[String]:
	var registered: Array[String] = []
	var text := FileAccess.get_file_as_string(NARRATIVE_VARIABLE_REGISTRY_PATH)
	if text.is_empty():
		return registered
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return registered
	for entry: Variant in (parsed as Dictionary).get("variables", []):
		if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).has("id"):
			registered.append(str(entry["id"]))
		elif typeof(entry) == TYPE_STRING:
			registered.append(str(entry))
	return registered

static func _normalize_integral_floats(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			if is_finite(value) and value == floorf(value):
				return int(value)
			return value
		TYPE_ARRAY:
			var normalized_array: Array = []
			for element: Variant in (value as Array):
				normalized_array.append(_normalize_integral_floats(element))
			return normalized_array
		TYPE_DICTIONARY:
			var normalized_dictionary := {}
			for key: Variant in (value as Dictionary):
				normalized_dictionary[key] = _normalize_integral_floats(value[key])
			return normalized_dictionary
	return value

static func _sorted_ids(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var ids: Array = (value as Array).duplicate(true)
	ids.sort()
	return ids

static func _detached(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			return (value as Dictionary).duplicate(true)
		TYPE_ARRAY:
			return (value as Array).duplicate(true)
	return value

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
