extends SceneTree
## Read-only microbenchmark of an actual save captured by the isolated click benchmark.
## Usage: -- --document=<absolute or res:// path to autosave.json>
## Reuse exactly the same file before/after a change; hashes identify the measured bytes.

const STRICT := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var document := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--document="):
			document = argument.trim_prefix("--document=")
	if document.is_empty() or not FileAccess.file_exists(document):
		_fail("An existing --document path is required")
		return
	var text := FileAccess.get_file_as_string(document)
	# The document schema deliberately tolerates malformed historical fallback entries.
	# These benchmark proofs must instead all be strict current snapshots, outside timing.
	var preflight := STRICT.parse_object(text)
	if not preflight.get("ok", false) or not SCHEMA.validate(preflight.value).get("ok", false):
		_fail("Fixed payload preflight failed")
		return
	for index: int in preflight.value.recovery_journal.size():
		var bundle: Dictionary = preflight.value.recovery_journal[index]
		var bundle_check := SCHEMA._validate_bundle(bundle)
		if not bundle_check.get("ok", false):
			_fail("Retained benchmark bundle %d refused: %s %s" % [index,
				bundle_check.get("code", ""), bundle_check.get("message", "")])
			return
	var samples := {"parse_us": [], "schema_us": [], "stringify_us": [], "value_validation_us": [],
		"outgoing_validation_us": []}
	var output_hash := ""
	var journal_bundles := 0
	for attempt: int in 5:
		var started := Time.get_ticks_usec()
		var parsed := STRICT.parse_object(text)
		var parsed_at := Time.get_ticks_usec()
		if not parsed.get("ok", false):
			_fail("Strict parse failed: " + str(parsed))
			return
		var validated := SCHEMA.validate(parsed.value)
		var validated_at := Time.get_ticks_usec()
		if not validated.get("ok", false):
			_fail("Save schema failed: " + str(validated))
			return
		var emitted := CANONICAL.stringify(parsed.value)
		var emitted_at := Time.get_ticks_usec()
		if not emitted.get("ok", false) or str(emitted.value) + "\n" != text:
			_fail("Canonical output must match this save's exact input bytes")
			return
		var value_started := Time.get_ticks_usec()
		var direct := SCHEMA.validate(CHECKPOINT_PORT._normalize_json_string_types(parsed.value))
		var value_validated_at := Time.get_ticks_usec()
		if not direct.get("ok", false) or not CANONICAL._deep_same(direct.value, validated.value):
			_fail("Direct value validation must equal strict parse plus schema validation")
			return
		# These bundles came from full validation of the exact measured save. Production
		# supplies its journal-owned proofs after their own byte-verified commits.
		var proofs: Array = validated.value.candidate.recovery_journal
		journal_bundles = proofs.size()
		var outgoing_started := Time.get_ticks_usec()
		var outgoing := SCHEMA.validate_outgoing(parsed.value, proofs)
		var outgoing_validated_at := Time.get_ticks_usec()
		if not outgoing.get("ok", false) or not CANONICAL._deep_same(outgoing.value, validated.value):
			_fail("Outgoing proven-journal validation must equal full validation")
			return
		output_hash = (str(emitted.value) + "\n").sha256_text()
		samples.parse_us.append(parsed_at - started)
		samples.schema_us.append(validated_at - parsed_at)
		samples.stringify_us.append(emitted_at - validated_at)
		samples.value_validation_us.append(value_validated_at - value_started)
		samples.outgoing_validation_us.append(outgoing_validated_at - outgoing_started)
	var report := {"bytes": text.to_utf8_buffer().size(), "input_sha256": text.sha256_text(),
		"output_sha256": output_hash, "journal_bundles": journal_bundles, "samples": samples,
		"validated_journal_bundles": preflight.value.recovery_journal.size(),
		"schema_version": preflight.value.schema_version,
		"snapshot_schema_version": preflight.value.current_snapshot.snapshot.schema_version}
	for phase: String in samples:
		var ordered: Array = samples[phase].duplicate()
		ordered.sort()
		report[phase + "_median"] = ordered[ordered.size() / 2]
	print("CHECKPOINT_JSON_BENCHMARK: " + JSON.stringify(report))
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
