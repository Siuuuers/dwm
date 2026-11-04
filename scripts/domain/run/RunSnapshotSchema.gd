class_name RunSnapshotSchema
extends RefCounted

const SCHEMA_VERSION := 9
const SCENE_SCHEMA_VERSION := SCHEMA_VERSION
const RECOVERY_LINE_HISTORY_LIMIT := 32

const NARRATIVE_VARIABLE_REGISTRY_PATH := "res://data/manifests/narrative_variables.json"
const SCENE_VALIDATION_TIMING := preload("res://scripts/narrative/SceneValidationTiming.gd")

const RUN_LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")
const DESKTOP_BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const DESKTOP_CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const NOTE_PURCHASE_RULES := preload("res://scripts/domain/shop/RunNotePurchaseRules.gd")
const SCENE_EVENT_CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")

const TOP_KEYS := SCENE_TOP_KEYS
const DESKTOP_KEYS: Array[String] = ["board", "consequence"]
const LIFECYCLE_KEYS := SCENE_LIFECYCLE_KEYS
const LIFECYCLE_STATES: Array[String] = ["PLAYING", "ENDING", "COMPLETED", "TERMINAL_PENDING"]
const PLAYBACK_SEQUENCE: Array[String] = ["PRIMARY_PENDING", "PRIMARY_PLAYED", "EPILOGUE_PLAYED", "GALLERY_RECORDED"]
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
	"missed_group_date_counts", "missed_invitations", "money",
	"penalty_points_today", "penalty_points_total", "pending_date_advance_day_after_finish",
	"pending_date_entries", "pending_date_entry_index", "pending_date_friend_id",
	"pending_group_date_friend_ids", "pending_group_date_inviter_id", "pending_hospital",
	"post_ending_queue", "route_context", "shop_purchase_counts",
	"stats", "story_flags",
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
	return build_scene(snapshot_input, dialogic_checkpoint, route_id, active_app_id,
		audio_context, content_version, checkpoint_sequence)

static func validate(snapshot: Dictionary) -> Dictionary:
	var version: Variant = snapshot.get("schema_version")
	if typeof(version) == TYPE_FLOAT and is_finite(version) and version == floorf(version): version = int(version)
	if version == SCENE_SCHEMA_VERSION:
		var selected: Dictionary = SCENE_MANIFEST.scene_contract_tables()
		if not selected.ok: return selected
		return validate_scene(snapshot, selected.bundle)
	return _fail(&"unsupported_schema_version", str(version))

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
		if (receipt as Dictionary).get("kind") == "scene_event":
			continue # The scene-event owner validates this complete variant and its chain below.
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
	var scene_events: Dictionary = SCENE_EVENT_CONTRACT.validate_receipts(receipts as Dictionary)
	if not scene_events.get("ok", false):
		return str(scene_events.get("code", "invalid_scene_event_receipts"))
	# Partition equality: legacy receipts and the two applied-ID sets describe exactly the same
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
		if kind in ["scene_event", "scene_admission", "scene_shop_purchase", "scene_round_completion"]:
			continue # Already validated separately; never counted as an effect or variable ID.
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
	if snapshot.get("schema_version") != SCENE_SCHEMA_VERSION:
		return _fail(&"unsupported_schema_version", str(snapshot.get("schema_version")))
	var lifecycle: Dictionary = snapshot.lifecycle
	var context := {"run_id": snapshot.run_id, "lifecycle_state": lifecycle.state,
		"active_app_id": "minesweeper" if snapshot.desktop.board.phase == "ACTIVE_VISIBLE" else null,
		"scene": snapshot.scene.duplicate(true), "contacts": snapshot.contacts.duplicate(true)}
	if is_scene_terminal(snapshot): context["ending_plan"] = lifecycle.ending_plan.duplicate(true)
	return {"ok": true, "code": &"ok", "value": context}

## Exact `{board,consequence}` (brief line 59). Both members are delegated wholesale to their own
## owning modules: `board` to `DesktopBoardState.prepare_restore()` (its established structural-
## validation entry point -- a throwaway instance is used since that method is not static),
## `consequence` to `DesktopConsequenceState.validate()`.
static func _validate_desktop(desktop: Variant) -> String:
	if typeof(desktop) != TYPE_DICTIONARY:
		return "desktop must be an object"
	var keys: Array = (desktop as Dictionary).keys()
	keys.sort()
	var expected := DESKTOP_KEYS.duplicate()
	expected.sort()
	if keys != Array(expected):
		return "unexpected desktop keys: " + str(keys)
	if typeof((desktop as Dictionary)["board"]) != TYPE_DICTIONARY:
		return "desktop.board must be an object"
	var board_check: Dictionary = DESKTOP_BOARD_STATE.new().prepare_restore((desktop as Dictionary)["board"])
	if not board_check.get("ok", false):
		return str(board_check.get("message", board_check.get("code", "invalid desktop.board")))
	if typeof((desktop as Dictionary)["consequence"]) != TYPE_DICTIONARY:
		return "desktop.consequence must be an object"
	var consequence_check: Dictionary = DESKTOP_CONSEQUENCE_STATE.validate((desktop as Dictionary)["consequence"])
	if not consequence_check.get("ok", false):
		return str(consequence_check.get("message", consequence_check.get("code", "invalid desktop.consequence")))
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

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}


## Scene format is admitted jointly with Save9. The legacy constants and paths
## above remain intact; no calendar-shaped defaults are produced for scenes.
const SCENE_MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const SCENE_CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const SCENE_READING := preload("res://scripts/narrative/SoloReadingSession.gd")
const SCENE_ATTEMPTS := preload("res://scripts/profile/DatingAttemptLedger.gd")
const SCENE_CANONICAL := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SCENE_CAPABILITIES := preload("res://scripts/domain/minesweeper/MinesweeperCapabilityRules.gd")
const SCENE_INPUT_KEYS := ["lifecycle", "gameplay", "contacts", "desktop", "scene",
	"applied_effect_transaction_ids", "applied_variable_transaction_ids", "command_receipts"]
const SCENE_TOP_KEYS := ["checkpoint_id", "checkpoint_sequence", "contacts", "content_version",
	"desktop", "gameplay", "lifecycle", "narrative_checkpoint", "route_id", "run_id", "scene", "schema_version"]
const SCENE_LIFECYCLE_KEYS := ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance",
	"causal_day_instance_issuer_receipt", "restore_provenance", "state"]
const SCENE_GAMEPLAY_KEYS := ["coins", "inventory",
	"minesweeper_app_rounds_finished_today", "minesweeper_money_earned_today", "minesweeper_rng_seed",
	"minesweeper_round_floor", "minesweeper_rounds_left", "minesweeper_selected_difficulty", "minesweeper_task_rewards_claimed",
	"money", "narrative_variables", "penalty_points_today", "penalty_points_total", "route_context",
	"scene_choices", "scene_challenge_outcomes",
	"shop_purchase_counts", "stats", "story_flags"]
const SCENE_CHECKPOINT_KEYS := ["content_version", "entry_id", "frozen_context", "manifest_fingerprint", "stage",
	"transaction_id", "reading_session"]
static var _scene_issuer: Object
static var _scene_authority: Object
static var _scene_creation_owner: Object
static var _scene_semantic_busy := false

