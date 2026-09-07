extends "res://addons/gut/test.gd"

const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILE_OPS := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const JSON_READER := preload("res://scripts/validation/StrictJson.gd")
const ROOT := "profile-new-run-memory"
const PATH := ROOT + "/profile.json"
const SIGNALS := ["profile_restored", "preference_changed", "gallery_changed", "visited_history_changed",
	"input_mappings_changed", "controls_bindings_changed", "profile_reset", "profile_write_failed"]


func _fixture(dark: bool = true) -> Dictionary:
	var ops: RefCounted = FILE_OPS.new()
	var storage: RefCounted = STORAGE.new(ROOT, ops)
	var profile: Node = autofree(PROFILE.new())
	assert_true(profile.initialize(storage).get("ok", false))
	assert_true(profile.configure_new_run_storage(storage).get("ok", false))
	# Explicitly authored Profile fixture; its first-process migration receipt stays false.
	var candidate: Dictionary = profile.get_profile_snapshot()
	candidate["preferences"]["dark_mode"] = {"available": true, "next_run_enabled": dark}
	candidate["preferences"]["reading"]["reveal_speed"] = "slow"
	candidate["preferences"]["audio"]["music_volume"] = 0.37
	candidate["gallery_unlocks"] = ["ending.alone"]
	candidate["visited_line_ids"] = ["fixture.new-run.persisted-line"]
	assert_true(profile.commit_prepared_profile(candidate).get("ok", false))
	var gate: RefCounted = GATE.new()
	assert_true(profile.configure_mutation_gate(gate).get("ok", false))
	watch_signals(profile)
	return {"profile": profile, "ops": ops, "storage": storage, "gate": gate}


func _material(fixture: Dictionary) -> Dictionary:
	var prepared: Dictionary = fixture.profile.prepare_new_run_consumption(fixture.profile.get_profile_revision())
	assert_true(prepared.get("ok", false), str(prepared))
	return prepared.get("value", {})


func _startup(seed: Dictionary) -> Dictionary:
	var ops: RefCounted = FILE_OPS.new(seed)
	var storage: RefCounted = STORAGE.new(ROOT, ops)
	var profile: Node = autofree(PROFILE.new())
	var gate: RefCounted = GATE.new()
	assert_true(profile.configure_new_run_storage(storage).get("ok", false))
	assert_true(profile.configure_mutation_gate(gate).get("ok", false))
	assert_true(gate.acquire(&"new_run").get("ok", false))
	watch_signals(profile)
	return {"profile": profile, "ops": ops, "storage": storage, "gate": gate}


func _quiet(profile: Node, before: Dictionary, revision: int) -> void:
	assert_eq(profile.get_profile_snapshot(), before)
	assert_eq(profile.get_profile_revision(), revision)
	for signal_name: String in SIGNALS:
		assert_signal_not_emitted(profile, signal_name)


func _no_writes(ops: RefCounted, start: int) -> void:
	var trace: Array = ops.operation_trace()
	for index: int in range(start, trace.size()):
		assert_false(trace[index].operation in [&"write_bytes", &"flush_path", &"rename_path", &"remove_path"], str(trace[index]))


func _replace_file(ops: RefCounted, path: String, text: String) -> void:
	assert_true(ops.write_bytes(path, text.to_utf8_buffer()).get("ok", false))
	assert_true(ops.flush_path(path).get("ok", false))


func test_storage_binding_is_quiet_immutable_and_can_precede_initialization() -> void:
	var profile: Node = autofree(PROFILE.new())
	var ops: RefCounted = FILE_OPS.new()
	var storage: RefCounted = STORAGE.new(ROOT, ops)
	watch_signals(profile)
	assert_false(profile.configure_new_run_storage(null).get("ok", true))
	assert_false(profile.configure_new_run_storage(RefCounted.new()).get("ok", true))
	assert_true(profile.configure_new_run_storage(storage).get("ok", false))
	assert_true(profile.configure_new_run_storage(storage).value.already_configured)
	var other: RefCounted = STORAGE.new(ROOT + "-other", FILE_OPS.new())
	assert_eq(profile.configure_new_run_storage(other).get("code"), &"profile_storage_already_bound")
	assert_eq(profile.initialize(other).get("code"), &"profile_storage_already_bound")
	assert_eq(profile.prepare_new_run_consumption(1).get("code"), &"not_initialized")
	assert_eq(ops.operation_trace(), [])
	_quiet(profile, {}, 0)
	assert_true(profile.initialize(storage).get("ok", false))


