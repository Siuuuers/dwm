extends "res://addons/gut/test.gd"
# SaveManager + real checkpoint-port journal integration
# (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 6).

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const TEMP_PATH := "res://tests/support/TemporaryStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const CHECKPOINT_PORT_PATH := "res://scripts/application/run/SaveManagerCheckpointPort.gd"
const VALID_FIXTURE := "res://tests/fixtures/snapshots/valid_day3.json"

var _suite_counter := 0

func _artifacts_exist() -> bool:
	for path: String in [SAVE_MANAGER_PATH, STORAGE_PATH, TEMP_PATH, GATE_PATH, CHECKPOINT_PORT_PATH]:
		if not ResourceLoader.exists(path, "Script"):
			return false
	return true

func _isolated_manager(suite_id: String) -> Node:
	_suite_counter += 1
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("save_manager_journal") \
		.path_join("%s_%d" % [suite_id, _suite_counter]).path_join("saves")
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	var storage: RefCounted = load(STORAGE_PATH).new(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	assert_true(manager.initialize(storage)["ok"])
	return manager

func _checkpoint_inputs(run_id: String) -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VALID_FIXTURE))
	var lifecycle: Dictionary = fixture["lifecycle"]
	lifecycle["run_id"] = run_id
	return {
		"snapshot_input": {
			"lifecycle": lifecycle,
			"gameplay": fixture["gameplay"],
			"contacts": fixture["contacts"],
			"committed_schedule": {
				"schema_version": 1, "day": int(lifecycle["day"]),
				"registry_fingerprint": null, "entries": [], "commit_receipt": null,
			},
			"dating": fixture["dating"],
			"applied_effect_transaction_ids": [],
			"applied_variable_transaction_ids": [],
		},
		"dialogic_checkpoint": {},
		"route_id": "main",
		"active_app_id": null,
		"audio_context": {},
		"content_version": 1,
	}

func test_record_checkpoint_advances_journal_and_persists_disk() -> void:
	assert_true(_artifacts_exist(), "artifacts must exist")
	if not _artifacts_exist():
		return
	var manager := _isolated_manager("journal_record")
	assert_true(manager._journal.reset("run-j")["ok"])
	var first: Dictionary = manager.record_stable_checkpoint(_checkpoint_inputs("run-j"), &"day_start")
	assert_true(first.get("ok", false), JSON.stringify(first))
	assert_eq(str(first["value"]["checkpoint_id"]), "run-j:1")
	var second: Dictionary = manager.record_stable_checkpoint(_checkpoint_inputs("run-j"), &"line")
	assert_true(second.get("ok", false))
	assert_eq(str(second["value"]["checkpoint_id"]), "run-j:2")
	var latest: Dictionary = manager.get_latest_stable_checkpoint()
	assert_true(latest["ok"])
	assert_eq(int(latest["value"]["bundle"]["snapshot"]["checkpoint_sequence"]), 2)
	var autosaved: Dictionary = manager.autosave_latest()
	assert_true(autosaved.get("ok", false), "the latest checkpoint persists to disk: " + JSON.stringify(autosaved))
	assert_true(manager.save_exists(&"autosave", -1))

func test_real_port_preview_is_pure_and_matches_prepare() -> void:
	assert_true(_artifacts_exist(), "artifacts must exist")
	if not _artifacts_exist():
		return
	var manager := _isolated_manager("port_preview")
	assert_true(manager._journal.reset("run-1")["ok"])
	assert_true(manager.record_stable_checkpoint(_checkpoint_inputs("run-1"), &"day_start")["ok"])
	var gate: RefCounted = load(GATE_PATH).new()
	var port: RefCounted = load(CHECKPOINT_PORT_PATH).new(manager)
	assert_true(port.configure_fatal_latch(gate)["ok"])
	var journal_before: Dictionary = manager._journal.capture_state()["value"]["backup"]
	var preview: Dictionary = port.preview_checkpoint_id("run-1")
	assert_true(preview.get("ok", false), JSON.stringify(preview))
	assert_eq(str(preview["value"]["checkpoint_id"]), "run-1:2", "next sequence after the seeded day_start")
	assert_eq(manager._journal.capture_state()["value"]["backup"], journal_before,
		"preview mutates no journal state")
	var prepared: Dictionary = port.prepare(_checkpoint_inputs("run-1"), &"day_resolution_stage",
		{"kind": &"none", "reason": &"stage"})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_eq(str(prepared["value"]["checkpoint_id"]), str(preview["value"]["checkpoint_id"]),
		"the immediately following prepare returns the previewed id")
	assert_false(port.preview_checkpoint_id("").get("ok", true), "empty run id rejects")
	assert_false(port.preview_checkpoint_id("run-z").get("ok", true), "mismatched run id rejects")

