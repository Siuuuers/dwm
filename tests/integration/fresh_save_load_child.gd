extends "res://tests/integration/authored_week_child.gd"
## Load the actual current-build slot written by the preceding native process.
## Setup and verification clocks are separate from the owner Ready signal.
const TIMING := preload("res://scripts/narrative/SceneValidationTiming.gd")
const REPORT := "res://.godot/ci/fresh-save-load/fresh-load.json"
var _fresh_result := {"complete": false, "phases": [], "pending_phase": ""}
var _load_pressed_us := 0

func _begin_fresh(label: String) -> int:
	_fresh_result.pending_phase = label
	_write_json(REPORT, _fresh_result)
	assert_true(TIMING.begin_scope("fresh_save_" + label, "ENDING", "PRIMARY_PENDING", 0))
	return Time.get_ticks_usec()

func _end_fresh(label: String, started: int, succeeded: bool) -> void:
	TIMING.end_scope(succeeded)
	_fresh_result.phases.append({"phase": label, "elapsed_us": Time.get_ticks_usec() - started, "ok": succeeded})
	_fresh_result.pending_phase = ""
	_write_json(REPORT, _fresh_result)

func _observe_fresh_ready() -> void:
	if _load_pressed_us != 0:
		_fresh_result.load_action_to_ready_us = Time.get_ticks_usec() - _load_pressed_us
		_load_pressed_us = 0

func _press_authored(control: Control) -> bool:
	var scene: Node = get_tree().current_scene
	if scene is MenuScene:
		var app: Control = scene._backup_app_instance
		if is_instance_valid(app) and control == app.action_buttons.get("load"):
			_load_pressed_us = Time.get_ticks_usec()
	return await super._press_authored(control)

func test_fresh_current_save_load() -> void:
	_phase = "fresh-save-load"
	_fresh_result.process_id = OS.get_process_id()
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://authored-week-terminal-pair.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	_fresh_result.creator_process_id = proof.process_id
	assert_ne(OS.get_process_id(), proof.process_id)
	var slot: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_3.json"))
	if not _ok(slot): return
	assert_eq(int(slot.value.schema_version), 9)
	assert_eq(slot.value.recovery_journal, [], "new Save has no obsolete fallback snapshots")
	assert_eq(slot.value.current_snapshot.snapshot, proof.snapshot)
	assert_eq(FileAccess.get_sha256("user://saves/slot_3.json"), proof.slot_sha256)
	assert_eq(FileAccess.get_sha256("user://profile.json"), proof.profile_sha256)
	assert_eq(FileAccess.get_sha256("user://saves/autosave.json"), proof.autosave_sha256)
	_fresh_result.source_slot_sha256 = proof.slot_sha256
	_fresh_result.source_slot_bytes = FileAccess.get_file_as_bytes("user://saves/slot_3.json").size()
	_fresh_result.recovery_journal_count = slot.value.recovery_journal.size()
	var retained_slot := "res://.godot/ci/fresh-save-load/slot_3.json"
	var copied := DirAccess.copy_absolute(ProjectSettings.globalize_path("user://saves/slot_3.json"),
		ProjectSettings.globalize_path(retained_slot))
	assert_eq(copied, OK, "retain the actual newly written Save before isolated-root cleanup")
	if copied != OK: return
	assert_eq(FileAccess.get_sha256(retained_slot), proof.slot_sha256)
	var started := _begin_fresh("boot")
	var succeeded := _setup_authored()
	_end_fresh("boot", started, succeeded)
	if not succeeded: return
	assert_eq(profile.get_profile_snapshot(), proof.profile)
	saves.live_session_ready.connect(_observe_fresh_ready)
	started = _begin_fresh("load")
	succeeded = await _load_authored(3, proof)
	_end_fresh("load", started, succeeded)
	if not succeeded: return
	assert_gt(int(_fresh_result.get("load_action_to_ready_us", 0)), 0)
	assert_eq(FileAccess.get_sha256("user://profile.json"), proof.profile_sha256)
	assert_eq(FileAccess.get_sha256("user://saves/autosave.json"), proof.autosave_sha256)
	_fresh_result.profile_sha256 = FileAccess.get_sha256("user://profile.json")
	_fresh_result.autosave_sha256 = FileAccess.get_sha256("user://saves/autosave.json")
	_fresh_result.registration_sha256 = AUTHORED_MANIFEST.scene_registration_fingerprint()
	_fresh_result.ready_native = _ready_observation
	_fresh_result.observed_lines = observed_lines
	_fresh_result.complete = true
	_write_json(REPORT, _fresh_result)