func test_preparation_freezes_current_first_process_profile_without_legacy_patch_or_side_effects() -> void:
	for dark: bool in [false, true]:
		var fixture: Dictionary = _fixture(dark)
		var before: Dictionary = fixture.profile.get_profile_snapshot()
		var revision: int = fixture.profile.get_profile_revision()
		var files: Dictionary = fixture.ops.snapshot_persisted()
		var start: int = fixture.ops.operation_trace().size()
		var material: Dictionary = _material(fixture)
		var expected: Dictionary = before.duplicate(true)
		expected["preferences"]["dark_mode"]["next_run_enabled"] = false
		assert_eq(material.size(), 7)
		assert_eq(material.before, before)
		assert_eq(material.candidate, expected)
		assert_eq(material.captured_dark, dark)
		assert_eq(material.profile_revision, revision)
		assert_eq(material.source_revision, fixture.storage.inspect_revision("profile.json").value.revision)
		assert_eq(material.outgoing_text, WRITER.stringify(expected).value)
		assert_eq(material.outgoing_hash, material.outgoing_text.sha256_text())
		assert_false(material.candidate.migration_receipts.legacy_game_state_profile_v1)
		assert_eq(material.candidate.controls_bindings, before.controls_bindings)
		assert_eq(material.candidate.preferences.reading.reveal_speed, "slow")
		material.before.preferences.reading.reveal_speed = "fast"
		material.candidate.gallery_unlocks.clear()
		_quiet(fixture.profile, before, revision)
		assert_eq(fixture.ops.snapshot_persisted(), files)
		_no_writes(fixture.ops, start)


func test_preparation_rejects_stale_revision_invalid_dark_and_live_disk_disagreement_without_writes() -> void:
	var fixture: Dictionary = _fixture()
	var revision: int = fixture.profile.get_profile_revision()
	var files: Dictionary = fixture.ops.snapshot_persisted()
	var start: int = fixture.ops.operation_trace().size()
	for invalid: Variant in [null, 1.5, "2", true, -1]:
		assert_eq(fixture.profile.prepare_new_run_consumption(invalid).get("code"), &"invalid_profile_revision")
	assert_eq(fixture.profile.prepare_new_run_consumption(revision - 1).get("code"), &"profile_revision_changed")
	var original: Dictionary = fixture.profile.get_profile_snapshot()
	for dark: Variant in [{"available": false, "next_run_enabled": true}, {"available": true, "next_run_enabled": 1}, {}]:
		var malformed: Dictionary = original.duplicate(true)
		malformed.preferences.dark_mode = dark
		fixture.profile.set("_profile", malformed) # Corrupt only this disposable owner's source.
		assert_false(fixture.profile.prepare_new_run_consumption(revision).get("ok", true))
	var changed: Dictionary = original.duplicate(true)
	changed.preferences.reading.reveal_speed = "fast"
	fixture.profile.set("_profile", changed)
	assert_eq(fixture.profile.prepare_new_run_consumption(revision).get("code"), &"profile_source_changed")
	assert_eq(fixture.ops.snapshot_persisted(), files)
	_no_writes(fixture.ops, start)
	_quiet(fixture.profile, changed, revision)


