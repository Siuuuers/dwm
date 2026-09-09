class_name SaveManagerCheckpointPort
extends RefCounted

## Production checkpoint port bridging DayResolutionCoordinator to
## SaveManager's CheckpointJournal and isolated storage
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 6).

const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE_DOCUMENT_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")
const DESKTOP_CONSEQUENCE_STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const VIEW_STATE := preload("res://scripts/domain/schedule/ScheduleViewState.gd")

## Consequence stage checkpoints are transient same-process retry state. Source-action and completed
## post-result Autosaves remain the cross-process recovery boundaries; legacy sidecars are never read,
## reconciled, rewritten, or removed.
const GATE_METHODS: Array[String] = [
	"acquire", "release", "guard_external", "is_active", "get_active_owner",
	"is_internal_owner_active", "latch_fatal", "is_fatal_latched",
]
const CHECKPOINT_INPUT_KEYS: Array[String] = [
	"active_app_id", "audio_context", "content_version", "dialogic_checkpoint",
	"route_id", "snapshot_input",
]
const DISK_WRITES := [
	{"kind": &"none", "reason": &"stage"},
	{"kind": &"autosave", "reason": &"day_start"},
	{"kind": &"autosave", "reason": &"ending"},
	# The Minesweeper pre-board autosave must be durable BEFORE a round is consumed or the save
	# lock acquired (dwm-p2r.9 Plan 06 Task 2). Both layers beneath this port already carry the
	# vocabulary -- CheckpointJournal.SEMANTIC_KINDS lists "pre_board" and
	# SaveDocumentSchema.AUTOSAVE_REASONS lists "pre_board" -- so only this enumeration was
	# missing the pairing. Reusing "day_start" instead would mislabel the durable document.
	{"kind": &"autosave", "reason": &"pre_board"},
	{"kind": &"autosave", "reason": &"automatic"},
]
const AUTOSAVE_RELATIVE_PATH := "autosave.json"

var _gate: Object = null
var _save_manager: Object = null
var _desktop_context_provider: Object = null
# Diagnostic counters only; never included in a candidate or persisted document.
var _profile_text_validator_calls := 0
var _profile_text_validator_us := 0
# One synchronous prepare/commit may reuse validation of its physically read preimage.
# Neither caller candidates nor later actions can seed this private exact-text proof.
var _prepared_text_validations: Dictionary = {}
var _prepared_validation_checkpoint := ""
var _prepared_validation_frame := -1
# Recovery checkpoints protect retries only while the current player action is executing. Source
# and completed post-result Autosaves retain the last fully saved player action; after a crash, the
# interrupted action may replay once.
var _transient_consequence_document := {"records": {}, "abandoned": {}}


func configure_desktop_context_provider(provider: Object) -> Dictionary:
	_clear_prepared_text_validation()
	# One Bootstrap-owned DesktopAppHostState supplies the persisted active_app_id. A second
	# direct configuration with the same object is idempotent; a different object is rejected.
	if provider == null or not provider.has_method("capture_persistent_state"):
		return _fail(&"invalid_desktop_context_provider", "provider must expose capture_persistent_state")
	if _desktop_context_provider != null:
		if provider == _desktop_context_provider:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _fail(&"desktop_provider_already_configured", "a desktop context provider is already configured")
	_desktop_context_provider = provider
	return {"ok": true, "code": &"ok",
		"value": {"provider_instance_id": _desktop_context_provider.get_instance_id()}, "receipt": {}}

func _init(save_manager: Object = null) -> void:
	_save_manager = save_manager

func configure_fatal_latch(gate: Object) -> Dictionary:
	_clear_prepared_text_validation()
	if gate == null or not gate.has_signal("capability_changed") or not _has_all_methods(gate):
		return {"ok": false, "code": &"invalid_mutation_gate", "message": "gate contract incomplete"}
	if _gate != null:
		if gate == _gate:
			return {"ok": true, "code": &"ok",
				"value": {"gate_instance_id": _gate.get_instance_id(), "already_configured": true},
				"receipt": {}}
		return {"ok": false, "code": &"mutation_gate_already_configured", "message": ""}
	_gate = gate
	if _gate.has_signal("transaction_released"):
		_gate.connect("transaction_released", _clear_prepared_text_validation)
	_gate.connect("capability_changed", _on_validation_capability_changed)
	return {"ok": true, "code": &"ok",
		"value": {"gate_instance_id": _gate.get_instance_id(), "already_configured": false},
		"receipt": {}}

