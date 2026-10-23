class_name FakeFileOps
extends RefCounted

var _persisted: Dictionary = {}
var _pending: Dictionary = {}
var _trace: Array[Dictionary] = []
var _operation_ordinal := 0
var _failure_ordinal := -1
var _failure_consumed := false

func _init(seed: Dictionary = {}) -> void:
	for path in seed:
		var value: Variant = seed[path]
		_persisted[str(path)] = value.duplicate() if value is PackedByteArray else str(value).to_utf8_buffer()

func fail_after(operation_ordinal: int) -> void:
	_failure_ordinal = operation_ordinal
	_failure_consumed = false

func exists(path: String) -> bool:
	_record_nonfallible(&"exists", path)
	return _persisted.has(path)

func read_bytes(path: String) -> Dictionary:
	if _should_fail(&"read_bytes", path):
		return _injected_failure()
	if not _persisted.has(path):
		return {"ok": false, "code": &"not_found", "message": path}
	return {"ok": true, "value": (_persisted[path] as PackedByteArray).duplicate()}

func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
	if _should_fail(&"write_bytes", path):
		return _injected_failure()
	_pending[path] = bytes.duplicate()
	return {"ok": true}

func flush_path(path: String) -> Dictionary:
	var fail := _should_fail(&"flush_path", path)
	if not _pending.has(path):
		return {"ok": false, "code": &"no_open_write", "message": path}
	if fail:
		_pending.erase(path)
		return _injected_failure()
	_persisted[path] = (_pending[path] as PackedByteArray).duplicate()
	_pending.erase(path)
	return {"ok": true}

func rename_path(from_path: String, to_path: String) -> Dictionary:
	if _should_fail(&"rename_path", from_path, to_path):
		return _injected_failure()
	if not _persisted.has(from_path):
		return {"ok": false, "code": &"not_found", "message": from_path}
	_persisted[to_path] = (_persisted[from_path] as PackedByteArray).duplicate()
	_persisted.erase(from_path)
	return {"ok": true}

func remove_path(path: String) -> Dictionary:
	if _should_fail(&"remove_path", path):
		return _injected_failure()
	_persisted.erase(path)
	_pending.erase(path)
	return {"ok": true}

func sha256(bytes: PackedByteArray) -> String:
	_record_nonfallible(&"sha256", "")
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func snapshot_persisted() -> Dictionary:
	var snapshot := {}
	for path in _persisted:
		snapshot[path] = (_persisted[path] as PackedByteArray).duplicate()
	return snapshot

func operation_trace() -> Array[Dictionary]:
	return _trace.duplicate(true)

func operation_count() -> int:
	return _operation_ordinal

func _should_fail(operation: StringName, path: String, destination: String = "") -> bool:
	_record(operation, path, destination)
	if not _failure_consumed and _operation_ordinal == _failure_ordinal:
		_failure_consumed = true
		return true
	return false

func _record(operation: StringName, path: String, destination: String = "") -> void:
	_operation_ordinal += 1
	_trace.append({"ordinal": _operation_ordinal, "operation": operation, "path": path, "destination": destination}.duplicate(true))

func _record_nonfallible(operation: StringName, path: String, destination: String = "") -> void:
	_trace.append({"ordinal": 0, "operation": operation, "path": path, "destination": destination}.duplicate(true))

func _injected_failure() -> Dictionary:
	return {"ok": false, "code": &"injected_failure", "message": "Injected FileOps failure at operation %d" % _operation_ordinal}