func test_real_port_commit_and_autosave_round_trip() -> void:
	assert_true(_artifacts_exist(), "artifacts must exist")
	if not _artifacts_exist():
		return
	var manager := _isolated_manager("port_commit")
	assert_true(manager._journal.reset("run-1")["ok"])
	var gate: RefCounted = load(GATE_PATH).new()
	var port: RefCounted = load(CHECKPOINT_PORT_PATH).new(manager)
	assert_true(port.configure_fatal_latch(gate)["ok"])
	var prepared: Dictionary = port.prepare(_checkpoint_inputs("run-1"), &"day_start",
		{"kind": &"autosave", "reason": &"day_start"})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var committed: Dictionary = port.commit(prepared["value"]["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_eq(str(committed["value"]["checkpoint_id"]), "run-1:1")
	assert_true(manager.save_exists(&"autosave", -1), "an autosave checkpoint wrote the disk document")
	assert_eq(int(manager._journal.peek_next_sequence("run-1")["value"]["checkpoint_sequence"]), 2,
		"the journal advanced exactly once")

func test_real_port_rollback_failure_latches_shared_gate() -> void:
	assert_true(_artifacts_exist(), "artifacts must exist")
	if not _artifacts_exist():
		return
	var manager := _isolated_manager("port_rollback")
	assert_true(manager._journal.reset("run-1")["ok"])
	var gate: RefCounted = load(GATE_PATH).new()
	var port: RefCounted = load(CHECKPOINT_PORT_PATH).new(manager)
	assert_true(port.configure_fatal_latch(gate)["ok"])
	# A backup carrying an invalid journal snapshot forces restore_state to fail.
	var poisoned := {"journal_backup": {"run_id": "run-1", "next_sequence": 1,
		"current": {}, "earlier": "not-an-array"}, "storage_backup": null}
	var result: Dictionary = port.rollback(poisoned)
	assert_false(result.get("ok", true))
	assert_eq(result["code"], &"APPLICATION_FATAL", JSON.stringify(result))
	assert_true(gate.is_fatal_latched(), "the shared gate latched once")
	var failure: Dictionary = result["details"]["failure"]
	assert_eq(failure["source"], "save_checkpoint")
	assert_eq(failure["code"], "fatal_rollback_failed")
	assert_true(failure["details"]["context"].has("run_id"))
	# Post-latch, the port routes every operation through the retained fatal guard.
	assert_eq(port.preview_checkpoint_id("run-1").get("code"), &"APPLICATION_FATAL")

func test_configure_fatal_latch_matrix() -> void:
	assert_true(_artifacts_exist(), "artifacts must exist")
	if not _artifacts_exist():
		return
	var manager := _isolated_manager("port_latch_matrix")
	var port: RefCounted = load(CHECKPOINT_PORT_PATH).new(manager)
	assert_eq(port.preview_checkpoint_id("run-1").get("code"), &"fatal_latch_not_configured",
		"operations fail until the fatal latch is configured")
	assert_eq(port.configure_fatal_latch(null).get("code"), &"invalid_mutation_gate")
	var gate: RefCounted = load(GATE_PATH).new()
	var configured: Dictionary = port.configure_fatal_latch(gate)
	assert_true(configured["ok"])
	assert_eq(configured["value"]["gate_instance_id"], gate.get_instance_id())
	assert_true(port.configure_fatal_latch(gate)["value"]["already_configured"])
	assert_eq(port.configure_fatal_latch(load(GATE_PATH).new()).get("code"),
		&"mutation_gate_already_configured")

func test_no_local_gate_or_projector_in_save_layer() -> void:
	assert_true(_artifacts_exist(), "artifacts must exist")
	if not _artifacts_exist():
		return
	for path: String in [SAVE_MANAGER_PATH, CHECKPOINT_PORT_PATH]:
		var source := FileAccess.get_file_as_string(path)
		assert_false(source.contains("ApplicationMutationGate.new("),
			path + " must not construct a gate")
		assert_false(source.contains("class_name FatalDiagnosticProjector"),
			path + " must not declare another projector")