func preview_checkpoint_id(run_id: String) -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	if run_id.is_empty():
		return _fail(&"invalid_run_id", "run_id must be nonempty")
	var peeked: Dictionary = _journal().peek_next_sequence(run_id)
	if not peeked.get("ok", false):
		return peeked
	return {"ok": true, "code": &"ok",
		"value": {"checkpoint_id": "%s:%d" % [run_id, int(peeked["value"]["checkpoint_sequence"])]},
		"receipt": {}}

func capture() -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	var captured: Dictionary = _journal().capture_state()
	return {"ok": true, "code": &"ok", "value": {"backup": captured["value"]["backup"]}}

func prepare(checkpoint_inputs: Dictionary, checkpoint_kind: StringName, disk_write: Dictionary) -> Dictionary:
	_clear_prepared_text_validation()
	if OS.get_environment("DWM_CHECKPOINT_PROFILE") == "1":
		_profile_text_validator_calls = 0
		_profile_text_validator_us = 0
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	var keys: Array = checkpoint_inputs.keys()
	keys.sort()
	var expected := CHECKPOINT_INPUT_KEYS.duplicate()
	expected.sort()
	if keys != Array(expected):
		return _fail(&"invalid_checkpoint_inputs", "unexpected input keys: " + str(keys))
	if disk_write not in DISK_WRITES:
		return _fail(&"invalid_disk_write", str(disk_write))
	var snapshot_input: Variant = checkpoint_inputs["snapshot_input"]
	if typeof(snapshot_input) != TYPE_DICTIONARY \
			or typeof((snapshot_input as Dictionary).get("lifecycle")) != TYPE_DICTIONARY:
		return _fail(&"invalid_checkpoint_inputs", "snapshot_input.lifecycle is required")
	var run_id := str((snapshot_input["lifecycle"] as Dictionary).get("run_id", ""))
	var peeked: Dictionary = _journal().peek_next_sequence(run_id)
	if not peeked.get("ok", false):
		return peeked
	# When configured, the desktop host is the sole source of the persisted active_app_id;
	# the caller-supplied value is ignored (dwm-p2r.9 Plan 02 Task 1).
	var active_app_id: Variant = checkpoint_inputs["active_app_id"]
	if _desktop_context_provider != null:
		active_app_id = _desktop_context_provider.capture_persistent_state().get("active_app_id", null)
	# T4-AF.18 / T4-AJ.C item 49: the live ScheduleView is checkpointed from the one restore
	# participant SaveManager already holds; absent participant, today's behaviour is unchanged;
	# no open day fails closed. A day-advance checkpoint's lifecycle NAMES the next day before
	# the live ScheduleViewController has opened it. GameStateDayResolutionPort._checkpoint_inputs
	# already resolves this same shape for committed_schedule -- a day the owner has not entered
	# gets its canonical empty aggregate -- so the RECORDED day, not the live day, is what gets
	# checkpointed. Mirroring ScheduleViewController.open_day()'s day-boundary law, the +1 day
	# derives a fresh empty view with the append-only condition_departure_receipts ledger carried
	# over. ANY forward gap derives -- the live controller is adopted to the new day only by
	# Task 5 / Task 7 work after each checkpoint, so in continuous play it can lag by several days
	# (RULING T4-AK, review P C1) -- while a recorded day BEHIND the captured view is left to
	# RunSnapshotSchema.build()'s own day binding to refuse.
	if not (snapshot_input as Dictionary).has("schedule_view") and _restore_participants().has("schedule_view"):
		var captured: Dictionary = _restore_participants()["schedule_view"].capture()
		if not captured.get("ok", false):
			return captured
		var backup: Variant = (captured.get("value", {}) as Dictionary).get("backup")
		if typeof(backup) != TYPE_DICTIONARY:
			return _fail(&"invalid_checkpoint_inputs", "schedule_view: no open day to checkpoint")
		var lifecycle: Dictionary = snapshot_input["lifecycle"]
		var recorded_day: int = int(lifecycle.get("day", 0))
		var backup_day: int = int((backup as Dictionary).get("day", 0))
		var merged_view: Dictionary = (backup as Dictionary).duplicate(true)
		if recorded_day > backup_day:
			var made: Dictionary = VIEW_STATE.make_empty(
				recorded_day, str(lifecycle.get("causal_day_instance", "")))
			if not made.get("ok", false):
				return made
			var derived_view: Dictionary = (made["value"] as Dictionary)["view"]
			var ledger: Variant = (backup as Dictionary).get("condition_departure_receipts")
			if typeof(ledger) != TYPE_DICTIONARY:
				return _fail(&"invalid_checkpoint_inputs",
					"schedule_view: captured view carries no departure ledger")
			derived_view["condition_departure_receipts"] = (ledger as Dictionary).duplicate(true)
			merged_view = derived_view
		snapshot_input = (snapshot_input as Dictionary).duplicate(true)
		snapshot_input["schedule_view"] = merged_view
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(
		snapshot_input, checkpoint_inputs["dialogic_checkpoint"],
		str(checkpoint_inputs["route_id"]), active_app_id,
		checkpoint_inputs["audio_context"], int(checkpoint_inputs["content_version"]),
		int(peeked["value"]["checkpoint_sequence"]))
	if not built.get("ok", false):
		return built
	var prepared_record: Dictionary = _journal().prepare_record(built["value"]["snapshot"], checkpoint_kind)
	if not prepared_record.get("ok", false):
		return prepared_record
	var journal_candidate: Dictionary = prepared_record["value"]["candidate"]
	var checkpoint_id := str(built["value"]["snapshot"]["checkpoint_id"])
	var candidate := {
		"journal_candidate": journal_candidate,
		"checkpoint_id": checkpoint_id,
		"autosave_document": null,
		"storage_backup": null,
	}
	var validated_texts := {}
	if str(disk_write["kind"]) == "autosave":
		var reason := str(disk_write["reason"])
		var projected_earlier: Array = journal_candidate["earlier"]
		var document: Dictionary = SAVE_DOCUMENT_SCHEMA.build(
			&"autosave", null, StringName(reason), journal_candidate["current"], projected_earlier)
		if not document.get("ok", false):
			return document
		candidate["autosave_document"] = document["value"]
		var backup := _capture_storage_backup(AUTOSAVE_RELATIVE_PATH, validated_texts)
		if not backup.get("ok", false):
			return backup
		candidate["storage_backup"] = backup["value"]["descriptor"]
	_prepared_text_validations = validated_texts
	_prepared_validation_checkpoint = checkpoint_id
	_prepared_validation_frame = Engine.get_process_frames()
	return {"ok": true, "code": &"ok",
		"value": {"candidate": candidate, "checkpoint_id": checkpoint_id}}

