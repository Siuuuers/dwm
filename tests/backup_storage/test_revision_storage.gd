extends SceneTree

const STORAGE = preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const OPS = preload("res://tests/backup_storage/CrashFileOps.gd")
const PATH := "slot.json"
const FINAL := "memory/slot.json"
const OUT := "{\"valid\":true,\"version\":2}"
var failures: Array[String] = []
var assertions := 0
var restarts := 0
var injected := 0

func _init() -> void:
	call_deferred("_run")

func _validate(text: String) -> Dictionary:
	var result := StrictJson.parse_object(text)
	if not result.get("ok", false) or result.get("value", {}).get("valid") != true:
		return {"ok": false}
	return result

func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)

func _hash(bytes: PackedByteArray) -> String:
	return "".sha256_text() if bytes.is_empty() else OPS.new().sha256(bytes)

func _run() -> void:
	var priors := [PackedByteArray(), "{\"valid\":true,\"version\":1}".to_utf8_buffer(),
		"broken JSON".to_utf8_buffer(), "{\"future\":99}".to_utf8_buffer(), PackedByteArray([255, 128, 195])]
	for prior in priors:
		for backup in [false, true]:
			if prior.is_empty() and backup:
				continue
			var seed := {}
			if not prior.is_empty():
				seed[FINAL] = prior
			if backup:
				seed[FINAL + ".bak"] = "older arbitrary backup".to_utf8_buffer()
			_test_inspection(seed)
			for deleting in [false, true]:
				_exercise(seed, deleting)
	_test_refusals()
	for seed in [{FINAL: PackedByteArray()}, {FINAL: OUT.to_utf8_buffer()}]:
		_test_inspection(seed)
		for deleting in [false, true]:
			_exercise(seed, deleting)
	_test_foreign_artifacts()
	_test_validator_marker_replacement()
	_test_legacy()
	print(JSON.stringify({"assertions": assertions, "restart_snapshots": restarts,
		"injected_positions": injected, "failures": failures}))
	if failures.is_empty():
		print("BACKUP_REVISION_STORAGE_PASS")
	quit(0 if failures.is_empty() else 1)

func _revision(seed: Dictionary) -> String:
	return _hash(seed[FINAL]) if seed.has(FINAL) else "absent"

func _test_inspection(seed: Dictionary) -> void:
	var ops := OPS.new(seed)
	var storage := STORAGE.new("memory", ops)
	var result := storage.inspect_revision(PATH)
	_check(result.get("ok", false), "Inspection succeeds")
	_check(result.get("value", {}).get("revision") == _revision(seed), "Raw revision exact")
	_check(ops.snapshot_persisted() == seed, "Inspection preserves every byte")
	_check(storage._leases.is_empty(), "Inspection grants no lease")
	for operation in ops.operation_trace():
		_check(operation["operation"] in [&"exists", &"read_bytes", &"sha256"], "Inspection only reads")
	if seed.has(FINAL) and not seed[FINAL].is_empty() and seed[FINAL][0] == 255:
		_check(result["value"]["text"] == null, "Invalid UTF-8 has no text")
	var before := ops.snapshot_persisted()
	_check(not storage.remove_if_revision(PATH, "0".repeat(64)).get("ok", false), "Stale delete rejected")
	_check(not storage.write_atomic_if_revision(PATH, OUT, _validate, "0".repeat(64)).get("ok", false), "Stale write rejected")
	_check(not storage.write_atomic_if_revision(PATH, "bad", _validate, _revision(seed)).get("ok", false), "Bad outgoing rejected")
	_check(ops.snapshot_persisted() == before, "Rejected actions preserve bytes")

func _invoke(storage: RefCounted, seed: Dictionary, deleting: bool) -> Dictionary:
	if deleting:
		return storage.remove_if_revision(PATH, _revision(seed))
	return storage.write_atomic_if_revision(PATH, OUT, _validate, _revision(seed))

