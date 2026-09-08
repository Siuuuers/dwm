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

## Plan 02 Task 6 (dwm-p2r.32): the narrow, self-contained durable record backing
## `DesktopCausalSequencePort`'s admission checkpoint -- one small atomic JSON file at a fixed
## relative path through the same injected StorageAdapter the autosave document already uses,
## deliberately NOT routed through CheckpointJournal/SaveDocumentSchema: those own the full
## RunSnapshot lifecycle, while this owns only the narrow consequence-admission compare-and-swap
## point (brief line 249's "final compare-and-swap/admission point shared by every source kind").
const CONSEQUENCE_CHECKPOINT_RELATIVE_PATH := "desktop-consequence-checkpoint.json"
## dwm-p2r.35.3 remediation (finding A-C3): the document is a keyed-records store, one record per
## occupied `(transaction_id, operation_ordinal)` slot -- mirroring this codebase's own established
## ledger precedent (`DesktopPublicationLedger`/`ScheduleFoundationPublicationLedger`'s
## `{schema_version,records}` shape and read-before-write/atomic-replace discipline) -- rather than
## the single fixed-shape document this file previously overwrote on every write, which could never be
## addressed by transaction/ordinal and therefore could never support a reader, an occupied-slot
## conflict law, or more than one durable checkpoint at a time.
## dwm-p2r.35.7 remediation (finding 1): `abandoned` added -- a flat `{transaction_id:true}` set,
## disjoint from `records`, written only by `abandon_pending_consequence_checkpoint()` below. See
## that method's own doc comment for why abandonment is a distinct top-level document member rather
## than another keyed record: the frozen law it implements explicitly forbids abandonment from
## creating or promoting a consequence checkpoint, so it cannot reuse the `records` keyspace, which
## exists only for genuine checkpoint operations.
const CONSEQUENCE_CHECKPOINT_DOCUMENT_KEYS: Array[String] = ["abandoned", "records", "schema_version"]
const CONSEQUENCE_CHECKPOINT_RECORD_KEYS: Array[String] = ["checkpoint_receipt", "header", "key", "stage_candidate"]

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


func configure_desktop_context_provider(provider: Object) -> Dictionary:
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
	if gate == null or not gate.has_signal("capability_changed") or not _has_all_methods(gate):
		return {"ok": false, "code": &"invalid_mutation_gate", "message": "gate contract incomplete"}
	if _gate != null:
		if gate == _gate:
			return {"ok": true, "code": &"ok",
				"value": {"gate_instance_id": _gate.get_instance_id(), "already_configured": true},
				"receipt": {}}
		return {"ok": false, "code": &"mutation_gate_already_configured", "message": ""}
	_gate = gate
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
	if str(disk_write["kind"]) == "autosave":
		var reason := str(disk_write["reason"])
		var projected_earlier: Array = journal_candidate["earlier"]
		var document: Dictionary = SAVE_DOCUMENT_SCHEMA.build(
			&"autosave", null, StringName(reason), journal_candidate["current"], projected_earlier)
		if not document.get("ok", false):
			return document
		candidate["autosave_document"] = document["value"]
		var backup := _capture_storage_backup(AUTOSAVE_RELATIVE_PATH)
		if not backup.get("ok", false):
			return backup
		candidate["storage_backup"] = backup["value"]["descriptor"]
	return {"ok": true, "code": &"ok",
		"value": {"candidate": candidate, "checkpoint_id": checkpoint_id}}

func commit(candidate: Dictionary) -> Dictionary:
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
		# Validation depends only on these exact bytes and the fixed resource registries
		# during this synchronous commit. Never retain a result across commits or retries.
		var validated_texts := {}
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

