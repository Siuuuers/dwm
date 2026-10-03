class_name DtlStructureValidator
extends RefCounted
## Scene-oriented DTL checks. The minimal playable entries admit only text and frozen routing.
## Legacy labels remain registered in timelines.json; semantic labels retain their allowed hooks.

const LABEL_PREFIX := "label "
const TERMINATOR := "return"
const PURPOSE_PREFIX := "# PURPOSE: "
const SIGNALS_PREFIX := "# ALLOWED SIGNALS: "
const DTL_FILE_MISSING := &"DTL_FILE_MISSING"
const DTL_EMPTY := &"DTL_EMPTY"
const DTL_LEADING_RETURN_MISSING := &"DTL_LEADING_RETURN_MISSING"
const DTL_DUPLICATE_LABEL := &"DTL_DUPLICATE_LABEL"
const DTL_LABEL_FALLTHROUGH := &"DTL_LABEL_FALLTHROUGH"
const DTL_TRAILING_FALLTHROUGH := &"DTL_TRAILING_FALLTHROUGH"
const DTL_UNREGISTERED_LABEL := &"DTL_UNREGISTERED_LABEL"
const DTL_MISSING_LABEL := &"DTL_MISSING_LABEL"
const DTL_PURPOSE_MISMATCH := &"DTL_PURPOSE_MISMATCH"
const DTL_SIGNAL_COMMENT_MISMATCH := &"DTL_SIGNAL_COMMENT_MISMATCH"
const DTL_DIRECT_DOMAIN_CALL := &"DTL_DIRECT_DOMAIN_CALL"
const DTL_DYNAMIC_RESOURCE_PATH := &"DTL_DYNAMIC_RESOURCE_PATH"
const DTL_DIALOGUE_LINE := &"DTL_DIALOGUE_LINE"
const DTL_INVALID_JUMP := &"DTL_INVALID_JUMP"
const PLAYABLE := {
	"res://dialogic/timelines/en/core/hospital_faint.dtl": {
		"labels": ["hospital.faint.shared", "hospital.faint.sylvia", "hospital.faint.ordinary"],
		"conditions": ["if {Frozen.sylvia_eligible}:", "else:"]},
	"res://dialogic/timelines/en/dating/solo/priscilla_day1_post_challenge.dtl": {
		"labels": ["dating.solo.priscilla.day1.post_challenge.exploded",
			"dating.solo.priscilla.day1.post_challenge.perfect",
			"dating.solo.priscilla.day1.post_challenge.cleared"],
		"conditions": ['if {Frozen.board_result} == "exploded":',
			'elif {Frozen.board_result} == "perfect":', 'elif {Frozen.board_result} == "cleared":']},
}


