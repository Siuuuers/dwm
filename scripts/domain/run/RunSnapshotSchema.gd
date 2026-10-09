class_name RunSnapshotSchema
extends RefCounted

## v4 run-snapshot schema (Plan 02 Task 6, dwm-p2r.32, amendment §11.2; v3 committed-Schedule
## boundary from Plan 01 Task 5, dwm-p2r.13).
##
## v4 preserves v3's `committed_schedule` byte-for-byte and adds exactly one new top-level member,
## `desktop` (exact keys `{board,consequence}`), plus five new members inside the already-existing
## `lifecycle` object -- never as additional top-level aliases. `board` validation is delegated
## wholesale to `DesktopBoardState` (via a throwaway instance's own `prepare_restore()`, its
## established structural-validation entry point) and `consequence` to `DesktopConsequenceState.
## validate()`; this module owns no second copy of either shape. Desktop-identity lifecycle
## validation is likewise delegated wholesale to `RunLifecycle._validate_desktop_identity()` so the
## two owners of a lifecycle dict's shape (this schema, and the live RunLifecycle state machine)
## can never silently diverge.
##
## v6 reconciles captured run Dark with Amendment Plan 03 Task 4 (dwm-oyo.3). It adds the
## top-level `schedule_view` -- the bare seven-key `ScheduleViewState` view, with no wrapper or
## embedded fingerprint -- plus three condition/terminal members inside `lifecycle`, while retaining
## the captured `dark_mode` lifecycle field. View validation is delegated wholesale to
## `ScheduleViewState.validate()` against the LIVE `ScheduleActionRegistry`, with the persisted
## `committed_schedule.registry_fingerprint` passed VERBATIM (null included) as the expectation;
## this schema owns no second copy of the view envelope, the draft-entry law, or the append-only
## condition-departure ledger law. It owns only the in-document bindings a snapshot's single day
## and causal-day identity impose, plus the date-latch coherence check below.

## v7 requires every admitted canonical presentation's immutable source-bound context.
## Earlier Run snapshots are refused; no historical context or Profile fact is reconstructed.
## v8 adds strictly validated scene-event receipts to the existing command ledger.
const SCHEMA_VERSION := 8
const SCENE_SCHEMA_VERSION := 9
const RECOVERY_LINE_HISTORY_LIMIT := 32

const ORDINARY_CORRESPONDENCE := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")
const DAY_RESOLUTION_PLAN := preload("res://scripts/domain/run/DayResolutionPlan.gd")
const DATING_ENDING_RULES := preload("res://scripts/domain/ending/DatingEndingRules.gd")
const SCHEDULE_STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const NARRATIVE_VARIABLE_REGISTRY_PATH := "res://data/manifests/narrative_variables.json"
const DESKTOP_APP_REGISTRY := preload("res://scripts/domain/desktop/DesktopAppRegistry.gd")
const RUN_LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")
const DESKTOP_BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const DESKTOP_CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const SCHEDULE_VIEW_STATE := preload("res://scripts/domain/schedule/ScheduleViewState.gd")
const SCHEDULE_ACTION_REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const NOTE_PURCHASE_RULES := preload("res://scripts/domain/shop/RunNotePurchaseRules.gd")
const SCENE_EVENT_CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")