func _exercise(seed: Dictionary, deleting: bool) -> void:
	var ops := OPS.new(seed)
	var storage := STORAGE.new("memory", ops)
	var result := _invoke(storage, seed, deleting)
	_check(result.get("ok", false), "Normal action succeeds: %s" % result)
	_check(ops.snapshot_persisted() == ({} if deleting else {FINAL: OUT.to_utf8_buffer()}), "Normal final exact and clean")
	if not deleting:
		_check(storage.read_text(PATH).get("value") == OUT, "Validated write grants exact lease")
	for snapshot in ops.snapshots:
		_restart(snapshot, seed, deleting)
	for ordinal in range(1, ops.operation_count() + 1):
		injected += 1
		var failed_ops := OPS.new(seed)
		failed_ops.fail_after(ordinal)
		var failed_storage := STORAGE.new("memory", failed_ops)
		_invoke(failed_storage, seed, deleting)
		_restart(failed_ops.snapshot_persisted(), seed, deleting)

func _restart(snapshot: Dictionary, original: Dictionary, deleting: bool) -> void:
	restarts += 1
	var ops := OPS.new(snapshot)
	var storage := STORAGE.new("memory", ops)
	if snapshot.has(FINAL + ".txn.json"):
		var result := storage.reconcile(PATH, _validate)
		_check(result.get("ok", false) or result.get("code") == &"write_not_committed", "Restart settles owned family: %s" % result)
	var after := ops.snapshot_persisted()
	var original_wins := after == original
	var outgoing_wins := after == ({} if deleting else {FINAL: OUT.to_utf8_buffer()})
	_check(original_wins or outgoing_wins, "Restart yields exact old or exact new state")
	if original_wins and not outgoing_wins:
		_check(storage._leases.is_empty(), "Opaque rollback has no playable lease")

func _test_refusals() -> void:
	for suffix in [".next", ".txn.json", ".revision-prior"]:
		var seed := {FINAL: "old".to_utf8_buffer(), FINAL + suffix: "unowned".to_utf8_buffer()}
		var ops := OPS.new(seed)
		var storage := STORAGE.new("memory", ops)
		_check(not storage.inspect_revision(PATH).get("ok", false), "Pending inspection refused")
		_check(not storage.remove_if_revision(PATH, _revision(seed)).get("ok", false), "Pending delete refused")
		_check(not storage.write_atomic_if_revision(PATH, OUT, _validate, _revision(seed)).get("ok", false), "Pending write refused")
		_check(ops.snapshot_persisted() == seed, "Unknown family preserved")
	var orphan := {FINAL + ".bak": "orphan".to_utf8_buffer()}
	var orphan_ops := OPS.new(orphan)
	_check(not STORAGE.new("memory", orphan_ops).remove_if_revision(PATH, "absent").get("ok", false), "Orphan backup delete refused")
	_check(orphan_ops.snapshot_persisted() == orphan, "Orphan backup preserved")

