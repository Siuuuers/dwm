extends "res://addons/gut/test.gd"

const MANAGER := preload("res://autoload/SaveManager.gd")
const PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const FIXTURE := "res://tests/fixtures/saves/v5_desktop_prepared.json"

# Only restore compatibility/execution is doubled. Journal, file revision, token
# custody, Quick policy and atomic writes remain the production SaveManager.
class RestoreFixture extends "res://autoload/SaveManager.gd":
	var fallback := false
	var restore_unavailable := false
	var final_record_fallback := false
	var restore_prepares := 0
	var restore_commits := 0
	func _prepare_restore_document(_locator: Dictionary, document: Dictionary, _migration: Dictionary) -> Dictionary:
		restore_prepares += 1
		if restore_unavailable:
			return {"ok": false, "code": &"fixture_restore_unavailable"}
		var bundle: Dictionary = document["current_snapshot"].duplicate(true)
		return {"ok": true, "value": {"prepared": {
			"bundle": bundle, "checkpoint_id": "fixture-earlier" if fallback else bundle["snapshot"]["checkpoint_id"]}}}
	func commit_prepared_restore(_prepared: Dictionary) -> Dictionary:
		restore_commits += 1
		return {"ok": true, "value": {"restored": true}}
	func prepare_backup_action(action: String, locator: String) -> Dictionary:
		var result := super.prepare_backup_action(action, locator)
		if final_record_fallback and result.get("ok", false):
			result["value"]["record"]["fallback"] = true
		return result

class Capture extends RefCounted:
	var result: Dictionary = {"ok": false, "code": &"fixture_capture_unavailable"}
	func capture() -> Dictionary:
		return result.duplicate(true)

class Admission extends RefCounted:
	var allowed := true
	func guard() -> Dictionary:
		return {"ok": allowed, "code": &"ok" if allowed else &"fixture_source_changed"}

var _manager: Node
var files: RefCounted
var storage: RefCounted
var gate: RefCounted
var port: RefCounted

func before_each() -> void:
	files = FILES.new()
	storage = STORAGE.new("memory/quick-actions", files)
	gate = GATE.new()
	_manager = RestoreFixture.new()
	assert_true(_manager.initialize(storage).get("ok", false))
	assert_true(_manager.configure_mutation_gate(gate).get("ok", false))
	_seed()
	port = PORT.new()
	assert_true(port.configure(_manager).get("ok", false))

func after_each() -> void:
	_manager.free()

func _seed() -> void:
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	snapshot["gameplay"]["money"] = 0
	_manager._journal.reset(snapshot["run_id"])
	var prepared: Dictionary = _manager._journal.prepare_record(snapshot, &"day_start")
	assert_true(prepared.get("ok", false))
	assert_true(_manager._journal.commit_prepared(prepared["value"]["candidate"]).get("ok", false))

func _save_quick() -> void:
	var prepared: Dictionary = port.prepare_quick_action("save")
	assert_true(prepared.get("ok", false))
	if prepared.get("ok", false):
		assert_true(port.commit_action(prepared["value"]["token"]).get("ok", false))

func _advance_source() -> void:
	var snapshot: Dictionary = _manager.get_latest_stable_checkpoint()["value"]["bundle"]["snapshot"].duplicate(true)
	snapshot["checkpoint_sequence"] += 1
	snapshot["checkpoint_id"] = str(snapshot["run_id"]) + ":" + str(snapshot["checkpoint_sequence"])
	var prepared: Dictionary = _manager._journal.prepare_record(snapshot, &"day_start")
	assert_true(prepared.get("ok", false))
	assert_true(_manager._journal.commit_prepared(prepared["value"]["candidate"]).get("ok", false))

