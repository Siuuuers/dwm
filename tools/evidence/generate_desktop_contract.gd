extends SceneTree

## Generator for evidence/phase_2r/handoff/desktop_contract.json (dwm-p2r.9 Plan 06 Task 3).
##
## Runs via `-s`, so this extends SceneTree and works in `_init()`. CONSEQUENCE FOR TESTS: probe
## this file with DynamicScriptProbe.load_script() or a preloaded const and NEVER instantiate() --
## instantiating constructs a SceneTree and executes the tool.
##
## Canonical-serializes to a same-directory temporary file, strict-parses and revalidates those
## exact bytes, then atomically promotes. An interrupted run therefore leaves either no artifact or
## a complete one, never a truncated one a later validator would have to interpret.

const EVIDENCE := preload("res://tools/evidence/DesktopContractEvidence.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")


func _init() -> void:
	var built: Dictionary = EVIDENCE.build()
	if not built.get("ok", false):
		_reject("BUILD", built)
		return
	var artifact: Dictionary = (built.get("value", {}) as Dictionary).get("artifact", {}) as Dictionary
	var canonical: Dictionary = EVIDENCE.canonical_bytes(artifact)
	if not canonical.get("ok", false):
		_reject("SERIALIZE", canonical)
		return
	var bytes: PackedByteArray = (canonical.get("value", {}) as Dictionary).get("bytes", PackedByteArray())
	var written: Dictionary = _publish(bytes)
	if not written.get("ok", false):
		_reject("WRITE", written)
		return
	print("DESKTOP_HANDOFF: GENERATED interface_version=%d" % EVIDENCE.INTERFACE_VERSION)
	quit(0)


func _publish(bytes: PackedByteArray) -> Dictionary:
	var absolute: String = ProjectSettings.globalize_path(EVIDENCE.ARTIFACT_PATH)
	var directory_error: int = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		return {"ok": false, "code": &"output_directory_failed",
			"message": "the output directory cannot be created", "details": {"error": directory_error}}
	var scratch: String = "%s.partial-%d" % [absolute, OS.get_process_id()]
	if FileAccess.file_exists(scratch):
		DirAccess.remove_absolute(scratch)
	var file: FileAccess = FileAccess.open(scratch, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "code": &"output_open_failed",
			"message": "the scratch artifact cannot be opened", "details": {"path": scratch}}
	file.store_buffer(bytes)
	file.flush()
	file.close()
	# Re-read and revalidate the EXACT bytes that will be promoted.
	var reread: PackedByteArray = FileAccess.get_file_as_bytes(scratch)
	if reread != bytes:
		DirAccess.remove_absolute(scratch)
		return {"ok": false, "code": &"output_reread_mismatch",
			"message": "the staged bytes differ from the serialization", "details": {}}
	var parsed: Dictionary = STRICT_JSON.parse_object(reread.get_string_from_utf8())
	if not parsed.get("ok", false):
		DirAccess.remove_absolute(scratch)
		return {"ok": false, "code": &"output_unparsable",
			"message": "the staged artifact is not a strict object",
			"details": {"message": str(parsed.get("message", ""))}}
	var revalidated: Dictionary = EVIDENCE.validate(parsed.get("value", {}) as Dictionary)
	if not revalidated.get("ok", false):
		DirAccess.remove_absolute(scratch)
		return revalidated
	var rename_error: int = DirAccess.rename_absolute(scratch, absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(scratch)
		return {"ok": false, "code": &"output_rename_failed",
			"message": "the artifact cannot be published atomically", "details": {"error": rename_error}}
	return {"ok": true, "code": &"ok", "value": {"path": EVIDENCE.ARTIFACT_PATH}}


func _reject(stage: String, envelope: Dictionary) -> void:
	printerr("DESKTOP_HANDOFF_%s_REJECTED: %s: %s" % [
		stage, str(envelope.get("code", &"")), str(envelope.get("message", "")),
	])
	quit(1)
