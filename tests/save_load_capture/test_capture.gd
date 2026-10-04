extends SceneTree

const MANAGER := preload("res://autoload/SaveManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const FIXTURE := "res://tests/fixtures/saves/v7_desktop_prepared.json"

class CaptureSource extends Node:
	var inputs: Dictionary = {}
	func capture() -> Dictionary:
		return {"ok": true, "value": inputs.duplicate(true)}

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var files := FILES.new()
	var storage := STORAGE.new("memory/capture", files)
	var manager: Node = MANAGER.new()
	_check(manager.initialize(storage).get("ok", false), "initialize")
	_check(manager.configure_mutation_gate(GATE.new()).get("ok", false), "gate")
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	snapshot["route_id"] = "main"
	snapshot["gameplay"]["money"] = 100
	manager._journal.reset(snapshot["run_id"])
	var seeded: Dictionary = manager._journal.prepare_record(snapshot, &"day_start")
	_check(seeded.get("ok", false), "initial main snapshot accepted")
	if not seeded.get("ok", false):
		manager.free()
		quit(1)
		return
	manager._journal.commit_prepared(seeded["value"]["candidate"])
	var source := CaptureSource.new()
	var raw_input := {}
	for key: String in ["lifecycle", "gameplay", "contacts", "committed_schedule", "desktop", "schedule_view", "dating", "applied_effect_transaction_ids", "applied_variable_transaction_ids", "command_receipts"]:
		raw_input[key] = snapshot[key].duplicate(true) if snapshot[key] is Dictionary or snapshot[key] is Array else snapshot[key]
	raw_input["gameplay"]["money"] = 200
	source.inputs = {"snapshot_input": raw_input, "route_id": "main", "active_app_id": &"backup", "dialogic_checkpoint": {}, "audio_context": {}, "content_version": 1}
	_check(manager.configure_backup_capture_provider(source.capture).get("ok", false), "configure capture")
	_check(manager.configure_backup_capture_provider(source.capture).get("ok", false), "idempotent capture binding")
	var other := CaptureSource.new()
	_check(not manager.configure_backup_capture_provider(other.capture).get("ok", false), "replacement rejected")
	other.free()
	var before: Dictionary = manager._journal.capture_state()
	var disk_before := files.snapshot_persisted()
	_check(manager.get_backup_save_capability()["enabled"], "current live source enabled")
	var prepared: Dictionary = manager.prepare_backup_action("save", "slot:1")
	_check(prepared.get("ok", false), "fresh capture prepares")
	if not prepared.get("ok", false):
		print(prepared)
		source.free()
		manager.free()
		quit(1)
		return
	_check(manager._journal.capture_state() == before and files.snapshot_persisted() == disk_before, "inspection and preparation are pure")
	manager.cancel_backup_action(prepared["value"]["token"])
	_check(not manager.commit_backup_action(prepared["value"]["token"]).get("ok", false), "cancel consumes candidate")
	_check(manager._journal.capture_state() == before and files.snapshot_persisted() == disk_before, "cancel preserves disk and journal")
	for field: String in ["gameplay", "route", "app", "audio", "narrative", "content", "journal"]:
		var original := source.inputs.duplicate(true)
		prepared = manager.prepare_backup_action("save", "slot:1")
		_check(prepared.get("ok", false), "prepare drift " + field)
		match field:
			"gameplay": source.inputs["snapshot_input"]["gameplay"]["money"] = 100
			"route": source.inputs["route_id"] = "hospital"
			"app": source.inputs["active_app_id"] = "contacts"
			"audio": source.inputs["audio_context"] = {"changed": true}
			"narrative": source.inputs["dialogic_checkpoint"] = {"changed": true}
			"content": source.inputs["content_version"] = 2
			"journal":
				var next := snapshot.duplicate(true)
				next["checkpoint_sequence"] = 2
				next["checkpoint_id"] = str(next["run_id"]) + ":2"
				var candidate: Dictionary = manager._journal.prepare_record(next, &"day_start")
				manager._journal.commit_prepared(candidate["value"]["candidate"])
		var at_commit: Dictionary = manager._journal.capture_state()
		_check(not manager.commit_backup_action(prepared["value"]["token"]).get("ok", false), "drift refuses " + field)
		_check(manager._journal.capture_state() == at_commit and files.snapshot_persisted() == disk_before, "drift preserves state " + field)
		source.inputs = original
	before = manager._journal.capture_state()
	prepared = manager.prepare_backup_action("save", "slot:1")
	files.fail_after(files.operation_count() + 1)
	_check(not manager.commit_backup_action(prepared["value"]["token"]).get("ok", false), "injected write failure refuses success")
	_check(manager._journal.capture_state() == before, "failed write preserves journal")
	files.fail_after(-1)
	prepared = manager.prepare_backup_action("save", "slot:1")
	_check(manager.commit_backup_action(prepared["value"]["token"]).get("ok", false), "fresh durable save succeeds")
	var document: Dictionary = JSON.parse_string(storage.read_text("slot_1.json")["value"])
	var validated: Dictionary = SCHEMA.validate(document)
	_check(validated.get("ok", false), "actual save document validates")
	document = validated["value"]["candidate"]
	var current: Dictionary = document["current_snapshot"]
	_check(current["checkpoint_kind"] == "manual_save", "honest manual save kind")
	_check(current["snapshot"]["route_id"] == "main" and current["snapshot"]["active_app_id"] == "backup" and current["snapshot"]["gameplay"]["money"] == 200, "save captures current main route and gameplay and foreground app")
	_check(manager._canonical_sha256(manager.get_latest_stable_checkpoint()["value"]["bundle"]) == manager._canonical_sha256(current), "journal publishes exact durable current bundle")
	prepared = manager.prepare_backup_action("save", "slot:1")
	before = manager._journal.capture_state()
	_check(storage.remove("slot_1.json").get("ok", false), "external target removal fixture")
	_check(manager.commit_backup_action(prepared["value"]["token"]).get("code") == &"stale_backup_target", "target drift refused")
	_check(manager._journal.capture_state() == before, "target drift preserves journal")
	for index in range(2):
		prepared = manager.prepare_backup_action("save", "quick")
		_check(prepared.get("ok", false), "repeated prepare " + str(index))
		_check(manager.commit_backup_action(prepared["value"]["token"]).get("ok", false), "repeated durable save " + str(index))
	# Exercise retention through real detached capture candidates without repeating
	# expensive disk fault protocol coverage already owned by backup_storage.
	for index in range(40):
		var capture: Dictionary = manager._prepare_backup_capture()
		_check(capture.get("ok", false), "retention candidate " + str(index))
		_check(manager._journal.commit_prepared(capture["value"]["journal_candidate"]).get("ok", false), "retention publish " + str(index))
	var earlier: Array = manager._journal.get_bundles_for_disk()
	var manual_count := 0
	var anchors := 0
	for bundle: Dictionary in earlier:
		if bundle["checkpoint_kind"] == "manual_save": manual_count += 1
		if bundle["checkpoint_kind"] == "day_start": anchors += 1
	_check(manual_count == 32 and anchors == 2, "manual tail bounded while existing semantic anchors retained")
	var original := source.inputs.duplicate(true)
	for bad: Variant in [null, 4, [], "invalid"]:
		source.inputs["dialogic_checkpoint"] = bad
		_check(not manager.prepare_backup_action("save", "slot:2").get("ok", false), "malformed context refused without throw")
	source.inputs = original.duplicate(true)
	source.inputs["snapshot_input"]["lifecycle"] = null
	_check(not manager.prepare_backup_action("save", "slot:2").get("ok", false), "malformed lifecycle refused")
	source.inputs = original.duplicate(true)
	source.inputs["snapshot_input"]["lifecycle"]["state"] = "ENDED"
	_check(not manager.get_backup_save_capability()["enabled"], "terminal lifecycle unavailable")
	source.inputs = original
	manager.acquire_save_lock(&"scene_transition")
	_check(not manager.prepare_backup_action("save", "slot:2").get("ok", false), "capture does not bypass owner save lock")
	manager.release_save_lock(&"scene_transition")
	source.free()
	_check(not manager.get_backup_save_capability()["enabled"], "freed configured provider never falls back")
	_check(not manager.prepare_backup_action("save", "slot:2").get("ok", false), "freed configured provider refuses save")
	manager.free()
	print("SAVE_LOAD_CAPTURE_PASS " if failures == 0 else "SAVE_LOAD_CAPTURE_FAIL ", checks, " checks; failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