## Task-6 addition (dwm-p2r.32): builds the narrow admission-checkpoint candidate for
## `DesktopCausalSequencePort`. Mutation-free -- it computes the frozen preimage/receipt (the sole
## legal builder is `DesktopConsequenceState.checkpoint_content_preimage()`) but writes nothing; only
## `commit_consequence_checkpoint()` durably writes.
##
## dwm-p2r.35.3 remediation (finding A-C3, fix 1 of 2): every checkpoint write is cross-checked against
## the frozen ordinal<->stage law (`DesktopConsequenceState.validate_checkpoint_ordinal_stage()`) here
## -- the one place every checkpoint author's write already passes through -- so ordinal 0 and
## ordinals 8-12 are guarded exactly as uniformly as `DesktopConsequenceCoordinator`'s own two
## directly-authored ordinals (1, 2) already were.
##
## dwm-p2r.35.3 remediation (finding A-C3, fix 2 of 2): the frozen "sole producer order" (plan02-frozen-
## contracts.md line 479) requires that, for admission, the newly minted receipt is attached to BOTH
## `checkpoint_receipt` and `admission_checkpoint_receipt`, and for a later forward/progress operation
## it is attached only as the new `checkpoint_receipt` (the admission field is preserved byte-for-
## byte) -- BEFORE the candidate/receipt relation is durably persisted. Previously this method stored
## the raw, receipt-free `stage_candidate` verbatim: at the admission ordinal (`sequence_committed`
## with both receipt fields still null -- `DesktopConsequenceState._validate_pending()`'s own in-
## flight-admission relaxation, legal ONLY inside the preimage this method itself computes) that raw
## shape is exactly what `DesktopConsequenceState.validate()` rejects with
## `pending_admission_receipt_required`, so the one durable admission record a reader could ever load
## was itself unloadable. `DesktopCausalSequencePort.commit()` separately patches these same two
## fields onto the LIVE object after this checkpoint already committed to disk; that live patch is
## unchanged (still correct, still redundant-but-harmless) -- this fix makes the DISK record carry the
## identical patched bytes, so what gets persisted and what gets adopted live are the same shape.
## Pre-admission stages (`action_prepared`, `prepared_checkpointed`) are left untouched: `validate()`
## requires BOTH receipt fields null there, which the unpatched input already satisfies.
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

## dwm-p2r.35.3 remediation (finding A-C3): real occupied-slot conflict law keyed on
## `(transaction_id, operation_ordinal)`, read-before-write/atomic-replace over a keyed-records
## document -- mirroring `DesktopPublicationLedger`/`ScheduleFoundationPublicationLedger`'s own
## established precedent, rather than the single fixed-shape document this method previously
## overwrote unconditionally on every write (which never tracked a slot, never read anything back
## first, and could never return `consequence_checkpoint_conflict`). An identical-bytes rewrite at an
## occupied slot replays the retained record's receipt as success; a changed-bytes rewrite at an
## occupied slot returns the frozen `consequence_checkpoint_conflict` (plan02-frozen-contracts.md
## line 481) without touching disk.
func commit_consequence_checkpoint(checkpoint_candidate: Dictionary, checkpoint_receipt: Dictionary) -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	if typeof(checkpoint_candidate.get("document")) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "candidate was not issued by prepare_consequence_checkpoint")
	var record: Dictionary = checkpoint_candidate["document"]
	if record.get("checkpoint_receipt") != checkpoint_receipt:
		return _fail(&"checkpoint_receipt_mismatch", "checkpoint_receipt does not match the prepared candidate")
	var key := str(record.get("key", ""))
	if key.is_empty():
		return _fail(&"invalid_candidate", "candidate is missing its occupied-slot key")

	var loaded := _load_consequence_checkpoint_document()
	if not loaded.get("ok", false):
		return loaded
	var document: Dictionary = loaded["value"]["document"]
	var records: Dictionary = document["records"]
	if records.has(key):
		var existing: Dictionary = records[key]
		# Compare by canonical serialization, not raw Dictionary `==`: `existing` came back through a
		# JSON round-trip (StrictJson has no StringName type, so e.g. header.kind lands as a plain
		# String), while `record` is the freshly built in-memory candidate this process never
		# serialized (header.kind is still the caller's original StringName). The two are semantically
		# byte-identical but would never compare `==` directly.
		if _canonical_text(existing) == _canonical_text(record):
			return {"ok": true, "code": &"ok", "value": {"checkpoint_receipt": checkpoint_receipt}}
		return _fail(&"consequence_checkpoint_conflict",
			"a different checkpoint is already durably recorded at " + key)

	var next_document := document.duplicate(true)
	(next_document["records"] as Dictionary)[key] = record.duplicate(true)
	var canonical: Dictionary = CANONICAL_JSON.stringify(next_document)
	if not canonical.get("ok", false):
		return _fail(&"canonical_serialization_failed", "consequence checkpoint document is not canonicalizable")
	var text := str(canonical["value"]) + "\n"
	var written: Dictionary = _storage().write_atomic(
		CONSEQUENCE_CHECKPOINT_RELATIVE_PATH, text, _consequence_checkpoint_text_validator)
	if not written.get("ok", false):
		return written
	var re_read: Dictionary = _storage().read_text(CONSEQUENCE_CHECKPOINT_RELATIVE_PATH)
	if not re_read.get("ok", false):
		return re_read
	if str(re_read["value"]) != text:
		return _fail(&"reread_mismatch", CONSEQUENCE_CHECKPOINT_RELATIVE_PATH)
	return {"ok": true, "code": &"ok", "value": {"checkpoint_receipt": checkpoint_receipt}}

