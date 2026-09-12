class_name JsonFileStorage
extends "res://scripts/infrastructure/storage/StorageAdapter.gd"

const FILE_OPS := preload("res://scripts/infrastructure/storage/FileOps.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const HASH_PATTERN := "^[0-9a-f]{64}$"

var _root_dir: String
var _file_ops: RefCounted
var _leases: Dictionary = {}
## Optional pre-write gate (dwm-634.1). The owner of this root may run one Callable before any
## durable mutation, so a save can first persist state that the saved bytes will reference. A
## refusal fails the write closed before any marker or candidate byte is written.
var _before_write: Callable = Callable()

func _init(root_dir: String, file_ops: RefCounted = null) -> void:
	_root_dir = root_dir.trim_suffix("/").trim_suffix("\\")
	_file_ops = file_ops if file_ops != null else FILE_OPS.new()

func configure_before_write(hook: Callable) -> Dictionary:
	if not hook.is_valid():
		return _failure(&"invalid_before_write_hook", "A valid Callable is required")
	if _before_write.is_valid() and _before_write != hook:
		return _failure(&"before_write_hook_already_configured", "One pre-write hook per storage root")
	_before_write = hook
	return {"ok": true}

func _run_before_write() -> Dictionary:
	if not _before_write.is_valid():
		return {"ok": true}
	var gate: Variant = _before_write.call()
	if gate is Dictionary and not (gate as Dictionary).get("ok", false):
		return _failure(&"before_write_refused", str((gate as Dictionary).get("code", "pre-write hook refused")))
	return {"ok": true}

func describe_root() -> String:
	return _root_dir

func exists(relative_path: String) -> bool:
	return _validate_relative_path(relative_path).get("ok", false) and _file_ops.call(&"exists", _path(relative_path))

## Unlike read_text, raw inspection does not reconcile, validate a save, or grant
## a lease. Invalid UTF-8 still has exact revision evidence but no text projection.
func inspect_revision(relative_path: String) -> Dictionary:
	var safe := _validate_relative_path(relative_path)
	if not safe.get("ok", false):
		return safe
	for artifact in [_marker_path(relative_path), _next_path(relative_path), _revision_prior_path(relative_path)]:
		if _file_ops.call(&"exists", artifact):
			return _failure(&"reconcile_required", "Pending transaction artifacts require recovery")
	var raw := _raw_artifact(_path(relative_path))
	if not raw.get("ok", false):
		return raw
	if raw["hash"] == null and _file_ops.call(&"exists", _backup_path(relative_path)):
		return _failure(&"reconcile_required", "An orphaned backup requires recovery")
	var text: Variant = null
	if raw["hash"] != null:
		var decoded := _decode_utf8(raw["bytes"])
		if decoded.get("ok", false):
			text = decoded["value"]
	return {"ok": true, "value": {"exists": raw["hash"] != null,
		"revision": raw["hash"] if raw["hash"] != null else "absent", "text": text}}

func write_atomic_if_revision(relative_path: String, text: String, validator: Callable, revision: String) -> Dictionary:
	var request := _validate_request(relative_path, validator)
	if not request.get("ok", false):
		return request
	var outgoing := _call_validator(validator, text)
	if not outgoing.get("ok", false) or typeof(outgoing.get("value")) != TYPE_DICTIONARY:
		return _failure(&"outgoing_validation_failed", "Outgoing document rejected")
	var bytes := text.to_utf8_buffer()
	if bytes.get_string_from_utf8() != text:
		return _failure(&"invalid_utf8", "Outgoing text is not stable UTF-8")
	var gate := _run_before_write()
	if not gate.get("ok", false):
		return gate
	var admitted := _admit_revision(relative_path, revision)
	if not admitted.get("ok", false):
		return admitted
	_leases.erase(relative_path)
	var marker := _revision_marker(relative_path, "write_revision", admitted,
		_file_ops.call(&"sha256", bytes))
	var step := _write_marker(relative_path, marker)
	if not step.get("ok", false):
		return _recover_revision_start(relative_path, validator, marker)
	step = _write_and_flush(_next_path(relative_path), bytes)
	if not step.get("ok", false):
		return _recover_revision_start(relative_path, validator, marker)
	return _promote_fresh_revision(relative_path, validator, marker, bytes)

## dwm-634.1: the writer just validated, wrote and flushed this candidate under the marker's
## outgoing hash, so the happy path promotes it with renames and removals plus one read-back of
## the promoted final, which is the artifact every later start will read. The artifacts
## and their order are exactly those v2 reconciliation expects, so any refused step falls back to
## _reconcile_revision over the same family instead of guessing.
func _promote_fresh_revision(relative_path: String, validator: Callable, marker: Dictionary,
		bytes: PackedByteArray) -> Dictionary:
	if marker["previous_hash"] != null:
		if not _file_ops.call(&"exists", _path(relative_path)) or _file_ops.call(&"exists", _revision_prior_path(relative_path)):
			return _reconcile_revision(relative_path, validator, marker)
		var preserved: Dictionary = _file_ops.call(&"rename_path", _path(relative_path), _revision_prior_path(relative_path))
		if not preserved.get("ok", false):
			return _reconcile_revision(relative_path, validator, marker)
	var promoted: Dictionary = _file_ops.call(&"rename_path", _next_path(relative_path), _path(relative_path))
	if not promoted.get("ok", false):
		return _reconcile_revision(relative_path, validator, marker)
	var final := _classify_document(_path(relative_path), validator)
	if final["state"] != &"valid" or final["hash"] != str(marker["outgoing_hash"]) or final["bytes"] != bytes:
		return _reconcile_revision(relative_path, validator, marker)
	for stale_path in [_revision_prior_path(relative_path), _backup_path(relative_path)]:
		var removed: Dictionary = _file_ops.call(&"remove_path", stale_path)
		if not removed.get("ok", false):
			return _reconcile_revision(relative_path, validator, marker)
	var cleaned: Dictionary = _file_ops.call(&"remove_path", _marker_path(relative_path))
	if not cleaned.get("ok", false):
		return _reconcile_revision(relative_path, validator, marker)
	_set_lease(relative_path, final)
	return {"ok": true, "exists": true, "value": (final["value"] as Dictionary).duplicate(true), "hash": str(marker["outgoing_hash"])}

func remove_if_revision(relative_path: String, revision: String) -> Dictionary:
	var admitted := _admit_revision(relative_path, revision)
	if not admitted.get("ok", false):
		return admitted
	_leases.erase(relative_path)
	if admitted["previous_hash"] == null:
		return {"ok": true, "exists": false}
	var marker := _revision_marker(relative_path, "delete_revision", admitted, null)
	var step := _write_marker(relative_path, marker)
	if not step.get("ok", false):
		return _recover_revision_start(relative_path, Callable(), marker)
	return _reconcile_revision(relative_path, Callable(), marker)

func _admit_revision(relative_path: String, revision: String) -> Dictionary:
	if revision != "absent" and not _is_hash(revision):
		return _failure(&"invalid_revision", "Expected an exact raw hash or absent")
	var inspected := inspect_revision(relative_path)
	if not inspected.get("ok", false):
		return inspected
	if inspected["value"]["revision"] != revision:
		return _failure(&"revision_changed", "The confirmed record has changed")
	var backup := _raw_artifact(_backup_path(relative_path))
	if not backup.get("ok", false):
		return backup
	return {"ok": true, "previous_hash": null if revision == "absent" else revision,
		"backup_hash": backup["hash"]}

func _revision_marker(relative_path: String, operation: String, admitted: Dictionary, outgoing: Variant) -> Dictionary:
	return {"schema_version": 2, "relative_path": relative_path, "operation": operation,
		"stage": "prepared" if operation == "write_revision" else "delete_marked",
		"previous_hash": admitted["previous_hash"], "backup_hash": admitted["backup_hash"],
		"outgoing_hash": outgoing}

func _raw_artifact(path: String) -> Dictionary:
	if not _file_ops.call(&"exists", path):
		return {"ok": true, "hash": null, "bytes": PackedByteArray()}
	var read: Dictionary = _file_ops.call(&"read_bytes", path)
	if not read.get("ok", false):
		return read
	# HashingContext.update rejects an empty buffer; an empty file still has an
	# exact SHA-256 revision and must remain distinguishable from absent.
	var raw_hash: String = "".sha256_text() if read["value"].is_empty() else _file_ops.call(&"sha256", read["value"])
	return {"ok": true, "hash": raw_hash, "bytes": read["value"]}

func _revision_family(relative_path: String, marker: Dictionary, require_marker: bool = true) -> Dictionary:
	if require_marker:
		var durable := _classify_marker(_marker_path(relative_path), relative_path)
		if durable["state"] != &"valid" or durable["value"] != marker:
			return _fatal(&"indeterminate_commit", "Durable transaction intent changed")
	var family := {}
	for key in ["final", "next", "prior", "backup"]:
		var paths := {"final": _path(relative_path), "next": _next_path(relative_path),
			"prior": _revision_prior_path(relative_path), "backup": _backup_path(relative_path)}
		var raw := _raw_artifact(paths[key])
		if not raw.get("ok", false):
			return _fatal(&"indeterminate_commit", "Transaction artifact could not be inspected")
		family[key] = raw
	var prior: Variant = marker["previous_hash"]
	var outgoing: Variant = marker["outgoing_hash"]
	if family["final"]["hash"] not in [null, prior, outgoing] \
			or family["backup"]["hash"] not in [null, marker["backup_hash"]] \
			or family["next"]["hash"] not in [null, outgoing] \
			or family["prior"]["hash"] not in [null, prior]:
		return _fatal(&"indeterminate_commit", "Unbound transaction bytes were preserved")
	if marker["operation"] == "delete_revision" and (family["next"]["hash"] != null or family["prior"]["hash"] != null):
		return _fatal(&"indeterminate_commit", "Delete contains unowned candidate artifacts")
	family["ok"] = true
	return family

## V2 has one immutable durable intent. Hash-bound artifacts, rather than marker
## rewrites, identify interrupted stages. Opaque prior bytes are only rollback
## custody and are never classified as a playable document or granted a lease.
func _reconcile_revision(relative_path: String, validator: Callable, marker: Dictionary) -> Dictionary:
	var family := _revision_family(relative_path, marker)
	if not family.get("ok", false):
		return family
	if marker["operation"] == "delete_revision":
		for path in [_path(relative_path), _backup_path(relative_path), _marker_path(relative_path)]:
			family = _revision_family(relative_path, marker)
			if not family.get("ok", false):
				return family
			if path == _marker_path(relative_path) and (family["final"]["hash"] != null or family["backup"]["hash"] != null):
				return _fatal(&"indeterminate_commit", "Delete artifacts reappeared before completion")
			var removed: Dictionary = _file_ops.call(&"remove_path", path)
			if not removed.get("ok", false):
				return _fatal(&"indeterminate_commit", "Bound delete requires reconciliation")
		_set_absent_lease(relative_path)
		return {"ok": true, "exists": false}
	var outgoing: String = marker["outgoing_hash"]
	if family["final"]["hash"] == outgoing:
		return _finish_revision_write(relative_path, validator, marker)
	if family["next"]["hash"] == outgoing:
		var candidate := _classify_document(_next_path(relative_path), validator)
		if candidate["state"] != &"valid" or candidate["hash"] != outgoing:
			return _fatal(&"indeterminate_commit", "Outgoing candidate no longer validates")
		family = _revision_family(relative_path, marker)
		if not family.get("ok", false):
			return family
		if marker["previous_hash"] != null and family["final"]["hash"] == null and family["prior"]["hash"] == null:
			return _fatal(&"indeterminate_commit", "Previous transaction evidence is missing")
		if family["final"]["hash"] != null:
			if family["prior"]["hash"] != null:
				return _fatal(&"indeterminate_commit", "Duplicated prior artifacts require recovery")
			var preserved: Dictionary = _file_ops.call(&"rename_path", _path(relative_path), _revision_prior_path(relative_path))
			if not preserved.get("ok", false):
				return _fatal(&"indeterminate_commit", "Prior preservation requires reconciliation")
		# Recheck exact ownership after preservation, before replacing the final.
		family = _revision_family(relative_path, marker)
		if not family.get("ok", false):
			return family
		if family["final"]["hash"] != null or family["next"]["hash"] != outgoing:
			return _fatal(&"indeterminate_commit", "Artifacts changed before promotion")
		var promoted: Dictionary = _file_ops.call(&"rename_path", _next_path(relative_path), _path(relative_path))
		if not promoted.get("ok", false):
			return _fatal(&"indeterminate_commit", "Promotion requires reconciliation")
		return _finish_revision_write(relative_path, validator, marker)
	# No outgoing candidate survived: restore only the exact bound prior, never a
	# schema-valid but foreign backup. A restored opaque prior creates no lease.
	if family["final"]["hash"] == null and family["prior"]["hash"] != null:
		var restored: Dictionary = _file_ops.call(&"rename_path", _revision_prior_path(relative_path), _path(relative_path))
		if not restored.get("ok", false):
			return _fatal(&"indeterminate_commit", "Prior rollback requires reconciliation")
		family = _revision_family(relative_path, marker)
		if not family.get("ok", false):
			return family
	if family["final"]["hash"] != marker["previous_hash"] or family["prior"]["hash"] != null:
		return _fatal(&"indeterminate_commit", "No exact previous winner remains")
	family = _revision_family(relative_path, marker)
	if not family.get("ok", false):
		return family
	var cleanup: Dictionary = _file_ops.call(&"remove_path", _marker_path(relative_path))
	if not cleanup.get("ok", false):
		return _fatal(&"indeterminate_commit", "Rollback cleanup requires reconciliation")
	return _failure(&"write_not_committed", "Exact previous bytes remain unchanged")

func _finish_revision_write(relative_path: String, validator: Callable, marker: Dictionary) -> Dictionary:
	var family := _revision_family(relative_path, marker)
	if not family.get("ok", false):
		return family
	var final := _classify_document(_path(relative_path), validator)
	if final["state"] != &"valid" or final["hash"] != marker["outgoing_hash"]:
		return _fatal(&"indeterminate_commit", "Final outgoing document did not validate")
	for path in [_next_path(relative_path), _revision_prior_path(relative_path), _backup_path(relative_path)]:
		family = _revision_family(relative_path, marker)
		if not family.get("ok", false):
			return family
		var removed: Dictionary = _file_ops.call(&"remove_path", path)
		if not removed.get("ok", false):
			return _fatal(&"indeterminate_commit", "Committed cleanup requires reconciliation")
	final = _classify_document(_path(relative_path), validator)
	if final["state"] != &"valid" or final["hash"] != marker["outgoing_hash"]:
		return _fatal(&"indeterminate_commit", "Final changed before marker cleanup")
	family = _revision_family(relative_path, marker)
	if not family.get("ok", false):
		return family
	if family["final"]["hash"] != marker["outgoing_hash"] or family["next"]["hash"] != null or family["prior"]["hash"] != null or family["backup"]["hash"] != null:
		return _fatal(&"indeterminate_commit", "Committed family changed before marker cleanup")
	var cleaned: Dictionary = _file_ops.call(&"remove_path", _marker_path(relative_path))
	if not cleaned.get("ok", false):
		return _fatal(&"indeterminate_commit", "Marker cleanup requires reconciliation")
	_set_lease(relative_path, final)
	return {"ok": true, "exists": true, "value": final["value"].duplicate(true), "hash": final["hash"]}

func _recover_revision_start(relative_path: String, validator: Callable, expected: Dictionary) -> Dictionary:
	var marker := _classify_marker(_marker_path(relative_path), relative_path)
	if marker["state"] == &"valid" and marker["value"] == expected:
		return _reconcile_revision(relative_path, validator, expected)
	if marker["state"] != &"absent":
		return _fatal(&"indeterminate_commit", "Revision marker did not become provable")
	var family := _revision_family(relative_path, expected, false)
	if not family.get("ok", false):
		return family
	if family["final"]["hash"] != expected["previous_hash"] or family["next"]["hash"] != null or family["prior"]["hash"] != null:
		return _fatal(&"indeterminate_commit", "Failed marker left uncertain transaction evidence")
	return _failure(&"write_not_committed", "Revision operation was not admitted durably")

func read_text(relative_path: String) -> Dictionary:
	var path_result := _validate_relative_path(relative_path)
	if not path_result.get("ok", false):
		return path_result
	if not _leases.has(relative_path):
		return _failure(&"reconcile_required", "A fresh reconciliation lease is required")
	var lease: Dictionary = _leases[relative_path]
	var final_path := _path(relative_path)
	if lease.get("absent", false):
		if _file_ops.call(&"exists", final_path):
			_leases.erase(relative_path)
			return _failure(&"reconcile_required", "Final artifact changed after reconciliation")
		return _failure(&"not_found", relative_path)
	var read_result: Dictionary = _file_ops.call(&"read_bytes", final_path)
	if not read_result.get("ok", false):
		_leases.erase(relative_path)
		return _failure(&"reconcile_required", "Final artifact changed after reconciliation")
	var bytes: PackedByteArray = read_result["value"]
	if _file_ops.call(&"sha256", bytes) != lease.get("hash", ""):
		_leases.erase(relative_path)
		return _failure(&"reconcile_required", "Final artifact changed after reconciliation")
	var decoded := _decode_utf8(bytes)
	if not decoded.get("ok", false):
		_leases.erase(relative_path)
		return _failure(&"reconcile_required", "Final artifact is no longer valid UTF-8")
	return {"ok": true, "value": decoded["value"]}

func reconcile(relative_path: String, validator: Callable) -> Dictionary:
	_leases.erase(relative_path)
	var path_result := _validate_request(relative_path, validator)
	if not path_result.get("ok", false):
		return path_result
	var revision_marker := _classify_marker(_marker_path(relative_path), relative_path)
	if revision_marker["state"] == &"invalid":
		return _fatal(&"indeterminate_transaction", "Transaction marker could not be proved; artifacts were preserved")
	if revision_marker["state"] == &"valid" and revision_marker["value"].get("schema_version") == 2:
		return _reconcile_revision(relative_path, validator, revision_marker["value"])
	if _file_ops.call(&"exists", _revision_prior_path(relative_path)):
		return _fatal(&"indeterminate_transaction", "Unowned opaque prior was preserved")
	var family := _classify_family(relative_path, validator)
	var marker: Dictionary = family["marker"]
	if marker["state"] == &"invalid":
		return _fatal(&"indeterminate_transaction", "Transaction marker is corrupt; artifacts were preserved")
	if marker["state"] == &"valid":
		var document: Dictionary = marker["value"]
		if document["operation"] == "delete":
			return _finish_delete(relative_path, validator)
		return _reconcile_write(relative_path, validator, family, document)
	var final: Dictionary = family["final"]
	var next: Dictionary = family["next"]
	var backup: Dictionary = family["backup"]
	if final["state"] == &"valid":
		if next["state"] != &"absent":
			var remove_next: Dictionary = _file_ops.call(&"remove_path", _next_path(relative_path))
			if not remove_next.get("ok", false):
				return remove_next
		_set_lease(relative_path, final)
		return {"ok": true, "exists": true, "value": (final["value"] as Dictionary).duplicate(true), "hash": final["hash"]}
	if final["state"] == &"absent" and next["state"] == &"absent" and backup["state"] == &"absent":
		_set_absent_lease(relative_path)
		return {"ok": true, "exists": false}
	return _fatal(&"indeterminate_transaction", "Unowned or invalid transaction artifacts were preserved")

func write_atomic(relative_path: String, text: String, validator: Callable, keep_backup: bool = true) -> Dictionary:
	_leases.erase(relative_path)
	var request := _validate_request(relative_path, validator)
	if not request.get("ok", false):
		return request
	var outgoing_validation := _call_validator(validator, text)
	if not outgoing_validation.get("ok", false):
		return _failure(&"outgoing_validation_failed", str(outgoing_validation.get("message", "Outgoing document rejected")))
	var outgoing_bytes := text.to_utf8_buffer()
	if outgoing_bytes.get_string_from_utf8() != text:
		return _failure(&"invalid_utf8", "Outgoing text is not stable UTF-8")
	var gate := _run_before_write()
	if not gate.get("ok", false):
		return gate
	var outgoing_hash: String = _file_ops.call(&"sha256", outgoing_bytes)
	var existing := reconcile(relative_path, validator)
	if not existing.get("ok", false):
		return existing
	var previous_hash: Variant = existing.get("hash") if existing.get("exists", false) else null
	var intent := {
		"operation": "write", "relative_path": relative_path,
		"outgoing_hash": outgoing_hash, "previous_hash": previous_hash,
		"previous_absent": not existing.get("exists", false), "keep_backup": keep_backup,
	}
	var marker := _make_write_marker(relative_path, "prepared", outgoing_hash, previous_hash, null, null, keep_backup)
	var step := _write_marker(relative_path, marker)
	if not step.get("ok", false):
		return _recover_known_write(intent, validator)
	step = _write_and_flush(_next_path(relative_path), outgoing_bytes)
	if not step.get("ok", false):
		return _recover_known_write(intent, validator)
	# dwm-634.1: the candidate was validated before it was written and flushed under the hash the
	# marker carries; recovery re-reads it on any interruption, so the happy path does not.
	marker = _make_write_marker(relative_path, "next_validated", outgoing_hash, previous_hash, outgoing_hash, null, keep_backup)
	step = _write_marker(relative_path, marker)
	if not step.get("ok", false):
		return _recover_known_write(intent, validator)
	var backup_hash: Variant = null
	if previous_hash != null:
		if _file_ops.call(&"exists", _backup_path(relative_path)):
			step = _file_ops.call(&"remove_path", _backup_path(relative_path))
			if not step.get("ok", false):
				return _recover_known_write(intent, validator)
		step = _file_ops.call(&"rename_path", _path(relative_path), _backup_path(relative_path))
		if not step.get("ok", false):
			return _recover_known_write(intent, validator)
		backup_hash = previous_hash
	marker = _make_write_marker(relative_path, "backup_preserved", outgoing_hash, previous_hash, outgoing_hash, backup_hash, keep_backup)
	step = _write_marker(relative_path, marker)
	if not step.get("ok", false):
		return _recover_known_write(intent, validator)
	step = _file_ops.call(&"rename_path", _next_path(relative_path), _path(relative_path))
	if not step.get("ok", false):
		return _recover_known_write(intent, validator)
	# The one read-back that stays: the promoted final is what every later start will read, so
	# it must re-read to the outgoing hash and validate before the transaction is declared won.
	var verified_final := _classify_document(_path(relative_path), validator)
	if verified_final["state"] != &"valid" or verified_final["hash"] != outgoing_hash or verified_final["bytes"] != outgoing_bytes:
		return _recover_known_write(intent, validator)
	marker = _make_write_marker(relative_path, "final_promoted", outgoing_hash, previous_hash, outgoing_hash, backup_hash, keep_backup)
	step = _write_marker(relative_path, marker)
	if not step.get("ok", false):
		return _recover_known_write(intent, validator)
	if _file_ops.call(&"exists", _next_path(relative_path)):
		step = _file_ops.call(&"remove_path", _next_path(relative_path))
		if not step.get("ok", false):
			return _recover_known_write(intent, validator)
	if not keep_backup and _file_ops.call(&"exists", _backup_path(relative_path)):
		step = _file_ops.call(&"remove_path", _backup_path(relative_path))
		if not step.get("ok", false):
			return _recover_known_write(intent, validator)
	step = _file_ops.call(&"remove_path", _marker_path(relative_path))
	if not step.get("ok", false):
		return _recover_known_write(intent, validator)
	_set_lease(relative_path, verified_final)
	return {"ok": true, "exists": true, "value": (verified_final["value"] as Dictionary).duplicate(true), "hash": outgoing_hash}

func remove(relative_path: String) -> Dictionary:
	var path_result := _validate_relative_path(relative_path)
	if not path_result.get("ok", false):
		return path_result
	if not _leases.has(relative_path):
		return _failure(&"reconcile_required", "A fresh reconciliation lease is required")
	var lease: Dictionary = _leases[relative_path]
	var final_path := _path(relative_path)
	if lease.get("absent", false):
		if _file_ops.call(&"exists", final_path):
			_leases.erase(relative_path)
			return _failure(&"reconcile_required", "Final artifact changed after reconciliation")
		return {"ok": true, "exists": false}
	var current: Dictionary = _file_ops.call(&"read_bytes", final_path)
	if not current.get("ok", false) or _file_ops.call(&"sha256", current["value"]) != lease.get("hash", ""):
		_leases.erase(relative_path)
		return _failure(&"reconcile_required", "Final artifact changed after reconciliation")
	var marker := {
		"operation": "delete", "previous_hash": lease["hash"],
		"relative_path": relative_path, "schema_version": 1, "stage": "delete_marked",
	}
	var marker_result := _write_marker(relative_path, marker)
	if not marker_result.get("ok", false):
		return _failure(&"write_not_committed", "Delete marker did not become durable")
	return _finish_delete_without_validator(relative_path)

func _reconcile_write(relative_path: String, validator: Callable, family: Dictionary, marker: Dictionary) -> Dictionary:
	var final: Dictionary = family["final"]
	var next: Dictionary = family["next"]
	var backup: Dictionary = family["backup"]
	var outgoing: String = marker["outgoing_hash"]
	var previous: Variant = marker["previous_hash"]
	var stage: String = marker["stage"]
	if final["state"] == &"valid" and final["hash"] == outgoing:
		return _finish_new_winner(relative_path, validator, marker, final)
	if stage in ["prepared", "next_validated", "backup_preserved"] and next["state"] == &"valid" and next["hash"] == outgoing:
		if stage == "backup_preserved" and not _backup_evidence_matches(marker, backup):
			return _fatal(&"indeterminate_commit", "Backup evidence does not match marker")
		var promotion: Dictionary = _file_ops.call(&"rename_path", _next_path(relative_path), _path(relative_path))
		if not promotion.get("ok", false):
			return _fatal(&"indeterminate_commit", "Outgoing candidate could not be promoted")
		var promoted := _classify_document(_path(relative_path), validator)
		if promoted["state"] != &"valid" or promoted["hash"] != outgoing:
			return _fatal(&"indeterminate_commit", "Promoted final does not match outgoing hash")
		return _finish_new_winner(relative_path, validator, marker, promoted)
	if stage == "prepared" and next["state"] == &"absent":
		if previous == null and final["state"] == &"absent":
			_cleanup_owned(relative_path, false)
			_set_absent_lease(relative_path)
			return _failure(&"write_not_committed", "First write did not commit", false)
		if previous != null:
			var winner := final if final["state"] == &"valid" and final["hash"] == previous else backup
			if winner["state"] == &"valid" and winner["hash"] == previous:
				if final["state"] != &"valid" or final["hash"] != previous:
					var restore: Dictionary = _file_ops.call(&"rename_path", _backup_path(relative_path), _path(relative_path))
					if not restore.get("ok", false):
						return _fatal(&"indeterminate_commit", "Previous winner could not be restored")
					winner = _classify_document(_path(relative_path), validator)
				_cleanup_owned(relative_path, bool(marker["keep_backup"]))
				_set_lease(relative_path, winner)
				return _failure(&"write_not_committed", "Previous bytes remain the winner", false)
	return _fatal(&"indeterminate_commit", "Durable transaction evidence cannot prove one winner")

func _finish_new_winner(relative_path: String, validator: Callable, marker: Dictionary, final: Dictionary) -> Dictionary:
	if _file_ops.call(&"exists", _next_path(relative_path)):
		var remove_next: Dictionary = _file_ops.call(&"remove_path", _next_path(relative_path))
		if not remove_next.get("ok", false):
			return _fatal(&"indeterminate_commit", "Committed final exists but candidate cleanup failed")
	if not marker["keep_backup"] and _file_ops.call(&"exists", _backup_path(relative_path)):
		var remove_backup: Dictionary = _file_ops.call(&"remove_path", _backup_path(relative_path))
		if not remove_backup.get("ok", false):
			return _fatal(&"indeterminate_commit", "Committed final exists but backup cleanup failed")
	var remove_marker: Dictionary = _file_ops.call(&"remove_path", _marker_path(relative_path))
	if not remove_marker.get("ok", false):
		return _fatal(&"indeterminate_commit", "Committed final exists but marker cleanup failed")
	var verified := _classify_document(_path(relative_path), validator)
	if verified["state"] != &"valid" or verified["hash"] != marker["outgoing_hash"]:
		return _fatal(&"indeterminate_commit", "Final changed during transaction cleanup")
	_set_lease(relative_path, verified)
	return {"ok": true, "exists": true, "value": (verified["value"] as Dictionary).duplicate(true), "hash": verified["hash"]}

func _recover_known_write(intent: Dictionary, validator: Callable) -> Dictionary:
	_leases.erase(intent["relative_path"])
	var relative_path: String = intent["relative_path"]
	var final := _classify_document(_path(relative_path), validator)
	if final["state"] == &"valid" and final["hash"] == intent["outgoing_hash"]:
		var cleanup_marker: Dictionary = _file_ops.call(&"remove_path", _marker_path(relative_path))
		if not cleanup_marker.get("ok", false):
			return _fatal(&"indeterminate_commit", "New bytes won but transaction cleanup failed")
		if _file_ops.call(&"exists", _next_path(relative_path)):
			_file_ops.call(&"remove_path", _next_path(relative_path))
		_set_lease(relative_path, final)
		return {"ok": true, "exists": true, "value": (final["value"] as Dictionary).duplicate(true), "hash": final["hash"]}
	var next := _classify_document(_next_path(relative_path), validator)
	if next["state"] == &"valid" and next["hash"] == intent["outgoing_hash"]:
		var promote: Dictionary = _file_ops.call(&"rename_path", _next_path(relative_path), _path(relative_path))
		if promote.get("ok", false):
			final = _classify_document(_path(relative_path), validator)
			if final["state"] == &"valid" and final["hash"] == intent["outgoing_hash"]:
				_file_ops.call(&"remove_path", _marker_path(relative_path))
				_set_lease(relative_path, final)
				return {"ok": true, "exists": true, "value": (final["value"] as Dictionary).duplicate(true), "hash": final["hash"]}
	var previous: Variant = intent["previous_hash"]
	if intent["previous_absent"] and final["state"] == &"absent":
		_file_ops.call(&"remove_path", _next_path(relative_path))
		_file_ops.call(&"remove_path", _marker_path(relative_path))
		_set_absent_lease(relative_path)
		return _failure(&"write_not_committed", "Outgoing bytes did not win", false)
	var backup := _classify_document(_backup_path(relative_path), validator)
	if previous != null and ((final["state"] == &"valid" and final["hash"] == previous) or (backup["state"] == &"valid" and backup["hash"] == previous)):
		if final["state"] != &"valid" or final["hash"] != previous:
			var restore: Dictionary = _file_ops.call(&"rename_path", _backup_path(relative_path), _path(relative_path))
			if not restore.get("ok", false):
				return _fatal(&"indeterminate_commit", "Previous bytes could not be restored")
			final = _classify_document(_path(relative_path), validator)
		_file_ops.call(&"remove_path", _next_path(relative_path))
		_file_ops.call(&"remove_path", _marker_path(relative_path))
		_set_lease(relative_path, final)
		return _failure(&"write_not_committed", "Previous bytes remain the winner", false)
	return _fatal(&"indeterminate_commit", "Injected failure left no provable winner")

func _finish_delete(relative_path: String, _validator: Callable) -> Dictionary:
	return _finish_delete_without_validator(relative_path)

func _finish_delete_without_validator(relative_path: String) -> Dictionary:
	for artifact_path in [_path(relative_path), _next_path(relative_path), _backup_path(relative_path)]:
		var removal: Dictionary = _file_ops.call(&"remove_path", artifact_path)
		if not removal.get("ok", false):
			return _fatal(&"indeterminate_commit", "Durable delete marker remains; reconciliation must retry")
	var marker_removal: Dictionary = _file_ops.call(&"remove_path", _marker_path(relative_path))
	if not marker_removal.get("ok", false):
		return _fatal(&"indeterminate_commit", "Delete won but marker cleanup must retry")
	_set_absent_lease(relative_path)
	return {"ok": true, "exists": false}

func _classify_family(relative_path: String, validator: Callable) -> Dictionary:
	return {
		"final": _classify_document(_path(relative_path), validator),
		"next": _classify_document(_next_path(relative_path), validator),
		"backup": _classify_document(_backup_path(relative_path), validator),
		"marker": _classify_marker(_marker_path(relative_path), relative_path),
	}

func _classify_document(path: String, validator: Callable) -> Dictionary:
	if not _file_ops.call(&"exists", path):
		return {"state": &"absent"}
	var read_result: Dictionary = _file_ops.call(&"read_bytes", path)
	if not read_result.get("ok", false):
		return {"state": &"invalid", "reason": read_result}
	var bytes: PackedByteArray = read_result["value"]
	var decoded := _decode_utf8(bytes)
	if not decoded.get("ok", false):
		return {"state": &"invalid", "reason": decoded, "bytes": bytes}
	var validation := _call_validator(validator, decoded["value"])
	if not validation.get("ok", false) or typeof(validation.get("value")) != TYPE_DICTIONARY:
		return {"state": &"invalid", "reason": validation, "bytes": bytes}
	return {
		"state": &"valid", "bytes": bytes.duplicate(), "text": decoded["value"],
		"value": (validation["value"] as Dictionary).duplicate(true), "hash": _file_ops.call(&"sha256", bytes),
	}

func _classify_marker(path: String, relative_path: String) -> Dictionary:
	if not _file_ops.call(&"exists", path):
		return {"state": &"absent"}
	var read_result: Dictionary = _file_ops.call(&"read_bytes", path)
	if not read_result.get("ok", false):
		return {"state": &"invalid", "reason": read_result}
	var decoded := _decode_utf8(read_result["value"])
	if not decoded.get("ok", false):
		return {"state": &"invalid", "reason": decoded}
	var parsed: Dictionary = STRICT_JSON.parse_object(decoded["value"])
	if not parsed.get("ok", false):
		return {"state": &"invalid", "reason": parsed}
	var validation := _validate_marker(parsed["value"], relative_path)
	if not validation.get("ok", false):
		return {"state": &"invalid", "reason": validation}
	return {"state": &"valid", "value": (parsed["value"] as Dictionary).duplicate(true)}

func _validate_marker(marker: Dictionary, relative_path: String) -> Dictionary:
	if marker.get("schema_version") == 2:
		if not _has_exact_keys(marker, ["schema_version", "relative_path", "operation", "stage", "previous_hash", "backup_hash", "outgoing_hash"]) or marker.get("relative_path") != relative_path:
			return _failure(&"invalid_marker", "Revision marker keys or path differ")
		for nullable_hash in [marker["previous_hash"], marker["backup_hash"]]:
			if nullable_hash != null and not _is_hash(nullable_hash):
				return _failure(&"invalid_marker", "Revision prior hash is invalid")
		if marker["previous_hash"] == null and marker["backup_hash"] != null:
			return _failure(&"invalid_marker", "Absent prior cannot own an orphan backup")
		if marker["operation"] == "write_revision" and marker["stage"] == "prepared" and _is_hash(marker["outgoing_hash"]):
			return {"ok": true}
		if marker["operation"] == "delete_revision" and marker["stage"] == "delete_marked" and _is_hash(marker["previous_hash"]) and marker["outgoing_hash"] == null:
			return {"ok": true}
		return _failure(&"invalid_marker", "Revision operation values are invalid")
	if marker.get("schema_version") != 1 or marker.get("relative_path") != relative_path:
		return _failure(&"invalid_marker", "Marker version or path does not match")
	var operation: Variant = marker.get("operation")
	if operation == "delete":
		if not _has_exact_keys(marker, ["operation", "previous_hash", "relative_path", "schema_version", "stage"]):
			return _failure(&"invalid_marker", "Delete marker keys do not match the closed schema")
		if marker.get("stage") != "delete_marked" or not _is_hash(marker.get("previous_hash")):
			return _failure(&"invalid_marker", "Delete marker values are invalid")
		return {"ok": true}
	if operation != "write" or not _has_exact_keys(marker, ["backup_hash", "keep_backup", "next_hash", "operation", "outgoing_hash", "previous_hash", "relative_path", "schema_version", "stage"]):
		return _failure(&"invalid_marker", "Write marker keys do not match the closed schema")
	if typeof(marker.get("keep_backup")) != TYPE_BOOL or not _is_hash(marker.get("outgoing_hash")):
		return _failure(&"invalid_marker", "Write marker values are invalid")
	for nullable_hash in [marker.get("previous_hash"), marker.get("next_hash"), marker.get("backup_hash")]:
		if nullable_hash != null and not _is_hash(nullable_hash):
			return _failure(&"invalid_marker", "Marker hash is invalid")
	var stage: Variant = marker.get("stage")
	if stage not in ["prepared", "next_validated", "backup_preserved", "final_promoted"]:
		return _failure(&"invalid_marker", "Write marker stage is invalid")
	if stage == "prepared" and (marker["next_hash"] != null or marker["backup_hash"] != null):
		return _failure(&"invalid_marker", "Prepared marker contains future evidence")
	if stage != "prepared" and marker["next_hash"] != marker["outgoing_hash"]:
		return _failure(&"invalid_marker", "Validated candidate hash is missing")
	if stage in ["backup_preserved", "final_promoted"] and marker["backup_hash"] != marker["previous_hash"]:
		return _failure(&"invalid_marker", "Backup hash does not match previous hash")
	return {"ok": true}

func _write_marker(relative_path: String, marker: Dictionary) -> Dictionary:
	var emitted: Dictionary = CANONICAL_WRITER.stringify(marker)
	if not emitted.get("ok", false):
		return emitted
	# dwm-634.1: a flushed marker is trusted as written; every recovery path re-reads and
	# validates the marker it finds, so a corrupt marker still fails closed on the next reconcile.
	return _write_and_flush(_marker_path(relative_path), (emitted["value"] as String).to_utf8_buffer())

func _write_and_flush(path: String, bytes: PackedByteArray) -> Dictionary:
	var write_result: Dictionary = _file_ops.call(&"write_bytes", path, bytes)
	if not write_result.get("ok", false):
		return write_result
	return _file_ops.call(&"flush_path", path)

func _make_write_marker(relative_path: String, stage: String, outgoing_hash: String, previous_hash: Variant, next_hash: Variant, backup_hash: Variant, keep_backup: bool) -> Dictionary:
	return {
		"backup_hash": backup_hash, "keep_backup": keep_backup, "next_hash": next_hash,
		"operation": "write", "outgoing_hash": outgoing_hash, "previous_hash": previous_hash,
		"relative_path": relative_path, "schema_version": 1, "stage": stage,
	}

func _cleanup_owned(relative_path: String, keep_backup: bool) -> void:
	_file_ops.call(&"remove_path", _next_path(relative_path))
	_file_ops.call(&"remove_path", _marker_path(relative_path))
	if not keep_backup:
		_file_ops.call(&"remove_path", _backup_path(relative_path))

func _backup_evidence_matches(marker: Dictionary, backup: Dictionary) -> bool:
	if marker["previous_hash"] == null:
		return marker["backup_hash"] == null and backup["state"] == &"absent"
	return backup["state"] == &"valid" and backup["hash"] == marker["previous_hash"] and marker["backup_hash"] == marker["previous_hash"]

func _call_validator(validator: Callable, text: String) -> Dictionary:
	var result: Variant = validator.call(text)
	if typeof(result) != TYPE_DICTIONARY:
		return _failure(&"invalid_validator_result", "Validator must return a Dictionary")
	return (result as Dictionary).duplicate(true)

func _decode_utf8(bytes: PackedByteArray) -> Dictionary:
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return _failure(&"invalid_utf8", "Artifact is not canonical UTF-8")
	return {"ok": true, "value": text}

func _validate_request(relative_path: String, validator: Callable) -> Dictionary:
	var path_result := _validate_relative_path(relative_path)
	if not path_result.get("ok", false):
		return path_result
	if not validator.is_valid():
		return _failure(&"invalid_validator", "A bound validator is required")
	return {"ok": true}

func _validate_relative_path(relative_path: String) -> Dictionary:
	if relative_path.is_empty() or relative_path.is_absolute_path() or ":" in relative_path or "\\" in relative_path or "\u0000" in relative_path:
		return _failure(&"invalid_relative_path", "Storage path must be a safe relative path")
	var parts := relative_path.split("/", true)
	if parts.is_empty() or "" in parts or "." in parts or ".." in parts or relative_path.simplify_path() != relative_path:
		return _failure(&"invalid_relative_path", "Storage path contains an unsafe segment")
	var full := _path(relative_path).simplify_path()
	var root := _root_dir.simplify_path().trim_suffix("/")
	if not full.begins_with(root + "/"):
		return _failure(&"path_escape", "Storage path escapes its constructor root")
	return {"ok": true}

func _path(relative_path: String) -> String:
	return _root_dir.path_join(relative_path)

func _next_path(relative_path: String) -> String:
	return _path(relative_path) + ".next"

func _marker_path(relative_path: String) -> String:
	return _path(relative_path) + ".txn.json"

func _backup_path(relative_path: String) -> String:
	return _path(relative_path) + ".bak"

func _revision_prior_path(relative_path: String) -> String:
	return _path(relative_path) + ".revision-prior"

func _set_lease(relative_path: String, artifact: Dictionary) -> void:
	_leases[relative_path] = {"absent": false, "hash": artifact["hash"]}

func _set_absent_lease(relative_path: String) -> void:
	_leases[relative_path] = {"absent": true}

func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true

func _is_hash(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or (value as String).length() != 64:
		return false
	for codepoint in (value as String).to_ascii_buffer():
		if not (codepoint >= 0x30 and codepoint <= 0x39) and not (codepoint >= 0x61 and codepoint <= 0x66):
			return false
	return true

func _failure(code: StringName, message: String, fatal: bool = false) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "fatal": fatal}

func _fatal(code: StringName, message: String) -> Dictionary:
	return _failure(code, message, true)
