extends SceneTree

## Validator for evidence/phase_2r/handoff/desktop_contract.json (dwm-p2r.9 Plan 06 Task 3).
##
## Runs via `-s`. Strict-parses the artifact and the schema, applies schema plus semantic
## validation, then rebuilds the expected canonical bytes and requires byte equality. Any artifact
## drift -- including final Bootstrap/project/source-binding drift -- fails freshness here.
##
## Prints exactly one success line: `DESKTOP_HANDOFF: PASS interface_version=1`.

const EVIDENCE := preload("res://tools/evidence/DesktopContractEvidence.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")


func _init() -> void:
	if not FileAccess.file_exists(EVIDENCE.ARTIFACT_PATH):
		_reject("READ", {"code": &"artifact_missing", "message": EVIDENCE.ARTIFACT_PATH})
		return
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(EVIDENCE.ARTIFACT_PATH)
	var parsed: Dictionary = STRICT_JSON.parse_object(bytes.get_string_from_utf8())
	if not parsed.get("ok", false):
		_reject("PARSE", {"code": &"artifact_unparsable", "message": str(parsed.get("message", ""))})
		return
	var artifact: Dictionary = parsed.get("value", {}) as Dictionary
	var validated: Dictionary = EVIDENCE.validate(artifact)
	if not validated.get("ok", false):
		_reject("VALIDATE", validated)
		return
	# Freshness: the committed bytes must equal a fresh canonical build from production constants.
	var rebuilt: Dictionary = EVIDENCE.build()
	if not rebuilt.get("ok", false):
		_reject("REBUILD", rebuilt)
		return
	var canonical: Dictionary = EVIDENCE.canonical_bytes(
		(rebuilt.get("value", {}) as Dictionary).get("artifact", {}) as Dictionary)
	if not canonical.get("ok", false):
		_reject("SERIALIZE", canonical)
		return
	if (canonical.get("value", {}) as Dictionary).get("bytes", PackedByteArray()) != bytes:
		_reject("FRESHNESS", {"code": &"artifact_not_canonical",
			"message": "the artifact bytes are not the canonical serialization of a fresh build"})
		return
	print("DESKTOP_HANDOFF: PASS interface_version=%d" % EVIDENCE.INTERFACE_VERSION)
	quit(0)


func _reject(stage: String, envelope: Dictionary) -> void:
	printerr("DESKTOP_HANDOFF_%s_REJECTED: %s: %s" % [
		stage, str(envelope.get("code", &"")), str(envelope.get("message", "")),
	])
	quit(1)