static func validate_text(path: String, text: String, expected: Array,
		legacy_labels: Array = []) -> Dictionary:
	var failures: Array = []
	if text.is_empty():
		return _result([_failure(DTL_EMPTY, 0, path + ": scene is empty")])
	var blocks := {}
	var playable: Dictionary = PLAYABLE.get(path, {})
	var jumps: Array[Dictionary] = []
	var current := ""
	var first_event := ""
	var line_number := 0
	for raw: String in text.split("\n"):
		line_number += 1
		var line := raw.strip_edges()
		if line.is_empty(): continue
		if line.begins_with("#"):
			if current != "":
				if line.begins_with(PURPOSE_PREFIX):
					blocks[current]["purpose"] = line.substr(PURPOSE_PREFIX.length())
				elif line.begins_with(SIGNALS_PREFIX):
					blocks[current]["signals"] = line.substr(SIGNALS_PREFIX.length())
			continue
		if first_event.is_empty(): first_event = line
		if line.begins_with(LABEL_PREFIX):
			var label := line.substr(LABEL_PREFIX.length())
			if current != "" and not blocks[current]["closed"]:
				failures.append(_failure(DTL_LABEL_FALLTHROUGH, line_number,
					"%s: %s falls into %s" % [path, current, label]))
			if blocks.has(label):
				failures.append(_failure(DTL_DUPLICATE_LABEL, line_number, path + ": " + label))
			else:
				blocks[label] = {"line": line_number, "closed": false, "purpose": "", "signals": ""}
			current = label
		elif line == TERMINATOR:
			if current != "": blocks[current]["closed"] = true
		elif not playable.is_empty() and not current.is_empty() and line.begins_with("jump "):
			jumps.append({"target": line.trim_prefix("jump "), "line": line_number})
		elif not playable.is_empty() and not current.is_empty() and (
				line in playable.conditions or _plain_caption(line)):
			pass
		else:
			var code := DTL_DIALOGUE_LINE
			if line.contains("res://") or line.contains("user://") or line.contains("load("):
				code = DTL_DYNAMIC_RESOURCE_PATH
			elif line.contains("(") and line.contains(")") and line.contains("."):
				code = DTL_DIRECT_DOMAIN_CALL
			failures.append(_failure(code, line_number, path + ": dialogue-free scene contains an executable event"))
	if first_event != TERMINATOR:
		failures.append(_failure(DTL_LEADING_RETURN_MISSING, 0, path + ": unlabeled playback must remain a no-op"))
	if current != "" and not blocks[current]["closed"]:
		failures.append(_failure(DTL_TRAILING_FALLTHROUGH, blocks[current]["line"], path + ": " + current))
	var registered := {}
	for entry: Dictionary in expected:
		var label := str(entry["label"])
		registered[label] = true
		if not blocks.has(label):
			failures.append(_failure(DTL_MISSING_LABEL, 0, path + ": " + label))
			continue
		var block: Dictionary = blocks[label]
		if block["purpose"] != str(entry["role"]):
			failures.append(_failure(DTL_PURPOSE_MISMATCH, block["line"], path + ": " + label))
		if block["signals"] != ", ".join(PackedStringArray(entry["allowed_signals"])):
			failures.append(_failure(DTL_SIGNAL_COMMENT_MISMATCH, block["line"], path + ": " + label))
	for jump: Dictionary in jumps:
		if not blocks.has(jump.target) or not jump.target in playable.labels:
			failures.append(_failure(DTL_INVALID_JUMP, jump.line, path + ": " + jump.target))
	for label: Variant in blocks:
		if not registered.has(label) and not legacy_labels.has(label) and not label in playable.get("labels", []):
			failures.append(_failure(DTL_UNREGISTERED_LABEL, blocks[label]["line"], path + ": " + str(label)))
	for label: Variant in legacy_labels:
		if not blocks.has(label):
			failures.append(_failure(DTL_MISSING_LABEL, 0, path + ": legacy " + str(label)))
	return _result(failures)


## The first playable slice uses narrator text only. Reject Dialogic shortcodes,
## interpolation, choices, speaker commands and expression syntax rather than
## admitting a general executable event under the guise of placeholder copy.
static func _plain_caption(line: String) -> bool:
	if line.is_empty() or not line.left(1).to_lower() in "abcdefghijklmnopqrstuvwxyz": return false
	for symbol: String in ["[", "]", "{", "}", "(", ")", ":", "=", "<", ">", "\\"]:
		if line.contains(symbol): return false
	return DialogicTimeline.event_from_string(line, DialogicResourceUtil.get_event_cache()) is DialogicTextEvent


## Compatibility name retained for callers; the values are now ordinary scene paths.
static func partition_by_master(document: Dictionary) -> Dictionary:
	var out := {}
	for record: Dictionary in document.get("entries", []):
		var locator: Dictionary = record.get("locators", {}).get("en", {})
		var path := str(locator.get("path", ""))
		if path.is_empty(): continue
		if not out.has(path): out[path] = []
		out[path].append({"label": str(locator["label"]), "role": record["role"],
			"allowed_signals": record["allowed_signals"]})
	return out


static func validate_file(path: String, expected: Array, legacy_labels: Array = []) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _result([_failure(DTL_FILE_MISSING, 0, path)])
	return validate_text(path, FileAccess.get_file_as_string(path), expected, legacy_labels)


static func _failure(code: StringName, line: int, message: String) -> Dictionary:
	return {"code": code, "line": line, "message": message}


static func _result(failures: Array) -> Dictionary:
	return {"ok": failures.is_empty(), "failures": failures}