func test_canonical_journal_roundtrip_persists_without_adoption_and_is_idempotent() -> void:
	var fixture: Dictionary = _fixture()
	var material: Dictionary = _material(fixture)
	var serialized: Dictionary = WRITER.stringify(material)
	assert_true(serialized.get("ok", false), str(serialized))
	var decoded: Dictionary = JSON_READER.parse_object(serialized.value)
	assert_true(decoded.get("ok", false))
	assert_eq(typeof(decoded.value.profile_revision), TYPE_INT)
	var before: Dictionary = fixture.profile.get_profile_snapshot()
	var revision: int = fixture.profile.get_profile_revision()
	assert_true(fixture.gate.acquire(&"new_run").get("ok", false))
	var persisted: Dictionary = fixture.profile.persist_new_run_consumption(decoded.value)
	assert_true(persisted.get("ok", false), str(persisted))
	assert_false(persisted.get("value", {}).get("already_persisted", true))
	assert_eq(fixture.storage.inspect_revision("profile.json").value.text, material.outgoing_text)
	_quiet(fixture.profile, before, revision)
	var start: int = fixture.ops.operation_trace().size()
	var replay: Dictionary = fixture.profile.persist_new_run_consumption(decoded.value)
	assert_true(replay.get("ok", false), str(replay))
	assert_true(replay.get("value", {}).get("already_persisted", false))
	_no_writes(fixture.ops, start)
	_quiet(fixture.profile, before, revision)


func test_source_revision_binds_actual_bytes_and_accepts_valid_noncanonical_source_formatting() -> void:
	var fixture: Dictionary = _fixture()
	var raw: String = fixture.storage.inspect_revision("profile.json").value.text
	_replace_file(fixture.ops, PATH, "\n" + raw + "\n")
	var material: Dictionary = _material(fixture)
	assert_eq(material.source_revision, ("\n" + raw + "\n").sha256_text())
	assert_ne(material.source_revision, raw.sha256_text())
	assert_true(fixture.gate.acquire(&"new_run").get("ok", false))
	assert_true(fixture.profile.persist_new_run_consumption(material).get("ok", false))
	assert_eq(fixture.storage.inspect_revision("profile.json").value.text, material.outgoing_text)
	_quiet(fixture.profile, material.before, material.profile_revision)


func test_disabled_selector_is_already_persisted_without_writes() -> void:
	var fixture: Dictionary = _fixture(false)
	var material: Dictionary = _material(fixture)
	assert_true(fixture.gate.acquire(&"new_run").get("ok", false))
	var start: int = fixture.ops.operation_trace().size()
	var persisted: Dictionary = fixture.profile.persist_new_run_consumption(material)
	assert_true(persisted.get("ok", false), str(persisted))
	assert_true(persisted.get("value", {}).get("already_persisted", false))
	_no_writes(fixture.ops, start)
	_quiet(fixture.profile, material.before, material.profile_revision)


func test_persistence_requires_exact_nonfatal_new_run_custody() -> void:
	for owner: StringName in [&"", &"restore", &"causal_transaction", &"new_run"]:
		var fixture: Dictionary = _fixture()
		var material: Dictionary = _material(fixture)
		if not owner.is_empty(): assert_true(fixture.gate.acquire(owner).get("ok", false))
		if owner == &"new_run":
			assert_true(fixture.gate.latch_fatal({"source": "fixture", "phase": "persist", "code": "blocked", "details": {}}).get("ok", false))
		var files: Dictionary = fixture.ops.snapshot_persisted()
		var start: int = fixture.ops.operation_trace().size()
		assert_eq(fixture.profile.persist_new_run_consumption(material).get("code"), &"new_run_custody_required")
		assert_eq(fixture.ops.snapshot_persisted(), files)
		_no_writes(fixture.ops, start)
		_quiet(fixture.profile, material.before, material.profile_revision)