func test_empty_quick_save_uses_single_use_token_and_real_atomic_write() -> void:
	var before: Dictionary = files.snapshot_persisted()
	var capability: Dictionary = port.get_quick_capability("save")
	assert_true(capability.value.enabled)
	assert_eq(capability.value.status_key, "")
	var prepared: Dictionary = port.prepare_quick_action("save")
	assert_true(prepared.get("ok", false))
	assert_false(prepared.value.confirmation_required)
	assert_eq(prepared.value.confirmation_kind, "none")
	assert_eq(files.snapshot_persisted(), before, "preparation cannot write")
	assert_true(port.commit_action(prepared.value.token).get("ok", false))
	assert_true(storage.exists("quicksave.json"))
	assert_false(port.commit_action(prepared.value.token).get("ok", false))
	assert_false(port.is_quick_condition_current(capability.value.condition), "durable target revision changed")
	assert_true(port.get_quick_capability("save").value.enabled, "proved normal Quick replacement stays direct")
	assert_false(_manager._pending_deferred_save)

func test_quick_does_not_cancel_preexisting_backup_consent() -> void:
	var pending: Dictionary = port.prepare_action("save", "slot:2")
	assert_true(pending.get("ok", false))
	var sequence: int = _manager._backup_action_sequence
	assert_false(port.get_quick_capability("save").value.enabled)
	assert_eq(port.prepare_quick_action("save").status_key, "unavailable")
	assert_eq(_manager._backup_action_sequence, sequence)
	assert_true(_manager._backup_actions.has(pending.value.token))
	assert_true(port.commit_action(pending.value.token).get("ok", false), "original consent remains usable")

func test_only_explicit_nonfatal_guard_facts_produce_please_wait_without_future_save() -> void:
	var before: Dictionary = files.snapshot_persisted()
	assert_true(_manager.acquire_save_lock(&"scene_transition").get("ok", false))
	var waiting: Dictionary = port.prepare_quick_action("save")
	assert_eq(waiting.status_key, "unavailable", "F5 never presents a temporary wait promise")
	assert_eq(port.prepare_quick_action("load").status_key, "please_wait")
	assert_false(_manager._pending_deferred_save)
	assert_true(_manager.release_save_lock(&"scene_transition").get("ok", false))
	assert_eq(files.snapshot_persisted(), before, "release never flushes a Quick request")
	assert_false(port.is_quick_condition_current(waiting.condition))
	var lease: Dictionary = gate.acquire(&"causal_transaction")
	assert_eq(port.prepare_quick_action("save").status_key, "unavailable", "F5 remains unavailable under an active gate")
	assert_eq(port.prepare_quick_action("load").status_key, "please_wait")
	assert_true(gate.release(&"causal_transaction", lease.value.token).get("ok", false))
	assert_eq(port.prepare_quick_action("load").status_key, "unavailable", "empty is not temporary")
	assert_true(gate.latch_fatal({"source": "fixture", "phase": "test", "code": "fixture_fatal", "details": {}}).get("ok", false))
	assert_eq(port.prepare_quick_action("save").status_key, "unavailable")
	assert_eq(files.snapshot_persisted(), before)

func test_fallback_and_unavailable_quick_never_silently_overwrite() -> void:
	_save_quick()
	var before: Dictionary = files.snapshot_persisted()
	_manager.fallback = true
	assert_false(port.get_quick_capability("save").value.enabled)
	assert_eq(port.prepare_quick_action("save").status_key, "unavailable")
	_manager.fallback = false
	_manager.restore_unavailable = true
	assert_eq(port.prepare_quick_action("save").status_key, "unavailable")
	assert_eq(port.prepare_quick_action("load").status_key, "unavailable", "generic restore refusal is not guessed temporary")
	assert_eq(files.snapshot_persisted(), before)
	assert_true(_manager._backup_actions.is_empty())

func test_authoritative_preparation_fallback_cancels_only_its_new_token() -> void:
	_manager.final_record_fallback = true
	var before: Dictionary = files.snapshot_persisted()
	assert_eq(port.prepare_quick_action("save").status_key, "unavailable")
	assert_eq(_manager._backup_action_sequence, 1, "race reached actual _manager preparation")
	assert_true(_manager._backup_actions.is_empty(), "new token retired")
	assert_eq(files.snapshot_persisted(), before)