func commit(candidate: Dictionary) -> Dictionary:
	var validated_texts := _take_prepared_text_validation(candidate)
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	if typeof(candidate.get("journal_candidate")) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "candidate was not issued by this port")
	var profile := {}
	var tick := 0
	if OS.get_environment("DWM_CHECKPOINT_PROFILE") == "1":
		tick = Time.get_ticks_usec()
		var history: Variant = candidate["journal_candidate"].get("earlier")
		profile = {"scope": "save_checkpoint", "checkpoint_id": str(candidate.get("checkpoint_id", "")),
			"autosave": candidate.get("autosave_document") != null,
			"history_bundles": history.size() if history is Array else -1, "_started_us": tick}
	if candidate.get("autosave_document") != null:
		var canonical: Dictionary = CANONICAL_JSON.stringify(candidate["autosave_document"])
		tick = _profile_phase(profile, "stringify_us", tick)
		if not canonical.get("ok", false):
			return _profile_result(profile, _fail(&"canonical_serialization_failed", ""))
		if not profile.is_empty():
			profile["document_bytes"] = str(canonical["value"]).to_utf8_buffer().size() + 1
			tick = Time.get_ticks_usec()
		# The registries stay fixed through this synchronous prepare/commit. The cache
		# may contain its exact preimage read; new bytes still receive strict validation.
		var validator := _cached_document_text_validator.bind(validated_texts)
		var outgoing_text := str(canonical["value"]) + "\n"
		var written: Dictionary = _storage().write_atomic(
			AUTOSAVE_RELATIVE_PATH, outgoing_text, validator)
		tick = _profile_phase(profile, "write_atomic_us", tick)
		if not written.get("ok", false):
			return _profile_result(profile, written)
		var re_read: Dictionary = _storage().read_text(AUTOSAVE_RELATIVE_PATH)
		tick = _profile_phase(profile, "reread_us", tick)
		if not re_read.get("ok", false):
			return _profile_result(profile, re_read)
		var reread_text := str(re_read["value"])
		var validated: Dictionary = validator.call(reread_text)
		var valid: bool = reread_text == outgoing_text and validated.get("ok", false)
		tick = _profile_phase(profile, "reread_validate_us", tick)
		if not valid:
			return _profile_result(profile, _fail(&"reread_mismatch", AUTOSAVE_RELATIVE_PATH))
	var committed: Dictionary = _journal().commit_prepared(candidate["journal_candidate"])
	_profile_phase(profile, "journal_us", tick)
	if not committed.get("ok", false):
		return _profile_result(profile, committed)
	return _profile_result(profile, {"ok": true, "code": &"ok",
		"value": {"checkpoint_id": str(committed["value"]["checkpoint_id"])}})