## External save admission adapts reading to installed content once. Physical
## attempts, identity receipts, economy and lifecycle remain historical facts.
static func normalize_scene_content(snapshot: Dictionary, trusted: bool = false) -> Dictionary:
	if not trusted:
		var primitive := validate_primitive_tree(snapshot)
		if not primitive.ok: return primitive
	var candidate: Dictionary = _normalize_integral_floats(snapshot)
	if not trusted and (candidate.get("schema_version") != SCENE_SCHEMA_VERSION \
			or not candidate.get("scene") is Dictionary or not candidate.get("gameplay") is Dictionary \
			or not candidate.get("narrative_checkpoint") is Dictionary):
		return _fail(&"invalid_snapshot_shape", "content normalization requires Run9")
	if trusted or candidate.scene.get("registration_sha256") != SCENE_MANIFEST.scene_registration_fingerprint():
		var presentation := _resolve_scene_presentation(candidate.scene)
		if not presentation.ok: return presentation
	var gameplay: Dictionary = candidate.gameplay
	if not trusted:
		var checkpoint: Dictionary = candidate.narrative_checkpoint
		if not _scene_current_keys(candidate.scene) \
				or not _scene_digest(candidate.scene.registration_sha256) \
				or not _scene_id(candidate.scene.active_occurrence_id) or not _scene_id(candidate.scene.entry_id) \
				or not candidate.scene.notification is Dictionary or not candidate.scene.active_challenge is Dictionary \
				or checkpoint.get("entry_id") != candidate.scene.entry_id \
				or checkpoint.get("transaction_id") != candidate.scene.active_occurrence_id \
				or checkpoint.get("manifest_fingerprint") != candidate.scene.registration_sha256 \
				or checkpoint.get("content_version") != candidate.get("content_version") \
				or not _scene_int(candidate.get("content_version"), 1):
			return _fail(&"reading_context_invalid", "original Scene and reading wrapper must agree")
		if not candidate.scene.active_challenge.is_empty() \
				and (not _scene_keys(candidate.scene.active_challenge, ["challenge_id", "playable_command_id"]) \
				or not _scene_id(candidate.scene.active_challenge.challenge_id) \
				or not _scene_id(candidate.scene.active_challenge.playable_command_id)):
			return _fail(&"scene_challenge_state_invalid", "invalid saved Challenge binding")
		if not candidate.scene.notification.is_empty() \
				and not SCENE_EVENT_CONTRACT._scene_payload("notification.set", candidate.scene.notification):
			return _fail(&"scene_notification_invalid", "invalid saved notification")
		if not gameplay.get("scene_choices") is Dictionary or not gameplay.get("scene_challenge_outcomes") is Dictionary \
				or not gameplay.get("route_context") is Dictionary:
			return _fail(&"invalid_gameplay", "scene progress owners are required")
		var progress_error := _validate_scene_progress(gameplay.scene_choices, gameplay.scene_challenge_outcomes)
		if not progress_error.is_empty(): return _fail(&"invalid_gameplay", progress_error)
		var route_error := _validate_scene_route_context(gameplay.route_context)
		if not route_error.is_empty(): return _fail(&"invalid_gameplay", route_error)
	var selected := SCENE_MANIFEST.scene_contract_tables()
	if not selected.ok: return selected
	if not trusted and candidate.scene.registration_sha256 == SCENE_MANIFEST.scene_registration_fingerprint():
		# An unchanged bundle is not an excuse to repair malformed current
		# references or a forged caption/control pair.
		var current := validate_current_scene(candidate.scene, selected.bundle)
		if not current.ok: return current
		var binding := _validate_scene_challenge_binding(candidate.scene, gameplay, selected.bundle)
		if not binding.ok: return binding
		var reading := SCENE_READING.expand_player_checkpoint(candidate.narrative_checkpoint)
		if not reading.ok: return reading
	# Preserve the content against which completion was decided. Rebuilt reading
	# may fall back, but it cannot turn that completed lifecycle into a new play.
	if candidate.get("lifecycle") is Dictionary and candidate.lifecycle.get("state") == "COMPLETED" \
			and not candidate.lifecycle.has("ending_plan") \
			and not candidate.lifecycle.has("completed_registration_sha256") \
			and candidate.scene.registration_sha256 != SCENE_MANIFEST.scene_registration_fingerprint():
		candidate.lifecycle["completed_registration_sha256"] = candidate.scene.registration_sha256
	# Unchanged content can resume the saved cursor directly. Resolve deleted
	# lines only when the authored registration changed.
	if not trusted or candidate.scene.registration_sha256 != SCENE_MANIFEST.scene_registration_fingerprint():
		var normalized: Dictionary = SCENE_READING.normalize_player_checkpoint(candidate.narrative_checkpoint,
			gameplay.scene_choices, gameplay.scene_challenge_outcomes)
		if not normalized.ok: return normalized
		candidate.narrative_checkpoint = normalized.value.checkpoint
		candidate.content_version = candidate.narrative_checkpoint.content_version
		candidate.scene.registration_sha256 = candidate.narrative_checkpoint.manifest_fingerprint
		candidate.scene.entry_id = candidate.narrative_checkpoint.entry_id
		if normalized.value.fallback:
			# Notification is presentation for the previous cursor, not gameplay.
			candidate.scene.notification = {}
	var record: Dictionary = gameplay.route_context.get("active_dating_challenge", {})
	for occurrence: String in gameplay.scene_challenge_outcomes:
		var outcome: Dictionary = gameplay.scene_challenge_outcomes[occurrence]
		if outcome.has("physical_slot"): continue
		outcome["physical_slot"] = ""
		if not record.is_empty() and outcome.outcome != "never_started" \
				and outcome.challenge_id == record.context.challenge_id:
			var slot: String = SCENE_ATTEMPTS.semantic_slot(record.context)
			if slot == "scene.challenge." + occurrence: outcome.physical_slot = slot
	if record.is_empty() and candidate.scene.get("active_challenge") is Dictionary \
			and not candidate.scene.active_challenge.is_empty():
		var still_registered := false
		for challenge: Dictionary in selected.bundle.challenges:
			if challenge.challenge_id == candidate.scene.active_challenge.get("challenge_id") \
					and challenge.entry_id == candidate.scene.entry_id: still_registered = true
		if not still_registered: candidate.scene.active_challenge = {}
	return {"ok": true, "value": candidate}

static func configure_scene_validation(issuer: Object, authority: Object, creation_owner: Object = null) -> Dictionary:
	if not is_instance_valid(issuer) or not issuer.has_method("verify_issued") \
			or not is_instance_valid(authority) or not authority.has_method("validate_scene_snapshot_semantics"):
		return _fail(&"scene_validation_unavailable", "real issuer and semantic owner are required")
	if creation_owner != null and (not is_instance_valid(creation_owner) \
			or creation_owner.get_script() != load("res://autoload/SaveManager.gd")):
		return _fail(&"scene_validation_unavailable", "creation authority must be the real SaveManager")
	if _scene_issuer != null or _scene_authority != null:
		if _scene_issuer != issuer or _scene_authority != authority \
				or (_scene_creation_owner != null and creation_owner != null and _scene_creation_owner != creation_owner):
			return _fail(&"scene_validation_already_configured", "owner replacement refused")
		if creation_owner != null: _scene_creation_owner = creation_owner
		return {"ok": true}
	_scene_issuer = issuer
	_scene_authority = authority
	_scene_creation_owner = creation_owner
	return {"ok": true}