func test_load_always_requires_consent_for_normal_and_fallback() -> void:
	_save_quick()
	for fallback: bool in [false, true]:
		_manager.fallback = fallback
		var prepared: Dictionary = port.prepare_quick_action("load")
		assert_true(prepared.get("ok", false))
		assert_true(prepared.value.confirmation_required)
		assert_eq(prepared.value.confirmation_kind, "replace_progress_fallback" if fallback else "replace_progress")
		assert_eq(_manager.restore_commits, 0, "preparation never restores")
		port.cancel_action(prepared.value.token)
		assert_false(port.commit_action(prepared.value.token).get("ok", false))
	var accepted: Dictionary = port.prepare_quick_action("load")
	assert_true(port.commit_action(accepted.value.token).get("ok", false))
	assert_eq(_manager.restore_commits, 1)

func test_load_source_binding_is_owner_enforced_and_condition_checks_do_not_prepare_restore() -> void:
	_save_quick()
	var prepared: Dictionary = _manager.prepare_quick_backup_action("load")
	assert_true(prepared.get("ok", false))
	var count: int = _manager.restore_prepares
	for index: int in range(4):
		assert_true(_manager.is_quick_condition_current(prepared.value.condition))
	assert_eq(_manager.restore_prepares, count, "cheap revalidation never prepares restore participants")
	assert_eq(prepared.value.condition.keys().size(), 2)
	assert_false(JSON.stringify(prepared.value.condition).contains("fixture-run"), "no raw source identity or snapshot escapes")
	var detached: Dictionary = prepared.value.condition.duplicate(true)
	detached["signature"] = "tampered"
	assert_false(_manager.is_quick_condition_current(detached))
	_advance_source()
	assert_false(_manager.is_quick_condition_current(prepared.value.condition))
	assert_eq(_manager.commit_backup_action(prepared.value.token).get("code"), &"stale_backup_source")
	assert_eq(_manager.restore_commits, 0)

func test_load_does_not_require_available_capture_but_available_capture_drift_invalidates() -> void:
	_save_quick()
	var capture := Capture.new()
	assert_true(_manager.configure_backup_capture_provider(Callable(capture, "capture")).get("ok", false))
	assert_false(port.get_quick_capability("save").value.enabled)
	var load_action: Dictionary = port.prepare_quick_action("load")
	assert_true(load_action.get("ok", false), "stable source is enough for Load")
	port.cancel_action(load_action.value.token)
	capture.result = {"ok": true, "value": {"snapshot_input": {"lifecycle": {"state": "PLAYING"}},
		"route_id": "main", "active_app_id": "backup", "dialogic_checkpoint": {}, "audio_context": {}, "content_version": 1}}
	load_action = port.prepare_quick_action("load")
	assert_true(load_action.get("ok", false))
	capture.result["value"]["audio_context"] = {"fixture_changed": true}
	assert_false(port.is_quick_condition_current(load_action.value.condition))
	assert_eq(port.commit_action(load_action.value.token).status_key, "unavailable")
	assert_eq(_manager.restore_commits, 0)

func test_title_and_refused_source_cannot_prepare_or_commit_quick() -> void:
	var title := PORT.new()
	assert_true(title.configure(_manager, "title").get("ok", false))
	for action: String in ["save", "load", "delete"]:
		assert_false(title.get_quick_capability(action).value.enabled)
		assert_eq(title.prepare_quick_action(action).status_key, "unavailable")
	var admission := Admission.new()
	var guarded := PORT.new()
	assert_true(guarded.configure(_manager, "in_run", Callable(admission, "guard")).get("ok", false))
	var prepared: Dictionary = guarded.prepare_quick_action("save")
	assert_true(prepared.get("ok", false))
	admission.allowed = false
	assert_false(guarded.is_quick_condition_current(prepared.value.condition))
	assert_eq(guarded.commit_action(prepared.value.token).status_key, "unavailable")
	assert_true(_manager._backup_actions.is_empty())
	assert_false(storage.exists("quicksave.json"))