static func _profile_phase(profile: Dictionary, phase: String, started_us: int) -> int:
	if profile.is_empty(): return 0
	var now := Time.get_ticks_usec()
	profile[phase] = now - started_us
	return now


func _profile_result(profile: Dictionary, result: Dictionary) -> Dictionary:
	if not profile.is_empty():
		profile["elapsed_us"] = Time.get_ticks_usec() - int(profile["_started_us"])
		profile.erase("_started_us")
		profile["ok"] = bool(result.get("ok", false))
		profile["text_validator_calls_since_prepare"] = _profile_text_validator_calls
		profile["text_validator_us_since_prepare"] = _profile_text_validator_us
		if not profile["ok"]: profile["code"] = str(result.get("code", ""))
		print("DWM_CHECKPOINT_PROFILE " + JSON.stringify(profile))
	return result

func rollback(backup: Dictionary) -> Dictionary:
	_clear_prepared_text_validation()
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	var attempts: Array = []
	var journal_backup: Variant = backup.get("journal_backup", backup)
	var journal_restored: Dictionary = _journal().restore_state(journal_backup)
	attempts.append({"owner_id": "checkpoint_journal", "operation": "restore_state", "result": journal_restored})
	var storage_descriptor: Variant = backup.get("storage_backup")
	var storage_ok := true
	if typeof(storage_descriptor) == TYPE_DICTIONARY:
		var descriptor := storage_descriptor as Dictionary
		var relative_path := str(descriptor.get("relative_path", AUTOSAVE_RELATIVE_PATH))
		var storage_result: Dictionary
		if bool(descriptor.get("existed", false)):
			storage_result = _storage().write_atomic(
				relative_path, str(descriptor.get("validated_text", "")), _document_text_validator)
		else:
			# A failed final reread may have invalidated the lease after a first save
			# became durable. Validate that artifact before restoring prior absence.
			storage_result = _storage().reconcile(relative_path, _document_text_validator)
			if storage_result.get("ok", false):
				storage_result = _storage().remove(relative_path)
		attempts.append({"owner_id": "save_storage", "operation": "rollback", "result": storage_result})
		storage_ok = storage_result.get("ok", false)
	if journal_restored.get("ok", false) and storage_ok:
		return {"ok": true, "code": &"ok"}
	return _fatal_rollback("rollback", str((journal_backup as Dictionary).get("run_id", "")), attempts)