## dwm-p2r.35.7 remediation (finding 1): plan02-frozen-contracts.md line 2271's "marks only the
## already-durable unpromoted source checkpoint abandoned through the injected checkpoint port".
## Requires an existing durable pre-admission (`action_prepared`/`prepared_checkpointed`) record for
## `transaction_id` -- abandonment is not legal for an already-admitted transaction, matching the
## frozen law's own "before causal admission" scoping. Records the transaction_id in a SEPARATE
## `abandoned` set rather than writing another keyed `records` entry: the frozen law explicitly says
## this "never creates or promotes a consequence checkpoint", and every `records` entry IS a
## checkpoint by this document's own convention, so reusing that keyspace here would contradict the
## very law this method implements. Idempotent: an already-abandoned transaction_id replays success
## without rewriting.
func abandon_pending_consequence_checkpoint(transaction_id: String) -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	if transaction_id.strip_edges().is_empty():
		return _fail(&"invalid_transaction_id", "transaction_id must be nonempty")
	var loaded := _load_consequence_checkpoint_document()
	if not loaded.get("ok", false):
		return loaded
	var document: Dictionary = loaded["value"]["document"]
	var abandoned: Dictionary = document.get("abandoned", {})
	if bool(abandoned.get(transaction_id, false)):
		return {"ok": true, "code": &"ok", "value": {"abandoned": true, "already_abandoned": true}}

	var records: Dictionary = document["records"]
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
		return _fail(&"consequence_checkpoint_not_found", "no durable checkpoint exists for " + transaction_id)
	if latest_stage not in ["action_prepared", "prepared_checkpointed"]:
		return _fail(&"consequence_checkpoint_not_pre_admission", "abandonment requires an unpromoted pre-admission checkpoint")

	var next_document := document.duplicate(true)
	var next_abandoned: Dictionary = (next_document.get("abandoned", {}) as Dictionary).duplicate(true)
	next_abandoned[transaction_id] = true
	next_document["abandoned"] = next_abandoned
	var canonical: Dictionary = CANONICAL_JSON.stringify(next_document)
	if not canonical.get("ok", false):
		return _fail(&"canonical_serialization_failed", "consequence checkpoint document is not canonicalizable")
	var text := str(canonical["value"]) + "\n"
	var written: Dictionary = _storage().write_atomic(
		CONSEQUENCE_CHECKPOINT_RELATIVE_PATH, text, _consequence_checkpoint_text_validator)
	if not written.get("ok", false):
		return written
	var re_read: Dictionary = _storage().read_text(CONSEQUENCE_CHECKPOINT_RELATIVE_PATH)
	if not re_read.get("ok", false):
		return re_read
	if str(re_read["value"]) != text:
		return _fail(&"reread_mismatch", CONSEQUENCE_CHECKPOINT_RELATIVE_PATH)
	return {"ok": true, "code": &"ok", "value": {"abandoned": true, "already_abandoned": false}}