func test_malformed_or_rewritten_material_is_refused_before_storage_mutation() -> void:
	var fixture: Dictionary = _fixture()
	var material: Dictionary = _material(fixture)
	assert_true(fixture.gate.acquire(&"new_run").get("ok", false))
	var variants: Array[Dictionary] = []
	for key: String in material:
		var missing: Dictionary = material.duplicate(true)
		missing.erase(key)
		variants.append(missing)
	for pair: Array in [["profile_revision", 2.0], ["captured_dark", false], ["source_revision", "absent"],
			["outgoing_hash", "f".repeat(64)], ["outgoing_text", material.outgoing_text + "\n"], ["before", null]]:
		var malformed: Dictionary = material.duplicate(true)
		malformed[pair[0]] = pair[1]
		variants.append(malformed)
	var extra: Dictionary = material.duplicate(true)
	extra["extra"] = true
	variants.append(extra)
	var rewritten: Dictionary = material.duplicate(true)
	rewritten.candidate.preferences.reading.reveal_speed = "fast"
	rewritten.outgoing_text = WRITER.stringify(rewritten.candidate).value
	rewritten.outgoing_hash = rewritten.outgoing_text.sha256_text()
	variants.append(rewritten)
	var files: Dictionary = fixture.ops.snapshot_persisted()
	var start: int = fixture.ops.operation_trace().size()
	for malformed: Dictionary in variants:
		assert_false(fixture.profile.persist_new_run_consumption(malformed).get("ok", true), str(malformed.keys()))
	assert_eq(fixture.ops.snapshot_persisted(), files)
	_no_writes(fixture.ops, start)
	_quiet(fixture.profile, material.before, material.profile_revision)


func test_foreign_final_bytes_and_stale_live_revision_are_refused() -> void:
	var fixture: Dictionary = _fixture()
	var material: Dictionary = _material(fixture)
	assert_true(fixture.gate.acquire(&"new_run").get("ok", false))
	var foreign: Dictionary = material.before.duplicate(true)
	foreign.preferences.reading.reveal_speed = "instant"
	_replace_file(fixture.ops, PATH, WRITER.stringify(foreign).value)
	var files: Dictionary = fixture.ops.snapshot_persisted()
	var start: int = fixture.ops.operation_trace().size()
	assert_eq(fixture.profile.persist_new_run_consumption(material).get("code"), &"profile_source_changed")
	assert_eq(fixture.ops.snapshot_persisted(), files)
	_no_writes(fixture.ops, start)
	fixture.profile.set("_profile_revision", material.profile_revision + 1)
	assert_eq(fixture.profile.persist_new_run_consumption(material).get("code"), &"profile_revision_changed")
	_quiet(fixture.profile, material.before, material.profile_revision + 1)


func test_pending_preparation_is_pure_and_foreign_marker_is_never_reconciled() -> void:
	var fixture: Dictionary = _fixture()
	var material: Dictionary = _material(fixture)
	assert_true(fixture.gate.acquire(&"new_run").get("ok", false))
	for mismatch: String in ["outgoing_hash", "previous_hash", "operation"]:
		var marker: Dictionary = {"schema_version": 2, "relative_path": "profile.json", "operation": "write_revision",
			"stage": "prepared", "previous_hash": material.source_revision, "backup_hash": null, "outgoing_hash": material.outgoing_hash}
		marker[mismatch] = "delete_revision" if mismatch == "operation" else "f".repeat(64)
		_replace_file(fixture.ops, PATH + ".txn.json", WRITER.stringify(marker).value)
		var files: Dictionary = fixture.ops.snapshot_persisted()
		var start: int = fixture.ops.operation_trace().size()
		assert_eq(fixture.profile.prepare_new_run_consumption(material.profile_revision).get("code"), &"reconcile_required")
		assert_eq(fixture.profile.persist_new_run_consumption(material).get("code"), &"profile_source_changed")
		assert_eq(fixture.ops.snapshot_persisted(), files)
		_no_writes(fixture.ops, start)
	_quiet(fixture.profile, material.before, material.profile_revision)


