extends SceneTree

const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const DOCUMENT_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

# Read-only diagnostic. Root runs with -- --source=<absolute autosave.json>.
func _initialize() -> void:
	var source := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source="):
			source = argument.trim_prefix("--source=")
	if source.is_empty() or not source.is_absolute_path():
		_finish({"ok": false, "code": "absolute_source_required"})
		return
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null:
		_finish({"ok": false, "code": "source_open_failed", "error": FileAccess.get_open_error()})
		return
	var text: String = file.get_as_text()
	file.close()
	var report := {"source": source, "bytes": text.to_utf8_buffer().size()}
	var started := Time.get_ticks_usec()
	var parsed: Dictionary = STRICT_JSON.parse_object(text)
	report["strict_parse_us"] = Time.get_ticks_usec() - started
	report["strict_parse_ok"] = bool(parsed.get("ok", false))
	if not parsed.get("ok", false):
		report["failure"] = parsed
		_finish(report)
		return
	started = Time.get_ticks_usec()
	var validated: Dictionary = DOCUMENT_SCHEMA.validate(parsed["value"])
	report["schema_validate_us"] = Time.get_ticks_usec() - started
	report["schema_validate_ok"] = bool(validated.get("ok", false))
	if not validated.get("ok", false):
		report["failure"] = validated
		_finish(report)
		return
	started = Time.get_ticks_usec()
	var emitted: Dictionary = CANONICAL_JSON.stringify(validated["value"]["candidate"])
	report["canonical_stringify_us"] = Time.get_ticks_usec() - started
	report["canonical_stringify_ok"] = bool(emitted.get("ok", false))
	if not emitted.get("ok", false):
		report["failure"] = emitted
		_finish(report)
		return
	report["emitted_bytes"] = str(emitted["value"]).to_utf8_buffer().size()
	report["source_sha256"] = text.sha256_text()
	report["canonical_sha256"] = str(emitted["value"]).sha256_text()
	report["canonical_matches_source"] = str(emitted["value"]) == text.trim_suffix("\n")
	started = Time.get_ticks_usec()
	var reparsed: Dictionary = STRICT_JSON.parse_object(emitted["value"])
	report["emitted_strict_parse_us"] = Time.get_ticks_usec() - started
	report["emitted_strict_parse_ok"] = bool(reparsed.get("ok", false))
	report["ok"] = bool(reparsed.get("ok", false))
	_finish(report)

func _finish(report: Dictionary) -> void:
	print("DWM_RETAINED_SAVE_BENCHMARK " + JSON.stringify(report))
	quit(0 if report.get("ok", false) else 1)
