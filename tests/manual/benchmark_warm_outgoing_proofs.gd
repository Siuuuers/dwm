extends SceneTree
## Independent outgoing schema composition and complete commit on an identical saturated payload.
## Composition always receives all 66 trusted raw bundles; modes vary normalized document proofs.
## Complete commit uses the same proof availability in the real journal and therefore exercises
## whole-document fallback in cold/mixed modes and the splice in warm mode.
## FakeFileOps is the physical boundary; this does not measure disk or gameplay latency.
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const CANON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/CheckpointJournal.gd")
const JOURNAL_REFERENCE := preload("res://tests/support/WarmOutgoingJournalReference.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const REFERENCE := preload("res://tests/support/WarmOutgoingProofReference.gd")
const ROOT := "warm-outgoing-proof-benchmark"

class Manager extends RefCounted:
	var _journal: RefCounted
	var _storage: RefCounted
	var _restore_participants := {}
	func _init(reference: bool = false) -> void:
		_journal = JOURNAL_REFERENCE.new() if reference else JOURNAL.new()

var _failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# No nested phase timers or their log emission belong to either measured boundary.
	OS.unset_environment("DWM_CHECKPOINT_PROFILE")
	var arguments := {}
	for argument: String in OS.get_cmdline_user_args():
		for key: String in ["document", "variant", "mode"]:
			if argument.begins_with("--" + key + "="):
				if not _require(not arguments.has(key), "duplicate " + key): return
				arguments[key] = argument.trim_prefix("--" + key + "=")
	var path := str(arguments.get("document", ""))
	var variant := str(arguments.get("variant", ""))
	var mode := str(arguments.get("mode", ""))
	if not _require(FileAccess.file_exists(path), "existing fixed document required"): return
	if not _require(variant in ["baseline", "candidate"] and mode in ["cold", "mixed", "warm"], "known variant/mode required"): return
	var text := FileAccess.get_file_as_string(path)
	var parsed := STRICT.parse_object(text)
	if not _require(parsed.get("ok", false), "fixed payload strict parse"): return
	var document: Dictionary = parsed["value"]
	var validated := SCHEMA.validate(document)
	if not _require(validated.get("ok", false), "fixed payload schema"): return
	var canonical := CANON.stringify(document)
	if not _require(canonical.get("ok", false) and str(canonical["value"]) + "\n" == text,
		"input is the exact canonical outgoing byte sequence"): return
	var bundles: Array = document["recovery_journal"]
	if not _require(bundles.size() == 66 and int(document["current_snapshot"]["snapshot"]["lifecycle"]["day"]) == 7,
		"saturated Day7 payload required"): return
	var expected_texts: Array[String] = []
	var manifest: Array = []
	var kinds := {"line": 0, "manual_save": 0, "semantic": 0}
	for bundle: Dictionary in bundles:
		if not _require(SCHEMA._validate_bundle(bundle).get("ok", false), "strict retained bundle"): return
		var emitted := CANON.stringify(bundle)
		if not _require(emitted.get("ok", false), "canonical retained bundle"): return
		var bundle_text := str(emitted["value"])
		expected_texts.append(bundle_text)
		manifest.append({"checkpoint_id": str(bundle["snapshot"]["checkpoint_id"]),
			"text_sha256": bundle_text.sha256_text(), "bytes": bundle_text.to_utf8_buffer().size()})
		var kind := str(bundle["checkpoint_kind"])
		var bucket := kind if kind in ["line", "manual_save"] else "semantic"
		kinds[bucket] += 1
	if not _require(kinds == {"line": 32, "manual_save": 32, "semantic": 2}, "unchanged retention classes"): return
	var seed_journal: RefCounted = JOURNAL_REFERENCE.new() if variant == "baseline" else JOURNAL.new()
	var seeded: Dictionary = seed_journal.prepare_seed(document, document["current_snapshot"])
	if not _require(seeded.get("ok", false) and seeded["value"]["diagnostics"].is_empty(), "strict complete seed"): return
	if not _require(seed_journal.commit_prepared(seeded["value"]["candidate"]).get("ok", false), "seed commit"): return
	var final_state: Dictionary = seed_journal.capture_state()["value"]["backup"]
	if not _require(CANON._deep_same(final_state["earlier"], bundles), "seed retains exact 66 in order"): return
	# Synthetic pre-commit fixture, derived only from strictly validated retained bundles. The
	# public journal preparation below reconstructs the exact original current plus all 66 earlier
	# bundles. Port prepare / live capture and physical disk are deliberately outside this scope.
	var prior_state := final_state.duplicate(true)
	prior_state["current"] = prior_state["earlier"].pop_back()
	prior_state["next_sequence"] = int(document["current_snapshot"]["snapshot"]["checkpoint_sequence"])
	var present_count := 66 if mode == "warm" else (51 if mode == "mixed" else 0)
	var expected_seed := manifest.slice(0, present_count)
	var input_before := var_to_bytes(document)
	var final_before := var_to_bytes(final_state)
	var prior_before := var_to_bytes(prior_state)
	var samples := {"schema_composition": [], "port_commit_fake_io": []}
	var evidence := {}
	for metric: String in samples:
		for index: int in 7:
			var manager := Manager.new(variant == "baseline")
			var files := FILES.new({ROOT + "/autosave.json": text})
			manager._storage = STORAGE.new(ROOT, files)
			var port: RefCounted = REFERENCE.new(manager) if variant == "baseline" else PORT.new(manager)
			if not _require(port.configure_fatal_latch(GATE.new()).get("ok", false), "port gate"): return
			var state: Dictionary = final_state if metric == "schema_composition" else prior_state
			if not _require(manager._journal.restore_state(state).get("ok", false), "fresh journal state"): return
			for proof_index: int in present_count:
				var bundle: Dictionary = bundles[proof_index]
				if not _require(manager._journal.remember_written_retained_bundle(
					str(bundle["snapshot"]["checkpoint_id"]), expected_texts[proof_index], bundle), "seed exact proof"): return
			if not _verify_proofs(manager._journal, bundles, expected_texts, present_count): return
			var candidate := {}
			if metric == "port_commit_fake_io":
				var prepared: Dictionary = manager._journal.prepare_record(document["current_snapshot"]["snapshot"],
					StringName(str(document["current_snapshot"]["checkpoint_kind"])))
				if not _require(prepared.get("ok", false), "public journal preparation"): return
				candidate = {"journal_candidate": prepared["value"]["candidate"],
					"checkpoint_id": str(document["current_snapshot"]["snapshot"]["checkpoint_id"]),
					"autosave_document": document.duplicate(true), "storage_backup": null}
				var expected_state: Dictionary = candidate["journal_candidate"].duplicate(true)
				expected_state.erase("candidate_kind")
				if not _require(CANON._deep_same(expected_state, final_state), "exact prepared journal"): return
			# Direct composition excludes all proof collection, port normalization and setup. Every raw
			# bundle was independently strictly validated above. Missing document proofs deliberately
			# exercise the unchanged public raw-proof fallback, separately from cold commit behavior.
			var raw_proofs: Array = []
			var document_proofs: Array = []
			for bundle: Dictionary in bundles:
				var checkpoint_id := str(bundle["snapshot"]["checkpoint_id"])
				raw_proofs.append(manager._journal.get_retained_bundle(checkpoint_id))
				document_proofs.append(manager._journal.get_retained_bundle_document(checkpoint_id))
			var normalized: Dictionary = PORT._normalize_outgoing_document(document, true)
			var normalized_before := var_to_bytes(normalized)
			var raw_before := var_to_bytes(raw_proofs)
			var documents_before := var_to_bytes(document_proofs)
			var candidate_before := var_to_bytes(candidate)
			var started := Time.get_ticks_usec()
			var committed := {"ok": true}
			var composed := {}
			if metric == "schema_composition":
				composed = SCHEMA.validate_outgoing(normalized, raw_proofs) if variant == "baseline" else \
					SCHEMA._validate_outgoing_document_proofs(normalized, raw_proofs, document_proofs)
			else:
				committed = port.commit(candidate)
			var elapsed := Time.get_ticks_usec() - started
			# Every setup, fixture/evidence emission, proof comparison and physical trace check is outside
			# timing. Each iteration gets a fresh port, journal, storage and physical adapter.
			if not _require(committed.get("ok", false), "complete commit: " + str(committed.get("code", ""))): return
			var final_proof_count: int = present_count if metric == "schema_composition" else 66
			if not _verify_proofs(manager._journal, bundles, expected_texts, final_proof_count): return
			if not _require(CANON._deep_same(manager._journal.capture_state()["value"]["backup"], final_state),
				"exact final journal including current and all 66 history bundles"): return
			if not _require(var_to_bytes(candidate) == candidate_before, "candidate unchanged"): return
			var physical: Dictionary = files.snapshot_persisted()
			if not _require(physical.has(ROOT + "/autosave.json")
				and physical[ROOT + "/autosave.json"] == text.to_utf8_buffer(), "exact final physical bytes"): return
			var trace: Array = files.operation_trace()
			var composed_type_hash := ""
			if metric == "schema_composition":
				if not _require(composed.get("ok", false), "schema composition accepted"): return
				var output: Dictionary = composed["value"]["candidate"]
				if not _require(var_to_bytes(output) == var_to_bytes(validated["value"]["candidate"]),
					"exact composed values, order and Variant container/leaf types"): return
				var emitted := CANON.stringify(output)
				if not _require(emitted.get("ok", false) and str(emitted["value"]) + "\n" == text,
					"exact composed canonical bytes"): return
				composed_type_hash = _type_hash(output)
				if not _require(trace.is_empty() and physical.size() == 1, "schema composition has no storage operations"): return
			else:
				var current_text := str(CANON.stringify(document["current_snapshot"])["value"])
				var current_id := str(document["current_snapshot"]["snapshot"]["checkpoint_id"])
				if not _require(manager._journal.get_retained_bundle_text(current_id) == current_text
					and CANON._deep_same(manager._journal.get_retained_bundle_document(current_id), document["current_snapshot"]),
					"complete commit learns exact current proof"): return
				if not _require(not trace.is_empty(), "complete commit exercised physical adapter"): return
			var physical_manifest := {}
			for filename: String in physical:
				var hasher := HashingContext.new()
				hasher.start(HashingContext.HASH_SHA256)
				hasher.update(physical[filename])
				physical_manifest[filename] = hasher.finish().hex_encode()
			if not _require(var_to_bytes(normalized) == normalized_before and var_to_bytes(raw_proofs) == raw_before
				and var_to_bytes(document_proofs) == documents_before, "all input/proof objects remain unchanged"): return
			var proof_state: Array = []
			for bundle: Dictionary in bundles:
				var checkpoint_id := str(bundle["snapshot"]["checkpoint_id"])
				proof_state.append({"checkpoint_id": checkpoint_id,
					"text_sha256": manager._journal.get_retained_bundle_text(checkpoint_id).sha256_text(),
					"document_type_sha256": _type_hash(manager._journal.get_retained_bundle_document(checkpoint_id))})
			var observation := {"physical_files": physical_manifest, "operation_trace": trace,
				"journal_sha256": _hash(manager._journal.capture_state()["value"]["backup"]),
				"journal_type_sha256": _type_hash(manager._journal.capture_state()["value"]["backup"]),
				"proof_state": proof_state, "final_proof_count": final_proof_count,
				"composed_type_sha256": composed_type_hash, "raw_proof_type_sha256": _type_hash(raw_proofs)}
			if evidence.has(metric):
				if not _require(var_to_bytes(evidence[metric]) == var_to_bytes(observation), "identical state/files/trace across fresh samples"): return
			else:
				evidence[metric] = observation
			if index >= 2: samples[metric].append(elapsed)
	if not _require(var_to_bytes(document) == input_before and var_to_bytes(final_state) == final_before
		and var_to_bytes(prior_state) == prior_before and FileAccess.get_file_as_string(path) == text,
		"all source objects and original file unchanged"): return
	var report := {"variant": variant, "mode": mode, "warmup_count": 2, "sample_count": 5,
		"input_sha256": text.sha256_text(), "output_sha256": text.sha256_text(), "bytes": text.to_utf8_buffer().size(),
		"journal_bundles": bundles.size(), "validated_journal_bundles": bundles.size(), "retained": kinds,
		"schema_version": document["schema_version"],
		"snapshot_schema_version": document["current_snapshot"]["snapshot"]["schema_version"],
		"initial_proofs_present": present_count, "initial_proofs_missing": 66 - present_count,
		"proof_seed": expected_seed, "proof_seed_sha256": _hash(expected_seed),
		"final_proof_manifest": manifest, "final_proof_manifest_sha256": _hash(manifest),
		"prior_journal_sha256": _hash(prior_state), "final_journal_sha256": _hash(final_state),
		"source_unchanged": true, "exact_proof_strings_and_documents": true,
		"exact_physical_bytes": true, "evidence": evidence,
		"reference_commit": REFERENCE.SOURCE_COMMIT,
		"reference_port_source_sha256": REFERENCE.PORT_SOURCE_SHA256,
		"reference_schema_source_sha256": REFERENCE.SCHEMA_SOURCE_SHA256,
		"reference_commit_method_sha256": REFERENCE.COMMIT_METHOD_SHA256,
		"reference_splice_method_sha256": REFERENCE.SPLICE_METHOD_SHA256,
		"reference_validate_method_sha256": REFERENCE.VALIDATE_METHOD_SHA256,
		"reference_journal_commit": JOURNAL_REFERENCE.SOURCE_COMMIT,
		"reference_journal_source_sha256": JOURNAL_REFERENCE.JOURNAL_SOURCE_SHA256,
		"reference_remember_method_sha256": JOURNAL_REFERENCE.REMEMBER_METHOD_SHA256,
		"candidate_port_source_sha256": FileAccess.get_file_as_string("res://" + REFERENCE.PORT_SOURCE_PATH).sha256_text(),
		"candidate_schema_source_sha256": FileAccess.get_file_as_string("res://" + REFERENCE.SCHEMA_SOURCE_PATH).sha256_text(),
		"candidate_journal_source_sha256": FileAccess.get_file_as_string("res://" + JOURNAL_REFERENCE.JOURNAL_SOURCE_PATH).sha256_text(),
		"journal_reference_source_sha256": FileAccess.get_file_as_string("res://tests/support/WarmOutgoingJournalReference.gd").sha256_text(),
		"exact_composed_values_types_and_bytes": true,
		"timing_boundary": "Independent schema validator call and complete port.commit call, nested profiling disabled. Preparation, proof collection, port normalization for direct composition and result verification are outside timing.",
		"control_boundary": "Accepted226 commit/splice and journal proof-learning methods versus current methods; all other port/journal methods and the current public raw-proof schema path are shared. Each variant seeds its own journal implementation outside timing. Direct composition compares the public raw path with the private document-proof adapter.",
		"scope": "Direct composition always has 66 strictly proven raw bundles; normalized document proof availability is 0/51/66. Complete commit uses the same real journal proof count, so cold/mixed take whole-document fallback and warm takes splice. Real journal/storage protocol with FakeFileOps; no public port.prepare/live capture, physical disk or gameplay/input-to-paint comparison."}
	for metric: String in samples:
		var ordered: Array = samples[metric].duplicate()
		ordered.sort()
		report[metric + "_samples_us"] = samples[metric]
		report[metric + "_median_us"] = ordered[2]
	if _failed: return
	print("WARM_OUTGOING_PROOF_BENCHMARK: " + JSON.stringify(report))
	quit(0)

func _verify_proofs(journal: RefCounted, bundles: Array, texts: Array[String], present: int) -> bool:
	for index: int in bundles.size():
		var bundle: Dictionary = bundles[index]
		var checkpoint_id := str(bundle["snapshot"]["checkpoint_id"])
		var proof_text: String = journal.get_retained_bundle_text(checkpoint_id)
		var proof_document: Dictionary = journal.get_retained_bundle_document(checkpoint_id)
		if index < present:
			if not _require(proof_text == texts[index] and CANON._deep_same(proof_document, bundle), "exact text/document proof"): return false
		else:
			if not _require(proof_text.is_empty() and proof_document.is_empty(), "exact missing proof state"): return false
	return true

func _type_hash(value: Variant) -> String:
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(var_to_bytes(value))
	return hasher.finish().hex_encode()

func _hash(value: Variant) -> String:
	var emitted := CANON.stringify(value)
	if not _require(emitted.get("ok", false), "canonical evidence hash"): return ""
	return str(emitted["value"]).sha256_text()

func _require(accepted: bool, message: String) -> bool:
	if not accepted:
		_failed = true
		printerr("WARM_OUTGOING_PROOF_FAIL: " + message)
		quit(1)
	return accepted
