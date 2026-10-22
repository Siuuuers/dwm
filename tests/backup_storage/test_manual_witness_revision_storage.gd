extends SceneTree
## Compare the frozen full-result baseline with the actual production compact
## witness helper. The real strict parser/schema, ordered storage protocol and
## revision custody remain unchanged.

const SAVE := preload("res://autoload/SaveManager.gd")
const BASELINE := preload("res://tests/support/ManualSaveWitnessPort.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const OPS := preload("res://tests/backup_storage/CrashFileOps.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const CANONICAL := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PATH := "slot_1.json"
const FINAL := "manual-witness/slot_1.json"

var failures: Array[String] = []
var assertions := 0
var write_pairs := 0
var write_fault_pairs := 0
var restart_pairs := 0
var restart_fault_pairs := 0
var refusal_pairs := 0
var distinct_snapshots := 0
var _outgoing := ""
var _document: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> bool:
	assertions += 1
	if not condition:
		failures.append(label)
	return condition

func _run() -> void:
	var previous_control := OS.get_environment("DWM_SAVE_PARSE_CACHE_DISABLED")
	if _build_document():
		for disabled: bool in [false, true]:
			OS.set_environment("DWM_SAVE_PARSE_CACHE_DISABLED", "1" if disabled else "")
			var cache_label := "cache-disabled" if disabled else "cache-enabled"
			var seeds: Array[Dictionary] = [{}, {FINAL: (" " + _outgoing).to_utf8_buffer()},
				{FINAL: _outgoing.to_utf8_buffer()}, {FINAL: PackedByteArray()},
				{FINAL: "broken JSON".to_utf8_buffer()},
				{FINAL: (" " + _outgoing).to_utf8_buffer(), FINAL + ".bak": "older opaque backup".to_utf8_buffer()},
				{FINAL: "opaque prior".to_utf8_buffer(), FINAL + ".bak": _outgoing.to_utf8_buffer()}]
			for index: int in seeds.size():
				_exercise(seeds[index], "%s/seed-%d" % [cache_label, index])
			_test_refusals(cache_label)
	OS.set_environment("DWM_SAVE_PARSE_CACHE_DISABLED", previous_control)
	print(JSON.stringify({"assertions": assertions, "write_pairs": write_pairs,
		"write_fault_pairs": write_fault_pairs, "restart_pairs": restart_pairs,
		"restart_fault_pairs": restart_fault_pairs, "distinct_snapshots": distinct_snapshots,
		"refusal_pairs": refusal_pairs, "failures": failures}))
	if failures.is_empty():
		print("MANUAL_WITNESS_REVISION_STORAGE_PASS")
	quit(0 if failures.is_empty() else 1)

func _build_document() -> bool:
	var snapshot := STRICT.parse_object(FileAccess.get_file_as_string(
		"res://tests/fixtures/saves/v7_desktop_prepared.json"))
	if not _check(snapshot.get("ok", false), "strict fixture parse"): return false
	snapshot.value["schema_version"] = preload("res://scripts/domain/run/RunSnapshotSchema.gd").SCHEMA_VERSION
	var built := SCHEMA.build(&"slot", 1, &"manual",
		{"checkpoint_kind": "manual_save", "snapshot": snapshot.value}, [])
	if not _check(built.get("ok", false), "real save schema build"): return false
	var emitted := CANONICAL.stringify(built.value)
	if not _check(emitted.get("ok", false), "canonical save document"): return false
	_outgoing = emitted.value + "\n"
	var admitted := SCHEMA.validate(STRICT.parse_object(_outgoing).value)
	if not _check(admitted.get("ok", false), "full outgoing schema admission"): return false
	_document = admitted.value.candidate
	return true

func _hash(bytes: PackedByteArray) -> String:
	return "".sha256_text() if bytes.is_empty() else OPS.new().sha256(bytes)

func _revision(seed: Dictionary) -> String:
	return _hash(seed[FINAL]) if seed.has(FINAL) else "absent"

## Every observation owns a new SaveManager, storage, FileOps and exact-text memo.
## In particular, restart never inherits a live memo, parse cache or playable lease.
func _observe(seed: Dictionary, production: bool, restarting: bool, outgoing: String,
		revision: String, fault: int = 0) -> Dictionary:
	var ops := OPS.new(seed)
	var storage := STORAGE.new("manual-witness", ops)
	var manager: Node = SAVE.new() if production else BASELINE.new()
	if not production:
		manager.write_variant = "baseline"
	_check(manager.initialize(storage).get("ok", false), "fresh owner initializes")
	_check(manager._document_parse_cache.is_empty() and storage._leases.is_empty(),
		"fresh owner starts without parse cache or lease")
	var memo := {}
	var validator: Callable = manager._write_document_text_validator.bind(memo)
	if fault > 0:
		ops.fail_after(fault)
	var result: Dictionary
	if restarting:
		result = storage.reconcile(PATH, validator)
	else:
		result = storage.write_atomic_if_revision(PATH, outgoing, validator, revision)
	var observation := {"result": result, "trace": ops.operation_trace(),
		"persisted": ops.snapshot_persisted(), "snapshots": ops.snapshots.duplicate(true),
		"operations": ops.operation_count(), "injected": ops._failure_consumed,
		"leases": storage._leases.duplicate(true), "memo_texts": memo.keys()}
	manager.free()
	return observation

func _pair(seed: Dictionary, restarting: bool, outgoing: String, revision: String,
		label: String, fault: int = 0) -> Dictionary:
	var baseline := _observe(seed, false, restarting, outgoing, revision, fault)
	var candidate := _observe(seed, true, restarting, outgoing, revision, fault)
	_check(baseline.trace == candidate.trace, label + ": exact ordered operations")
	_check(baseline.operations == candidate.operations, label + ": same fallible operation count")
	_check(baseline.injected == candidate.injected, label + ": same injection reachability")
	if fault > 0:
		_check(baseline.injected, label + ": selected operation actually failed")
	_check(baseline.persisted == candidate.persisted, label + ": exact durable bytes")
	_check(baseline.snapshots == candidate.snapshots, label + ": every durable interruption snapshot")
	_check(baseline.leases == candidate.leases, label + ": exact playable lease disposition")
	_check(baseline.memo_texts == candidate.memo_texts, label + ": identical admitted exact texts")
	var baseline_result: Dictionary = baseline.result.duplicate(true)
	var candidate_result: Dictionary = candidate.result.duplicate(true)
	# This is the sole intentional helper API difference. Do not normalize
	# refusals or other success metadata, and independently assert both value shapes.
	if baseline_result.get("ok", false) and baseline_result.has("value"):
		_check(CANONICAL._deep_same(baseline_result.value, _document),
			label + ": frozen baseline returns the complete independently admitted document")
		_check(candidate_result.get("value") == {}, label + ": production returns only its compact Dictionary")
		baseline_result.erase("value")
		candidate_result.erase("value")
	_check(baseline_result == candidate_result, label + ": exact outcome and refusal details")
	return baseline

func _collect_snapshots(snapshots: Array[Dictionary], observation: Dictionary) -> void:
	for snapshot: Dictionary in observation.snapshots:
		if snapshot not in snapshots:
			snapshots.append(snapshot.duplicate(true))
	if observation.persisted not in snapshots:
		snapshots.append(observation.persisted.duplicate(true))

func _exercise(seed: Dictionary, label: String) -> void:
	var revision := _revision(seed)
	var normal := _pair(seed, false, _outgoing, revision, label + "/write")
	write_pairs += 1
	_check(normal.result.get("ok", false), label + ": ordinary write succeeds")
	_check(normal.persisted == {FINAL: _outgoing.to_utf8_buffer()}, label + ": exact clean outgoing winner")
	var snapshots: Array[Dictionary] = [seed.duplicate(true)]
	_collect_snapshots(snapshots, normal)
	for ordinal: int in range(1, int(normal.operations) + 1):
		var failed := _pair(seed, false, _outgoing, revision,
			label + "/write-fault-%d" % ordinal, ordinal)
		write_fault_pairs += 1
		# Include fallback-reconciliation mutations, not only the happy-path flushes.
		_collect_snapshots(snapshots, failed)
	distinct_snapshots += snapshots.size()
	for index: int in snapshots.size():
		var restart_label := label + "/snapshot-%d" % index
		var restarted := _restart(snapshots[index], seed, restart_label)
		for ordinal: int in range(1, int(restarted.operations) + 1):
			var failed_restart := _pair(snapshots[index], true, "", "",
				restart_label + "/restart-fault-%d" % ordinal, ordinal)
			restart_fault_pairs += 1
			var interrupted: Array[Dictionary] = []
			_collect_snapshots(interrupted, failed_restart)
			for interruption: int in interrupted.size():
				_restart(interrupted[interruption], seed,
					restart_label + "/restart-fault-%d/durable-%d" % [ordinal, interruption])

func _restart(snapshot: Dictionary, original: Dictionary, label: String) -> Dictionary:
	var result := _pair(snapshot, true, "", "", label)
	restart_pairs += 1
	var original_wins: bool = result.persisted == original
	var outgoing_wins: bool = result.persisted == {FINAL: _outgoing.to_utf8_buffer()}
	_check(original_wins or outgoing_wins, label + ": restart yields exact old or exact new family")
	if snapshot.has(FINAL + ".txn.json"):
		_check(result.result.get("ok", false) or result.result.get("code") == &"write_not_committed",
			label + ": owned revision settles after fresh restart")
	if not result.result.get("ok", false):
		_check(result.leases.is_empty(), label + ": refused or opaque rollback grants no lease")
	if result.result.get("ok", false) and result.result.get("exists", false):
		_check(result.leases.get(PATH, {}).get("hash") == _hash(result.persisted[FINAL]),
			label + ": playable lease binds the exact physical winner")
	return result

func _refused(seed: Dictionary, restarting: bool, outgoing: String, revision: String,
		label: String, code: StringName = &"") -> void:
	var result := _pair(seed, restarting, outgoing, revision, label)
	refusal_pairs += 1
	_check(not result.result.get("ok", true), label + ": refused")
	if not code.is_empty():
		_check(result.result.get("code") == code, label + ": exact expected refusal")
	_check(result.persisted == seed and result.snapshots.is_empty(), label + ": custody preserves every byte")
	_check(result.leases.is_empty(), label + ": refusal grants no lease")

func _test_refusals(label: String) -> void:
	var prior := (" " + _outgoing).to_utf8_buffer()
	var seed := {FINAL: prior, FINAL + ".bak": "opaque backup".to_utf8_buffer()}
	for invalid: String in ["{", '{"duplicate":1,"duplicate":2}', '{"schema_version":999}']:
		_refused(seed, false, invalid, _revision(seed), label + "/invalid-outgoing-" + invalid,
			&"outgoing_validation_failed")
	_refused(seed, false, _outgoing, "0".repeat(64), label + "/stale-revision", &"revision_changed")
	for suffix: String in [".next", ".txn.json", ".revision-prior"]:
		var pending := seed.duplicate(true)
		pending[FINAL + suffix] = "unowned".to_utf8_buffer()
		_refused(pending, false, _outgoing, _revision(seed), label + "/pending" + suffix, &"reconcile_required")
	_refused({FINAL + ".bak": prior}, false, _outgoing, "absent", label + "/orphan-backup", &"reconcile_required")
	var marker := {"schema_version": 2, "relative_path": PATH, "operation": "write_revision",
		"stage": "prepared", "previous_hash": _hash(prior), "backup_hash": null,
		"outgoing_hash": _hash(_outgoing.to_utf8_buffer())}
	for suffix: String in ["", ".next", ".revision-prior", ".bak"]:
		var foreign := {FINAL: prior, FINAL + ".next": _outgoing.to_utf8_buffer(),
			FINAL + ".txn.json": JSON.stringify(marker).to_utf8_buffer()}
		foreign[FINAL + suffix] = "foreign bytes".to_utf8_buffer()
		_refused(foreign, true, "", "", label + "/foreign" + suffix, &"indeterminate_commit")
	for invalid: String in ['{"schema_version":999}', '{"duplicate":1,"duplicate":2}']:
		var invalid_marker := marker.duplicate(true)
		invalid_marker.outgoing_hash = _hash(invalid.to_utf8_buffer())
		_refused({FINAL: prior, FINAL + ".next": invalid.to_utf8_buffer(),
			FINAL + ".txn.json": JSON.stringify(invalid_marker).to_utf8_buffer()},
			true, "", "", label + "/hash-bound-invalid-" + invalid, &"indeterminate_commit")
	_refused({FINAL: prior, FINAL + ".txn.json": '{"schema_version":'.to_utf8_buffer()},
		true, "", "", label + "/torn-marker", &"indeterminate_transaction")
