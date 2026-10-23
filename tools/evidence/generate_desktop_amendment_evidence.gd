extends SceneTree

## Generator for evidence/phase_2r/contracts/desktop_contract.json AND
## evidence/phase_2r/contracts/minesweeper_contract.json (dwm-p2r.32 Plan 02 Task 9,
## req.test.desktop_amendment_gate).
##
## Runs via `-s`, so this extends SceneTree and works in `_init()`, matching
## tools/evidence/generate_desktop_contract.gd and tools/schedule/generate_schedule_v3_boundary.gd.
## CONSEQUENCE FOR TESTS: probe this file with DynamicScriptProbe.load_script() or a preloaded
## const and NEVER instantiate() -- instantiating constructs a SceneTree and executes the tool.
##
## TWO CLOSED CLI FORMS, exactly one required:
##   --subject-commit=<40hex> --write   (builds and atomically publishes both documents)
##   --subject-commit=<40hex> --check   (rebuilds both documents fresh and compares byte-for-byte
##                                        against the already-published files; never opens either
##                                        target for write)
## --write refuses to overwrite an already-published document (matching generate_schedule_v3_
## boundary.gd's own "the record already exists and is never overwritten" law) so a second --write
## against a different subject_commit cannot silently re-bind an existing sealed document.

const DESKTOP_EVIDENCE := preload("res://tools/evidence/DesktopAmendmentContractEvidence.gd")
const MINESWEEPER_EVIDENCE := preload("res://tools/evidence/MinesweeperAmendmentContractEvidence.gd")
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

const MODE_FLAGS := ["write", "check"]


## Validates one complete command line. Returns value={mode, subject_commit}. Missing, extra,
## duplicate, and mixed flags all fail before any git or filesystem work happens.
static func parse_arguments(args: PackedStringArray) -> Dictionary:
	var mode: String = ""
	var subject_commit: String = ""
	for raw_argument: String in args:
		var argument: String = String(raw_argument)
		if not argument.begins_with("--"):
			return _fail(&"generator_argument_unknown", "arguments are long flags only", {"argument": argument})
		var body: String = argument.substr(2)
		var split_at: int = body.find("=")
		if split_at < 0:
			if not body in MODE_FLAGS:
				return _fail(&"generator_argument_unknown", "the valueless flag is not a mode", {"flag": body})
			if not mode.is_empty():
				return _fail(&"generator_mode_mixed", "exactly one of --write or --check is accepted",
					{"first": mode, "second": body})
			mode = body
			continue
		var flag: String = body.substr(0, split_at)
		var value: String = body.substr(split_at + 1)
		if flag != "subject-commit":
			return _fail(&"generator_argument_unknown", "unrecognized valued flag", {"flag": flag})
		if not subject_commit.is_empty():
			return _fail(&"generator_argument_duplicate", "subject-commit is supplied more than once", {})
		if value.is_empty():
			return _fail(&"generator_argument_blank", "subject-commit is never blank", {})
		subject_commit = value
	if mode.is_empty():
		return _fail(&"generator_mode_missing", "exactly one of --write or --check is required", {})
	if subject_commit.is_empty():
		return _fail(&"generator_argument_missing", "--subject-commit is required", {})
	return _ok({"mode": mode, "subject_commit": subject_commit})


static func _repository_root() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")


func _init() -> void:
	var parsed: Dictionary = parse_arguments(OS.get_cmdline_user_args())
	if not parsed.get("ok", false):
		_reject("ARGUMENTS", parsed)
		return
	var values: Dictionary = parsed.get("value", {}) as Dictionary
	var subject_commit: String = str(values["subject_commit"])
	if str(values["mode"]) == "check":
		_run_check(subject_commit)
		return
	_run_write(subject_commit)