## Builds the canonical stage record and receipt without mutating transient or durable state.
func prepare_consequence_checkpoint(checkpoint_header: Dictionary, stage_candidate: Dictionary) -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	var preimage: Dictionary = DESKTOP_CONSEQUENCE_STATE.checkpoint_content_preimage(checkpoint_header, stage_candidate)
	if not preimage.get("ok", false):
		return preimage
	var preimage_value: Dictionary = (preimage["value"] as Dictionary)["preimage"]
	var normalized_header: Dictionary = preimage_value["header"]
	var pairing := DESKTOP_CONSEQUENCE_STATE.validate_checkpoint_ordinal_stage(
		int(normalized_header["operation_ordinal"]), str(normalized_header["stage"]))
	if not pairing.get("ok", false):
		return pairing
	var canonical: Dictionary = CANONICAL_JSON.stringify(preimage_value)
	if not canonical.get("ok", false):
		return _fail(&"canonical_serialization_failed", "consequence checkpoint preimage is not canonicalizable")
	var content_sha256 := str(canonical["value"]).sha256_text()
	var checkpoint_receipt := {
		"receipt_id": "consequence_checkpoint." + content_sha256,
		"header": normalized_header.duplicate(true),
		"content_sha256": content_sha256,
	}
	var receipt_attached_candidate: Dictionary = stage_candidate.duplicate(true)
	var pending: Variant = receipt_attached_candidate.get("pending")
	if typeof(pending) == TYPE_DICTIONARY:
		var pending_dict: Dictionary = (pending as Dictionary).duplicate(true)
		if str(pending_dict.get("stage", "")) not in ["action_prepared", "prepared_checkpointed"]:
			pending_dict["checkpoint_receipt"] = checkpoint_receipt.duplicate(true)
			if pending_dict.get("admission_checkpoint_receipt") == null:
				pending_dict["admission_checkpoint_receipt"] = checkpoint_receipt.duplicate(true)
			receipt_attached_candidate["pending"] = pending_dict
	var key := str(checkpoint_header.get("transaction_id", "")) + ":" + str(normalized_header["operation_ordinal"])
	var record := {
		"key": key,
		"header": normalized_header.duplicate(true),
		"stage_candidate": receipt_attached_candidate,
		"checkpoint_receipt": checkpoint_receipt,
	}
	return {"ok": true, "code": &"ok", "value": {
		"candidate": {"document": record},
		"checkpoint_receipt": checkpoint_receipt,
	}}

## Retains one stage in memory. Identical occupied-slot retries replay; changed bytes conflict.
func commit_consequence_checkpoint(checkpoint_candidate: Dictionary, checkpoint_receipt: Dictionary) -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	if typeof(checkpoint_candidate.get("document")) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "candidate was not issued by prepare_consequence_checkpoint")
	var record: Dictionary = checkpoint_candidate["document"]
	if record.get("checkpoint_receipt") != checkpoint_receipt:
		return _fail(&"checkpoint_receipt_mismatch", "checkpoint_receipt does not match the prepared candidate")
	var validated := _validate_transient_consequence_record(record)
	if not validated.get("ok", false):
		return validated
	var normalized: Dictionary = validated["value"]
	var key: String = normalized["key"]
	var records: Dictionary = _transient_consequence_document["records"]
	if records.has(key):
		var existing: Dictionary = records[key]
		if str(validated["canonical_text"]) == _canonical_text(existing):
			return {"ok": true, "code": &"ok", "value": {"checkpoint_receipt": checkpoint_receipt}}
		return _fail(&"consequence_checkpoint_conflict",
			"a different checkpoint is already retained at " + key)
	records[key] = normalized
	return {"ok": true, "code": &"ok", "value": {"checkpoint_receipt": checkpoint_receipt}}

## Marks an unpromoted transient transaction abandoned without creating another stage record.
func abandon_pending_consequence_checkpoint(transaction_id: String) -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	if transaction_id.strip_edges().is_empty():
		return _fail(&"invalid_transaction_id", "transaction_id must be nonempty")
	var abandoned: Dictionary = _transient_consequence_document["abandoned"]
	if bool(abandoned.get(transaction_id, false)):
		return {"ok": true, "code": &"ok", "value": {"abandoned": true, "already_abandoned": true}}
	var records: Dictionary = _transient_consequence_document["records"]
	var latest_ordinal := -1
	var latest_stage := ""
	for record_key: String in records.keys():
		var record: Dictionary = records[record_key]
		var header: Dictionary = record["header"]
		if str(header["transaction_id"]) != transaction_id:
			continue
		var ordinal := int(header["operation_ordinal"])
		if ordinal > latest_ordinal:
			latest_ordinal = ordinal
			latest_stage = str(header["stage"])
	if latest_ordinal < 0:
		return _fail(&"consequence_checkpoint_not_found", "no retained checkpoint exists for " + transaction_id)
	if latest_stage not in ["action_prepared", "prepared_checkpointed"]:
		return _fail(&"consequence_checkpoint_not_pre_admission", "abandonment requires an unpromoted pre-admission checkpoint")
	abandoned[transaction_id] = true
	return {"ok": true, "code": &"ok", "value": {"abandoned": true, "already_abandoned": false}}

