extends SceneTree
## Matched helper costs. The port seam uses the SAME current outgoing schema in both variants.
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const CANON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const EAGER := preload("res://tests/support/EagerNormalizationReference.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
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
	if not _require(variant in ["baseline", "candidate"] and mode in ["full", "splice"], "known variant/mode required"): return
	var text := FileAccess.get_file_as_string(path)
	var parsed := STRICT.parse_object(text)
	if not _require(parsed.get("ok", false), "fixed payload strict parse"): return
	var document: Dictionary = parsed["value"]
	var validated := SCHEMA.validate(document)
	if not _require(validated.get("ok", false), "fixed payload schema"): return
	var proofs: Array = validated["value"]["candidate"]["recovery_journal"]
	if not _require(proofs.size() == 66, "all 66 retained bundles required"): return
	for index: int in proofs.size():
		if not _require(SCHEMA._validate_bundle(proofs[index]).get("ok", false), "strict retained bundle " + str(index)): return
	var helper_input: Dictionary = document
	if mode == "splice":
		helper_input = document.duplicate()
		helper_input["recovery_journal"] = []
	var helper_text := CANON.stringify(helper_input)
	if not _require(helper_text.get("ok", false), "canonical helper input"): return
	var before := var_to_bytes(document)
	var helper_before := var_to_bytes(helper_input)
	var schema_normalizer: Callable = EAGER._normalize_engine_text if variant == "baseline" else SCHEMA._normalize_engine_text
	var port_normalizer: Callable = EAGER._normalize_json_string_types if variant == "baseline" else PORT._normalize_json_string_types
	for normalize: Callable in [schema_normalizer, port_normalizer]:
		var kept := {"untouched": [1, 1.0]}
		var changed := {&"caption": &"sample", "kept": kept}
		var changed_before := var_to_bytes(changed)
		var converted: Dictionary = normalize.call(changed)
		if not _require(not is_same(converted, changed) and typeof(converted.keys()[0]) == TYPE_STRING
			and typeof(converted["caption"]) == TYPE_STRING and is_same(converted["kept"], kept)
			and var_to_bytes(changed) == changed_before, "changed path identity/types and source preservation"): return
	var samples := {"schema_helper": [], "port_helper": [], "port_seam": []}
	for index: int in 7:
		var tick := Time.get_ticks_usec()
		var schema_result: Variant = schema_normalizer.call(helper_input)
		var schema_us := Time.get_ticks_usec() - tick
		tick = Time.get_ticks_usec()
		var port_result: Variant = port_normalizer.call(helper_input)
		var port_us := Time.get_ticks_usec() - tick
		tick = Time.get_ticks_usec()
		var seam_input: Dictionary = port_normalizer.call(helper_input)
		var outgoing := SCHEMA.validate_outgoing(seam_input, proofs)
		var seam_us := Time.get_ticks_usec() - tick
		# All equality, strict-output and source checks are outside every timed region.
		if not _require(is_same(schema_result, helper_input) and is_same(port_result, helper_input)
			and is_same(seam_input, helper_input), "clean JSON retains its exact container identity"): return
		if not _require(outgoing.get("ok", false)
			and CANON._deep_same(outgoing["value"], validated["value"]), "same strict outgoing value"): return
		var emitted := CANON.stringify(outgoing["value"]["candidate"])
		if not _require(emitted.get("ok", false) and str(emitted["value"]) + "\n" == text, "exact original canonical bytes"): return
		if index >= 2:
			samples["schema_helper"].append(schema_us)
			samples["port_helper"].append(port_us)
			samples["port_seam"].append(seam_us)
	if not _require(var_to_bytes(document) == before and var_to_bytes(helper_input) == helper_before,
		"source objects unchanged after all samples"): return
	var report := {
		"variant": variant, "mode": mode, "warmup_count": 2, "sample_count": 5,
		"input_sha256": text.sha256_text(), "output_sha256": text.sha256_text(), "bytes": text.to_utf8_buffer().size(),
		"helper_input_sha256": str(helper_text["value"]).sha256_text(),
		"helper_input_bytes": str(helper_text["value"]).to_utf8_buffer().size(),
		"journal_bundles": proofs.size(), "validated_journal_bundles": proofs.size(),
		"schema_version": document["schema_version"],
		"snapshot_schema_version": document["current_snapshot"]["snapshot"]["schema_version"],
		"identity_preserved_unchanged": true, "identity_replaced_changed": true, "source_unchanged": true,
		"reference_commit": EAGER.SOURCE_COMMIT,
		"reference_schema_source_sha256": EAGER.SCHEMA_SOURCE_SHA256,
		"reference_port_source_sha256": EAGER.PORT_SOURCE_SHA256,
		"reference_schema_helper_sha256": EAGER.SCHEMA_HELPER_SHA256,
		"reference_port_helper_sha256": EAGER.PORT_HELPER_SHA256,
		"candidate_schema_source_sha256": FileAccess.get_file_as_string("res://" + EAGER.SCHEMA_SOURCE_PATH).sha256_text(),
		"candidate_port_source_sha256": FileAccess.get_file_as_string("res://" + EAGER.PORT_SOURCE_PATH).sha256_text(),
		"timing_boundary": "Direct helper calls; port seam additionally includes the same current strict outgoing validator. Proof creation, envelope construction, emission and equality checks are outside timing.",
		"proof_source": "Strict validation of all bundles in this identical fixed JSON payload, not gameplay proof-cache evidence.",
		"seam_limitation": "Only direct port normalization differs. This is not a matched schema-build, full checkpoint, physical-write or frame-time comparison."
	}
	for metric: String in samples:
		var ordered: Array = samples[metric].duplicate()
		ordered.sort()
		report[metric + "_samples_us"] = samples[metric]
		report[metric + "_median_us"] = ordered[2]
	print("LAZY_NORMALIZATION_BENCHMARK: " + JSON.stringify(report))
	quit(0)

func _require(accepted: bool, message: String) -> bool:
	if not accepted:
		printerr("LAZY_NORMALIZATION_FAIL: " + message)
		quit(1)
	return accepted