func _run_write(subject_commit: String) -> void:
	var repository_root: String = _repository_root()
	if FileAccess.file_exists(DESKTOP_EVIDENCE.ARTIFACT_PATH) or FileAccess.file_exists(MINESWEEPER_EVIDENCE.ARTIFACT_PATH):
		_reject("WRITE", _fail(&"output_already_exists",
			"a generated document already exists and is never overwritten",
			{"desktop": DESKTOP_EVIDENCE.ARTIFACT_PATH, "minesweeper": MINESWEEPER_EVIDENCE.ARTIFACT_PATH}))
		return
	var desktop_built: Dictionary = DESKTOP_EVIDENCE.build(repository_root, subject_commit)
	if not desktop_built.get("ok", false):
		_reject("WRITE_DESKTOP", desktop_built)
		return
	var minesweeper_built: Dictionary = MINESWEEPER_EVIDENCE.build(repository_root, subject_commit)
	if not minesweeper_built.get("ok", false):
		_reject("WRITE_MINESWEEPER", minesweeper_built)
		return
	var desktop_written: Dictionary = DESKTOP_EVIDENCE.write_canonical(DESKTOP_EVIDENCE.ARTIFACT_PATH,
		(desktop_built.get("value", {}) as Dictionary).get("document", {}) as Dictionary)
	if not desktop_written.get("ok", false):
		_reject("WRITE_DESKTOP", desktop_written)
		return
	var minesweeper_written: Dictionary = MINESWEEPER_EVIDENCE.write_canonical(MINESWEEPER_EVIDENCE.ARTIFACT_PATH,
		(minesweeper_built.get("value", {}) as Dictionary).get("document", {}) as Dictionary)
	if not minesweeper_written.get("ok", false):
		_reject("WRITE_MINESWEEPER", minesweeper_written)
		return
	print("DESKTOP_AMENDMENT_EVIDENCE: GENERATED subject_commit=%s" % subject_commit)
	quit(0)


## Rebuilds both documents fresh from the named subject commit's tree and compares them
## byte-for-byte against the already-published files. Read-only throughout: never calls
## FileAccess.open(..., FileAccess.WRITE) or DirAccess.rename_absolute/remove_absolute on either
## target -- `build()`/`canonical_bytes()` are pure, and this function only ever reads.
func _run_check(subject_commit: String) -> void:
	var repository_root: String = _repository_root()
	var desktop_check: Dictionary = _check_one(DESKTOP_EVIDENCE, repository_root, subject_commit)
	if not desktop_check.get("ok", false):
		_reject("CHECK_DESKTOP", desktop_check)
		return
	var minesweeper_check: Dictionary = _check_one(MINESWEEPER_EVIDENCE, repository_root, subject_commit)
	if not minesweeper_check.get("ok", false):
		_reject("CHECK_MINESWEEPER", minesweeper_check)
		return
	print("DESKTOP_AMENDMENT_EVIDENCE: CHECK_OK subject_commit=%s" % subject_commit)
	quit(0)


func _check_one(evidence: Script, repository_root: String, subject_commit: String) -> Dictionary:
	var artifact_path: String = evidence.ARTIFACT_PATH
	if not FileAccess.file_exists(artifact_path):
		return {"ok": false, "code": &"output_missing", "message": "the published document is absent",
			"details": {"path": artifact_path}}
	var on_disk_bytes: PackedByteArray = FileAccess.get_file_as_bytes(artifact_path)
	var parsed: Dictionary = _STRICT_JSON.parse_object(on_disk_bytes.get_string_from_utf8())
	if not parsed.get("ok", false):
		return {"ok": false, "code": &"output_unparsable", "message": "the published document is not a strict object", "details": {}}
	var on_disk_document: Dictionary = parsed.get("value", {}) as Dictionary
	if str(on_disk_document.get("subject_commit", "")) != subject_commit:
		return {"ok": false, "code": &"subject_commit_mismatch",
			"message": "the published document names a different subject_commit",
			"details": {"published": str(on_disk_document.get("subject_commit", "")), "requested": subject_commit}}
	var rebuilt: Dictionary = evidence.build(repository_root, subject_commit)
	if not rebuilt.get("ok", false):
		return rebuilt
	var rebuilt_document: Dictionary = (rebuilt.get("value", {}) as Dictionary).get("document", {}) as Dictionary
	var canonical: Dictionary = evidence.canonical_bytes(rebuilt_document)
	if not canonical.get("ok", false):
		return canonical
	var fresh_bytes: PackedByteArray = (canonical.get("value", {}) as Dictionary).get("bytes", PackedByteArray())
	if fresh_bytes != on_disk_bytes:
		return {"ok": false, "code": &"output_not_canonical",
			"message": "fresh regeneration is not byte-equal to the published document",
			"details": {"path": artifact_path}}
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func _reject(stage: String, envelope: Dictionary) -> void:
	printerr("DESKTOP_AMENDMENT_EVIDENCE_%s_REJECTED: %s: %s" % [
		stage, str(envelope.get("code", &"")), str(envelope.get("message", "")),
	])
	quit(1)


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
