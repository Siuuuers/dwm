extends "res://addons/gut/test.gd"

## Complete save-boundary comparisons: real port, journal and storage protocol; deterministic I/O.
## The reference freezes the accepted commit/splice and journal proof learning. Strict reparsing
## independently checks that each cached lease describes the actual written bytes.
const PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const REFERENCE := preload("res://tests/support/WarmOutgoingProofReference.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/CheckpointJournal.gd")
const JOURNAL_REFERENCE := preload("res://tests/support/WarmOutgoingJournalReference.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const SNAPSHOT := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const DOCUMENT := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const ROOT := "warm-proof-commits"
const FINAL := ROOT + "/autosave.json"
const PROFILE_ENV := "DWM_CHECKPOINT_PROFILE"

class Manager extends RefCounted:
	var _journal: RefCounted
	var _storage: RefCounted
	var _restore_participants := {}
	func _init(reference: bool = false) -> void:
		_journal = JOURNAL_REFERENCE.new() if reference else JOURNAL.new()

var _had_profile := false
var _previous_profile := ""

func before_each() -> void:
	_had_profile = OS.has_environment(PROFILE_ENV)
	_previous_profile = OS.get_environment(PROFILE_ENV)
	OS.unset_environment(PROFILE_ENV)

func after_each() -> void:
	if _had_profile: OS.set_environment(PROFILE_ENV, _previous_profile)
	else: OS.unset_environment(PROFILE_ENV)

func _wired(reference: bool = false) -> Dictionary:
	var parsed := STRICT.parse_object(FileAccess.get_file_as_string(
		"res://tests/fixtures/saves/v7_desktop_prepared.json"))
	assert_true(parsed.get("ok", false), "fixture strict parse")
	parsed.value["schema_version"] = SNAPSHOT.SCHEMA_VERSION
	var validated := SNAPSHOT.validate(parsed.get("value", {}))
	assert_true(validated.get("ok", false), "fixture snapshot validation")
	var manager := Manager.new(reference)
	var files := FILES.new()
	manager._storage = STORAGE.new(ROOT, files)
	var port: RefCounted = REFERENCE.new(manager) if reference else PORT.new(manager)
	assert_true(port.configure_fatal_latch(GATE.new()).get("ok", false))
	var snapshot: Dictionary = validated["value"]["candidate"]
	assert_true(manager._journal.reset(str(snapshot.run_id)).get("ok", false))
	return {"manager": manager, "files": files, "port": port, "snapshot": snapshot}

func _prepare(wired: Dictionary, money: int) -> Dictionary:
	var snapshot: Dictionary = wired.snapshot.duplicate(true)
	snapshot["gameplay"]["money"] = money
	var input := {}
	for key: String in ["lifecycle", "gameplay", "contacts", "committed_schedule", "dating",
			"applied_effect_transaction_ids", "applied_variable_transaction_ids", "desktop", "schedule_view", "command_receipts"]:
		input[key] = snapshot[key]
	# Public capture accepts engine text and typed empty arrays; persisted leases must be JSON-shaped.
	var effects: Array[StringName] = []
	input["applied_effect_transaction_ids"] = effects
	var prepared: Dictionary = wired.port.prepare({"snapshot_input": input, "dialogic_checkpoint": {},
		"route_id": "main", "active_app_id": &"contacts", "audio_context": snapshot.audio_context,
		"content_version": snapshot.content_version}, &"post_result", {"kind": &"autosave", "reason": &"automatic"})
	assert_true(prepared.get("ok", false), str(prepared.get("code", "")))
	return prepared.get("value", {}).get("candidate", {})

func _assert_same_state(actual: Dictionary, reference: Dictionary) -> void:
	assert_eq(actual.files.snapshot_persisted(), reference.files.snapshot_persisted(), "exact physical bytes")
	assert_eq(var_to_bytes(actual.files.operation_trace()), var_to_bytes(reference.files.operation_trace()),
		"every ordered storage operation, including native StringName fields")
	assert_eq(var_to_bytes(actual.manager._journal.capture_state()),
		var_to_bytes(reference.manager._journal.capture_state()), "journal values, types and cursor")
	for bundle: Dictionary in actual.manager._journal.get_bundles_for_disk():
		var checkpoint_id := str(bundle.snapshot.checkpoint_id)
		assert_eq(actual.manager._journal.get_retained_bundle_text(checkpoint_id),
			reference.manager._journal.get_retained_bundle_text(checkpoint_id), "proof text")
		assert_true(WRITER._deep_same(actual.manager._journal.get_retained_bundle_document(checkpoint_id),
			reference.manager._journal.get_retained_bundle_document(checkpoint_id)), "proof document")

func _assert_lease(wired: Dictionary) -> Dictionary:
	var text: String = wired.files.snapshot_persisted()[FINAL].get_string_from_utf8()
	var parsed := STRICT.parse_object(text)
	assert_true(parsed.get("ok", false), "written text parses strictly")
	var validated := DOCUMENT.validate(parsed.get("value", {}))
	assert_true(validated.get("ok", false), "written text validates strictly")
	assert_true(wired.port._proven_document_validations.has(text), "exact-text lease is retained before lookup")
	var lease: Dictionary = wired.port._cached_document_text_validator(text, {})
	assert_true(lease.get("ok", false), "exact written text has a lease")
	var expected: Dictionary = validated["value"]["candidate"]
	assert_true(WRITER._deep_same(lease["value"], expected), "lease describes exact written values and numeric types")
	assert_false((lease["value"]["recovery_journal"] as Array).is_typed(), "untyped JSON journal")
	_assert_document_shape(lease["value"]["current_snapshot"])
	for bundle: Dictionary in lease["value"]["recovery_journal"]:
		_assert_document_shape(bundle)
	# An exposed lease is detached even when the port internally used private journal document proofs.
	lease["value"]["current_snapshot"]["snapshot"]["gameplay"]["money"] = 987654
	assert_true(WRITER._deep_same(wired.port._cached_document_text_validator(text, {})["value"], expected),
		"caller mutation cannot alter a retained lease")
	return expected

func _assert_document_shape(bundle: Dictionary) -> void:
	assert_eq(typeof(bundle.snapshot.active_app_id), TYPE_STRING, "engine text was normalized")
	assert_false((bundle.snapshot.applied_effect_transaction_ids as Array).is_typed(), "untyped JSON descendants")
	assert_false((bundle.snapshot.audio_context as Dictionary).is_typed(), "untyped JSON object")
	for key: Variant in bundle.snapshot:
		assert_eq(typeof(key), TYPE_STRING, "JSON snapshot keys are Strings")

func _edit_equal_engine_containers(bundle: Dictionary) -> void:
	# Equal values and canonical bytes do not prove the original engine containers are normalized.
	var effects: Array[String] = []
	var audio: Dictionary[String, String] = {}
	bundle.snapshot["applied_effect_transaction_ids"] = effects
	bundle.snapshot.erase("audio_context")
	bundle.snapshot[&"audio_context"] = audio

func _commit_pair(actual: Dictionary, reference: Dictionary, money: int) -> void:
	assert_true(actual.port.commit(_prepare(actual, money)).get("ok", false))
	assert_true(reference.port.commit(_prepare(reference, money)).get("ok", false))
	_assert_same_state(actual, reference)
	_assert_lease(actual)

func test_warm_commit_uses_exact_ordered_proofs_and_preserves_profile_and_caller_custody() -> void:
	var actual := _wired()
	var reference := _wired(true)
	for money: int in [101, 102]:
		for wired: Dictionary in [actual, reference]:
			var prepared := _prepare(wired, money)
			_edit_equal_engine_containers(prepared.autosave_document.current_snapshot)
			assert_true(wired.port.commit(prepared).get("ok", false))
		_assert_same_state(actual, reference)
		_assert_lease(actual)
		var checkpoint_id: String = actual.manager._journal.get_current_bundle()["value"]["bundle"].snapshot.checkpoint_id
		var proof: Dictionary = actual.manager._journal.get_retained_bundle_document(checkpoint_id)
		assert_false(proof.is_empty(), "equal engine containers do not lose the successful proof")
		_assert_document_shape(proof)
	var candidate := _prepare(actual, 103)
	var control := _prepare(reference, 103)
	for prepared: Dictionary in [candidate, control]:
		var history: Array = prepared.autosave_document.recovery_journal
		assert_eq(history.size(), 2, "warm fixture has two retained proofs")
		history.reverse()
		history[0]["snapshot"]["gameplay"]["money"] = 999999
	var before := var_to_bytes(candidate)
	var raw: Array = []
	var documents: Array = []
	var current_text: String = WRITER.stringify(candidate.autosave_document.current_snapshot)["value"]
	assert_false(actual.port._splice_autosave_text(candidate.autosave_document, current_text, raw, documents).is_empty())
	assert_eq(documents.size(), 2)
	assert_eq(str(documents[0].snapshot.checkpoint_id), str(raw[0].snapshot.checkpoint_id))
	assert_eq(str(documents[1].snapshot.checkpoint_id), str(raw[1].snapshot.checkpoint_id))
	var documents_before := var_to_bytes(documents)
	var detached := DOCUMENT._validate_outgoing_document_proofs(candidate.autosave_document, raw, documents)
	assert_true(detached.get("ok", false))
	detached["value"]["candidate"]["recovery_journal"][0]["snapshot"]["gameplay"]["money"] = 888888
	assert_eq(var_to_bytes(documents), documents_before, "schema composition detaches journal-owned proofs")
	# These defensive fallback states cannot be produced by a successful port collection, but must
	# not turn a partial proof set into a trusted lease if the internal adapter receives one.
	for incomplete: Array in [[], [documents[0]], [documents[0], {}]]:
		var fallback := DOCUMENT._validate_outgoing_document_proofs(candidate.autosave_document, raw, incomplete)
		var original := DOCUMENT.validate_outgoing(candidate.autosave_document, raw)
		assert_true(WRITER._deep_same(fallback["value"], original["value"]), "incomplete proof set keeps raw behavior")
	OS.set_environment(PROFILE_ENV, "1")
	var committed: Dictionary = actual.port.commit(candidate)
	OS.unset_environment(PROFILE_ENV)
	var original: Dictionary = reference.port.commit(control)
	assert_true(committed.get("ok", false))
	assert_eq(committed, original)
	assert_eq(var_to_bytes(candidate), before, "commit does not mutate caller candidate")
	assert_eq(var_to_bytes(documents), documents_before, "commit never mutates borrowed proof documents")
	_assert_same_state(actual, reference)
	var written := _assert_lease(actual)
	assert_eq(int(written.recovery_journal[0].snapshot.gameplay.money), 102, "first written proof follows selected id/order")
	assert_eq(int(written.recovery_journal[1].snapshot.gameplay.money), 101, "edited caller history cannot replace proof bytes")

func test_text_only_and_partial_document_proofs_keep_complete_commit_equivalence() -> void:
	for mode: String in ["text_only", "partial"]:
		var actual := _wired()
		var reference := _wired(true)
		for money: int in [201, 202]:
			_commit_pair(actual, reference, money)
			if mode == "text_only" or money == 202:
				for wired: Dictionary in [actual, reference]:
					var current: Dictionary = wired.manager._journal.get_current_bundle()["value"]["bundle"]
					var checkpoint_id := str(current.snapshot.checkpoint_id)
					var text: String = wired.manager._journal.get_retained_bundle_text(checkpoint_id)
					assert_true(wired.manager._journal.remember_committed_bundle_text(checkpoint_id, text))
					assert_true(wired.manager._journal.get_retained_bundle_document(checkpoint_id).is_empty())
		_commit_pair(actual, reference, 203)
	# A caller can edit both issued copies. Preserve that existing write/text outcome without
	# treating an integral-float text as a proof for the schema's normalized integer document.
	var widened := _wired()
	var widened_reference := _wired(true)
	for wired: Dictionary in [widened, widened_reference]:
		var prepared := _prepare(wired, 204)
		prepared.autosave_document.current_snapshot.snapshot["content_version"] = float(wired.snapshot.content_version)
		prepared.journal_candidate.current.snapshot["content_version"] = float(wired.snapshot.content_version)
		assert_true(wired.port.commit(prepared).get("ok", false))
	_assert_same_state(widened, widened_reference)
	_assert_lease(widened)
	var widened_id: String = widened.manager._journal.get_current_bundle()["value"]["bundle"].snapshot.checkpoint_id
	assert_false(widened.manager._journal.get_retained_bundle_text(widened_id).is_empty(), "existing text proof survives")
	assert_true(widened.manager._journal.get_retained_bundle_document(widened_id).is_empty(),
		"numeric normalization cannot become a document proof for differently typed emitted values")

func test_reset_restore_and_seed_drop_proofs_before_the_next_complete_write() -> void:
	for operation: String in ["reset", "restore", "seed", "numeric_history"]:
		var actual := _wired()
		var reference := _wired(true)
		for money: int in [301, 302]: _commit_pair(actual, reference, money)
		for wired: Dictionary in [actual, reference]:
			var journal: RefCounted = wired.manager._journal
			var current: Dictionary = journal.get_current_bundle()["value"]["bundle"]
			var checkpoint_id := str(current.snapshot.checkpoint_id)
			assert_false(journal.get_retained_bundle_document(checkpoint_id).is_empty())
			if operation == "reset":
				assert_true(journal.reset(str(current.snapshot.run_id)).get("ok", false))
			elif operation in ["restore", "numeric_history"]:
				assert_true(journal.restore_state(journal.capture_state()["value"]["backup"]).get("ok", false))
			else:
				var document := _assert_lease(wired)
				var seeded: Dictionary = journal.prepare_seed(document, current)
				assert_true(seeded.get("ok", false))
				assert_true(journal.commit_prepared(seeded["value"]["candidate"]).get("ok", false))
			assert_eq(journal.get_retained_bundle_text(checkpoint_id), "", operation + " forgets text")
			assert_true(journal.get_retained_bundle_document(checkpoint_id).is_empty(), operation + " forgets document")
		var original_region := ""
		for wired: Dictionary in [actual, reference]:
			var prepared := _prepare(wired, 303)
			for bundle: Dictionary in prepared.autosave_document.recovery_journal:
				_edit_equal_engine_containers(bundle)
			if operation == "numeric_history":
				var history: Array = prepared.autosave_document.recovery_journal
				var original_bundle: Dictionary = history[0].duplicate(true)
				original_region = WRITER.stringify(original_bundle)["value"]
				history[0]["snapshot"]["content_version"] = float(original_bundle.snapshot.content_version)
				# A normalized integer region exists elsewhere in these same written bytes. It
				# must not override the original widened entry's retained-value refusal.
				history[1]["snapshot"]["audio_context"] = {"nested_original": original_bundle}
			assert_true(wired.port.commit(prepared).get("ok", false))
		_assert_same_state(actual, reference)
		_assert_lease(actual)
		for bundle: Dictionary in actual.manager._journal.get_bundles_for_disk():
			var proof: Dictionary = actual.manager._journal.get_retained_bundle_document(str(bundle.snapshot.checkpoint_id))
			if operation == "numeric_history":
				assert_true(proof.is_empty(), "widened or edited history retains its original proof refusal")
			else:
				assert_false(proof.is_empty(), "cold full writer learns a reusable normalized document")
				_assert_document_shape(proof)
				# Exercise the producer itself with equal typed containers and String keys. The
				# port owns StringName normalization; the journal must not borrow caller containers.
				var checkpoint_id := str(bundle.snapshot.checkpoint_id)
				var supplied := proof.duplicate(true)
				var effects: Array[String] = []
				var audio: Dictionary[String, String] = {}
				supplied.snapshot["applied_effect_transaction_ids"] = effects
				supplied.snapshot["audio_context"] = audio
				var original_input := var_to_bytes(supplied)
				var proof_text: String = actual.manager._journal.get_retained_bundle_text(checkpoint_id)
				assert_true(actual.manager._journal.remember_written_retained_bundle(checkpoint_id, proof_text, supplied))
				assert_true(reference.manager._journal.remember_written_retained_bundle(checkpoint_id, proof_text, supplied))
				assert_eq(var_to_bytes(supplied), original_input, "proof learning leaves its caller input untouched")
				proof = actual.manager._journal.get_retained_bundle_document(checkpoint_id)
				_assert_document_shape(proof)
				var old_proof: Dictionary = reference.manager._journal.get_retained_bundle_document(checkpoint_id)
				assert_true((old_proof.snapshot.applied_effect_transaction_ids as Array).is_typed(),
					"frozen producer reproduces the typed-container obligation")
				var proof_before := var_to_bytes(proof)
				supplied.snapshot.gameplay["money"] = 777777
				effects.append("caller-mutation")
				audio["caller"] = "mutation"
				assert_eq(var_to_bytes(actual.manager._journal.get_retained_bundle_document(checkpoint_id)), proof_before,
					"validated proof owns detached nested dictionaries and typed source containers")
		if operation == "numeric_history":
			var text: String = actual.files.snapshot_persisted()[FINAL].get_string_from_utf8()
			assert_gte(text.find(original_region), 0, "the tempting normalized region was really written elsewhere")
		_commit_pair(actual, reference, 304)

func test_a_partial_failed_splice_cannot_seed_the_full_writer_with_stale_proofs() -> void:
	var actual := _wired()
	var reference := _wired(true)
	for money: int in [401, 402]: _commit_pair(actual, reference, money)
	var candidate := _prepare(actual, 403)
	var control := _prepare(reference, 403)
	for prepared: Dictionary in [candidate, control]:
		prepared.autosave_document.recovery_journal[1]["snapshot"]["checkpoint_id"] = "missing-proof:99"
		prepared.autosave_document.recovery_journal[1]["snapshot"]["gameplay"]["money"] = 444444
	var raw: Array = []
	var documents: Array = []
	var text: String = WRITER.stringify(candidate.autosave_document.current_snapshot)["value"]
	assert_eq(actual.port._splice_autosave_text(candidate.autosave_document, text, raw, documents), "")
	assert_eq(raw.size(), 1, "first raw proof was collected before the missing text")
	assert_eq(documents.size(), 1, "first normalized proof was collected before the missing text")
	assert_true(actual.port.commit(candidate).get("ok", false))
	assert_true(reference.port.commit(control).get("ok", false))
	_assert_same_state(actual, reference)
	var written := _assert_lease(actual)
	assert_eq(str(written.recovery_journal[1].snapshot.checkpoint_id), "missing-proof:99")
	assert_eq(int(written.recovery_journal[1].snapshot.gameplay.money), 444444,
		"full writer and lease retain the supplied history when any splice text is missing")

func test_warm_proofs_preserve_schema_refusals_and_physical_failure_custody() -> void:
	for failure: String in ["shape", "current", "physical", "corrupt_final"]:
		var actual := _wired()
		var reference := _wired(true)
		for money: int in [501, 502]: _commit_pair(actual, reference, money)
		var candidate := _prepare(actual, 503)
		var control := _prepare(reference, 503)
		for prepared: Dictionary in [candidate, control]:
			if failure == "shape":
				prepared.autosave_document["unknown"] = true
				prepared.autosave_document["current_snapshot"] = "also invalid"
			elif failure == "current":
				prepared.autosave_document.current_snapshot.snapshot.gameplay["narrative_variables"] = "invalid"
		for wired: Dictionary in [actual, reference]:
			if failure == "physical": wired.files.fail_after(wired.files.operation_count() + 1)
			elif failure == "corrupt_final": wired.files._persisted[FINAL] = "{broken".to_utf8_buffer()
		var journal_before := var_to_bytes(actual.manager._journal.capture_state())
		var refused: Dictionary = actual.port.commit(candidate)
		var original: Dictionary = reference.port.commit(control)
		assert_false(refused.get("ok", true), failure + " must fail")
		assert_eq(refused, original, "same complete refusal and precedence: " + failure)
		assert_eq(var_to_bytes(actual.manager._journal.capture_state()), journal_before, "failed write cannot advance journal")
		_assert_same_state(actual, reference)
