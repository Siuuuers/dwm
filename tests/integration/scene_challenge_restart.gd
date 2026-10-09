extends SceneTree
## Two separate Actions processes exercise actual ProfileManager/JsonFileStorage
## durability. Admission, source Run checkpoint and closure are labelled injected
## seams: Save8 remains unintegrated and this is not a real two-store Save/Load test.
const FIXTURE := preload("res://tests/support/SceneChallengeFixture.gd")
const CANONICAL := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var phase := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("scene-challenge-restart")
	if phase not in ["write", "read"] or OS.get_environment("DWM_TEST_ROOT").is_empty():
		push_error("scene restart requires DWM_TEST_ROOT and --phase=write|read")
		quit(1); return
	var original_profile_sha := FileAccess.get_sha256(root.path_join("profile.json")) if phase == "read" else ""
	var f := FIXTURE.new()
	var setup: Dictionary = f.setup(root, true)
	if not setup.ok:
		_fail(f, "profile initialize", setup); return
	if phase == "write":
		f.state.inventory = {"debug_key": 1}
		if not f.begin().ok:
			_fail(f, "admit", {}); return
		f.authority.reject_checkpoint = true
		var started: Dictionary = f.action("start")
		var retained: Dictionary = f.attempt()
		if started.ok or not retained.ok or retained.value.get("record", {}).get("phase") != "preparing":
			_fail(f, "Profile preparing must precede failed injected Run", {"start": started, "retained": retained}); return
		var evidence := {"record": retained.value.record, "revision": retained.value.revision,
			"process_id": OS.get_process_id(), "profile_sha256": FileAccess.get_sha256(root.path_join("profile.json")),
			"record_sha256": CANONICAL.canonical_sha256(retained.value.record).value.sha256,
			"evidence_scope": "real Profile disk write; injected failed source checkpoint"}
		if not _write(root.path_join("write-evidence.json"), evidence):
			_fail(f, "write evidence", {}); return
	else:
		var loaded: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(root.path_join("write-evidence.json")))
		if not loaded.ok:
			_fail(f, "load original evidence", loaded); return
		if loaded.value.process_id == OS.get_process_id() or loaded.value.profile_sha256 != original_profile_sha or original_profile_sha != FileAccess.get_sha256(root.path_join("profile.json")):
			_fail(f, "distinct process exact Profile bytes", {}); return
		if not f.begin().ok or f.owner.pull_physical(f.token).value.phase != "checkpoint_retry":
			_fail(f, "recover Profile-ahead without installed Run", {}); return
		var retried: Dictionary = f.action("retry")
		if not retried.ok or f.record() != loaded.value.record or f.attempt().value.revision != loaded.value.revision:
			_fail(f, "exact preparing recovery", retried); return
		var closed: Dictionary = f.owner.close_scene_challenge(f.token)
		if not closed.ok or closed.value.outcome != "unfinished":
			_fail(f, "close recovered preparation", closed); return
		var proof: Dictionary = closed.value.attempt_proof
		var retained: Dictionary = f.attempt(proof.branch_id)
		if not FIXTURE.LEDGER.validate_attempt_proof(retained.value, proof).ok:
			_fail(f, "exact proof resolver", {}); return
		if not _write(root.path_join("read-evidence.json"), {"proof": proof, "closure": closed.value, "process_id": OS.get_process_id(),
			"original_profile_sha256": original_profile_sha, "original_process_id": loaded.value.process_id,
			"record_sha256": CANONICAL.canonical_sha256(f.record()).value.sha256,
			"evidence_scope": "new process real Profile disk read; injected source checkpoint and closure"}):
			_fail(f, "read evidence", {}); return
	print("SCENE_CHALLENGE_RESTART_PASS phase=" + phase)
	f.dispose()
	quit(0)

func _write(path: String, value: Dictionary) -> bool:
	var encoded: Dictionary = CANONICAL.canonical_json(value)
	if not encoded.ok: return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(str(encoded.value.text))
	file.close()
	return true

func _fail(f: RefCounted, stage: String, detail: Dictionary) -> void:
	push_error("scene restart " + stage + ": " + str(detail))
	f.dispose()
	quit(1)
