extends SceneTree
## Matched-payload proof of the checkpoint port's outgoing normalization/validation seam.
## The baseline port lacks the new helper and uses its original complete-document walk.

const STRICT := preload("res://scripts/validation/StrictJson.gd")
const CANON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var document := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--document="): document = argument.trim_prefix("--document=")
	if not _require(not document.is_empty() and FileAccess.file_exists(document), "existing fixed document required"): return
	var text := FileAccess.get_file_as_string(document)
	var parsed := STRICT.parse_object(text)
	if not _require(parsed.get("ok", false), "fixed payload strict parse"): return
	var validated := SCHEMA.validate(parsed.value)
	if not _require(validated.get("ok", false), "fixed payload schema"): return
	var proofs: Array = validated.value.candidate.recovery_journal
	var port: RefCounted = PORT.new()
	var candidate := port.has_method("_normalize_outgoing_document")
	var samples: Array[int] = []
	for index: int in 7:
		var started := Time.get_ticks_usec()
		var normalized: Variant
		if candidate:
			normalized = port.call("_normalize_outgoing_document", parsed.value, true)
		else:
			normalized = port._normalize_json_string_types(parsed.value)
		var outgoing := SCHEMA.validate_outgoing(normalized, proofs)
		var elapsed := Time.get_ticks_usec() - started
		if not _require(outgoing.get("ok", false)
			and CANON._deep_same(outgoing.value, validated.value), "outgoing value exactly equals full validation"): return
		var emitted := CANON.stringify(outgoing.value.candidate)
		if not _require(emitted.get("ok", false) and str(emitted.value) + "\n" == text, "outgoing exact canonical bytes"): return
		# First two executions warm the engine; five samples are retained on identical bytes.
		if index >= 2: samples.append(elapsed)
	var ordered := samples.duplicate()
	ordered.sort()
	print("OUTGOING_NORMALIZATION_BENCHMARK: " + JSON.stringify({
		"variant": "candidate" if candidate else "baseline", "samples_us": samples,
		"median_us": ordered[2], "input_sha256": text.sha256_text(),
		"output_sha256": text.sha256_text(), "bytes": text.to_utf8_buffer().size(),
		"journal_bundles": proofs.size(),
		"proof_source": "full validation of fixed bytes; seam measurement, not evidence that gameplay had a complete splice proof set"}))
	quit(0)

func _require(accepted: bool, message: String) -> bool:
	if not accepted:
		printerr("OUTGOING_NORMALIZATION_FAIL: " + message)
		quit(1)
	return accepted