static func build_scene(snapshot_input: Dictionary, dialogic_checkpoint: Dictionary, route_id: String,
		_active_app_id: Variant, _audio_context: Dictionary, content_version: int, checkpoint_sequence: int) -> Dictionary:
	if route_id not in ["scene", "ending"] or not _scene_keys(snapshot_input, SCENE_INPUT_KEYS) \
			or not snapshot_input.lifecycle is Dictionary:
		return _fail(&"invalid_snapshot_input", "scene input requires its exact complete owner shape")
	var selected := SCENE_MANIFEST.scene_contract_tables()
	if not selected.ok: return selected
	var live := validate_scene_input_fields(snapshot_input, selected.bundle)
	if not live.ok: return live
	var snapshot: Dictionary = snapshot_input.duplicate(true)
	for member: String in ["command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		snapshot.erase(member)
	if not snapshot.get("desktop") is Dictionary or not snapshot.desktop.get("board") is Dictionary:
		return _fail(&"invalid_desktop_aggregate", "desktop board input is required")
	# Only the outgoing player document omits transient retries. Live captures and
	# prospective transactions keep their complete owner state for rollback.
	var player_board: Dictionary = DESKTOP_BOARD_STATE.project_player_state(snapshot.desktop.board)
	if not player_board.ok: return player_board
	snapshot.desktop.board = player_board.value.snapshot
	snapshot.merge({"schema_version": SCENE_SCHEMA_VERSION, "content_version": content_version,
		"run_id": snapshot_input.lifecycle.get("run_id"), "checkpoint_sequence": checkpoint_sequence,
		"checkpoint_id": "%s:%d" % [str(snapshot_input.lifecycle.get("run_id", "")), checkpoint_sequence],
		"route_id": route_id,
		"narrative_checkpoint": dialogic_checkpoint.duplicate(true)})
	var player_reading: Dictionary = SCENE_READING.project_player_checkpoint(snapshot.narrative_checkpoint)
	if not player_reading.ok: return player_reading
	snapshot.narrative_checkpoint = player_reading.value
	if is_scene_terminal(snapshot):
		if not snapshot.lifecycle.ending_plan.get("source_reading_checkpoint") is Dictionary:
			return _fail(&"reading_checkpoint_invalid", "terminal source reading must be an object")
		var source_reading: Dictionary = SCENE_READING.project_player_checkpoint(snapshot.lifecycle.ending_plan.source_reading_checkpoint)
		if not source_reading.ok: return source_reading
		snapshot.lifecycle.ending_plan.source_reading_checkpoint = source_reading.value
	var checked := validate(snapshot)
	if not checked.ok: return checked
	return {"ok": true, "code": &"ok", "value": {"snapshot": checked.value.candidate}}

## Producer construction uses the same exact initial candidate proof, never ordinary Load.
static func build_scene_new_run_candidate(snapshot_input: Dictionary, dialogic_checkpoint: Dictionary,
		_audio_context: Dictionary, content_version: int, allocation_candidate: Dictionary,
		profile_material: Dictionary, bundle: Dictionary, issuer: Object) -> Dictionary:
	if not _scene_keys(snapshot_input, SCENE_INPUT_KEYS) or not snapshot_input.lifecycle is Dictionary:
		return _fail(&"invalid_snapshot_input", "initial scene input requires its complete owner shape")
	if not snapshot_input.command_receipts is Dictionary or snapshot_input.command_receipts.size() != 1 \
			or not snapshot_input.applied_effect_transaction_ids is Array or not snapshot_input.applied_effect_transaction_ids.is_empty() \
			or not snapshot_input.applied_variable_transaction_ids is Array or not snapshot_input.applied_variable_transaction_ids.is_empty():
		return _fail(&"scene_initial_state_invalid", "initial live input requires only its genuine creation admission")
	var admission: Variant = snapshot_input.command_receipts.values()[0]
	if not admission is Dictionary: return _fail(&"scene_initial_state_invalid", "initial admission must be an object")
	var admitted := SCENE_EVENT_CONTRACT.validate_scene_initial_admission_candidate(admission, allocation_candidate, profile_material, bundle, issuer)
	if not admitted.ok: return admitted
	if not snapshot_input.scene is Dictionary \
			or snapshot_input.command_receipts.keys() != [allocation_candidate.request.transaction_id] \
			or snapshot_input.scene.get("entry_id") != admission.scene_admission.result.entry_id:
		return _fail(&"scene_initial_state_invalid", "initial scene differs from genuine creation admission")
	var snapshot: Dictionary = snapshot_input.duplicate(true)
	for member: String in ["command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		snapshot.erase(member)
	if not snapshot.get("desktop") is Dictionary or not snapshot.desktop.get("board") is Dictionary:
		return _fail(&"invalid_desktop_aggregate", "desktop board input is required")
	# Only the outgoing player document omits transient retries. Live captures and
	# prospective transactions keep their complete owner state for rollback.
	var player_board: Dictionary = DESKTOP_BOARD_STATE.project_player_state(snapshot.desktop.board)
	if not player_board.ok: return player_board
	snapshot.desktop.board = player_board.value.snapshot
	snapshot.merge({"schema_version": SCENE_SCHEMA_VERSION, "content_version": content_version,
		"run_id": snapshot_input.lifecycle.get("run_id"), "checkpoint_sequence": 1,
		"checkpoint_id": str(snapshot_input.lifecycle.get("run_id", "")) + ":1",
		"route_id": "scene",
		"narrative_checkpoint": dialogic_checkpoint.duplicate(true)})
	var player_reading: Dictionary = SCENE_READING.project_player_checkpoint(snapshot.narrative_checkpoint)
	if not player_reading.ok: return player_reading
	snapshot.narrative_checkpoint = player_reading.value
	var checked := validate_scene_new_run_candidate(snapshot, allocation_candidate, profile_material, bundle, issuer)
	if not checked.ok: return checked
	return {"ok": true, "code": &"ok", "value": {"snapshot": checked.value.candidate}}

## Detached initial candidates have their own authority: the reproducible allocation and
## frozen Profile material, not a completed creation or current live Profile.
static func validate_scene_new_run_candidate(snapshot: Dictionary, allocation_candidate: Dictionary,
		profile_material: Dictionary, bundle: Dictionary, issuer: Object,
		acknowledged_checkpoint: Dictionary = {}) -> Dictionary:
	var retained := snapshot.duplicate()
	retained.erase("audio_context")
	retained.erase("active_app_id")
	var primitive := validate_primitive_tree(retained)
	if not primitive.ok: return primitive
	var selected: Dictionary = SCENE_MANIFEST.scene_contract_tables()
	if not selected.ok: return selected
	if not is_same(bundle, selected.bundle) and not _scene_exact_value(bundle, selected.bundle):
		return _fail(&"scene_registration_mismatch", "initial candidate must use the installed registration")
	bundle = selected.bundle
	var candidate: Dictionary = retained.duplicate(true)
	if not _scene_keys(candidate, SCENE_TOP_KEYS) or typeof(candidate.schema_version) != TYPE_INT \
			or candidate.schema_version != SCENE_SCHEMA_VERSION or candidate.route_id != "scene" \
			or not _scene_id(candidate.run_id) or not _scene_int(candidate.content_version, 1) \
			or not _scene_int(candidate.checkpoint_sequence, 1, 1) \
			or candidate.checkpoint_id != candidate.run_id + ":1":
		return _fail(&"invalid_snapshot_shape", "initial Run9 requires the exact sequence-one scene shape")
	if not _scene_keys(candidate.lifecycle, SCENE_LIFECYCLE_KEYS + ["scene_assignment"]) \
			or candidate.lifecycle.state != "PLAYING" or candidate.lifecycle.restore_provenance != null:
		return _fail(&"scene_initial_state_invalid", "initial candidate cannot contain prior state")
	var materials := SCENE_EVENT_CONTRACT._validate_initial_materials(allocation_candidate, profile_material, issuer)
	if not materials.ok: return materials
	var transaction_id: String = allocation_candidate.request.transaction_id
	if candidate.run_id != allocation_candidate.run_id:
		return _fail(&"scene_initial_state_invalid", "initial Run must use the creation identity")
	for member: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance", "causal_day_instance_issuer_receipt"]:
		if not _scene_exact_value(candidate.lifecycle[member], allocation_candidate[member]):
			return _fail(&"invalid_lifecycle", "initial lifecycle differs from its allocation")
	if not _scene_exact_value(candidate.lifecycle.scene_assignment, profile_material.scene_assignment.receipt):
		return _fail(&"invalid_lifecycle", "initial lifecycle differs from its frozen assignment")
	if acknowledged_checkpoint.is_empty():
		var current := validate_current_scene(candidate.scene, bundle)
		if not current.ok: return current
		var audio := derive_scene_audio_context(candidate, bundle)
		if not audio.ok: return audio
	else:
		if not _scene_current_keys(candidate.scene) \
				or candidate.scene.registration_sha256 != acknowledged_checkpoint.manifest_fingerprint \
				or candidate.scene.entry_id != acknowledged_checkpoint.entry_id \
				or acknowledged_checkpoint.transaction_id != transaction_id \
				or candidate.content_version != acknowledged_checkpoint.content_version \
				or not _scene_exact_value(candidate.narrative_checkpoint, acknowledged_checkpoint):
			return _fail(&"scene_initial_state_invalid", "historical creation differs from retained initial reading")
	if candidate.scene.active_occurrence_id != transaction_id or candidate.scene.notification != {} \
			or candidate.scene.active_challenge != {} or candidate.scene.return_to != null:
		return _fail(&"scene_initial_state_invalid", "initial scene cannot contain prior control state")
	var gameplay_error := _validate_scene_gameplay(candidate.gameplay)
	if not gameplay_error.is_empty(): return _fail(&"invalid_gameplay", gameplay_error)
	var game_owner: Script = load("res://autoload/GameState.gd")
	var gameplay: Dictionary = game_owner.make_scene_new_run_gameplay()
	if not _scene_exact_value(candidate.gameplay, gameplay) \
			or not _scene_exact_value(candidate.contacts, SCENE_CONTACTS.make_scene_defaults()):
		return _fail(&"scene_initial_state_invalid", "initial gameplay and Contacts must be pristine owner defaults")
	var consequence: Dictionary = DESKTOP_CONSEQUENCE_STATE.make_empty({
		"causal_day_instance": allocation_candidate.causal_day_instance,
		"causal_day_instance_issuer_receipt": allocation_candidate.causal_day_instance_issuer_receipt})
	if not consequence.ok: return consequence
	var desktop := {"board": DESKTOP_BOARD_STATE.new().capture(), "consequence": consequence.value.state}
	desktop.board.erase("terminal_receipts")
	desktop.board["settled_inspection"] = false
	desktop.board["round_paid"] = false
	var player_board: Dictionary = DESKTOP_BOARD_STATE.project_player_state(desktop.board)
	if not player_board.ok: return player_board
	desktop.board = player_board.value.snapshot
	if not _scene_exact_value(candidate.desktop, desktop):
		return _fail(&"scene_initial_state_invalid", "initial desktop cannot contain prior attempts or consequences")
	if not acknowledged_checkpoint.is_empty():
		return {"ok": true, "code": &"ok", "value": {"candidate": candidate}}
	var reading := _validate_scene_reading(candidate)
	if not reading.ok: return reading
	var checkpoint: Dictionary = reading.checkpoint
	var saved: Dictionary = checkpoint.reading_session
	if checkpoint.transaction_id != transaction_id or checkpoint.entry_id != candidate.scene.entry_id \
			or typeof(checkpoint.content_version) != TYPE_INT or typeof(saved.schema_version) != TYPE_INT \
			or typeof(saved.program_index) != TYPE_INT \
			or saved.boundary != "line" or saved.next_operation != null \
			or saved.ledger.captions.size() != 1 or saved.ledger.entry_contexts.size() != 1:
		return _fail(&"scene_initial_state_invalid", "initial reading must contain only its first caption and frame")
	var bridge_owner: Script = load("res://autoload/DialogicBridge.gd")
	# Reading admission prepared the selected entry. This callback-free tail
	# can reuse that configuration while rebuilding a wholly new ledger.
	var initial_reading: Dictionary = bridge_owner._build_current_scene_initial_checkpoint(candidate.scene, bundle, reading.session)
	if not initial_reading.ok: return initial_reading
	var projected_initial: Dictionary = SCENE_READING.project_player_checkpoint(initial_reading.value)
	if not projected_initial.ok: return projected_initial
	var projected_candidate: Dictionary = SCENE_READING.project_player_checkpoint(checkpoint)
	if not projected_candidate.ok: return projected_candidate
	if not _scene_exact_value(projected_candidate.value, projected_initial.value):
		return _fail(&"scene_initial_state_invalid", "initial checkpoint must be the registered target's exact first caption")
	var frozen_owner: Script = load("res://scripts/narrative/FrozenRunContext.gd")
	var frames: Dictionary = frozen_owner.derive_current_scene_frames(candidate.scene, saved)
	if not frames.ok: return frames
	if frames.value.entry_contexts.size() != 1 \
			or not _scene_exact_value(frames.value.entry_contexts.values()[0], checkpoint.frozen_context):
		return _fail(&"reading_entry_context_mismatch", "initial frozen frame differs from its authenticated admission")
	return {"ok": true, "code": &"ok", "value": {"candidate": candidate}}

## Historical normalization must never coerce the new authenticated variant.
## Float-valued story/audio leaves remain untouched; this screens only identity,
## initial receipts and the integer snapshot header before any normalization.
static func _scene_has_initial_admission(snapshot: Dictionary) -> bool:
	return snapshot.get("schema_version") == SCENE_SCHEMA_VERSION or snapshot.has("scene")

static func _scene_initial_types_error(snapshot: Dictionary) -> String:
	if not _scene_has_initial_admission(snapshot): return ""
	for member: String in ["schema_version", "content_version", "checkpoint_sequence"]:
		if snapshot.has(member) and typeof(snapshot[member]) != TYPE_INT:
			return "Scene snapshot header must retain integer types"
	var lifecycle: Variant = snapshot.get("lifecycle")
	if lifecycle is Dictionary and not SCENE_EVENT_CONTRACT._same_types(lifecycle, _normalize_integral_floats(lifecycle)):
		return "Scene lifecycle must retain exact identity types"
	return ""

static func _scene_exact_value(left: Variant, right: Variant) -> bool:
	return SCENE_EVENT_CONTRACT._same_types(left, right) and _scene_equal(left, right)

static func validate_scene(snapshot: Dictionary, bundle: Dictionary) -> Dictionary:
	var started_us: int = SCENE_VALIDATION_TIMING.start_sample()
	if started_us < 0: return _validate_scene_observed_body(snapshot, bundle)
	var observation: Dictionary = {}
	var sequence: Variant = snapshot.get("checkpoint_sequence")
	if typeof(sequence) == TYPE_INT: observation["checkpoint_sequence"] = sequence
	var lifecycle_label: Variant = snapshot.get("lifecycle")
	if lifecycle_label is Dictionary:
		var state_label: Variant = lifecycle_label.get("state")
		if typeof(state_label) in [TYPE_STRING, TYPE_STRING_NAME] and String(state_label) in LIFECYCLE_STATES:
			observation["lifecycle_state"] = String(state_label)
		var plan_label: Variant = lifecycle_label.get("ending_plan")
		if plan_label is Dictionary:
			var stage_label: Variant = plan_label.get("playback_stage")
			if typeof(stage_label) in [TYPE_STRING, TYPE_STRING_NAME] and String(stage_label) in PLAYBACK_SEQUENCE:
				observation["playback_stage"] = String(stage_label)
	# An active record must remain nonempty even when malformed input has no admitted labels.
	observation["inclusive_nested"] = true
	var result: Dictionary = _validate_scene_observed_body(snapshot, bundle, observation)
	SCENE_VALIDATION_TIMING.finish_snapshot(started_us, observation, bool(result.get("ok", false)))
	return result


static func _validate_scene_observed_body(snapshot: Dictionary, bundle: Dictionary,
		observation: Dictionary = {}) -> Dictionary:
	var phase_tick: int = Time.get_ticks_usec() if not observation.is_empty() else 0
	var type_error := _scene_initial_types_error(snapshot)
	if not type_error.is_empty(): return _fail(&"scene_initial_types_invalid", type_error)
	if not is_instance_valid(_scene_issuer) or not is_instance_valid(_scene_authority) or _scene_semantic_busy:
		return _fail(&"scene_validation_unavailable", "scene semantic owner unavailable or reentrant")
	var selected: Dictionary = SCENE_MANIFEST.scene_contract_tables()
	if not selected.ok: return selected
	if not is_same(bundle, selected.bundle) and not _scene_exact_value(selected.bundle, bundle):
		return _fail(&"scene_registration_mismatch", "saved data cannot select a registration")
	bundle = selected.bundle
	var retained := snapshot.duplicate()
	retained.erase("audio_context")
	retained.erase("active_app_id")
	var candidate: Dictionary = _normalize_integral_floats(retained)
	var primitive := validate_primitive_tree(candidate)
	if not primitive.ok: return primitive
	if not _scene_keys(candidate, SCENE_TOP_KEYS) or typeof(candidate.schema_version) != TYPE_INT \
			or candidate.schema_version != SCENE_SCHEMA_VERSION or candidate.route_id != "scene" \
			or not _scene_id(candidate.run_id) or not _scene_int(candidate.content_version, 1) \
			or not _scene_int(candidate.checkpoint_sequence, 0) \
			or candidate.checkpoint_id != "%s:%d" % [candidate.run_id, candidate.checkpoint_sequence]:
		return _fail(&"invalid_snapshot_shape", "invalid Run9 header or member set")
	if not candidate.lifecycle is Dictionary or candidate.lifecycle.get("run_id") != candidate.run_id:
		return _fail(&"invalid_lifecycle", "scene lifecycle must belong to its Run")
	# Old Run9 saves keep their progress; the retired run-level form is no longer state.
	candidate.lifecycle.erase("scene_assignment")
	var lifecycle_keys := SCENE_LIFECYCLE_KEYS.duplicate()
	if candidate.lifecycle.has("completed_registration_sha256"): lifecycle_keys.append("completed_registration_sha256")
	if not _scene_keys(candidate.lifecycle, lifecycle_keys) or candidate.lifecycle.state not in ["PLAYING", "COMPLETED"]:
		return _fail(&"invalid_lifecycle", "current Scene uses ordinary passage lifecycle")
	var lifecycle: Dictionary = RUN_LIFECYCLE.validate_scene(candidate.lifecycle, _scene_issuer)
	if not lifecycle.ok: return lifecycle
	if not candidate.contacts is Dictionary:
		return _fail(&"invalid_snapshot_shape", "Contacts must be an object")
	var current := validate_current_scene(candidate.scene, bundle)
	if not current.ok: return current
	var gameplay_error := _validate_scene_gameplay(candidate.gameplay)
	if not gameplay_error.is_empty(): return _fail(&"invalid_gameplay", gameplay_error)
	var binding := _validate_scene_challenge_binding(candidate.scene, candidate.gameplay, bundle)
	if not binding.ok: return binding
	var contacts: Dictionary = SCENE_CONTACTS.validate_scene_state(candidate.contacts, candidate.scene.registration_sha256, _scene_issuer)
	if not contacts.ok: return contacts
	for receipt: Dictionary in candidate.contacts.transaction_receipts.values():
		if receipt.context.identity.run_id != candidate.run_id:
			return _fail(&"scene_contact_run_changed", "Contacts receipt belongs to another run")
	if not _scene_keys(candidate.desktop, DESKTOP_KEYS) or not candidate.desktop.board is Dictionary \
			or not candidate.desktop.consequence is Dictionary:
		return _fail(&"invalid_desktop_aggregate", "desktop requires its exact owners")
	var board: Dictionary = DESKTOP_BOARD_STATE.new().prepare_player_restore_scene(candidate.desktop.board, _scene_issuer)
	if not board.ok: return board
	var board_identity := _validate_scene_board_identity(candidate.desktop.board, candidate.lifecycle)
	if not board_identity.ok: return board_identity
	var consequence: Dictionary = DESKTOP_CONSEQUENCE_STATE.validate(candidate.desktop.consequence)
	if not consequence.ok: return consequence
	var audio := derive_scene_audio_context(candidate, bundle)
	if not audio.ok: return audio
	var reading := _validate_scene_reading(candidate)
	if not reading.ok: return reading
	# The live owner checks current physical Profile references and the reading
	# frame without executing prior story controls.
	# It must not call Run.validate again. A Boolean supplied by saved data is
	# never substituted for this privately installed owner.
	phase_tick = SCENE_VALIDATION_TIMING.snapshot_phase(observation, "pre_semantic_us", phase_tick)
	# Normalization detached the candidate; registration is recursively read-only.
	# Production semantic validation reads both synchronously without publishing state.
	var installed_bundle: Dictionary = selected.bundle
	phase_tick = SCENE_VALIDATION_TIMING.snapshot_phase(observation, "guard_prepare_us", phase_tick)
	var semantic_owner: Object = _scene_authority
	_scene_semantic_busy = true
	var semantic: Variant = semantic_owner.call("validate_scene_snapshot_semantics", candidate, installed_bundle)
	_scene_semantic_busy = false
	phase_tick = SCENE_VALIDATION_TIMING.snapshot_phase(observation, "semantic_us", phase_tick)
	SCENE_VALIDATION_TIMING.snapshot_phase(observation, "guard_verify_us", phase_tick)
	if not semantic is Dictionary or semantic.get("ok") != true:
		return semantic if semantic is Dictionary else _fail(&"scene_validation_invalid_result", "semantic owner must return a result")
	return {"ok": true, "code": &"ok", "value": {"candidate": candidate}}

## Identity checks select an existing validator, never a caller-supplied trust assertion.
static func _scene_semantic_authenticates_receipts() -> bool:
	if not is_instance_valid(_scene_authority) or _scene_authority.get_script() != load("res://autoload/GameState.gd"):
		return false
	var owner := _scene_authority as Node
	return owner.get("_identity_issuer") == _scene_issuer \
		and owner.get_node_or_null("/root/SaveManager") == _scene_creation_owner

static func _scene_can_reuse_reading() -> bool:
	if not _scene_semantic_authenticates_receipts(): return false
	var bridge: Variant = _scene_authority.get("_scene_event_bridge")
	return is_instance_valid(bridge) and bridge.get_script() == load("res://autoload/DialogicBridge.gd")

static func _scene_terminal_reading_owners() -> Array:
	if not _scene_semantic_authenticates_receipts(): return []
	var frozen := preload("res://scripts/narrative/FrozenRunContext.gd")
	if not frozen.scene_validation_uses(_scene_issuer, _scene_creation_owner): return []
	return [_scene_authority, _scene_issuer, _scene_creation_owner]

static func _scene_terminal_reading_owners_match(owners: Array) -> bool:
	return not owners.is_empty() and owners == _scene_terminal_reading_owners()

static func is_scene_terminal(snapshot: Dictionary) -> bool:
	var lifecycle: Variant = snapshot.get("lifecycle")
	return lifecycle is Dictionary and lifecycle.get("ending_plan") is Dictionary \
		and lifecycle.ending_plan.get("source_kind") == "scene" \
		and lifecycle.get("state") in ["ENDING", "COMPLETED"]

static func _validate_scene_reading(candidate: Dictionary) -> Dictionary:
	if not candidate.get("narrative_checkpoint") is Dictionary:
		return _fail(&"reading_checkpoint_invalid", "narrative checkpoint must be an object")
	var expanded: Dictionary = SCENE_READING.expand_player_checkpoint(candidate.narrative_checkpoint)
	if not expanded.ok: return expanded
	var checkpoint: Variant = expanded.value
	if not _scene_keys(checkpoint, SCENE_CHECKPOINT_KEYS) or checkpoint.stage != "scene" \
			or not _scene_id(checkpoint.entry_id) or not _scene_id(checkpoint.transaction_id) \
			or checkpoint.content_version != candidate.content_version \
			or checkpoint.manifest_fingerprint != candidate.scene.registration_sha256 \
			or not checkpoint.reading_session is Dictionary or not checkpoint.frozen_context is Dictionary:
		return _fail(&"reading_checkpoint_invalid", "Run9 requires a complete scene checkpoint")
	var saved: Dictionary = checkpoint.reading_session
	if saved.get("schema_version") != 5 or saved.get("occurrence_id") != candidate.scene.active_occurrence_id \
			or saved.get("entry_id") != checkpoint.entry_id or checkpoint.entry_id != candidate.scene.entry_id:
		return _fail(&"reading_context_invalid", "active occurrence and reading5 must agree")
	var session: RefCounted = expanded.get("session")
	if session == null:
		# Expanded reading5 inputs still require their own restoration.
		session = SCENE_READING.new()
		var configured: Dictionary = session.configure_scene()
		if not configured.ok: return configured
		var restored: Dictionary = session.restore(saved, checkpoint.entry_id)
		if not restored.ok: return restored
	if not checkpoint.frozen_context.get("presentation") is Dictionary:
		return _fail(&"reading_context_invalid", "frozen presentation must be an object")
	var fields: Variant = checkpoint.frozen_context.presentation.get("fields")
	if not fields is Dictionary or fields.get("occurrence_id") != candidate.scene.active_occurrence_id \
			or fields.get("admission_receipt_id") != candidate.scene.active_occurrence_id \
			or fields.get("entry_id") != checkpoint.entry_id \
			or checkpoint.frozen_context.get("transaction_id") != checkpoint.transaction_id:
		return _fail(&"reading_context_invalid", "active admission and frozen wrapper must agree")
	if candidate.scene.active_challenge.is_empty() and saved.boundary == "control":
		var selected := SCENE_MANIFEST.scene_contract_tables()
		if not selected.ok: return selected
		var node: Dictionary = session._scene_nodes[checkpoint.entry_id][saved.program_index]
		for challenge: Dictionary in selected.bundle.challenges:
			if challenge.entry_id == checkpoint.entry_id and challenge.playable_marker_id == node.get("marker_id"):
				return _fail(&"scene_challenge_position_invalid", "held playable requires its current Challenge")
	if not candidate.scene.active_challenge.is_empty():
		var selected := SCENE_MANIFEST.scene_contract_tables()
		if not selected.ok: return selected
		var challenge := {}
		for row: Dictionary in selected.bundle.challenges:
			if row.challenge_id == candidate.scene.active_challenge.challenge_id: challenge = row
		var nodes: Array = session._scene_nodes.get(checkpoint.entry_id, [])
		var playable_index := -1
		var end_index := -1
		for index: int in nodes.size():
			if nodes[index].get("marker_id") == challenge.get("playable_marker_id"): playable_index = index
			if nodes[index].get("marker_id") == challenge.get("end_marker_id"): end_index = index
		var position: int = saved.program_index
		var cue: bool = playable_index > 0 and end_index == playable_index + 1 \
				and position == playable_index - 1 and saved.boundary == "line" \
				and nodes[position].get("kind") == "caption"
		if playable_index < 0 or end_index <= playable_index \
				or (not cue and (position < playable_index or position >= end_index)):
			var record: Dictionary = candidate.gameplay.route_context.get("active_dating_challenge", {})
			if record.is_empty() or record.context.challenge_id != candidate.scene.active_challenge.challenge_id \
					or record.context.playable_command_id != candidate.scene.active_challenge.playable_command_id:
				return _fail(&"scene_challenge_position_invalid", "suspended Challenge requires its retained physical record")
			# A suspended board cannot authorize another current playable marker.
			if saved.boundary == "control":
				var node: Dictionary = nodes[position]
				for row: Dictionary in selected.bundle.challenges:
					if row.entry_id == checkpoint.entry_id and row.playable_marker_id == node.get("marker_id"):
						return _fail(&"scene_challenge_position_invalid", "held playable differs from suspended Challenge")
	return {"ok": true, "session": session, "checkpoint": checkpoint}

## For the actual GameState rollback/capture owner. This validates the complete
## captured input without inventing a narrative checkpoint. Full save admission
## still additionally requires validate_scene's reading and semantic checks.
static func validate_scene_input_fields(input: Dictionary, bundle: Dictionary) -> Dictionary:
	var type_error := _scene_initial_types_error(input)
	if not type_error.is_empty(): return _fail(&"scene_initial_types_invalid", type_error)
	if not is_instance_valid(_scene_issuer): return _fail(&"scene_validation_unavailable", "issuer unavailable")
	if not _scene_keys(input, SCENE_INPUT_KEYS): return _fail(&"invalid_snapshot_input", "incomplete scene capture")
	var primitive := validate_primitive_tree(input)
	if not primitive.ok: return primitive
	var selected: Dictionary = SCENE_MANIFEST.scene_contract_tables()
	if not selected.ok: return selected
	if not is_same(bundle, selected.bundle) and not _scene_exact_value(selected.bundle, bundle): return _fail(&"scene_registration_mismatch", "unselected bundle")
	bundle = selected.bundle
	if not input.lifecycle is Dictionary: return _fail(&"invalid_lifecycle", "invalid scene lifecycle")
	var lifecycle: Dictionary = RUN_LIFECYCLE.validate_scene(input.lifecycle, _scene_issuer)
	if not lifecycle.ok: return lifecycle
	var current := validate_current_scene(input.scene, bundle)
	if not current.ok: return current
	var gameplay_error := _validate_scene_gameplay(input.gameplay)
	if not gameplay_error.is_empty(): return _fail(&"invalid_gameplay", gameplay_error)
	var binding := _validate_scene_challenge_binding(input.scene, input.gameplay, bundle)
	if not binding.ok: return binding
	if not input.contacts is Dictionary or not input.command_receipts is Dictionary:
		return _fail(&"invalid_snapshot_input", "Contacts/receipts must be objects")
	var contacts: Dictionary = SCENE_CONTACTS.validate_scene_state(input.contacts, input.scene.registration_sha256, _scene_issuer)
	if not contacts.ok: return contacts
	for receipt: Dictionary in input.contacts.transaction_receipts.values():
		if receipt.context.identity.run_id != input.lifecycle.run_id:
			return _fail(&"scene_contact_run_changed", "Contacts receipt belongs to another run")
	if not _scene_keys(input.desktop, DESKTOP_KEYS) or not input.desktop.board is Dictionary \
			or not input.desktop.consequence is Dictionary: return _fail(&"invalid_desktop_aggregate", "invalid desktop owners")
	var board: Dictionary = DESKTOP_BOARD_STATE.new().prepare_restore_scene(input.desktop.board, _scene_issuer)
	if not board.ok: return board
	var board_identity := _validate_scene_board_identity(input.desktop.board, input.lifecycle)
	if not board_identity.ok: return board_identity
	var consequence: Dictionary = DESKTOP_CONSEQUENCE_STATE.validate(input.desktop.consequence)
	if not consequence.ok: return consequence
	for member: String in ["applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		var ids_error := _validate_transaction_ids(input[member], member)
		if not ids_error.is_empty(): return _fail(&"invalid_transaction_ids", ids_error)
	return {"ok": true}

## Current Scene facts have one registration owner. No command history is needed.
static func validate_current_scene(scene: Variant, bundle: Dictionary) -> Dictionary:
	if not _scene_current_keys(scene) \
			or scene.registration_sha256 != SCENE_MANIFEST.scene_registration_fingerprint():
		return _fail(&"scene_registration_mismatch", "current Scene must use installed registration")
	var registered := SCENE_EVENT_CONTRACT.validate_bundle_structure(bundle)
	if not registered.ok: return registered
	var tables: Dictionary = registered.value
	if tables.fingerprint != scene.registration_sha256:
		return _fail(&"scene_registration_mismatch", "current Scene cannot select another bundle")
	var frame := _validate_current_scene_frame(scene, tables)
	if not frame.ok: return frame
	var presentation := _resolve_scene_presentation(scene)
	if not presentation.ok: return presentation
	if scene.return_to == null: return presentation
	var back: Variant = scene.return_to
	if not _scene_keys(back, ["parent", "target_id", "contact_event_id"]) \
			or not _scene_keys(back.parent, ["active_occurrence_id", "entry_id", "notification", "active_challenge"]) \
			or not _scene_id(back.target_id) or not _scene_id(back.contact_event_id) \
			or not tables.targets.has(back.target_id) or not tables.contacts.has(back.contact_event_id):
		return _fail(&"scene_contact_parent_invalid", "current Contacts return must be registered")
	var parent := _validate_current_scene_frame(back.parent, tables)
	if not parent.ok: return parent
	var contact: Dictionary = tables.contacts[back.contact_event_id]
	var target: Dictionary = tables.targets[back.target_id].target
	if back.parent.active_occurrence_id == scene.active_occurrence_id \
			or contact.entry_id != scene.entry_id or contact.return_target_id != back.target_id \
			or target.kind != "return" or target.entry_id != back.parent.entry_id:
		return _fail(&"scene_contact_parent_invalid", "Contacts return differs from its registered parent")
	return presentation

static func _validate_scene_challenge_binding(scene: Dictionary, gameplay: Dictionary, bundle: Dictionary) -> Dictionary:
	if scene.active_challenge.is_empty(): return {"ok": true}
	var active: Dictionary = scene.active_challenge
	for challenge: Dictionary in bundle.challenges:
		if challenge.challenge_id == active.challenge_id and challenge.entry_id == scene.entry_id:
			return {"ok": true}
	var record: Dictionary = gameplay.route_context.get("active_dating_challenge", {})
	if record.is_empty() or record.context.challenge_id != active.challenge_id \
			or record.context.playable_command_id != active.playable_command_id:
		return _fail(&"scene_challenge_state_invalid", "suspended Challenge requires its exact retained physical record")
	return {"ok": true}

static func _validate_current_scene_frame(frame: Dictionary, tables: Dictionary) -> Dictionary:
	if not _scene_id(frame.active_occurrence_id) or not _scene_id(frame.entry_id) \
			or not tables.entries.has(frame.entry_id) or not frame.notification is Dictionary \
			or not frame.active_challenge is Dictionary:
		return _fail(&"scene_current_state_invalid", "current entry and controls are invalid")
	if not frame.notification.is_empty():
		var found := false
		for bound: Dictionary in tables.markers.values():
			if bound.entry_id == frame.entry_id and bound.marker.kind == "notification.set" \
					and _scene_exact_value(bound.marker.payload, frame.notification): found = true
		if not found: return _fail(&"scene_notification_invalid", "notification must match an authored control")
	if not frame.active_challenge.is_empty():
		var challenge: Dictionary = frame.active_challenge
		if not _scene_keys(challenge, ["challenge_id", "playable_command_id"]) \
				or not _scene_id(challenge.challenge_id) or not _scene_id(challenge.playable_command_id):
			return _fail(&"scene_challenge_state_invalid", "active Challenge binding is malformed")
	return {"ok": true}

## Save only the selected plan label; asset metadata stays with authored content.
## Terminal snapshots retain the source admission and therefore its soundtrack.
static func derive_scene_audio_context(snapshot: Dictionary, bundle: Dictionary = {}) -> Dictionary:
	if bundle.is_empty():
		var selected: Dictionary = SCENE_MANIFEST.scene_contract_tables()
		if not selected.ok: return selected
		bundle = selected.bundle
	if bundle.get("schema_version") != 3:
		var presentation := _resolve_scene_presentation(snapshot.get("scene", {}))
		if not presentation.ok: return presentation
		if not presentation.value.is_empty() and not str(presentation.value.audio_plan_id).is_empty():
			return _fail(&"scene_audio_owner_unavailable", "named presentation requires its authored audio plan")
		return {"ok": true, "value": {"ambience_context": {}, "ambience_context_id": "",
			"music_context": {}, "music_context_id": ""}}
	var current := validate_current_scene(snapshot.get("scene"), bundle)
	if not current.ok: return current
	var owner: Script = load("res://scripts/data/AudioManifest.gd")
	if owner == null or not owner.has_method("make_scene_context"):
		return _fail(&"scene_audio_owner_unavailable", "canonical audio owner required")
	if snapshot.scene.has("music_plan_id"):
		return owner.call("make_named_presentation_context", bundle, snapshot.scene.music_plan_id, snapshot.scene.active_occurrence_id)
	if not current.value.is_empty():
		return owner.call("make_named_presentation_context", bundle,
			current.value.audio_plan_id, snapshot.scene.active_occurrence_id)
	return owner.call("make_scene_context", bundle, snapshot.scene.entry_id, snapshot.scene.active_occurrence_id)


static func _scene_current_keys(scene: Variant) -> bool:
	var keys := ["registration_sha256", "active_occurrence_id", "entry_id", "notification", "active_challenge", "return_to"]
	if scene is Dictionary and scene.has("presentation"): keys.append("presentation")
	if scene is Dictionary and scene.has("music_plan_id"):
		if not scene.music_plan_id is String: return false
		keys.append("music_plan_id")
	return _scene_keys(scene, keys)


static func _resolve_scene_presentation(scene: Dictionary) -> Dictionary:
	if not scene.has("presentation"): return {"ok": true, "value": {}}
	if not scene.presentation is Dictionary:
		return _fail(&"scene_presentation_invalid", "saved presentation must be an object")
	return preload("res://scripts/data/ArtManifest.gd").resolve_saved_presentation(scene.presentation)


static func _validate_scene_gameplay(gameplay: Variant) -> String:
	if not _scene_keys(gameplay, SCENE_GAMEPLAY_KEYS): return "unexpected scene gameplay members"
	for key: String in ["inventory",
			"minesweeper_task_rewards_claimed", "narrative_variables", "route_context", "shop_purchase_counts", "story_flags"]:
		if not gameplay[key] is Dictionary: return key + " must be an object"
	if not _scene_keys(gameplay.stats, ["pressure"]) or not _scene_int(gameplay.stats.pressure, 0, 12):
		return "stats must contain only pressure in 0..12"
	if not _scene_int(gameplay.money, -30) or not _scene_int(gameplay.coins, 0): return "invalid money/coins"
	for key: String in ["minesweeper_app_rounds_finished_today", "minesweeper_money_earned_today", "minesweeper_rng_seed",
			"penalty_points_today", "penalty_points_total"]:
		if not _scene_int(gameplay[key], 0): return "invalid " + key
	if gameplay.penalty_points_total < gameplay.penalty_points_today: return "penalty total precedes current count"
	if not _scene_int(gameplay.minesweeper_round_floor, -3, 0) \
			or not _scene_int(gameplay.minesweeper_rounds_left, gameplay.minesweeper_round_floor, 2): return "invalid desktop round bounds"
	if gameplay.minesweeper_selected_difficulty not in ["beginner", "intermediate", "expert"]:
		return "unregistered desktop difficulty"
	for item: Variant in gameplay.inventory:
		if not _scene_id(item) or not _scene_int(gameplay.inventory[item], 0): return "invalid inventory count"
	var owned: Dictionary = SCENE_CAPABILITIES.resolve_owned(gameplay.inventory)
	if not owned.ok: return "invalid inventory capabilities"
	var spec: Dictionary = SCENE_CAPABILITIES.build_spec_inputs(owned.value, gameplay.stats.pressure, gameplay.penalty_points_today)
	if not spec.ok: return "invalid capability inputs"
	var notes: Dictionary = NOTE_PURCHASE_RULES.validate_counts(gameplay.shop_purchase_counts)
	if not notes.ok: return "invalid Notes purchase counts"
	for task: Variant in gameplay.minesweeper_task_rewards_claimed:
		if task not in ["complete_beginner", "complete_intermediate", "complete_expert", "no_flag_finish", "foresight_finish",
				"perfect_beginner", "perfect_intermediate", "perfect_expert", "win_win_win"] \
				or typeof(gameplay.minesweeper_task_rewards_claimed[task]) != TYPE_BOOL: return "invalid task reward claim"
	var registered := _registered_narrative_variables()
	for variable: Variant in gameplay.narrative_variables:
		if variable not in registered: return "unregistered narrative variable"
	var progress_error := _validate_scene_progress(gameplay.scene_choices, gameplay.scene_challenge_outcomes)
	if progress_error != "": return progress_error
	return _validate_scene_route_context(gameplay.route_context)

## Scene progress is current Run state; gameplay semantics are checked by GameState.
static func _validate_scene_progress(choices: Variant, outcomes: Variant) -> String:
	if not choices is Dictionary or not outcomes is Dictionary: return "scene progress must be objects"
	if choices.is_empty() and outcomes.is_empty(): return ""
	# These are encountered facts, including choices and Challenges retired by an
	# authoring edit. Current controls still validate new commands at dispatch.
	for opportunity: Variant in choices:
		if not _scene_id(opportunity) or not _scene_id(choices[opportunity]):
			return "invalid scene choice"
	for occurrence: Variant in outcomes:
		var outcome: Variant = outcomes[occurrence]
		if not _scene_digest(occurrence) or not outcome is Dictionary:
			return "invalid scene challenge outcome"
		if not _scene_keys(outcome, ["challenge_id", "outcome"]) \
				and not _scene_keys(outcome, ["challenge_id", "outcome", "physical_slot"]):
			return "invalid scene challenge outcome"
		if not _scene_id(outcome.challenge_id) \
				or outcome.outcome not in ["never_started", "unfinished", "lost", "won", "perfect"]:
			return "invalid scene challenge outcome"
		var slot: Variant = outcome.get("physical_slot", "")
		if not slot is String or (slot != "" and (not slot.begins_with("scene.challenge.") \
				or not _scene_digest(slot.trim_prefix("scene.challenge.")))) \
				or (outcome.outcome == "never_started" and slot != ""):
			return "invalid scene challenge physical slot"
	return ""

static func _validate_scene_route_context(context: Dictionary) -> String:
	for key: String in context:
		if key not in ["active_dating_challenge", "dating_active_attempt_ref", "dating_canonical_heads"]:
			return "unregistered scene route-context member"
		if not context[key] is Dictionary: return "scene route-context owner must be an object"
	var record: Dictionary = context.get("active_dating_challenge", {})
	var reference: Dictionary = context.get("dating_active_attempt_ref", {})
	if not record.is_empty():
		if record.get("schema_version") != 4 or not SCENE_ATTEMPTS.validate_record(record): return "invalid scene physical record"
		if not _scene_keys(reference, ["attempt_id", "branch_id", "generation"]) \
				or reference.attempt_id != record.spec.board_token or not _scene_id(reference.branch_id) \
				or not _scene_int(reference.generation, 1): return "scene physical record requires its matching attempt reference"
	elif not reference.is_empty(): return "attempt reference without physical record"
	for slot: Variant in context.get("dating_canonical_heads", {}):
		var head: Variant = context.dating_canonical_heads[slot]
		if not _scene_id(slot) or not str(slot).begins_with("scene.challenge.") \
				or not _scene_keys(head, ["attempt_id", "branch_id"]) \
				or not _scene_id(head.attempt_id) or not _scene_id(head.branch_id): return "invalid scene canonical head"
	return ""

static func _scene_keys(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size(): return false
	for key: Variant in value:
		if not key is String or key not in keys: return false
	return true

static func _scene_id(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()

static func _scene_int(value: Variant, minimum: int, maximum: int = 9223372036854775807) -> bool:
	return typeof(value) == TYPE_INT and value >= minimum and value <= maximum

static func _scene_digest(value: Variant) -> bool:
	return value is String and value.length() == 64 and value.is_valid_hex_number(false) and value == value.to_lower()

static func _scene_hash(value: Variant) -> String:
	var encoded: Dictionary = SCENE_CANONICAL.stringify(value)
	return str(encoded.value).sha256_text() if encoded.ok else ""

# The board owner validates its identity shape; this aggregate owns its Run join.
# This closes an existing consistency gap, not a historical-payment proof check.
static func _validate_scene_board_identity(board: Dictionary, lifecycle: Dictionary) -> Dictionary:
	if board.identity == null: return {"ok": true}
	for member: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance"]:
		if not _scene_exact_value(board.identity[member], lifecycle[member]):
			return _fail(&"scene_board_identity_mismatch", "board and lifecycle differ: " + member)
	return {"ok": true}


static func _scene_equal(a: Variant, b: Variant) -> bool:
	var hash := _scene_hash(a)
	return not hash.is_empty() and hash == _scene_hash(b)