const TOP_KEYS: Array[String] = [
	"active_app_id", "applied_effect_transaction_ids", "applied_variable_transaction_ids",
	"audio_context", "checkpoint_id", "checkpoint_sequence", "command_receipts", "committed_schedule",
	"contacts", "content_version", "desktop",
	"dating", "gameplay", "lifecycle", "narrative_checkpoint", "route_id", "run_id",
	"schedule_view", "schema_version",
]
const DESKTOP_KEYS: Array[String] = ["board", "consequence"]
const LIFECYCLE_KEYS: Array[String] = [
	"active_condition_hospital_plan", "active_resolution_plan", "branch_id", "causal_day_instance",
	"causal_day_instance_issuer_receipt", "condition_hospital_history", "dark_mode", "day",
	"desktop_timeline_generation", "ending_plan", "restore_provenance", "run_id", "state",
	"terminal_intent_handoff",
]
const LIFECYCLE_STATES: Array[String] = ["PLAYING", "ENDING", "COMPLETED", "TERMINAL_PENDING"]
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
	if route_id == "scene":
		return build_scene(snapshot_input, dialogic_checkpoint, route_id, active_app_id,
			audio_context, content_version, checkpoint_sequence)
	for member: String in ["lifecycle", "gameplay", "contacts", "committed_schedule", "dating",
			"applied_effect_transaction_ids", "applied_variable_transaction_ids", "desktop",
			"schedule_view"]:
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
		"committed_schedule": _detached(snapshot_input["committed_schedule"]),
		"desktop": _detached(snapshot_input["desktop"]),
		"schedule_view": _detached(snapshot_input["schedule_view"]),
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
	var version: Variant = snapshot.get("schema_version")
	if typeof(version) == TYPE_FLOAT and is_finite(version) and version == floorf(version): version = int(version)
	if version == SCENE_SCHEMA_VERSION:
		var selected: Dictionary = SCENE_MANIFEST.scene_registration()
		if not selected.ok: return selected
		return validate_scene(snapshot, selected.value)
	# `_normalize_integral_floats()` allocates a FRESH Dictionary/Array at every container node,
	# so the candidate never aliases the caller and a `duplicate(true)` ahead of it only rebuilt
	# the same tree a second time. Proof obligation for the leaves the normalizer passes through
	# by reference instead of copying (Packed arrays, Objects): neither can ever reach a saved
	# document, so the removed copy protected nothing. `validate_primitive_tree()` below refuses
	# both with `invalid_primitive`, and `CanonicalJsonWriter._emit()` refuses both with
	# `unsupported_type`, so a document containing one cannot be written either.
	var normalized: Variant = _normalize_integral_floats(snapshot)
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
	if candidate["active_app_id"] != null:
		# Logout is registered on the launcher, but its consent is never saved as a workspace.
		if typeof(candidate["active_app_id"]) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return _fail(&"invalid_snapshot_shape", "active_app_id must be null or a content app id")
		var aid := StringName(candidate["active_app_id"])
		if aid == &"logout" or not DESKTOP_APP_REGISTRY.new().has_app(aid):
			return _fail(&"invalid_snapshot_shape", "active_app_id must be null or a content app id")
	for member: String in ["narrative_checkpoint", "contacts", "dating", "audio_context"]:
		if typeof(candidate[member]) != TYPE_DICTIONARY:
			return _fail(&"invalid_snapshot_shape", member + " must be an object")
		var member_check := validate_primitive_tree(candidate[member], "$." + member)
		if not member_check.get("ok", false):
			return member_check
	# The committed-Schedule aggregate law lives in exactly ONE module. Delegate wholesale and
	# surface the delegate's typed code unchanged; this schema owns no second copy of the member
	# set, the entry law, or the receipt binding.
	var committed_check: Dictionary = SCHEDULE_STATE_SCHEMA.validate_aggregate(
		candidate["committed_schedule"])
	if not committed_check.get("ok", false):
		return committed_check
	# The saved ScheduleView law lives in exactly ONE module (Amendment Plan 03 Task 2). Delegate
	# wholesale and surface the delegate's typed code AND details unchanged; this schema owns no
	# second copy of the view envelope, the draft-entry law, or the condition-departure ledger law.
	# The expected fingerprint is the persisted committed one, passed VERBATIM including null -- so
	# this delegation must run AFTER the committed_schedule delegation, whose own code wins when the
	# aggregate is malformed. ScheduleViewState.validate is typed `view: Dictionary`, so the local
	# Dictionary guard turns what would be an engine type error into a typed refusal.
	if typeof(candidate["schedule_view"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_snapshot_shape", "schedule_view must be an object")
	var registry_loaded: Dictionary = SCHEDULE_ACTION_REGISTRY.load_current()
	if not registry_loaded.get("ok", false):
		return registry_loaded
	var view_check: Dictionary = SCHEDULE_VIEW_STATE.validate(
		candidate["schedule_view"],
		(registry_loaded["value"] as Dictionary)["registry"],
		(candidate["committed_schedule"] as Dictionary)["registry_fingerprint"])
	if not view_check.get("ok", false):
		return view_check
	# ScheduleViewState never inspects the interior of pending_warning or the consumed-receipt
	# map, so the primitive-purity sweep over the whole view is this schema's job. Kept separate
	# from the member loop above because the member's own Dictionary guard already ran.
	var view_primitive := validate_primitive_tree(candidate["schedule_view"], "$.schedule_view")
	if not view_primitive.get("ok", false):
		return view_primitive
	var desktop_error := _validate_desktop(candidate["desktop"])
	if desktop_error != "":
		return _fail(&"invalid_desktop_aggregate", desktop_error)
	# The bindings this module DOES own: a snapshot names one day and one causal-day instance, so
	# neither the committed aggregate nor the saved view can disagree with the lifecycle about
	# which day (and, for the view, which causal-day instance) it belongs to.
	if int((candidate["committed_schedule"] as Dictionary)["day"]) \
			!= int((candidate["lifecycle"] as Dictionary)["day"]):
		return _fail(&"invalid_snapshot_shape",
			"committed_schedule day must equal the lifecycle day")
	if int((candidate["schedule_view"] as Dictionary)["day"]) \
			!= int((candidate["lifecycle"] as Dictionary)["day"]):
		return _fail(&"invalid_snapshot_shape",
			"schedule_view day must equal the lifecycle day")
	if str((candidate["schedule_view"] as Dictionary)["causal_day_instance"]) \
			!= str((candidate["lifecycle"] as Dictionary)["causal_day_instance"]):
		return _fail(&"invalid_snapshot_shape",
			"schedule_view causal_day_instance must equal the lifecycle causal_day_instance")
	var latch_error := _schedule_view_latch_error(candidate["schedule_view"])
	if latch_error != "":
		return _fail(&"invalid_snapshot_shape", latch_error)
	# The null-fingerprint pairing, view half: a null committed registry_fingerprint is legal only
	# beside an empty view. ScheduleViewState.validate answers the reachable case first with its own
	# typed code, so this binding is defensive (deviation D-12's shape) and exists so that the
	# document schema states the pairing it relies on rather than inheriting it silently.
	if (candidate["committed_schedule"] as Dictionary)["registry_fingerprint"] == null \
			and not ((candidate["schedule_view"] as Dictionary)["entries"] as Array).is_empty():
		return _fail(&"invalid_snapshot_shape",
			"a null committed_schedule registry_fingerprint requires an empty schedule_view")
	var ordinary_check: Dictionary = ORDINARY_CORRESPONDENCE.validate_state(candidate["contacts"])
	if not ordinary_check.get("ok", false):
		return _fail(&"invalid_ordinary_correspondence", str(ordinary_check.get("code", "")))
	var gameplay_error := _validate_gameplay(candidate["gameplay"])
	if gameplay_error != "":
		return _fail(&"invalid_gameplay", gameplay_error)
	# Primitive validation above keeps persisted keys strictly String. Runtime count
	# normalization must never widen the wire schema to accept StringName keys.
	var counts_check: Dictionary = NOTE_PURCHASE_RULES.validate_counts(
		(candidate["gameplay"] as Dictionary).get("shop_purchase_counts", {}))
	if not counts_check.get("ok", false):
		return _fail(&"invalid_gameplay", "invalid shop_purchase_counts")
	# Preserve omitted wire fields so full and proof-backed document builders keep
	# identical bytes. Restore owners materialize the empty map before mutation.
	if candidate["gameplay"].has("shop_purchase_counts"):
		candidate["gameplay"]["shop_purchase_counts"] = counts_check["value"]["shop_purchase_counts"]
	for member: String in ["applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		var ids_error := _validate_transaction_ids(candidate[member], member)
		if ids_error != "":
			return _fail(&"invalid_transaction_ids", ids_error)
	var receipts_error := _validate_command_receipts(candidate["command_receipts"],
		candidate["applied_effect_transaction_ids"], candidate["applied_variable_transaction_ids"])
	if receipts_error != "":
		return _fail(&"invalid_command_receipts", receipts_error)
	# Inspect the detached saved facts before any restore participant installs them.
	# v7 requires the applicable producer caches and their exact admitted projections.
	var frozen_check: Dictionary = preload("res://scripts/narrative/FrozenRunContext.gd").validate(candidate, true)
	if not frozen_check.get("ok", false): return frozen_check
	return {"ok": true, "code": &"ok", "value": {"candidate": candidate}}

## Effect/variable and scene-event command ledger. Ending/gallery receipt
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
		if kind in ["scene_event", "scene_admission"]:
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
	var validated := validate(snapshot)
	if not validated.get("ok", false):
		return validated
	var candidate: Dictionary = validated["value"]["candidate"]
	var lifecycle: Dictionary = candidate["lifecycle"]
	if candidate.schema_version == SCENE_SCHEMA_VERSION:
		return {"ok": true, "code": &"ok", "value": {
			"run_id": candidate.run_id, "lifecycle_state": lifecycle.state,
			"active_app_id": candidate.active_app_id, "scene": candidate.scene.duplicate(true),
			"contacts": candidate.contacts.duplicate(true)}}
	return {"ok": true, "code": &"ok", "value": {
		"run_id": str(candidate["run_id"]),
		"day": int(lifecycle["day"]),
		"lifecycle_state": str(lifecycle["state"]),
		"active_app_id": candidate["active_app_id"],
		"ending_plan": (lifecycle["ending_plan"] as Dictionary).duplicate(true) \
			if lifecycle["ending_plan"] != null else null,
		"contacts": (candidate["contacts"] as Dictionary).duplicate(true),
		"committed_schedule": (candidate["committed_schedule"] as Dictionary).duplicate(true),
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
	if typeof(lifecycle["dark_mode"]) != TYPE_BOOL:
		return "dark_mode must be a Boolean"
	if str(lifecycle["run_id"]) != str(candidate["run_id"]):
		return "lifecycle run_id must match the snapshot run_id"
	if typeof(lifecycle["day"]) != TYPE_INT or int(lifecycle["day"]) < 1 or int(lifecycle["day"]) > 7:
		return "day must be an integer 1..7: " + str(lifecycle["day"])
	var state := str(lifecycle["state"])
	if state not in LIFECYCLE_STATES:
		return "unknown lifecycle state: " + state
	# Delegated wholesale to RunLifecycle so this schema and the live state machine never diverge
	# about the shape of the desktop-identity lifecycle members it added in v4.
	var desktop_identity_error: String = RUN_LIFECYCLE._validate_desktop_identity(lifecycle)
	if desktop_identity_error != "":
		return desktop_identity_error
	# Likewise for the three condition-Hospital / terminal-intent members v5 added (Amendment Plan
	# 03 Task 4): one owner, reached through the same anti-divergence delegation.
	var condition_error: String = RUN_LIFECYCLE._validate_condition_lifecycle(lifecycle)
	if condition_error != "":
		return condition_error
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
		if state != "PLAYING" and state != "TERMINAL_PENDING":
			return state + " requires an ending plan"
	else:
		if state == "PLAYING":
			return "PLAYING requires a null ending plan"
		if state == "TERMINAL_PENDING":
			return "TERMINAL_PENDING requires a null ending plan"
		if int(lifecycle["day"]) != 7:
			return "an ending plan requires day 7"
		var ending_error := _validate_ending_plan(lifecycle["ending_plan"])
		if ending_error != "":
			return ending_error
	return ""

static func _validate_ending_plan(plan: Variant) -> String:
	if typeof(plan) != TYPE_DICTIONARY:
		return "ending_plan must be null or an object"
	# RunLifecycle is the single owner of both exact admitted shapes and their semantic laws.
	# The structural delegate retains its closed legacy/ordered union. The v7 frozen-context
	# check additionally requires the admitted ordered plan's source-bound seed.
	return RUN_LIFECYCLE._validate_ending_plan(plan as Dictionary)


## The date latch is monotone: the controller sets it on the first date entry and never clears it
## (ScheduleViewController.prepare_remove). A persisted view carrying a date entry with the latch
## still false is only reachable by tampering, and it would re-arm a warning queue the player
## already cleared -- so the persisted document is where that incoherence is refused. It is
## one-directional: a true latch beside zero date entries is the ordinary post-removal shape.
static func _schedule_view_latch_error(view: Variant) -> String:
	if bool((view as Dictionary)["date_entry_seen"]):
		return ""
	for raw: Variant in ((view as Dictionary)["entries"] as Array):
		if typeof(raw) != TYPE_DICTIONARY:
			continue  # ScheduleRules already refused this; do not double-report
		if str((raw as Dictionary).get("action_kind", "ordinary")) != "ordinary":
			return "date_entry_seen must be true while the view carries a date entry"
	return ""

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


## Scene format is admitted jointly with Save9. The legacy constants and paths
## above remain intact; no calendar-shaped defaults are produced for scenes.
const SCENE_MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const SCENE_CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const SCENE_READING := preload("res://scripts/narrative/SoloReadingSession.gd")
const SCENE_ATTEMPTS := preload("res://scripts/profile/DatingAttemptLedger.gd")
const SCENE_ASSIGNMENT := preload("res://scripts/domain/relationship/PairDeckDraw.gd")
const SCENE_CANONICAL := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SCENE_CAPABILITIES := preload("res://scripts/domain/minesweeper/MinesweeperCapabilityRules.gd")
const SCENE_INPUT_KEYS := ["lifecycle", "gameplay", "contacts", "desktop", "scene",
	"applied_effect_transaction_ids", "applied_variable_transaction_ids", "command_receipts"]
const SCENE_TOP_KEYS := ["active_app_id", "applied_effect_transaction_ids", "applied_variable_transaction_ids",
	"audio_context", "checkpoint_id", "checkpoint_sequence", "command_receipts", "contacts", "content_version",
	"desktop", "gameplay", "lifecycle", "narrative_checkpoint", "route_id", "run_id", "scene", "schema_version"]
const SCENE_LIFECYCLE_KEYS := ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance",
	"causal_day_instance_issuer_receipt", "restore_provenance", "state", "scene_assignment"]
const SCENE_GAMEPLAY_KEYS := ["affection", "coins", "friend_attitude", "friends", "inter_friend_affection", "inventory",
	"minesweeper_app_rounds_finished_today", "minesweeper_money_earned_today", "minesweeper_rng_seed",
	"minesweeper_round_floor", "minesweeper_rounds_left", "minesweeper_selected_difficulty", "minesweeper_task_rewards_claimed",
	"money", "narrative_variables", "penalty_points_today", "penalty_points_total", "route_context",
	"shop_purchase_counts", "stats", "story_flags"]
const SCENE_CHECKPOINT_KEYS := ["content_version", "entry_id", "frozen_context", "manifest_fingerprint", "stage",
	"transaction_id", "reading_session"]
static var _scene_issuer: Object
static var _scene_authority: Object
static var _scene_semantic_busy := false

static func configure_scene_validation(issuer: Object, authority: Object) -> Dictionary:
	if not is_instance_valid(issuer) or not issuer.has_method("verify_issued") \
			or not is_instance_valid(authority) or not authority.has_method("validate_scene_snapshot_semantics"):
		return _fail(&"scene_validation_unavailable", "real issuer and semantic owner are required")
	if _scene_issuer != null or _scene_authority != null:
		return {"ok": true} if _scene_issuer == issuer and _scene_authority == authority \
			else _fail(&"scene_validation_already_configured", "owner replacement refused")
	_scene_issuer = issuer
	_scene_authority = authority
	return {"ok": true}

static func build_scene(snapshot_input: Dictionary, dialogic_checkpoint: Dictionary, route_id: String,
		active_app_id: Variant, audio_context: Dictionary, content_version: int, checkpoint_sequence: int) -> Dictionary:
	if route_id != "scene" or not _scene_keys(snapshot_input, SCENE_INPUT_KEYS) \
			or not snapshot_input.lifecycle is Dictionary:
		return _fail(&"invalid_snapshot_input", "scene input requires its exact complete owner shape")
	var snapshot: Dictionary = snapshot_input.duplicate(true)
	snapshot.merge({"schema_version": SCENE_SCHEMA_VERSION, "content_version": content_version,
		"run_id": snapshot_input.lifecycle.get("run_id"), "checkpoint_sequence": checkpoint_sequence,
		"checkpoint_id": "%s:%d" % [str(snapshot_input.lifecycle.get("run_id", "")), checkpoint_sequence],
		"route_id": route_id, "active_app_id": active_app_id,
		"narrative_checkpoint": dialogic_checkpoint.duplicate(true), "audio_context": audio_context.duplicate(true)})
	var checked := validate(snapshot)
	if not checked.ok: return checked
	return {"ok": true, "code": &"ok", "value": {"snapshot": checked.value.candidate}}

static func validate_scene(snapshot: Dictionary, bundle: Dictionary) -> Dictionary:
	if not is_instance_valid(_scene_issuer) or not is_instance_valid(_scene_authority) or _scene_semantic_busy:
		return _fail(&"scene_validation_unavailable", "scene semantic owner unavailable or reentrant")
	var selected: Dictionary = SCENE_MANIFEST.scene_registration()
	if not selected.ok: return selected
	if not _scene_equal(selected.value, bundle):
		return _fail(&"scene_registration_mismatch", "saved data cannot select a registration")
	var candidate: Dictionary = _normalize_integral_floats(snapshot)
	var primitive := validate_primitive_tree(candidate)
	if not primitive.ok: return primitive
	if not _scene_keys(candidate, SCENE_TOP_KEYS) or typeof(candidate.schema_version) != TYPE_INT \
			or candidate.schema_version != SCENE_SCHEMA_VERSION or candidate.route_id != "scene" \
			or not _scene_id(candidate.run_id) or not _scene_int(candidate.content_version, 1) \
			or not _scene_int(candidate.checkpoint_sequence, 0) \
			or candidate.checkpoint_id != "%s:%d" % [candidate.run_id, candidate.checkpoint_sequence]:
		return _fail(&"invalid_snapshot_shape", "invalid Run9 header or member set")
	if not _scene_keys(candidate.lifecycle, SCENE_LIFECYCLE_KEYS) \
			or candidate.lifecycle.run_id != candidate.run_id or candidate.lifecycle.state != "PLAYING":
		return _fail(&"invalid_lifecycle", "scene lifecycle requires its exact eight members and PLAYING")
	var assignment: Dictionary = SCENE_ASSIGNMENT.validate_scene(candidate.lifecycle.scene_assignment)
	if not assignment.ok: return assignment
	var lifecycle: Dictionary = RUN_LIFECYCLE.validate_scene(candidate.lifecycle, _scene_issuer)
	if not lifecycle.ok: return lifecycle
	if candidate.active_app_id != null and (not candidate.active_app_id is String \
			or candidate.active_app_id == "logout" or not DESKTOP_APP_REGISTRY.new().has_app(StringName(candidate.active_app_id))):
		return _fail(&"invalid_snapshot_shape", "invalid active content app")
	if not candidate.audio_context is Dictionary or not candidate.contacts is Dictionary \
			or not candidate.command_receipts is Dictionary:
		return _fail(&"invalid_snapshot_shape", "scene owner sections must be objects")
	if not _scene_keys(candidate.scene, ["registration_sha256", "active_occurrence_id", "active_admission_receipt_id"]) \
			or candidate.scene.registration_sha256 != SCENE_MANIFEST.scene_registration_fingerprint() \
			or not _scene_id(candidate.scene.active_occurrence_id) or not _scene_id(candidate.scene.active_admission_receipt_id):
		return _fail(&"scene_registration_mismatch", "active scene reference must use installed registration")
	var gameplay_error := _validate_scene_gameplay(candidate.gameplay)
	if not gameplay_error.is_empty(): return _fail(&"invalid_gameplay", gameplay_error)
	var contacts: Dictionary = SCENE_CONTACTS.validate_scene_state(candidate.contacts, candidate.scene.registration_sha256, _scene_issuer)
	if not contacts.ok: return contacts
	for receipt: Dictionary in candidate.contacts.transaction_receipts.values():
		if receipt.context.identity.run_id != candidate.run_id:
			return _fail(&"scene_contact_run_changed", "Contacts receipt belongs to another run")
	if not _scene_keys(candidate.desktop, DESKTOP_KEYS) or not candidate.desktop.board is Dictionary \
			or not candidate.desktop.consequence is Dictionary:
		return _fail(&"invalid_desktop_aggregate", "desktop requires its exact owners")
	var board: Dictionary = DESKTOP_BOARD_STATE.new().prepare_restore_scene(candidate.desktop.board, _scene_issuer)
	if not board.ok: return board
	var consequence: Dictionary = DESKTOP_CONSEQUENCE_STATE.validate(candidate.desktop.consequence)
	if not consequence.ok: return consequence
	for member: String in ["applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		var ids_error := _validate_transaction_ids(candidate[member], member)
		if not ids_error.is_empty(): return _fail(&"invalid_transaction_ids", ids_error)
	var receipts_error := _validate_scene_receipt_shapes(candidate)
	if not receipts_error.is_empty(): return _fail(&"invalid_command_receipts", receipts_error)
	var scene_receipts: Dictionary = SCENE_EVENT_CONTRACT.validate_scene_receipts(candidate.command_receipts, bundle, _scene_issuer)
	if not scene_receipts.ok: return scene_receipts
	var reading := _validate_scene_reading(candidate)
	if not reading.ok: return reading
	# The real live owner authenticates historical/current admissions, issuer
	# chains, physical Profile references, assignment creation and Frozen frames.
	# It must not call Run.validate again. A Boolean supplied by saved data is
	# never substituted for this privately installed owner.
	var before := _scene_hash(candidate)
	var detached := candidate.duplicate(true)
	var detached_bundle := bundle.duplicate(true)
	var bundle_before := _scene_hash(detached_bundle)
	_scene_semantic_busy = true
	var semantic: Variant = _scene_authority.call("validate_scene_snapshot_semantics", detached, detached_bundle)
	_scene_semantic_busy = false
	if _scene_hash(detached) != before or _scene_hash(detached_bundle) != bundle_before:
		return _fail(&"scene_validation_mutated", "semantic owner mutated validation input")
	if not semantic is Dictionary or semantic.get("ok") != true:
		return semantic if semantic is Dictionary else _fail(&"scene_validation_invalid_result", "semantic owner must return a result")
	return {"ok": true, "code": &"ok", "value": {"candidate": candidate}}

static func _validate_scene_reading(candidate: Dictionary) -> Dictionary:
	var checkpoint: Variant = candidate.narrative_checkpoint
	if not _scene_keys(checkpoint, SCENE_CHECKPOINT_KEYS) or checkpoint.stage != "scene" \
			or not _scene_id(checkpoint.entry_id) or not _scene_id(checkpoint.transaction_id) \
			or checkpoint.content_version != candidate.content_version \
			or checkpoint.manifest_fingerprint != candidate.scene.registration_sha256 \
			or not checkpoint.reading_session is Dictionary or not checkpoint.frozen_context is Dictionary:
		return _fail(&"reading_checkpoint_invalid", "Run9 requires a complete scene checkpoint")
	var saved: Dictionary = checkpoint.reading_session
	if saved.get("schema_version") != 5 or saved.get("occurrence_id") != candidate.scene.active_occurrence_id \
			or saved.get("entry_id") != checkpoint.entry_id:
		return _fail(&"reading_context_invalid", "active occurrence and reading5 must agree")
	var session := SCENE_READING.new()
	var configured: Dictionary = session.configure_scene()
	if not configured.ok: return configured
	var restored: Dictionary = session.restore(saved, checkpoint.entry_id)
	if not restored.ok: return restored
	if not checkpoint.frozen_context.get("presentation") is Dictionary:
		return _fail(&"reading_context_invalid", "frozen presentation must be an object")
	var fields: Variant = checkpoint.frozen_context.presentation.get("fields")
	if not fields is Dictionary or fields.get("occurrence_id") != candidate.scene.active_occurrence_id \
			or fields.get("admission_receipt_id") != candidate.scene.active_admission_receipt_id \
			or fields.get("entry_id") != checkpoint.entry_id \
			or checkpoint.frozen_context.get("transaction_id") != checkpoint.transaction_id:
		return _fail(&"reading_context_invalid", "active admission and frozen wrapper must agree")
	return {"ok": true}

## For the actual GameState rollback/capture owner. This validates the complete
## captured input without inventing a narrative checkpoint. Full save admission
## still additionally requires validate_scene's reading and semantic checks.
static func validate_scene_input_fields(input: Dictionary, bundle: Dictionary) -> Dictionary:
	if not is_instance_valid(_scene_issuer): return _fail(&"scene_validation_unavailable", "issuer unavailable")
	if not _scene_keys(input, SCENE_INPUT_KEYS): return _fail(&"invalid_snapshot_input", "incomplete scene capture")
	var primitive := validate_primitive_tree(input)
	if not primitive.ok: return primitive
	var selected: Dictionary = SCENE_MANIFEST.scene_registration()
	if not selected.ok: return selected
	if not _scene_equal(selected.value, bundle): return _fail(&"scene_registration_mismatch", "unselected bundle")
	if not _scene_keys(input.lifecycle, SCENE_LIFECYCLE_KEYS): return _fail(&"invalid_lifecycle", "invalid scene lifecycle keys")
	var lifecycle: Dictionary = RUN_LIFECYCLE.validate_scene(input.lifecycle, _scene_issuer)
	if not lifecycle.ok: return lifecycle
	if not _scene_keys(input.scene, ["registration_sha256", "active_occurrence_id", "active_admission_receipt_id"]) \
			or input.scene.registration_sha256 != SCENE_MANIFEST.scene_registration_fingerprint() \
			or not _scene_id(input.scene.active_occurrence_id) or not _scene_id(input.scene.active_admission_receipt_id):
		return _fail(&"scene_registration_mismatch", "invalid active scene reference")
	var gameplay_error := _validate_scene_gameplay(input.gameplay)
	if not gameplay_error.is_empty(): return _fail(&"invalid_gameplay", gameplay_error)
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
	var consequence: Dictionary = DESKTOP_CONSEQUENCE_STATE.validate(input.desktop.consequence)
	if not consequence.ok: return consequence
	for member: String in ["applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		var ids_error := _validate_transaction_ids(input[member], member)
		if not ids_error.is_empty(): return _fail(&"invalid_transaction_ids", ids_error)
	var receipts_error := _validate_scene_receipt_shapes(input)
	if not receipts_error.is_empty(): return _fail(&"invalid_command_receipts", receipts_error)
	var scene_receipts: Dictionary = SCENE_EVENT_CONTRACT.validate_scene_receipts(input.command_receipts, bundle, _scene_issuer)
	if not scene_receipts.ok: return scene_receipts
	return {"ok": true}

static func _validate_scene_receipt_shapes(snapshot: Dictionary) -> String:
	for id: Variant in snapshot.command_receipts:
		var receipt: Variant = snapshot.command_receipts[id]
		if not _scene_id(id) or not receipt is Dictionary or receipt.get("transaction_id") != id \
				or not _scene_digest(receipt.get("request_fingerprint")) or not _scene_id(receipt.get("source_id")):
			return "invalid command receipt identity"
		if receipt.get("kind") == "scene_admission":
			if not _scene_keys(receipt, ["transaction_id", "request_fingerprint", "kind", "source_id", "scene_admission"]) \
					or not _scene_keys(receipt.scene_admission, ["schema_version", "registration_fingerprint", "source_identity", "issuer_receipt", "provenance", "result"]):
				return "invalid scene admission receipt members"
			var admission: Dictionary = receipt.scene_admission
			if typeof(admission.schema_version) != TYPE_INT or admission.schema_version != 2 \
					or admission.registration_fingerprint != snapshot.scene.registration_sha256 \
					or not admission.source_identity is Dictionary or not admission.issuer_receipt is Dictionary \
					or not admission.provenance is Dictionary or not admission.result is Dictionary:
				return "invalid scene admission receipt family/registration"
		elif receipt.get("kind") == "scene_event":
			if not _scene_keys(receipt, ["transaction_id", "request_fingerprint", "kind", "source_id", "scene_event"]) \
					or not _scene_keys(receipt.scene_event, ["schema_version", "semantic", "registration_fingerprint", "reading_anchor", "result"]):
				return "invalid scene command receipt members"
			var event: Dictionary = receipt.scene_event
			if typeof(event.schema_version) != TYPE_INT or event.schema_version != 2 \
					or event.registration_fingerprint != snapshot.scene.registration_sha256 \
					or not event.semantic is Dictionary or not event.result is Dictionary or not event.reading_anchor is Dictionary:
				return "invalid scene command receipt family/registration"
		else:
			if not _scene_keys(receipt, COMMAND_RECEIPT_KEYS) or receipt.get("kind") not in COMMAND_RECEIPT_KINDS:
				return "invalid effect/variable command receipt"
	if not snapshot.command_receipts.has(snapshot.scene.active_admission_receipt_id):
		return "active admission receipt is absent"
	return _validate_receipt_partition(snapshot.command_receipts,
		snapshot.applied_effect_transaction_ids, snapshot.applied_variable_transaction_ids)

static func _validate_scene_gameplay(gameplay: Variant) -> String:
	if not _scene_keys(gameplay, SCENE_GAMEPLAY_KEYS): return "unexpected scene gameplay members"
	for key: String in ["affection", "friend_attitude", "friends", "inter_friend_affection", "inventory",
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
	if not _scene_keys(gameplay.affection, SCENE_CONTACTS.FRIEND_IDS) \
			or not _scene_keys(gameplay.friend_attitude, SCENE_CONTACTS.FRIEND_IDS): return "invalid friend indexes"
	for friend: String in SCENE_CONTACTS.FRIEND_IDS:
		if not _scene_int(gameplay.affection[friend], -4, 10) or not gameplay.friend_attitude[friend] is String:
			return "invalid friend affection/attitude"
	for pair: Variant in gameplay.inter_friend_affection:
		if pair not in ["lavinia_priscilla", "lavinia_sylvia", "priscilla_sylvia"] \
				or typeof(gameplay.inter_friend_affection[pair]) != TYPE_INT: return "invalid inter-friend affection"
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
	return _validate_scene_route_context(gameplay.route_context)

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

static func _scene_equal(a: Variant, b: Variant) -> bool:
	var hash := _scene_hash(a)
	return not hash.is_empty() and hash == _scene_hash(b)