func test_restart_recovers_failures_before_promotion_and_after_committed_write_without_adoption() -> void:
	var fixture: Dictionary = _fixture()
	var material: Dictionary = _material(fixture)
	var seed: Dictionary = fixture.ops.snapshot_persisted()
	var probe: Dictionary = _startup(seed)
	assert_true(probe.profile.persist_new_run_consumption(material).get("ok", false))
	var ordinals: Array[int] = []
	var last_read: int = 0
	for step: Dictionary in probe.ops.operation_trace():
		if (step.operation == &"flush_path" and step.path == PATH + ".txn.json") \
				or (step.operation == &"rename_path" and step.path == PATH + ".next") \
				or (step.operation == &"remove_path" and step.path == PATH + ".txn.json"):
			ordinals.append(step.ordinal)
		if step.operation == &"read_bytes" and step.path == PATH: last_read = step.ordinal
	ordinals.append(last_read)
	assert_eq(ordinals.size(), 4, "Before marker durability, before promotion, committed cleanup and final readback")
	for ordinal: int in ordinals:
		var fault: Dictionary = _startup(seed)
		fault.ops.fail_after(ordinal)
		var attempted: Dictionary = fault.profile.persist_new_run_consumption(material)
		assert_false(attempted.get("ok", true), "Fault ordinal %d must be observed: %s" % [ordinal, attempted])
		_quiet(fault.profile, {}, 0)
		var restart: Dictionary = _startup(fault.ops.snapshot_persisted())
		var recovered: Dictionary = restart.profile.persist_new_run_consumption(material)
		assert_true(recovered.get("ok", false), "Fault ordinal %d: %s" % [ordinal, recovered])
		assert_eq(restart.storage.inspect_revision("profile.json").value.text, material.outgoing_text)
		_quiet(restart.profile, {}, 0)
		var start: int = restart.ops.operation_trace().size()
		assert_true(restart.profile.persist_new_run_consumption(material).get("ok", false))
		_no_writes(restart.ops, start)


func test_consumption_proof_is_read_only_before_adoption_after_restart_and_with_foreign_bytes() -> void:
	var fixture: Dictionary = _fixture()
	var material: Dictionary = _material(fixture)
	assert_true(fixture.profile.has_method("prove_new_run_consumption"))
	if not fixture.profile.has_method("prove_new_run_consumption"): return
	var start: int = fixture.ops.operation_trace().size()
	assert_false(fixture.profile.prove_new_run_consumption(material).get("ok", true))
	_no_writes(fixture.ops, start)
	assert_true(fixture.gate.acquire(&"new_run").get("ok", false))
	assert_true(fixture.profile.persist_new_run_consumption(material).get("ok", false))
	start = fixture.ops.operation_trace().size()
	assert_true(fixture.profile.prove_new_run_consumption(material).get("ok", false))
	_quiet(fixture.profile, material.before, material.profile_revision)
	_no_writes(fixture.ops, start)
	var restarted: Dictionary = _startup(fixture.ops.snapshot_persisted())
	assert_true(restarted.profile.initialize(restarted.storage).get("ok", false))
	assert_eq(restarted.profile.get_profile_snapshot(), material.candidate)
	assert_ne(restarted.profile.get_profile_revision(), material.profile_revision)
	start = restarted.ops.operation_trace().size()
	assert_true(restarted.profile.prove_new_run_consumption(material).get("ok", false))
	_no_writes(restarted.ops, start)
	var foreign: Dictionary = material.candidate.duplicate(true)
	foreign.preferences.reading.reveal_speed = "fast"
	_replace_file(restarted.ops, PATH, WRITER.stringify(foreign).value)
	var files: Dictionary = restarted.ops.snapshot_persisted()
	start = restarted.ops.operation_trace().size()
	assert_false(restarted.profile.prove_new_run_consumption(material).get("ok", true))
	var malformed: Dictionary = material.duplicate(true)
	malformed.candidate.preferences.reading.reveal_speed = "fast"
	assert_false(restarted.profile.prove_new_run_consumption(malformed).get("ok", true))
	_no_writes(restarted.ops, start)
	assert_eq(restarted.ops.snapshot_persisted(), files)