## dwm-p2r.35.3 remediation (finding A-C3, "no reader"): the sole reader `desktop-consequence-
## checkpoint.json` has ever had. For every transaction_id present in the durable records, keeps only
## its highest-ordinal record (the most-advanced durable truth for that transaction); among those,
## returns the one whose `stage_candidate.pending` is still nonnull -- a transaction whose most-
## advanced record already shows `pending=null` reached terminal cleanup and has nothing left to
## recover. The exclusive `causal_transaction` mutation-gate owner means at most one transaction_id
## should ever satisfy this at a time; more than one is a genuine anomaly and fails loudly rather than
## silently picking one.
func read_pending_consequence_checkpoint() -> Dictionary:
	var readiness := _readiness()
	if not readiness.is_empty():
		return readiness
	var loaded := _load_consequence_checkpoint_document()
	if not loaded.get("ok", false):
		return loaded
	var document: Dictionary = (loaded["value"] as Dictionary)["document"]
	var records: Dictionary = document["records"]
	# dwm-p2r.35.7 remediation (finding 1): a transaction_id marked abandoned is never reported as
	# still-pending -- otherwise adopt_durable_checkpoint_if_live_is_behind() would re-adopt the exact
	# transaction accept_prepared_action() just abandoned on every subsequent boot.
	var abandoned: Dictionary = document.get("abandoned", {})
	var latest_by_transaction: Dictionary = {}
	for record_key: String in records.keys():
		var record: Dictionary = records[record_key]
		var header: Dictionary = record["header"]
		var transaction_id := str(header["transaction_id"])
		var ordinal := int(header["operation_ordinal"])
		if not latest_by_transaction.has(transaction_id) \
				or ordinal > int((latest_by_transaction[transaction_id]["header"] as Dictionary)["operation_ordinal"]):
			latest_by_transaction[transaction_id] = record
	var pending_transaction_ids: Array = []
	for transaction_id: String in latest_by_transaction.keys():
		if bool(abandoned.get(transaction_id, false)):
			continue
		var record: Dictionary = latest_by_transaction[transaction_id]
		if (record["stage_candidate"] as Dictionary).get("pending") != null:
			pending_transaction_ids.append(transaction_id)
	if pending_transaction_ids.is_empty():
		return {"ok": true, "code": &"ok", "value": {"found": false}}
	var saved := _read_completed_snapshot()
	if not saved.get("ok", false):
		return saved
	var completed_snapshot: Dictionary = saved["value"]["snapshot"]
	for transaction_id: String in pending_transaction_ids.duplicate():
		var record: Dictionary = latest_by_transaction[transaction_id]
		if _completed_snapshot_supersedes(record, completed_snapshot):
			# Repair the missing terminal write durably. Otherwise replacing Autosave on a later
			# day/continuation would remove this proof and make the stale transaction reappear.
			var repaired := _repair_completed_consequence_checkpoint(record, completed_snapshot)
			if not repaired.get("ok", false):
				return repaired
			pending_transaction_ids.erase(transaction_id)
	if pending_transaction_ids.is_empty():
		return {"ok": true, "code": &"ok", "value": {"found": false}}
	if pending_transaction_ids.size() > 1:
		return _fail(&"consequence_checkpoint_multiple_pending_transactions",
			"more than one transaction_id has an unresolved durable checkpoint: " + str(pending_transaction_ids))
	var chosen: String = pending_transaction_ids[0]
	return {"ok": true, "code": &"ok", "value": {
		"found": true,
		"stage_candidate": ((latest_by_transaction[chosen] as Dictionary)["stage_candidate"] as Dictionary).duplicate(true),
	}}

## A crash may occur after the complete Autosave write but before terminal sidecar cleanup.
## In that window the full snapshot is authoritative: replaying an older admitted payload would
## rewind gameplay. Only the same exact run/branch/generation/day and an advanced completed causal
## state establish supersession; unrelated or remapped identities are never guessed equivalent.
func _read_completed_snapshot() -> Dictionary:
	var reconciled: Dictionary = _storage().reconcile(AUTOSAVE_RELATIVE_PATH, _document_text_validator)
	if not reconciled.get("ok", false):
		return reconciled
	if not reconciled.get("exists", false):
		return {"ok": true, "value": {"snapshot": {}}}
	var read: Dictionary = _storage().read_text(AUTOSAVE_RELATIVE_PATH)
	if not read.get("ok", false):
		return read
	var validated := _document_text_validator(str(read["value"]))
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "value": {"snapshot": validated["value"]["current_snapshot"]["snapshot"]}}


func _repair_completed_consequence_checkpoint(record: Dictionary, snapshot: Dictionary) -> Dictionary:
	var transaction_id := str(record["header"]["transaction_id"])
	var header := {"kind": &"consequence_cleanup", "transaction_id": transaction_id,
		"stage": "publication_pending", "operation_ordinal": 12, "run_id": "", "source_ids": [transaction_id]}
	var prepared := prepare_consequence_checkpoint(header, snapshot["desktop"]["consequence"])
	if not prepared.get("ok", false):
		return prepared
	return commit_consequence_checkpoint(prepared["value"]["candidate"], prepared["value"]["checkpoint_receipt"])