## Clears retry state only at an explicit successful session boundary.
func clear_transient_consequence_checkpoints() -> Dictionary:
	var records_cleared := (_transient_consequence_document["records"] as Dictionary).size()
	var abandoned_cleared := (_transient_consequence_document["abandoned"] as Dictionary).size()
	_transient_consequence_document = {"records": {}, "abandoned": {}}
	return {"ok": true, "code": &"ok", "value": {
		"records_cleared": records_cleared, "abandoned_cleared": abandoned_cleared}}


func read_pending_consequence_checkpoint() -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	var records: Dictionary = _transient_consequence_document["records"]
	var abandoned: Dictionary = _transient_consequence_document["abandoned"]
	var latest_by_transaction: Dictionary = {}
	for record_key: String in records.keys():
		var record: Dictionary = records[record_key]
		var header: Dictionary = record["header"]
		var transaction_id := str(header["transaction_id"])
		var ordinal := int(header["operation_ordinal"])
		if not latest_by_transaction.has(transaction_id) \
				or ordinal > int((latest_by_transaction[transaction_id]["header"] as Dictionary)["operation_ordinal"]):
			latest_by_transaction[transaction_id] = record
	var pending_transaction_ids: Array[String] = []
	for transaction_id: String in latest_by_transaction.keys():
		if bool(abandoned.get(transaction_id, false)):
			continue
		var record: Dictionary = latest_by_transaction[transaction_id]
		if (record["stage_candidate"] as Dictionary).get("pending") != null:
			pending_transaction_ids.append(transaction_id)
	if pending_transaction_ids.is_empty():
		return {"ok": true, "code": &"ok", "value": {"found": false}}
	if pending_transaction_ids.size() > 1:
		return _fail(&"consequence_checkpoint_multiple_pending_transactions",
			"more than one transaction_id has an unresolved transient checkpoint: " + str(pending_transaction_ids))
	var chosen: String = pending_transaction_ids[0]
	return {"ok": true, "code": &"ok", "value": {
		"found": true,
		"stage_candidate": ((latest_by_transaction[chosen] as Dictionary)["stage_candidate"] as Dictionary).duplicate(true),
	}}

func _canonical_text(value: Variant) -> String:
	var canonical: Dictionary = CANONICAL_JSON.stringify(value)
	if not canonical.get("ok", false):
		return ""
	return str(canonical["value"])

