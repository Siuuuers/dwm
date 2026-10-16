extends "res://addons/gut/test.gd"

const ENDING := preload("res://scripts/narrative/EndingFrozenContext.gd")
const CONTEXT := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const RUN := preload("res://scripts/narrative/FrozenRunContext.gd")

func _plan() -> Dictionary:
	# Projection fixtures intentionally carry no issuer authority. Only the
	# saved-Run validator may authenticate an admission, never this builder.
	return {"source_kind": "scene", "schema_version": 1,
		"admission": {"target": {"kind": "ending", "entry_id": "ending.alone.normal"}},
		"steps": [{"ending_id": "ending.alone", "role": "core"}]}

func test_scene_terminal_uses_registered_neutral_signature_without_legacy_eligibility() -> void:
	var built := ENDING.build_scene(_plan(), "run:ending:0")
	assert_true(built.ok, str(built))
	if not built.ok: return
	assert_eq(built.value.signature, {"entry_id": "ending.alone.normal", "schema_version": 1,
		"fields": {"ending_role": "core", "ending_form": "alone_normal"}})
	var fields: Dictionary = built.value.presentation.fields
	assert_eq(fields.alone_cause, "scene_terminal")
	assert_eq(fields.step_token, "run:ending:0")
	assert_eq(fields.prerequisite_receipt_ids, [])
	assert_true(CONTEXT.validate("ending.alone.normal", built.value.presentation).ok)
	var changed: Dictionary = built.value.presentation.duplicate(true)
	changed.fields.ending_role = "primary"
	assert_false(CONTEXT.validate("ending.alone.normal", changed).ok)

func test_scene_terminal_rejects_different_target_role_or_extra_steps() -> void:
	var plan := _plan()
	plan.admission.target.entry_id = "ending.alone.dark_mode"
	assert_false(ENDING.build_scene(plan, "run:ending:0").ok)
	plan = _plan()
	plan.steps[0].role = "primary"
	assert_false(ENDING.build_scene(plan, "run:ending:0").ok)
	plan = _plan()
	plan.steps.append({"ending_id": "ending.sylvia.dark", "role": "core"})
	assert_false(ENDING.build_scene(plan, "run:ending:0").ok)
	assert_false(ENDING.build_scene(_plan(), "").ok)

func test_scene_presentation_is_detached_and_transport_token_does_not_change_signature() -> void:
	var plan := _plan()
	var first := ENDING.build_scene(plan, "run:ending:0")
	var second := ENDING.build_scene(plan, "loaded-run:ending:0")
	assert_true(first.ok and second.ok)
	if not first.ok or not second.ok: return
	assert_eq(first.value.signature, second.value.signature)
	assert_ne(first.value.presentation.fields.step_token, second.value.presentation.fields.step_token)
	plan.admission.target.entry_id = "changed"
	assert_eq(first.value.presentation.fields.entry_id, "ending.alone.normal")

func test_scene_projection_alone_cannot_authorize_saved_ending() -> void:
	var snapshot := {"schema_version": 9, "route_id": "ending", "command_receipts": {},
		"scene": {}, "contacts": {}, "narrative_checkpoint": {},
		"lifecycle": {"state": "ENDING", "ending_plan": _plan()}}
	assert_false(RUN.validate(snapshot, true).ok,
		"A projection is not an authenticated terminal admission or retained source checkpoint")

class NativeOccupancyProbe extends RefCounted:
	var occupied := false
	func has_active_playback() -> bool: return occupied

func test_restore_reservation_blocks_ordinary_start_without_claiming_native_playback() -> void:
	var bridge := preload("res://autoload/DialogicBridge.gd").new()
	var native := NativeOccupancyProbe.new()
	bridge._runtime_adapter = native
	bridge._scene_restore = {"operation_id": "restore:owned", "confirmed": false}
	assert_true(bridge.has_active_playback(), "restore custody blocks ordinary callers")
	assert_false(bridge._has_physical_playback(), "reservation is not native playback")
	assert_eq(bridge._begin_entry_playback("ending.alone.normal", {}, &"canonical", "resume", 1).code,
		&"entry_already_active")
	assert_eq(bridge._begin_entry_playback("ending.alone.normal", {}, &"canonical", "resume", 1, "restore:foreign").code,
		&"scene_activation_operation_invalid", "foreign operation cannot bypass custody")
	assert_eq(bridge._begin_entry_playback("ending.alone.normal", {}, &"canonical", "resume", 1, "restore:owned").code,
		&"scene_activation_operation_invalid", "operation id alone cannot authorize activation")
	native.occupied = true
	assert_true(bridge._has_physical_playback(), "actual adapter occupancy remains visible")
	bridge._scene_restore.clear()
	assert_true(bridge.has_active_playback(), "native playback remains occupied without reservation")
	assert_eq(bridge._begin_entry_playback("ending.alone.normal", {}, &"canonical", "resume", 1).code,
		&"entry_already_active")
	native.occupied = false
	assert_false(bridge.has_active_playback())
	bridge.free()