func _completed_snapshot_supersedes(record: Dictionary, snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	var state: Dictionary = record["stage_candidate"]
	var pending: Dictionary = state["pending"]
	if str(pending.get("stage", "")) not in ["sequence_committed", "publication_pending"]:
		return false
	var payload: Dictionary = pending.get("recovery_payload", {})
	var action: Dictionary = payload.get("action_receipt", {})
	for recipe: Variant in payload.get("publication_plan", []):
		if typeof(recipe) == TYPE_DICTIONARY and str(recipe.get("participant", "")) == "action_source":
			action = recipe.get("publication", {}).get("action_receipt", {})
			break
	var lifecycle: Dictionary = snapshot.get("lifecycle", {})
	for field: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance"]:
		if not action.has(field) or action[field] != lifecycle.get(field):
			return false
	var completed: Dictionary = snapshot.get("desktop", {}).get("consequence", {})
	return completed.get("pending") == null \
		and str(completed.get("causal_day_instance", "")) == str(state.get("causal_day_instance", "")) \
		and int(completed.get("causal_sequence", -1)) >= int(state.get("causal_sequence", 0)) \
		and int(completed.get("run_revision", -1)) >= int(state.get("run_revision", 0))


func _canonical_text(value: Variant) -> String:
	var canonical: Dictionary = CANONICAL_JSON.stringify(value)
	if not canonical.get("ok", false):
		return ""
	return str(canonical["value"])

func _load_consequence_checkpoint_document() -> Dictionary:
	var reconciled: Dictionary = _storage().reconcile(CONSEQUENCE_CHECKPOINT_RELATIVE_PATH,
		_consequence_checkpoint_text_validator)
	if not reconciled.get("ok", false):
		return reconciled
	if not reconciled.get("exists", false):
		return {"ok": true, "code": &"ok", "value": {"document": {"schema_version": 1, "records": {}, "abandoned": {}}}}
	var read: Dictionary = _storage().read_text(CONSEQUENCE_CHECKPOINT_RELATIVE_PATH)
	if not read.get("ok", false):
		return read
	var validated := _consequence_checkpoint_text_validator(str(read["value"]))
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": {"document": validated["value"]}}

func _consequence_checkpoint_text_validator(text: String) -> Dictionary:
	var parsed: Dictionary = STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false):
		return {"ok": false, "code": &"invalid_json", "message": "strict parse failed"}
	var raw: Variant = parsed["value"]
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"invalid_consequence_checkpoint", "message": "document must be an object"}
	var document: Dictionary = raw
	var keys: Array = document.keys()
	keys.sort()
	var expected := CONSEQUENCE_CHECKPOINT_DOCUMENT_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return {"ok": false, "code": &"invalid_consequence_checkpoint", "message": "unexpected document keys"}
	if typeof(document["schema_version"]) != TYPE_INT or int(document["schema_version"]) != 1:
		return {"ok": false, "code": &"invalid_consequence_checkpoint", "message": "schema_version must be exactly 1"}
	if typeof(document["records"]) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"invalid_consequence_checkpoint", "message": "records must be an object"}
	if typeof(document["abandoned"]) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"invalid_consequence_checkpoint", "message": "abandoned must be an object"}
	for abandoned_key: Variant in (document["abandoned"] as Dictionary):
		if typeof(abandoned_key) != TYPE_STRING or str(abandoned_key).strip_edges().is_empty():
			return {"ok": false, "code": &"invalid_consequence_checkpoint", "message": "an abandoned key must be a nonblank string"}
		if (document["abandoned"] as Dictionary)[abandoned_key] != true:
			return {"ok": false, "code": &"invalid_consequence_checkpoint", "message": "an abandoned value must be exactly true"}
	var records: Dictionary = document["records"]
	for record_key: Variant in records:
		if typeof(record_key) != TYPE_STRING or str(record_key).strip_edges().is_empty():
			return {"ok": false, "code": &"invalid_consequence_checkpoint", "message": "a record key must be a nonblank string"}
		if typeof(records[record_key]) != TYPE_DICTIONARY:
			return {"ok": false, "code": &"invalid_consequence_checkpoint", "message": "a record must be an object"}
		var record: Dictionary = records[record_key]
		var record_keys: Array = record.keys()
		record_keys.sort()
		var expected_record_keys := CONSEQUENCE_CHECKPOINT_RECORD_KEYS.duplicate()
		expected_record_keys.sort()
		if record_keys != expected_record_keys:
			return {"ok": false, "code": &"invalid_consequence_checkpoint", "message": "unexpected record keys"}
		if str(record["key"]) != str(record_key):
			return {"ok": false, "code": &"invalid_consequence_checkpoint", "message": "a record's key must equal its index"}
	return {"ok": true, "code": &"ok", "value": document}

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

func _capture_storage_backup(relative_path: String) -> Dictionary:
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
		var validation := _document_text_validator(text)
		if not validation.get("ok", false):
			return validation
		descriptor["validated_text"] = text
		descriptor["sha256"] = text.sha256_text()
	return {"ok": true, "code": &"ok", "value": {"descriptor": descriptor}}

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