func _validate_transient_consequence_record(record: Dictionary) -> Dictionary:
	var canonical: Dictionary = CANONICAL_JSON.stringify(record)
	if not canonical.get("ok", false):
		return _fail(&"invalid_candidate", "checkpoint record is not canonicalizable")
	var parsed: Dictionary = STRICT_JSON.parse_object(str(canonical["value"]))
	if not parsed.get("ok", false) or typeof(parsed.get("value")) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "checkpoint record failed canonical round-trip validation")
	var normalized: Dictionary = parsed["value"]
	var keys: Array = normalized.keys()
	keys.sort()
	if keys != ["checkpoint_receipt", "header", "key", "stage_candidate"]:
		return _fail(&"invalid_candidate", "checkpoint record has unexpected keys")
	if typeof(normalized["key"]) != TYPE_STRING or str(normalized["key"]).strip_edges().is_empty():
		return _fail(&"invalid_candidate", "checkpoint record key must be a nonblank string")
	if typeof(normalized["header"]) != TYPE_DICTIONARY \
			or typeof(normalized["stage_candidate"]) != TYPE_DICTIONARY \
			or typeof(normalized["checkpoint_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "checkpoint record fields have invalid types")
	var header: Dictionary = normalized["header"]
	if str(normalized["key"]) != str(header.get("transaction_id", "")) + ":" + str(header.get("operation_ordinal", "")):
		return _fail(&"invalid_candidate", "checkpoint record key does not match its header")
	return {"ok": true, "code": &"ok", "value": normalized,
		"canonical_text": str(canonical["value"])}

func _fatal_rollback(phase: String, run_id: String, raw_diagnostics: Array) -> Dictionary:
	var already_retained := false
	for diagnostic: Dictionary in raw_diagnostics:
		if str((diagnostic.get("result", {}) as Dictionary).get("code", "")) == "APPLICATION_FATAL":
			already_retained = true
	if not already_retained and not _gate.is_fatal_latched():
		var projected: Dictionary = PROJECTOR.project_failure(
			"save_checkpoint", phase, "fatal_rollback_failed",
			{"run_id": run_id, "relative_path": AUTOSAVE_RELATIVE_PATH},
			raw_diagnostics)
		var candidate: Dictionary = PROJECTOR.get_invariant_fallback()
		if projected.get("ok", false):
			var failure: Dictionary = projected["value"]["failure"]
			if PROJECTOR.validate_failure(failure).get("ok", false):
				candidate = failure
		_gate.latch_fatal(candidate)
	return _gate.guard_external(&"save_checkpoint_recovery")

func _capture_storage_backup(relative_path: String, validated_texts: Dictionary) -> Dictionary:
	var existed: bool = _storage().exists(relative_path)
	var descriptor := {
		"relative_path": relative_path,
		"existed": existed,
		"validated_text": null,
		"sha256": null,
	}
	if existed:
		var read: Dictionary = _storage().read_text(relative_path)
		if not read.get("ok", false):
			if str(read.get("code", "")) == "reconcile_required":
				# A failed read invalidates the storage lease before any checkpoint is committed.
				# Revalidate durable evidence so an explicit retry can read it again.
				# This attempt still fails; corrupt or ambiguous artifacts remain refused.
				var reconciled: Dictionary = _storage().reconcile(relative_path, _document_text_validator)
				if not reconciled.get("ok", false):
					return reconciled
			return read
		var text := str(read["value"])
		var validation := _cached_document_text_validator(text, validated_texts)
		if not validation.get("ok", false):
			return validation
		descriptor["validated_text"] = text
		descriptor["sha256"] = text.sha256_text()
	return {"ok": true, "code": &"ok", "value": {"descriptor": descriptor}}

func _clear_prepared_text_validation() -> void:
	_prepared_text_validations = {}
	_prepared_validation_checkpoint = ""
	_prepared_validation_frame = -1

func _on_validation_capability_changed(_capability: Dictionary) -> void:
	_clear_prepared_text_validation()

func _take_prepared_text_validation(candidate: Dictionary) -> Dictionary:
	var cache := {}
	if _prepared_validation_frame == Engine.get_process_frames() \
			and str(candidate.get("checkpoint_id", "")) == _prepared_validation_checkpoint:
		cache = _prepared_text_validations
	# Consume before any failure, external callback or I/O; retries always start fresh.
	_clear_prepared_text_validation()
	return cache

func _cached_document_text_validator(text: String, cache: Dictionary) -> Dictionary:
	if cache.has(text):
		return (cache[text] as Dictionary).duplicate(true)
	var result := _document_text_validator(text)
	if result.get("ok", false):
		cache[text] = result.duplicate(true)
	return result

func _document_text_validator(text: String) -> Dictionary:
	if OS.get_environment("DWM_CHECKPOINT_PROFILE") != "1":
		return _validate_document_text(text)
	var started_us := Time.get_ticks_usec()
	var result := _validate_document_text(text)
	_profile_text_validator_calls += 1
	_profile_text_validator_us += Time.get_ticks_usec() - started_us
	return result


func _validate_document_text(text: String) -> Dictionary:
	var parsed: Dictionary = STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false):
		return {"ok": false, "code": &"invalid_json", "message": "strict parse failed"}
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": validated["value"]["candidate"]}

func _readiness() -> Dictionary:
	if _gate == null:
		return _fail(&"fatal_latch_not_configured", "")
	if _gate.is_fatal_latched():
		return _gate.guard_external(&"save_checkpoint_recovery")
	if _save_manager == null or _journal() == null or _storage() == null:
		return _fail(&"not_initialized", "SaveManagerCheckpointPort requires an initialized SaveManager")
	return {}

func _journal() -> RefCounted:
	return _save_manager._journal if _save_manager != null else null

func _storage() -> RefCounted:
	return _save_manager._storage if _save_manager != null else null

func _restore_participants() -> Dictionary:
	return _save_manager._restore_participants if _save_manager != null else {}

static func _has_all_methods(target: Object) -> bool:
	for method: String in GATE_METHODS:
		if not target.has_method(method):
			return false
	return true

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
