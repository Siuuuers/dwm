class_name FakeDesktopContinuationJournalStorage
extends RefCounted

## Test double for the atomic storage injected into DesktopContinuationOperationJournal
## (Plan 02 Task 1, dwm-p2r.16).
##
## Duck-typed `extends RefCounted` rather than `extends StorageAdapter`, matching all 13 existing
## tests/support fakes (dwm-p2r.16 DECISION 8.5). Full working body per DECISION 9.2.
##
## SCOPE: this double serves the JOURNAL only. The issuer root store gets real JsonFileStorage over
## FakeFileOps instead (DECISION 9.3), because its crash cuts must exercise genuine two-phase
## atomic-write semantics rather than a hand-rolled imitation of them.
##
## PROTOCOL FIDELITY. JsonFileStorage requires a fresh `reconcile()` lease before `read_text()` will
## answer, and fails with `reconcile_required` otherwise. This double enforces the same rule
## deliberately: without it, a Step 1.3 journal could skip reconciliation, pass against this fake,
## and then fail against real storage. The validator convention also matches production --
## `validator.call(text)` must return a Dictionary, and on success its `value` member is the parsed
## document that `reconcile()` hands back.
##
## Fake-local codes (`fake_*`) are inventions of this double. Tests MUST NOT assert them as though
## they were frozen production contract; assert only the DECISION 9.9 distinctness law. No method
## here ever returns `not_implemented`, so no rejection assertion can be satisfied by an
## unconfigured double.

const ROOT_LABEL := "fake://desktop-continuation-journal"

## Spy surface: one entry per call, `{"method": StringName, "relative_path": String}`, in order.
var call_log: Array[Dictionary] = []
var write_count: int = 0

var _documents: Dictionary = {}
var _leases: Dictionary = {}
var _armed_write_failure_code: StringName = &""
var _armed_write_failure_ordinal: int = -1


# ---------------------------------------------------------------------------------------------
# StorageAdapter's six-method contract
# ---------------------------------------------------------------------------------------------

func read_text(relative_path: String) -> Dictionary:
	_log(&"read_text", relative_path)
	if not _leases.has(relative_path):
		return _failed(&"reconcile_required", "A fresh reconciliation lease is required")
	if not _documents.has(relative_path):
		return _failed(&"not_found", relative_path)
	return {"ok": true, "value": str(_documents[relative_path])}


func write_atomic(relative_path: String, text: String, validator: Callable,
		keep_backup: bool = true) -> Dictionary:
	_log(&"write_atomic", relative_path)
	write_count += 1
	var outgoing: Variant = validator.call(text)
	if typeof(outgoing) != TYPE_DICTIONARY:
		return _failed(&"invalid_validator_result", "Validator must return a Dictionary")
	if not (outgoing as Dictionary).get("ok", false):
		return _failed(&"outgoing_validation_failed",
			str((outgoing as Dictionary).get("message", "Outgoing document rejected")))
	if _write_should_fail():
		# The armed failure lands AFTER validation and BEFORE the store mutates, which is the cut
		# that matters: plan line 729, "A failed durable advance returns no token."
		return _failed(_armed_write_failure_code, "armed durable-write failure at ordinal %d" % write_count)
	_documents[relative_path] = text
	_leases.erase(relative_path)
	return {"ok": true, "hash": sha256_hex(text), "keep_backup": keep_backup}


func reconcile(relative_path: String, validator: Callable) -> Dictionary:
	_log(&"reconcile", relative_path)
	if not _documents.has(relative_path):
		_leases[relative_path] = {"absent": true}
		return {"ok": true, "exists": false}
	var text := str(_documents[relative_path])
	var validated: Variant = validator.call(text)
	if typeof(validated) != TYPE_DICTIONARY:
		return _failed(&"invalid_validator_result", "Validator must return a Dictionary")
	if not (validated as Dictionary).get("ok", false):
		return _failed(&"fake_stored_document_invalid",
			str((validated as Dictionary).get("message", "Stored document rejected")))
	var hash := sha256_hex(text)
	_leases[relative_path] = {"absent": false, "hash": hash}
	return {
		"ok": true,
		"exists": true,
		"value": (validated as Dictionary).get("value", {}),
		"hash": hash,
	}


func exists(relative_path: String) -> bool:
	_log(&"exists", relative_path)
	return _documents.has(relative_path)


func remove(relative_path: String) -> Dictionary:
	_log(&"remove", relative_path)
	_documents.erase(relative_path)
	_leases.erase(relative_path)
	return {"ok": true}


func describe_root() -> String:
	return ROOT_LABEL


# ---------------------------------------------------------------------------------------------
# Test-facing helpers
# ---------------------------------------------------------------------------------------------

## Arms the next `write_atomic()` to fail after validation but before the store mutates.
func fail_next_write(code: StringName = &"fake_durable_write_failed") -> void:
	_armed_write_failure_code = code
	_armed_write_failure_ordinal = write_count + 1


## Arms the Nth `write_atomic()` (1-based) to fail, for crash cuts at an exact ordinal.
func fail_write_at(ordinal: int, code: StringName = &"fake_durable_write_failed") -> void:
	_armed_write_failure_code = code
	_armed_write_failure_ordinal = ordinal


## Installs bytes directly, modelling a document already on disk at process start.
func seed(relative_path: String, text: String) -> void:
	_documents[relative_path] = text
	_leases.erase(relative_path)


## Detached copy of everything durably stored, for byte-equality checks across a simulated restart.
func snapshot() -> Dictionary:
	return _documents.duplicate(true)


## Drops every lease without touching stored bytes -- a process restart over the same disk.
func restart() -> void:
	_leases.clear()
	call_log.clear()
	write_count = 0


func calls_to(method: StringName) -> Array[Dictionary]:
	var matched: Array[Dictionary] = []
	for entry: Dictionary in call_log:
		if entry.get("method") == method:
			matched.append(entry)
	return matched


static func sha256_hex(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


# ---------------------------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------------------------

func _write_should_fail() -> bool:
	if _armed_write_failure_code == &"":
		return false
	if _armed_write_failure_ordinal != write_count:
		return false
	return true


func _log(method: StringName, relative_path: String) -> void:
	call_log.append({"method": method, "relative_path": relative_path})


func _failed(code: StringName, message: String) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"message": "FakeDesktopContinuationJournalStorage: " + message,
	}
