extends SceneTree
## Matched history learning and complete commit with a real journal/storage protocol.
## FakeFileOps is the physical boundary; this does not measure disk or gameplay latency.
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const CANON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/CheckpointJournal.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const REFERENCE := preload("res://tests/support/HistoryRegionSearchReference.gd")
const ROOT := "history-region-benchmark"

class Manager extends RefCounted:
	var _journal := JOURNAL.new()
	var _storage: RefCounted
	var _restore_participants := {}

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
	if not _require(variant in ["baseline", "candidate"] and mode in ["cold", "mixed"], "known variant/mode required"): return
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
	var seed_journal := JOURNAL.new()
	var seeded := seed_journal.prepare_seed(document, document["current_snapshot"])
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
	var present_count := 51 if mode == "mixed" else 0
	var expected_seed := manifest.slice(0, present_count)
	var input_before := var_to_bytes(document)
	var final_before := var_to_bytes(final_state)
	var prior_before := var_to_bytes(prior_state)
	var samples := {"learning_seam": [], "port_commit_fake_io": []}
	var evidence := {}
	for metric: String in samples:
		for index: int in 7:
			var manager := Manager.new()
			var files := FILES.new({ROOT + "/autosave.json": text})
			manager._storage = STORAGE.new(ROOT, files)
			var port: RefCounted = REFERENCE.new(manager) if variant == "baseline" else PORT.new(manager)
			if not _require(port.configure_fatal_latch(GATE.new()).get("ok", false), "port gate"): return
			var state: Dictionary = final_state if metric == "learning_seam" else prior_state
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
			var candidate_before := var_to_bytes(candidate)
			var started := Time.get_ticks_usec()
			var committed := {"ok": true}
			if metric == "learning_seam":
				port._remember_written_history(bundles, text)
			else:
				committed = port.commit(candidate)
			var elapsed := Time.get_ticks_usec() - started
			# Every setup, fixture/evidence emission, proof comparison and physical trace check is outside
			# timing. Each iteration gets a fresh port, journal, storage and physical adapter.
			if not _require(committed.get("ok", false), "complete commit: " + str(committed.get("code", ""))): return
			if not _verify_proofs(manager._journal, bundles, expected_texts, 66): return
			if not _require(CANON._deep_same(manager._journal.capture_state()["value"]["backup"], final_state),
				"exact final journal including current and all 66 history bundles"): return
			if not _require(var_to_bytes(candidate) == candidate_before, "candidate unchanged"): return
			var physical: Dictionary = files.snapshot_persisted()
			if not _require(physical.has(ROOT + "/autosave.json")
				and physical[ROOT + "/autosave.json"] == text.to_utf8_buffer(), "exact final physical bytes"): return
			var trace: Array = files.operation_trace()
			if metric == "learning_seam":
				if not _require(trace.is_empty() and physical.size() == 1, "learning seam has no storage operations"): return
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
			var observation := {"physical_files": physical_manifest, "operation_trace": trace,
				"journal_sha256": _hash(manager._journal.capture_state()["value"]["backup"])}
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
		"reference_method_sha256": REFERENCE.METHOD_SHA256,
		"candidate_port_source_sha256": FileAccess.get_file_as_string("res://" + REFERENCE.PORT_SOURCE_PATH).sha256_text(),
		"timing_boundary": "Independent direct learning call and complete port.commit call, with nested profiling disabled; preparation, proof setup and result verification are outside timing.",
		"scope": "Real CheckpointJournal and JsonFileStorage protocol; FakeFileOps physical boundary. Synthetic retained prestate, no public port.prepare/live capture, no physical disk or gameplay/input-to-paint comparison."}
	for metric: String in samples:
		var ordered: Array = samples[metric].duplicate()
		ordered.sort()
		report[metric + "_samples_us"] = samples[metric]
		report[metric + "_median_us"] = ordered[2]
	if _failed: return
	print("HISTORY_REGION_SEARCH_BENCHMARK: " + JSON.stringify(report))
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

func _hash(value: Variant) -> String:
	var emitted := CANON.stringify(value)
	if not _require(emitted.get("ok", false), "canonical evidence hash"): return ""
	return str(emitted["value"]).sha256_text()

func _require(accepted: bool, message: String) -> bool:
	if not accepted:
		_failed = true
		printerr("HISTORY_REGION_SEARCH_FAIL: " + message)
		quit(1)
	return accepted