func _test_foreign_artifacts() -> void:
	var old := "opaque prior".to_utf8_buffer()
	var marker := {"schema_version": 2, "relative_path": PATH, "operation": "write_revision", "stage": "prepared",
		"previous_hash": _hash(old), "backup_hash": null, "outgoing_hash": _hash(OUT.to_utf8_buffer())}
	for suffix in ["", ".next", ".revision-prior", ".bak"]:
		var seed := {FINAL: old, FINAL + ".next": OUT.to_utf8_buffer(), FINAL + ".txn.json": JSON.stringify(marker).to_utf8_buffer()}
		seed[FINAL + suffix] = "{\"valid\":true,\"foreign\":true}".to_utf8_buffer()
		_assert_preserved(seed, "Foreign hash " + suffix)
	for changed in ["relative_path", "stage", "extra"]:
		var invalid := marker.duplicate(true)
		invalid[changed] = "unexpected"
		_assert_preserved({FINAL: old, FINAL + ".next": OUT.to_utf8_buffer(), FINAL + ".txn.json": JSON.stringify(invalid).to_utf8_buffer()}, "Malformed marker " + changed)
	var delete_marker := marker.duplicate(true)
	delete_marker["operation"] = "delete_revision"
	delete_marker["stage"] = "delete_marked"
	delete_marker["outgoing_hash"] = null
	for suffix in ["", ".next", ".revision-prior", ".bak"]:
		var seed := {FINAL: old, FINAL + ".txn.json": JSON.stringify(delete_marker).to_utf8_buffer()}
		seed[FINAL + suffix] = "foreign".to_utf8_buffer()
		_assert_preserved(seed, "Foreign delete artifact " + suffix)
	_assert_preserved({FINAL: old, FINAL + ".next": "truncated".to_utf8_buffer(), FINAL + ".txn.json": JSON.stringify(marker).to_utf8_buffer()}, "Torn candidate never promoted")
	_assert_preserved({FINAL: old, FINAL + ".txn.json": "{\"schema_version\":".to_utf8_buffer()}, "Torn marker preserves prior")
	var invalid_out := marker.duplicate(true)
	invalid_out["outgoing_hash"] = _hash("bad".to_utf8_buffer())
	_assert_preserved({FINAL: old, FINAL + ".next": "bad".to_utf8_buffer(), FINAL + ".txn.json": JSON.stringify(invalid_out).to_utf8_buffer()}, "Hash cannot replace real validator")
	var rollback := {FINAL + ".revision-prior": old, FINAL + ".txn.json": JSON.stringify(marker).to_utf8_buffer()}
	var ops := OPS.new(rollback)
	var storage := STORAGE.new("memory", ops)
	_check(storage.reconcile(PATH, _validate).get("code") == &"write_not_committed", "Opaque sidecar rolls back")
	_check(ops.snapshot_persisted() == {FINAL: old}, "Opaque rollback bytes exact")
	_check(not storage.read_text(PATH).get("ok", false), "Rollback never grants playable lease")

func _assert_preserved(seed: Dictionary, label: String) -> void:
	var ops := OPS.new(seed)
	var storage := STORAGE.new("memory", ops)
	_check(not storage.reconcile(PATH, _validate).get("ok", false), label + " refused")
	_check(ops.snapshot_persisted() == seed, label + " preserved")
	_check(storage._leases.is_empty(), label + " has no lease")

func _test_validator_marker_replacement() -> void:
	var marker := {"schema_version": 2, "relative_path": PATH, "operation": "write_revision", "stage": "prepared",
		"previous_hash": null, "backup_hash": null, "outgoing_hash": _hash(OUT.to_utf8_buffer())}
	var ops := OPS.new({FINAL: OUT, FINAL + ".txn.json": JSON.stringify(marker)})
	var storage := STORAGE.new("memory", ops)
	var calls := [0]
	var validator := func(text: String) -> Dictionary:
		calls[0] += 1
		if calls[0] == 2:
			ops._persisted[FINAL + ".txn.json"] = "foreign marker".to_utf8_buffer()
		return _validate(text)
	_check(not storage.reconcile(PATH, validator).get("ok", false), "Final validation cannot replace durable authority")
	_check(ops.snapshot_persisted().get(FINAL + ".txn.json") == "foreign marker".to_utf8_buffer(), "Foreign marker survives final validation callback")
	_check(storage._leases.is_empty(), "Changed marker gives no lease")

func _test_legacy() -> void:
	var old := "{\"valid\":true,\"version\":1}"
	var ops := OPS.new({FINAL: old})
	var storage := STORAGE.new("memory", ops)
	_check(storage.write_atomic(PATH, OUT, _validate).get("ok", false), "Legacy write still succeeds")
	_check(ops.snapshot_persisted().get(FINAL + ".bak") == old.to_utf8_buffer(), "Legacy keeps backup")
	_check(storage.reconcile(PATH, _validate).get("ok", false), "Legacy reconcile succeeds")
	_check(storage.remove(PATH).get("ok", false), "Legacy delete succeeds")
	_check(ops.snapshot_persisted().is_empty(), "Legacy delete cleans family")
